import Chess.Analysis.Compare
import Chess.Notation.San
import Chess.Perft

/-!
# Where do two rule sets start to disagree?

`divergences a b pos plies` explores the tree of moves that are legal under *both* rule sets,
up to `plies` plies from `pos`, and returns the positions where the two rule sets disagree on
the legal moves.

Since every standard legal move is a natural legal move (`standard_legal_subset_natural`), the
perft difference decomposes over these divergence points:

    perft_nat(p, d) - perft_std(p, d)
      = Σ_{m common} (perft_nat(p·m, d-1) - perft_std(p·m, d-1)) + Σ_{m natural only} perft_nat(p·m, d-1)
-/

namespace Chess

structure Divergence where
  /-- Moves from the root, in order. -/
  path : List Move
  position : Position
  onlyA : List Move
  onlyB : List Move
  /-- For each move of `onlyB`, the legality rules of `a` that forbid it. -/
  forbiddenInA : List (Move × List String)

def divergences (a b : RuleSet) (pos : Position) : Nat → List Divergence :=
  go [] pos
where
  go (path : List Move) (pos : Position) : Nat → List Divergence
    | 0 => []
    | n + 1 =>
      let movesA := a.legalMoves pos
      let movesB := b.legalMoves pos
      let onlyA := movesA.filter (!movesB.contains ·)
      let onlyB := movesB.filter (!movesA.contains ·)
      let here := if onlyA.isEmpty && onlyB.isEmpty then [] else
        [{ path := path.reverse, position := pos, onlyA, onlyB,
           forbiddenInA := onlyB.map fun m => (m, (a.forbiddenBy pos m).map (·.name)) }]
      here ++ (movesA.filter movesB.contains).flatMap fun m => go (m :: path) (pos.play m) n

/-- The moves of a path, in SAN under rule set `rs`, numbered from `pos`. -/
def pathSan (rs : RuleSet) (pos : Position) (path : List Move) : String := Id.run do
  let mut out := ""
  let mut p := pos
  for m in path do
    if p.turn == .white then out := out ++ s!"{p.fullmoveNumber}. "
    else if out.isEmpty then out := out ++ s!"{p.fullmoveNumber}... "
    out := out ++ san rs p m ++ " "
    p := p.play m
  return out

/-- A report on the divergences of `a` and `b` within `plies` plies of `pos`: how many
positions disagree at each ply, which rules of `a` forbid the extra moves of `b`, and examples.
With `perftDepth`, also the contribution of each ply to the perft difference at that depth. -/
def divergenceReport (a b : RuleSet) (pos : Position) (plies : Nat) (examples : Nat := 10)
    (perftDepth : Option Nat := none) : String := Id.run do
  let ds := divergences a b pos plies
  let mut out := s!"Divergences between '{a.name}' and '{b.name}' within {plies} plies of {pos.toFen}\n"
  out := out ++ s!"{ds.length} positions where the legal moves differ\n"
  for k in List.range plies do
    let atK := ds.filter (·.path.length == k)
    let extraB := atK.foldl (· + ·.onlyB.length) 0
    let extraA := atK.foldl (· + ·.onlyA.length) 0
    out := out ++ s!"  after {k} plies: {atK.length} positions, {extraB} moves only in '{b.name}', {extraA} only in '{a.name}'"
    if let some d := perftDepth then
      if k < d then
        let contribution := atK.foldl (init := 0) fun acc dv =>
          acc + dv.onlyB.foldl (fun n m => n + perft b (dv.position.play m) (d - k - 1)) 0
        out := out ++ s!"; contribution to perft({d}) difference: {contribution}"
    out := out ++ "\n"
  -- why are the extra moves forbidden in `a`?
  let reasons := ds.flatMap fun dv => dv.forbiddenInA.map fun (_, rs) => String.intercalate "+" rs
  let distinct := reasons.foldl (fun acc r => if acc.contains r then acc else acc ++ [r]) []
  out := out ++ s!"Rules of '{a.name}' forbidding the extra moves of '{b.name}':\n"
  for r in distinct do
    out := out ++ s!"  {r}: {reasons.count r}\n"
  out := out ++ s!"First {examples} examples:\n"
  for dv in ds.take examples do
    let extra := dv.forbiddenInA.map fun (m, rs) => s!"{san b dv.position m} [{String.intercalate "+" rs}]"
    out := out ++ s!"  {pathSan a pos dv.path}| {dv.position.toFen}\n    only in '{b.name}': {String.intercalate ", " extra}\n"
  return out

end Chess
