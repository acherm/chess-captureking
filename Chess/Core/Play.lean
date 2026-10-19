import Chess.Core.Attacks

/-!
# Playing a move

`Position.play` carries out a move on a position, without asking whether the move is
legal: legality is the business of the rule sets (`Chess.Rules`). Playing updates the
board (including the captured pawn of an en passant capture and the rook of a castling),
the castling rights, the en passant target, the clocks and the side to move.
-/

namespace Chess

namespace CastlingRights

/-- Castling rights that survive a move touching squares `a` and `b`: a right is lost once its
king or its rook leaves its original square, or the rook is captured there (FIDE 3.8.2.1). -/
def afterTouching (cr : CastlingRights) (a b : Square) : CastlingRights :=
  [Color.white, .black].foldl (init := cr) fun cr c =>
    [CastlingSide.kingside, .queenside].foldl (init := cr) fun cr side =>
      let g := castlingGeometry c side
      if [g.kingFrom, g.rookFrom].any (fun s => s == a || s == b) then cr.revoke c side else cr

end CastlingRights

namespace Position

/-- The castling side of `m`, if `m` is a castling move (a king moving two files along its
first rank, FIDE 3.8.2). -/
def castlingSide? (pos : Position) (m : Move) : Option CastlingSide :=
  match pos.board.get m.src with
  | some ⟨c, .king⟩ =>
    let g := castlingGeometry c .kingside
    if m.src == g.kingFrom && m.dst == g.kingTo then some .kingside
    else if m.src == g.kingFrom && m.dst == (castlingGeometry c .queenside).kingTo then some .queenside
    else none
  | _ => none

def isCastling (pos : Position) (m : Move) : Bool := (pos.castlingSide? m).isSome

/-- Is `m` an en passant capture (a pawn moving diagonally to an empty square)? -/
def isEnPassant (pos : Position) (m : Move) : Bool :=
  match pos.board.get m.src with
  | some ⟨_, .pawn⟩ => m.src.file != m.dst.file && pos.board.isEmpty m.dst
  | _ => false

/-- The square of the piece captured by `m`, if `m` captures something. -/
def capturedSquare? (pos : Position) (m : Move) : Option Square :=
  if pos.isEnPassant m then some (Square.ofFileRank m.dst.file m.src.rank)
  else if pos.board.isEmpty m.dst then none
  else some m.dst

def isCapture (pos : Position) (m : Move) : Bool := (pos.capturedSquare? m).isSome

/-- The piece captured by `m`, if any. -/
def captured? (pos : Position) (m : Move) : Option Piece :=
  (pos.capturedSquare? m).bind pos.board.get

/-- Pass the turn without moving (the null move). -/
def pass (pos : Position) : Position :=
  { pos with
    turn := pos.turn.opponent
    epTarget := none
    halfmoveClock := pos.halfmoveClock + 1
    fullmoveNumber := if pos.turn == .black then pos.fullmoveNumber + 1 else pos.fullmoveNumber }

/-- Play move `m`, assuming it is at least a move of the piece standing on `m.src`. -/
def play (pos : Position) (m : Move) : Position := Id.run do
  if m.isNull then return pos.pass
  let some piece := pos.board.get m.src | return pos
  let isPawnMove := piece.kind == .pawn
  let isCapture := pos.isCapture m
  -- 1. the piece leaves its square, captures what stands on the arrival square (if
  --    anything) and is replaced by the promotion piece when it is a promoting pawn
  let placed : Piece := { piece with kind := m.promotion.getD piece.kind }
  let mut board := (pos.board.set m.src none).set m.dst (some placed)
  -- 2. en passant: the captured pawn is not on the arrival square (FIDE 3.7.3.1)
  if pos.isEnPassant m then
    board := board.set (Square.ofFileRank m.dst.file m.src.rank) none
  -- 3. castling: the rook jumps over the king (FIDE 3.8.2)
  if let some side := pos.castlingSide? m then
    let g := castlingGeometry piece.color side
    board := (board.set g.rookFrom none).set g.rookTo (board.get g.rookFrom)
  -- 4. en passant target: the square passed over by a pawn advancing two squares
  let epTarget :=
    if isPawnMove && (m.dst.rank : Int) - m.src.rank == 2 * piece.color.forward then
      Square.ofFileRank m.src.file ((m.src.rank + m.dst.rank) / 2) |> some
    else none
  return {
    board
    turn := pos.turn.opponent
    castling := CastlingRights.afterTouching pos.castling m.src m.dst
    epTarget
    halfmoveClock := if isPawnMove || isCapture then 0 else pos.halfmoveClock + 1
    fullmoveNumber := if pos.turn == .black then pos.fullmoveNumber + 1 else pos.fullmoveNumber }

end Position

end Chess
