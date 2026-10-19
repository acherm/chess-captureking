#!/usr/bin/env python3
"""Summarize `chess grid-verdicts` output (run with `python3 -I`).

Input: the TSV printed by `chess grid-verdicts HORIZON` (one row per position: the FEN, then one
verdict per rule set, e.g. `W:win3`, `L:loss2`, `D:stalemate`, `?:unknown`; horizon H for the
standard games, H+2 for the natural ones). The first 8 rule sets are Hamkins' grid; the last 4
are the naturalized standard games, which are paired with the natural games in the same order.

Output (markdown, on stdout):
* the verdicts of each rule set (W/D/L for the player to move, ? = undecided within the horizon);
* for each pair of grid games, the positions where both verdicts are known and differ
  ("certain" disagreements), with one witness (opposite decisive results preferred);
* for each bridge, the disagreements and whether every decisive verdict of the natural game is
  exactly 2 plies longer than that of its naturalized standard counterpart.

Usage: summarize_grid.py GRID_VERDICTS_TSV
"""
import re
import sys
from collections import Counter


def result(tag):
    return tag.split(":", 1)[0]


def plies(tag):
    """Distance of a decisive verdict in plies (0 when the game is already over)."""
    m = re.search(r"(win|loss)(\d+)$", tag)
    if m:
        return int(m.group(2))
    return 0 if result(tag) in ("W", "L") else None


def main(path):
    with open(path) as f:
        header = f.readline().rstrip("\n").split("\t")
        rows = [line.rstrip("\n").split("\t") for line in f if line.strip()]
    rows = [r for r in rows if len(r) == len(header)]
    names = header[1:]
    grid, bridges = names[:8], names[8:]
    col = {n: i + 1 for i, n in enumerate(names)}
    print(f"{len(rows)} positions\n")

    print("| rule set | W | D | L | ? |")
    print("|---|---|---|---|---|")
    for n in names:
        c = Counter(result(r[col[n]]) for r in rows)
        print(f"| `{n}` | {c['W']} | {c['D']} | {c['L']} | {c['?']} |")

    print("\n| game A | game B | certain disagreements | witness | A | B |")
    print("|---|---|---|---|---|---|")
    for i, a in enumerate(grid):
        for b in grid[i + 1:]:
            diffs = [r for r in rows
                     if "?" not in (result(r[col[a]]), result(r[col[b]]))
                     and result(r[col[a]]) != result(r[col[b]])]
            opposite = [r for r in diffs if {result(r[col[a]]), result(r[col[b]])} == {"W", "L"}]
            w = (opposite or diffs or [None])[0]
            wit = f"`{w[0]}` | {w[col[a]]} | {w[col[b]]}" if w else "| |"
            print(f"| `{a}` | `{b}` | {len(diffs)} | {wit} |")

    print("\n| naturalized standard game | natural game | certain disagreements | decisive in both | natural = naturalized + 2 plies |")
    print("|---|---|---|---|---|")
    for s, n in zip(bridges, grid[4:]):
        known = [r for r in rows if "?" not in (result(r[col[s]]), result(r[col[n]]))]
        dis = [r for r in known if result(r[col[s]]) != result(r[col[n]])]
        decisive = [r for r in known if result(r[col[s]]) == result(r[col[n]]) in ("W", "L")
                    and plies(r[col[s]]) is not None and plies(r[col[n]]) is not None]
        shifted = [r for r in decisive if plies(r[col[n]]) == plies(r[col[s]]) + 2]
        print(f"| `{s}` | `{n}` | {len(dis)} | {len(decisive)} | {len(shifted)} |")


if __name__ == "__main__":
    main(sys.argv[1])
