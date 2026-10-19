import Chess.Rules.Framework

/-!
# How the pieces move (FIDE Articles 3.1–3.8)

Movement rules propose the *candidate* moves of the side to move. They say nothing about
check: whether a candidate is legal is decided by legality rules (`Chess.Rules.Standard`).
Candidates are what chess programmers call "pseudo-legal" moves.

The geometric conditions of castling (rights still held, king and rook on their original
squares, nothing in between) are movement conditions; the conditions about attacked squares
(FIDE 3.8.2.2) are legality rules.
-/

namespace Chess

namespace Position

/-- The squares of the pieces of kind `k` of the side to move. -/
def own (pos : Position) (k : PieceKind) : List Square := pos.board.squaresOf ⟨pos.turn, k⟩

/-- A piece may go to `t` unless a piece of its own colour stands there (FIDE 3.1.1).
Going to a square occupied by an opponent's piece captures it. -/
def mayLandOn (pos : Position) (t : Square) : Bool := !pos.board.hasColor t pos.turn

end Position

namespace Movement

private def lastRank : Color → Nat
  | .white => 7
  | .black => 0

private def pawnStartRank : Color → Nat
  | .white => 1
  | .black => 6

/-- A pawn move from `s` to `t`; on the last rank the pawn must be exchanged for a queen, rook,
bishop or knight, giving four candidates (FIDE 3.7.3.3). -/
private def pawnMovesTo (c : Color) (s t : Square) : List Move :=
  if t.rank == lastRank c then PieceKind.promotionChoices.map fun k => ⟨s, t, some k⟩
  else [⟨s, t, none⟩]

/-- Moves of the pieces of kind `k` that go one step in each of the given directions. -/
private def stepper (k : PieceKind) (steps : List Step) (pos : Position) : List Move :=
  (pos.own k).flatMap fun s =>
    steps.filterMap fun (df, dr) =>
      (s.offset df dr).filter pos.mayLandOn |>.map fun t => ⟨s, t, none⟩

/-- Moves of the pieces of kind `k` that slide along their directions (FIDE 3.5). -/
private def slider (k : PieceKind) (pos : Position) : List Move :=
  (pos.own k).flatMap fun s =>
    (slideDirections k).flatMap fun d =>
      (pos.board.ray s d).filter pos.mayLandOn |>.map fun t => ⟨s, t, none⟩

def pawnPush : MovementRule where
  name := "pawnPush"
  doc := "FIDE 3.7.1: a pawn may move forward to the square immediately in front of it, if it is unoccupied (promoting on the last rank, 3.7.3.3)."
  candidates pos :=
    (pos.own .pawn).flatMap fun s =>
      match s.offset 0 pos.turn.forward with
      | some t => if pos.board.isEmpty t then pawnMovesTo pos.turn s t else []
      | none => []

def pawnDoublePush : MovementRule where
  name := "pawnDoublePush"
  doc := "FIDE 3.7.2: on its first move a pawn may advance two squares along the same file, if both squares are unoccupied."
  candidates pos :=
    (pos.own .pawn).filter (·.rank == pawnStartRank pos.turn) |>.filterMap fun s => do
      let t1 ← s.offset 0 pos.turn.forward
      let t2 ← s.offset 0 (2 * pos.turn.forward)
      if pos.board.isEmpty t1 && pos.board.isEmpty t2 then some ⟨s, t2, none⟩ else none

def pawnCapture : MovementRule where
  name := "pawnCapture"
  doc := "FIDE 3.7.3: a pawn may capture an opponent's piece diagonally in front of it on an adjacent file (promoting on the last rank)."
  candidates pos :=
    (pos.own .pawn).flatMap fun s =>
      [(-1 : Int), 1].flatMap fun df =>
        match s.offset df pos.turn.forward with
        | some t => if pos.board.hasColor t pos.turn.opponent then pawnMovesTo pos.turn s t else []
        | none => []

def enPassant : MovementRule where
  name := "enPassant"
  doc := "FIDE 3.7.3.1-2: a pawn attacking a square crossed by an opponent's pawn that has just advanced two squares may capture it as if it had moved only one square, on the very next move only."
  candidates pos :=
    match pos.epTarget with
    | none => []
    | some t =>
      -- the opponent's pawn that has just advanced stands just behind the target square
      let victimThere := match t.offset 0 (-pos.turn.forward) with
        | some v => pos.board.has v ⟨pos.turn.opponent, .pawn⟩
        | none => false
      if !victimThere || !pos.board.isEmpty t then [] else
      [(-1 : Int), 1].filterMap fun df => do
        let s ← t.offset df (-pos.turn.forward)
        if pos.board.has s ⟨pos.turn, .pawn⟩ then some ⟨s, t, none⟩ else none

def knightMoves : MovementRule where
  name := "knight"
  doc := "FIDE 3.6: the knight may move to one of the squares nearest to it but not on its rank, file or diagonal."
  candidates := stepper .knight knightJumps

def bishopMoves : MovementRule where
  name := "bishop"
  doc := "FIDE 3.2, 3.5: the bishop moves along a diagonal, without passing over other pieces."
  candidates := slider .bishop

def rookMoves : MovementRule where
  name := "rook"
  doc := "FIDE 3.3, 3.5: the rook moves along a file or rank, without passing over other pieces."
  candidates := slider .rook

def queenMoves : MovementRule where
  name := "queen"
  doc := "FIDE 3.4, 3.5: the queen moves along a file, rank or diagonal, without passing over other pieces."
  candidates := slider .queen

def kingMoves : MovementRule where
  name := "king"
  doc := "FIDE 3.8.1: the king moves to an adjoining square."
  candidates := stepper .king kingSteps

def castling : MovementRule where
  name := "castling"
  doc := "FIDE 3.8.2: the king moves two squares towards a rook on the same rank, which then jumps over it; only if the right to castle has not been lost (3.8.2.1: king and rook have not moved) and no piece stands between king and rook (3.8.2.2)."
  candidates pos :=
    [CastlingSide.kingside, .queenside].filterMap fun side =>
      let g := castlingGeometry pos.turn side
      if pos.castling.has pos.turn side &&
          pos.board.has g.kingFrom ⟨pos.turn, .king⟩ &&
          pos.board.has g.rookFrom ⟨pos.turn, .rook⟩ &&
          g.between.all pos.board.isEmpty then
        some ⟨g.kingFrom, g.kingTo, none⟩
      else none

/-- All the movement rules of FIDE chess. -/
def fide : List MovementRule :=
  [pawnPush, pawnDoublePush, pawnCapture, enPassant, knightMoves, bishopMoves, rookMoves,
   queenMoves, kingMoves, castling]

end Movement

end Chess
