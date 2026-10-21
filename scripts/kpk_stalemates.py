#!/usr/bin/env python3
"""The K+P v K stalemates of results/stalemates_passing.tsv, in detail.

Groups them by pattern (colours normalized so that White stalemates Black, files mirrored so that
the pawn is on the e- to h-file), and values, exactly, the position one move earlier (the
stalemating side to move, replayed from the Lichess PGN) under standard chess, passing and
lose-your-turn.

usage: python3 -I scripts/kpk_stalemates.py > results/kpk_stalemates.txt
"""
import collections
import io
import subprocess

import chess
import chess.pgn

CHESS = ".lake/build/bin/chess"
PGN = "data/lichess-games/2026-09-head.pgn"
RULES = ["standard", "standard-passing", "standard-lose-turn"]


def normalize(fen):
    b = chess.Board(fen)
    if b.turn == chess.WHITE:
        b = b.mirror()
    pawn = next(s for s, p in b.piece_map().items() if p.piece_type == chess.PAWN)
    if chess.square_file(pawn) < 4:
        b = b.transform(chess.flip_horizontal)
    return b.board_fen()


def before_positions(ids):
    """Game id -> (FEN before the last move, last move in SAN)."""
    found, lines, gid = {}, [], None

    def flush():
        if gid in ids:
            game = chess.pgn.read_game(io.StringIO("".join(lines)))
            board = game.board()
            moves = list(game.mainline_moves())
            for m in moves[:-1]:
                board.push(m)
            found[gid] = (board.fen(), board.san(moves[-1]))

    with open(PGN) as f:
        for line in f:
            if line.startswith("[Event "):
                flush()
                lines, gid = [], None
            if line.startswith("[Site "):
                gid = line.strip().rstrip('"]').split("/")[-1]
            lines.append(line)
        flush()
    return found


def exact(rules, fens):
    out = subprocess.run([CHESS, "exact-batch", rules], input="\n".join(fens) + "\n",
                         capture_output=True, text=True, check=True).stdout
    return dict(line.split("\t") for line in out.splitlines())


def verdict(v):
    """A value for the player to move (the stalemating side) -> win/draw/loss."""
    return "win" if v.startswith("win") else "loss" if v.startswith("loss") else "draw"


def main():
    rows = [l.rstrip("\n").split("\t") for l in open("results/stalemates_passing.tsv")][1:]
    kpk = [r for r in rows if r[2] == "KP v K"]
    before = before_positions({r[0] for r in kpk})
    small = sorted({fen for fen, _ in before.values()
                    if sum(c.isalpha() for c in fen.split()[0]) <= 3})
    values = {rs: exact(rs, small) for rs in RULES}
    groups = collections.defaultdict(list)
    for gid, fen, _, _, passing, lose_turn in kpk:
        prev, move = before[gid]
        prev_values = tuple(verdict(values[rs][prev]) if prev in values[rs] else "4 pieces"
                            for rs in RULES)
        groups[normalize(fen)].append((gid, passing, lose_turn, prev, move, prev_values))
    print(f"{len(kpk)} K+P v K stalemates (normalized: White stalemates Black, pawn on files e-h)\n")
    for pattern, games in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        print(f"{pattern}  ({len(games)} games)")
        for (passing, lose_turn), n in collections.Counter((g[1], g[2]) for g in games).items():
            print(f"  stalemate: passing {passing}, lose-your-turn {lose_turn}: {n}")
        counts = collections.Counter(g[5] for g in games)
        for prev_values, n in sorted(counts.items()):
            example = next(g for g in games if g[5] == prev_values)
            print(f"  one move earlier, standard/passing/lose-your-turn {'/'.join(prev_values)}: {n}"
                  f"  (e.g. {example[0]}: {example[3]}, then {example[4]})")
        print()


if __name__ == "__main__":
    main()
