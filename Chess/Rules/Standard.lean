import Chess.Rules.Movement

/-!
# Standard chess (FIDE Laws of Chess)

The rule set of standard chess: the FIDE movement rules (`Chess.Rules.Movement`), plus the
legality rules about check, and the rules ending the game (checkmate, stalemate, dead
position, 75 moves, fivefold repetition) or allowing a draw claim (threefold repetition,
50 moves). Article numbers refer to the FIDE Laws of Chess (2023).
-/

namespace Chess

namespace Standard

/-! ## Legality -/

def noKingCapture : LegalityRule where
  name := "noKingCapture"
  doc := "FIDE 1.4.1: 'capturing' the opponent's king is not allowed."
  permits pos := ⟨false, fun m =>
    match pos.captured? m with
    | some ⟨_, .king⟩ => false
    | _ => true⟩

def noSelfCheck : LegalityRule where
  name := "noSelfCheck"
  doc := "FIDE 3.9.2 (and 1.4.1): no piece can be moved that will either expose the king of the same colour to check or leave that king in check."
  permits pos :=
    let us := pos.turn
    let king? := pos.kingSquare? us
    ⟨false, fun m =>
      match king? with
      | none => true
      | some k =>
        let after := pos.play m
        let k' := if m.src == k then m.dst else k
        !after.board.isAttacked k' us.opponent⟩

def castlingNotOutOfCheck : LegalityRule where
  name := "castlingNotOutOfCheck"
  doc := "FIDE 3.8.2.2: castling is prevented if the square on which the king stands is attacked."
  permits pos :=
    let inCheck := pos.isInCheck pos.turn
    { permitsAll := !inCheck, test := fun m => !pos.isCastling m }

def castlingNotThroughCheck : LegalityRule where
  name := "castlingNotThroughCheck"
  doc := "FIDE 3.8.2.2: castling is prevented if the square which the king must cross, or the square which it is to occupy, is attacked."
  permits pos := ⟨false, fun m =>
    match pos.castlingSide? m with
    | none => true
    | some side =>
      let g := castlingGeometry pos.turn side
      (g.crossed ++ [g.kingTo]).all fun s => !pos.board.isAttacked s pos.turn.opponent⟩

/-! ## End of the game -/

def checkmate : EndingRule where
  name := "checkmate"
  doc := "FIDE 1.4, 5.1.1: a player whose king is in check and who has no legal move is checkmated and loses; this immediately ends the game."
  judge sit :=
    let pos := sit.position
    if pos.isInCheck pos.turn && sit.noLegalMove.get then some (Result.winner pos.turn.opponent)
    else none

def stalemate : EndingRule where
  name := "stalemate"
  doc := "FIDE 5.2.1: the game is drawn when the player to move has no legal move and his/her king is not in check."
  judge sit :=
    let pos := sit.position
    if !pos.isInCheck pos.turn && sit.noLegalMove.get then some .draw else none

/-- Material with which no checkmate is possible: no pawns, rooks or queens, and either a
single minor piece or only bishops all standing on squares of the same colour. -/
def insufficientMaterial (b : Board) : Bool :=
  let others := Square.all.filterMap fun s =>
    match b.get s with
    | some p => if p.kind == .king then none else some (s, p.kind)
    | none => none
  match others with
  | [] => true
  | [(_, k)] => k == .knight || k == .bishop
  | (s, _) :: _ => others.all fun (t, k) => k == .bishop && t.isLight == s.isLight

def deadPosition : EndingRule where
  name := "deadPosition"
  doc := "FIDE 5.2.2: the game is drawn when neither player can checkmate the opponent's king with any series of legal moves. Detected (soundly but incompletely) by insufficient material: bare kings, a single minor piece, or bishops all on squares of one colour."
  judge sit := if insufficientMaterial sit.position.board then some .draw else none

def seventyFiveMoves : EndingRule where
  name := "seventyFiveMoves"
  doc := "FIDE 9.6.2: the game is drawn after 75 moves by each player without pawn move or capture (checkmate takes precedence: it is checked first)."
  judge sit := if sit.position.halfmoveClock ≥ 150 then some .draw else none

/-- The en passant target, if an en passant capture is actually possible: only then does it make
the position different from the same placement without it (FIDE 9.2.3.1). -/
def effectiveEpTarget (legalMovesOf : Position → List Move) (p : Position) : Option Square :=
  match p.epTarget with
  | none => none
  | some t => if (legalMovesOf p).any p.isEnPassant then some t else none

/-- FIDE 9.2.3: positions are the same if the same player has the move, pieces of the same
kind and colour occupy the same squares, and the possible moves of all the pieces are the same
(castling rights and en passant possibilities included). -/
def samePosition (legalMovesOf : Position → List Move) (a b : Position) : Bool :=
  a.board == b.board && a.turn == b.turn && a.castling == b.castling &&
    effectiveEpTarget legalMovesOf a == effectiveEpTarget legalMovesOf b

/-- How many times the current position has appeared in the game (at least once). -/
def occurrences (sit : Situation) : Nat :=
  1 + sit.history.countP (samePosition sit.legalMovesOf sit.position)

def fivefoldRepetition : EndingRule where
  name := "fivefoldRepetition"
  doc := "FIDE 9.6.1: the game is drawn when the same position has appeared at least five times."
  judge sit := if occurrences sit ≥ 5 then some .draw else none

def threefoldRepetition : EndingRule where
  name := "threefoldRepetition"
  doc := "FIDE 9.2: a draw may be claimed when the same position has appeared at least three times (here: after it has appeared)."
  judge sit := if occurrences sit ≥ 3 then some .draw else none

def fiftyMoves : EndingRule where
  name := "fiftyMoves"
  doc := "FIDE 9.3: a draw may be claimed when the last 50 moves by each player have been completed without pawn move or capture."
  judge sit := if sit.position.halfmoveClock ≥ 100 then some .draw else none

/-! ## Validity of positions -/

def oneKingEach : ValidityRule where
  name := "oneKingEach"
  doc := "FIDE 2.2, 1.4.1, 3.7.3.3: each player has exactly one king (one at the start, never captured, never created by promotion)."
  holds pos := [Color.white, .black].all fun c => (pos.board.squaresOf ⟨c, .king⟩).length == 1

def noPawnOnFirstOrLastRank : ValidityRule where
  name := "noPawnOnFirstOrLastRank"
  doc := "FIDE 2.3, 3.7: pawns start on the 2nd/7th rank, move forward and are promoted on the last rank."
  holds pos := Square.all.all fun s =>
    match pos.board.get s with
    | some ⟨_, .pawn⟩ => s.rank != 0 && s.rank != 7
    | _ => true

def opponentNotInCheck : ValidityRule where
  name := "opponentNotInCheck"
  doc := "FIDE 3.9.2: the player who has just moved cannot have left his/her king in check."
  holds pos := !pos.isInCheck pos.turn.opponent

def castlingRightsConsistent : ValidityRule where
  name := "castlingRightsConsistent"
  doc := "FIDE 3.8.2.1: a castling right implies that the king and that rook are on their original squares."
  holds pos := [Color.white, .black].all fun c =>
    [CastlingSide.kingside, .queenside].all fun side =>
      let g := castlingGeometry c side
      !pos.castling.has c side ||
        (pos.board.has g.kingFrom ⟨c, .king⟩ && pos.board.has g.rookFrom ⟨c, .rook⟩)

def enPassantConsistent : ValidityRule where
  name := "enPassantConsistent"
  doc := "FIDE 3.7.3.2: an en passant target lies just behind an opponent's pawn that has just advanced two squares."
  holds pos :=
    match pos.epTarget with
    | none => true
    | some t =>
      let them := pos.turn.opponent
      t.rank == (if them == .white then 2 else 5) && pos.board.isEmpty t &&
        (t.offset 0 them.forward).any (pos.board.has · ⟨them, .pawn⟩)

/-! ## The rule set -/

def rules : RuleSet where
  name := "standard"
  movement := Movement.fide
  legality := [noKingCapture, noSelfCheck, castlingNotOutOfCheck, castlingNotThroughCheck]
  endings := [checkmate, stalemate, deadPosition, seventyFiveMoves, fivefoldRepetition]
  claims := [threefoldRepetition, fiftyMoves]
  validity := [oneKingEach, noPawnOnFirstOrLastRank, opponentNotInCheck, castlingRightsConsistent,
    enPassantConsistent]

end Standard

end Chess
