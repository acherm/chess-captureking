/-!
# Chess vocabulary

Colours, kinds of pieces, pieces, squares and moves.

Nothing in this file depends on the rules of any particular variant of chess:
it is the shared vocabulary of every rule set defined in `Chess.Rules`.
-/

namespace Chess

/-- The two sides. -/
inductive Color where
  | white
  | black
  deriving DecidableEq, Repr, Inhabited, Hashable

namespace Color

def opponent : Color → Color
  | white => black
  | black => white

/-- The direction in which the pawns of this colour advance (in ranks). -/
def forward : Color → Int
  | white => 1
  | black => -1

instance : ToString Color where
  toString
    | white => "white"
    | black => "black"

end Color

inductive PieceKind where
  | pawn
  | knight
  | bishop
  | rook
  | queen
  | king
  deriving DecidableEq, Repr, Inhabited, Hashable

namespace PieceKind

/-- The (upper-case) letter of the piece, as used in FEN and SAN. -/
def letter : PieceKind → Char
  | pawn => 'P'
  | knight => 'N'
  | bishop => 'B'
  | rook => 'R'
  | queen => 'Q'
  | king => 'K'

def ofLetter? (c : Char) : Option PieceKind :=
  match c.toUpper with
  | 'P' => some pawn
  | 'N' => some knight
  | 'B' => some bishop
  | 'R' => some rook
  | 'Q' => some queen
  | 'K' => some king
  | _ => none

/-- The pieces a pawn may be promoted to (FIDE 3.7.3.3). -/
def promotionChoices : List PieceKind := [queen, rook, bishop, knight]

end PieceKind

structure Piece where
  color : Color
  kind : PieceKind
  deriving DecidableEq, Repr, Inhabited, Hashable

namespace Piece

/-- FEN letter: upper case for White, lower case for Black. -/
def toChar (p : Piece) : Char :=
  match p.color with
  | .white => p.kind.letter
  | .black => p.kind.letter.toLower

def ofChar? (c : Char) : Option Piece :=
  (PieceKind.ofLetter? c).map fun k => ⟨if c.isUpper then .white else .black, k⟩

end Piece

/-- A square of the board, as an index `0‥63`: a1 = 0, b1 = 1, …, h1 = 7, a2 = 8, …, h8 = 63. -/
structure Square where
  index : Fin 64
  deriving DecidableEq, Repr, Inhabited, Hashable

namespace Square

/-- File of the square: 0 for the a-file, …, 7 for the h-file. -/
def file (s : Square) : Nat := s.index.val % 8

/-- Rank of the square: 0 for the first rank, …, 7 for the eighth rank. -/
def rank (s : Square) : Nat := s.index.val / 8

def ofIndex (n : Nat) : Square := ⟨⟨n % 64, Nat.mod_lt _ (by decide)⟩⟩

/-- The square on file `f` and rank `r` (both expected in `0‥7`). -/
def ofFileRank (f r : Nat) : Square := ofIndex (8 * r + f)

/-- The square `df` files and `dr` ranks away from `s`, if it is on the board. -/
def offset (s : Square) (df dr : Int) : Option Square :=
  let f : Int := s.file + df
  let r : Int := s.rank + dr
  if 0 ≤ f && f < 8 && 0 ≤ r && r < 8 then some (ofFileRank f.toNat r.toNat) else none

/-- All 64 squares, from a1 to h8. -/
def all : List Square := (List.range 64).map ofIndex

/-- Algebraic name of the square, e.g. `"e4"`. -/
def name (s : Square) : String :=
  String.ofList [Char.ofNat ('a'.toNat + s.file), Char.ofNat ('1'.toNat + s.rank)]

instance : ToString Square := ⟨name⟩

def ofName? (str : String) : Option Square :=
  match str.toList with
  | [f, r] =>
    if 'a' ≤ f && f ≤ 'h' && '1' ≤ r && r ≤ '8' then
      some (ofFileRank (f.toNat - 'a'.toNat) (r.toNat - '1'.toNat))
    else none
  | _ => none

/-- Light squares (h1 is light, a1 is dark). -/
def isLight (s : Square) : Bool := (s.file + s.rank) % 2 == 1

end Square

/-- A move as a player announces it: the square a piece leaves, the square it goes to, and
the piece chosen on promotion. Castling is written as the two-square move of the king
(e.g. `e1g1`), as in UCI. Everything else (captures, en passant, rook move of castling) is
deduced from the position when the move is played. -/
structure Move where
  src : Square
  dst : Square
  promotion : Option PieceKind := none
  deriving DecidableEq, Repr, Inhabited, Hashable

namespace Move

/-- The "null move" (a pass). It is not a move of FIDE chess; it only exists so that rule
sets *may* allow a player to pass (see `RuleSet.fallback`). Written `0000` in UCI. -/
def null : Move := ⟨Square.ofIndex 0, Square.ofIndex 0, none⟩

def isNull (m : Move) : Bool := m.src == m.dst

/-- UCI long algebraic notation, e.g. `e2e4`, `e7e8q`, `e1g1`. -/
def toUci (m : Move) : String :=
  if m.isNull then "0000" else
  m.src.name ++ m.dst.name ++
    match m.promotion with
    | some k => String.singleton k.letter.toLower
    | none => ""

instance : ToString Move := ⟨toUci⟩

def ofUci? (s : String) : Option Move :=
  if s == "0000" then some null else
  match s.toList with
  | [a, b, c, d] => do
    let src ← Square.ofName? (String.ofList [a, b])
    let dst ← Square.ofName? (String.ofList [c, d])
    return ⟨src, dst, none⟩
  | [a, b, c, d, p] => do
    let src ← Square.ofName? (String.ofList [a, b])
    let dst ← Square.ofName? (String.ofList [c, d])
    let k ← PieceKind.ofLetter? p
    return ⟨src, dst, some k⟩
  | _ => none

end Move

end Chess
