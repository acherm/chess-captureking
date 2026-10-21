# Hamkins' grid: which variations of chess are equivalent?

*Every game of chess ends prematurely* (J. D. Hamkins, Infinitely More, 15 October 2026) closes
with four questions. The fourth one is:

> How many chess variations do we have here? Standard versus natural; normal versus ordinary;
> passing versus no-passing versus lose-your-turn passing; standard penultimate versus natural
> penultimate; and the same for antepenultimate. Which variations are equivalent or inequivalent
> in terms of their judgements of the commonly arising positions? Which comparisons are not yet
> settled by the discussion here?

This document answers it for the eight games obtained by crossing the two winning conditions
with the four conventions for a player who cannot, or would rather not, move. Penultimate and
antepenultimate chess are left for later (§7).

**In short.**
* **No two of the eight games are equivalent.** All 28 pairs differ, and three of Hamkins' own
  diagrams, evaluated in all eight games, are enough to separate them (§3).
* **Two independent things separate them.** *Castling* out of and through check separates every
  standard game from every natural game. *The convention for a player who cannot move* separates
  the four games within each family, and passing is by far the most disruptive: it erases 98% of
  the K+R v K wins, but no K+Q v K win.
* **Hamkins' guess about real stalemates holds**: with passing, at least 82% of 1,956 Lichess
  stalemates become wins for the stalemating side (97.5% when it is a rook or more ahead). The
  exception is the most frequent one, K+P v K, which stays drawn. But 203 of these 212 games were
  already drawn one move before the stalemate, a single pawn up, so they lie outside his "far
  more material" case (§3.4).
* **Modulo castling, exactly two pairs are equivalent**: normal-play standard and natural chess,
  and standard and natural chess with passing. This is the precise form of the essay's closing
  sentence ("with the normal play convention [...] the correspondence works perfectly"), which,
  read literally, its own castling position contradicts (§5).
* Every value is exact on 1.9M endgame positions, bounded on 16,783 positions from games, and
  machine-checked in Lean for the witnesses.

---

## 1. The eight games

| convention (Hamkins' words) | standard chess: checkmate wins | natural chess: capturing the king wins |
|---|---|---|
| **ordinary**: stalemate is a draw | `standard` | `natural`: a player with no move at all (not even one exposing the king) draws |
| **normal** play: "to lose means to have no legal move" | `standard-normal`: no legal move loses, in check or not | `natural-normal`: no legal move (nothing can move at all) loses |
| **passing**: "a player may opt not to make any move" | `standard-passing`: a pass at any time, except out of check | `natural-passing`: a pass at any time (passing with the king attacked loses it) |
| **lose-your-turn**: "the stalemated player simply loses their turn" | `standard-lose-turn`: a stalemated player passes | `natural-lose-turn`: a player who cannot move at all passes |

Each game is a rule set, defined as a small delta on `standard` or `natural`
(`Chess/Rules/Variants.lean`), and `chess diff` prints the delta:

```
$ chess diff standard standard-normal          (condensed)
- ending checkmate   - ending stalemate   - ending deadPosition   + ending noLegalMoveLoses
$ chess diff standard standard-passing
+ movement passAnyTime   - ending stalemate
$ chess diff standard standard-lose-turn
- ending stalemate   + fallback passIfNoMove
$ chess diff natural natural-normal
- ending noLegalMove   + ending noLegalMoveLoses
$ chess diff natural natural-passing
+ movement passAnyTime   - ending noLegalMove
$ chess diff natural natural-lose-turn
- ending noLegalMove   + fallback passIfNoMove
```

A pass is the null move: the board is unchanged and the other player moves. A *fallback* move is
offered only when no other move is legal. The rules of the eight games side by side (generated
by `scripts/variability_matrix.py`; ● = present, numbers = priority of the ending rules):

<details>
<summary>Rule matrix of the grid</summary>

Common to all: movement pawnPush, pawnDoublePush, pawnCapture, enPassant, knight, bishop, rook, queen, king, castling; claims threefoldRepetition, fiftyMoves.

**Extra movement rules**

| rule | std | std-normal | std-passing | std-lose-turn | nat | nat-normal | nat-passing | nat-lose-turn |
|---|---|---|---|---|---|---|---|---|
| `passAnyTime` |  |  | ● |  |  |  | ● |  |

**Legality**

| rule | std | std-normal | std-passing | std-lose-turn | nat | nat-normal | nat-passing | nat-lose-turn |
|---|---|---|---|---|---|---|---|---|
| `noKingCapture` | ● | ● | ● | ● |  |  |  |  |
| `noSelfCheck` | ● | ● | ● | ● |  |  |  |  |
| `castlingNotOutOfCheck` | ● | ● | ● | ● |  |  |  |  |
| `castlingNotThroughCheck` | ● | ● | ● | ● |  |  |  |  |
| `noMoveAfterKingCapture` |  |  |  |  | ● | ● | ● | ● |

**Endings (priority order)**

| rule | std | std-normal | std-passing | std-lose-turn | nat | nat-normal | nat-passing | nat-lose-turn |
|---|---|---|---|---|---|---|---|---|
| `checkmate` | 1 |  | 1 | 1 |  |  |  |  |
| `stalemate` | 2 |  |  |  |  |  |  |  |
| `deadPosition` | 3 |  | 2 | 2 |  |  |  |  |
| `seventyFiveMoves` | 4 | 2 | 3 | 3 | 3 | 3 | 2 | 2 |
| `fivefoldRepetition` | 5 | 3 | 4 | 4 | 4 | 4 | 3 | 3 |
| `noLegalMoveLoses` |  | 1 |  |  |  | 2 |  |  |
| `kingCaptured` |  |  |  |  | 1 | 1 | 1 | 1 |
| `noLegalMove` |  |  |  |  | 2 |  |  |  |

**Validity**

| rule | std | std-normal | std-passing | std-lose-turn | nat | nat-normal | nat-passing | nat-lose-turn |
|---|---|---|---|---|---|---|---|---|
| `oneKingEach` | ● | ● | ● | ● |  |  |  |  |
| `noPawnOnFirstOrLastRank` | ● | ● | ● | ● | ● | ● | ● | ● |
| `opponentNotInCheck` | ● | ● | ● | ● |  |  |  |  |
| `castlingRightsConsistent` | ● | ● | ● | ● | ● | ● | ● | ● |
| `enPassantConsistent` | ● | ● | ● | ● | ● | ● | ● | ● |
| `atMostOneKingEach` |  |  |  |  | ● | ● | ● | ● |

**Fallback**

| rule | std | std-normal | std-passing | std-lose-turn | nat | nat-normal | nat-passing | nat-lose-turn |
|---|---|---|---|---|---|---|---|---|
| `passIfNoMove` |  |  |  | ● |  |  |  | ● |

</details>

**Interpretation choices.** The essay describes the variations in a sentence or two; making them
rule sets forced five decisions.

1. **A pass is subject to the legality rules.** In standard chess with passing, a player in check
   cannot pass, since the pass would leave the king in check (FIDE 3.9.2). Otherwise a checkmated
   player could pass, and checkmate would disappear. The essay agrees: in checkmate "there is no
   good move, and also it is not good to make no move". In natural chess a pass is always legal,
   and passing with the king attacked loses it.
2. **Normal standard chess drops the dead-position rule.** FIDE 5.2.2 draws a position where no
   player can win "with any series of legal moves". Once stalemate wins, insufficient material no
   longer implies this: K+B v K and K+N v K can be won by stalemating the lone king. With passing
   or lose-your-turn, stalemate does not win, and the insufficient-material rule stays sound
   (no checkmate is possible), so it is kept.
3. **Lose-your-turn means different things in the two games.** A player passes when he has no
   legal move. In standard chess, that includes a stalemated player. In natural chess, moves that
   expose the king are legal, so a stalemated player who has any piece to move must move it (and
   lose his king). He passes only when nothing can move at all.
4. **Passing forever is a draw.** If both players pass forever, the game is drawn: in a game by
   fivefold repetition (FIDE 9.6.1), and in the exact solver because it never ends. The essay
   calls this "a draw by repetition—repetition of passing".
5. **Standard chess with passing needs no stalemate rule.** A player who is not in check can
   always pass, so stalemate never occurs. This is the essay's remark that "standard chess with
   passing is the same as normal standard chess with passing".

---

## 2. Experimental design

**Equivalence.** Two games are equivalent when they give every position the same value (win, draw
or loss for the player to move, under best play). The positions are those valid in standard
chess, the stricter of the two notions of validity. Natural games take two more plies to win (the
king capture comes one move after the checkmate), so values are compared by their sign, and the
distances separately.

**Three sources of positions, three strengths of evidence.**

| positions | how they are valued | what they can show |
|---|---|---|
| **all 1,945,584 positions** of K+Q v K, K+R v K, K+B v K, K+N v K and K+P v K that are valid in standard chess, either side to move | exactly: retrograde analysis of the whole game graph, under each game (`chess grid-endgame M`) | exact disagreement counts, but no castling (no rook or king at home with rights) and no blocked pieces |
| **16,783 positions** from real games and random positions: every position where standard and natural chess disagree in REPORT §3.2–3.3, plus 10,000 others (`data/positions/naturalized_test.fen`) | bounded search: 3 plies in the standard games, 5 in the natural ones (`chess grid-verdicts 3`) | castling, many pieces; a disagreement counts only when both verdicts are known |
| **Hamkins' diagrams**, plus a few constructed positions | certified in Lean (`Chess/GridTheorems.lean`): `status` for finished games, `canWin`/`mustLose` for forced results, the exact solver for draws | one witness per pair of games; each position is legal (proof games, `Chess/ProofGames.lean`) |

For each of the 28 pairs of games, the tablebases give the number of positions where the values
differ, with a witness (opposite results preferred, then the shortest lines).

**Bridges.** REPORT §3.6 found that natural chess has exactly the values of `standard-naturalized`:
standard chess with castling allowed out of and through check, no dead-position rule, and the
convention for a player without legal move rewritten as natural chess reads it. The same
construction gives one bridge per convention:

| natural game | its naturalized standard counterpart | delta from the standard game of the same convention |
|---|---|---|
| `natural` | `standard-naturalized` | free castling; no dead position; no legal move loses, unless nothing can move at all (draw) |
| `natural-normal` | `standard-normal-naturalized` | free castling |
| `natural-passing` | `standard-passing-naturalized` | free castling; no dead position |
| `natural-lose-turn` | `standard-lose-turn-naturalized` | free castling; no dead position; a stalemated player who has a piece to move loses (`stalemateLosesUnlessBlocked`) |

Each bridge is tested on the same positions: are the values the same, and every natural win
exactly two plies longer?

**Threats to validity.**
* The tablebases contain neither castling rights nor blocked positions (with three pieces,
  a king can always move somewhere). Castling and "no move at all" are covered only by the game
  positions (bounded search) and by the certified witnesses.
* Bounded search sees only wins and losses within its horizon; "undecided" is not a draw.
* The exact solver ignores the move counters, so the 75-move rule plays no role (its timing
  effect is discussed in REPORT §3.4).
* The positions of the tablebases are all the valid placements, most of which are not
  reachable in practice. The witnesses, in contrast, are legal positions (proof games).

---

## 3. Results: no two games are equivalent

**All 28 pairs of games are inequivalent**, and three of Hamkins' own diagrams are enough to
show it. Their values in the eight games, certified in Lean (`Chess/GridTheorems.lean`):

| position (player to move) | `standard` | `standard-normal` | `standard-passing` | `standard-lose-turn` | `natural` | `natural-normal` | `natural-passing` | `natural-lose-turn` |
|---|---|---|---|---|---|---|---|---|
| **A**. Hamkins' castling position `5kr1/4p1p1/6B1/1b6/8/2p5/3q3P/1R2K2R w K - 0 1` (White) | L (mate) | L | L (mate) | L (mate) | **W** (2. O-O) | **W** | **W** | **W** |
| **B**. Hamkins' lose-your-turn position `kqn5/prp1p3/KpPpP3/1P1P4/8/8/8/8 b - - 0 1` (Black) | D (stalemate) | L | D | **W** (3 plies) | D (no move) | L | D | **W** (5 plies) |
| **C**. Hamkins' K+R v K position `8/8/8/8/2r5/4k3/8/3K4 w - - 0 1` (White) | L (1. Ke1 Rc1#) | L | **D** | L | L | L | **D** | L |

(W/D/L: win, draw or loss for the player to move. Every "D" of a passing game is an exact value;
the draws of C come from the compiled test suite, see `hamkins_rook_zugzwang`.)

* **A** separates every standard game from every natural game (16 pairs): castling out of and
  through check turns a checkmate into a win, whatever the convention for stalemate or passing.
* **B** separates the four conventions within each family (D, L, D, W on both sides) except
  ordinary from passing.
* **C** separates ordinary (and normal, and lose-your-turn) from passing, in both families: with
  passing, the zugzwang that forces 1. Ke1 disappears.

So Hamkins' discussion settles every comparison once each diagram is evaluated in all eight games;
the essay evaluates most of them in only some of the games. The other witnesses found by the
tablebases are in `results/grid_endgame_K*K.txt` (one per pair, e.g. the stalemated lone king of
K+B v K, `8/8/8/8/8/8/8/kBK5 b - - 0 1`: a draw in four games, a loss in the other four).

### 3.1 How much the games differ: exact values in five endgames

Values of all 1,945,584 standard-valid positions of five endgames, under each game (wins, draws and
losses for the player to move; `results/grid_endgame_K*K.txt`):

| game | K+Q v K | K+R v K | K+B v K | K+N v K | K+P v K |
|---|---|---|---|---|---|
| `standard` | 144,508 / 23,048 / 200,896 | 175,168 / 22,244 / 201,700 | 0 / 417,228 / 0 | 0 / 429,440 / 0 | 124,960 / 108,788 / 97,604 |
| `standard-normal` | 144,508 / 22,176 / 201,768 | 175,168 / 22,176 / 201,768 | 7,360 / 407,872 / 1,996 | 2,844 / 426,084 / 512 | 141,846 / 72,914 / 116,592 |
| `standard-passing` | 144,508 / 22,176 / 201,768 | **2,804 / 395,744 / 564** | 0 / 417,228 / 0 | 0 / 429,440 / 0 | 113,290 / 130,416 / 87,646 |
| `standard-lose-turn` | 144,508 / 22,176 / 201,768 | 175,168 / 22,176 / 201,768 | 0 / 417,228 / 0 | 0 / 429,440 / 0 | 137,020 / 82,646 / 111,686 |
| `natural` | = `standard-normal` | = `standard-normal` | = `standard-normal` | = `standard-normal` | = `standard-normal` |
| `natural-normal` | = `standard-normal` | = `standard-normal` | = `standard-normal` | = `standard-normal` | = `standard-normal` |
| `natural-passing` | = `standard-passing` | = `standard-passing` | = `standard-passing` | = `standard-passing` | = `standard-passing` |
| `natural-lose-turn` | = `standard-normal` | = `standard-normal` | = `standard-normal` | = `standard-normal` | = `standard-normal` |

"=" means the same value for every position, not only the same totals (0 pairwise
disagreements). In these endgames the eight games fall into a few classes:

| endgame | classes of games with identical values |
|---|---|
| K+Q v K | {`standard`} · {the other seven} |
| K+R v K | {`standard`} · {`standard-passing`, `natural-passing`} · {the other five} |
| K+B v K, K+N v K | {`standard`, `standard-passing`, `standard-lose-turn`, `natural-passing`} · {`standard-normal`, `natural`, `natural-normal`, `natural-lose-turn`} |
| K+P v K | {`standard`} · {`standard-passing`, `natural-passing`} · {`standard-lose-turn`} · {`standard-normal`, `natural`, `natural-normal`, `natural-lose-turn`} |

Observations:

* **Normal play is natural chess, in these endgames.** `standard-normal` and the three natural
  games without passing agree on every position, natural wins being two plies longer. With three
  pieces a king can always move somewhere, so "no move at all" never happens and the natural
  conventions coincide. What remains of the standard/natural difference is stalemate (a draw in
  `standard`), and it is exactly what normal play changes.
* **Passing is the most disruptive convention, and it depends on the material.**
  - *Against a lone rook*, 99.1% of the decisive positions become draws: 3,300 of 376,868 stay
    decisive (plus 68 stalemates, which become losses for the stalemated king). The 2,804 wins
    that survive are of two kinds only. In 1,512, the lone king is on the edge and a mate in one is
    already there. In the other 1,292, the lone king is **in a corner**, with the attacking king
    two or three squares away, and the rook mates in 2 to 5 moves even though the defender may
    pass. For example, in `4RK1k/8/8/8/8/8/8/8 w` the line is 1. Re7 (pass) 2. Rg7 (pass) 3. Kf7
    (pass) 4. Rg5, and Rh5# follows whether Black passes or plays Kh7. Everywhere else K+R v K is
    drawn: no win starts with the lone king off the edge, and on the edge, outside the corners,
    only mates in one remain. The rook needs zugzwang to drive the king into the corner, and only
    there can it mate without it. With the lone king to move, the 564 losses are the 216
    checkmates, the 68 stalemates (the pass is followed by mate), and 280 corner positions where
    every option, the pass included, is mated (`results/krk_passing.txt`; these counts are
    recomputed with python-chess from the list of wins, independently of the Lean tablebase).
  - *Against a lone queen*, passing changes no result: all 144,508 wins survive. 55% keep their
    length and 44% get longer, by up to six moves (the longest mate goes from 10 moves to 12).
    For example, `8/8/8/8/8/2k5/4Q3/1K6 w` is a mate in 4 in standard chess, by zugzwang
    (1. Qe4 Kb3 2. Qd4 Ka3 3. Kc2 Ka2 4. Qa4#), and a mate in 10 with passing: Black passes until
    the white king arrives, then the queen herds the king to the a-file without needing his
    cooperation (worked out move by move in §3.3). And 1.3% of the wins get *shorter*, because passing abolishes stalemate: in
    `8/8/8/8/7k/4KQ2/8/8 w`, 1. Kf4 is stalemate in standard chess (which then needs 4 moves to
    mate), but with passing Black must pass and 2. Qg4# follows. The queen covers enough squares
    to build a mating net around a king that refuses to move.
  - *In K+P v K*, passing changes 21,652 values: wins that rest on zugzwang disappear, and
    stalemates become wins for the stalemating side (113,290 wins in all, against 124,960 in
    standard chess).
* **Lose-your-turn sits between ordinary and normal play in standard chess.** It agrees with
  normal play in K+Q v K and K+R v K (a stalemated lone king passes, and is then mated), with
  ordinary chess in K+B v K and K+N v K (the stalemated king passes, and nothing can mate it), and
  with neither in K+P v K (9,732 positions differ from normal play: of the 22 stalemates, 8 are
  drawn).
* **A stalemated player never wins by passing**, as Hamkins argues: over the 1,138 standard
  stalemates of these endgames, the stalemated player never wins in `standard-passing` (it draws
  or loses: in K+Q v K and K+R v K, passing out of a stalemate loses, since the opponent then mates).

### 3.2 Game positions

On the 16,783 game positions, bounded search (3 plies in the standard games, 5 in the natural
ones) can certify a disagreement only when both verdicts are known
(`results/grid_verdicts_summary.md`). The certain disagreements are stalemates and dead positions:
1,964 positions separate `standard` from normal play and from the natural games (e.g. the bare-king
stalemate `8/8/8/8/Kbk5/8/8/8 w`), 1,016 separate it from passing and lose-your-turn, and 7 dead
positions separate the games that keep the insufficient-material rule from those that do not. The
castling differences (the 508 real checkmates escaped by castling, REPORT §3.2) appear as "lost"
in every standard game and "undecided" within 5 plies in every natural game, so they are not
counted as certain. They are covered by the bridges below and by position A.

### 3.3 A worked example: mating a king that may pass

`8/8/8/8/8/2k5/4Q3/1K6 w - - 0 1` (White: Kb1, Qe2; Black: Kc3), White to move.

```
8 . . . . . . . .
7 . . . . . . . .
6 . . . . . . . .
5 . . . . . . . .
4 . . . . . . . .
3 . . k . . . . .
2 . . . . Q . . .
1 . K . . . . . .
  a b c d e f g h
```

**Standard chess: mate in 4, by zugzwang.** 1. Qe4 Kb3 2. Qd4 Ka3 3. Kc2 Ka2 4. Qa4#. After
1. Qe4 Black must leave c3, and every legal move walks toward the corner.

**With passing: mate in 10.** Black stays on c3 and passes. A king away from the edge cannot be
mated, so White has to do all the work with his own moves. A line of best play, where
Black passes whenever passing is one of his best options (– = pass):

> 1. Qe4 – 2. Qd5 – 3. Kc1 – 4. Kd1 – 5. Ke2 – 6. Qc5+ Kb3 7. Kd3 Kb2 8. Qb5+ Ka3 9. Kc3 Ka2
> 10. Qb2#

Every alternative is valued by the exact tablebase (`chess explain`). For Black, the table gives
the White move on which each option is mated:

| move | White plays (other moves that mate as fast) | Black's options: mated on White's move … | Black plays |
|---|---|---|---|
| 1 | Qe4 (Qe5+, Qd1) | Kb3 8, Kd2 8, **pass 10** | pass |
| 2 | Qd5 (Kc1, Ka2) | Kb4 8, **pass 10** | pass |
| 3 | Kc1 (none) | Kb4 9, **pass 10** | pass |
| 4 | Kd1 (none) | Kb2 8, Kb4 10, **pass 10** | pass |
| 5 | Ke2 (none) | Kb2 9, Kb4 10, Kc2 10, **pass 10** | pass |
| 6 | **Qc5+** (none) | in check, no pass: Kb3 10, Kb2 10 | Kb3 |
| 7 | Kd3 (Kd2) | Ka4 9, Ka2 9, Kb2 10, pass 10 | Kb2 |
| 8 | **Qb5+** (Qc2+, Qb6+, Qb4+) | in check, no pass: Ka3, Ka2, Ka1, Kc1, all 10 | Ka3 |
| 9 | Kc3 (Kc2) | Ka2 10, pass 10 | Ka2 |
| 10 | Qb2# (after a pass on move 9, with the king on a3: Qb3#) | | |

The mate takes four phases:

1. **The queen builds a box (moves 1–2).** After 2. Qd5 the king on c3 has a single move, to b4:
   the queen covers b3, c4 and the d-file, and the white king on b1 covers b2 and c2. Passing is
   Black's best defence. Moving loses faster: after 1... Kb3 or 1... Kd2, mate comes two moves
   sooner.
2. **The white king walks around (moves 3–5).** From b1 it cannot approach directly, since b2 and
   c2 touch the black king. So it detours via c1, d1 and e2, heading for d3. At moves 3 to 5
   no other White move mates as fast. Black keeps passing (4... Kb4 and 5... Kb4 or 5... Kc2 are
   no worse).
3. **Checks do the pushing (moves 6 and 8).** A player in check cannot pass. 6. Qc5+ drives the
   king to b3 or b2, 7. Kd3 brings the white king up, and 8. Qb5+ drives the king to the a-file
   or the first rank.
4. **The net closes without zugzwang (moves 7–10).** Passing is never better than moving here: at
   move 7, Kb2 and the pass are equally good; move 8 is a check; and at move 9 both options are
   mated on move 10. After 9. Kc3, if 9... Ka2 then 10. Qb2# (the queen is protected by the king),
   and if Black passes with the king on a3, then 10. Qb3#.

So the defender is never made to move except by check. The mating net is built by the queen's
moves, the king's moves and two checks. This is why every K+Q v K win survives passing, while
K+R v K, where the rook covers too few squares to stop the defending king stepping aside, needs
zugzwang to drive the king into the corner (§3.1).

The tablebase's own main line is different but just as long: 4... Kb4 (instead of passing)
5. Qc6 Ka5 6. Qb7 Ka4 7. Qb6 Ka3 8. Qb5 Ka2 9. Kc2 Ka3 10. Qa5#. A mate in 10 against a king that
may pass, where standard chess needs 4, is the longest increase (+6 moves) found in K+Q v K
(128 of the 144,508 wins).

Reproduce:

```sh
B=.lake/build/bin/chess
$B line Q standard "8/8/8/8/8/2k5/4Q3/1K6 w - - 0 1"          # mate in 4 (7 plies)
$B explain Q standard-passing "8/8/8/8/8/2k5/4Q3/1K6 w - - 0 1"  # mate in 10, every alternative valued
$B play standard-passing --fen 8/8/8/8/8/2k5/4Q3/1K6 w - - 0 1 \
   Qe4 0000 Qd5 0000 Kc1 0000 Kd1 0000 Ke2 0000 Qc5+ Kb3 Kd3 Kb2 Qb5+ Ka3 Kc3 Ka2 Qb2#
```

### 3.4 Real stalemates: does passing turn them into wins?

The essay makes a prediction about real games. When a stalemate arises, the player causing it
often has far more material, "and in most of these cases, if passing were allowed, then the
instigating player would be able to push through a win. Indeed, I believe that most stalemates
that arise in practice have this feature".

**Design.** The positions are the 1,956 games ending in stalemate among the first 299,675 games
of the Lichess dump (REPORT §3.2), in their final position. Each is valued for the stalemating
side under two games:
* standard chess with passing, the variation of the prediction;
* lose-your-turn chess, the medieval rule quoted by Hamkins from Davidson, for comparison. There
  the stalemated player passes once, and must then move whenever he can.

The methods:
* The 387 positions with three pieces are solved exactly, in one retrograde analysis of the
  1.77M positions reachable from them (`chess exact-batch`).
* The 1,569 others are searched to 8 plies, then to 10 plies for those still undecided
  (`chess solve-batch`). A win found by search is certain. A draw can only be established
  exactly, so these positions are either wins or undecided.

Material is counted as pawn 1, knight and bishop 3, rook 5, queen 9. The stalemated player never
wins.

| stalemates | n | with passing: win / draw / undecided | lose-your-turn: win / draw / undecided |
|---|---|---|---|
| all | 1,956 | **1,604 (82.0%)** / 224 (11.5%) / 128 (6.5%) | 1,715 (87.7%) / 140 (7.2%) / 101 (5.2%) |
| stalemating side 5 points or more ahead | 1,507 | **1,470 (97.5%)** / 0 / 37 | 1,485 (98.5%) / 0 / 22 |
| 1 to 4 points ahead | 420 | 134 (31.9%) / 205 (48.8%) / 81 | 230 (54.8%) / 121 (28.8%) / 69 |
| level or behind | 29 | 0 / 19 / 10 | 0 / 19 / 10 |

| most frequent material (stalemating v stalemated) | n | with passing: win / draw / undecided | lose-your-turn: win / draw / undecided |
|---|---|---|---|
| K+P v K | 212 | 11 / **201** / 0 | 95 / 117 / 0 |
| K+Q v K | 142 | 142 / 0 / 0 | 142 / 0 / 0 |
| K+B+P v K | 50 | 13 / 0 / 37 | 15 / 0 / 35 |
| K+P+P v K | 49 | 46 / 0 / 3 | 47 / 0 / 2 |
| K+Q v K+P | 25 | 22 / 0 / 3 | 23 / 0 / 2 |
| K v K+P | 19 | 0 / 19 / 0 | 0 / 19 / 0 |

Findings:
* **Hamkins is right.** With passing, at least 82% of real stalemates become wins for the
  stalemating side, and at most 88.5% (1,956 minus the 224 exact draws). His "far more material"
  case is a rook's worth or more, which covers 77% of the stalemates. There the wins reach 97.5%,
  and no draw is found. The commonest case is K+Q v K (142 stalemates, all won): with passing, the
  stalemate that saved the defender is simply gone. The 37 undecided positions of this group are
  mostly rook endings with pawns, where a pawn must queen first, beyond the horizon.
* **The exception is the most common stalemate, K+P v K** (212 games, 11%): with passing, 201
  stay drawn. They fall into only seven patterns. In the table, colours and board sides are
  normalized so that White stalemates and the pawn is on the e- to h-file. The last column
  values, exactly, the position one move before the stalemate, replayed from the PGN
  (`results/kpk_stalemates.txt`).

  | pattern (Black stalemated) | games | with passing | lose-your-turn | one move earlier, standard chess |
  |---|---|---|---|---|
  | rook's pawn, `7k/7P/7K` | 79 | draw | draw | draw (79) |
  | rook's pawn, `7k/7P/6K1` | 38 | draw | draw | draw (38) |
  | knight's pawn on the 7th, `6k1/6P1/6K1` | 39 | draw | win in 5 moves | draw (39) |
  | bishop's pawn on the 7th, `5k2/5P2/5K2` | 36 | draw | win in 7 moves | draw (35), after a capture (1) |
  | centre pawn on the 7th, `4k3/4P3/4K3` | 9 | draw | win in 9 moves | draw (9) |
  | knight's pawn on the 6th, `7k/5K2/6P1` | 10 | win in 3 moves | win in 3 moves | win (7), draw (3) |
  | knight's pawn on the 6th, `5K1k/8/6P1` | 1 | win in 4 moves | win in 4 moves | after a capture (1) |

  - **The stalemate cost nothing.** In 203 of the 212 games, the position one move earlier was
    already a standard draw. The stalemate was how a drawn ending ended, a single pawn up, not
    a blunder that threw away a win. K+P v K is therefore the exception in number, but it lies
    outside the case Hamkins describes ("far more material"), and does not refute him.
  - **The rook's pawn** (117 games): the defending king sits in the corner. It is drawn with
    passing and with lose-your-turn alike. Only normal play, by definition, and natural chess,
    where the stalemated king must step into check, count it as a win.
  - **The pawn on the 7th** (84 games): the defending king stands on the queening square, and the
    attacking king directly behind the pawn. The attacker lacks a single tempo, which only
    zugzwang could give him. Lose-your-turn gives it: in `5k2/5P2/5K2/8/8/8/8/8 b` (Lichess
    mPijDxzR), after Black's forced pass, 1. Ke6 Kg7 2. Ke7 Kg6 3. f8=Q, and mate follows. With
    passing, Black passes back for ever and the white king can never take f8 away from him.
  - **The knight's pawn on the 6th** (11 games) is the only pattern that passing wins: the pawn
    queens with check. In `7k/5K2/6P1/8/8/8/8/8 b` (Lichess 9IakqfEz), after Black's pass,
    1. g7+ Kh7 2. g8=Q+ Kh6 3. Qg6#. Seven of these were real blunders, standard wins thrown
    away by the stalemating move (Lichess hD3Mtb8J, `k7/2K5/8/1P6/8/8/8/8 w`: 80. b6??
    stalemate), and passing wins all seven back.
* **The bishop and rook's pawn.** Most of the undecided K+B+P v K positions (26 of 37) are this
  fortress, with a bishop of the wrong colour: the defending king sits in the corner. They are
  drawn in standard chess and very likely with passing too, but with four pieces they are beyond
  the exact solver.
* **So the affinity Hamkins sees between passing and normal play holds in practice.** It breaks
  where only zugzwang could win, as in the K+P v K stalemates with the pawn on the 7th, which
  lose-your-turn wins and passing does not. Normal play wins all 1,956 stalemates by
  definition, lose-your-turn 88–93%, and passing 82–88%.

Reproduce: `scripts/stalemates_passing.sh` writes `results/stalemates_passing.tsv` (one row per
game) and `results/stalemates_passing_summary.md`.

---

## 4. Hamkins' claims, checked

| claim in the essay | verdict | evidence |
|---|---|---|
| (1) after 1... Nc7#, White has no move: a standard win, a natural draw | ✓ | `hamkins_no_move_mate` |
| ... and no other black move wins in natural chess | ✓ within 9 plies (bounded; the essay's argument is informal) | `hamkins_no_move_mate` |
| (2) the stalemate after ...Qb5 (D. Madore) is a natural Black-to-win-in-1 | ✓ | `hamkins_madore_stalemate` |
| (3) after 1... Qd2#, 2. O-O wins for White in natural chess | ✓ within 7 plies, in all four natural games | `hamkins_castling`, `hamkins_castling_grid` |
| the mate by pinned pieces shows no deviation | ✓ | `hamkins_pinned` |
| 1... Qc8 is not a natural checkmate (2. Rxa3 takes the king first) | ✓ | `hamkins_qc8` |
| a standard stalemate is a natural stalemate or an immediate loss | ✓ no exception in 15.5M random positions and 1,956 real stalemates | REPORT §3.2, §3.4 |
| normal standard chess and normal natural chess differ, by castling | ✓ | position A |
| "standard chess with passing is the same as normal standard chess with passing" | ✓ by construction: a player not in check can always pass | §1, choice 5 |
| the double stalemate `k7/P1p5/KpP5/1P6/8/8/8/8 b`: a draw by perpetual passing in standard chess with passing, a White win in natural chess, a draw in natural chess with passing | ✓ exact | `hamkins_double_stalemate` |
| K+R v K `8/8/8/8/2r5/4k3/8/3K4 w`: a Black win in standard chess "even with normal play", a draw with passing | ✓ exact | `hamkins_rook_zugzwang`, `tests --deep` |
| "the standard king + rook versus king checkmate requires zugzwang" | ✓ to drive the king to the corner: with passing, 99.1% of the decisive K+R v K positions become draws, no win starts with the lone king off the edge, and on the edge, outside the corners, only mates in one remain. The 2,804 surviving wins are positions where the king is already caught: a mate in one on the edge (1,512), or the king in a corner with the attacking king 2 or 3 squares away (1,292, mates in 2 to 5 moves). They contradict only the literal reading "no K+R v K win without zugzwang". K+Q v K, in contrast, needs no zugzwang: all its wins survive passing | `results/grid_endgame_KRK.txt`, `results/krk_passing.txt`, `chess line` |
| "most stalemates that arise in practice" would be wins for the stalemating side if passing were allowed | ✓ at least 82.0% of 1,956 Lichess stalemates (97.5% when the stalemating side is a rook or more ahead). But K+P v K, the most frequent stalemate (212), stays drawn in 201 cases. In 203 of the 212, the position was already a standard draw one move earlier, a single pawn up: outside his "far more material" case | §3.4, `results/stalemates_passing_summary.md`, `results/kpk_stalemates.txt` |
| a player stalemated in standard chess cannot force a win when passing is allowed | ✓ none of the 1,138 standard stalemates of the five endgames is a win for the stalemated player with passing | `results/grid_endgame_K*K.txt` |
| the lose-your-turn position B: stalemate in standard and natural chess, a draw by passing in both, a Black win in lose-your-turn chess in both | ✓ exact | `hamkins_lose_turn` |
| "with the normal play convention [...] the correspondence works perfectly" (closing sentence) | ✗ as stated (position A, and the essay's own "Normal chess" section); ✓ once castling is freed in standard chess (§5) | bridges |

---

## 5. Why: one bridge per convention

Why do the games group as they do? The difference between a standard game and a natural game of
the grid splits into a time shift (the king is captured one move after the mate) and a few rules.
Each bridge of §2 isolates those rules:

| natural game | naturalized standard game (rules changed in the standard game) | tablebases: disagreements / positions | game positions: certain disagreements | natural wins exactly 2 plies longer |
|---|---|---|---|---|
| `natural` | `standard-naturalized` (free castling, no dead position, stalemate loses unless nothing can move) | 0 / 1,945,584 | 0 / 16,783 (7,501 verdicts changed by the naturalization, all matched) | all |
| `natural-normal` | `standard-normal-naturalized` (free castling) | 0 / 1,945,584 | 0 / 16,783 (522 changed, 509 of them castling escapes; all matched) | all |
| `natural-passing` | `standard-passing-naturalized` (free castling, no dead position) | 0 / 1,945,584 | 0 / 16,783 (5,075 changed, all matched) | all |
| `natural-lose-turn` | `standard-lose-turn-naturalized` (free castling, no dead position, a stalemated player with a piece to move loses) | 0 / 1,945,584 | 0 / 16,783 (7,270 changed, all matched) | all |

"Changed" counts the positions where the naturalized standard game gives a different verdict
than the standard game of the same convention (castling freed, dead-position rule dropped,
stalemate convention transposed); on all of them the natural game follows the naturalized one.
"All": on every position decisive in both games (994,362 tablebase positions per bridge, 550,580 for
passing; 2,653 game positions, 1,482 for passing), the natural win is exactly 2 plies longer.

Read column by column, the bridges explain the grid:

* **Normal play and passing transpose unchanged.** For these two conventions the naturalized game
  is the standard game of the same convention plus free castling (the dead-position rule, kept by
  `standard-passing`, never changes a value there). So `natural-normal` is `standard-normal` with
  castling freed from the attacked-squares condition, and the same for passing. **Modulo castling,
  these two pairs are equivalent**, and nothing else is.
* **Ordinary and lose-your-turn do not transpose.** A standard stalemate in which some piece can
  still move is a loss in natural chess, whatever the convention, because the stalemated player
  must move it. So the standard counterpart of `natural` is not `standard` but normal play with an
  exception for positions where nothing can move (a draw), and the counterpart of
  `natural-lose-turn` is normal play with the same exception (a pass). In positions where some
  piece can always move (all of the tablebases), both are normal play.
* **Castling separates every standard game from every natural game.** All four bridges free
  castling, and position A shows that this change alone flips a result under every convention.

Hamkins' closing sentence, "with the normal play convention by which stalemate is a win for the
player causing it, then the correspondence works perfectly", is therefore right in a precise
sense: under normal play (and also under passing), checkmate is the necessary capture of the king
one move later, **provided castling obeys the same rule in both games**. With the FIDE castling
rule in standard chess and free castling in natural chess, position A breaks the correspondence
under every convention, as the essay's own "Normal chess" section observes.

---

## 6. Conclusion

**Answer to Hamkins' question 4.** Of the eight games obtained from {standard, natural} ×
{ordinary, normal, passing, lose-your-turn}, no two are equivalent. The comparisons the essay
leaves open are all settled by its own diagrams, once each is evaluated in every game (§3).

**Structure.** Two independent rule differences account for everything observed:

1. **castling** across attacked squares, which separates the standard family from the natural
   family under every convention, and is the *only* difference left between normal-play standard
   and natural chess, and between standard and natural chess with passing;
2. **the convention for immobility**, which separates the games within each family. Passing at
   any time removes zugzwang, in both families. Otherwise, in standard chess the convention
   matters in every stalemate, while in natural chess normal play and lose-your-turn matter only
   in the rare positions where a player cannot move at all.

Everything else is a time shift: natural wins are exactly two plies longer, on every position
where both games are decisive.

**How much.** Normal play, lose-your-turn and the natural games change only stalemates and what
follows from them: a fraction of the draws of K+P v K (up to a third), and the stalemate traps
of K+B v K and K+N v K. Passing changes far more: it erases 98% of the K+R v K wins, and none of
the K+Q v K wins, which shows exactly where zugzwang is needed in the basic mates. On real
stalemates, passing gives the stalemating side the win in at least 82% of the games, as Hamkins
predicted. K+P v K, the most frequent, is the exception. Those games were almost all drawn
one move before the stalemate, and only zugzwang could win them: lose-your-turn supplies it, and
passing removes it.

**What the formalization forced.** The essay's variations are described in a sentence each. As
rule sets they need decisions that change results: a pass must be forbidden out of check (or
checkmate disappears); normal play must drop the insufficient-material rule (or K+B v K, which
can be won by stalemate, is declared drawn); and "lose your turn" means something different in
natural chess, where a stalemated player still has moves. Each decision is a named rule, so it can
be changed and its effect measured.

**Limits.** The exact values cover only 3-piece endgames, without castling and without blocked
positions; castling and immobility rest on the game positions (bounded search, 3 and 5 plies) and
on the certified witnesses. The bridges are tested, not proved. The move counters are ignored by the
exact solver. Of the real stalemates of §3.4, 6.5% (with passing) and 5.2% (lose-your-turn) stay
undecided: they have four pieces or more and need more than 10 plies.

## 7. Not done: penultimate and antepenultimate chess

The essay's questions 2 and 3 (standard versus natural *penultimate* chess, won by
"checkmate-mate", and whether natural penultimate chess is equivalent to natural chess) are not
addressed here. The framework can express them: the winning condition is an ending rule that calls
the bounded solver ("the opponent is mated in one whatever he does"), and Hamkins' suggestion of
forbidding a player to leave himself exposed to checkmate-check is a legality rule of the same kind.
The question is whether the four rule differences found here (castling, stalemate, dead position,
draw timing) still explain everything one level up, or whether new ones appear.

## 8. Reproducing

```sh
lake build && lake build tests && .lake/build/bin/tests --deep
B=.lake/build/bin/chess
for m in B N Q R P; do $B grid-endgame $m > results/grid_endgame_K${m}K.txt; done
cut -f1 data/positions/naturalized_test.fen | $B grid-verdicts 3 > results/grid_verdicts.tsv
python3 -I scripts/summarize_grid.py results/grid_verdicts.tsv > results/grid_verdicts_summary.md
python3 -I scripts/variability_matrix.py $B std=standard std-normal=standard-normal \
  std-passing=standard-passing std-lose-turn=standard-lose-turn nat=natural \
  nat-normal=natural-normal nat-passing=natural-passing nat-lose-turn=natural-lose-turn
$B exact standard-passing "8/8/8/8/2r5/4k3/8/3K4 w - - 0 1"
$B longest-wins R standard-passing 3000                    # the K+R v K wins that survive passing
$B longest-wins R standard-passing 5000 | python3 -I scripts/krk_passing.py > results/krk_passing.txt
$B line R standard-passing "4RK1k/8/8/8/8/8/8/8 w - - 0 1"   # a line of best play
scripts/stalemates_passing.sh                              # §3.4: the real stalemates
python3 -I scripts/kpk_stalemates.py > results/kpk_stalemates.txt   # §3.4: the K+P v K ones
$B explain Q standard-passing "8/8/8/8/8/2k5/4Q3/1K6 w - - 0 1"  # the worked example of §3.3
```
