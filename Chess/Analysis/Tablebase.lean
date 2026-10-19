import Std.Data.HashMap
import Chess.Rules.Framework

/-!
# Endgame tablebases, for any rule set

`solveEndgame rs start` computes the exact game-theoretic value (win / loss / draw for the
player to move, with the distance in plies) of every position reachable from the positions
`start`, under rule set `rs`, by retrograde analysis:

1. the game graph is built by exploring all legal moves from the start positions (positions
   are *normalized*: the move counters are reset, so the 50/75-move rules play no role, as is
   usual for tablebases);
2. positions where the game is over get their value from the ending rules;
3. values are propagated backwards: a position is won if some move leads to a lost position,
   and lost if all moves lead to won positions; the rest is drawn.

The same code solves standard chess (wins by checkmate) and natural chess (wins by capturing the
king), so the two tablebases can be compared position by position.
-/

namespace Chess

/-- Exact value of a position, for the player to move. -/
inductive Value where
  | win (plies : Nat)
  | loss (plies : Nat)
  | draw
  deriving DecidableEq, Repr, Inhabited

instance : ToString Value where
  toString
    | .win n => s!"win{n}"
    | .loss n => s!"loss{n}"
    | .draw => "draw"

def Value.sign : Value → Int
  | .win _ => 1
  | .loss _ => -1
  | .draw => 0

/-- The distance to the end of the game, in plies (0 for a draw). -/
def Value.plies : Value → Nat
  | .win n | .loss n => n
  | .draw => 0

/-- Forget the move counters, and the en passant target when no en passant capture is possible. -/
def normalizePosition (rs : RuleSet) (p : Position) : Position :=
  let p := { p with halfmoveClock := 0, fullmoveNumber := 1 }
  match p.epTarget with
  | none => p
  | some _ => if (rs.legalMoves p).any p.isEnPassant then p else { p with epTarget := none }

structure Tablebase where
  positions : Array Position
  index : Std.HashMap Position Nat
  values : Array Value

def Tablebase.value? (tb : Tablebase) (p : Position) (rs : RuleSet) : Option Value :=
  (tb.index.get? (normalizePosition rs p)).map fun i => tb.values[i]!

/-- Map `f` over `xs` in parallel chunks. -/
private def parMap {α β} [Inhabited β] (f : α → β) (xs : Array α) (chunk : Nat := 2048) : Array β :=
  Id.run do
    let mut tasks := #[]
    let mut i := 0
    while i < xs.size do
      let part := xs.extract i (i + chunk)
      tasks := tasks.push (Task.spawn fun _ => part.map f)
      i := i + chunk
    return tasks.foldl (fun acc t => acc ++ t.get) #[]

/-- With `kingCaptureWins`, a position where the player to move can capture the opponent's king is
not explored further: it is won in 1 ply (the capture). This is exact in games won by capturing
the king, and keeps their game graphs from growing with every move that hands the king over. -/
def solveEndgame (rs : RuleSet) (start : Array Position) (kingCaptureWins : Bool := false) :
    Tablebase := Id.run do
  -- 1. explore the game graph, layer by layer
  let mut positions : Array Position := #[]
  let mut index : Std.HashMap Position Nat := {}
  let mut frontier : Array Position := #[]
  for p in start do
    let p := normalizePosition rs p
    if !index.contains p then
      index := index.insert p positions.size
      positions := positions.push p
      frontier := frontier.push p
  -- successors (as indices) and terminal outcomes, in the order of `positions`
  let mut succ : Array (Array Nat) := #[]
  let mut terminal : Array (Option Value) := #[]
  while !frontier.isEmpty do
    let expanded := parMap (fun p =>
      let sit := rs.situation p
      match rs.outcome? sit with
      | some o =>
        let v := if o.result == Result.draw then Value.draw
          else if o.result == Result.winner p.turn then .win 0 else .loss 0
        (some v, #[])
      | none =>
        if kingCaptureWins && p.isInCheck p.turn.opponent then (some (.win 1), #[])
        else (none, (sit.legalMoves.get.map fun m => normalizePosition rs (p.play m)).toArray))
      frontier
    let mut next := #[]
    for (o, children) in expanded do
      terminal := terminal.push o
      let mut ids := #[]
      for c in children do
        match index.get? c with
        | some i => ids := ids.push i
        | none =>
          index := index.insert c positions.size
          ids := ids.push positions.size
          positions := positions.push c
          next := next.push c
      succ := succ.push ids
    frontier := next
  -- 2. predecessors, and the number of successors not yet known to be won (for the mover there)
  let n := positions.size
  let mut pred : Array (Array Nat) := Array.replicate n #[]
  for i in List.range n do
    for j in succ[i]! do
      pred := pred.modify j (·.push i)
  let mut pending : Array Nat := succ.map (·.size)
  let mut values : Array (Option Value) := Array.replicate n none
  let mut queue : Array Nat := #[]
  for i in List.range n do
    if let some v := terminal[i]! then
      values := values.set! i (some v)
  -- decisive terminal positions, by increasing distance (0, then the shortcut wins in 1)
  for d in [0, 1] do
    for i in List.range n do
      if let some v := terminal[i]! then
        if v != Value.draw && v.plies == d then queue := queue.push i
  -- 3. backward propagation, in order of increasing distance
  let mut head := 0
  while head < queue.size do
    let j := queue[head]!
    head := head + 1
    match values[j]! with
    | some (.loss d) =>
      for i in pred[j]! do
        if values[i]!.isNone then
          values := values.set! i (some (.win (d + 1)))
          queue := queue.push i
    | some (.win d) =>
      for i in pred[j]! do
        if values[i]!.isNone then
          pending := pending.modify i (· - 1)
          if pending[i]! == 0 then
            values := values.set! i (some (.loss (d + 1)))
            queue := queue.push i
    | _ => pure ()
  return { positions, index, values := values.map (·.getD .draw) }

/-- All positions with the white king, the black king and the given extra pieces on distinct
squares (pawns not on the first or last rank), with either player to move. -/
def allPlacements (extra : List Piece) : Array Position := Id.run do
  let mut out := #[]
  let pieces : List Piece := ⟨.white, .king⟩ :: ⟨.black, .king⟩ :: extra
  let rec place : List Piece → Board → List Board
    | [], b => [b]
    | p :: ps, b =>
      (Square.all.filter fun s => b.isEmpty s && (p.kind != .pawn || (s.rank != 0 && s.rank != 7)))
        |>.flatMap fun s => place ps (b.set s (some p))
  for b in place pieces Board.empty do
    for turn in [Color.white, .black] do
      out := out.push { board := b, turn, castling := {}, epTarget := none, halfmoveClock := 0,
                        fullmoveNumber := 1 }
  return out

end Chess
