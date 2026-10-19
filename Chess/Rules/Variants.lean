import Chess.Rules.Natural

/-!
# Interpretation variants

Where the informal definition of natural chess leaves room for interpretation, the
alternatives are rule sets too, so that their consequences can be measured. Each one is a
small delta on `Natural.rules` or `Standard.rules`.
-/

namespace Chess

namespace Variants

/-- A player with no legal move passes (Hamkins' commenter's "null move" proposal), so that a
"checkmated" player who cannot move at all still gets his king captured. Hamkins calls this
*lose-your-turn* chess; Davidson reports it from twelfth- and thirteenth-century France. -/
def passIfNoMove : MovementRule where
  name := "passIfNoMove"
  doc := "A player who has no legal move passes (null move): he loses his turn."
  candidates _ := [Move.null]

/-- A player may pass at any time, as in Go (Hamkins: *chess with passing*). The pass is still
subject to the legality rules: in standard chess a player in check cannot pass, since the pass
would leave the king in check (`Standard.noSelfCheck`). -/
def passAnyTime : MovementRule where
  name := "passAnyTime"
  doc := "A player may pass (null move) instead of moving, at any time, as in Go."
  candidates _ := [Move.null]

def noLegalMoveLoses : EndingRule where
  name := "noLegalMoveLoses"
  doc := "A player who has no legal move loses (as in draughts)."
  judge sit :=
    if sit.noLegalMove.get then some (Result.winner sit.position.turn.opponent) else none

def stalemateWins : EndingRule where
  name := "stalemateWins"
  doc := "A stalemated player loses: the stalemating player wins (as in some early forms of chess; Lasker and Réti proposed 3/4 of a point)."
  judge sit :=
    let pos := sit.position
    if !pos.isInCheck pos.turn && sit.noLegalMove.get then some (Result.winner pos.turn.opponent)
    else none

/-- Natural chess where a player with no legal move passes (Hamkins' *lose-your-turn* natural
chess). The ending `noLegalMove` is dropped: it can no longer apply. -/
def naturalLoseTurn : RuleSet :=
  Natural.rules.renamed "natural-lose-turn"
    |>.withoutEndings [Natural.noLegalMove]
    |>.withFallback [passIfNoMove]

/-- Natural chess where a player with no legal move loses (Hamkins' *normal* natural chess:
the normal-play convention of combinatorial game theory). -/
def naturalNormal : RuleSet :=
  Natural.rules.renamed "natural-normal"
    |>.replacingEnding Natural.noLegalMove noLegalMoveLoses

/-- Natural chess keeping the (insufficient material) dead-position rule of standard chess. -/
def naturalDead : RuleSet :=
  Natural.rules.renamed "natural-dead"
    |>.withEndingsLast [Standard.deadPosition]

/-- Natural chess keeping the FIDE restrictions on castling (not out of, through or into an
attacked square). Isolates the effect of castling. -/
def naturalFideCastling : RuleSet :=
  Natural.rules.renamed "natural-fide-castling"
    |>.withLegality [Standard.castlingNotOutOfCheck, Standard.castlingNotThroughCheck]

/-- Standard chess where castling ignores attacked squares (but a move may still not leave
the king in check). Isolates the effect of castling. -/
def standardFreeCastling : RuleSet :=
  Standard.rules.renamed "standard-free-castling"
    |>.withoutLegality [Standard.castlingNotOutOfCheck, Standard.castlingNotThroughCheck]

/-- Standard chess where stalemate is a win for the stalemating player. -/
def standardStalemateWins : RuleSet :=
  Standard.rules.renamed "standard-stalemate-wins"
    |>.replacingEnding Standard.stalemate stalemateWins

/-- Natural chess where moves may not expose the king (only castling differs from standard
chess, plus the endings). -/
def naturalNoSuicide : RuleSet :=
  Natural.rules.renamed "natural-nosuicide"
    |>.withLegality [Standard.noSelfCheck]

/-- A player without legal move loses, unless no piece can move at all (then the game is drawn,
as `Natural.noLegalMove`). -/
def noLegalMoveLosesUnlessBlocked : EndingRule where
  name := "noLegalMoveLosesUnlessBlocked"
  doc := "A player with no legal move loses (checkmate or stalemate alike), unless none of his pieces can move at all, even into check (draw)."
  judge sit :=
    if !sit.noLegalMove.get then none
    else if (Standard.rules.candidates sit.position).isEmpty then some .draw
    else some (Result.winner sit.position.turn.opponent)

/-- Standard chess changed exactly where the experiments locate the game-theoretic differences
with natural chess (REPORT §3.6): castling may cross or leave attacked squares, a player without
legal move loses unless nothing can move at all, and there is no dead-position rule. The
hypothesis is that this game and natural chess have the same values (natural chess taking two
more plies to win). -/
def standardNaturalized : RuleSet :=
  standardFreeCastling.renamed "standard-naturalized"
    |>.withoutEndings [Standard.checkmate, Standard.stalemate, Standard.deadPosition]
    |>.withEndingsFirst [noLegalMoveLosesUnlessBlocked]

/-! ### Natural chess made equivalent to standard chess

The converse construction: what must be added to natural chess so that it has the values of
standard chess (one move later)? Each added rule has to speak about *attacked* kings again. -/

/-- FIDE 5.2.1, restated with attacks: the king of the player to move is not attacked, but every
move would leave it attacked. -/
def stalemateByAttacks : EndingRule where
  name := "stalemateByAttacks"
  doc := "The game is drawn when the king of the player to move is not attacked but every move would leave it attacked (stalemate, FIDE 5.2.1, restated with attacks)."
  judge sit :=
    let pos := sit.position
    if !pos.isInCheck pos.turn && sit.legalMoves.get.all (fun m => (pos.play m).isInCheck pos.turn)
    then some .draw else none

/-- A player who cannot move at all: checkmate if the king is attacked, stalemate otherwise. -/
def noLegalMoveLikeFide : EndingRule where
  name := "noLegalMoveLikeFide"
  doc := "A player who cannot move at all loses if his king is attacked (checkmate) and draws otherwise (stalemate)."
  judge sit :=
    let pos := sit.position
    if !sit.noLegalMove.get then none
    else if pos.isInCheck pos.turn then some (Result.winner pos.turn.opponent)
    else some .draw

/-- FIDE 9.6.2 with its precedence clause restated for a game that ends by capturing the king:
no draw while the player to move can capture the opponent's king, or while his own king is
attacked and every move leaves it attacked (a checkmate). -/
def seventyFiveMovesUnlessDecided : EndingRule where
  name := "seventyFiveMovesUnlessDecided"
  doc := "FIDE 9.6.2: drawn after 75 moves by each player without pawn move or capture, except while the player to move can capture the opponent's king, or is attacked with every move leaving his king attacked (checkmate takes precedence)."
  judge sit :=
    let pos := sit.position
    if pos.halfmoveClock < 150 || pos.isInCheck pos.turn.opponent then none
    else if pos.isInCheck pos.turn && sit.legalMoves.get.all (fun m => (pos.play m).isInCheck pos.turn)
    then none
    else some .draw

/-- A draw rule that gives way to an imminent king capture: it does not apply while the player to
move can capture the opponent's king. (A standard game would already be over: by checkmate, or
because the move exposing the king was illegal.) -/
def givingWayToKingCapture (r : EndingRule) : EndingRule where
  name := r.name ++ "UnlessKingCapturable"
  doc := r.doc ++ " Does not apply while the player to move can capture the opponent's king."
  judge sit := if sit.position.isInCheck sit.position.turn.opponent then none else r.judge sit

/-- Natural chess plus exactly what standard chess has and natural chess lacks, game-
theoretically: the FIDE castling conditions, stalemate, the dead-position rule, checkmate without
any move, and, for the automatic draws (dead position, 75 moves, fivefold repetition), the
precedence of checkmate, i.e. of an imminent king capture. The hypothesis is that this game
has the values of standard chess, its wins taking two more plies. -/
def naturalStandardized : RuleSet :=
  Natural.rules.renamed "natural-standardized"
    |>.withLegality [Standard.castlingNotOutOfCheck, Standard.castlingNotThroughCheck]
    |>.replacingEnding Natural.noLegalMove noLegalMoveLikeFide
    |>.withEndingsAfter Natural.kingCaptured [stalemateByAttacks]
    |>.withEndingsAfter noLegalMoveLikeFide [givingWayToKingCapture Standard.deadPosition]
    |>.replacingEnding Standard.seventyFiveMoves seventyFiveMovesUnlessDecided
    |>.replacingEnding Standard.fivefoldRepetition (givingWayToKingCapture Standard.fivefoldRepetition)

/-! ### Hamkins' grid of variants

*Every game of chess ends prematurely* closes with the question: how many variations are there,
and which are equivalent? Two winning conditions (checkmate; capture of the king) times four
conventions for a player who cannot, or would rather not, move:

| convention | standard | natural |
|---|---|---|
| ordinary: stalemate is a draw (natural: having no move at all is a draw) | `standard` | `natural` |
| normal play: a player with no legal move loses | `standard-normal` | `natural-normal` |
| passing: a player may pass at any time | `standard-passing` | `natural-passing` |
| lose your turn: a player with no legal move passes | `standard-lose-turn` | `natural-lose-turn` |

GRID_VARIANTS.md compares them pairwise. -/

/-- Standard chess with the normal-play convention: a player with no legal move loses, in check
(checkmate) or not (stalemate). The dead-position rule is dropped as well: FIDE 5.2.2 means
"no player can win", and once stalemate wins, insufficient material no longer implies it (K+B v K
and K+N v K can be won by stalemating the lone king). -/
def standardNormal : RuleSet :=
  Standard.rules.renamed "standard-normal"
    |>.withoutEndings [Standard.checkmate, Standard.stalemate, Standard.deadPosition]
    |>.withEndingsFirst [noLegalMoveLoses]

/-- Standard chess where a player may pass at any time, but not out of check. Stalemate can no
longer occur, so its rule is dropped. The dead-position rule stays sound: insufficient material
cannot checkmate, whatever the passes. -/
def standardPassing : RuleSet :=
  Standard.rules.renamed "standard-passing"
    |>.withMovement [passAnyTime]
    |>.withoutEndings [Standard.stalemate]

/-- Standard chess where a stalemated player loses his turn instead of drawing (Hamkins'
*lose-your-turn* chess). A checkmated player cannot pass (the pass would leave his king in
check), so checkmate still ends the game. -/
def standardLoseTurn : RuleSet :=
  Standard.rules.renamed "standard-lose-turn"
    |>.withoutEndings [Standard.stalemate]
    |>.withFallback [passIfNoMove]

/-- Natural chess where a player may pass at any time (passing while the king is attacked simply
loses it). No player is ever without a move, so `noLegalMove` is dropped. -/
def naturalPassing : RuleSet :=
  Natural.rules.renamed "natural-passing"
    |>.withMovement [passAnyTime]
    |>.withoutEndings [Natural.noLegalMove]

/-- The grid, standard column first. -/
def grid : List RuleSet :=
  [Standard.rules, standardNormal, standardPassing, standardLoseTurn,
   Natural.rules, naturalNormal, naturalPassing, naturalLoseTurn]

/-! ### The grid, naturalized convention by convention

`standard-naturalized` has the values of natural chess. The same construction applies to every
convention of the grid: standard chess with castling freed from the conditions on attacked
squares, no dead-position rule, and the convention for a player who cannot move transposed to
natural chess, where a stalemated player who has a piece to move must move it (and lose his
king). The hypothesis (GRID_VARIANTS.md) is that each of these has the values of the natural
game of the same convention. -/

def standardNormalNaturalized : RuleSet :=
  standardNormal.renamed "standard-normal-naturalized"
    |>.withoutLegality [Standard.castlingNotOutOfCheck, Standard.castlingNotThroughCheck]

def standardPassingNaturalized : RuleSet :=
  standardPassing.renamed "standard-passing-naturalized"
    |>.withoutLegality [Standard.castlingNotOutOfCheck, Standard.castlingNotThroughCheck]
    |>.withoutEndings [Standard.deadPosition]

/-- Natural lose-your-turn chess, seen from standard chess: a player passes only when none of
his pieces can move at all; a stalemated player who has a piece to move must move it. -/
def stalemateLosesUnlessBlocked : EndingRule where
  name := "stalemateLosesUnlessBlocked"
  doc := "A player who is not in check, and whose only legal move is to pass, loses if one of his pieces could move (exposing his king); he passes only if none can move at all."
  judge sit :=
    let pos := sit.position
    if !pos.isInCheck pos.turn && sit.legalMoves.get.all (·.isNull) &&
        !(Standard.rules.candidates pos).isEmpty
    then some (Result.winner pos.turn.opponent) else none

def standardLoseTurnNaturalized : RuleSet :=
  standardLoseTurn.renamed "standard-lose-turn-naturalized"
    |>.withoutLegality [Standard.castlingNotOutOfCheck, Standard.castlingNotThroughCheck]
    |>.withoutEndings [Standard.deadPosition]
    |>.withEndingsFirst [stalemateLosesUnlessBlocked]

/-- Each natural game of the grid with its naturalized standard counterpart. -/
def gridBridges : List (RuleSet × RuleSet) :=
  [(standardNaturalized, Natural.rules), (standardNormalNaturalized, naturalNormal),
   (standardPassingNaturalized, naturalPassing), (standardLoseTurnNaturalized, naturalLoseTurn)]

def all : List RuleSet :=
  [Standard.rules, Natural.rules, naturalLoseTurn, naturalNormal, naturalDead,
   naturalFideCastling, standardFreeCastling, standardStalemateWins, naturalNoSuicide,
   standardNaturalized, naturalStandardized,
   standardNormal, standardPassing, standardLoseTurn, naturalPassing,
   standardNormalNaturalized, standardPassingNaturalized, standardLoseTurnNaturalized]

def byName? (name : String) : Option RuleSet := all.find? (·.name == name)

end Variants

end Chess
