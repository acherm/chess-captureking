import Chess.Core.Types

/-!
# Boards and positions

A `Board` says what stands on each square; a `Position` adds everything else that the
rules need to know (FEN fields): side to move, castling rights, en passant target and the
two move counters.

A board is *not* required to contain exactly one king per side: positions where a king
has been captured are meaningful in natural chess.
-/

namespace Chess

/-- What stands on each of the 64 squares. -/
structure Board where
  squares : Vector (Option Piece) 64
  deriving DecidableEq

namespace Board

def empty : Board := ⟨Vector.replicate 64 none⟩

def get (b : Board) (s : Square) : Option Piece := b.squares[s.index]

def set (b : Board) (s : Square) (p : Option Piece) : Board := ⟨b.squares.set s.index p⟩

def isEmpty (b : Board) (s : Square) : Bool := (b.get s).isNone

/-- Is there a piece of colour `c` on `s`? -/
def hasColor (b : Board) (s : Square) (c : Color) : Bool :=
  match b.get s with
  | some p => p.color == c
  | none => false

/-- Is the piece `p` on `s`? -/
def has (b : Board) (s : Square) (p : Piece) : Bool := b.get s == some p

/-- The squares holding a piece of colour `c`, with the kind of that piece. -/
def piecesOf (b : Board) (c : Color) : List (Square × PieceKind) :=
  Square.all.filterMap fun s =>
    match b.get s with
    | some p => if p.color == c then some (s, p.kind) else none
    | none => none

/-- The squares holding piece `p`. -/
def squaresOf (b : Board) (p : Piece) : List Square := Square.all.filter (b.has · p)

/-- The square of the king of colour `c` (the first one found, if several). -/
def kingSquare? (b : Board) (c : Color) : Option Square := Square.all.find? (b.has · ⟨c, .king⟩)

instance : Hashable Board where
  hash b := b.squares.foldl (fun h p => mixHash h (hash p)) 7

end Board

inductive CastlingSide where
  | kingside
  | queenside
  deriving DecidableEq, Repr, Inhabited, Hashable

/-- Castling rights: which castlings are still permitted in the future (FIDE 3.8.2.1: the
right is lost once the king, or the rook concerned, has moved). Whether castling is
possible *now* is a different matter, decided by the rules. -/
structure CastlingRights where
  whiteKingside : Bool := false
  whiteQueenside : Bool := false
  blackKingside : Bool := false
  blackQueenside : Bool := false
  deriving DecidableEq, Repr, Inhabited, Hashable

namespace CastlingRights

def all : CastlingRights := ⟨true, true, true, true⟩
def none : CastlingRights := {}

def has (cr : CastlingRights) : Color → CastlingSide → Bool
  | .white, .kingside => cr.whiteKingside
  | .white, .queenside => cr.whiteQueenside
  | .black, .kingside => cr.blackKingside
  | .black, .queenside => cr.blackQueenside

def revoke (cr : CastlingRights) : Color → CastlingSide → CastlingRights
  | .white, .kingside => { cr with whiteKingside := false }
  | .white, .queenside => { cr with whiteQueenside := false }
  | .black, .kingside => { cr with blackKingside := false }
  | .black, .queenside => { cr with blackQueenside := false }

end CastlingRights

/-- The squares involved in one castling (FIDE 3.8.2). -/
structure CastlingGeometry where
  color : Color
  side : CastlingSide
  kingFrom : Square
  kingTo : Square
  rookFrom : Square
  rookTo : Square
  /-- Squares between king and rook, which must be empty (FIDE 3.8.2.2, last item). -/
  between : List Square
  /-- Squares the king crosses, strictly between `kingFrom` and `kingTo`. -/
  crossed : List Square

def castlingGeometry (c : Color) (side : CastlingSide) : CastlingGeometry :=
  let r := match c with
    | .white => 0
    | .black => 7
  let sq (f : Nat) := Square.ofFileRank f r
  match side with
  | .kingside =>
    { color := c, side, kingFrom := sq 4, kingTo := sq 6, rookFrom := sq 7, rookTo := sq 5,
      between := [sq 5, sq 6], crossed := [sq 5] }
  | .queenside =>
    { color := c, side, kingFrom := sq 4, kingTo := sq 2, rookFrom := sq 0, rookTo := sq 3,
      between := [sq 1, sq 2, sq 3], crossed := [sq 3] }

/-- All the information the rules need about the current state of a game, except the
history of earlier positions (see `Chess.Game`). These are exactly the six FEN fields. -/
structure Position where
  board : Board
  turn : Color
  castling : CastlingRights
  /-- The square a pawn has just passed over by advancing two squares, if any
  (the FEN "en passant target square"). -/
  epTarget : Option Square
  /-- Half-moves since the last capture or pawn move (FIDE 9.3, 9.6.2). -/
  halfmoveClock : Nat
  fullmoveNumber : Nat
  deriving DecidableEq

namespace Position

/-- The square of the king of colour `c`, if it is (still) on the board. -/
def kingSquare? (pos : Position) (c : Color) : Option Square := pos.board.kingSquare? c

instance : Hashable Position where
  hash p := mixHash (hash p.board) <| mixHash (hash p.turn) <| mixHash (hash p.castling) <|
    mixHash (hash p.epTarget) <| mixHash (hash p.halfmoveClock) (hash p.fullmoveNumber)

instance : Inhabited Position :=
  ⟨{ board := Board.empty, turn := .white, castling := {}, epTarget := none,
     halfmoveClock := 0, fullmoveNumber := 1 }⟩

end Position

end Chess
