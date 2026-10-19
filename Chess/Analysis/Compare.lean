import Chess.Solver
import Chess.Rules.Standard

/-!
# Comparing two rule sets on a position

`compare a b pos` gathers, for one position, what rule sets `a` (the reference, e.g. standard
chess) and `b` (the variant, e.g. natural chess) say: legal moves, status, and the verdict of a
bounded search. For the moves that `b` allows and `a` forbids, it records *which* legality
rules of `a` forbid them.
-/

namespace Chess

structure Comparison where
  position : Position
  /-- Is the player to move in check? -/
  inCheck : Bool
  movesA : List Move
  movesB : List Move
  /-- Moves legal under `a` only, and under `b` only. -/
  onlyA : List Move
  onlyB : List Move
  /-- For each move of `onlyB`: the legality rules of `a` that forbid it. -/
  forbiddenInA : List (Move × List String)
  /-- Moves of `onlyB` after which the mover's king is not attacked ("non-suicidal"). -/
  safeOnlyB : List Move
  statusA : Status
  statusB : Status
  verdictA : Option Verdict := none
  verdictB : Option Verdict := none

/-- Compare `a` and `b` on `pos`; if `horizon` is given, also run bounded searches with
horizons `horizon` (for `a`) and `horizon + extraPlies` (for `b`). -/
def compare (a b : RuleSet) (pos : Position) (horizon : Option Nat := none)
    (extraPlies : Nat := 2) : Comparison :=
  let movesA := a.legalMoves pos
  let movesB := b.legalMoves pos
  let onlyA := movesA.filter (!movesB.contains ·)
  let onlyB := movesB.filter (!movesA.contains ·)
  let forbiddenInA := onlyB.map fun m => (m, (a.forbiddenBy pos m).map (·.name))
  let safeOnlyB := onlyB.filter fun m => !(pos.play m).isInCheck pos.turn
  { position := pos
    inCheck := pos.isInCheck pos.turn
    movesA, movesB, onlyA, onlyB, forbiddenInA, safeOnlyB
    statusA := a.status pos
    statusB := b.status pos
    verdictA := horizon.map (solve a pos ·)
    verdictB := horizon.map fun h => solve b pos (h + extraPlies) }

namespace Comparison

/-- Number of moves of `onlyB` forbidden (in `a`) by the rule named `rule`. -/
def countForbiddenBy (c : Comparison) (rule : String) : Nat :=
  c.forbiddenInA.countP fun (_, rules) => rules.contains rule

private def statusTag : Status → String
  | .over o => s!"{o.result}:{o.rule}"
  | .ongoing _ => "ongoing"

private def verdictTag (turn : Color) : Option Verdict → String
  | none => ""
  | some v =>
    let res := match v.result? turn with
      | some r => toString r
      | none => "?"
    let detail := match v with
      | .over o => o.rule
      | .win n => s!"win{n}"
      | .loss n => s!"loss{n}"
      | .unknown => "unknown"
    s!"{res}:{detail}"

def tsvHeader : String :=
  "fen\tin_check\tn_a\tn_b\tn_only_a\tn_only_b\tby_noSelfCheck\tby_castlingNotOutOfCheck\t" ++
  "by_castlingNotThroughCheck\tby_noKingCapture\tn_safe_only_b\tsafe_only_b\tstatus_a\tstatus_b\t" ++
  "verdict_a\tverdict_b"

def toTsv (c : Comparison) : String :=
  let turn := c.position.turn
  let fields := [c.position.toFen, toString c.inCheck, toString c.movesA.length,
    toString c.movesB.length, toString c.onlyA.length, toString c.onlyB.length,
    toString (c.countForbiddenBy "noSelfCheck"), toString (c.countForbiddenBy "castlingNotOutOfCheck"),
    toString (c.countForbiddenBy "castlingNotThroughCheck"), toString (c.countForbiddenBy "noKingCapture"),
    toString c.safeOnlyB.length, String.intercalate " " (c.safeOnlyB.map Move.toUci),
    statusTag c.statusA, statusTag c.statusB, verdictTag turn c.verdictA, verdictTag turn c.verdictB]
  String.intercalate "\t" fields

end Comparison

end Chess
