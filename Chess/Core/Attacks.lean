import Chess.Core.Position

/-!
# Piece geometry and attacks

How each kind of piece moves across the board (FIDE 3.2–3.8), and which squares it
*attacks*. Following FIDE 3.1.3, a piece attacks a square if it could capture on that
square, even if the capture would be illegal (e.g. because the piece is pinned, FIDE 3.9.1).
-/

namespace Chess

/-- A displacement on the board, in files and ranks. -/
abbrev Step := Int × Int

def knightJumps : List Step := [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
def kingSteps : List Step := [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
def orthogonals : List Step := [(1, 0), (0, 1), (-1, 0), (0, -1)]
def diagonals : List Step := [(1, 1), (-1, 1), (-1, -1), (1, -1)]

/-- Directions along which a piece slides (empty for non-sliding pieces). -/
def slideDirections : PieceKind → List Step
  | .bishop => diagonals
  | .rook => orthogonals
  | .queen => orthogonals ++ diagonals
  | _ => []

/-- For each square, the squares reached by the given steps (precomputed once). -/
def stepTable (steps : List Step) : Vector (List Square) 64 :=
  Vector.ofFn fun i => steps.filterMap fun (df, dr) => (Square.ofIndex i).offset df dr

/-- For each square and each direction of `orthogonals ++ diagonals`, the squares met when going
from that square in that direction up to the edge of the board (precomputed once). -/
def rayTable : Vector (List (Step × List Square)) 64 :=
  Vector.ofFn fun i =>
    let rec go : Nat → Square → Step → List Square
      | 0, _, _ => []
      | n + 1, s, d =>
        match s.offset d.1 d.2 with
        | some t => t :: go n t d
        | none => []
    (orthogonals ++ diagonals).map fun d => (d, go 7 (Square.ofIndex i) d)

def knightTable : Vector (List Square) 64 := stepTable knightJumps
def kingTable : Vector (List Square) 64 := stepTable kingSteps

namespace Board

/-- The squares a sliding piece standing on `s` reaches in direction `d`: the empty squares,
followed by the first occupied square, if any (FIDE 3.5: it cannot move over pieces). -/
def ray (b : Board) (s : Square) (d : Step) : List Square := go 7 s
where
  go : Nat → Square → List Square
    | 0, _ => []
    | n + 1, cur =>
      match cur.offset d.1 d.2 with
      | none => []
      | some next => if b.isEmpty next then next :: go n next else [next]

/-- The first occupied square from `s` in direction `d`, if any. -/
def firstOccupied? (b : Board) (s : Square) (d : Step) : Option Square := go 7 s
where
  go : Nat → Square → Option Square
    | 0, _ => none
    | n + 1, cur =>
      match cur.offset d.1 d.2 with
      | none => none
      | some next => if b.isEmpty next then go n next else some next

/-- The squares holding a piece of colour `c` that attacks square `s`. -/
def attackers (b : Board) (s : Square) (c : Color) : List Square :=
  let holds (k : PieceKind) (t : Square) := b.has t ⟨c, k⟩
  let jumpers (steps : List Step) (k : PieceKind) :=
    steps.filterMap (fun (df, dr) => s.offset df dr) |>.filter (holds k)
  -- a pawn of colour `c` attacks the two squares diagonally in front of it, so it attacks `s`
  -- from the two squares diagonally *behind* `s` (from `c`'s point of view)
  let pawns := [(-1 : Int), 1].filterMap (fun df => s.offset df (-c.forward)) |>.filter (holds .pawn)
  let sliders := (orthogonals ++ diagonals).filterMap fun d =>
    match b.firstOccupied? s d with
    | some t =>
      let k := if orthogonals.contains d then PieceKind.rook else PieceKind.bishop
      if holds k t || holds .queen t then some t else none
    | none => none
  pawns ++ jumpers knightJumps .knight ++ jumpers kingSteps .king ++ sliders

/-- Is square `s` attacked by a piece of colour `c`? (Same answer as `attackers`, but faster:
it uses precomputed tables and stops at the first attacker found.) -/
def isAttacked (b : Board) (s : Square) (c : Color) : Bool :=
  let holds (k : PieceKind) (t : Square) := b.has t ⟨c, k⟩
  let pawn := [(-1 : Int), 1].any fun df => (s.offset df (-c.forward)).any (holds .pawn)
  -- the first occupied square of a ray holds an attacker of the right kind
  let slides (ray : Step × List Square) :=
    match ray.2.find? (!b.isEmpty ·) with
    | some t => holds .queen t || holds (if orthogonals.contains ray.1 then .rook else .bishop) t
    | none => false
  pawn || knightTable[s.index].any (holds .knight) || kingTable[s.index].any (holds .king) ||
    rayTable[s.index].any slides

end Board

namespace Position

/-- Is the king of colour `c` attacked ("in check", FIDE 3.9.1)? A side without king is never
in check. -/
def isInCheck (pos : Position) (c : Color) : Bool :=
  match pos.board.kingSquare? c with
  | some k => pos.board.isAttacked k c.opponent
  | none => false

/-- The squares of the pieces giving check to the king of colour `c`. -/
def checkers (pos : Position) (c : Color) : List Square :=
  match pos.board.kingSquare? c with
  | some k => pos.board.attackers k c.opponent
  | none => []

end Position

end Chess
