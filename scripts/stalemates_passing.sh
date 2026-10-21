#!/bin/sh
# The 1,956 real stalemates of data/positions/stalemate.fen under standard chess with passing and
# lose-your-turn chess: exact values for the positions with 3 pieces, bounded search for the
# others (horizon 8, then deeper on what is still undecided).
# Writes results/stalemates_passing.tsv and results/stalemates_passing_summary.md.
# usage: scripts/stalemates_passing.sh [DEEPER_HORIZONS...]   (default: 10)
set -e
B=.lake/build/bin/chess
T=$(mktemp -d)
cut -f1 data/positions/stalemate.fen | awk '{b=$1; if (gsub(/[A-Za-z]/, "", b) <= 3) print}' > $T/small.fen
cut -f1 data/positions/stalemate.fen | awk '{b=$1; if (gsub(/[A-Za-z]/, "", b) > 3) print}' > $T/big.fen
args=""
for r in standard-passing standard-lose-turn; do
  $B exact-batch $r < $T/small.fen > $T/$r.exact
  $B solve-batch $r 8 < $T/big.fen > $T/$r.8
  files=$T/$r.exact,$T/$r.8
  prev=$T/$r.8
  for h in ${@:-10}; do
    grep 'unknown' $prev | cut -f1 > $T/$r.unknown || true
    $B solve-batch $r $h < $T/$r.unknown > $T/$r.$h
    files=$files,$T/$r.$h
    prev=$T/$r.$h
  done
  args="$args $r=$files"
done
python3 -I scripts/summarize_stalemates.py data/positions/stalemate.fen results/stalemates_passing.tsv \
  $args > results/stalemates_passing_summary.md
rm -r $T
