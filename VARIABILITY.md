# Variability: how the rule variants are implemented

This project implements a small *family* of chess games: standard (FIDE) chess, natural chess
(Hamkins), and nine other variants that encode alternative interpretations or "bridges" between
the two. This document explains the variability mechanism, what varies and what does not, which
analyses the mechanism enables, and its limits.

## In one paragraph

Variability is **compositional and delta-based, with rules as first-class runtime values**. There
is no preprocessor, no compile-time option and no boolean feature flag. A rule set is a record of
lists of named rules. `Standard.rules` is the base product. Every other variant is obtained by
applying *delta operations* (remove, add, replace, insert-after) to an existing rule set. All
variants are compiled into the same binary, built once at program start, and selected **at runtime
by name** (`chess perft natural-pass 3`). The standard code is never modified by a variant:
`Chess/Rules/Natural.lean` only *uses* `Standard.rules`.

| aspect | choice |
|---|---|
| kind of variability | compositional: rules are separate units; no `#ifdef`-style annotations in shared code |
| unit of variation | one rule (a named, documented value carrying a function) |
| variant definition | a delta: a chain of operations applied to a base rule set (`Chess/Rules/Natural.lean`, `Chess/Rules/Variants.lean`) |
| binding time | all variants compiled in; constructed at initialization; selected at runtime by name |
| identification of rules | by name (string); deltas refer to the rule *values*, so a misspelled rule fails to compile |
| derived artifacts | `chess rules V` (documentation), `chess diff A B` (rule-level diff), Lean theorems about the rule lists |

## 1. The variation points

```lean
structure RuleSet where
  name : String
  movement : List MovementRule    -- propose candidate moves
  legality : List LegalityRule    -- a candidate is legal iff every rule here permits it
  endings  : List EndingRule      -- ordered: the first rule that applies decides the result
  claims   : List EndingRule      -- draws a player may claim
  validity : List ValidityRule    -- conditions on sensible positions (FEN input)
  fallback : List MovementRule    -- moves offered only when no candidate is legal (e.g. a pass)
```

Each rule is a small record `{ name, doc, <function> }`; `doc` cites the FIDE article.

| kind | function | how a rule set combines them | order matters? |
|---|---|---|---|
| movement | `candidates : Position → List Move` | union (concatenation) | no |
| legality | `permits : Position → MoveTest` | conjunction: a move is legal iff no rule forbids it | no |
| ending | `judge : Situation → Option Result` | first rule that returns a result wins | **yes** (e.g. checkmate before the 75-move rule, FIDE 9.6.2) |
| claim | `judge : Situation → Option Result` | all applicable claims are listed | no |
| validity | `holds : Position → Bool` | conjunction | no |
| fallback | `candidates`, used only if nothing else is legal | union, then legality filter | no |

The generic semantics is a dozen lines in `Chess/Rules/Framework.lean`:

```lean
def legalMoves (rs : RuleSet) (pos : Position) : List Move :=
  let tests := rs.legality.map (fun r => r.permits pos) |>.filter (!·.permitsAll)
  let legal (m : Move) := tests.all fun t => t.test m
  match (rs.candidates pos).filter legal with
  | [] => (rs.fallback.flatMap fun r => r.candidates pos).filter legal
  | moves => moves

def outcome? (rs : RuleSet) (sit : Situation) : Option Outcome :=
  rs.endings.findSome? fun r => (r.judge sit).map fun res => ⟨res, r.name⟩
```

Everything else is generic in the rule set and therefore shared by all variants: perft, SAN,
games (sequences of moves with legality explanations and history), the bounded solver, the
tablebase generator, the comparison and divergence tools.

**Staging.** A legality rule receives the position first and returns a `MoveTest`. It can
therefore compute position-wide facts once ("is my king in check?", "where is my king?") and
apply a cheap test to each candidate. `permitsAll := true` declares that the rule forbids nothing
in this position, and the test is skipped. This keeps the indirection affordable: standard perft
runs at about 1M nodes/s on 16 cores.

## 2. The delta operations

| operation | effect | variability meaning |
|---|---|---|
| `renamed n` | new name | identify the product |
| `withoutLegality [r…]`, `withoutEndings`, `withoutMovement`, `withoutClaims`, `withoutValidity` | remove the rules with these names | deactivate a feature |
| `withLegality [r…]`, `withMovement`, `withClaims`, `withValidity`, `withFallback` | append rules | activate / add a feature |
| `withEndingsFirst`, `withEndingsLast`, `withEndingsAfter anchor [r…]` | insert ending rules at a given priority | add a feature where order matters |
| `replacingEnding old new` | replace in place, same priority | override a feature |

Deltas are ordinary functions, so they compose by chaining (`|>.`), and a variant can be built on
top of another variant.

## 3. The family

Natural chess, as a delta on standard chess (`Chess/Rules/Natural.lean`):

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

The other variants (`Chess/Rules/Variants.lean`), with the base each one is derived from:

| variant | base | delta | purpose |
|---|---|---|---|
| `natural-pass` | natural | `+ fallback passIfNoMove` | interpretation: a player with no move passes |
| `natural-nomove-loses` | natural | `noLegalMove` replaced by `noLegalMoveLoses` | interpretation: no move = loss |
| `natural-dead` | natural | `+ deadPosition` (last) | interpretation: keep the insufficient-material rule |
| `natural-fide-castling` | natural | `+ castlingNotOutOfCheck, castlingNotThroughCheck` | isolate the effect of castling |
| `natural-nosuicide` | natural | `+ noSelfCheck` | natural chess without suicidal moves |
| `standard-free-castling` | standard | `− castlingNotOutOfCheck, castlingNotThroughCheck` | isolate the effect of castling |
| `standard-stalemate-wins` | standard | `stalemate` replaced by `stalemateWins` | Lasker-style stalemate |
| `standard-naturalized` | standard-free-castling | `− checkmate, stalemate, deadPosition; + noLegalMoveLosesUnlessBlocked` (first) | bridge: standard chess with the values of natural chess |
| `natural-standardized` | natural | `+ castling conditions; noLegalMove → noLegalMoveLikeFide; + stalemateByAttacks after kingCaptured; + deadPosition (giving way to king capture); 75-move and fivefold rules giving way to king capture` | bridge: natural chess with the values of standard chess |

Derivation tree (each edge is one delta):

```
standard
├── natural
│   ├── natural-pass
│   ├── natural-nomove-loses
│   ├── natural-dead
│   ├── natural-fide-castling
│   ├── natural-nosuicide
│   └── natural-standardized
├── standard-free-castling
│   └── standard-naturalized
└── standard-stalemate-wins
```

### The family as a matrix

Generated from `chess rules <variant>` for each variant. The 10 movement rules (pawnPush,
pawnDoublePush, pawnCapture, enPassant, knight, bishop, rook, queen, king, castling) and the two
claim rules (threefoldRepetition, fiftyMoves) are common to all eleven variants. ● = present;
for endings, the number is the rule's priority.

**Legality**

| rule | std | nat | nat-pass | nat-nomove-loses | nat-dead | nat-fide-castling | std-free-castling | std-stalemate-wins | nat-nosuicide | std-naturalized | nat-standardized |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `noKingCapture` | ● |  |  |  |  |  | ● | ● |  | ● |  |
| `noSelfCheck` | ● |  |  |  |  |  | ● | ● | ● | ● |  |
| `castlingNotOutOfCheck` | ● |  |  |  |  | ● |  | ● |  |  | ● |
| `castlingNotThroughCheck` | ● |  |  |  |  | ● |  | ● |  |  | ● |
| `noMoveAfterKingCapture` |  | ● | ● | ● | ● | ● |  |  | ● |  | ● |

**Endings** (priority order)

| rule | std | nat | nat-pass | nat-nomove-loses | nat-dead | nat-fide-castling | std-free-castling | std-stalemate-wins | nat-nosuicide | std-naturalized | nat-standardized |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `checkmate` | 1 |  |  |  |  |  | 1 | 1 |  |  |  |
| `stalemate` | 2 |  |  |  |  |  | 2 |  |  |  |  |
| `deadPosition` | 3 |  |  |  | 5 |  | 3 | 3 |  |  |  |
| `seventyFiveMoves` | 4 | 3 | 3 | 3 | 3 | 3 | 4 | 4 | 3 | 2 |  |
| `fivefoldRepetition` | 5 | 4 | 4 | 4 | 4 | 4 | 5 | 5 | 4 | 3 |  |
| `kingCaptured` |  | 1 | 1 | 1 | 1 | 1 |  |  | 1 |  | 1 |
| `noLegalMove` |  | 2 | 2 |  | 2 | 2 |  |  | 2 |  |  |
| `noLegalMoveLoses` |  |  |  | 2 |  |  |  |  |  |  |  |
| `stalemateWins` |  |  |  |  |  |  |  | 2 |  |  |  |
| `noLegalMoveLosesUnlessBlocked` |  |  |  |  |  |  |  |  |  | 1 |  |
| `stalemateByAttacks` |  |  |  |  |  |  |  |  |  |  | 2 |
| `noLegalMoveLikeFide` |  |  |  |  |  |  |  |  |  |  | 3 |
| `deadPositionUnlessKingCapturable` |  |  |  |  |  |  |  |  |  |  | 4 |
| `seventyFiveMovesUnlessDecided` |  |  |  |  |  |  |  |  |  |  | 5 |
| `fivefoldRepetitionUnlessKingCapturable` |  |  |  |  |  |  |  |  |  |  | 6 |

**Validity and fallback**

| rule | std | nat | nat-pass | nat-nomove-loses | nat-dead | nat-fide-castling | std-free-castling | std-stalemate-wins | nat-nosuicide | std-naturalized | nat-standardized |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `oneKingEach` | ● |  |  |  |  |  | ● | ● |  | ● |  |
| `noPawnOnFirstOrLastRank` | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● |
| `opponentNotInCheck` | ● |  |  |  |  |  | ● | ● |  | ● |  |
| `castlingRightsConsistent` | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● |
| `enPassantConsistent` | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● |
| `atMostOneKingEach` |  | ● | ● | ● | ● | ● |  |  | ● |  | ● |
| `passIfNoMove` (fallback) |  |  | ● |  |  |  |  |  |  |  |  |

## 4. Binding time and selection

* **Inclusion: compile time.** Every variant is a Lean `def`, listed in `Variants.all`, and
  compiled into the single `chess` executable. Rule sets are closed terms, built once when the
  program starts.
* **Selection: run time.** `Variants.byName?` maps a name to a rule set. Every command takes rule
  set names as arguments, and several commands use two at once:
  ```sh
  lake exe chess variants                         # list the family
  lake exe chess rules natural-standardized       # the rules of one product, with FIDE references
  lake exe chess diff standard natural            # the delta between two products, recomputed
  lake exe chess perft natural-fide-castling 4
  lake exe chess compare standard natural 3 < fens.txt
  lake exe chess endgame P standard natural-standardized 3
  ```
* **New variants require Lean code**: write the delta in `Chess/Rules/Variants.lean` and add it
  to `Variants.all`. There is no runtime configuration language (yet; see §8).

## 5. Why runtime values rather than compile-time variability

| option | what it would have meant here | why not chosen |
|---|---|---|
| preprocessor / conditional compilation | `#ifdef NATURAL` around the check rules | Lean 4 has no preprocessor. It would also give one product per build, and comparisons need two products in one run. |
| boolean feature flags in one implementation | `if cfg.castlingThroughCheck then …` scattered in the move generator | annotative: variability tangled with the shared code, and no clean diff |
| type classes / compile-time specialization | `class Rules σ`, one instance per variant, specialized by the compiler | faster, but rule sets would not be data: no `diff`, no `describe`, no list-level theorems, no generic iteration over the family |
| **runtime rule values + deltas** (chosen) | rule sets as records of lists; variants as functions over them | readable, compositional, products comparable side by side |

Treating products as data paid off concretely:
* **Side-by-side analyses of products**: `compare`, `divergences` and `endgame` take two rule
  sets and run them together.
* **Attribution of a behavioural difference to one feature** (`scripts/attribute.py`): each
  position where standard and natural chess disagree is re-solved under single-rule variants
  (`natural-fide-castling`, `standard-stalemate-wins`, `natural-dead`). This showed that every
  observed value difference comes from castling, stalemate or the dead-position rule.
* **Rule-level diffs** are computed (`RuleSet.diff`), not written by hand.
* **Theorems about products**: `Natural.rules.legality = [Natural.noMoveAfterKingCapture]` holds
  by `rfl`, and from it, for every position, `standard_legal_subset_natural`.

## 6. Equivalences between products

Different configurations can define the same game, or games with the same values. These were
established by testing (perft, exhaustive tablebases, bounded search on positions), not by proof:

| products | relation | evidence |
|---|---|---|
| `natural-nosuicide`, `standard-free-castling` | same perft (two different deltas, same legal moves on reachable positions) | the six reference positions, depths 1–4 (1–5 for the initial position and position 3) (REPORT §2) |
| `standard-naturalized`, `natural` | same values; natural wins exactly 2 plies longer | 1,945,584 tablebase positions (KPK, KBK, KNK, KQK, KRK); 16,783 game positions |
| `standard`, `natural-standardized` | same values; wins exactly 2 plies longer | same data |
| `standard-stalemate-wins`, `natural` | same values on KPK, 2 plies longer | 331,352 positions |

The two bridges split the delta `standard → natural` into a value-preserving part (the "time
shift": no-self-check and no-king-capture dropped, king capture instead of checkmate) and a
value-changing part (castling conditions, stalemate, dead position, precedence of checkmate over
automatic draws).

## 7. Feature interactions found along the way

* **Draw rules × king capture.** A first version of `natural-standardized` kept the plain
  `deadPosition` rule, and some standard wins in KQK/KRK/KPK became draws. Against a mate where
  the queen is protected by its king, the mated king plays Kxq (suicidal). Bare kings are left, and
  the dead-position rule fires *before* the king can be captured. The same interaction exists with
  the 75-move rule, whose FIDE precedence clause speaks of checkmate. Fix: the wrapper
  `givingWayToKingCapture`, which turns any ending rule into one that does not apply while a king
  can be captured.
* **Removing rules creates obligations.** Dropping `noKingCapture` and `noSelfCheck` makes it
  possible to play on after a king has been captured. Natural chess therefore *adds*
  `noMoveAfterKingCapture`; without it, natural perft would count moves of a side without king.
* **Overlapping rules.** Castling *into* check is forbidden both by `noSelfCheck` and by
  `castlingNotThroughCheck`, which covers the crossed square and the destination, as FIDE 3.8.2.2
  does. So `natural-fide-castling` still forbids castling into check, while
  `standard-free-castling` forbids it through `noSelfCheck` only.
* **Staging × explanation.** The `permitsAll` shortcut was first ignored by `forbiddenBy` (which
  explains why a move is illegal). As a result, castling moves were blamed on
  `castlingNotOutOfCheck` even when the king was not in check. Legality itself was right; the
  explanation layer was not. Fixed; the attribution numbers in the report use the fixed version.

## 8. Limits and possible extensions

* **No explicit feature model.** Constraints between rules (e.g. "`noMoveAfterKingCapture` is
  required when `noKingCapture` is absent", or "some ending must cover positions without legal
  moves") are only conventions. Nothing prevents building an inconsistent product. A feature model
  with cross-tree constraints, checked when a rule set is built, would make the family explicit.
* **Identity by name.** Deltas match rules by their name string. Two different rules with the same
  name would be confused.
* **Non-modular parts of the core.** Some variation points would require changing the shared core
  rather than writing a delta:
  - attack detection is fixed to FIDE piece geometry (removing the knight's movement rule would not
    remove knight attacks);
  - the execution of castling, en passant and promotion lives in `Position.play`;
  - the position fields are fixed. Capturing a king that castled across an attacked square "en
    passant" would need a new field, which is why that interpretation is listed but not implemented;
  - the "pass" variant needed a small core addition, the null move.
* **Only 11 of many products.** The configuration space (any subset of rules, any order of endings)
  is not enumerated. The variants were chosen by hand to isolate one rule at a time.
* **Possible extensions:**
  - a runtime configuration language, e.g. `chess perft "standard -castlingNotThroughCheck +stalemateWins" 4`,
    to explore the space without writing Lean;
  - sampling of the configuration space, with the existing comparison tools as oracles;
  - a compile-time specialized build of one chosen variant, if raw speed ever matters;
  - proving the bridge equivalences in Lean rather than testing them.

## 9. Recipe: adding a variant

1. Write any new rule as a value in `Chess/Rules/Variants.lean` (name, FIDE-style doc, function).
2. Define the variant as a delta on an existing product:
   ```lean
   def myVariant : RuleSet :=
     Natural.rules.renamed "my-variant"
       |>.replacingEnding Natural.noLegalMove myEnding
   ```
3. Add it to `Variants.all`. It is then available to every command: `lake exe chess diff natural my-variant`,
   `lake exe chess perft my-variant 4`, `lake exe chess compare standard my-variant 3 < fens.txt`, …
