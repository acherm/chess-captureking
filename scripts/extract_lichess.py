#!/usr/bin/env python3
"""Extract positions from a Lichess PGN dump (run with `python3 -I`).

Writes, in OUT_DIR:
  random.fen      one uniformly random position per sampled game (FEN, game id, ply)
  check.fen       positions where the side to move is in check (sampled games, capped)
  mate.fen        final positions of games ending in checkmate (all games)
  stalemate.fen   final positions of games ending in stalemate (all games)
  insufficient.fen final positions of games ending by insufficient material (all games)
  games.uci       sampled games as UCI move sequences, with result and python-chess final status

Usage: extract_lichess.py PGN OUT_DIR [--sample N] [--seed S]
"""
import argparse
import io
import os
import random
import re
import sys
from multiprocessing import Pool

import chess
import chess.pgn


def split_games(path):
    """Yield the raw text of each game (headers + movetext)."""
    buf = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("[Event ") and buf:
                yield "".join(buf)
                buf = []
            buf.append(line)
    if buf:
        yield "".join(buf)


def header(text, key):
    m = re.search(r'^\[' + key + r' "([^"]*)"\]', text, re.M)
    return m.group(1) if m else ""


def replay(text):
    """Parse a game; return (game id, list of positions as boards, moves) or None."""
    game = chess.pgn.read_game(io.StringIO(text))
    if game is None or game.errors:
        return None
    board = game.board()
    boards = [board.copy(stack=False)]
    moves = []
    for move in game.mainline_moves():
        board.push(move)
        moves.append(move)
        boards.append(board.copy(stack=False))
    return board, boards, moves


def process(args):
    idx, text, sampled, seed = args
    site = header(text, "Site").rsplit("/", 1)[-1]
    termination = header(text, "Termination")
    result = header(text, "Result")
    movetext = text.split("\n\n", 1)[-1]
    out = {"random": [], "check": [], "mate": [], "stalemate": [], "insufficient": [], "games": []}
    ends_with_mate = "#" in movetext[-40:]
    is_draw = result == "1/2-1/2"
    if not (sampled or ends_with_mate or is_draw):
        return out
    r = replay(text)
    if r is None:
        return out
    final, boards, moves = r
    if final.is_checkmate():
        out["mate"].append(f"{final.fen()}\t{site}\t{len(moves)}")
    if final.is_stalemate():
        out["stalemate"].append(f"{final.fen()}\t{site}\t{len(moves)}")
    if final.is_insufficient_material():
        out["insufficient"].append(f"{final.fen()}\t{site}\t{len(moves)}")
    if sampled:
        rng = random.Random(seed * 1000003 + idx)
        ply = rng.randrange(len(boards))
        out["random"].append(f"{boards[ply].fen()}\t{site}\t{ply}")
        checks = [(i, b) for i, b in enumerate(boards) if b.is_check()]
        for i, b in checks[:5]:
            out["check"].append(f"{b.fen()}\t{site}\t{i}")
        o = final.outcome(claim_draw=False)
        status = f"{o.result()} {o.termination.name}" if o else "ongoing"
        out["games"].append(f"{site}\t{result}\t{status}\t{' '.join(m.uci() for m in moves)}")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pgn")
    ap.add_argument("out_dir")
    ap.add_argument("--sample", type=int, default=20000, help="games fully sampled")
    ap.add_argument("--seed", type=int, default=2026)
    args = ap.parse_args()
    os.makedirs(args.out_dir, exist_ok=True)
    games = list(split_games(args.pgn))
    # the dump is cut in the middle of a game: drop the last one
    games = games[:-1]
    rng = random.Random(args.seed)
    sampled = set(rng.sample(range(len(games)), min(args.sample, len(games))))
    print(f"{len(games)} games, {len(sampled)} sampled", file=sys.stderr)
    jobs = ((i, g, i in sampled, args.seed) for i, g in enumerate(games))
    files = {k: open(os.path.join(args.out_dir, f"{k}.fen" if k != "games" else "games.uci"), "w")
             for k in ["random", "check", "mate", "stalemate", "insufficient", "games"]}
    with Pool(14) as pool:
        for n, out in enumerate(pool.imap(process, jobs, chunksize=200)):
            for k, lines in out.items():
                for line in lines:
                    files[k].write(line + "\n")
            if n % 50000 == 0:
                print(f"  {n} games processed", file=sys.stderr)
    for f in files.values():
        f.close()


if __name__ == "__main__":
    main()
