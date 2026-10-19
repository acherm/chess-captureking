import Chess.Rules.Standard

/-!
# Natural chess (J. D. Hamkins)

"We abandon the rules about check and checkmate, adopting instead the goal of capturing the
opposing king." (J. D. Hamkins, *Every game of chess ends prematurely*, Infinitely More.)

Natural chess is defined as a *delta* on standard chess: the movement rules are untouched,
the four legality rules that mention check (or the capture of the king) are dropped, and the
endings that depend on check are replaced by the capture of the king.

Interpretation choices (see `Chess.Rules.Variants` for the alternatives):
* castling keeps its geometric conditions (rights, empty squares between king and rook) and
  loses the conditions about attacked squares (they are rules about check);
* a king that castled across an attacked square cannot be captured "in passing" there:
  natural chess has no such rule;
* a player with no legal move at all (not even a move exposing the king) cannot capture
  anything nor be captured: the game is drawn, like a stalemate (Hamkins, *Checkmate is not
  the same as a forced capture of the enemy king in simplified chess*);
* the dead-position rule is dropped: its standard meaning ("no checkmate possible") is
  about checkmate, and its natural analogue ("no king capture possible by any series of
  legal moves") almost never holds, since a king may always walk into capture.
-/

namespace Chess

namespace Natural

def bothKingsOnBoard (pos : Position) : Bool :=
  (pos.kingSquare? .white).isSome && (pos.kingSquare? .black).isSome

def noMoveAfterKingCapture : LegalityRule where
  name := "noMoveAfterKingCapture"
  doc := "Natural chess: the game ends as soon as a king is captured, so no move is legal afterwards."
  permits pos :=
    let ongoing := bothKingsOnBoard pos
    { permitsAll := ongoing, test := fun _ => ongoing }

def kingCaptured : EndingRule where
  name := "kingCaptured"
  doc := "Natural chess: the player who captures the opponent's king wins."
  judge sit :=
    match (sit.position.kingSquare? .white).isSome, (sit.position.kingSquare? .black).isSome with
    | true, false => some .whiteWins
    | false, true => some .blackWins
    | false, false => some .draw
    | true, true => none

def noLegalMove : EndingRule where
  name := "noLegalMove"
  doc := "Natural chess: a player who has no legal move (not even one exposing the king) cannot move; the game is drawn, as in a stalemate."
  judge sit := if sit.noLegalMove.get then some .draw else none

def kingsAtMostOneEach : ValidityRule where
  name := "atMostOneKingEach"
  doc := "Natural chess: each player has one king, until it is captured."
  holds pos := [Color.white, .black].all fun c => (pos.board.squaresOf ⟨c, .king⟩).length ≤ 1

/-- Natural chess, as a delta on `Standard.rules`. -/
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

end Natural

end Chess
