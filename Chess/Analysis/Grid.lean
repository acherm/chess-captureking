import Chess.Analysis.Tablebase
import Chess.Rules.Variants
import Chess.Solver

/-!
# Comparing the games of Hamkins' grid

Hamkins asks which of his variations (standard or natural; ordinary, normal play, passing or
lose-your-turn) are equivalent. Two games are compared by the *values* they give to the same
positions: win, draw or loss for the player to move, under best play. The positions are those
valid in standard chess, the stricter of the two validity notions.

* `gridEndgame` computes exact values (by retrograde analysis, `solveEndgame`) of every position
  with a given material, under every rule set of a list, and gathers the pairwise disagreements,
  with one witness position per disagreeing pair.
* `exactValue` solves the game graph reachable from one position.
* `gridVerdicts` runs bounded searches (`solve`) on positions from real games, with two more
  plies for the games that are won by capturing the king.
-/

namespace Chess

namespace Grid

/-- Does `rs` win by capturing the king (natural family)? Such games need two more plies. -/
def winsByCapture (rs : RuleSet) : Bool := rs.endings.any (·.name == Natural.kingCaptured.name)

/-- The exact value of each of the `start` positions under `rs`, with the size of the game
graph explored. -/
def startValues (rs : RuleSet) (start : Array Position) : Array Value × Nat :=
  let tb := solveEndgame rs start (kingCaptureWins := winsByCapture rs)
  (start.map fun p => (tb.value? p rs).getD .draw, tb.positions.size)

/-- The exact value of `pos` under `rs`: retrograde analysis of every position reachable from
`pos` (move counters ignored; a game that goes on forever is a draw). -/
def exactValue (rs : RuleSet) (pos : Position) : Value × Nat :=
  match startValues rs #[pos] with
  | (vs, n) => (vs[0]!, n)

/-- How good a witness of a disagreement between two values is (smaller is better): opposite
decisive results first, then short decisive lines. -/
def witnessScore (a b : Value) : Nat :=
  (if a.sign * b.sign == -1 then 0 else 100000) + Value.plies a + Value.plies b

structure PairReport where
  a : Nat
  b : Nat
  /-- Positions where the values have different signs. -/
  disagreements : Nat
  witness : Option (Position × Value × Value)

/-- Pairwise comparison of value arrays (indexed like `start`). -/
def comparePairs (start : Array Position) (values : Array (Array Value)) : Array PairReport :=
  Id.run do
    let mut out := #[]
    for i in List.range values.size do
      for j in List.range values.size do
        if i < j then
          let mut count := 0
          let mut best : Option (Position × Value × Value) := none
          for k in List.range start.size do
            let (a, b) := (values[i]![k]!, values[j]![k]!)
            if a.sign != b.sign then
              count := count + 1
              best := match best with
                | some (p, x, y) => if witnessScore a b < witnessScore x y then some (start[k]!, a, b)
                                   else some (p, x, y)
                | none => some (start[k]!, a, b)
          out := out.push { a := i, b := j, disagreements := count, witness := best }
    return out

/-- Agreement of a naturalized standard game with its natural counterpart: sign disagreements,
and the histogram of distance differences (natural minus naturalized) on positions decisive in
both with the same sign. -/
def compareBridge (va vb : Array Value) : Nat × List (Int × Nat) := Id.run do
  let mut disagreements := 0
  let mut deltas : Std.HashMap Int Nat := {}
  for k in List.range va.size do
    let (a, b) := (va[k]!, vb[k]!)
    if a.sign != b.sign then disagreements := disagreements + 1
    else if a.sign != 0 then
      let d : Int := (Value.plies b : Int) - Value.plies a
      deltas := deltas.insert d (deltas.getD d 0 + 1)
  return (disagreements, deltas.toList.mergeSort (fun x y => x.1 ≤ y.1))

def counts (vs : Array Value) : Nat × Nat × Nat :=
  vs.foldl (init := (0, 0, 0)) fun (w, d, l) v => match v with
    | Value.win _ => (w + 1, d, l)
    | Value.draw => (w, d + 1, l)
    | Value.loss _ => (w, d, l + 1)

/-! ## Bounded verdicts on arbitrary positions -/

/-- `W`, `D`, `L` (for the player to move) or `?`, with the detail of the verdict. -/
def verdictTag (turn : Color) (v : Verdict) : String :=
  let res := match v.result? turn with
    | some r => if r == Result.draw then "D" else if r == Result.winner turn then "W" else "L"
    | none => "?"
  let detail := match v with
    | .over o => o.rule
    | .win n => s!"win{n}"
    | .loss n => s!"loss{n}"
    | .unknown => "unknown"
  s!"{res}:{detail}"

/-- The verdicts of the rule sets on `pos`: horizon `h` plies, `h + 2` for the natural family. -/
def gridVerdicts (sets : List RuleSet) (pos : Position) (h : Nat) : List String :=
  sets.map fun rs => verdictTag pos.turn (solve rs pos (if winsByCapture rs then h + 2 else h))

end Grid

end Chess
