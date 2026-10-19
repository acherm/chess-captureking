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
"checkmated" player who cannot move at all still gets his king captured. -/
def passIfNoMove : MovementRule where
  name := "passIfNoMove"
  doc := "A player who has no legal move passes (null move)."
  candidates _ := [Move.null]

def noLegalMoveLoses : EndingRule where
  name := "noLegalMoveLoses"
  doc := "A player who has no legal move loses (as in many king-capture variants)."
  judge sit :=
    if sit.noLegalMove.get then some (Result.winner sit.position.turn.opponent) else none

def stalemateWins : EndingRule where
  name := "stalemateWins"
  doc := "A stalemated player loses: the stalemating player wins (proposals by Lasker and others)."
  judge sit :=
    let pos := sit.position
    if !pos.isInCheck pos.turn && sit.noLegalMove.get then some (Result.winner pos.turn.opponent)
    else none

/-- Natural chess where a player with no legal move passes. -/
def naturalPass : RuleSet :=
  Natural.rules.renamed "natural-pass"
    |>.withFallback [passIfNoMove]

/-- Natural chess where a player with no legal move loses. -/
def naturalNoMoveLoses : RuleSet :=
  Natural.rules.renamed "natural-nomove-loses"
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

def all : List RuleSet :=
  [Standard.rules, Natural.rules, naturalPass, naturalNoMoveLoses, naturalDead,
   naturalFideCastling, standardFreeCastling, standardStalemateWins, naturalNoSuicide,
   standardNaturalized, naturalStandardized]

def byName? (name : String) : Option RuleSet := all.find? (·.name == name)

end Variants

end Chess
