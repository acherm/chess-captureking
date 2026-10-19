#!/usr/bin/env python3
"""Attribute the verdict disagreements of `chess compare` outputs to rules (run with `python3 -I`).

For each position where the standard verdict (horizon H) and the natural verdict (horizon H+2)
disagree, re-solve it with three variants:
  natural-fide-castling    natural chess keeping the FIDE castling conditions
  standard-stalemate-wins  standard chess where stalemate is a win for the stalemating player
  natural-dead             natural chess keeping the dead-position rule
If the first (or third) agrees with standard chess, castling (or the dead-position rule) explains
the difference; if the second agrees with natural chess, stalemate explains it.

Usage: attribute.py CHESS_BINARY H OUT.tsv FILE.tsv [FILE.tsv ...]
"""
import csv
import subprocess
import sys


def result(tag, turn):
    # verdict strings printed by `solve`: "win in N plies", "loss in N plies", "over …", "unknown"
    if tag.startswith("win"):
        return "1-0" if turn == "w" else "0-1"
    if tag.startswith("loss"):
        return "0-1" if turn == "w" else "1-0"
    if tag.startswith("over"):
        return tag.split()[1]
    return "?"


def solve(binary, rules, plies, fens):
    out = subprocess.run([binary, "solve-batch", rules, str(plies)], input="\n".join(fens) + "\n",
                         capture_output=True, text=True, check=True).stdout
    return [l.split("\t")[1].split("\t(")[0] for l in out.splitlines() if l]


def main():
    binary, h, out_path = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    rows = []
    for path in sys.argv[4:]:
        for r in csv.DictReader(open(path), delimiter="\t"):
            a, b = r["verdict_a"].split(":")[0], r["verdict_b"].split(":")[0]
            if a != b:
                rows.append((path, r["fen"], a, b))
    fens = [f for _, f, _, _ in rows]
    fide_castling = solve(binary, "natural-fide-castling", h + 2, fens)
    stalemate_wins = solve(binary, "standard-stalemate-wins", h, fens)
    dead = solve(binary, "natural-dead", h + 2, fens)
    counts = {}
    with open(out_path, "w") as out:
        out.write("source\tfen\tstandard\tnatural\tnatural_fide_castling\tstandard_stalemate_wins\tnatural_dead\tcause\n")
        for (path, fen, a, b), c, s, d in zip(rows, fide_castling, stalemate_wins, dead):
            turn = fen.split()[1]
            rc, rs, rd = result(c, turn), result(s, turn), result(d, turn)
            causes = []
            if rc == a:
                causes.append("castling")
            if rs == b:
                causes.append("stalemate")
            if rd == a:
                causes.append("deadPosition")
            cause = "+".join(causes) or "other"
            counts[cause] = counts.get(cause, 0) + 1
            out.write(f"{path}\t{fen}\t{a}\t{b}\t{c}\t{s}\t{d}\t{cause}\n")
    print(f"{len(rows)} disagreements; causes: {counts}")


if __name__ == "__main__":
    main()
