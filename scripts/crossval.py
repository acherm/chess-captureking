#!/usr/bin/env python3
"""Cross-validate the Lean engines against python-chess (run with `python3 -I`).

Standard chess: the Lean `standard` rule set must agree with python-chess on the legal moves
(UCI), their SAN, check, and the status of the position (checkmate, stalemate, insufficient
material, 75-move rule), and must replay every game of games.uci with the same final status.

Natural chess: the Lean `natural` rule set must agree with an independent reference written
here on top of python-chess: pseudo-legal moves (python-chess), with castling regenerated
without the conditions on attacked squares, and no moves once a king has been captured.

Usage: crossval.py CHESS_BINARY POSITIONS_DIR
"""
import subprocess
import sys

import chess


def lean(binary, args, lines):
    out = subprocess.run([binary] + args, input="\n".join(lines) + "\n", capture_output=True,
                         text=True, check=True).stdout
    return [l for l in out.split("\n") if l]


def py_status(board):
    o = board.outcome(claim_draw=False)
    if o is None:
        return "ongoing"
    name = {chess.Termination.CHECKMATE: "checkmate", chess.Termination.STALEMATE: "stalemate",
            chess.Termination.INSUFFICIENT_MATERIAL: "deadPosition",
            chess.Termination.SEVENTYFIVE_MOVES: "seventyFiveMoves",
            chess.Termination.FIVEFOLD_REPETITION: "fivefoldRepetition"}[o.termination]
    return f"{o.result()} {name}"


def same_status(lean_status, py):
    if lean_status == py:
        return True
    # a stalemate with insufficient material: python-chess reports the material first
    return {lean_status, py} == {"1/2-1/2 stalemate", "1/2-1/2 deadPosition"}


def natural_moves(board):
    """Reference natural-chess moves: pseudo-legal moves, castling ignoring attacks."""
    if board.king(chess.WHITE) is None or board.king(chess.BLACK) is None:
        return []
    moves = [m for m in board.generate_pseudo_legal_moves() if not board.is_castling(m)]
    rank = 0 if board.turn == chess.WHITE else 7
    king, rook_k, rook_q = chess.square(4, rank), chess.square(7, rank), chess.square(0, rank)
    for rook, between, king_to, right in [
            (rook_k, [5, 6], 6, board.has_kingside_castling_rights(board.turn)),
            (rook_q, [1, 2, 3], 2, board.has_queenside_castling_rights(board.turn))]:
        if (right and board.piece_at(king) == chess.Piece(chess.KING, board.turn)
                and board.piece_at(rook) == chess.Piece(chess.ROOK, board.turn)
                and all(board.piece_at(chess.square(f, rank)) is None for f in between)):
            moves.append(chess.Move(king, chess.square(king_to, rank)))
    return moves


def natural_perft(board, depth):
    if depth == 0:
        return 1
    moves = natural_moves(board)
    if depth == 1:
        return len(moves)
    n = 0
    for m in moves:
        board.push(m)
        n += natural_perft(board, depth - 1)
        board.pop()
    return n


def check_positions(binary, path, report):
    fens = [l.split("\t")[0] for l in open(path) if l.strip()]
    std = lean(binary, ["legal-batch", "standard"], fens)
    nat = lean(binary, ["legal-batch", "natural"], fens)
    bad = {"std_moves": 0, "std_san": 0, "std_check": 0, "std_status": 0, "nat_moves": 0}
    examples = []
    for fen, s, n in zip(fens, std, nat):
        board = chess.Board(fen)
        _, moves, status, check, sans = (s.split("\t") + [""] * 5)[:5]
        py_moves = " ".join(sorted(m.uci() for m in board.legal_moves))
        py_sans = " ".join(sorted(board.san(m) for m in board.legal_moves))
        problems = []
        if moves != py_moves:
            problems.append("std_moves")
        if sans != py_sans:
            problems.append("std_san")
        if (check == "true") != board.is_check():
            problems.append("std_check")
        if not same_status(status, py_status(board)):
            problems.append("std_status")
        if n.split("\t")[1] != " ".join(sorted(m.uci() for m in natural_moves(board))):
            problems.append("nat_moves")
        for p in problems:
            bad[p] += 1
        if problems and len(examples) < 5:
            examples.append((fen, problems))
    report.append(f"{path}: {len(fens)} positions; mismatches {bad}")
    for fen, problems in examples:
        report.append(f"    {fen}: {problems}")


def check_games(binary, path, report):
    games = [l.rstrip("\n").split("\t") for l in open(path) if l.strip()]
    rows = lean(binary, ["games-batch", "standard"], [f"{g[0]}\t{g[3] if len(g) > 3 else ''}" for g in games])
    bad = 0
    for g, row in zip(games, rows):
        site, _, py, *_ = g
        r = row.split("\t")
        lean_status = r[2] if r[1] == "ok" else "ILLEGAL " + r[2]
        if lean_status.startswith("ongoing"):
            lean_status = "ongoing"
        py = py.replace("CHECKMATE", "checkmate").replace("STALEMATE", "stalemate") \
               .replace("INSUFFICIENT_MATERIAL", "deadPosition") \
               .replace("SEVENTYFIVE_MOVES", "seventyFiveMoves") \
               .replace("FIVEFOLD_REPETITION", "fivefoldRepetition")
        if not same_status(lean_status, py):
            bad += 1
            if bad <= 5:
                report.append(f"    game {site}: lean '{lean_status}' python-chess '{py}'")
    report.append(f"{path}: {len(games)} games replayed; {bad} status mismatches")


def check_natural_perft(binary, report):
    positions = {
        "initial": ("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", 4),
        "kiwipete": ("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", 3),
        "pos3": ("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", 4),
        "pos4": ("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", 3),
        "pos5": ("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", 3),
        "pos6": ("r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10", 3),
    }
    for name, (fen, depth) in positions.items():
        for d in range(1, depth + 1):
            ours = int(subprocess.run([binary, "perft", "natural", str(d)] + fen.split(),
                                      capture_output=True, text=True).stdout.split()[0])
            ref = natural_perft(chess.Board(fen), d)
            flag = "ok" if ours == ref else "MISMATCH"
            report.append(f"natural perft {name} depth {d}: lean {ours}, reference {ref} {flag}")


def main():
    binary, posdir = sys.argv[1], sys.argv[2]
    report = []
    for name in ["random", "check", "mate", "stalemate", "insufficient"]:
        check_positions(binary, f"{posdir}/{name}.fen", report)
        print(report[-1], flush=True)
    check_games(binary, f"{posdir}/games.uci", report)
    print(report[-1], flush=True)
    check_natural_perft(binary, report)
    print("\n".join(report))


if __name__ == "__main__":
    main()
