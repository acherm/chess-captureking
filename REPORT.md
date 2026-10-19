# Natural chess is not standard chess: a Lean 4 formalization

*Natural chess* (J. D. Hamkins, [*Every game of chess ends prematurely*](https://www.infinitelymore.xyz/p/chess-games-end-one-move-early))
keeps the pieces and their moves but "abandons the rules about check and checkmate, adopting
instead the goal of capturing the opposing king". Hamkins shows that it is "almost equivalent to
standard chess" but "not quite fully equivalent", with one position of each of three kinds:
(1) standard wins where the king cannot be captured in natural chess (a checkmate that leaves the
mated player without any move), (2) standard draws that are natural wins (a stalemate, suggested by
David Madore), (3) immediate standard wins that are natural losses (a checkmate escaped by
castling out of and through check).

This report formalizes both games with two Lean engines that share all their code except a
nine-line delta, machine-checks Hamkins' positions (§3.4), measures how often and how much the
games differ, explains the difference exactly (§3.6), and reports every interpretation choice
that the formalization forced (§4). The comparison of Hamkins' further variations (normal play,
passing, lose-your-turn) is in [GRID_VARIANTS.md](GRID_VARIANTS.md).

*Note.* The first version of this report was written from the free preview of the essay, which
announces the three kinds but shows none of the positions. Hamkins' positions, and his arguments
on castling and stalemate, are now credited where they apply.

## Summary

* **Engine (step 1).** Standard chess is a rule set of named, FIDE-referenced rules, built in an
  explicitly modular way. Perft matches the reference tables on the six classic positions, up to
  depth 6 for the initial position (119,060,324), and so do all the detailed counters (captures,
  e.p., castles, promotions, checks, discovered and double checks, mates). Against python-chess,
  there are 0 mismatches over 160,257 Lichess positions (legal moves, SAN, check, game status) and
  20,000 complete games.
* **Natural chess (step 2)** is a delta on standard chess: remove 4 legality rules and 3 ending
  rules, add 1 legality rule and 2 ending rules. It is cross-checked against an independent Python
  reference. One general fact is proved in Lean for *every* position: **every standard legal move is
  a natural legal move**. Natural legal moves are exactly the pseudo-legal moves while both kings
  stand.
* **Your step-2 expectation holds only partly.** Perft at depths 0–2 coincides for the initial
  position (in fact up to depth 3), but not for the other reference positions. They diverge already
  at depth 1 (positions 3 and 4) or depth 2 (Kiwipete, 5, 6). Every extra node is explained by the
  standard rule that forbids it.
* **Perft differs** from the initial position at depth 4: 197,742 vs 197,281. All 461 extra
  sequences come from 134 positions after 3 plies (e.g. 1. c3 d6 2. Qa4+, where Black has 21 extra
  moves). The difference decomposes exactly over these divergence points (depth 5: 16,733 + 14,914 = 31,647).
* **Non-equivalence**: Hamkins' three positions are machine-checked (§3.4), and each kind also
  occurs in real games or in smaller constructed positions:
  * (1) **508 of 72,691 real Lichess checkmates (0.70%)** are not checkmates in natural chess: the
    mated player castles out of check to safety. In 448 of them the castler is still not lost within
    7 plies. Example: Lichess RSJfq4Su, 9... Qxe2# 0-1, where 10. O-O escapes. A mate in 2 of
    standard chess also fails in natural chess (Lichess t82cDrIb). And a hand-built mate in which the
    mated player has no move at all is a natural draw.
  * (2) **All 1,956 real stalemates** are natural losses for the stalemated player (lost in 2 plies),
    e.g. the textbook KPK stalemate of Lichess NZ2sKoBF. Even K+B v K, a dead position in standard
    chess, has natural wins: 9,356 of 417,228 positions (2.2%).
  * (3) **Opposite outcomes**: positions where the side to move is checkmated in standard chess
    (lost), yet wins by force in natural chess by castling out of check. Hamkins' example has 12
    pieces; targeted search found one with 6, and an exhaustive search finds one with 5 and none
    with 4 (up to 13 plies, §3.4). None occurs among the real games examined.
* **Exact tablebases** (retrograde analysis, any rule set): no standard win or loss changes, but
  **33% of the KPK draws are decisive in natural chess**, and so are 2.2% of KBK and 0.8% of KNK positions.
* **Two "bridges"** make the result exact in both directions: `standard-naturalized` (standard
  chess + the rule part of the difference) has the values of natural chess, and
  `natural-standardized` (natural chess + castling conditions, stalemate, dead position, and draw
  rules that give way to an imminent king capture) has the values of standard chess, both up to
  the one-move shift. Both are verified on 1.9M endgame positions and 16,783 game positions, 0 exceptions.
* **What exactly differs.** Every verdict difference observed is caused by one of three rules:
  castling across attacked squares, stalemate, or dead position. That covers 7,647 positions, 4,860 of
  which are standard dead-position draws that natural chess simply plays on. A "naturalized"
  standard chess makes those three changes: castling free, no-legal-move loses unless nothing can
  move, no dead position. It has **the same values as natural chess**, exactly one move shorter:
  verified on 1.9M endgame positions and 16,783 game positions, 0 exceptions. The only other
  divergence found is a new one: the 75-move rule's checkmate precedence has no natural analogue.
* **Theorems** (`Chess/Theorems.lean`): the inclusion of legal moves (proved), and the
  non-equivalences above on concrete positions (checked by `native_decide`).

---

## 1. Step 1: a standard chess engine with modular rules

### Design

Everything rule-specific is a *named, documented value* (see `chess rules standard`):

```
Rule set 'standard'
Movement:   pawnPush (FIDE 3.7.1), pawnDoublePush (3.7.2), pawnCapture (3.7.3), enPassant (3.7.3.1-2),
            knight (3.6), bishop (3.2, 3.5), rook (3.3, 3.5), queen (3.4, 3.5), king (3.8.1), castling (3.8.2)
Legality:   noKingCapture (1.4.1), noSelfCheck (3.9.2), castlingNotOutOfCheck (3.8.2.2),
            castlingNotThroughCheck (3.8.2.2)
Endings:    checkmate (1.4, 5.1.1), stalemate (5.2.1), deadPosition (5.2.2), seventyFiveMoves (9.6.2),
            fivefoldRepetition (9.6.1)          -- first applicable rule decides (checkmate beats 75 moves)
Claims:     threefoldRepetition (9.2), fiftyMoves (9.3)
Validity:   oneKingEach, noPawnOnFirstOrLastRank, opponentNotInCheck, castlingRightsConsistent,
            enPassantConsistent
```

A move is *legal* iff it is proposed by a movement rule and forbidden by no legality rule. The game
is *over* when an ending rule applies. When a move is illegal, the engine says which rule forbids
it:

```
$ chess play standard e4 f6 Qh5 Kf7
Illegal: move 4 'Kf7' …: e8f7 is forbidden by [noSelfCheck (FIDE 3.9.2 (and 1.4.1): no piece can be
moved that will either expose the king of the same colour to check or leave that king in check.)]
```

Games are sequences of moves (UCI or SAN) with history, so repetition rules work. The code is
written for readability: a mailbox board, lists, no bitboards. The only concessions to speed are
precomputed attack tables and "staged" legality rules, which compute position-wide facts (e.g.
"am I in check?") once per position. That gives about 1M nodes/s on 16 cores; natural perft is
about 10× faster since it needs no legality test.

### Verification

| position | depths verified (nodes) | counters verified |
|---|---|---|
| initial | 1–6 (119,060,324) | all, depths 0–5 |
| Kiwipete | 1–5 (193,690,690) | all, depths 1–4 |
| position 3 | 1–6 (11,030,083) | all, depths 1–5 |
| position 4 (and mirrored) | 1–5 (15,833,292) | all published columns, depths 1–4 |
| position 5 | 1–4 (2,103,487) | — (not published) |
| position 6 | 1–4 (3,894,594) | — (not published) |

* One convention had to be reverse-engineered: a check counts as "discovered" only when the moved
  piece does not itself give check. Counting "any discovered piece" gives 48 instead of 42 for
  Kiwipete at depth 4, and 1,295 instead of 1,292 for position 3 at depth 5; the excess is exactly
  the number of double checks.
* **python-chess cross-validation** (`scripts/crossval.py`, `results/crossval.txt`): 0 mismatches on
  20,000 random positions, 63,899 positions in check, 72,691 checkmates, 1,956 stalemates and
  1,711 insufficient-material positions from Lichess (legal moves, SAN of every move, check, status).
  Also 0 mismatches on the final status of 20,000 complete games, including 4 fivefold repetitions,
  127 stalemates and 113 dead positions.
* `Tests.lean`: 60 tests (77 with `--deep`, including the tablebase bridge equivalences) on perft, counters and rule-specific situations
  (en passant exposing the king along a rank, castling through/out of/into check, 75 moves vs mate, …).

---

## 2. Step 2: natural chess as a delta

```
$ chess diff standard natural          (output condensed into columns)
- legality noKingCapture           - ending checkmate        - validity oneKingEach
- legality noSelfCheck             - ending stalemate        - validity opponentNotInCheck
- legality castlingNotOutOfCheck   - ending deadPosition     + validity atMostOneKingEach
- legality castlingNotThroughCheck + ending kingCaptured
+ legality noMoveAfterKingCapture  + ending noLegalMove
  ending rules, in order: [kingCaptured, noLegalMove, seventyFiveMoves, fivefoldRepetition]
```

No line of standard chess was modified: `Chess/Rules/Natural.lean` only *uses* `Standard.rules`.
The movement rules, the draw rules, perft, SAN, games, the solver and the tablebases are shared.
The rationale for each choice is in §4.

**Proved in Lean** (`Chess/Theorems.lean`, no `native_decide`):

```lean
theorem natural_legalMoves (pos) (h : Natural.bothKingsOnBoard pos = true) :
    Natural.rules.legalMoves pos = Natural.rules.candidates pos
theorem standard_legal_subset_natural (pos) (h : Natural.bothKingsOnBoard pos = true) (m)
    (hm : m ∈ Standard.rules.legalMoves pos) : m ∈ Natural.rules.legalMoves pos
```

**Independent check**: natural perft agrees with a Python reference on all six reference positions
(depths 1–4 for the initial position and position 3, 1–3 for the others). The reference is built
from python-chess pseudo-legal moves, with castling regenerated without the attack conditions and a
stop at king capture.

### Perft at depths 0–2 (and beyond)

Standard / natural, all counters at depths 0–2 (`chess stats standard 2 …`, `chess stats natural 2 …`).
A cell shows one value when both games agree, `std / nat` otherwise:

| position | depth | nodes | captures | e.p. | castles | promotions | checks | discovered | double | mates / king captures |
|---|---|---|---|---|---|---|---|---|---|---|
| initial | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| initial | 1 | 20 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| initial | 2 | 400 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| initial | 3 | 8,902 | 34 | 0 | 0 | 0 | 12 | 0 | 0 | 0 |
| initial | 4 | **197,281 / 197,742** | **1,576 / 1,579** | 0 | 0 | 0 | 469 | 0 | 0 | **8 / 0** |
| Kiwipete | 1 | 48 | 8 | 0 | 2 | 0 | 0 | 0 | 0 | 0 |
| Kiwipete | 2 | **2,039 / 2,049** | 351 | 1 | **91 / 96** | 0 | 3 | 0 | 0 | 0 |
| position 3 | 1 | **14 / 16** | 1 | 0 | 0 | 0 | 2 | 0 | 0 | 0 |
| position 3 | 2 | **191 / 278** | **14 / 24** | **0 / 2** | 0 | 0 | **10 / 39** | **0 / 19** | **0 / 2** | **0 / 2** |
| position 4 | 1 | **6 / 38** | **0 / 3** | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| position 4 | 2 | **264 / 1,845** | **87 / 561** | 0 | **6 / 74** | **48 / 296** | **10 / 1,510** | **0 / 1,306** | **0 / 3** | **0 / 32** |
| position 5 | 1 | 44 | 6 | 0 | 1 | 4 | 0 | 0 | 0 | 0 |
| position 5 | 2 | **1,486 / 1,552** | **222 / 224** | 0 | 0 | 0 | **117 / 123** | 0 | 0 | 0 |
| position 6 | 1 | 46 | 4 | 0 | 0 | 0 | 1 | 0 | 0 | 0 |
| position 6 | 2 | **2,079 / 2,124** | **203 / 207** | 0 | 0 | 0 | **40 / 41** | 0 | 0 | 0 |

(Depth 0 is 1 node everywhere. "Mates" are leaf positions where the game is over and the mover has
won: checkmates in standard chess, king captures in natural chess. A natural "check" may target a
king that its owner has just left en prise, which is why position 4 has 1,510 of them.)

So the expectation "same numbers at depths 0, 1, 2" is true for the initial position only, and
there up to depth 3. For the other reference positions, the two games *must* differ as soon as a
check-related rule bites within the horizon:

* **position 4**: White is in check at the root, so depth 1 already gives 38 vs 6;
* **position 3**: depth 1 gives 16 vs 14. Natural chess adds Kb6, into the c7-pawn's attack, and b6, which exposes the king on a5 to the rook on h5;
* **Kiwipete**, depth 2 (+10): 5 king moves into check, 4 castlings through check, 1 castling
  through and into check (`chess divergences standard natural 2 …`);
* **positions 5 and 6**, depth 2: only moves exposing the king (66 and 45 extra moves).

The table below isolates each rule's contribution. `natural-nosuicide` (natural + "no self-check")
and `standard-free-castling` (standard without the castling attack conditions) are built
differently but agree everywhere, which cross-checks the rule decomposition. Their difference with
`standard` is exactly the effect of castling across attacked squares.

| position | depth | standard | standard-free-castling | natural-nosuicide | natural-fide-castling | natural |
|---|---|---|---|---|---|---|
| initial | 1 | 20 | 20 | 20 | 20 | 20 |
| initial | 2 | 400 | 400 | 400 | 400 | 400 |
| initial | 3 | 8902 | 8902 | 8902 | 8902 | 8902 |
| initial | 4 | 197281 | 197281 | 197281 | 197742 | 197742 |
| initial | 5 | 4865609 | 4865609 | 4865609 | 4897256 | 4897256 |
| kiwipete | 1 | 48 | 48 | 48 | 48 | 48 |
| kiwipete | 2 | 2039 | 2043 | 2043 | 2044 | 2049 |
| kiwipete | 3 | 97862 | 98196 | 98196 | 98515 | 98903 |
| kiwipete | 4 | 4085603 | 4111156 | 4111156 | 4174750 | 4206146 |
| pos3 | 1 | 14 | 14 | 14 | 16 | 16 |
| pos3 | 2 | 191 | 191 | 191 | 278 | 278 |
| pos3 | 3 | 2812 | 2812 | 2812 | 4840 | 4840 |
| pos3 | 4 | 43238 | 43238 | 43238 | 88813 | 88813 |
| pos3 | 5 | 674624 | 674624 | 674624 | 1603830 | 1603830 |
| pos4 | 1 | 6 | 6 | 6 | 38 | 38 |
| pos4 | 2 | 264 | 264 | 264 | 1807 | 1845 |
| pos4 | 3 | 9467 | 9467 | 9467 | 70297 | 71811 |
| pos4 | 4 | 422333 | 423325 | 423325 | 3372082 | 3500218 |
| pos5 | 1 | 44 | 44 | 44 | 44 | 44 |
| pos5 | 2 | 1486 | 1486 | 1486 | 1552 | 1552 |
| pos5 | 3 | 62379 | 62478 | 62478 | 70962 | 71104 |
| pos5 | 4 | 2103487 | 2107464 | 2107464 | 2585193 | 2590828 |
| pos6 | 1 | 46 | 46 | 46 | 46 | 46 |
| pos6 | 2 | 2079 | 2079 | 2079 | 2124 | 2124 |
| pos6 | 3 | 89890 | 89890 | 89890 | 94089 | 94089 |
| pos6 | 4 | 3894594 | 3894594 | 3894594 | 4181760 | 4181760 |

---

## 3. Step 3: non-equivalence

### 3.0 What "differ" means, precisely

Two rule sets `a` (standard) and `b` (natural) are compared at five levels, each one a Lean
definition in `Chess/Analysis/Compare.lean`, `Divergence.lean`, `Solver.lean` and `Tablebase.lean`:

| level | definition | in Lean |
|---|---|---|
| legal moves | the moves legal in one game only | `onlyB := movesB.filter (!movesA.contains ·)`, with `movesA := a.legalMoves pos`; moves are compared structurally (from, to, promotion piece), castling being the king's two-square move |
| why | for each move of `onlyB`, the legality rules of `a` that forbid it | `forbiddenInA := onlyB.map fun m => (m, (a.forbiddenBy pos m).map (·.name))` |
| safe moves | extra moves after which the mover's king is not attacked | `safeOnlyB := onlyB.filter fun m => !(pos.play m).isInCheck pos.turn` |
| perft | difference of the numbers of legal move sequences | `perft b pos d - perft a pos d`, decomposed over the positions where `onlyB ≠ []` (`divergences`) |
| status | game over or not, result and ending rule | `a.status pos` vs `b.status pos` (`Status.ongoing claims` / `Status.over ⟨result, rule⟩`) |
| verdict | bounded best play: forced win/loss within the horizon | `solve a pos h` vs `solve b pos (h+2)`, compared by `Verdict.result?` (win/loss/draw/undecided) |
| value | exact best play (tablebases) | `(solveEndgame a start).value? pos` vs the same for `b`, compared by `Value.sign`, and the distance in plies |

Only the last two levels speak about who wins. The first ones differ much more often, but mostly
harmlessly: a natural-only move that exposes the king is legal yet loses at once.

### 3.1 Perft

From the initial position, standard and natural chess agree at depths 1–3 and differ from depth 4:

| depth | standard | natural | difference |
|---|---|---|---|
| 3 | 8,902 | 8,902 | 0 |
| 4 | 197,281 | 197,742 | 461 |
| 5 | 4,865,609 | 4,897,256 | 31,647 |
| 6 | 119,060,324 | 120,909,363 | 1,849,039 |

`chess divergences standard natural 5 10 5` lists every position of the common tree where the
legal moves differ. Within 4 plies, these are 134 positions after 3 plies, with 461 natural-only
moves, all forbidden by `noSelfCheck`. Within 5 plies, add 3,313 positions after 4 plies with
14,914 moves. Since standard legal moves are natural legal moves (theorem above), the perft
difference decomposes exactly over these divergence points: 16,733 + 14,914 = 31,647 at depth 5.
First examples:

* 1\. b3 e6 2. Ba3: natural Black may play Ke7 (into the bishop's attack);
* 1\. c3 a6 2. Qa4: d6/d5 (the d-pawn is pinned);
* 1\. c3 d6 2. Qa4+: 21 extra moves, everything that ignores the check.

The first king captures appear at depth 5. Castling never matters this early from the initial
position (`natural-nosuicide` = standard up to depth 5).

**Anatomy of one divergence point**, 1. c3 d6 2. Qa4+ (`rnbqkbnr/ppp1pppp/3p4/8/Q7/2P5/PP1PPPPP/RNB1KBNR b KQkq - 1 2`):

* legal moves: standard 6 (c6, b5, Nd7, Nc6, Bd7, Qd7), natural 27. The 21 extra moves (a6, h6, Nf6,
  Kd7, …) are all forbidden in standard chess by `noSelfCheck` and are all *legal* in natural chess;
* the king is attacked in both games: natural chess has no rule called check, but `isInCheck` is the
  same predicate (the king is attacked ⟺ it can be captured);
* status: `ongoing` in both;
* value: unchanged. Each of the 21 extra moves is answered by 3. Qxe8, capturing the king
  (`solve natural 1` → "win in 1 ply" after each), so best play never uses them;
* perft: this node contributes 21 extra leaves to perft(4). At depth 5, each of these 21 positions
  contributes all of White's natural replies, among them the capture of the king.

This is the pattern of the whole perft divergence from the initial position at depths 4 and 5:
every extra sequence goes through a move that exposes the king (castling plays no role yet), so the
numbers differ while no value does. Values only
change through the three rules of §3.6.

### 3.2 Lichess positions

Positions from the first 299,675 games of the Lichess rated-games dump of September 2026:
- one random position from each of 20,000 random games;
- all positions in check in those games (at most 5 per game);
- the final positions of *all* games ending in checkmate, stalemate or insufficient material.

For each position, `chess compare standard natural H` compares:
- the legal moves, recording which standard rules forbid the extra natural moves;
- the *safe* extra moves, after which the mover's king is not attacked;
- the status (game over or not);
- the verdict of a bounded search, with horizon H plies for standard chess and H+2 for natural
  chess (H = 3 for random and check positions, H = 1 for terminal ones).

| set | positions | legal moves differ | extra natural moves (mean; standard mean) | extra *safe* moves | status differs | verdict differs |
|---|---|---|---|---|---|---|
| random | 20,000 | 30.8% | 2.32 (30.66) | 175 (0.88%) | 88 (0.44%) | 14 (0.07%) |
| in check | 63,899 | 99.99% | 28.76 (3.42) | **4,742 (7.42%)** | 2,617 (4.1%) | 60 (0.09%) |
| checkmates | 72,691 | 100% | 24.72 (0) | **508 (0.70%)** | 100% | **508 (0.70%)** |
| stalemates | 1,956 | 100% | 4.82 (0) | 0 | 100% | **1,956 (100%)** |
| insufficient material | 1,711 | 57.6% | 1.37 (6.49) | 0 | 100% | 5 (+1,706 by rule only) |

How to read it:
* **Legal moves** differ very often. The extra natural moves are, overwhelmingly, moves that give
  the king away (`noSelfCheck`: 46,220 of the 46,406 extra moves in the random set). The rest are
  castlings across attacked squares (`castlingNotOutOfCheck`, `castlingNotThroughCheck`).
* **Safe** extra moves exist only through castling. One real position in check out of 14 could
  castle out of check, typically an early bishop or queen check against an uncastled king.
* **Status** differs for every terminal position: natural chess ends one move later, or, for
  insufficient material, does not end.
* **Value** (best play, within the horizons) almost always agrees. It differs for 0.07% of
  random positions and 0.09% of positions in check, and **never with opposite decisive results**:
  one side is decisive and the other is undecided or a draw. §3.6 attributes every difference to a rule.

Checkmates and stalemates in detail:

* **Checkmates.** In 2,744 of the 72,691 real mates (3.8%), the mated side still had a castling
  right; in 508 of them (0.70% of all mates), castling out of check reaches a safe square. White
  was mated in 211 of the 508, Black in 297; O-O in 351, O-O-O in 234 (77 had both); median ply
  35, earliest ply 11. A deeper natural search of those 508:
  - 50 are lost 4 plies later: the escape only postpones a mate in 1;
  - 10 are lost 6 plies later;
  - **448 are not lost within 7 plies**;
  - none is won by the castler within 7 plies.

  Example, Lichess
  [RSJfq4Su](https://lichess.org/RSJfq4Su) (rapid, 1165–1262): 1. e4 d5 2. d3 dxe4 3. d4 Nf6
  4\. Qf3 exf3 5. Nxf3 Nc6 6. Ne5 Nxd4 7. Na3 Qd5 8. Bf4 Qe4+ 9. Be2 Qxe2# 0-1. In natural chess,
  10\. O-O (or O-O-O) and the king is safe (theorem `castling_escape`).
* **Stalemates.** All 1,956 are natural losses in 2 plies for the stalemated player. Example,
  Lichess [NZ2sKoBF](https://lichess.org/NZ2sKoBF) (rapid, 1919–1907): 71. h7+ Kh8 72. Kh6, the
  textbook K+P draw, which in natural chess is lost (theorem `stalemate_loses`). Castling never saves a
  stalemated player, by a small structural argument, the one Hamkins gives in the section
  "Stalemate in natural chess" of his essay. A castling candidate needs the squares next to the
  rook empty, so the rook could legally step there: a corner rook never shields its own king, and
  the stalemated king is not in check. Hence a standard stalemate is a natural loss unless no
  piece can move at all.
* **Deeper in the tree.** A mate in 2 can also fail: Lichess [t82cDrIb](https://lichess.org/t82cDrIb)
  (bullet), 19... Nd3+ mates next move in standard chess, but in natural chess White answers
  20\. O-O or 20. O-O-O. Black cannot force a king capture within 5 plies (theorem `mate_in_two_lost`),
  nor within 7 (`chess solve natural 7`). In the game, White played 20. Kf1 and lost on time.

### 3.3 Random positions

* *placement*: kings plus 0–12 random pieces on random squares. A position is kept if valid in
  standard chess; castling rights are granted at random when king and rook are at home.
* *playout*: up to 200 random legal moves from the initial position.

| set | positions | legal moves differ | extra natural moves (mean; standard mean) | extra *safe* moves | status differs | verdict differs |
|---|---|---|---|---|---|---|
| random placement | 20,000 | 70.0% | 8.79 (14.84) | 1 | 3,505 (17.5%) | 190 (0.95%) + 3,149 by rule only |
| random playout | 20,000 | 66.9% | 4.07 (26.39) | 39 (0.20%) | 844 (4.2%) | 59 (0.30%) |

Random placements have little material: 15.7% are standard dead positions (K+minor v K, …),
which natural chess plays on ("by rule only": standard draw, natural undecided). Their value
differences are almost all stalemate tricks: natural chess wins by stalemating, or wins faster
than standard chess by doing so. Random playouts end in stalemate more often than real games do.
In both sets castling hardly matters, since the random mover rarely keeps the king at home with
castling rights.

### 3.4 Hamkins' positions, and targeted and exhaustive search

**Hamkins' positions.** The diagrams of the essay, transcribed as FEN and machine-checked
(`Chess/Theorems.lean`). Each one is a legal position: proof games reach them all
(`Chess/ProofGames.lean`).

| kind | Hamkins' position | standard chess | natural chess | theorem |
|---|---|---|---|---|
| (1) | `KRBkn3/PP1P4/8/8/8/8/8/8 b - - 0 1`, Black to move | 1... Nc7#, mate in 1 | after 1... Nc7 White has no move at all: drawn. Black cannot force a capture within 9 plies (the essay argues the draw; a bounded check) | `hamkins_no_move_mate` |
| (2) | `1r6/K6k/8/1q6/8/8/8/8 w - - 0 1` (David Madore) | stalemate | White is lost in 2 plies | `hamkins_madore_stalemate` |
| (3) | `5kr1/4p1p1/6B1/1b6/8/2p5/3q3P/1R2K2R w K - 0 1`, after 1... Qd2# | checkmate | 2. O-O, out of and through check, wins within 7 plies | `hamkins_castling` |
| none: a mate by pinned pieces | `k6q/4K3/4P3/8/1r6/b4B2/8/Q7 b - - 0 1` | 1... Rb7#, mate in 1 | won within 3 plies | `hamkins_pinned` |
| none: what checkmate means in natural chess | `K7/R7/q7/8/8/k7/8/8 b - - 0 1` | 1... Qc8 is illegal (the queen is pinned) | 1... Qc8 is legal but no checkmate: 2. Rxa3 takes the king first | `hamkins_qc8` |

The essay also proves that a standard stalemate is, in natural chess, either a stalemate again or
an immediate loss for the stalemated player (castling cannot help, the rook could move instead).
That is the argument of §3.2, confirmed by the hunt `stalemate-escape` below and by all 1,956 real
stalemates.

**Targeted search.** `chess hunt KIND GENERATOR …` generates random positions, with a bias towards
the configurations that matter (king at home with castling rights; few defenders), and keeps
those of a given kind. Unless they come from real games, examples are filtered for plausible
material (`scripts/plausible.py`) and the smallest are kept.

| kind (Hamkins) | hunt | found | smallest / best example |
|---|---|---|---|
| (1) standard win, king not capturable: castling out of check | `castle-escape` | 0.9% of biased positions; **508 real games** | `8/8/8/8/4k3/8/1r6/1q2K2R w K -` (5 pieces): O-O blocks the queen |
| (1) standard win, king not capturable: no move at all | `no-move` | 0 in 34M random valid positions | Hamkins' position above; hand-made `KN1q4/PPpPk3/PnP5/8/8/8/8/8 w - -`: mate by Nb6, but no white piece can move, even into check; natural draw (theorem `no_move_checkmate`) |
| (2) standard draw, natural win | `stalemate-loses` | 0.1% of uniform positions; **all 1,956 real stalemates** | Lichess NZ2sKoBF; K+B v K `8/8/8/8/8/8/8/kBK5 w`: 1. Kc2 is stalemate in standard chess and wins in natural chess (theorem `bishop_wins`) |
| (2') standard stalemate, natural escape by castling | `stalemate-escape` | 0 in 15.5M | impossible (argument above, and in the essay) |
| (3) **opposite outcomes**: standard immediate loss, natural win | `opposite`, `opposite5` | 2 per 15.5M (natural win within 3 plies); 42 per 11.8M (within 5) | **`8/8/8/8/1Q6/3k4/4qP2/R3K3 w Q -`** (6 pieces) |
| castling through check wins for the attacker | `castle-attack` | 40 per 1.6M | `1B2k2r/2N3r1/4r3/8/8/8/8/5K2 b k -`: O-O+ wins, standard has no mate in 1 |

**The opposite outcome** (theorem `opposite_outcome`): `8/8/8/8/1Q6/3k4/4qP2/R3K3 w Q - 0 1`.
White to move is checkmated by Qe2, protected by the king on d3: **0-1 in standard chess**. In
natural chess 1. O-O-O+ escapes with a rook check on the d-file. Every black defence then loses
the king within 5 plies, e.g. 1... Qxd1+ 2. Kxd1, after which all eight moves of the black king
expose it: **White wins**. Hamkins' own example has 12 pieces, and a commenter on the essay
wished for a "miniaturized" one; this one has 6. It wins by a zugzwang, though: with passing
allowed (GRID_VARIANTS.md) the black king would simply pass. Hamkins' example wins under every
convention.

**The smallest opposite outcome: 5 pieces.** An exhaustive search settles the size, up to a
search horizon. In a standard checkmate, every natural move except castling leaves the king
attacked, so an opposite outcome needs a mated player who castles out of check (and Black's
castling rights or an en passant target can only help Black: they can be dropped).
`chess miniature 2` enumerates every position with White to move, the white king on e1 with one
or both rooks at home and their castling rights, the black king, and up to two more pieces of any
kind and colour: 19,086,943 valid positions, 32,070 checkmates, of which 23,225 can be escaped by
castling (`data/positions/castle_escape_small.fen`). Their natural values, by bounded search
(`results/miniature_opposite.txt`):

| pieces | escapable checkmates | natural win for the mated side |
|---|---|---|
| 4 | 18 | none within 13 plies |
| 5 | 18,407 | none within 5 plies; **exactly one within 7 plies** |
| 6 (both rooks at home) | 4,800 | one within 7 plies, `8/8/8/8/5Q2/3k4/4q3/R3K2R w KQ -` |

The 5-piece position is `8/8/8/8/8/8/3Q4/R3Kqk1 w Q - 0 1` (theorem `opposite_outcome_5`; a
52-ply proof game shows it is legal). White is mated by Qf1, protected by the king on g1. In
natural chess 1. O-O-O puts the rook on d1, which pins the black queen to its king along the
first rank: almost every queen move hands over the king. 1... Qxd1+ 2. Kxd1 leaves the lone king
on g1 in a stalemate trap, and White wins within 7 plies. So the smallest opposite outcome has 5
pieces, unless a 4-piece one exists with a win longer than 13 plies. Settling that would need
4-piece tablebases of natural chess with castling rights, beyond the solver used here. Like
the 6-piece miniature, it wins through a zugzwang: in natural chess with passing it is not a win
(GRID_VARIANTS.md).

**A further divergence found while formalizing, not in Hamkins' list.** The 75-move rule
(FIDE 9.6.2) gives precedence to a checkmate delivered on the last move. Natural chess has no such
clause and needs two more plies to finish. In `k7/8/1K6/8/8/8/8/2R5 w - - 148 120`, 1. Rc8 is
mate in standard chess. In natural chess, 1. Rc8 Kb7 reaches 150 half-moves before the king can be
taken: a **draw** (theorem `seventy_five_moves`).

### 3.5 Endgame tablebases

`chess endgame M standard natural` computes, by retrograde analysis and under each rule set, the
exact value of every legal position with the given material (move counters ignored, as usual).
The same solver serves both games. Rows: standard value; columns: natural value (player to move).

| endgame | positions | std win → nat win | std loss → nat loss | std draw → nat draw | **std draw → nat win** | **std draw → nat loss** |
|---|---|---|---|---|---|---|
| KQK | 368,452 | 144,508 | 200,896 | 22,176 | 0 | 872 |
| KRK | 399,112 | 175,168 | 201,700 | 22,176 | 0 | 68 |
| KBK | 417,228 | – | – | 407,872 | 7,360 | 1,996 |
| KNK | 429,440 | – | – | 426,084 | 2,844 | 512 |
| KPK | 331,352 | 124,960 | 97,604 | 72,914 | **16,886** | **18,988** |

* No standard win or loss changes; only draws change, and only towards the side that can stalemate.
  **A third of the KPK draws (35,874 of 108,788) are decisive in natural chess.** The minor-piece
  endings, dead positions in standard chess, have natural wins: 2.2% of KBK, 0.8% of KNK positions.
* The distance to the win (in plies, natural minus standard, over positions decisive in both)
  never exceeds +2: the standard winning strategy works in natural chess, one move later. It is
  often *shorter*, by up to 26 plies in KPK, thanks to stalemate traps.
* **KPK, standard-with-stalemate-as-a-win versus natural: identical values on all 331,352
  positions, and on every decisive one the natural win takes exactly 2 more plies.** In this
  endgame, natural chess *is* standard chess with stalemate counted as a win, ending one move later.

### 3.6 What exactly makes the two games different?

**Attribution.** Each value disagreement of §3.2–3.3 was re-solved with variants that change a
single rule (`scripts/attribute.py`, `results/attribution_all.tsv`):

| cause | value disagreements explained | test |
|---|---|---|
| castling across attacked squares (FIDE 3.8.2.2) | 40 + the 508 mates of §3.2 | `natural-fide-castling` agrees with standard chess |
| stalemate (FIDE 5.2.1) | 277 + the 1,956 stalemates of §3.2 | `standard-stalemate-wins` agrees with natural chess |
| dead position (FIDE 5.2.2) | 4,860 (+ 6 together with stalemate) | `natural-dead` agrees with standard chess |
| anything else | **0** | |

`noSelfCheck` and `noKingCapture` cause more than 99% of the *move-level* differences, but they never
change a *value*: a move that gives the king away simply loses at once.

**One representative example per rule** (exact values, from tablebases or terminal positions):

| rule | position | standard | natural |
|---|---|---|---|
| castling (FIDE 3.8.2.2) | `8/8/8/8/1Q6/3k4/4qP2/R3K3 w Q - 0 1` (constructed) | 0-1, checkmate | 1-0: 1. O-O-O+ (out of and through check) and White captures the king within 5 plies |
| castling, in a real game | Lichess RSJfq4Su, `r1b1kb1r/ppp1pppp/5n2/4N3/3n1B2/N7/PPP1qPPP/R3K2R w KQkq - 0 10` | 0-1, checkmate (9... Qxe2#) | ongoing: 10. O-O, king safe |
| stalemate (FIDE 5.2.1) | Lichess NZ2sKoBF before White's 72nd move, `7k/7P/6K1/8/8/8/8/8 w - - 1 72` | draw (tablebase; 72. Kh6 was played: stalemate) | 1-0 in 3 plies: 72. Kh6!, then any black move exposes the king |
| dead position (FIDE 5.2.2) | Lichess A8iBWO7I, final position `8/8/8/8/8/8/8/4k1bK b - - 0 108` | draw: the game is over (insufficient material), no move may be played | 0-1 in 3 plies: 108... Kf2, then the three white king moves all expose it |

The dead-position rule changes values only together with stalemate traps, as in the last
example: the standard game is over before the trap can be set. On its own it changes the
*status*: e.g. K+N v K is over in standard chess but played on, and drawn, in natural chess.

**The naturalized standard game.** This suggests the following picture. In natural chess, a move
that leaves the king attacked loses immediately, so under best play both players keep their king
safe. The safe moves are exactly the legal moves of standard chess *without the castling
conditions*. A player with no safe move loses, whether in check or not, unless nothing can move
at all. Nothing corresponds to the dead-position rule. Hence the rule set

```
$ chess diff standard standard-naturalized          (condensed)
- legality castlingNotOutOfCheck        - ending checkmate      - ending deadPosition
- legality castlingNotThroughCheck      - ending stalemate
+ ending noLegalMoveLosesUnlessBlocked: a player with no legal move loses (checkmate or stalemate
  alike), unless none of his pieces can move at all, even into check (draw)
```

should have **the same values as natural chess, with natural wins exactly 2 plies (one move)
longer**. Tested:
* **Tablebases**: identical values on all 1,945,584 positions of KPK, KBK, KNK, KQK and KRK; on all
  994,362 decisive positions, the natural distance is exactly the naturalized distance + 2.
* **Positions**: on 16,783 positions, comprising all 7,647 positions where standard and natural chess
  disagree plus 10,000 others, there are **0** disagreements. Every decisive verdict is exactly 2 plies
  longer in natural chess (2,653 positions).
* The only exception is the timing of the draw rules (§3.4: a mate at the 75-move limit). Natural
  games last one move longer, so a draw rule can fire in between.

The argument above is a proof sketch, not a Lean proof. Mechanizing it, by induction on the game
tree with the attack/capture correspondence, is the natural next step.

**The converse bridge: a "standardized" natural chess.** Which rules must be *added to natural
chess* to recover the values of standard chess (one move later)?

```
$ chess diff natural natural-standardized          (condensed)
+ legality castlingNotOutOfCheck, castlingNotThroughCheck        (FIDE 3.8.2.2, unchanged)
- ending noLegalMove
+ ending noLegalMoveLikeFide: a player who cannot move at all loses if his king is attacked
  (checkmate) and draws otherwise (stalemate)
+ ending stalemateByAttacks: drawn when the king of the player to move is not attacked but every
  move would leave it attacked (FIDE 5.2.1, restated with attacks)
+ ending deadPositionUnlessKingCapturable
- ending seventyFiveMoves             + ending seventyFiveMovesUnlessDecided
- ending fivefoldRepetition           + ending fivefoldRepetitionUnlessKingCapturable
  ending rules, in order: [kingCaptured, stalemateByAttacks, noLegalMoveLikeFide,
    deadPositionUnlessKingCapturable, seventyFiveMovesUnlessDecided,
    fivefoldRepetitionUnlessKingCapturable]
```

My first attempt failed, and the failure was instructive. With the plain `deadPosition` rule,
some standard wins in KQK, KRK and KPK became draws, and some mates took 4 extra plies instead of 2.
The mechanism: against a mate where the queen is protected by its king, the mated king plays the
suicidal Kxq, leaving bare kings. The dead-position rule then ends the game *before* the king can
be captured, so the attacker must choose longer mates. Like the 75-move rule, every automatic draw
rule must **give way to an imminent king capture** (`givingWayToKingCapture`). With that clause:
* **Tablebases**: natural-standardized and standard have identical values on all 1,945,584
  positions of KPK, KBK, KNK, KQK and KRK, with natural-standardized wins exactly 2 plies longer on
  every decisive position;
* **Positions**: on the same 16,783 positions, **0** disagreements with standard chess.
  Every decisive verdict is exactly 2 plies longer: 740 checkmates, including the 508 castle
  escapes, which become "lost in 2 plies", and 182 forced wins.

So the two bridges commute, with "≈" meaning "same values, wins 2 plies longer on the right":

```
standard  ≈  natural-standardized          standard-naturalized  ≈  natural
   (the time shift: noSelfCheck,               (the same time shift)
    noKingCapture, checkmate → kingCaptured)
```

and the **difference between the two games splits in two parts**:
- a *time shift*, which changes no value. It removes the rules that only anticipate the king capture
  (noSelfCheck, noKingCapture) and lets the capture replace checkmate: Hamkins' "one move early";
- a *rule part*, which changes values: castling conditions, stalemate, dead position, and the
  precedence of checkmate over automatic draws.

Each rule of the second part has to mention attacked kings again (castling, stalemate, precedence).
So standard chess cannot be recovered from natural chess without reintroducing exactly the notions
of check that natural chess abandons. The four FIDE provisions where check is more than a shorthand
for "the king would be captured next" are castling (3.8.2.2), stalemate (5.2.1), dead position (5.2.2),
and the precedence clause of 9.6.2. Those are where the two games part ways.

So, in precise terms, Hamkins' "almost equivalent but not quite": natural chess is standard chess
**ended one move later**, with **castling allowed out of and through check**, **stalemate counted as
a loss**, **no dead-position draws**, and **"no move at all" as the only draw by immobility**,
modulo the timing of the 75-move/fivefold rules. Each of these differences is realized by
positions from real games (castling, stalemate) or by verified constructed positions (no-move,
75 moves), and the opposite-outcome positions of §3.4 combine the castling difference with a
counter-attack.

Hamkins reaches part of this picture by argument. In the section "Normal chess" he observes that
counting stalemate as a win (normal play) does not align the two games, because of castling. His
closing sentence then says that with normal play "the correspondence works perfectly", which his
own castling position contradicts. The bridges give the exact version: normal-play natural chess
has the values of normal-play standard chess once castling is freed from the attacked-squares
condition (and the dead-position rule dropped, which normal play requires anyway).
GRID_VARIANTS.md tests this, and the same construction for passing and lose-your-turn chess.

### 3.7 Machine-checked statements (`Chess/Theorems.lean`)

| theorem | statement | checked by |
|---|---|---|
| `natural_legalMoves` | with both kings on the board, natural legal moves = candidate (pseudo-legal) moves | proof |
| `standard_legal_subset_natural` | every standard legal move is a natural legal move | proof |
| `perft_initial_3`, `perft_initial_4` | perft agrees to depth 3, differs at depth 4 (197,281 vs 197,742) | `native_decide` |
| `castling_escape` | Lichess RSJfq4Su: standard checkmate; natural O-O legal, king safe, not lost within 4 plies | `native_decide` |
| `mate_in_two_lost` | Lichess t82cDrIb: standard mate in 2; no natural king capture within 5 plies | `native_decide` |
| `stalemate_loses` | Lichess NZ2sKoBF: standard stalemate; natural loss in 2 plies | `native_decide` |
| `stalemating_move_wins` | Lichess NZ2sKoBF before move 72: 72. Kh6 is stalemate in standard chess and wins in natural chess within 3 plies | `native_decide` |
| `dead_position_wins` | Lichess A8iBWO7I: standard dead position (game over); natural win for Black within 3 plies | `native_decide` |
| `bishop_wins` | K+B v K: standard dead position, natural win in 3 plies (1. Kc2 is stalemate in standard chess) | `native_decide` |
| `opposite_outcome` | standard checkmate (0-1); natural win for the mated side within 5 plies | `native_decide` |
| `seventy_five_moves` | mate in 1 at half-move 148 in standard chess; natural draw by the 75-move rule | `native_decide` |
| `no_move_checkmate` | standard checkmate; natural draw (no move at all); natural lose-your-turn: loss in 2 | `native_decide` |
| `hamkins_no_move_mate`, `hamkins_madore_stalemate`, `hamkins_castling` | Hamkins' three positions, one per kind (§3.4) | `native_decide` |
| `hamkins_pinned`, `hamkins_qc8` | Hamkins' two positions that do not distinguish the games | `native_decide` |
| `proofGame_*` (13 theorems, `Chess/ProofGames.lean`) | each constructed position and each of Hamkins' diagrams is reached by a game of standard chess from the initial position (every move legal, no earlier end of the game) | `native_decide` |
| `hamkins_lose_turn`, `hamkins_double_stalemate`, `hamkins_rook_zugzwang`, `hamkins_castling_grid`, `hamkins_no_move_grid` (`Chess/GridTheorems.lean`) | the values of Hamkins' positions in the eight games of his grid (GRID_VARIANTS.md) | `native_decide` |

`native_decide` runs the engine through the Lean compiler's evaluator, outside the kernel. It
therefore trusts the compiler in addition to the kernel, and the correctness of the engine
itself, which perft and the python-chess cross-validation support. The two general theorems are
kernel-checked proofs about the rule-set definitions, valid for every position. The proof games
are also checked independently with python-chess (`scripts/proofgame_check.py`).

---

## 4. Interpretation choices and ambiguities

Formalizing forced decisions that the informal descriptions leave open. Each choice is a named rule,
and the main alternatives are rule sets in `Chess/Rules/Variants.lean`, so their effect can be measured.
[RULES.md](RULES.md) traces every rule to its source in the FIDE Laws and lists the choices made in
transcribing the Laws themselves.

### In the specification of natural chess

1. **What "abandon the rules about check" removes.** Four FIDE provisions mention check or king
   capture: 1.4.1 (do not capture the king), 3.9.2 (do not expose/leave your king in check),
   3.8.2.2 (castling not out of, through, or into check). All four are dropped. Castling *into*
   check needs no rule of its own: it is just a move that hands over the king. Variant
   `natural-fide-castling` keeps the castling conditions. The essay makes the same choice
   explicitly: "I am inclined to take natural chess as allowing castling out of, into, and through
   check".
2. **Castling across an attacked square.** Some king-capture programs let the opponent capture
   the king "in passing" on the square it crossed (en passant on the king). The essay weighs this
   argument (castling seen "in the en passant manner") and declines it. Natural chess has no such
   rule, and none is implemented. It would need a new field in `Position`
   (the crossed square), i.e. a change to the core, unlike every other variant here.
3. **A player with no move at all** (not even one exposing the king). Default: draw, like a stalemate.
   That is how Hamkins treats it, in the essay (his first position) and in *Checkmate is not the
   same as a forced capture…*. Alternatives, both discussed in the essay: `natural-normal` (no
   legal move loses), and `natural-lose-turn` (the player passes, as suggested by a commenter;
   it restores equivalence for this case). GRID_VARIANTS.md compares all these conventions.
4. **Stalemate.** Taken literally, natural chess has no stalemate rule: a stalemated player must
   move and expose the king, then loses it. "Stalemate = draw" cannot be stated in natural chess
   without reintroducing *check*. For comparison, `standard-stalemate-wins` changes standard chess instead.
5. **Dead position (FIDE 5.2.2)** is defined as "no checkmate possible". Its natural analogue,
   "no king capture possible by any series of legal moves", almost never holds: even a bare king
   can walk into capture, so K v K is *not* dead. Default: rule dropped (games still end by the 75-move
   rule or fivefold repetition). `natural-dead` keeps the standard insufficient-material rule.
6. **Draw rules** (50/75 moves, threefold/fivefold repetition) are kept unchanged, but they do not
   transfer exactly. The 75-move rule says a checkmate on the last move takes precedence (FIDE 9.6.2).
   Natural chess has no checkmate, and its games last one move longer, so a mate at the limit becomes
   a draw (theorem `seventy_five_moves`). A natural version of the clause would have to say "a king
   capture that is unavoidable…", i.e. reintroduce checkmate. One subtle point:
   repetition compares "the possible moves" (FIDE 9.2.3), and those depend on the rules. An en passant
   capture that is pseudo-legal but illegal because of a pin makes two positions *different* in
   natural chess and *the same* in standard chess.
7. **Valid positions.** In natural chess the player who has just moved *may* be in check (they
   blundered the king), and a king may be missing (the game is then over). Validity rules are
   part of the rule set.
8. **No compulsory king capture.** Natural chess lets a player leave an en prise king alone. (The
   Brumleve–Hamkins–Schlicht paper mentions a variant where capturing it is compulsory.)
   This changes no game value: capturing always wins at once.
9. **After the king is captured** there are no legal moves. This is a legality rule
   (`noMoveAfterKingCapture`), so perft stops there.

### In the specification of the engine / the experiment

10. **Perft semantics.** Perft counts sequences of legal moves and ignores the ending rules, by
    convention (checkmate and stalemate positions simply have no legal moves). In natural chess
    the only cut-off is the capture of the king. Draw rules play no role in either game.
11. **Perft counters.** The chessprogramming.org tables count a check as *discovered* only when
    the moved piece does not itself give check. A double check by the moved piece plus a discovered
    piece counts as a double check, not a discovered one. We found this convention by matching the
    tables: counting "any discovered piece" gives 48 instead of 42 for Kiwipete at depth 4.
12. **"Checkmates" in natural perft.** There is no checkmate in natural chess. The column counts
    positions where the game is over and the mover has won (king captured), plus a separate king-capture count.
13. **Dead position detection** is sound but incomplete: insufficient material (bare kings, one minor
    piece, bishops on one colour), the same criterion as Lichess and python-chess. Blocked-pawn
    fortresses are not detected.
14. **Threefold repetition claims** are checked once the position has occurred three times.
    Claims announced with a move ("is about to occur") are not modelled.
15. **What "equivalent" means.** Three increasingly meaningful notions:
    (a) same legal moves: false in most positions;
    (b) same immediate status (game over or not): false for *every* checkmate and stalemate, since
    natural chess ends one move later;
    (c) same game-theoretic value (win/draw/loss under best play): the notion Hamkins means.
    Under (c), a standard mate in *n* moves corresponds to a natural win in *2n+1* plies. All
    comparisons here use (c), computed either by bounded search (standard horizon *h*, natural *h*+2)
    or exactly (tablebases).
16. **Reachability.** Real Lichess positions are reachable by construction. The constructed
    positions of the theorems, and Hamkins' diagrams, are reachable too: each one is reached by a
    proof game from the initial position (`data/proofgames/`, checked by python-chess and replayed in
    Lean, `Chess/ProofGames.lean`). The 75-move position is reached with its exact move counters
    (148 half-moves, move 120). The other hunted and random positions only satisfy the validity rules
    (one king each, side not to move not in check, consistent castling rights, no pawn on the back
    ranks), plus a material-plausibility filter for the hunted examples. That is necessary, not
    sufficient, for reachability (FIDE 3.10.3).

---

## 5. Reproducing

```sh
lake build && lake build tests && .lake/build/bin/tests --deep
B=.lake/build/bin/chess
# data (first 300k games of the September 2026 Lichess dump)
curl -s https://database.lichess.org/standard/lichess_db_standard_rated_2026-09.pgn.zst | zstd -dc | head -c 700000000 > data/lichess-games/2026-09-head.pgn
python3 -I scripts/extract_lichess.py data/lichess-games/2026-09-head.pgn data/positions --sample 20000
python3 -I scripts/crossval.py $B data/positions                      # step 1/2 cross-validation
$B divergences standard natural 5 10 5                                # 3.1
for s in mate stalemate insufficient; do cut -f1 data/positions/$s.fen | $B compare standard natural 1 > results/compare_lichess_$s.tsv; done
for s in random check; do cut -f1 data/positions/$s.fen | $B compare standard natural 3 > results/compare_lichess_$s.tsv; done
$B random placement 20000 1 12 | $B compare standard natural 3 > results/compare_random_placement.tsv
$B random playout 20000 2 200 | $B compare standard natural 3 > results/compare_random_playout.tsv
python3 -I scripts/summarize_compare.py results/summary.md lichess-random=results/compare_lichess_random.tsv ...
$B hunt castle-escape castling 8 1600000 3 1                          # 3.4
$B endgame P standard natural 5                                       # 3.5
sh scripts/perft_tables.sh $B
```

Results files are in `results/`.

