#!/usr/bin/env python3
"""Real stalemates under passing and lose-your-turn: who wins?

Joins the stalemates of data/positions/stalemate.fen (FEN, Lichess game id, ply) with the values
computed by `chess exact-batch` (positions with 3 pieces) and `chess solve-batch` (the others,
by increasing horizons), and writes, for each rule set, one row per game and a summary by
material. Values are given for the *stalemating* side (the player not to move).

usage: summarize_stalemates.py STALEMATES OUT_TSV RULES=EXACT_TSV,SEARCH_TSV[,SEARCH_TSV...] ...
"""
import collections
import re
import sys

import chess

VALUES = {chess.PAWN: 1, chess.KNIGHT: 3, chess.BISHOP: 3, chess.ROOK: 5, chess.QUEEN: 9}
ORDER = "QRBNP"


def material(board, color):
    pieces = [chess.piece_symbol(p.piece_type).upper() for p in board.piece_map().values()
              if p.color == color and p.piece_type != chess.KING]
    return "K" + "".join(sorted(pieces, key=ORDER.index))


def points(board, color):
    return sum(VALUES[p.piece_type] for p in board.piece_map().values()
               if p.color == color and p.piece_type != chess.KING)


def read_values(paths):
    """FEN -> (verdict for the stalemating side, method). Later files refine 'unknown'."""
    values = {}
    for path in paths:
        for line in open(path):
            fen, v = line.rstrip("\n").split("\t")[:2]
            if m := re.fullmatch(r"(win|loss|draw)(\d*)", v):          # exact-batch
                kind, n = m.groups()
                verdict = {"loss": "win", "win": "loss", "draw": "draw"}[kind]
                values[fen] = (verdict + (f" in {n}" if n else ""), "exact")
            elif m := re.fullmatch(r"(win|loss) in (\d+) plies", v):     # solve-batch
                kind, n = m.groups()
                verdict = {"loss": "win", "win": "loss"}[kind]
                values[fen] = (f"{verdict} in {n}", "search")
            elif v == "unknown":
                if fen not in values or values[fen][0] == "?":
                    values[fen] = ("?", "search")
            else:
                raise ValueError(line)
    return values


def main():
    stalemates_path, out_path, *specs = sys.argv[1:]
    rules = {}
    for spec in specs:
        name, files = spec.split("=")
        rules[name] = read_values(files.split(","))
    rows = []
    for line in open(stalemates_path):
        fen, game, ply = line.rstrip("\n").split("\t")
        b = chess.Board(fen)
        assert b.is_stalemate(), fen
        att = not b.turn
        mat = f"{material(b, att)} v {material(b, b.turn)}"
        adv = points(b, att) - points(b, b.turn)
        rows.append((game, fen, mat, adv, [rules[r][fen] for r in rules]))
    with open(out_path, "w") as out:
        out.write("game\tfen\tmaterial (stalemating v stalemated)\tadvantage\t" +
                  "\t".join(rules) + "\n")
        for game, fen, mat, adv, vs in rows:
            out.write(f"{game}\t{fen}\t{mat}\t{adv:+d}\t" +
                      "\t".join(f"{v} ({how})" for v, how in vs) + "\n")

    def tally(subset, i):
        c = collections.Counter(r[4][i][0].split(" ")[0] for r in subset)
        return c["win"], c["draw"], c["?"], c["loss"]

    def pct(k, n):
        return f"{k} ({100 * k / n:.1f}%)" if n else "0"

    groups = [
        ("all stalemates", rows),
        ("stalemating side ahead by 5 points or more", [r for r in rows if r[3] >= 5]),
        ("ahead by 1 to 4 points", [r for r in rows if 1 <= r[3] <= 4]),
        ("level or behind", [r for r in rows if r[3] <= 0]),
    ]
    for i, name in enumerate(rules):
        print(f"\n### {name} (value for the stalemating side)\n")
        print("| stalemates | n | win | draw | undecided | loss |")
        print("|---|---|---|---|---|---|")
        for label, subset in groups:
            w, d, u, l = tally(subset, i)
            n = len(subset)
            print(f"| {label} | {n} | {pct(w, n)} | {pct(d, n)} | {pct(u, n)} | {pct(l, n)} |")
        print("\nmost frequent material:\n")
        print("| material | n | win | draw | undecided |")
        print("|---|---|---|---|---|")
        by_mat = collections.defaultdict(list)
        for r in rows:
            by_mat[r[2]].append(r)
        for mat, subset in sorted(by_mat.items(), key=lambda kv: -len(kv[1]))[:12]:
            w, d, u, _ = tally(subset, i)
            print(f"| {mat} | {len(subset)} | {w} | {d} | {u} |")
        methods = collections.Counter((r[4][i][1], r[4][i][0].split(" ")[0]) for r in rows)
        print(f"\nmethods: {dict(sorted(methods.items()))}")


if __name__ == "__main__":
    main()
