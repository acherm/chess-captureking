# Standard chess vs natural chess, in Lean 4

> *Why do we play chess for checkmate instead of playing more naturally to capture the enemy king?*
>
> J. D. Hamkins, [*Every game of chess ends prematurely*](https://www.infinitelymore.xyz/p/chess-games-end-one-move-early) (Infinitely More, October 2026)

After all, are check and checkmate really needed as part of chess rules? In Hamkins' words, "games of chess thus seem always to end one move early—the
curtains close just before the climax." His *natural chess* drop the rules about
check and checkmate, and play on until a king is actually captured. Surely that changes nothing?
Hamkins says that natural chess is "almost equivalent to standard chess", but "not quite fully
equivalent".

This project formalizes both games in Lean 4 and checks the
claim, by proofs, by perft, on Lichess positions, on random positions, by targeted search, and
with complete endgame tablebases.

## TL;DR (beware of teasing!)

**Natural chess is not equivalent to standard chess**, and all three kinds of divergence
announced by Hamkins occur:

| kind | example position | standard chess | natural chess |
|---|---|---|---|
| (1) a standard win where the king cannot be captured: castling out of check | Lichess [RSJfq4Su](https://lichess.org/RSJfq4Su) after 9... Qxe2#: `r1b1kb1r/ppp1pppp/5n2/4N3/3n1B2/N7/PPP1qPPP/R3K2R w KQkq - 0 10` | 0-1, checkmate | 10. O-O, the king is safe and the game goes on |
| (1') a standard win where the mated side cannot move at all | `KN1q4/PPpPk3/PnP5/8/8/8/8/8 w - - 0 1` | 0-1, checkmate | draw: no move, so the king can never be captured |
| (2) a standard draw that is a natural win: stalemate | Lichess [NZ2sKoBF](https://lichess.org/NZ2sKoBF) before move 72: `7k/7P/6K1/8/8/8/8/8 w - - 1 72` | draw (72. Kh6 is stalemate) | 1-0: 72. Kh6!, and every black move exposes the king |
| (2') a standard draw that is a natural win: dead position | Lichess [A8iBWO7I](https://lichess.org/A8iBWO7I), final position: `8/8/8/8/8/8/8/4k1bK b - - 0 108` | draw, game over (insufficient material) | 0-1: 108... Kf2 and White must expose his king |
| (3) **opposite outcomes** | `8/8/8/8/1Q6/3k4/4qP2/R3K3 w Q - 0 1` | **0-1**, White is checkmated | **1-0**: 1. O-O-O+ (out of and through check) wins within 5 plies |
| (new) a timing effect of the 75-move rule | `k7/8/1K6/8/8/8/8/2R5 w - - 148 120` | 1-0: 1. Rc8# (mate takes precedence) | draw: 1. Rc8 Kb7 reaches 150 half-moves before the king can be taken |

How often, and how much:
* **Perft** agrees from the initial position up to depth 3 and differs at depth 4: 197,742 natural
  vs 197,281 standard. The 461 extra sequences go through moves that expose the king, e.g.
  1\. c3 d6 2. Qa4+ h6??, legal only in natural chess and answered by 3. Qxe8. The other reference
  positions differ already at depth 1 or 2.
* **Real games** (first 300k Lichess games of September 2026):
  - legal moves differ in 31% of random positions, but these extra moves almost never change who wins;
  - **508 of 72,691 checkmates (0.70%)** could be escaped in natural chess by castling out of check;
  - **all 1,956 stalemates** are natural wins for the stalemating side.
* **Exact endgame tablebases**: no standard win changes, but **33% of the KPK draws** are decisive
  in natural chess, and so are 2.2% of KBK and 0.8% of KNK positions (dead positions in standard chess).
* **What exactly differs.** Every difference in who wins comes from one of three rules:
  - castling across attacked squares (FIDE 3.8.2.2);
  - stalemate (5.2.1);
  - the dead position rule (5.2.2), plus the timing of automatic draws.

  Two "bridge" rule sets make this exact, with every win taking exactly one move longer in natural chess:
  - `standard-naturalized` = standard chess changed on those points; it has the values of natural chess;
  - `natural-standardized` = natural chess plus those rules restated with attacked kings; it has the
    values of standard chess.

  Both bridges hold on 1.9M endgame positions and 16,783 game positions, with 0 exceptions.
* **Machine-checked**:
  - proved for every position: every standard legal move is a natural legal move;
  - checked by evaluation (`native_decide`): the key fact about every position in the table above
    (theorems in `Chess/Theorems.lean`). That the KPK position is an exact standard draw comes from
    the tablebase;
  - tested: perft matches the reference tables (initial position to depth 6), and there are 0
    mismatches with python-chess on 160,257 Lichess positions and 20,000 games.

**Full results and the list of interpretation choices: see [REPORT.md](REPORT.md).**
**How the variants are implemented (variability mechanism): see [VARIABILITY.md](VARIABILITY.md).**
**Every rule traced back to the FIDE Laws of Chess, and natural chess as an edit of the Laws: see [RULES.md](RULES.md).**

## Design and Variability

Rules are first-class, named, documented values (each one cites its FIDE article; [RULES.md](RULES.md)
lists them all with their sources). A *rule set*
is a list of rules of five kinds:

| kind | role | examples |
|---|---|---|
| movement | propose candidate moves | `pawnPush`, `enPassant`, `knight`, `castling` (FIDE 3.1–3.8) |
| legality | forbid candidates | `noSelfCheck` (3.9.2), `castlingNotOutOfCheck` (3.8.2.2) |
| ending | end the game (first applicable wins) | `checkmate`, `stalemate`, `deadPosition`, `seventyFiveMoves` |
| claim | allow a draw claim | `threefoldRepetition`, `fiftyMoves` |
| validity | vet positions (FEN input) | `oneKingEach`, `opponentNotInCheck` |

Variants are built with combinators (`withoutLegality`, `withLegality`, `replacingEnding`, …)
and `chess diff A B` prints the rule-level diff. Natural chess is such a delta on standard chess
and leaves the standard chess code untouched (`Chess/Rules/Natural.lean`):

```lean
def rules : RuleSet :=
  Standard.rules
    |>.renamed "natural"
    |>.withoutLegality [Standard.noKingCapture, Standard.noSelfCheck,
                        Standard.castlingNotOutOfCheck, Standard.castlingNotThroughCheck]
    |>.withLegality [noMoveAfterKingCapture]
    |>.withoutEndings [Standard.checkmate, Standard.stalemate, Standard.deadPosition]
    |>.withEndingsFirst [kingCaptured, noLegalMove]
    |>.withoutValidity [Standard.oneKingEach, Standard.opponentNotInCheck]
    |>.withValidity [kingsAtMostOneEach]
```

Every piece of analysis code (perft, SAN, games, bounded search, tablebases, comparisons) is
generic in the rule set.

| file | content |
|---|---|
| `Chess/Core/` | squares, pieces, moves, boards, positions, FEN, attacks, playing a move (rule-independent) |
| `Chess/Rules/Framework.lean` | rule sets, legal moves, game status, combinators, `describe`, `diff` |
| `Chess/Rules/Movement.lean` | FIDE movement rules (shared by both games) |
| `Chess/Rules/Standard.lean` | FIDE legality, ending, claim and validity rules |
| `Chess/Rules/Natural.lean` | natural chess, as a delta |
| `Chess/Rules/Variants.lean` | alternative interpretations (pass, no-move-loses, keep dead position, keep FIDE castling, …) and the two "bridges": `standard-naturalized` (standard chess with the values of natural chess) and `natural-standardized` (natural chess with the values of standard chess) |
| `Chess/Notation/San.lean`, `Chess/Game.lean` | SAN, games (sequences of moves, legality with explanations, status with history) |
| `Chess/Perft.lean` | perft, divide, perft counters (captures, e.p., castles, promotions, checks, …) |
| `Chess/Solver.lean` | bounded game-theoretic search (`canWin`, `mustLose`, `solve`) |
| `Chess/Analysis/` | comparison of rule sets, divergence explorer, random positions, hunts, tablebases |
| `Chess/Theorems.lean` | theorems: standard legal moves ⊆ natural legal moves; concrete non-equivalences |
| `Main.lean` | command-line interface |
| `Tests.lean` | test suite |
| `scripts/` | Lichess extraction, cross-validation against python-chess, summaries |

## Build and run

Requires Lean 4.29 (`lean-toolchain`); python-chess for the scripts.

The executable is `.lake/build/bin/chess`; it is not on your `PATH`. Either run it through
Lake, which builds it first if needed:

```sh
lake exe chess diff standard natural
```

or call the binary (`./.lake/build/bin/chess diff standard natural`), or add an alias
(`alias chess=$PWD/.lake/build/bin/chess`) to type `chess diff standard natural` as below.

```sh
lake build                       # library, theorems and the `chess` executable
lake build tests && .lake/build/bin/tests [--deep]
B=.lake/build/bin/chess
$B rules natural                 # all rules, with their FIDE references
$B diff standard natural         # what natural chess changes
$B diff standard standard-naturalized     # the rule part of the difference, applied to standard chess
$B diff natural natural-standardized      # ... and undone in natural chess
$B show natural "<FEN>"          # board, legal moves (SAN), status
$B play standard e4 f6 Qh5 Kf7   # -> "e8f7 is forbidden by [noSelfCheck (FIDE 3.9.2 …)]"
$B perft natural 4               # 197742 (standard: 197281)
$B stats standard 5              # perft counters, as on chessprogramming.org
$B divergences standard natural 5 10 5    # where the two games start to differ
$B solve natural 5 "<FEN>"       # bounded search
$B hunt opposite5 sparse 6 32000000 3 11  # search for "opposite outcome" positions
$B endgame P standard natural 5  # KPK tablebases under both rule sets, compared
```

Data: `scripts/extract_lichess.py` extracts positions from a Lichess dump. Here: the first 300k
games of September 2026. The raw PGN (700 MB) is not in the repository; REPORT.md §5 shows how
to download it again. The extracted positions are in `data/positions/`. `scripts/crossval.py` checks the
engines against python-chess; `scripts/summarize_compare.py` and `scripts/attribute.py` summarize
comparisons and attribute value differences to rules; `scripts/perft_tables.sh` builds the perft
table of the variants. Results are in `results/`.

## How this was built: an AI agent in the loop

This project was produced in one session (18 October 2026) by an AI coding agent, Claude Code
running Claude Opus 5.5, working on a 16-core Mac. The agent had a shell, file editing and web
access. A human (acherm) wrote the specification and steered the work with follow-up questions.
The agent planned, wrote all the code and documents, ran all the experiments, and reported. The
prompts are reproduced verbatim below.

**Division of labour**
* *Human*: the problem and its methodology (three steps), chess expertise, and the questions that
  sharpened the results. They led to the anatomy of a perft divergence, the precise definitions of
  "difference", the representative examples, the "standardized" natural chess (whose first version
  failed, revealing the dead-position timing effect), and the variability documentation.
* *Agent*:
  - grounded the rules in sources: the preview of Hamkins' essay, his blog post on simplified chess,
    the FIDE Laws (2023), and the chessprogramming.org perft tables;
  - designed the rule framework;
  - implemented the engines, the tools and the Lean proofs;
  - fetched and processed the Lichess data;
  - ran the experiments and wrote REPORT.md and VARIABILITY.md.

**How the agent's work was checked.** The agent was not trusted on its own word; every claim
rests on an independent check:
* perft and its detailed counters against the published tables;
* python-chess (a widely used, independent library) as an oracle on 160,257 real positions and
  20,000 games;
* an independent Python implementation of natural chess's moves, for natural perft;
* cross-checks between variants that must agree (e.g. two different deltas giving the same perft);
* Lean proofs for the general facts, and `native_decide` for the concrete positions;
* a test suite (65 tests).

**Mistakes made by the agent and caught by these checks**, kept here because they show what such
a workflow needs:
* the convention for "discovered checks" in the perft tables was first guessed wrong (found by
  matching the tables);
* the tool explaining *why* a move is illegal blamed the wrong castling rule in some positions,
  which skewed one column of statistics (found, fixed, statistics recomputed);
* about ten test positions written by the agent were themselves wrong (e.g. a king capturing into
  check);
* the first "standardized natural chess" turned some standard wins into draws (found by the
  tablebase comparison). This was not only a bug: it revealed a genuine rule interaction;
* a performance optimization silently did not apply until restructured;
* a few statements in the report draft were stronger than the evidence and were weakened.

**What remains to trust**:
* `native_decide` relies on the Lean compiler;
* the equivalences of the two bridges are tested exhaustively on endgames and extensively on
  positions, but not proved;
* bounded searches are bounded;
* hunted positions are plausible, but not proved to be reachable from the initial position.

<details>
<summary>The prompts (verbatim)</summary>

**Initial prompt**

> @acherm, a FIDE Chess Master and computer science professor, quotes mathematician Joel David Hamkins to highlight that directly capturing the opponent's king as the win condition is not equivalent to standard chess checkmate rules.
> Hamkins' essay describes standard chess as ending "one move early" before the king is actually taken, proposing "natural chess" that drops check and checkmate rules in favor of continuing play until capture.
> Positions exist where standard chess checkmate wins but natural chess allows continued play with different legal moves like castling through check, leading to opposite outcomes.
>
> I'm acherm
>
> I want to prove that "natural chess" is indeed non-equivalent to standard chess
> The methodology is as follows.
> First step:
>  * for standard chess, write in Lean a chess "engine" that controls the legality of all moves in a certain position and the ability to make and control the legality of a sequence of moves... Also control that the engine is capable of stating whether a game is over (and who's winning and whethere it's a draw). I'm using the term engine here to document I want facilities to reason and implement rules, but I don't want necessarily to play games.
> * adopt a modular approach for rules' implementation to be able to activate/decative some rules, or to add/override rules
> * favor code readability and understanding over pure performance
> * verify with perft https://chessprogramming.org/Perft_Results the correctness of the engine
>
> Second step:
>  * for natural chess, write a Lean engine by customizing/extending the Lean engine of standard chess written in previous first step. That is, you activate/deactivate/add/override some rules of the original standard chess engine.
>  * a good property is to make as little modifications as possible of the original code base. If it's possible, I would like to have a clear "diff". Preprocessor directives and compile-time options can be leveraged to implement variations, but feel free to choose any implementation technique you want.
>  * verify with perft (depth 0, 1, 2 only) that you're obtaining the same behavior and numbers (eg number of checks) as for standard chess
>
> Third step:
>  * show that perft at a certain depth differs in standard chess and natural chess... report positions leading to this situation
>  * in addition to perft, pick some random positions coming from Lichess database says, and involving check and checkmate... verify whether such positions are "equivalent" in standard and classical chess (eg same judgment of whether it's white win/draw/black win, different legal moves). Quantify the differences and how much positions differ.
>  * pick truly random positions you generate and same: quantify differences
>  * try to find on your own positions that differ, leveraging your two engines and infrastructure... you can well program a generator seeking to such position
>
> If my specification is unclear or/and it's pretty clear BUT some decisions are ambigous and deserve some interpretation, please report. It's also part of the exerice and inquiry to try formalizing rules in a sound and complete way.

**Follow-up prompts**

> at depth=4 The 461 extra sequences come from 134 positions, e.g. 1.c3 d6 2.Qa4+. => what does it change exactly, excerpt the fact it is not "check"? it does not change the status (winning/draw)... but yea it does change the legal moves then (eg black can well play 2...h6, it's legal in natural chess but not in standard chess, and it's losing since white can take the king...)...
>
> for Position 3 depth 1 of perft, what does differ exactly? what's your precise definition of "difference", in Lean?
>
> btw can you show up three representative examples of the three rules leading to differences?
>
> besides, have you tried to implement a "naturalized" standard chess? or a "standardized" natural chess?
> what could be the "diff"?
>
> btw how to make "chess diff standard natural" work?

> from a variability point of view, how did you implement the different variants? compile-time? or you load on-demand rules with core (standard rules) + adding of specific rules or activation of standard chess rules?

> please document this in VARIABILITY.md

> the README.md is excellent but missing a tldr; in terms of key results (the three kinds of situations that differ, even some positions identified, etc.)
>
> I also think it's nice to include the original prompt I give, and the methodology of leveraging an AI agent

</details>
