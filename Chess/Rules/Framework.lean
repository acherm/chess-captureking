import Chess.Core.Play
import Chess.Core.Fen

/-!
# Rule sets

A *rule set* is a list of named, documented rules of four kinds:

* **movement rules** propose *candidate* moves (how the pieces move: FIDE Article 3.1–3.8);
* **legality rules** may forbid candidates; a candidate is *legal* iff no legality rule
  forbids it (e.g. FIDE 3.9.2: do not leave your king in check);
* **ending rules** say when a game is over and with what result (checkmate, stalemate, …),
  tried in order — the first rule that applies decides;
* **claim rules** say when a player may claim a draw (FIDE 9.2, 9.3);

plus **validity rules** saying which positions make sense at all (used to vet FEN input),
and optional **fallback** movement rules, whose moves are offered only when no candidate is
legal (empty in FIDE chess; a "pass" in some variants).

Variants of chess are obtained by removing, adding or replacing rules of an existing rule
set with the combinators at the end of this file; `RuleSet.diff` prints what changed.
-/

namespace Chess

/-- A movement rule proposes candidate moves. -/
structure MovementRule where
  name : String
  /-- Where the rule comes from and what it says. -/
  doc : String
  candidates : Position → List Move

/-- What a legality rule says about the candidate moves of one position. -/
structure MoveTest where
  /-- `true` when the rule permits every move of the position (the test is then skipped). -/
  permitsAll : Bool := false
  test : Move → Bool

/-- A legality rule may forbid candidate moves.

`permits pos` is evaluated once per position and then applied to every candidate: a rule may
compute facts about the position (e.g. "is my king in check?") before returning its test. -/
structure LegalityRule where
  name : String
  doc : String
  permits : Position → MoveTest

/-- The result of a finished game. -/
inductive Result where
  | whiteWins
  | blackWins
  | draw
  deriving DecidableEq, Repr, Inhabited, Hashable

def Result.winner : Color → Result
  | .white => .whiteWins
  | .black => .blackWins

instance : ToString Result where
  toString
    | .whiteWins => "1-0"
    | .blackWins => "0-1"
    | .draw => "1/2-1/2"

/-- What ending rules look at: the position, its legal moves, and the earlier positions of the
game (most recent first; empty when analysing a bare position). The legal moves are computed
only when a rule needs them. -/
structure Situation where
  position : Position
  legalMoves : Thunk (List Move)
  /-- Whether the player to move has no legal move (cheaper than computing all legal moves). -/
  noLegalMove : Thunk Bool
  history : List Position := []
  /-- The legal moves of any position under the same rules. Needed by rules that compare
  positions, which are "the same" only if they have the same possible moves (FIDE 9.2.3). -/
  legalMovesOf : Position → List Move

/-- An ending rule may declare the game over (or a draw claimable). -/
structure EndingRule where
  name : String
  doc : String
  judge : Situation → Option Result

/-- A validity rule is a condition that every sensible position satisfies. -/
structure ValidityRule where
  name : String
  doc : String
  holds : Position → Bool

/-- How a game ended: its result and the rule that ended it. -/
structure Outcome where
  result : Result
  rule : String
  deriving DecidableEq, Repr, Inhabited

instance : ToString Outcome := ⟨fun o => s!"{o.result} ({o.rule})"⟩

/-- The state of a game: still going on (possibly with draws that may be claimed), or over. -/
inductive Status where
  | ongoing (claimable : List Outcome)
  | over (outcome : Outcome)
  deriving DecidableEq, Repr, Inhabited

instance : ToString Status where
  toString
    | .ongoing [] => "ongoing"
    | .ongoing cs => s!"ongoing (claimable: {cs})"
    | .over o => s!"over: {o}"

def Status.isOver : Status → Bool
  | .over _ => true
  | .ongoing _ => false

def Status.result? : Status → Option Result
  | .over o => some o.result
  | .ongoing _ => none

structure RuleSet where
  name : String
  movement : List MovementRule
  legality : List LegalityRule
  endings : List EndingRule
  claims : List EndingRule := []
  validity : List ValidityRule := []
  fallback : List MovementRule := []

namespace RuleSet

/-! ## Moves -/

/-- Candidate moves: everything the movement rules propose. -/
def candidates (rs : RuleSet) (pos : Position) : List Move :=
  rs.movement.flatMap fun r => r.candidates pos

/-- The legality rules that forbid `m` in `pos` (empty iff `m` is legal, when it is a
candidate). -/
def forbiddenBy (rs : RuleSet) (pos : Position) (m : Move) : List LegalityRule :=
  rs.legality.filter fun r =>
    let t := r.permits pos
    !(t.permitsAll || t.test m)

/-- The legal moves of a position: the candidates that every legality rule permits, or, if
there are none, the permitted fallback moves. -/
def legalMoves (rs : RuleSet) (pos : Position) : List Move :=
  let tests := rs.legality.map (fun r => r.permits pos) |>.filter (!·.permitsAll)
  let legal (m : Move) := tests.all fun t => t.test m
  match (rs.candidates pos).filter legal with
  | [] => (rs.fallback.flatMap fun r => r.candidates pos).filter legal
  | moves => moves

/-- Does the player to move have a legal move? (Same as `legalMoves` being non-empty, but stops
at the first legal move found.) -/
def hasLegalMove (rs : RuleSet) (pos : Position) : Bool :=
  let tests := rs.legality.map (fun r => r.permits pos) |>.filter (!·.permitsAll)
  let legal (m : Move) := tests.all fun t => t.test m
  rs.movement.any (fun r => (r.candidates pos).any legal) ||
    rs.fallback.any fun r => (r.candidates pos).any legal

def isLegal (rs : RuleSet) (pos : Position) (m : Move) : Bool := (rs.legalMoves pos).contains m

/-! ## End of the game -/

def situation (rs : RuleSet) (pos : Position) (history : List Position := []) : Situation :=
  { position := pos, history, legalMovesOf := rs.legalMoves
    legalMoves := Thunk.mk fun _ => rs.legalMoves pos
    noLegalMove := Thunk.mk fun _ => !rs.hasLegalMove pos }

/-- The first ending rule that applies, if any. -/
def outcome? (rs : RuleSet) (sit : Situation) : Option Outcome :=
  rs.endings.findSome? fun r => (r.judge sit).map fun res => ⟨res, r.name⟩

/-- The draws (or other results) that may be claimed. -/
def claimable (rs : RuleSet) (sit : Situation) : List Outcome :=
  rs.claims.filterMap fun r => (r.judge sit).map fun res => ⟨res, r.name⟩

def statusOf (rs : RuleSet) (sit : Situation) : Status :=
  match rs.outcome? sit with
  | some o => .over o
  | none => .ongoing (rs.claimable sit)

/-- The status of a position, given the earlier positions of the game (most recent first). -/
def status (rs : RuleSet) (pos : Position) (history : List Position := []) : Status :=
  rs.statusOf (rs.situation pos history)

/-! ## Validity of positions -/

/-- The validity rules that `pos` violates. -/
def violations (rs : RuleSet) (pos : Position) : List ValidityRule :=
  rs.validity.filter fun r => !r.holds pos

def isValid (rs : RuleSet) (pos : Position) : Bool := rs.violations pos |>.isEmpty

/-! ## Building variants

Rules are identified by their names: removing a rule removes every rule with the same
name. -/

def removeNamed {α} (name : α → String) (xs removed : List α) : List α :=
  xs.filter fun x => !(removed.any fun r => name r == name x)

def renamed (rs : RuleSet) (name : String) : RuleSet := { rs with name }

def withoutMovement (rs : RuleSet) (rules : List MovementRule) : RuleSet :=
  { rs with movement := removeNamed (·.name) rs.movement rules }
def withMovement (rs : RuleSet) (rules : List MovementRule) : RuleSet :=
  { rs with movement := rs.movement ++ rules }

def withoutLegality (rs : RuleSet) (rules : List LegalityRule) : RuleSet :=
  { rs with legality := removeNamed (·.name) rs.legality rules }
def withLegality (rs : RuleSet) (rules : List LegalityRule) : RuleSet :=
  { rs with legality := rs.legality ++ rules }

def withoutEndings (rs : RuleSet) (rules : List EndingRule) : RuleSet :=
  { rs with endings := removeNamed (·.name) rs.endings rules }
/-- Add ending rules with priority over the existing ones. -/
def withEndingsFirst (rs : RuleSet) (rules : List EndingRule) : RuleSet :=
  { rs with endings := rules ++ rs.endings }
def withEndingsLast (rs : RuleSet) (rules : List EndingRule) : RuleSet :=
  { rs with endings := rs.endings ++ rules }
/-- Insert ending rules just after the ending rule named like `anchor`. -/
def withEndingsAfter (rs : RuleSet) (anchor : EndingRule) (rules : List EndingRule) : RuleSet :=
  { rs with endings := rs.endings.flatMap fun r => if r.name == anchor.name then r :: rules else [r] }
/-- Replace the ending rule named like `old` by `new`, at the same place in the order. -/
def replacingEnding (rs : RuleSet) (old new : EndingRule) : RuleSet :=
  { rs with endings := rs.endings.map fun r => if r.name == old.name then new else r }

def withoutClaims (rs : RuleSet) (rules : List EndingRule) : RuleSet :=
  { rs with claims := removeNamed (·.name) rs.claims rules }
def withClaims (rs : RuleSet) (rules : List EndingRule) : RuleSet :=
  { rs with claims := rs.claims ++ rules }

def withoutValidity (rs : RuleSet) (rules : List ValidityRule) : RuleSet :=
  { rs with validity := removeNamed (·.name) rs.validity rules }
def withValidity (rs : RuleSet) (rules : List ValidityRule) : RuleSet :=
  { rs with validity := rs.validity ++ rules }

def withFallback (rs : RuleSet) (rules : List MovementRule) : RuleSet :=
  { rs with fallback := rs.fallback ++ rules }

/-! ## Documentation -/

private def section_ (title : String) (rules : List (String × String)) : String :=
  if rules.isEmpty then "" else
  s!"{title}:\n" ++ String.join (rules.map fun (n, d) => s!"  - {n}: {d}\n")

/-- A description of all the rules of the rule set. -/
def describe (rs : RuleSet) : String :=
  s!"Rule set '{rs.name}'\n" ++
  section_ "Movement" (rs.movement.map fun r => (r.name, r.doc)) ++
  section_ "Legality" (rs.legality.map fun r => (r.name, r.doc)) ++
  section_ "Endings (first applicable rule decides)" (rs.endings.map fun r => (r.name, r.doc)) ++
  section_ "Draw claims" (rs.claims.map fun r => (r.name, r.doc)) ++
  section_ "Validity of positions" (rs.validity.map fun r => (r.name, r.doc)) ++
  section_ "Fallback moves (when no move is legal)" (rs.fallback.map fun r => (r.name, r.doc))

private def diffNames (kind : String) (a b : List (String × String)) : List String :=
  let names (xs : List (String × String)) := xs.map (·.1)
  (a.filter (fun x => !(names b).contains x.1)).map (fun (n, d) => s!"- {kind} {n}: {d}") ++
  (b.filter (fun x => !(names a).contains x.1)).map (fun (n, d) => s!"+ {kind} {n}: {d}")

/-- The rules removed (`-`) and added (`+`) when going from rule set `a` to rule set `b`,
plus a note when the order of the ending rules changed. -/
def diff (a b : RuleSet) : List String :=
  let pairsM (rs : List MovementRule) := rs.map fun r => (r.name, r.doc)
  let pairsL (rs : List LegalityRule) := rs.map fun r => (r.name, r.doc)
  let pairsE (rs : List EndingRule) := rs.map fun r => (r.name, r.doc)
  let pairsV (rs : List ValidityRule) := rs.map fun r => (r.name, r.doc)
  diffNames "movement" (pairsM a.movement) (pairsM b.movement) ++
  diffNames "legality" (pairsL a.legality) (pairsL b.legality) ++
  diffNames "ending" (pairsE a.endings) (pairsE b.endings) ++
  diffNames "claim" (pairsE a.claims) (pairsE b.claims) ++
  diffNames "validity" (pairsV a.validity) (pairsV b.validity) ++
  diffNames "fallback" (pairsM a.fallback) (pairsM b.fallback) ++
  [s!"  ending rules, in order: {b.endings.map (·.name)}"]

end RuleSet

end Chess
