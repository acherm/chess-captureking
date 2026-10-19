import Chess.Rules.Framework

/-!
# Perft

`perft rs pos d` counts the sequences of `d` legal moves from `pos` under rule set `rs`
(https://www.chessprogramming.org/Perft). As usual, ending rules are ignored, except that
there are no moves once the legality rules permit none (e.g. after checkmate, or after the
capture of a king in natural chess).

`perftStats` also classifies the last move of each sequence, as in the tables of
https://www.chessprogramming.org/Perft_Results.
-/

namespace Chess

def perft (rs : RuleSet) (pos : Position) : Nat → Nat
  | 0 => 1
  | 1 => (rs.legalMoves pos).length
  | d + 2 => (rs.legalMoves pos).foldl (fun n m => n + perft rs (pos.play m) (d + 1)) 0

/-- Perft of each legal move (the "divide" command of perft tools). -/
def divide (rs : RuleSet) (pos : Position) (d : Nat) : List (Move × Nat) :=
  (rs.legalMoves pos).map fun m => (m, perft rs (pos.play m) (d - 1))

/-- Perft, with one task per legal move of the root position. -/
def perftParallel (rs : RuleSet) (pos : Position) (d : Nat) : Nat :=
  if d ≤ 2 then perft rs pos d else
  let tasks := (rs.legalMoves pos).map fun m => Task.spawn fun _ => perft rs (pos.play m) (d - 1)
  tasks.foldl (fun n t => n + t.get) 0

/-- Counters of the perft tables of the Chess Programming Wiki (moves to leaves only). -/
structure PerftStats where
  nodes : Nat := 0
  captures : Nat := 0
  enPassants : Nat := 0
  castles : Nat := 0
  promotions : Nat := 0
  checks : Nat := 0
  /-- Checks given only by pieces other than the one that moved (the convention of the Chess
  Programming Wiki tables: a double check by the moved piece and a discovered piece is counted
  as a double check, not as a discovered check). -/
  discoveredChecks : Nat := 0
  /-- Checks given by two pieces at once. -/
  doubleChecks : Nat := 0
  /-- Leaf positions where the game is over and the player who has just moved has won
  (checkmate in standard chess). -/
  mates : Nat := 0
  /-- Leaf moves that capture a king (impossible in standard chess). -/
  kingCaptures : Nat := 0
  deriving Repr, Inhabited, DecidableEq

instance : Add PerftStats where
  add a b := {
    nodes := a.nodes + b.nodes, captures := a.captures + b.captures,
    enPassants := a.enPassants + b.enPassants, castles := a.castles + b.castles,
    promotions := a.promotions + b.promotions, checks := a.checks + b.checks,
    discoveredChecks := a.discoveredChecks + b.discoveredChecks,
    doubleChecks := a.doubleChecks + b.doubleChecks, mates := a.mates + b.mates,
    kingCaptures := a.kingCaptures + b.kingCaptures }

/-- The counters for one leaf move `m` played in `pos`. -/
def leafStats (rs : RuleSet) (pos : Position) (m : Move) : PerftStats :=
  let after := pos.play m
  let them := pos.turn.opponent
  let checkers := after.checkers them
  -- the squares of the piece(s) that moved: for castling, the king and the rook
  let moved := match pos.castlingSide? m with
    | some side => [m.dst, (castlingGeometry pos.turn side).rookTo]
    | none => [m.dst]
  let won := match rs.outcome? (rs.situation after) with
    | some o => o.result == Result.winner pos.turn
    | none => false
  let count (b : Bool) := if b then 1 else 0
  { nodes := 1
    captures := count (pos.isCapture m)
    enPassants := count (pos.isEnPassant m)
    castles := count (pos.isCastling m)
    promotions := count m.promotion.isSome
    checks := count !checkers.isEmpty
    discoveredChecks := count (!checkers.isEmpty && checkers.all fun s => !moved.contains s)
    doubleChecks := count (checkers.length ≥ 2)
    mates := count won
    kingCaptures := count (match pos.captured? m with
      | some ⟨_, .king⟩ => true
      | _ => false) }

def perftStats (rs : RuleSet) (pos : Position) : Nat → PerftStats
  | 0 => { nodes := 1 }
  | 1 => (rs.legalMoves pos).foldl (fun s m => s + leafStats rs pos m) {}
  | d + 2 => (rs.legalMoves pos).foldl (fun s m => s + perftStats rs (pos.play m) (d + 1)) {}

def perftStatsParallel (rs : RuleSet) (pos : Position) (d : Nat) : PerftStats :=
  if d ≤ 1 then perftStats rs pos d else
  let tasks := (rs.legalMoves pos).map fun m =>
    Task.spawn fun _ => perftStats rs (pos.play m) (d - 1)
  tasks.foldl (fun s t => s + t.get) {}

end Chess
