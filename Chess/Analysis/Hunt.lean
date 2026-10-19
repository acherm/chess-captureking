import Chess.Analysis.Random
import Chess.Rules.Natural
import Chess.Notation.San
import Chess.Solver

/-!
# Hunting for positions where standard and natural chess differ

Random positions are generated (with a bias towards positions where castling matters: the king
of the player to move on its original square, with castling rights), and kept when they belong
to one of the kinds of divergence that J. D. Hamkins exhibits in *Every game of chess ends
prematurely* (one position each):

1. wins in standard chess where, in natural chess, the king cannot be captured
   (`castleEscape`: the checkmated player castles out of check; `noMove`: the checkmated player
   has no move at all, not even one exposing the king);
2. draws in standard chess that are wins in natural chess (`stalemateLoses`);
3. immediate wins in standard chess that are losses in natural chess (`opposite`: the
   checkmated player castles out of check and then wins by force).

An exhaustive search (`castlingEscapes`, at the end) finds the smallest positions of the third
kind.
-/

namespace Chess

namespace Hunt

/-- A random position with up to `maxPieces` extra pieces where the player to move has its king
on its original square, a rook in a corner and the corresponding castling right; extra pieces
are put near that king with probability 3/4. -/
def castlingSetup (g : Rng) (maxPieces : Nat) : Option Position × Rng := Id.run do
  let mut g := g
  let (whiteToMove, g') := g.coin
  g := g'
  let us : Color := if whiteToMove then .white else .black
  let them := us.opponent
  let home := (castlingGeometry us .kingside).kingFrom
  let mut b := Board.empty.set home (some ⟨us, .king⟩)
  -- one or two rooks in the corners
  let (sides, g') := g.pick [[CastlingSide.kingside], [.queenside], [.kingside, .queenside]]
  g := g'
  for side in sides do
    b := b.set (castlingGeometry us side).rookFrom (some ⟨us, .rook⟩)
  (b, g) := placeRandomly g b ⟨them, .king⟩
  let nearHome (s : Square) := (s.rank : Int) - home.rank ≤ 3 && home.rank - (s.rank : Int) ≤ 3
  let (n, g') := g.below (maxPieces + 1)
  g := g'
  for _ in List.range n do
    let (k, g1) := g.pick pieceKinds
    let (white, g2) := g1.coin
    let (near, g3) := g2.below 4
    (b, g) := placeRandomly g3 b ⟨if white then .white else .black, k⟩
      (if near != 0 then nearHome else fun _ => true)
  let (otherRights, g') := randomCastlingRights g b
  g := g'
  let castling := match us with
    | .white => { otherRights with
        whiteKingside := sides.contains .kingside, whiteQueenside := sides.contains .queenside }
    | .black => { otherRights with
        blackKingside := sides.contains .kingside, blackQueenside := sides.contains .queenside }
  let pos : Position := { board := b, turn := us, castling, epTarget := none,
                          halfmoveClock := 0, fullmoveNumber := 1 }
  return (if Standard.rules.isValid pos then some pos else none, g)

/-- Like `castlingSetup`, but with few pieces for the opponent (1 to `theirMax`), put near our
king, and up to `ourMax` pieces of ours anywhere: positions where, after castling, the opponent
may run out of safe moves. -/
def sparseSetup (g : Rng) (ourMax theirMax : Nat) : Option Position × Rng := Id.run do
  let mut g := g
  let (whiteToMove, g') := g.coin
  g := g'
  let us : Color := if whiteToMove then .white else .black
  let them := us.opponent
  let home := (castlingGeometry us .kingside).kingFrom
  let mut b := Board.empty.set home (some ⟨us, .king⟩)
  let (sides, g') := g.pick [[CastlingSide.kingside], [.queenside], [.kingside, .queenside]]
  g := g'
  for side in sides do
    b := b.set (castlingGeometry us side).rookFrom (some ⟨us, .rook⟩)
  (b, g) := placeRandomly g b ⟨them, .king⟩
  let nearHome (s : Square) := (s.rank : Int) - home.rank ≤ 2 && home.rank - (s.rank : Int) ≤ 2
  let (n, g') := g.below theirMax
  g := g'
  for _ in List.range (n + 1) do
    let (k, g1) := g.pick pieceKinds
    (b, g) := placeRandomly g1 b ⟨them, k⟩ nearHome
  let (m, g') := g.below (ourMax + 1)
  g := g'
  for _ in List.range m do
    let (k, g1) := g.pick pieceKinds
    (b, g) := placeRandomly g1 b ⟨us, k⟩
  let castling := match us with
    | .white => { whiteKingside := sides.contains .kingside, whiteQueenside := sides.contains .queenside }
    | .black => { blackKingside := sides.contains .kingside, blackQueenside := sides.contains .queenside }
  let pos : Position := { board := b, turn := us, castling, epTarget := none,
                          halfmoveClock := 0, fullmoveNumber := 1 }
  return (if Standard.rules.isValid pos then some pos else none, g)

def isCheckmate (pos : Position) : Bool :=
  pos.isInCheck pos.turn && !Standard.rules.hasLegalMove pos

def isStalemate (pos : Position) : Bool :=
  !pos.isInCheck pos.turn && !Standard.rules.hasLegalMove pos

/-- Natural moves after which the mover's king is not attacked. -/
def safeNaturalMoves (pos : Position) : List Move :=
  (Natural.rules.legalMoves pos).filter fun m => !(pos.play m).isInCheck pos.turn

/-- The kinds of positions we hunt for; each returns a description when the position fits. -/
def castleEscape (pos : Position) : Option String :=
  if !isCheckmate pos then none else
  match safeNaturalMoves pos with
  | [] => none
  | ms => some s!"standard: checkmate; natural: escapes by {ms.map (san Natural.rules pos)}"

def noMove (pos : Position) : Option String :=
  if isCheckmate pos && (Natural.rules.legalMoves pos).isEmpty then
    some "standard: checkmate; natural: no move at all (drawn, the king cannot be captured)"
  else none

def stalemateLoses (pos : Position) : Option String :=
  if isStalemate pos && mustLose Natural.rules pos 2 then
    some "standard: stalemate (draw); natural: every move exposes the king (loss in 2 plies)"
  else none

def stalemateEscape (pos : Position) : Option String :=
  if !isStalemate pos then none else
  match safeNaturalMoves pos with
  | [] => none
  | ms => some s!"standard: stalemate; natural: safe move(s) {ms.map (san Natural.rules pos)}"

/-- Standard checkmate, but in natural chess the checkmated player wins by force within
`plies` plies. -/
def opposite (plies : Nat) (pos : Position) : Option String := do
  let _ ← castleEscape pos
  let winning := (safeNaturalMoves pos).filter fun m =>
    mustLose Natural.rules (pos.play m) (plies - 1)
  if winning.isEmpty then none else
  some s!"standard: checkmate ({pos.turn.opponent} wins); natural: {pos.turn} wins within {plies} plies by {winning.map (san Natural.rules pos)}"

/-- Standard stalemate, but in natural chess the stalemated player wins by force within
`plies` plies. -/
def stalemateOpposite (plies : Nat) (pos : Position) : Option String := do
  let _ ← stalemateEscape pos
  let winning := (safeNaturalMoves pos).filter fun m =>
    mustLose Natural.rules (pos.play m) (plies - 1)
  if winning.isEmpty then none else
  some s!"standard: stalemate (draw); natural: {pos.turn} wins within {plies} plies by {winning.map (san Natural.rules pos)}"

/-- Natural chess: the player to move wins within 3 plies by a castling move that standard chess
forbids (through or out of check), while standard chess has no mate in 1. -/
def castleAttack (pos : Position) : Option String :=
  let std := Standard.rules.legalMoves pos
  let castlings := (Natural.rules.legalMoves pos).filter fun m => pos.isCastling m && !std.contains m
  if castlings.isEmpty then none else
  let winning := castlings.filter fun m => mustLose Natural.rules (pos.play m) 2
  if winning.isEmpty || canWin Standard.rules pos 1 then none else
  some s!"natural: {pos.turn} wins within 3 plies by {winning.map (san Natural.rules pos)} (illegal in standard chess, which has no mate in 1)"

def byName? : String → Option (Position → Option String)
  | "castle-escape" => some castleEscape
  | "castle-attack" => some castleAttack
  | "no-move" => some noMove
  | "stalemate-loses" => some stalemateLoses
  | "stalemate-escape" => some stalemateEscape
  | "opposite" => some (opposite 3)
  | "opposite5" => some (opposite 5)
  | "stalemate-opposite" => some (stalemateOpposite 3)
  | "stalemate-opposite5" => some (stalemateOpposite 5)
  | _ => none

/-! ## Exhaustive search for small opposite-outcome positions

In a standard checkmate, every natural move other than castling leaves the king attacked, and
loses it at once. An opposite outcome therefore needs a checkmated player who castles out of
check. It is enough to look at positions where the player to move (White, by symmetry of
colours) has the king on e1 and a rook on a1 or h1 (or both) with the corresponding castling
rights, plus the black king and a few more pieces. Black needs no castling right and there
is no en passant target: removing them changes neither the standard checkmate nor White's
first move (the castling), and only takes defences away from Black afterwards. -/

/-- The ten kinds of pieces other than kings. -/
def extraPieces : List Piece :=
  [Color.white, .black].flatMap fun c => pieceKinds.map fun k => ⟨c, k⟩

/-- The boards obtained by adding `k` pieces of `extraPieces` to `b`, on empty squares (pawns
not on the first or last rank). Each set of pieces is produced once: the codes
`piece * 64 + square` of the added pieces increase. -/
def addPieces (b : Board) : Nat → Nat → List Board
  | 0, _ => [b]
  | k + 1, first =>
    (List.range' first (64 * extraPieces.length - first)).flatMap fun code =>
      let p := extraPieces[code / 64]!
      let s := Square.ofIndex (code % 64)
      if b.isEmpty s && (p.kind != .pawn || (s.rank != 0 && s.rank != 7)) then
        addPieces (b.set s (some p)) k (code + 1)
      else []

/-- The three ways for White to keep a castling right: queenside, kingside, both. -/
def castlingConfigs : List (List CastlingSide) := [[.queenside], [.kingside], [.kingside, .queenside]]

/-- All positions with White to move, the white king on e1 with the rooks and castling rights
of `sides`, the black king on `bk` and `extras` more pieces, that are valid in standard chess
and where White is checkmated but can castle to a square where the king is not attacked (in
natural chess). Also returns the number of valid positions and of checkmates examined. -/
def castlingEscapes (sides : List CastlingSide) (bk : Square) (extras : Nat) :
    Array Position × Nat × Nat := Id.run do
  let home := (castlingGeometry .white .kingside).kingFrom
  let mut b := Board.empty.set home (some ⟨.white, .king⟩)
  for side in sides do
    b := b.set (castlingGeometry .white side).rookFrom (some ⟨.white, .rook⟩)
  if !b.isEmpty bk then return (#[], 0, 0)
  b := b.set bk (some ⟨.black, .king⟩)
  let castling : CastlingRights :=
    { whiteKingside := sides.contains .kingside, whiteQueenside := sides.contains .queenside,
      blackKingside := false, blackQueenside := false }
  let mut found := #[]
  let mut valid := 0
  let mut mates := 0
  for k in List.range (extras + 1) do
    for board in addPieces b k 0 do
      let pos : Position := { board, turn := .white, castling, epTarget := none,
                              halfmoveClock := 0, fullmoveNumber := 1 }
      if Standard.rules.isValid pos then
        valid := valid + 1
        if isCheckmate pos then
          mates := mates + 1
          if (castleEscape pos).isSome then found := found.push pos
  return (found, valid, mates)

/-- Try `attempts` random positions from `gen`; return the ones `pred` accepts (at most
`wanted`), with their descriptions, and the number of valid positions generated. -/
def run (gen : Rng → Option Position × Rng) (pred : Position → Option String) (seed : Nat)
    (attempts wanted : Nat) : List (Position × String) × Nat := Id.run do
  let mut g : Rng := ⟨seed.toUInt64⟩
  let mut found := #[]
  let mut valid := 0
  for _ in List.range attempts do
    if found.size ≥ wanted then break
    let (p?, g') := gen g
    g := g'
    if let some p := p? then
      valid := valid + 1
      if let some why := pred p then found := found.push (p, why)
  return (found.toList, valid)

end Hunt

end Chess
