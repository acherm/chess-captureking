import Chess

/-!
# Test suite

    lake build tests && .lake/build/bin/tests [--deep]

Perft and perft counters on the reference positions of the Chess Programming Wiki (standard
chess), perft of natural chess (checked against an independent Python reference, see
`scripts/crossval.py`), and situations exercising individual rules of both rule sets.
`--deep` runs the larger perft depths (a few minutes).
-/

open Chess

structure Check where
  name : String
  ok : Unit → Bool

def initial := startFen
def kiwipete := "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
def pos3 := "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"
def pos4 := "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1"
def pos4mirror := "r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1"
def pos5 := "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8"
def pos6 := "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10"

def perftCheck (rs : RuleSet) (name fen : String) (d expected : Nat) : Check :=
  { name := s!"{rs.name} perft {name} depth {d} = {expected}",
    ok := fun _ => perftParallel rs (Position.ofFen! fen) d == expected }

/-- Expected counters: nodes, captures, ep, castles, promotions, checks, discovered checks,
double checks, checkmates (Chess Programming Wiki, "Perft Results"). -/
def statsCheck (name fen : String) (d : Nat) (e : List Nat) : Check :=
  { name := s!"standard perft counters {name} depth {d}",
    ok := fun _ =>
      let s := perftStatsParallel Standard.rules (Position.ofFen! fen) d
      [s.nodes, s.captures, s.enPassants, s.castles, s.promotions, s.checks, s.discoveredChecks,
        s.doubleChecks, s.mates] == e }

def gameCheck (rs : RuleSet) (name : String) (moves : List String) (expected : Status → Bool)
    (fen := startFen) : Check :=
  { name := s!"{rs.name}: {name}",
    ok := fun _ => match (Game.new rs (Position.ofFen! fen)).playAll moves with
      | .ok g => expected g.status
      | .error _ => false }

def illegalCheck (rs : RuleSet) (name : String) (moves : List String) (rule : String)
    (fen := startFen) : Check :=
  { name := s!"{rs.name}: {name} is illegal ({rule})",
    ok := fun _ => match (Game.new rs (Position.ofFen! fen)).playAll moves with
      | .ok _ => false
      | .error e => (e.splitOn rule).length > 1 }

def overWith (r : Result) (rule : String) : Status → Bool
  | .over o => o.result == r && o.rule == rule
  | _ => false

def ongoing : Status → Bool
  | .ongoing _ => true
  | _ => false

def claimable (rule : String) : Status → Bool
  | .ongoing cs => cs.any (·.rule == rule)
  | _ => false

def shallow : List Check := [
  perftCheck Standard.rules "initial" initial 4 197281,
  perftCheck Standard.rules "kiwipete" kiwipete 3 97862,
  perftCheck Standard.rules "pos3" pos3 5 674624,
  perftCheck Standard.rules "pos4" pos4 4 422333,
  perftCheck Standard.rules "pos4-mirrored" pos4mirror 4 422333,
  perftCheck Standard.rules "pos5" pos5 3 62379,
  perftCheck Standard.rules "pos6" pos6 3 89890,
  statsCheck "initial" initial 4 [197281, 1576, 0, 0, 0, 469, 0, 0, 8],
  statsCheck "kiwipete" kiwipete 3 [97862, 17102, 45, 3162, 0, 993, 0, 0, 1],
  statsCheck "pos3" pos3 4 [43238, 3348, 123, 0, 0, 1680, 106, 0, 17],
  statsCheck "pos4" pos4 3 [9467, 1021, 4, 0, 120, 38, 2, 0, 22],
  -- natural chess (values checked against scripts/crossval.py)
  perftCheck Natural.rules "initial" initial 3 8902,
  perftCheck Natural.rules "initial" initial 4 197742,
  perftCheck Natural.rules "kiwipete" kiwipete 2 2049,
  perftCheck Natural.rules "kiwipete" kiwipete 3 98903,
  perftCheck Natural.rules "pos3" pos3 4 88813,
  perftCheck Natural.rules "pos4" pos4 3 71811,
  perftCheck Natural.rules "pos5" pos5 3 71104,
  perftCheck Natural.rules "pos6" pos6 3 94089,
  -- variants isolating the rules: with the no-self-check rule back, natural chess only differs
  -- from standard chess by castling
  perftCheck Variants.naturalNoSuicide "initial" initial 5 4865609,
  perftCheck Variants.standardFreeCastling "kiwipete" kiwipete 3 98196,
  perftCheck Variants.naturalNoSuicide "kiwipete" kiwipete 3 98196,
  -- standard chess: game endings
  gameCheck Standard.rules "fool's mate" ["f3", "e5", "g4", "Qh4#"] (overWith .blackWins "checkmate"),
  gameCheck Standard.rules "scholar's mate" ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"]
    (overWith .whiteWins "checkmate"),
  gameCheck Standard.rules "stalemate" ["Qc7"] (overWith .draw "stalemate")
    (fen := "k7/8/1Q6/8/8/8/8/1K6 w - - 0 1"),
  gameCheck Standard.rules "dead position K+B v K" ["Kxd2"] (overWith .draw "deadPosition")
    (fen := "k7/8/8/8/8/8/3r4/3KB3 w - - 0 1"),
  gameCheck Standard.rules "threefold repetition claim"
    ["Nf3", "Nf6", "Ng1", "Ng8", "Nf3", "Nf6", "Ng1", "Ng8"] (claimable "threefoldRepetition"),
  gameCheck Standard.rules "no claim after two repetitions" ["Nf3", "Nf6", "Ng1", "Ng8"]
    (fun s => s == .ongoing []),
  gameCheck Standard.rules "fivefold repetition"
    ["Nf3", "Nf6", "Ng1", "Ng8", "Nf3", "Nf6", "Ng1", "Ng8", "Nf3", "Nf6", "Ng1", "Ng8",
     "Nf3", "Nf6", "Ng1", "Ng8"] (overWith .draw "fivefoldRepetition"),
  gameCheck Standard.rules "fifty-move claim" ["Kb1"] (claimable "fiftyMoves")
    (fen := "8/8/8/4k3/8/8/2r5/K7 w - - 99 80"),
  gameCheck Standard.rules "seventy-five-move rule" ["Kb1"] (overWith .draw "seventyFiveMoves")
    (fen := "8/8/8/4k3/8/8/2r5/K7 w - - 149 100"),
  gameCheck Standard.rules "checkmate beats the 75-move rule" ["Rc8#"] (overWith .whiteWins "checkmate")
    (fen := "k7/8/1K6/8/8/8/8/2R5 w - - 149 100"),
  gameCheck Standard.rules "en passant" ["e4", "a6", "e5", "d5", "exd6"] ongoing,
  illegalCheck Standard.rules "late en passant" ["e4", "a6", "e5", "d5", "a3", "a5", "exd6"]
    "not a move of any piece",
  illegalCheck Standard.rules "en passant exposing the king along the rank" ["exd6"] "noSelfCheck"
    (fen := "8/8/8/K2pP2r/8/8/8/7k w - d6 0 1"),
  illegalCheck Standard.rules "castling out of check" ["O-O"] "castlingNotOutOfCheck"
    (fen := "4r1k1/8/8/8/8/8/8/4K2R w K - 0 1"),
  illegalCheck Standard.rules "castling through check" ["O-O"] "castlingNotThroughCheck"
    (fen := "5rk1/8/8/8/8/8/8/4K2R w K - 0 1"),
  illegalCheck Standard.rules "castling into check" ["O-O"] "noSelfCheck"
    (fen := "6rk/8/8/8/8/8/8/4K2R w K - 0 1"),
  illegalCheck Standard.rules "castling after the king moved" ["Kf1", "Kf7", "Ke1", "Kg8", "O-O"]
    "not a move of any piece" (fen := "6k1/8/8/8/8/8/8/4K2R w K - 0 1"),
  illegalCheck Standard.rules "moving a pinned piece" ["Nf3"] "noSelfCheck"
    (fen := "4k3/8/8/b7/8/8/3N4/4K3 w - - 0 1"),
  illegalCheck Standard.rules "moving after checkmate" ["f3", "e5", "g4", "Qh4", "a3"] "the game is over",
  -- natural chess
  gameCheck Natural.rules "king capture ends the game" ["e4", "f6", "Qh5", "Kf7", "Qxf7"]
    (overWith .whiteWins "kingCaptured"),
  gameCheck Natural.rules "fool's 'mate' is not the end" ["f3", "e5", "g4", "Qh4"] ongoing,
  gameCheck Natural.rules "... but the king is captured next" ["f3", "e5", "g4", "Qh4", "a3", "Qxe1"]
    (overWith .blackWins "kingCaptured"),
  gameCheck Natural.rules "castling out of check" ["O-O"] ongoing
    (fen := "4r1k1/8/8/8/8/8/8/4K2R w K - 0 1"),
  gameCheck Natural.rules "castling through check" ["O-O"] ongoing
    (fen := "5rk1/8/8/8/8/8/8/4K2R w K - 0 1"),
  gameCheck Natural.rules "castling into check loses the king" ["O-O", "Rxg1"]
    (overWith .blackWins "kingCaptured") (fen := "6rk/8/8/8/8/8/8/4K2R w K - 0 1"),
  gameCheck Natural.rules "stalemate is not a draw" ["Qc7", "Kb8", "Qxb8"]
    (overWith .whiteWins "kingCaptured") (fen := "k7/8/1Q6/8/8/8/8/1K6 w - - 0 1"),
  gameCheck Natural.rules "K v K is not a dead position" [] ongoing
    (fen := "8/8/8/4k3/8/8/8/4K3 w - - 0 1"),
  illegalCheck Natural.rules "moving after the king capture" ["e4", "f6", "Qh5", "Kf7", "Qxf7", "e6"]
    "the game is over"
]

def deep : List Check := [
  perftCheck Standard.rules "initial" initial 5 4865609,
  perftCheck Standard.rules "kiwipete" kiwipete 4 4085603,
  perftCheck Standard.rules "pos3" pos3 6 11030083,
  perftCheck Standard.rules "pos4" pos4 5 15833292,
  perftCheck Standard.rules "pos4-mirrored" pos4mirror 5 15833292,
  perftCheck Standard.rules "pos5" pos5 4 2103487,
  perftCheck Standard.rules "pos6" pos6 4 3894594,
  statsCheck "initial" initial 5 [4865609, 82719, 258, 0, 0, 27351, 6, 0, 347],
  statsCheck "kiwipete" kiwipete 4 [4085603, 757163, 1929, 128013, 15172, 25523, 42, 6, 43],
  statsCheck "pos3" pos3 5 [674624, 52051, 1165, 0, 0, 52950, 1292, 3, 0],
  statsCheck "pos4" pos4 4 [422333, 131393, 0, 7795, 60032, 15492, 19, 0, 5],
  { name := "KBK and KPK tablebases: standard-naturalized and natural have the same values, natural 2 plies longer",
    ok := fun _ => [[⟨.white, .bishop⟩], [⟨.white, .pawn⟩]].all fun extra =>
      let start := (allPlacements extra).filter Standard.rules.isValid
      let a := solveEndgame Variants.standardNaturalized start
      let b := solveEndgame Natural.rules start
      start.all fun p => match a.value? p Variants.standardNaturalized, b.value? p Natural.rules with
        | some (.win x), some (.win y) => y == x + 2
        | some (.loss x), some (.loss y) => y == x + 2
        | some .draw, some .draw => true
        | _, _ => false },
  { name := "KQK and KPK tablebases: natural-standardized and standard have the same values, 2 plies longer",
    ok := fun _ => [[⟨.white, .queen⟩], [⟨.white, .pawn⟩]].all fun extra =>
      let start := (allPlacements extra).filter Standard.rules.isValid
      let a := solveEndgame Standard.rules start
      let b := solveEndgame Variants.naturalStandardized start
      start.all fun p => match a.value? p Standard.rules, b.value? p Variants.naturalStandardized with
        | some (.win x), some (.win y) => y == x + 2
        | some (.loss x), some (.loss y) => y == x + 2
        | some .draw, some .draw => true
        | _, _ => false },
  perftCheck Natural.rules "initial" initial 5 4897256,
  perftCheck Natural.rules "initial" initial 6 120909363
]

def main (args : List String) : IO UInt32 := do
  let checks := shallow ++ (if args.contains "--deep" then deep else [])
  let mut failures := 0
  for c in checks do
    let t0 ← IO.monoMsNow
    let ok ← IO.lazyPure c.ok
    let t1 ← IO.monoMsNow
    IO.println s!"{if ok then "PASS" else "FAIL"}  {c.name}  ({t1 - t0} ms)"
    if !ok then failures := failures + 1
  IO.println s!"{checks.length - failures}/{checks.length} passed"
  return if failures == 0 then 0 else 1
