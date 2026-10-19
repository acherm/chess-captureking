# The rules, one by one, and where they come from

Lichess game [RSJfq4Su](https://lichess.org/RSJfq4Su) ends with 9... Qxe2#. The black queen
attacks White's king on e1. The king cannot step away, cannot take her (the knight on d4 protects
her), and nothing can block. By Articles 1.4 and 5.1.1 of the FIDE Laws of Chess, Black has won.

```
r . b . k b . r      8
p p p . p p p p      7
. . . . . n . .      6
. . . . N . . .      5
. . . n . B . .      4
N . . . . . . .      3
P P P . q P P P      2
R . . . K . . R      1     White to move
a b c d e f g h
```

Now take a pen and strike out half a sentence of Article 3.8.2.2: "Castling is prevented
temporarily: ~~if the square on which the king stands, or the square which it must cross, or the
square which it is to occupy, is attacked by one or more of the opponent's pieces, or~~ if there is
any piece between the king and the rook". White plays 10. O-O: the king walks out of check,
crosses the attacked f1 square, lands safely on g1, and the game goes on (10. O-O-O works too). That is what happens in
natural chess.

Rules are text, and a variant of chess is an edit of that text. This document makes the edit
precise:
* **§2** puts each of the 26 rules of standard chess in the engine next to the FIDE article it
  transcribes: the quote, what the Lean code checks, and the places where even the official Laws
  leave room for interpretation. When are two positions "the same"? Is the right to castle lost
  when a rook is captured on its home square?
* **§3** writes natural chess as nine articles of the Laws, red-lined.
* **§4** traces the variant rules to their origins: a blog comment, thirteenth-century France,
  the rules of draughts, Lasker and Réti.
* **§0, §1, §5 and §6** cover how the Laws map onto kinds of rules, what is fixed in the core,
  the choices made in transcribing the Laws, and what is not modelled.

Each rule is also a Lean value whose doc string cites its source: `lake exe chess rules standard`
prints them all. [VARIABILITY.md](VARIABILITY.md) explains how rules are combined into rule sets.
[REPORT.md](REPORT.md) §4 discusses the interpretation choices and their measured effects.

**Sources**

| tag | source |
|---|---|
| FIDE | *FIDE Laws of Chess*, effective 1 January 2023 (FIDE Handbook E.01), <https://handbook.fide.com/chapter/E012023>. All article numbers refer to it. |
| H26 | J. D. Hamkins, [*Every game of chess ends prematurely*](https://www.infinitelymore.xyz/p/chess-games-end-one-move-early), Infinitely More, 15 October 2026. Only the free part (before the paywall) was read. |
| H22 | J. D. Hamkins, [*Checkmate is not the same as a forced capture of the enemy king in simplified chess*](https://jdh.hamkins.org/checkmate-is-not-the-same-as-a-forced-capture-of-the-enemy-king-in-simplified-chess/), blog post, 2 July 2022, and its comments. |
| BHS | D. Brumleve, J. D. Hamkins, P. Schlicht, [*The mate-in-n problem of infinite chess is decidable*](https://arxiv.org/abs/1201.5597), 2012. |
| PGN | S. J. Edwards, *Portable Game Notation Specification and Implementation Guide*, 1994 ([copy](https://www.saremba.de/chessgml/standards/pgn/pgn-complete.htm)): FEN (§16.1), SAN (§8.2.3). |
| CPW | chessprogramming.org, [*Perft Results*](https://www.chessprogramming.org/Perft_Results): perft numbers and counting conventions. |
| Wiki | Wikipedia, [*Stalemate*](https://en.wikipedia.org/wiki/Stalemate): the history of the stalemate rule. |

---

## 0. How the Laws map onto kinds of rules

FIDE 3.10.1: "A move is legal when all the relevant requirements of Articles 3.1 – 3.9 have been
fulfilled." The engine takes this literally: a move is legal if and only if a *movement* rule
proposes it and no *legality* rule forbids it.

| kind | answers | FIDE articles | Lean type |
|---|---|---|---|
| movement | which moves the pieces can make | 3.1–3.8, without the attacked-squares condition of 3.8.2.2 | `MovementRule`: position → candidate moves |
| legality | which candidates are forbidden | 1.4.1, 3.8.2.2 (attacked squares), 3.9.2 | `LegalityRule`: position → test on moves |
| ending | when the game is over, with what result | 1.4, 5.1.1, 5.2.1, 5.2.2, 9.6 | `EndingRule`: situation → result, tried in order |
| claim | when a draw may be claimed | 9.2, 9.3 | same type as endings |
| validity | which positions make sense | 2.2, 2.3, 3.10.3 and consequences of Article 3 | `ValidityRule`: position → Bool |
| fallback | moves offered only when nothing else is legal | none (empty in FIDE chess) | `MovementRule` |

Two phrases of the Laws shape how the engine evaluates a position:
* "This immediately ends the game" (5.1.1, 5.2.1, 5.2.2). The ending rules are judged in every
  position reached, before any further move.
* "If the last move resulted in checkmate, that shall take precedence" (9.6.2). The ending rules
  are tried in order and the first that applies decides, so `checkmate` comes before
  `seventyFiveMoves`.

---

## 1. The core: what every rule set shares

Not everything is a rule. The core (`Chess/Core/`) fixes the board and the pieces, and what
*playing* a move does to a position. Rule sets only decide which moves are allowed and when the
game ends. The items below are therefore the same in every variant. Changing one of them would
mean changing the core (see the limits in [VARIABILITY.md](VARIABILITY.md)).

| what | FIDE | Lean | note |
|---|---|---|---|
| 8×8 board; files, ranks, diagonals | 2.1, 2.4 | `Square` (`Core/Types`) | |
| initial position | 2.2, 2.3 | `Position.start` (`Core/Fen`) | |
| White moves first, then the players alternate | 1.2, 1.3 | `Position.turn`, flipped by `Position.play` | |
| a captured piece is removed "as part of the same move" | 3.1.1 | `Position.play` | |
| en passant removes the pawn *behind* the arrival square | 3.7.3.1 | `Position.play`, step 2 | |
| castling moves the rook over the king and counts "as a single move of the king" | 3.8.2 | `Position.play`, step 3 | a castling move is written as the king's two-square move (`e1g1`), as in UCI |
| promotion: a queen, rook, bishop or knight of the same colour; "not restricted to pieces that have been captured previously"; "the effect of the new piece is immediate" | 3.7.3.3–3.7.3.5 | `Move.promotion`, `PieceKind.promotionChoices` | four candidate moves per promoting pawn move |
| the right to castle is lost once the king or that rook has moved | 3.8.2.1 | `CastlingRights.afterTouching` | also lost when the rook is captured on its original square (§5, item 3) |
| en passant is possible only "on the move following this advance" | 3.7.3.2 | `Position.epTarget`, set after every two-square pawn advance, cleared after any other move | PGN §16.1.3.4: given "if and only if the last move was a pawn advance of two squares" |
| moves without pawn move or capture | 9.3, 9.6.2 | `Position.halfmoveClock`, reset by pawn moves and captures | PGN §16.1.3.5 |
| a piece attacks a square "even if this piece is constrained from moving to that square because it would then leave or place the king of its own colour under attack" | 3.1.2, 3.1.3 | `Board.isAttacked` (`Core/Attacks`): pure geometry, pins ignored | pawns attack diagonally forward only; castling and en passant are not attacks |
| "The king is said to be 'in check' if it is attacked by one or more of the opponent's pieces" | 3.9.1 | `Position.isInCheck` | a definition, not a rule: rules use it |

---

## 2. Standard chess, rule by rule

`Standard.rules` in `Chess/Rules/Standard.lean`; the movement rules are in `Chess/Rules/Movement.lean`.

### 2.1 Movement (10 rules)

Every movement rule respects 3.1: "It is not permitted to move a piece to a square occupied by a
piece of the same colour" (`Position.mayLandOn`).

| rule | FIDE | the Law says | the Lean rule proposes |
|---|---|---|---|
| `pawnPush` | 3.7.1, 3.7.3.3 | "The pawn may move forward to the square immediately in front of it on the same file, provided that this square is unoccupied" | one step forward to an empty square; four promotion candidates on the last rank |
| `pawnDoublePush` | 3.7.2 | "on its first move the pawn may [...] advance two squares along the same file, provided that both squares are unoccupied" | two steps forward from the 2nd (7th) rank, both squares empty |
| `pawnCapture` | 3.7.3, 3.7.3.3 | "the pawn may move to a square occupied by an opponent's piece diagonally in front of it on an adjacent file, capturing that piece" | a diagonal step forward onto an opponent's piece; four promotion candidates on the last rank |
| `enPassant` | 3.7.3.1, 3.7.3.2 | "may capture this opponent's pawn as though the latter had been moved only one square"; "only legal on the move following this advance" | a diagonal step to the (empty) en passant target, when the opponent's pawn stands just behind it |
| `knight` | 3.6 | "one of the squares nearest to that on which it stands but not on the same rank, file or diagonal" | the eight jumps |
| `bishop` | 3.2, 3.5 | "any square along a diagonal on which it stands"; "may not move over any intervening pieces" | diagonal rays, up to the first piece |
| `rook` | 3.3, 3.5 | "any square along the file or the rank on which it stands" | orthogonal rays, up to the first piece |
| `queen` | 3.4, 3.5 | "any square along the file, the rank or a diagonal on which it stands" | all eight rays, up to the first piece |
| `king` | 3.8.1 | "by moving to an adjoining square" | the eight steps |
| `castling` | 3.8.2, 3.8.2.1, 3.8.2.2 (second condition) | "the king is transferred from its original square two squares towards the rook on its original square, then that rook is transferred to the square the king has just crossed"; the right is lost "if the king has already moved" or "with a rook that has already moved"; prevented "if there is any piece between the king and the rook" | the king's two-square move, if the right is still held, the king and the rook stand on their original squares, and every square between them is empty |

The movement rules say nothing about check: they propose what chess programmers call
*pseudo-legal* moves (CPW). They even propose captures of the opponent's king; forbidding these
is the job of the legality rule `noKingCapture`.

**A choice: Article 3.8.2.2 is split in two.** It prevents castling under two conditions of
different nature: an *attacked* square (the king's square, a square it crosses, or its arrival
square), and a *piece* between king and rook. The second is geometry and stays in the movement
rule. The first is about check and becomes two legality rules (§2.2). Because of this split,
natural chess can drop the first condition and keep the second.

### 2.2 Legality (4 rules)

Article 1.4.1 has three prohibitions in one sentence: "Leaving one's own king under attack,
exposing one's own king to attack and also 'capturing' the opponent's king is not allowed."
Article 3.9.2 restates the first two: "No piece can be moved that will either expose the king of
the same colour to check or leave that king in check."

| rule | FIDE | forbids | note |
|---|---|---|---|
| `noKingCapture` | 1.4.1 (third prohibition) | capturing a king | Never applies in a position reached by legal moves: the opponent cannot have left a king in check. It matters for arbitrary FEN input, and makes the natural delta explicit. |
| `noSelfCheck` | 3.9.2; 1.4.1 (first two prohibitions) | any move after which the mover's king is attacked (the king's square is recomputed when the king itself moves) | also forbids castling *into* check |
| `castlingNotOutOfCheck` | 3.8.2.2 (first condition: "the square on which the king stands") | castling while the king is attacked | permits every move when the king is not attacked |
| `castlingNotThroughCheck` | 3.8.2.2 (first condition: "the square which it must cross, or the square which it is to occupy") | castling when a crossed square or the arrival square is attacked | attacks are evaluated in the position before castling, as the Law reads |

`chess play standard e4 f6 Qh5 Kf7` answers `e8f7 is forbidden by [noSelfCheck (FIDE 3.9.2 …)]`:
the explanation of an illegal move is the list of legality rules that forbid it.

### 2.3 Endings (5 rules, tried in this order)

| order | rule | FIDE | result | the Lean rule |
|---|---|---|---|---|
| 1 | `checkmate` | 1.4, 1.4.1, 1.4.2, 5.1.1 | the player to move loses | the king of the player to move is attacked and there is no legal move |
| 2 | `stalemate` | 5.2.1 | draw | the king is not attacked and there is no legal move |
| 3 | `deadPosition` | 1.5, 5.2.2 | draw | insufficient material (below) |
| 4 | `seventyFiveMoves` | 9.6.2 | draw | half-move clock ≥ 150 |
| 5 | `fivefoldRepetition` | 9.6.1 | draw | the position has appeared at least five times in the game |

* `checkmate` transcribes 1.4: "The objective of each player is to place the opponent's king 'under
  attack' in such a way that the opponent has no legal move."
* `stalemate` transcribes 5.2.1: "The game is drawn when the player to move has no legal move and
  his/her king is not in check."
* `deadPosition` approximates 5.2.2: "The game is drawn when a position has arisen in which neither
  player can checkmate the opponent's king with any series of legal moves." The Law is semantic:
  it quantifies over all continuations. The engine uses insufficient material instead: no pawn,
  rook or queen, and either no other piece, a single knight or bishop, or only bishops all on
  squares of one colour. This is sound (every such position is dead) but incomplete (blocked pawn
  fortresses are dead too). Lichess and python-chess use the same criterion.
* `seventyFiveMoves`: "any series of at least 75 moves have been made by each player without the
  movement of any pawn and without any capture. If the last move resulted in checkmate, that shall
  take precedence."
* `fivefoldRepetition`: "the same position has appeared, as in 9.2.2 at least five times": over the
  whole game, not necessarily on consecutive moves.

**Order.** Several endings apply at once only rarely. The Laws settle one case: a checkmate given
on the move that reaches the 75-move limit wins (9.6.2), hence `checkmate` before
`seventyFiveMoves`. In every other coincidence the endings involved are all draws, so the order only
changes which rule is reported.

### 2.4 Draw claims (2 rules)

| rule | FIDE | claimable when |
|---|---|---|
| `threefoldRepetition` | 9.2, 9.2.2, 9.2.3 | the current position has appeared at least three times |
| `fiftyMoves` | 9.3, 9.3.2 | half-move clock ≥ 100 |

A claim never ends the game: the status is `ongoing (claimable: …)`. Claims made by announcing a
move that will repeat the position or complete the 50 moves (9.2.1, 9.3.1) are not modelled.

### 2.5 When are two positions the same? (9.2.3)

"Positions are considered the same if and only if the same player has the move, pieces of the same
kind and colour occupy the same squares and the possible moves of all the pieces of both players are
the same. Thus positions are not the same if: at the start of the sequence a pawn could have been
captured en passant [9.2.3.1]; a king had castling rights with a rook that has not been moved, but
forfeited these after moving. The castling rights are lost only after the king or rook is moved
[9.2.3.2]."

The Lean predicate `samePosition` compares:
* the board;
* the side to move;
* the castling *rights*;
* the *effective* en passant target (`effectiveEpTarget`: the target counts only if an en passant
  capture is actually legal).

Rights, not castling moves, are compared, as 9.2.3.2 requires: a castling that is temporarily
prevented by an attacked square does not make two positions different.

"Possible moves" means legal moves, so sameness depends on the rules. An en passant capture that is
pseudo-legal but illegal because of a pin makes two positions different in natural chess and the
same in standard chess (REPORT §4, item 6).

### 2.6 Validity (5 rules)

Article 3.10.3: "A position is illegal when it cannot have been reached by any series of legal
moves." Deciding reachability is expensive, so the validity rules are simple *necessary*
conditions, used to reject FEN input. They are consequences of the Laws rather than Laws:

| rule | derived from | holds when |
|---|---|---|
| `oneKingEach` | 2.2 (one king each at the start), 1.4.1 (a king is never captured), 3.7.3.3 (no promotion to a king) | each colour has exactly one king |
| `noPawnOnFirstOrLastRank` | 2.3 (pawns start on the 2nd/7th rank), 3.7 (they move forward only), 3.7.3.3 (promotion on the last rank) | no pawn stands on rank 1 or 8 |
| `opponentNotInCheck` | 3.9.2 | the player who has just moved is not in check |
| `castlingRightsConsistent` | 3.8.2.1 | each castling right has its king and its rook on their original squares |
| `enPassantConsistent` | 3.7.3.1, 3.7.3.2 | the en passant target is on the 3rd (6th) rank, empty, and the pawn that has just advanced stands beyond it |

Not checked, for example: impossible material (ten queens) or pawn structures that need more
captures than pieces are missing.

---

## 3. Natural chess

The definition (H26): "In what I call natural chess, we abandon the rules about check and checkmate,
adopting instead the goal of capturing the opposing king." Hamkins' earlier *simplified chess*
(H22) is the same game: "no rule against leaving your king in check or even moving your king into
check", and "the winning goal of simplified chess was simply to capture the enemy king".

Everything else is interpretation (REPORT §4, items 1–9). `Natural.rules`
(`Chess/Rules/Natural.lean`) is `Standard.rules` with the following delta.

| delta | rule | source | what it does / why |
|---|---|---|---|
| − legality | `noKingCapture`, `noSelfCheck` | H26, H22 | These are 1.4.1 and 3.9.2, the rules about check. |
| − legality | `castlingNotOutOfCheck`, `castlingNotThroughCheck` | H26 | The attacked-squares condition of 3.8.2.2 is a rule about check (REPORT §4, item 1). The geometric condition stays. |
| + legality | `noMoveAfterKingCapture` | 5.1.1, "this immediately ends the game" | If a king is missing, every move is forbidden. Needed because perft counts legal moves and ignores endings. |
| − ending | `checkmate` | H26 | "abandon the rules about [...] checkmate" |
| + ending, first | `kingCaptured` | H26: "the goal of capturing the opposing king" | The side whose king is still on the board wins. Both kings missing (unreachable) is a draw. |
| − ending | `stalemate` | 5.2.1 is stated with check ("and his/her king is not in check") | Taken literally, there is no stalemate: the stalemated player must expose the king (REPORT §4, item 4). |
| + ending, second | `noLegalMove` | H22: "in simplified chess, this position is a stalemate, rather than a Black win" | A player with no move at all, not even one exposing the king, draws (REPORT §4, item 3). |
| − ending | `deadPosition` | 5.2.2 is stated with checkmate ("neither player can checkmate") | Its natural analogue, "no king capture is possible", almost never holds (REPORT §4, item 5). |
| kept | `seventyFiveMoves`, `fivefoldRepetition`, `threefoldRepetition`, `fiftyMoves` | 9.2, 9.3, 9.6 | Same text, but not the same effect (below). |
| − validity | `oneKingEach`, `opponentNotInCheck` | | After a blunder, the player who has just moved may be in check, or the king may be gone. |
| + validity | `atMostOneKingEach` | | At most one king per colour. |

All the movement rules are kept, including the geometric conditions of castling. The delta only
removes legality rules (and adds one that forbids nothing while both kings are on the board). So,
in every position with both kings on the board, every standard legal move is a natural legal move:
theorem `standard_legal_subset_natural` in `Chess/Theorems.lean`.

### Natural chess as an edit of the FIDE Laws

The same delta, written on the text of the Laws: ~~struck out~~ is removed, **bold** is added.
Only the articles that change are shown.

> **1.4** The objective of each player is to ~~place the opponent's king 'under attack' in such a way that the opponent has no legal move~~ **capture the opponent's king**.
>
> **1.4.1** The player who achieves this goal ~~is said to have 'checkmated' the opponent's king and to have~~ **has** won the game. ~~Leaving one's own king under attack, exposing one's own king to attack and also 'capturing' the opponent's king is not allowed.~~
>
> **1.4.2** The opponent whose king has been ~~checkmated~~ **captured** has lost the game.
>
> **1.5** ~~If the position is such that neither player can possibly checkmate the opponent's king, the game is drawn (see Article 5.2.2).~~
>
> **3.8.2.2** Castling is prevented temporarily: ~~if the square on which the king stands, or the square which it must cross, or the square which it is to occupy, is attacked by one or more of the opponent's pieces, or~~ if there is any piece between the king and the rook with which castling is to be effected.
>
> **3.9.2** ~~No piece can be moved that will either expose the king of the same colour to check or leave that king in check.~~
>
> **5.1.1** The game is won by the player who has ~~checkmated~~ **captured** his/her opponent's king. This immediately ends the game, provided that the move producing ~~the checkmate~~ **this** position was in accordance with Article 3 and Articles 4.2 – 4.7.
>
> **5.2.1** The game is drawn when the player to move has no legal move ~~and his/her king is not in check. The game is said to end in 'stalemate'~~. This immediately ends the game, provided that the move producing ~~the stalemate~~ **this** position was in accordance with Article 3 and Articles 4.2 – 4.7.
>
> **5.2.2** ~~The game is drawn when a position has arisen in which neither player can checkmate the opponent's king with any series of legal moves. The game is said to end in a 'dead position'. [...]~~

Some articles keep their text but change their effect:
* **3.9.1** (the definition of check) remains a definition. It is used only by the notation (`+`).
* **3.10.1**: "A move is legal when all the relevant requirements of Articles 3.1 – 3.9 have been
  fulfilled." Article 3.9 no longer contains any requirement.
* **9.6.2**: "If the last move resulted in checkmate, that shall take precedence." Kept, but there is
  no checkmate any more, so the clause never applies. This changes results. A standard checkmate
  given on the move that reaches the 75-move limit wins. The natural king capture would come one
  move later, after the automatic draw (theorem `seventy_five_moves`). An analogous clause for
  natural chess would have to say "a king capture that cannot be avoided", i.e. reintroduce
  checkmate.
* **9.2.3**: "the possible moves" are now the natural legal moves (§2.5).
* **5.1.2** (resignation) and **6.9** (loss on time) make an exception when the opponent "cannot
  checkmate the player's king by any possible series of legal moves". The engine has neither
  resignation nor clock, so this is not modelled. A natural version would need a natural reading of
  "cannot checkmate", the same difficulty as 5.2.2.
* **Glossary**: "Checkmate: Where the king is attacked and cannot parry the threat"; "Stalemate:
  Where the player has no legal move and his/her king is not in check". Both definitions are no
  longer used.
* **Appendix C.13.5**, "++ or # = checkmate": the engine writes `#` for a move that wins the game,
  i.e. a king capture in natural chess.

**Not added: compulsory king capture.** A capturable king may be left alone; capturing it is never
compulsory. BHS describe chess in terms of king capture "with the additional rules that one must do
so if possible". Adding that rule would change no game value, since capturing the king always wins
at once (REPORT §4, item 8).

---

## 4. The variant rules and where they come from

Rules used only by variants (`Chess/Rules/Variants.lean`). Three come from the history of chess or
from proposals by others. The others were built in this project to isolate or bridge the
differences (REPORT §3.6).

**From the literature**

| rule | used by | says | origin |
|---|---|---|---|
| `passIfNoMove` (fallback) | `natural-pass` | a player with no legal move passes (null move) | Proposed by a commenter on H22 (Umberto Cavasinni): "it is possible for a player not to move any piece and to skip the turn when there are no possible moves". Hamkins replied that it "does release the tension in my example and restores the claim". The commenter also quotes H. A. Davidson, *A Short History of Chess* (1949): in twelfth- and thirteenth-century France, "stalemate merely caused the stalled player to lose his move". |
| `noLegalMoveLoses` | `natural-nomove-loses` | a player with no legal move loses | The rule of draughts, where a player who cannot move loses; H22 mentions it. |
| `stalemateWins` | `standard-stalemate-wins` | a stalemate is won by the stalemating player | Historical: "a win for the stalemating player in 10th century Arabia" (Wiki). Modern proposals stop short of a full win: Lasker and Réti proposed ¾ point for the stalemating side, and Larry Kaufman tested ¾–¼ (Wiki). H22 notes that this scoring would not affect his argument. |

**Built in this project** (each restates a FIDE rule for a game that ends by capturing the king)

| rule | used by | says | restates |
|---|---|---|---|
| `noLegalMoveLosesUnlessBlocked` | `standard-naturalized` | no legal move: loss, for checkmate and stalemate alike, unless no piece can move at all even into check (draw) | what natural chess makes of 1.4 and 5.2.1, one move later |
| `stalemateByAttacks` | `natural-standardized` | draw if the king of the player to move is not attacked but every move leaves it attacked | 5.2.1 |
| `noLegalMoveLikeFide` | `natural-standardized` | no move at all: loss if the king is attacked, draw otherwise | 1.4 and 5.2.1 |
| `seventyFiveMovesUnlessDecided` | `natural-standardized` | the 75-move draw, except while the player to move can capture the king, or is attacked with every move leaving the king attacked | 9.6.2 with its precedence clause |
| `givingWayToKingCapture r` | `natural-standardized`, applied to `deadPosition` and `fivefoldRepetition` | rule `r`, except while the player to move can capture the opponent's king | the 9.6.2 precedence, extended to the other automatic draws (the tablebases showed it is needed: REPORT §3.6) |

**Every variant as an edit of the Laws**

| variant | edit |
|---|---|
| `natural-fide-castling` | natural chess with 3.8.2.2 restored |
| `natural-nosuicide` | natural chess with 3.9.2 restored |
| `natural-dead` | natural chess with 5.2.2 restored (as insufficient material, last ending) |
| `natural-pass` | natural chess where a player with no legal move passes |
| `natural-nomove-loses` | natural chess where 5.2.1 reads "the game is lost by the player to move" |
| `standard-free-castling` | the attacked-squares condition of 3.8.2.2 deleted |
| `standard-stalemate-wins` | 5.2.1 reads "the game is won by the opponent" |
| `standard-naturalized` | `standard-free-castling`, with 1.4/5.1.1, 5.2.1 and 5.2.2 replaced by `noLegalMoveLosesUnlessBlocked` |
| `natural-standardized` | natural chess with 3.8.2.2 restored, 5.2.1 restated with attacks, checkmate (1.4) restored for a player who cannot move at all, and the 5.2.2, 9.6.1 and 9.6.2 draws giving way to a king capture |

Each bridge has the game values of the game it imitates, every win taking exactly one move (two
plies) longer on the natural side (REPORT §3.6).

---

## 5. Interpretation choices in the FIDE Laws themselves

Even standard chess required choices. Each one is listed with the rule it affects.

1. **1.4.1 and 3.9.2 overlap.** 1.4.1 has three prohibitions; 3.9.2 restates the first two. They
   become two rules: `noSelfCheck` (the first two) and `noKingCapture` (the third). The second is
   redundant in positions reached by legal moves, but it keeps the transcription faithful.
2. **3.8.2.2 mixes geometry and attacks.** The two conditions are split between the movement rule
   `castling` and two legality rules (§2.1).
3. **Rook captured on its original square.** 3.8.2.1 says the right to castle is lost "with a rook
   that has already moved". When that rook is captured where it stands, the right is lost: any rook
   arriving on that square later has moved. FEN and all engines do the same.
4. **En passant depends on the last move, not only on the board.** The en passant target is
   recorded after every two-square advance (PGN convention), even when no capture is possible.
   Repetition compares only effective targets (9.2.3.1).
5. **Dead position (5.2.2) is semantic.** It is approximated by insufficient material: sound,
   incomplete.
6. **"Possible moves" (9.2.3) means legal moves** under the rule set in use. Castling rights, not
   castling moves, are compared (9.2.3.2).
7. **Fivefold repetition (9.6.1)** counts occurrences over the whole game, not necessarily on
   consecutive moves.
8. **Precedence.** Only 9.6.2 states one: checkmate before the 75-move draw. It is implemented by
   the order of the endings. Other simultaneous endings give the same result.
9. **"Immediately ends the game".** Endings are judged in every position. Claims never end the
   game, and announced claims (9.2.1, 9.3.1) are not modelled.
10. **Illegal positions (3.10.3).** The validity rules are necessary conditions, not a decision
    procedure for reachability.
11. **Promotion (3.7.3.4).** There is no limit on the number of pieces of one kind.
12. **Notation.** SAN follows PGN §8.2.3: castling `O-O` with the letter O, promotion `e8=Q`.
    FIDE Appendix C writes `0-0` and `e8Q`; the parser accepts both spellings of castling. `+`
    marks a move after which the opponent's king is attacked (the 3.9.1 definition, which survives
    in natural chess). `#` marks a move that wins the game: checkmate in standard chess, king capture
    in natural chess.
13. **Perft (CPW)** counts sequences of legal moves and ignores the ending rules, including the
    draws. A checked position counts as a "discovered check" only if the moved piece does not
    itself give check (REPORT §4, items 10–12).

---

## 6. What is not modelled

The engine covers what the board and the sequence of moves determine. It leaves out:
* Article 4: the act of moving (one hand, touch-move, adjusting pieces);
* 5.1.2 (resignation), 5.2.3 (draw by agreement) and 9.1 (draw offers);
* Article 6: the clock, including 6.9 (loss on time, unless the opponent "cannot checkmate");
* Article 7: irregularities. In 7.5, an illegal move is completed and then penalized. The engine
  simply refuses it and says which rule forbids it;
* Article 8 (recording the moves) and Articles 10–12 (points, conduct, the arbiter);
* the Appendices (rapid, blitz, blind chess) and the Guidelines (adjourned games, Chess960,
  quickplay finishes).

As the Preface puts it, "The Laws of Chess cannot cover all possible situations that may arise
during a game".

---

## 7. From the command line

```sh
lake exe chess rules standard                  # every rule with its doc string (FIDE article)
lake exe chess rules natural
lake exe chess diff standard natural           # the delta of §3, rule by rule
lake exe chess play standard e4 f6 Qh5 Kf7     # e8f7 is forbidden by [noSelfCheck (FIDE 3.9.2 …)]
```
