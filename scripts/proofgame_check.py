#!/usr/bin/env python3
"""Check proof games: each constructed position is reached from the initial position (run with `python3 -I`).

FIDE 3.10.3: "A position is illegal when it cannot have been reached by any series of legal moves."
Each row of the TSV gives a target FEN and a game (UCI moves) that should reach it. The game is replayed
with python-chess from the initial position, and the row is OK when
  * every move is legal in the position where it is played,
  * the game is not over before the last move: no checkmate, stalemate, insufficient material,
    fivefold repetition or 75-move rule at any earlier position (claim_draw=False). The final
    position may itself be over (several targets are checkmates, stalemates or dead positions),
  * the final position matches the target: piece placement, side to move, castling rights and
    en passant square (python-chess keeps an en passant square only when the capture is legal),
  * the move counters match when the target does not use the default "0 1" (only seventy-five,
    whose halfmove clock is the point of the position),
  * the reached_fen and plies columns agree with the replay.

TSV columns: name, target_fen, reached_fen, plies, uci_moves (space-separated).
Usage: proofgame_check.py data/proofgames/proofgames.tsv
"""
import csv
import sys

import chess


def legal_ep(board):
    return board.ep_square if board.has_legal_en_passant() else None


def final_status(board):
    o = board.outcome(claim_draw=False)
    if o is None:
        return "ongoing"
    return f"{o.result()} {o.termination.name.lower()}"


def check(row):
    """Replay one row; return (ok, message)."""
    moves = row["uci_moves"].split()
    board = chess.Board()
    for i, uci in enumerate(moves, start=1):
        o = board.outcome(claim_draw=False)
        if o is not None:
            return False, f"game over ({o.termination.name}) before ply {i}"
        try:
            move = chess.Move.from_uci(uci)
        except ValueError:
            return False, f"ply {i}: malformed move {uci}"
        if move not in board.legal_moves:
            return False, f"ply {i}: illegal move {uci} in {board.fen()}"
        board.push(move)

    target = chess.Board(row["target_fen"])
    problems = []
    if board.board_fen() != target.board_fen():
        problems.append(f"placement {board.board_fen()}")
    if board.turn != target.turn:
        problems.append("side to move")
    if board.castling_rights != target.castling_rights:
        problems.append(f"castling {board.castling_xfen()} (target {target.castling_xfen()})")
    if legal_ep(board) != target.ep_square:
        problems.append("en passant square")
    if (target.halfmove_clock, target.fullmove_number) != (0, 1):
        if board.halfmove_clock != target.halfmove_clock:
            problems.append(f"halfmove clock {board.halfmove_clock} (target {target.halfmove_clock})")
        if board.fullmove_number != target.fullmove_number:
            problems.append(f"fullmove number {board.fullmove_number} (target {target.fullmove_number})")
    if board.fen() != row["reached_fen"]:
        problems.append(f"reached_fen column differs from replay {board.fen()}")
    if int(row["plies"]) != len(moves):
        problems.append(f"plies column {row['plies']} but {len(moves)} moves")
    if problems:
        return False, "; ".join(problems)
    return True, f"{len(moves)} plies, reached {board.fen()} ({final_status(board)})"


def main(path):
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f, delimiter="\t"))
    failures = 0
    for row in rows:
        ok, msg = check(row)
        failures += not ok
        print(f"{'OK  ' if ok else 'FAIL'} {row['name']}: {msg}")
    print(f"{len(rows) - failures}/{len(rows)} proof games verified")
    return 1 if failures else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
