import Chess.Rules.Framework

/-!
# Bounded game-theoretic search

`canWin rs pos d`: the player to move can force a win (under rule set `rs`) within `d` plies,
whatever the opponent does. `mustLose rs pos d`: whatever the player to move does, the
opponent can force a win within `d` plies. Both only use the legal moves and the ending
rules of `rs`: the same code solves standard chess (wins by checkmate) and natural chess (wins
by capture of the king).

Plies count the moves of both players: a mate in 1 is a win in 1 ply in standard chess and a
win in 3 plies in natural chess (mate, any reply, capture of the king). Repetitions are not
taken into account (the search sees positions, not games).
-/

namespace Chess

/-- Order moves so that forcing moves are tried first: captures of a king, then other captures,
then the rest. (Only affects speed.) -/
def orderForSearch (pos : Position) (moves : List Move) : List Move :=
  let isKingCapture (m : Move) := match pos.captured? m with
    | some ⟨_, .king⟩ => true
    | _ => false
  let kingCaptures := moves.filter isKingCapture
  let captures := moves.filter fun m => pos.isCapture m && !isKingCapture m
  let quiet := moves.filter fun m => !pos.isCapture m
  kingCaptures ++ captures ++ quiet

mutual

/-- The player to move can force a win within `d` plies. -/
def canWin (rs : RuleSet) (pos : Position) : Nat → Bool
  | 0 => false
  | d + 1 =>
    let sit := rs.situation pos
    match rs.outcome? sit with
    | some _ => false
    | none => (orderForSearch pos sit.legalMoves.get).any fun m => mustLose rs (pos.play m) d

/-- Whatever the player to move does, the opponent can force a win within `d` plies. -/
def mustLose (rs : RuleSet) (pos : Position) : Nat → Bool
  | 0 =>
    match rs.outcome? (rs.situation pos) with
    | some o => o.result == Result.winner pos.turn.opponent
    | none => false
  | d + 1 =>
    let sit := rs.situation pos
    match rs.outcome? sit with
    | some o => o.result == Result.winner pos.turn.opponent
    | none => sit.legalMoves.get.all fun m => canWin rs (pos.play m) d

end

/-- What a bounded search says about a position, from the point of view of the player to move. -/
inductive Verdict where
  /-- The game is already over. -/
  | over (o : Outcome)
  /-- The player to move can force a win within this many plies (and not fewer). -/
  | win (plies : Nat)
  /-- The player to move loses within this many plies whatever it does (and not fewer). -/
  | loss (plies : Nat)
  /-- Neither, within the horizon. -/
  | unknown
  deriving DecidableEq, Repr, Inhabited

instance : ToString Verdict where
  toString
    | .over o => s!"over {o}"
    | .win n => s!"win in {n} plies"
    | .loss n => s!"loss in {n} plies"
    | .unknown => "unknown"

/-- The result of the game under best play, as far as the verdict says (`none` if unknown). -/
def Verdict.result? (v : Verdict) (turn : Color) : Option Result :=
  match v with
  | .over o => some o.result
  | .win _ => some (Result.winner turn)
  | .loss _ => some (Result.winner turn.opponent)
  | .unknown => none

/-- Iterative deepening up to `horizon` plies: wins are found at odd depths, losses at even
depths. -/
def solve (rs : RuleSet) (pos : Position) (horizon : Nat) : Verdict :=
  match rs.outcome? (rs.situation pos) with
  | some o => .over o
  | none =>
    let found := (List.range horizon).findSome? fun i =>
      let d := i + 1
      if d % 2 == 1 then (if canWin rs pos d then some (Verdict.win d) else none)
      else if mustLose rs pos d then some (Verdict.loss d) else none
    found.getD .unknown

end Chess
