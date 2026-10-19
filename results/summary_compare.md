# Standard vs natural chess: comparison of positions

### lichess-random

* positions: **20000** (side to move in check: 1259, 6.29%)
* legal move sets differ: **6155** (30.77%); standard-only moves: 0; natural-only moves: 46406 (mean 2.32 per position, standard mean 30.66 legal moves)
* standard rules forbidding the natural-only moves (a move may be forbidden by several): `noSelfCheck` 46220, `castlingNotOutOfCheck` 103, `castlingNotThroughCheck` 196, `noKingCapture` 0
* positions where natural chess has extra **safe** moves (the mover's king is not attacked afterwards): **175** (0.88%)
    * `r3nrk1/ppp2ppp/8/2qp2P1/4p1bP/P1P1P3/1PQB1P2/R3KB1R w KQ - 0 18`: e1c1 (standard status: ongoing, natural verdict: ?:unknown)
    * `rn2k2r/1p3ppp/3qpn2/p2p4/Q1PNbP2/P3P2P/1P1N2P1/R3KB1R b KQkq - 2 12`: e8g8 (standard status: ongoing, natural verdict: ?:unknown)
    * `r3k2r/pppq1p2/2np1B1p/2b1p3/4P3/1P1P1N1P/1PP2PP1/R2QK2R b KQkq - 0 13`: e8c8 (standard status: ongoing, natural verdict: ?:unknown)
    * `rnb1k2r/pp2qpb1/3pp1pp/1BpP4/4P3/2N2N1P/PPP2PP1/R2QK2R b KQkq - 1 9`: e8g8 (standard status: ongoing, natural verdict: ?:unknown)
    * `rn2k1nr/pbpp1ppp/1p6/3P4/8/2BB4/PPP1qPPP/R3K1NR w KQkq - 0 10`: e1c1 (standard status: ongoing, natural verdict: ?:unknown)
    * `1k1r3r/ppp5/2n1q3/4p3/3pP1pb/P7/1PPBQ1B1/R3K1R1 w Q - 2 24`: e1c1 (standard status: ongoing, natural verdict: ?:unknown)
    * `5rk1/2p1np1p/1p1pp1p1/q7/r1P5/3PP3/3NBPbP/1R1QK2R w K - 0 19`: e1g1 (standard status: ongoing, natural verdict: ?:unknown)
    * `r1bqk2r/ppp2ppp/2B2n2/3p4/1b6/2N1P3/PPP2PPP/R1BQK1NR b KQkq - 0 7`: e8g8 (standard status: ongoing, natural verdict: ?:unknown)

| standard status | natural status | positions |
|---|---|---|
| ongoing | ongoing | 19912 (99.56%) |
| 1-0 (checkmate) | ongoing | 51 (0.26%) |
| 0-1 (checkmate) | ongoing | 37 (0.18%) |

| standard verdict | natural verdict (horizon +2) | positions |
|---|---|---|
| ? | ? | 19625 (98.12%) |
| 1-0 | 1-0 | 201 (1.00%) |
| 0-1 | 0-1 | 160 (0.80%) |
| ? | 1-0 | 7 (0.04%) |
| ? | 0-1 | 6 (0.03%) |
| 0-1 | ? | 1 (0.01%) |

* verdicts disagree: **14** (0.07%), of which both known: **0**
    * standard `? unknown` vs natural `1-0 win`: 6
    * standard `? unknown` vs natural `0-1 win`: 4
    * standard `? unknown` vs natural `0-1 loss`: 2
    * standard `0-1 win` vs natural `? unknown`: 1
    * standard `? unknown` vs natural `1-0 loss`: 1
    * e.g. `2k2r2/ppp3pp/5n2/4n1B1/3Np1b1/1P6/P1q2QPP/R3K2R b KQ - 1 19`: standard 0-1:win3, natural ?:unknown
    * e.g. `8/8/1k6/5Q2/4Q3/1P2P3/PB6/5RK1 w - - 3 48`: standard ?:unknown, natural 1-0:win5
    * e.g. `8/P1P4k/5Q2/8/6P1/3P1P2/1P3K2/8 w - - 1 62`: standard ?:unknown, natural 1-0:win3
    * e.g. `8/4k1K1/8/7q/8/8/8/8 b - - 21 66`: standard ?:unknown, natural 0-1:win5
    * e.g. `8/8/5n2/4p3/4b3/4k3/7K/2q3q1 w - - 0 63`: standard ?:unknown, natural 0-1:loss4
    * e.g. `8/6p1/4p3/3p2k1/2q5/8/8/K7 b - - 5 45`: standard ?:unknown, natural 0-1:win3

### lichess-check

* positions: **63899** (side to move in check: 63899, 100.00%)
* legal move sets differ: **63895** (99.99%); standard-only moves: 0; natural-only moves: 1837498 (mean 28.76 per position, standard mean 3.42 legal moves)
* standard rules forbidding the natural-only moves (a move may be forbidden by several): `noSelfCheck` 1832207, `castlingNotOutOfCheck` 6628, `castlingNotThroughCheck` 1721, `noKingCapture` 0
* positions where natural chess has extra **safe** moves (the mover's king is not attacked afterwards): **4742** (7.42%)
    * `r3kb1r/pp1nnppp/3B4/q1Pb4/8/5N2/PPP1QPPP/R3KB1R w KQkq - 2 12`: e1c1 (standard status: ongoing, natural verdict: ?:unknown)
    * `1r2k2r/p2Qbp1p/6p1/2P5/8/2P5/qP3PPP/3RKB1R b Kk - 0 17`: e8g8 (standard status: ongoing, natural verdict: ?:unknown)
    * `r2q1rk1/ppp2pb1/3p1np1/7p/2P1P1bP/P1Nn1N2/1PB2PP1/R1B1K2R w KQ - 0 12`: e1g1 (standard status: ongoing, natural verdict: ?:unknown)
    * `r3kbnr/pp3ppp/2B5/4pb2/4N3/5N2/PP3PPP/R1B1K2R b KQkq - 0 11`: e8c8 (standard status: ongoing, natural verdict: ?:unknown)
    * `r3k2r/pb3ppp/5q2/1B1pp3/8/2Q5/PPP2PPP/R3K2R b KQkq - 1 13`: e8g8 (standard status: ongoing, natural verdict: ?:unknown)
    * `r2qk2r/pppB1p2/3p1p1p/2bNn3/4P3/5N2/PP3PPP/2RQ1RK1 b kq - 0 12`: e8g8 (standard status: ongoing, natural verdict: ?:unknown)
    * `r2bk2r/pp3pq1/2pNb3/8/1P1P1P2/5BP1/P4P1p/R2Q1R1K b kq - 2 23`: e8g8 (standard status: ongoing, natural verdict: ?:unknown)
    * `r1b1k2r/ppp2ppp/3p1q2/4b3/Q1N1P1n1/2P2N2/PP3PPP/R3KB1R b KQkq - 2 10`: e8g8 (standard status: ongoing, natural verdict: ?:unknown)

| standard status | natural status | positions |
|---|---|---|
| ongoing | ongoing | 61282 (95.90%) |
| 1-0 (checkmate) | ongoing | 1495 (2.34%) |
| 0-1 (checkmate) | ongoing | 1121 (1.75%) |
| 1/2-1/2 (deadPosition) | ongoing | 1 (0.00%) |

| standard verdict | natural verdict (horizon +2) | positions |
|---|---|---|
| ? | ? | 59928 (93.79%) |
| 1-0 | 1-0 | 2202 (3.45%) |
| 0-1 | 0-1 | 1709 (2.67%) |
| 1-0 | ? | 22 (0.03%) |
| 0-1 | ? | 15 (0.02%) |
| ? | 0-1 | 13 (0.02%) |
| ? | 1-0 | 9 (0.01%) |
| 1/2-1/2 | ? | 1 (0.00%) |

* verdicts disagree: **60** (0.09%), of which both known: **0**
    * standard `1-0 checkmate` vs natural `? unknown`: 15
    * standard `? unknown` vs natural `0-1 loss`: 13
    * standard `0-1 checkmate` vs natural `? unknown`: 11
    * standard `1-0 loss` vs natural `? unknown`: 7
    * standard `? unknown` vs natural `1-0 loss`: 6
    * standard `0-1 loss` vs natural `? unknown`: 4
    * standard `? unknown` vs natural `1-0 win`: 3
    * standard `1/2-1/2 deadPosition` vs natural `? unknown`: 1
    * e.g. `r3kb1r/pppb1ppp/8/8/3Qn3/N1P2p2/P2Bq1PP/R3K2R w KQkq - 0 14`: standard 0-1:checkmate, natural ?:unknown
    * e.g. `7k/2p3p1/1p1p2p1/pP1Pp3/P3P3/6K1/3q2r1/8 w - - 0 34`: standard ?:unknown, natural 0-1:loss4
    * e.g. `2k2r2/ppp3pp/5n2/6B1/3Np1b1/1P1n4/P1q2QPP/R3K2R w KQ - 2 20`: standard 0-1:loss2, natural ?:unknown
    * e.g. `8/8/p7/P2p1p2/2p5/2Pn1q2/4k1K1/8 w - - 4 57`: standard ?:unknown, natural 0-1:loss4
    * e.g. `r3k2r/p1p2ppp/b2bp3/8/3p2P1/2P1qP1N/PP5P/R2QK2R w KQkq - 0 15`: standard 0-1:loss2, natural ?:unknown
    * e.g. `r1qnk2r/ppp1Rpp1/6Np/3P4/6P1/2P5/PP3P1P/R1BQ2K1 b kq - 0 17`: standard 1-0:checkmate, natural ?:unknown

### lichess-mate

* positions: **72691** (side to move in check: 72691, 100.00%)
* legal move sets differ: **72691** (100.00%); standard-only moves: 0; natural-only moves: 1796687 (mean 24.72 per position, standard mean 0.00 legal moves)
* standard rules forbidding the natural-only moves (a move may be forbidden by several): `noSelfCheck` 1796102, `castlingNotOutOfCheck` 1156, `castlingNotThroughCheck` 1032, `noKingCapture` 0
* positions where natural chess has extra **safe** moves (the mover's king is not attacked afterwards): **508** (0.70%)
    * `4r1k1/p1pQ1ppp/b1p3P1/8/PP4P1/5N2/4q2P/1N2K2R w K - 0 19`: e1g1 (standard status: 0-1:checkmate, natural verdict: ?:unknown)
    * `rn2k1nr/pp3pp1/4p3/2bpP2b/5P2/1NP1B2Q/P3q1BP/RN2K2R w KQkq - 2 15`: e1g1 (standard status: 0-1:checkmate, natural verdict: ?:unknown)
    * `3rk2r/4Qp2/4pPp1/3bq1Pp/3R4/Pp6/1P5P/1KBR4 b k - 2 29`: e8g8 (standard status: 1-0:checkmate, natural verdict: ?:unknown)
    * `r3k1r1/ppp1Q2p/1b3p2/3q4/3P1B2/2P5/P1P2PPP/R3R1K1 b q - 0 19`: e8c8 (standard status: 1-0:checkmate, natural verdict: ?:unknown)
    * `2Q1k2r/pp2pp1p/5bp1/1q6/8/5P2/Pp4PP/R3R1K1 b k - 0 24`: e8g8 (standard status: 1-0:checkmate, natural verdict: ?:unknown)
    * `r3kQ2/pp1q3p/2p5/4P3/4P2b/6P1/P1P3KP/3R1R2 b q - 0 24`: e8c8 (standard status: 1-0:checkmate, natural verdict: ?:unknown)
    * `r3k2r/ppqnQp2/2p3p1/7p/2BP4/2N2b2/PPP2KP1/R3R3 b kq - 0 18`: e8g8 e8c8 (standard status: 1-0:checkmate, natural verdict: ?:unknown)
    * `4k2r/p3Qpb1/1pq3b1/2p5/5B2/P2r2P1/1PP4P/4RRK1 b k - 0 31`: e8g8 (standard status: 1-0:checkmate, natural verdict: ?:unknown)

| standard status | natural status | positions |
|---|---|---|
| 1-0 (checkmate) | ongoing | 38792 (53.37%) |
| 0-1 (checkmate) | ongoing | 33899 (46.63%) |

| standard verdict | natural verdict (horizon +2) | positions |
|---|---|---|
| 1-0 | 1-0 | 38495 (52.96%) |
| 0-1 | 0-1 | 33688 (46.34%) |
| 1-0 | ? | 297 (0.41%) |
| 0-1 | ? | 211 (0.29%) |

* verdicts disagree: **508** (0.70%), of which both known: **0**
    * standard `1-0 checkmate` vs natural `? unknown`: 297
    * standard `0-1 checkmate` vs natural `? unknown`: 211
    * e.g. `4r1k1/p1pQ1ppp/b1p3P1/8/PP4P1/5N2/4q2P/1N2K2R w K - 0 19`: standard 0-1:checkmate, natural ?:unknown
    * e.g. `rn2k1nr/pp3pp1/4p3/2bpP2b/5P2/1NP1B2Q/P3q1BP/RN2K2R w KQkq - 2 15`: standard 0-1:checkmate, natural ?:unknown
    * e.g. `3rk2r/4Qp2/4pPp1/3bq1Pp/3R4/Pp6/1P5P/1KBR4 b k - 2 29`: standard 1-0:checkmate, natural ?:unknown
    * e.g. `r3k1r1/ppp1Q2p/1b3p2/3q4/3P1B2/2P5/P1P2PPP/R3R1K1 b q - 0 19`: standard 1-0:checkmate, natural ?:unknown
    * e.g. `2Q1k2r/pp2pp1p/5bp1/1q6/8/5P2/Pp4PP/R3R1K1 b k - 0 24`: standard 1-0:checkmate, natural ?:unknown
    * e.g. `r3kQ2/pp1q3p/2p5/4P3/4P2b/6P1/P1P3KP/3R1R2 b q - 0 24`: standard 1-0:checkmate, natural ?:unknown

### lichess-stalemate

* positions: **1956** (side to move in check: 0, 0.00%)
* legal move sets differ: **1956** (100.00%); standard-only moves: 0; natural-only moves: 9427 (mean 4.82 per position, standard mean 0.00 legal moves)
* standard rules forbidding the natural-only moves (a move may be forbidden by several): `noSelfCheck` 9427, `castlingNotOutOfCheck` 0, `castlingNotThroughCheck` 0, `noKingCapture` 0
* positions where natural chess has extra **safe** moves (the mover's king is not attacked afterwards): **0** (0.00%)

| standard status | natural status | positions |
|---|---|---|
| 1/2-1/2 (stalemate) | ongoing | 1956 (100.00%) |

| standard verdict | natural verdict (horizon +2) | positions |
|---|---|---|
| 1/2-1/2 | 0-1 | 979 (50.05%) |
| 1/2-1/2 | 1-0 | 977 (49.95%) |

* verdicts disagree: **1956** (100.00%), of which both known: **1956**
    * standard `1/2-1/2 stalemate` vs natural `0-1 loss`: 979
    * standard `1/2-1/2 stalemate` vs natural `1-0 loss`: 977
    * e.g. `1r6/8/4k3/2Kbb3/8/8/8/8 w - - 25 82`: standard 1/2-1/2:stalemate, natural 0-1:loss2
    * e.g. `r7/8/p1bbk2n/3p4/1Pp5/K7/P4r2/8 w - - 0 44`: standard 1/2-1/2:stalemate, natural 0-1:loss2
    * e.g. `7k/7B/6K1/7P/8/8/8/8 b - - 12 65`: standard 1/2-1/2:stalemate, natural 1-0:loss2
    * e.g. `7k/5Q2/4R1P1/8/P4P2/1P6/8/2K5 b - - 2 46`: standard 1/2-1/2:stalemate, natural 1-0:loss2
    * e.g. `7k/7P/7K/8/8/8/8/8 b - - 2 72`: standard 1/2-1/2:stalemate, natural 1-0:loss2
    * e.g. `6k1/6P1/6K1/8/8/8/8/8 b - - 2 85`: standard 1/2-1/2:stalemate, natural 1-0:loss2

### lichess-insufficient

* positions: **1711** (side to move in check: 44, 2.57%)
* legal move sets differ: **986** (57.63%); standard-only moves: 0; natural-only moves: 2338 (mean 1.37 per position, standard mean 6.49 legal moves)
* standard rules forbidding the natural-only moves (a move may be forbidden by several): `noSelfCheck` 2338, `castlingNotOutOfCheck` 0, `castlingNotThroughCheck` 0, `noKingCapture` 0
* positions where natural chess has extra **safe** moves (the mover's king is not attacked afterwards): **0** (0.00%)

| standard status | natural status | positions |
|---|---|---|
| 1/2-1/2 (deadPosition) | ongoing | 1707 (99.77%) |
| 1/2-1/2 (stalemate) | ongoing | 4 (0.23%) |

| standard verdict | natural verdict (horizon +2) | positions |
|---|---|---|
| 1/2-1/2 | ? | 1706 (99.71%) |
| 1/2-1/2 | 0-1 | 4 (0.23%) |
| 1/2-1/2 | 1-0 | 1 (0.06%) |

* verdicts disagree: **1711** (100.00%), of which both known: **5**
    * standard `1/2-1/2 deadPosition` vs natural `? unknown`: 1706
    * standard `1/2-1/2 stalemate` vs natural `0-1 loss`: 3
    * standard `1/2-1/2 stalemate` vs natural `1-0 loss`: 1
    * standard `1/2-1/2 deadPosition` vs natural `0-1 win`: 1
    * e.g. `8/1K6/8/1k6/8/8/8/8 w - - 0 52`: standard 1/2-1/2:deadPosition, natural ?:unknown
    * e.g. `8/8/8/8/K7/7k/8/8 w - - 0 80`: standard 1/2-1/2:deadPosition, natural ?:unknown
    * e.g. `8/8/8/8/4K3/8/k7/8 w - - 0 77`: standard 1/2-1/2:deadPosition, natural ?:unknown
    * e.g. `3K4/8/7k/6n1/8/8/8/8 w - - 0 65`: standard 1/2-1/2:deadPosition, natural ?:unknown
    * e.g. `4b3/8/8/8/8/K1k5/8/8 w - - 0 58`: standard 1/2-1/2:deadPosition, natural ?:unknown
    * e.g. `8/8/4k3/8/3K4/8/8/8 b - - 0 101`: standard 1/2-1/2:deadPosition, natural ?:unknown

### random-placement

* positions: **20000** (side to move in check: 6223, 31.11%)
* legal move sets differ: **13995** (69.97%); standard-only moves: 0; natural-only moves: 175731 (mean 8.79 per position, standard mean 14.84 legal moves)
* standard rules forbidding the natural-only moves (a move may be forbidden by several): `noSelfCheck` 175730, `castlingNotOutOfCheck` 0, `castlingNotThroughCheck` 1, `noKingCapture` 0
* positions where natural chess has extra **safe** moves (the mover's king is not attacked afterwards): **1** (0.01%)
    * `r3k3/2P5/8/3P4/8/7K/2B4P/B7 b q - 0 1`: e8c8 (standard status: ongoing, natural verdict: ?:unknown)

| standard status | natural status | positions |
|---|---|---|
| ongoing | ongoing | 16495 (82.47%) |
| 1/2-1/2 (deadPosition) | ongoing | 3149 (15.74%) |
| 0-1 (checkmate) | ongoing | 187 (0.94%) |
| 1-0 (checkmate) | ongoing | 155 (0.78%) |
| 1/2-1/2 (stalemate) | ongoing | 14 (0.07%) |

| standard verdict | natural verdict (horizon +2) | positions |
|---|---|---|
| ? | ? | 14636 (73.18%) |
| 1/2-1/2 | ? | 3147 (15.73%) |
| 0-1 | 0-1 | 1070 (5.35%) |
| 1-0 | 1-0 | 955 (4.78%) |
| ? | 1-0 | 90 (0.45%) |
| ? | 0-1 | 86 (0.43%) |
| 1/2-1/2 | 1-0 | 9 (0.04%) |
| 1/2-1/2 | 0-1 | 7 (0.04%) |

* verdicts disagree: **3339** (16.70%), of which both known: **16**
    * standard `1/2-1/2 deadPosition` vs natural `? unknown`: 3147
    * standard `? unknown` vs natural `1-0 win`: 64
    * standard `? unknown` vs natural `0-1 win`: 58
    * standard `? unknown` vs natural `0-1 loss`: 28
    * standard `? unknown` vs natural `1-0 loss`: 26
    * standard `1/2-1/2 stalemate` vs natural `1-0 loss`: 9
    * standard `1/2-1/2 stalemate` vs natural `0-1 loss`: 5
    * standard `1/2-1/2 deadPosition` vs natural `0-1 win`: 2
    * e.g. `k7/8/8/5K2/8/3N4/8/8 b - - 0 1`: standard 1/2-1/2:deadPosition, natural ?:unknown
    * e.g. `8/1k6/6K1/8/8/8/8/8 b - - 0 1`: standard 1/2-1/2:deadPosition, natural ?:unknown
    * e.g. `3n4/8/5K2/8/8/8/5k2/8 b - - 0 1`: standard 1/2-1/2:deadPosition, natural ?:unknown
    * e.g. `8/1k6/8/8/7K/8/3N4/8 w - - 0 1`: standard 1/2-1/2:deadPosition, natural ?:unknown
    * e.g. `7k/8/6K1/8/8/8/7b/8 b - - 0 1`: standard 1/2-1/2:deadPosition, natural ?:unknown
    * e.g. `8/7K/2k5/8/8/8/8/8 w - - 0 1`: standard 1/2-1/2:deadPosition, natural ?:unknown

### random-playout

* positions: **20000** (side to move in check: 1949, 9.74%)
* legal move sets differ: **13381** (66.91%); standard-only moves: 0; natural-only moves: 81496 (mean 4.07 per position, standard mean 26.39 legal moves)
* standard rules forbidding the natural-only moves (a move may be forbidden by several): `noSelfCheck` 81456, `castlingNotOutOfCheck` 11, `castlingNotThroughCheck` 67, `noKingCapture` 0
* positions where natural chess has extra **safe** moves (the mover's king is not attacked afterwards): **39** (0.20%)
    * `1nbqkb1r/1ppppppp/1P6/5Pr1/p6P/N1PBP1n1/PB1P2P1/2RQK2R w K - 0 16`: e1g1 (standard status: ongoing, natural verdict: ?:unknown)
    * `r3kN2/4B3/pnp1p3/1b2P2P/3q1p2/PP6/2PB3P/RN1KQBr1 b q - 3 37`: e8c8 (standard status: ongoing, natural verdict: ?:unknown)
    * `1r2k1nr/1p3ppp/n3q3/p1ppp1N1/1b1P1PP1/4BB1b/PPPNP2P/1R1QK2R w Kk - 4 14`: e1g1 (standard status: ongoing, natural verdict: ?:unknown)
    * `r3kb1r/q3B2n/1p2np2/p2p4/2PN4/NP3P2/P2PP1BK/R1Q5 b q - 1 25`: e8c8 (standard status: ongoing, natural verdict: ?:unknown)
    * `r1bqk2r/pppp3p/2n5/P3pp2/1BP2pn1/b2P2P1/3NP1B1/3QK1NR b Kkq - 3 16`: e8g8 (standard status: ongoing, natural verdict: ?:unknown)
    * `rnb2b1r/pp1ppk1p/1N3pp1/8/P1n4P/2Pp1PPB/1PQNq3/R3K2R w KQ - 0 15`: e1g1 e1c1 (standard status: 0-1:checkmate, natural verdict: ?:unknown)
    * `2rqk2r/2B1n2p/p2b2PQ/1p1Pp3/2p3P1/7P/PPP1BP1R/R3K3 b Qk - 0 24`: e8g8 (standard status: ongoing, natural verdict: ?:unknown)
    * `rnbqk2r/p1p3pp/1p5n/3pp3/1BP2p1P/bP4P1/P2PPPB1/RQ2K1NR b Qkq - 1 13`: e8g8 (standard status: ongoing, natural verdict: ?:unknown)

| standard status | natural status | positions |
|---|---|---|
| ongoing | ongoing | 19156 (95.78%) |
| 0-1 (checkmate) | ongoing | 421 (2.10%) |
| 1-0 (checkmate) | ongoing | 392 (1.96%) |
| 1/2-1/2 (stalemate) | ongoing | 28 (0.14%) |
| 1/2-1/2 (deadPosition) | ongoing | 3 (0.01%) |

| standard verdict | natural verdict (horizon +2) | positions |
|---|---|---|
| ? | ? | 18469 (92.34%) |
| 0-1 | 0-1 | 754 (3.77%) |
| 1-0 | 1-0 | 718 (3.59%) |
| 1/2-1/2 | 0-1 | 15 (0.07%) |
| ? | 0-1 | 15 (0.07%) |
| 1/2-1/2 | 1-0 | 13 (0.07%) |
| ? | 1-0 | 12 (0.06%) |
| 1/2-1/2 | ? | 3 (0.01%) |
| 0-1 | ? | 1 (0.01%) |

* verdicts disagree: **59** (0.29%), of which both known: **28**
    * standard `1/2-1/2 stalemate` vs natural `0-1 loss`: 15
    * standard `1/2-1/2 stalemate` vs natural `1-0 loss`: 13
    * standard `? unknown` vs natural `0-1 win`: 12
    * standard `? unknown` vs natural `1-0 win`: 11
    * standard `1/2-1/2 deadPosition` vs natural `? unknown`: 3
    * standard `? unknown` vs natural `0-1 loss`: 3
    * standard `? unknown` vs natural `1-0 loss`: 1
    * standard `0-1 checkmate` vs natural `? unknown`: 1
    * e.g. `5br1/1q2p1p1/6p1/2p3Pk/2p2K2/2p5/8/4q3 w - - 1 55`: standard 1/2-1/2:stalemate, natural 0-1:loss2
    * e.g. `1n4k1/8/8/8/5K2/8/8/8 w - - 15 94`: standard 1/2-1/2:deadPosition, natural ?:unknown
    * e.g. `5b2/8/2P4P/PR1p3B/3R4/2k1P3/8/6K1 w - - 3 79`: standard ?:unknown, natural 1-0:win5
    * e.g. `3k4/1R6/3N3p/7P/8/2NK1R2/r7/8 b - - 7 75`: standard ?:unknown, natural 1-0:loss4
    * e.g. `kR1r4/8/K7/P7/P3p3/8/8/8 b - - 15 100`: standard ?:unknown, natural 0-1:win3
    * e.g. `3nr1k1/8/5p2/2p2P2/3R1P2/r4n2/8/7K b - - 7 79`: standard ?:unknown, natural 0-1:win5

