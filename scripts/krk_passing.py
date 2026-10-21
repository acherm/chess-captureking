#!/usr/bin/env python3
"""Which K+R v K positions are still won when the lone king may pass?

Reads the wins of `chess longest-wins R standard-passing 5000` (rook side to move) and
1. classifies them by the square of the lone king and the distance between the kings;
2. recomputes, independently of the Lean tablebase, the positions where the lone king, to move,
   loses: it may pass when not in check, and loses when every option (pass, king move) leads to
   one of those wins, or when it is checkmated. Capturing the rook draws.

usage: chess longest-wins R standard-passing 5000 | python3 -I scripts/krk_passing.py
"""
import collections
import sys

import chess

CORNERS = (chess.A1, chess.A8, chess.H1, chess.H8)


def where(s):
    if s in CORNERS:
        return "corner"
    f, r = chess.square_file(s), chess.square_rank(s)
    return "edge" if f in (0, 7) or r in (0, 7) else "inside"


def main():
    wins = {}
    for line in sys.stdin:
        fen, value = line.split()[0:6], line.rstrip("\n").split("\t")[1]
        wins[fen[0]] = (" ".join(fen), value)
    kinds = collections.Counter()
    example = {}
    for fen, value in wins.values():
        b = chess.Board(fen)
        lone = b.king(not b.turn)
        key = (value, where(lone), chess.square_distance(lone, b.king(b.turn)))
        kinds[key] += 1
        example.setdefault(key, fen)
    print(f"{len(wins)} wins for the rook side (to move), by value, lone king, distance between kings")
    for key in sorted(kinds):
        print(f"  {kinds[key]:5}  {key[0]:5} {key[1]:6} {key[2]}   e.g. {example[key]}")

    losses = collections.Counter()
    example = {}
    for wk in chess.SQUARES:
        for wr in chess.SQUARES:
            for bk in chess.SQUARES:
                if len({wk, wr, bk}) < 3 or chess.square_distance(wk, bk) < 2:
                    continue
                b = chess.Board(None)
                b.set_piece_at(wk, chess.Piece(chess.KING, chess.WHITE))
                b.set_piece_at(wr, chess.Piece(chess.ROOK, chess.WHITE))
                b.set_piece_at(bk, chess.Piece(chess.KING, chess.BLACK))
                b.turn = chess.BLACK
                options = []
                for m in b.legal_moves:
                    if b.is_capture(m):
                        options.append(False)
                    else:
                        b.push(m)
                        options.append(b.board_fen() in wins)
                        b.pop()
                if not b.is_check():
                    options.append(b.board_fen() in wins)   # the pass
                if all(options):
                    kind = ("checkmate" if b.is_checkmate() else "stalemate" if b.is_stalemate()
                            else "in check" if b.is_check() else "not in check")
                    key = (kind, where(bk))
                    losses[key] += 1
                    example.setdefault(key, b.fen())
    print(f"\n{sum(losses.values())} losses for the lone king (to move)")
    for key in sorted(losses):
        print(f"  {losses[key]:5}  {key[0]:12} {key[1]:6}   e.g. {example[key]}")


if __name__ == "__main__":
    main()
