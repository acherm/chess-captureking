#!/usr/bin/env python3
"""Print the rule-by-variant matrices of VARIABILITY.md (run with `python3 -I`).

For each rule set given on the command line, `chess rules RULE_SET` lists its rules by kind.
The matrices have one row per rule and one column per rule set: ● when the rule is present,
and for endings the rule's priority (1 = tried first). Movement rules and claims common to all
the rule sets are listed in one sentence instead of rows.

Usage: variability_matrix.py CHESS_BINARY SHORT=RULE_SET [SHORT=RULE_SET ...]
  e.g. variability_matrix.py .lake/build/bin/chess std=standard nat=natural
"""
import subprocess
import sys

SECTIONS = {"Movement": "movement", "Legality": "legality",
            "Endings (first applicable rule decides)": "endings", "Draw claims": "claims",
            "Validity of positions": "validity", "Fallback moves (when no move is legal)": "fallback"}


def rules_of(binary, name):
    out = subprocess.run([binary, "rules", name], capture_output=True, text=True, check=True).stdout
    kinds = {k: [] for k in SECTIONS.values()}
    current = None
    for line in out.splitlines():
        if line.rstrip(":") in SECTIONS:
            current = SECTIONS[line.rstrip(":")]
        elif line.startswith("  - ") and current:
            kinds[current].append(line[4:].split(":", 1)[0])
    return kinds


def table(title, kind, columns, rules, ranked=False):
    names = []
    for _, r in columns:
        for n in rules[r][kind]:
            if n not in names:
                names.append(n)
    print(f"**{title}**\n")
    print("| rule | " + " | ".join(short for short, _ in columns) + " |")
    print("|---|" + "---|" * len(columns))
    for n in names:
        cells = []
        for _, r in columns:
            present = rules[r][kind]
            cells.append(str(present.index(n) + 1) if ranked and n in present
                         else ("●" if n in present else ""))
        print(f"| `{n}` | " + " | ".join(cells) + " |")
    print()


def main(binary, specs):
    columns = [tuple(s.split("=", 1)) for s in specs]
    rules = {r: rules_of(binary, r) for _, r in columns}
    common_moves = set.intersection(*(set(rules[r]["movement"]) for _, r in columns))
    common_claims = set.intersection(*(set(rules[r]["claims"]) for _, r in columns))
    first = rules[columns[0][1]]
    print("Common to all: movement " + ", ".join(m for m in first["movement"] if m in common_moves)
          + "; claims " + ", ".join(c for c in first["claims"] if c in common_claims) + ".\n")
    extra_moves = [m for _, r in columns for m in rules[r]["movement"] if m not in common_moves]
    if extra_moves:
        table("Extra movement rules", "movement",
              columns, {r: {"movement": [m for m in rules[r]["movement"] if m not in common_moves]}
                        for _, r in columns})
    table("Legality", "legality", columns, rules)
    table("Endings (priority order)", "endings", columns, rules, ranked=True)
    table("Validity", "validity", columns, rules)
    if any(rules[r]["fallback"] for _, r in columns):
        table("Fallback", "fallback", columns, rules)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
