import Chess.Rules.Standard

/-!
# Random positions

Two generators of random positions, both reproducible from a seed:

* `randomPlacement`: kings and a random number of random pieces put on random squares; the
  position is kept only if it is valid in standard chess (one king each, no pawn on the first or
  last rank, the player who has just moved is not in check). Castling rights are granted at random
  when king and rook stand on their original squares.
* `randomPlayout`: a random number of random legal moves (of standard chess) from the initial
  position.
-/

namespace Chess

/-- A small pseudo-random generator (SplitMix64). -/
structure Rng where
  state : UInt64

namespace Rng

def next (g : Rng) : UInt64 × Rng :=
  let s := g.state + 0x9E3779B97F4A7C15
  let z := (s ^^^ (s >>> 30)) * 0xBF58476D1CE4E5B9
  let z := (z ^^^ (z >>> 27)) * 0x94D049BB133111EB
  (z ^^^ (z >>> 31), ⟨s⟩)

/-- A number in `0‥n-1` (`n > 0`). -/
def below (g : Rng) (n : Nat) : Nat × Rng :=
  let (x, g) := g.next
  (x.toNat % n, g)

def coin (g : Rng) : Bool × Rng :=
  let (x, g) := g.below 2
  (x == 1, g)

/-- A random element of a non-empty list. -/
def pick {α} [Inhabited α] (g : Rng) (xs : List α) : α × Rng :=
  let (i, g) := g.below xs.length
  (xs[i]!, g)

end Rng

/-- Put `p` on a random empty square accepted by `ok`. -/
def placeRandomly (g : Rng) (b : Board) (p : Piece) (ok : Square → Bool := fun _ => true) :
    Board × Rng :=
  let free := Square.all.filter fun s => b.isEmpty s && ok s &&
    (p.kind != .pawn || (s.rank != 0 && s.rank != 7))
  if free.isEmpty then (b, g) else
  let (s, g) := g.pick free
  (b.set s (some p), g)

/-- Grant each castling right at random, when king and rook are on their original squares. -/
def randomCastlingRights (g : Rng) (b : Board) : CastlingRights × Rng := Id.run do
  let mut cr : CastlingRights := {}
  let mut g := g
  for c in [Color.white, .black] do
    for side in [CastlingSide.kingside, .queenside] do
      let geo := castlingGeometry c side
      if b.has geo.kingFrom ⟨c, .king⟩ && b.has geo.rookFrom ⟨c, .rook⟩ then
        let (yes, g') := g.coin
        g := g'
        if yes then
          cr := match c, side with
            | .white, .kingside => { cr with whiteKingside := true }
            | .white, .queenside => { cr with whiteQueenside := true }
            | .black, .kingside => { cr with blackKingside := true }
            | .black, .queenside => { cr with blackQueenside := true }
  return (cr, g)

def pieceKinds : List PieceKind := [.pawn, .knight, .bishop, .rook, .queen]

/-- A random position with the two kings and up to `maxPieces` other pieces (`none` if the
attempt does not give a valid standard position). -/
def randomPlacement (g : Rng) (maxPieces : Nat) : Option Position × Rng := Id.run do
  let mut g := g
  let mut b := Board.empty
  for c in [Color.white, .black] do
    (b, g) := placeRandomly g b ⟨c, .king⟩
  let (n, g') := g.below (maxPieces + 1)
  g := g'
  for _ in List.range n do
    let (k, g1) := g.pick pieceKinds
    let (white, g2) := g1.coin
    (b, g) := placeRandomly g2 b ⟨if white then .white else .black, k⟩
  let (whiteToMove, g') := g.coin
  g := g'
  let (castling, g') := randomCastlingRights g b
  g := g'
  let pos : Position := { board := b, turn := if whiteToMove then .white else .black, castling,
                          epTarget := none, halfmoveClock := 0, fullmoveNumber := 1 }
  return (if Standard.rules.isValid pos then some pos else none, g)

/-- The position after up to `plies` random legal moves of standard chess from the initial
position (stopping early if the game ends). -/
def randomPlayout (g : Rng) (plies : Nat) : Position × Rng := Id.run do
  let mut g := g
  let mut pos := Position.start
  for _ in List.range plies do
    let moves := Standard.rules.legalMoves pos
    if moves.isEmpty then break
    let (m, g') := g.pick moves
    g := g'
    pos := pos.play m
  return (pos, g)

end Chess
