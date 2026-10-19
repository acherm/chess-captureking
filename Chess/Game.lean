import Chess.Notation.San

/-!
# Games

A game is a starting position and a sequence of moves, played under some rule set. Playing a
move checks that the game is not over and that the move is legal; when it is not, the error
says which rule forbids it. The status of a game takes its history into account (repetitions).
-/

namespace Chess

structure Game where
  rules : RuleSet
  initial : Position
  current : Position
  /-- The positions before `current`, most recent first. -/
  previous : List Position := []
  /-- The moves played so far, in order. -/
  moves : Array Move := #[]
  /-- Their SAN, in order. -/
  sans : Array String := #[]

namespace Game

def new (rules : RuleSet) (initial : Position := Position.start) : Game :=
  { rules, initial, current := initial }

def status (g : Game) : Status := g.rules.status g.current g.previous

/-- Why `m` cannot be played in the current position (`none` if it can). -/
def whyIllegal (g : Game) (m : Move) : Option String :=
  let pos := g.current
  match g.status with
  | .over o => some s!"the game is over: {o}"
  | .ongoing _ =>
    if (g.rules.legalMoves pos).contains m then none
    else if !(g.rules.candidates pos).contains m then
      some s!"{m} is not a move of any piece of the side to move"
    else
      let rules := (g.rules.forbiddenBy pos m).map fun r => s!"{r.name} ({r.doc})"
      some s!"{m} is forbidden by {rules}"

/-- Play a move, given in UCI or SAN. -/
def play (g : Game) (s : String) : Except String Game := do
  let pos := g.current
  let m ← match parseMove g.rules pos s, parseCandidate g.rules pos s with
    | some m, _ => pure m
    | none, some m => pure m   -- an illegal move: explained below
    | none, none => throw s!"move {g.moves.size + 1} '{s}' in {pos.toFen}: not a move of any piece"
  if let some why := g.whyIllegal m then
    throw s!"move {g.moves.size + 1} '{s}' in {pos.toFen}: {why}"
  return { g with
    current := pos.play m
    previous := pos :: g.previous
    moves := g.moves.push m
    sans := g.sans.push (san g.rules pos m) }

def playAll (g : Game) (moves : List String) : Except String Game :=
  moves.foldlM play g

/-- The moves in numbered SAN, e.g. `1. e4 e5 2. Nf3`. -/
def movetext (g : Game) : String := Id.run do
  let mut out := ""
  let mut number := g.initial.fullmoveNumber
  let mut turn := g.initial.turn
  for (s, i) in g.sans.toList.zip (List.range g.sans.size) do
    if turn == .white then out := out ++ s!"{number}. "
    else if i == 0 then out := out ++ s!"{number}... "
    out := out ++ s ++ " "
    if turn == .black then number := number + 1
    turn := turn.opponent
  return out.trimAsciiEnd.toString

end Game

end Chess
