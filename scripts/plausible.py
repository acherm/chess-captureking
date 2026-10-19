#!/usr/bin/env python3
"""Keep hunted positions whose material could arise in a game, smallest first.

A necessary condition for a position to be reachable: for each side, the pieces beyond the
initial set (a second queen, a third rook, ...) need promotions, and there are at most
8 - (pawns on the board) of them. Bishops are counted per square colour.
Reads lines "FEN<TAB>description" on stdin, writes the plausible ones sorted by number of pieces.
"""
import sys

import chess


def promotions_needed(board, color):
    q = len(board.pieces(chess.QUEEN, color))
    r = len(board.pieces(chess.ROOK, color))
    n = len(board.pieces(chess.KNIGHT, color))
    bishops = board.pieces(chess.BISHOP, color)
    light = len(bishops & chess.BB_LIGHT_SQUARES)
    dark = len(bishops & chess.BB_DARK_SQUARES)
    return max(0, q - 1) + max(0, r - 2) + max(0, n - 2) + max(0, light - 1) + max(0, dark - 1)


def plausible(board):
    for color in chess.COLORS:
        pawns = len(board.pieces(chess.PAWN, color))
        if pawns > 8 or promotions_needed(board, color) > 8 - pawns:
            return False
        if len(board.occupied_co[color] and chess.SquareSet(board.occupied_co[color])) > 16:
            return False
    return True


def main():
    rows = []
    for line in sys.stdin:
        line = line.rstrip("\n")
        if not line:
            continue
        fen, _, why = line.partition("\t")
        board = chess.Board(fen)
        if plausible(board):
            rows.append((len(board.piece_map()), fen, why))
    rows.sort()
    seen = set()
    for n, fen, why in rows:
        if fen not in seen:
            seen.add(fen)
            print(f"{n}\t{fen}\t{why}")


if __name__ == "__main__":
    main()
