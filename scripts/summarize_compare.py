#!/usr/bin/env python3
"""Summarize `chess compare standard natural H` outputs (TSV) as Markdown.

For each file: how often the legal moves differ (and which standard rules forbid the extra
natural moves), how often natural chess has extra *safe* moves (castling out of / through
check), how the status of the position (game over or not) differs, and how the verdicts of the
bounded searches differ (standard horizon H, natural horizon H+2).

Usage: summarize_compare.py OUT.md NAME=FILE.tsv[:ATTRIB.tsv] ...
(the optional ATTRIB.tsv, a `compare` run without horizon on the same positions, supplies the
move-level columns; FILE.tsv supplies the verdicts)
"""
import collections
import csv
import sys


def load(path):
    with open(path) as f:
        return list(csv.DictReader(f, delimiter="\t"))


def pct(n, total):
    return f"{100.0 * n / total:.2f}%" if total else "-"


def result_of(tag):
    return tag.split(":", 1)[0] if tag else ""


def status_kind(tag):
    if tag == "ongoing":
        return "ongoing"
    res, rule = tag.split(":", 1)
    return f"{res} ({rule})"


def summarize(name, rows, out):
    n = len(rows)
    differ = [r for r in rows if int(r["n_only_b"]) or int(r["n_only_a"])]
    only_a = sum(int(r["n_only_a"]) for r in rows)
    extra = sum(int(r["n_only_b"]) for r in rows)
    by_rule = {k: sum(int(r[f"by_{k}"]) for r in rows)
               for k in ["noSelfCheck", "castlingNotOutOfCheck", "castlingNotThroughCheck", "noKingCapture"]}
    safe = [r for r in rows if int(r["n_safe_only_b"])]
    checks = sum(r["in_check"] == "true" for r in rows)
    out.append(f"### {name}\n")
    out.append(f"* positions: **{n}** (side to move in check: {checks}, {pct(checks, n)})")
    out.append(f"* legal move sets differ: **{len(differ)}** ({pct(len(differ), n)}); "
               f"standard-only moves: {only_a}; natural-only moves: {extra} "
               f"(mean {extra / n:.2f} per position, standard mean {sum(int(r['n_a']) for r in rows) / n:.2f} legal moves)")
    out.append("* standard rules forbidding the natural-only moves (a move may be forbidden by several): " +
               ", ".join(f"`{k}` {v}" for k, v in by_rule.items()))
    out.append(f"* positions where natural chess has extra **safe** moves (the mover's king is not "
               f"attacked afterwards): **{len(safe)}** ({pct(len(safe), n)})")
    for r in safe[:8]:
        out.append(f"    * `{r['fen']}`: {r['safe_only_b']} (standard status: {r['status_a']}, "
                   f"natural verdict: {r['verdict_b']})")
    # status
    st = collections.Counter((status_kind(r["status_a"]), status_kind(r["status_b"])) for r in rows)
    out.append("\n| standard status | natural status | positions |\n|---|---|---|")
    for (a, b), k in st.most_common():
        out.append(f"| {a} | {b} | {k} ({pct(k, n)}) |")
    # verdicts
    if rows and rows[0]["verdict_a"]:
        vt = collections.Counter((result_of(r["verdict_a"]), result_of(r["verdict_b"])) for r in rows)
        out.append("\n| standard verdict | natural verdict (horizon +2) | positions |\n|---|---|---|")
        for (a, b), k in sorted(vt.items(), key=lambda x: -x[1]):
            out.append(f"| {a or '-'} | {b or '-'} | {k} ({pct(k, n)}) |")
        disagree = [r for r in rows if result_of(r["verdict_a"]) != result_of(r["verdict_b"])]
        both_known = [r for r in disagree if "?" not in (result_of(r["verdict_a"]), result_of(r["verdict_b"]))]
        out.append(f"\n* verdicts disagree: **{len(disagree)}** ({pct(len(disagree), n)}), "
                   f"of which both known: **{len(both_known)}**")
        kinds = collections.Counter((r["verdict_a"].split(":")[0] + " " + r["verdict_a"].split(":", 1)[1].rstrip("0123456789"),
                                     r["verdict_b"].split(":")[0] + " " + r["verdict_b"].split(":", 1)[1].rstrip("0123456789"))
                                    for r in disagree)
        for (a, b), k in kinds.most_common(12):
            out.append(f"    * standard `{a}` vs natural `{b}`: {k}")
        for r in disagree[:6]:
            out.append(f"    * e.g. `{r['fen']}`: standard {r['verdict_a']}, natural {r['verdict_b']}")
    out.append("")


def main():
    out_path = sys.argv[1]
    out = ["# Standard vs natural chess: comparison of positions\n"]
    for arg in sys.argv[2:]:
        name, paths = arg.split("=", 1)
        path, _, attrib = paths.partition(":")
        rows = load(path)
        if attrib:
            moves = {r["fen"]: r for r in load(attrib)}
            for r in rows:
                m = moves[r["fen"]]
                for k in r:
                    if k not in ("verdict_a", "verdict_b"):
                        r[k] = m[k]
        summarize(name, rows, out)
    open(out_path, "w").write("\n".join(out) + "\n")
    print("\n".join(out))


if __name__ == "__main__":
    main()
