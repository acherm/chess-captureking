#!/bin/sh
# Perft of the reference positions under several rule sets (Markdown table).
#   standard               FIDE chess
#   standard-free-castling FIDE chess without the castling conditions on attacked squares
#   natural-nosuicide      natural chess plus "no self-check" (= standard-free-castling, except endings)
#   natural-fide-castling  natural chess keeping the FIDE castling conditions
#   natural                natural chess
# Usage: scripts/perft_tables.sh CHESS_BINARY
B=${1:-./.lake/build/bin/chess}
RULES="standard standard-free-castling natural-nosuicide natural-fide-castling natural"
row() { # name depth fen
  printf "| %s | %s |" "$1" "$2"
  for r in $RULES; do
    n=$($B perft $r $2 $3 | cut -f1)
    printf " %s |" "$n"
  done
  printf "\n"
}
printf "| position | depth |"; for r in $RULES; do printf " %s |" "$r"; done; printf "\n"
printf "|---|---|"; for r in $RULES; do printf "%s" "---|"; done; printf "\n"
for d in 1 2 3 4 5; do row initial $d "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"; done
for d in 1 2 3 4; do row kiwipete $d "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"; done
for d in 1 2 3 4 5; do row pos3 $d "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"; done
for d in 1 2 3 4; do row pos4 $d "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1"; done
for d in 1 2 3 4; do row pos5 $d "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8"; done
for d in 1 2 3 4; do row pos6 $d "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10"; done
