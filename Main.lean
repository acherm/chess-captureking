import Chess

/-!
# Command-line interface

    chess rules [RULES]                      describe a rule set (default: standard)
    chess variants                           list the available rule sets
    chess diff RULES_A RULES_B               rules removed/added from A to B
    chess show RULES [FEN]                   board, legal moves and status of a position
    chess play RULES [--fen FEN] MOVE...     play moves (SAN or UCI), report status or why illegal
    chess perft RULES DEPTH [FEN]            perft (parallel)
    chess stats RULES DEPTH [FEN]            perft with detailed counters, depths 0..DEPTH
    chess divide RULES DEPTH [FEN]           perft of each legal move
    chess solve RULES PLIES [FEN]            bounded game-theoretic search
    chess legal-batch RULES                  FENs on stdin -> legal moves and status (TSV)
    chess compare RULES_A RULES_B [HORIZON]  FENs on stdin -> comparison (TSV)
    chess divergences A B PLIES EXAMPLES PERFT_DEPTH [FEN]
                                             positions within PLIES plies where A and B disagree
                                             (PERFT_DEPTH 0: skip the perft decomposition)
    chess hunt ...                           search for positions where rule sets differ
    chess endgame MATERIAL A B EXAMPLES      tablebases of K+MATERIAL v K under A and B, compared
    chess endgame-value MATERIAL RULES FEN   exact value of one position
    chess exact RULES FEN                    exact value of a position (retrograde analysis of
                                             every position reachable from it)
    chess grid-endgame MATERIAL              tablebases of K+MATERIAL v K under the 8 games of
                                             Hamkins' grid (and the bridges), compared pairwise
    chess line MATERIAL RULES FEN            a line of best play, from the tablebase of K+MATERIAL v K
    chess explain MATERIAL RULES FEN         the same line, with the value of every alternative
    chess longest-wins MATERIAL RULES N      the N positions of K+MATERIAL v K with the longest wins
    chess grid-verdicts HORIZON              FENs on stdin -> bounded verdicts under the grid
                                             games and the bridges (TSV)
    chess miniature EXTRAS                   every standard checkmate with K+R(s) at home, the
                                             black king and up to EXTRAS more pieces, where the
                                             mated side can castle to safety (FENs)
-/

open Chess

def getRules (name : String) : IO RuleSet :=
  match Variants.byName? name with
  | some rs => pure rs
  | none => throw <| IO.userError s!"unknown rule set '{name}'; try: {Variants.all.map (·.name)}"

def getPosition (args : List String) : IO Position :=
  let fen := if args.isEmpty then startFen else String.intercalate " " args
  match Position.ofFen fen with
  | .ok p => pure p
  | .error e => throw <| IO.userError e

def getNat (s : String) : IO Nat :=
  match s.toNat? with
  | some n => pure n
  | none => throw <| IO.userError s!"expected a number, got '{s}'"

def timed {α} (f : Unit → α) : IO (α × Nat) := do
  let t0 ← IO.monoMsNow
  let x ← IO.lazyPure f
  let t1 ← IO.monoMsNow
  return (x, t1 - t0)

def readLines : IO (Array String) := do
  let stdin ← IO.getStdin
  let mut lines := #[]
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break
    let l := line.trimAscii.toString
    if !l.isEmpty then lines := lines.push l
  return lines

/-- Map `f` over `xs` with one task per chunk, keeping the order. -/
def parallelMap {α β} (f : α → β) (xs : Array α) (chunk : Nat := 64) : Array β := Id.run do
  let mut tasks := #[]
  let mut i := 0
  while i < xs.size do
    let part := xs.extract i (i + chunk)
    tasks := tasks.push (Task.spawn fun _ => part.map f)
    i := i + chunk
  return tasks.foldl (fun acc t => acc ++ t.get) #[]

def showPosition (rs : RuleSet) (pos : Position) : String :=
  let moves := rs.legalMoves pos
  let sans := moves.map (san rs pos)
  pos.board.toAscii ++ s!"FEN: {pos.toFen}\nRules: {rs.name}\n" ++
    s!"{pos.turn} to move{if pos.isInCheck pos.turn then " (in check)" else ""}\n" ++
    s!"{moves.length} legal moves: {String.intercalate " " sans}\n" ++
    s!"Status: {rs.status pos}\n"

def statsRow (d : Nat) (s : PerftStats) : String :=
  s!"{d}\t{s.nodes}\t{s.captures}\t{s.enPassants}\t{s.castles}\t{s.promotions}\t{s.checks}\t" ++
    s!"{s.discoveredChecks}\t{s.doubleChecks}\t{s.mates}\t{s.kingCaptures}"

def run : List String → IO Unit
  | ["rules"] => IO.print Standard.rules.describe
  | ["rules", name] => do IO.print (← getRules name).describe
  | ["variants"] => for rs in Variants.all do IO.println rs.name
  | ["diff", a, b] => do
    let (ra, rb) := (← getRules a, ← getRules b)
    IO.println s!"From '{ra.name}' to '{rb.name}':"
    for line in ra.diff rb do IO.println line
  | "show" :: name :: fen => do
    IO.print (showPosition (← getRules name) (← getPosition fen))
  | "play" :: name :: rest => do
    let rs ← getRules name
    let (pos, moves) ← match rest with
      | "--fen" :: f1 :: f2 :: f3 :: f4 :: f5 :: f6 :: ms => do
        pure (← getPosition [f1, f2, f3, f4, f5, f6], ms)
      | ms => pure (Position.start, ms)
    match (Game.new rs pos).playAll moves with
    | .ok g =>
      IO.println g.movetext
      IO.print (showPosition rs g.current)
      IO.println s!"Game status (with history): {g.status}"
    | .error e => IO.println s!"Illegal: {e}"
  | "perft" :: name :: depth :: fen => do
    let (rs, d, pos) := (← getRules name, ← getNat depth, ← getPosition fen)
    let (n, ms) ← timed fun _ => perftParallel rs pos d
    IO.println s!"{n}\t({ms} ms)"
  | "stats" :: name :: depth :: fen => do
    let (rs, d, pos) := (← getRules name, ← getNat depth, ← getPosition fen)
    IO.println "depth\tnodes\tcaptures\tep\tcastles\tpromotions\tchecks\tdiscovered\tdouble\tmates\tking_captures"
    for i in List.range (d + 1) do
      let (s, _) ← timed fun _ => perftStatsParallel rs pos i
      IO.println (statsRow i s)
  | "divide" :: name :: depth :: fen => do
    let (rs, d, pos) := (← getRules name, ← getNat depth, ← getPosition fen)
    let rows := divide rs pos d
    for (m, n) in rows do IO.println s!"{m.toUci}\t{san rs pos m}\t{n}"
    IO.println s!"total\t{rows.foldl (· + ·.2) 0}"
  | "solve" :: name :: plies :: fen => do
    let (rs, d, pos) := (← getRules name, ← getNat plies, ← getPosition fen)
    let (v, ms) ← timed fun _ => solve rs pos d
    IO.println s!"{v}\t({ms} ms)"
  | ["solve-batch", name, plies] => do
    -- FENs on stdin; for each, the verdict of a search of PLIES plies, for the position and for
    -- each legal move (verdict of the opponent after the move)
    let (rs, d) := (← getRules name, ← getNat plies)
    let lines ← readLines
    let rows := parallelMap (fun (fen : String) =>
      match Position.ofFen fen with
      | .error e => s!"{fen}\tERROR {e}"
      | .ok pos => s!"{fen}\t{solve rs pos d}") lines (chunk := 1)
    for r in rows do IO.println r
  | ["legal-batch", name] => do
    let rs ← getRules name
    let lines ← readLines
    let rows := parallelMap (fun (fen : String) =>
      match Position.ofFen fen with
      | .error e => s!"{fen}\tERROR {e}"
      | .ok pos =>
        let moves := (rs.legalMoves pos).map Move.toUci |>.mergeSort
        let status := match rs.status pos with
          | .over o => s!"{o.result} {o.rule}"
          | .ongoing _ => "ongoing"
        s!"{fen}\t{String.intercalate " " moves}\t{status}\t{pos.isInCheck pos.turn}\t" ++
          String.intercalate " " ((rs.legalMoves pos).map (san rs pos) |>.mergeSort)) lines
    for r in rows do IO.println r
  | ["games-batch", name] => do
    -- each line: an id, a tab, and the moves of a game from the initial position (UCI or SAN)
    let rs ← getRules name
    let lines ← readLines
    let rows := parallelMap (fun (line : String) =>
      let (id, moves) := match line.splitOn "\t" with
        | id :: rest => (id, words (String.intercalate " " rest))
        | [] => ("", [])
      match (Game.new rs).playAll moves with
      | .ok g =>
        let status := match g.status with
          | .over o => s!"{o.result} {o.rule}"
          | .ongoing [] => "ongoing"
          | .ongoing cs => s!"ongoing claimable:{String.intercalate "," (cs.map Outcome.rule)}"
        s!"{id}\tok\t{status}\t{g.current.toFen}"
      | .error e => s!"{id}\tillegal\t{e}") lines (chunk := 16)
    for r in rows do IO.println r
  | "compare" :: a :: b :: rest => do
    let (ra, rb) := (← getRules a, ← getRules b)
    let horizon ← match rest with
      | [h] => some <$> getNat h
      | _ => pure none
    let lines ← readLines
    IO.println Comparison.tsvHeader
    let rows := parallelMap (fun (fen : String) =>
      match Position.ofFen fen with
      | .error e => s!"{fen}\tERROR {e}"
      | .ok pos => (compare ra rb pos horizon).toTsv) lines (chunk := 8)
    for r in rows do IO.println r
  | "divergences" :: a :: b :: plies :: examples :: perftDepth :: fen => do
    let (ra, rb) := (← getRules a, ← getRules b)
    let (k, e, d) := (← getNat plies, ← getNat examples, ← getNat perftDepth)
    IO.print (divergenceReport ra rb (← getPosition fen) k e (if d == 0 then none else some d))
  | ["random", kind, count, seed, size] => do
    let (n, sd, k) := (← getNat count, ← getNat seed, ← getNat size)
    let mut g : Rng := ⟨sd.toUInt64⟩
    let mut produced := 0
    while produced < n do
      match kind with
      | "placement" =>
        let (p?, g') := randomPlacement g k
        g := g'
        if let some p := p? then
          IO.println p.toFen
          produced := produced + 1
      | "playout" =>
        let (plies, g1) := g.below (k + 1)
        let (p, g') := randomPlayout g1 plies
        g := g'
        IO.println p.toFen
        produced := produced + 1
      | _ => throw <| IO.userError "random placement|playout COUNT SEED SIZE"
  | ["hunt", kind, generator, size, attempts, wanted, seed] => do
    let some pred := Hunt.byName? kind | throw <| IO.userError s!"unknown hunt '{kind}'"
    let (k, a, w, sd) := (← getNat size, ← getNat attempts, ← getNat wanted, ← getNat seed)
    let gen : Rng → Option Position × Rng := match generator with
      | "castling" => (Hunt.castlingSetup · k)
      | "sparse" => (Hunt.sparseSetup · k 3)
      | _ => (randomPlacement · k)
    let workers := 16
    let tasks := (List.range workers).map fun i =>
      Task.spawn fun _ => Hunt.run gen pred (sd * 1000 + i) (a / workers) w
    let results := tasks.map Task.get
    let found := results.flatMap (·.1)
    let valid := results.foldl (· + ·.2) 0
    for (p, why) in found do IO.println s!"{p.toFen}\t{why}"
    IO.eprintln s!"{a} attempts, {valid} valid positions, {found.length} found"
  | ["endgame", material, nameA, nameB, examples] => do
    -- material: the pieces besides the kings, upper case for White (e.g. "P", "B", "Rp")
    let (ra, rb, e) := (← getRules nameA, ← getRules nameB, ← getNat examples)
    let extra := material.toList.filterMap Piece.ofChar?
    let start := (allPlacements extra).filter Standard.rules.isValid
    let (tbA, msA) ← timed fun _ => solveEndgame ra start
    let (tbB, msB) ← timed fun _ => solveEndgame rb start
    IO.println s!"K{material}K: {start.size} standard-valid positions; graph sizes {tbA.positions.size} ({ra.name}, {msA} ms), {tbB.positions.size} ({rb.name}, {msB} ms)"
    let pairs := start.filterMap fun p => do
      let a ← tbA.value? p ra
      let b ← tbB.value? p rb
      return (p, a, b)
    let label (v : Value) := match v with
      | .win _ => "win"
      | .loss _ => "loss"
      | .draw => "draw"
    let cats := ["win", "draw", "loss"]
    IO.println s!"rows: {ra.name}, columns: {rb.name} (value for the player to move)"
    IO.println s!"\t{String.intercalate "\t" cats}"
    for ca in cats do
      let row := cats.map fun cb => toString (pairs.filter fun (_, a, b) => label a == ca && label b == cb).size
      IO.println s!"{ca}\t{String.intercalate "\t" row}"
    -- distance to win: natural minus standard, when both win
    let deltas := pairs.filterMap fun (_, a, b) => match a, b with
      | .win x, .win y => some ((y : Int) - x)
      | .loss x, .loss y => some ((y : Int) - x)
      | _, _ => none
    let distinct := deltas.foldl (fun acc d => if acc.contains d then acc else acc.push d) #[]
    IO.println s!"distance in plies ({rb.name} - {ra.name}) when both decisive with the same sign:"
    for d in distinct.qsort (· < ·) do
      IO.println s!"  {d}: {(deltas.filter (· == d)).size}"
    for ca in cats do
      for cb in cats do
        if ca != cb then
          let xs := pairs.filter fun (_, a, b) => label a == ca && label b == cb
          for (p, a, b) in xs.toList.take e do
            IO.println s!"  {ca}->{cb}: {p.toFen}  {ra.name} {a}, {rb.name} {b}"
  | "endgame-value" :: material :: name :: fen => do
    -- the exact value of one position, from the tablebase of its material under a rule set
    let (rs, pos) := (← getRules name, ← getPosition fen)
    let extra := material.toList.filterMap Piece.ofChar?
    let tb := solveEndgame rs ((allPlacements extra).filter Standard.rules.isValid)
    match tb.value? pos rs with
    | some v => IO.println s!"{rs.name}: {v} (for {pos.turn})"
    | none => IO.println "position not in the tablebase (wrong material?)"
  | "exact" :: name :: fen => do
    let (rs, pos) := (← getRules name, ← getPosition fen)
    let ((v, n), ms) ← timed fun _ => Grid.exactValue rs pos
    IO.println s!"{rs.name}: {v} (for {pos.turn}; {n} positions, {ms} ms)"
  | ["grid-endgame", material] => do
    let extra := material.toList.filterMap Piece.ofChar?
    let start := (allPlacements extra).filter Standard.rules.isValid
    let sets := Variants.grid ++ Variants.gridBridges.map (·.1)
    IO.println s!"K{material}K: {start.size} standard-valid positions (value for the player to move)"
    IO.println "rule set\twin\tdraw\tloss\tlongest win (plies)\tgraph size\tms"
    let mut values : Array (Array Value) := #[]
    for rs in sets do
      let ((vs, n), ms) ← timed fun _ => Grid.startValues rs start
      let (w, d, l) := Grid.counts vs
      let longest := vs.foldl (fun m v => if v.sign == 1 then max m v.plies else m) 0
      IO.println s!"{rs.name}\t{w}\t{d}\t{l}\t{longest}\t{n}\t{ms}"
      values := values.push vs
    -- the standard stalemates (player to move stalemated), valued by each game
    let stalemates := (List.range start.size).filter fun k =>
      Standard.rules.status start[k]! == .over ⟨.draw, "stalemate"⟩
    IO.println s!"\n{stalemates.length} standard stalemates, valued for the stalemated player (win/draw/loss)"
    for (rs, vs) in sets.zip values.toList do
      let (w, d, l) := Grid.counts (stalemates.map (vs[·]!)).toArray
      IO.println s!"{rs.name}\t{w}\t{d}\t{l}"
    let names := sets.map (·.name) |>.toArray
    let g := Variants.grid.length
    IO.println "\npairwise disagreements (positions where the values differ)"
    for r in Grid.comparePairs start (values.extract 0 g) do
      IO.println s!"{names[r.a]!}\t{names[r.b]!}\t{r.disagreements}"
    IO.println "\nwitnesses"
    for r in Grid.comparePairs start (values.extract 0 g) do
      if let some (p, a, b) := r.witness then
        IO.println s!"{names[r.a]!}\t{names[r.b]!}\t{p.toFen}\t{a}\t{b}"
    IO.println "\nbridges (naturalized standard game vs natural game of the same convention)"
    for ((s, n), i) in Variants.gridBridges.zipIdx do
      let some ni := Variants.grid.findIdx? (·.name == n.name) | continue
      let (dis, deltas) := Grid.compareBridge values[g + i]! values[ni]!
      IO.println s!"{s.name}\t{n.name}\tdisagreements {dis}\tdistance (natural - naturalized): {deltas}"
  | "line" :: material :: name :: fen => do
    -- a line of best play from the tablebase of K+MATERIAL v K: the winner plays a fastest win,
    -- the loser a longest defence
    let (rs, pos) := (← getRules name, ← getPosition fen)
    let extra := material.toList.filterMap Piece.ofChar?
    let tb := solveEndgame rs ((allPlacements extra).filter Standard.rules.isValid)
    let mut p := pos
    let mut sans := #[]
    let start := tb.value? pos rs
    for _ in List.range 80 do
      let some v := tb.value? p rs | break
      let target : Option Value := match v with
        | .win (d + 1) => some (.loss d)
        | .loss (d + 1) => some (.win d)
        | _ => none
      let some t := target | break
      let some m := (rs.legalMoves p).find? fun m => tb.value? (p.play m) rs == some t | break
      sans := sans.push (san rs p m)
      p := p.play m
    IO.println s!"{rs.name}: {start.map toString |>.getD "?"} for {pos.turn}: {String.intercalate " " sans.toList}"
    IO.println s!"final position: {p.toFen}  ({rs.status p})"
  | "explain" :: material :: name :: fen => do
    -- the line of `line`, with the alternatives: for the winner, every move that wins as fast;
    -- for the loser, what each move (or pass) leads to, from his point of view
    let (rs, pos) := (← getRules name, ← getPosition fen)
    let extra := material.toList.filterMap Piece.ofChar?
    let tb := solveEndgame rs ((allPlacements extra).filter Standard.rules.isValid)
    let forMover : Value → String
      | .win k => s!"loses in {k + 1}"
      | .loss k => s!"wins in {k + 1}"
      | .draw => "draws"
    let mut p := pos
    for _ in List.range 80 do
      let some v := tb.value? p rs | break
      let target : Option Value := match v with
        | .win (d + 1) => some (.loss d)
        | .loss (d + 1) => some (.win d)
        | _ => none
      let some t := target | break
      let options := (rs.legalMoves p).filterMap fun m => (tb.value? (p.play m) rs).map (m, ·)
      let some (m, _) := options.find? (·.2 == t) | break
      let label := s!"{p.fullmoveNumber}{if p.turn == .white then "." else "..."} {san rs p m}"
      if v.sign == 1 then
        let also := (options.filter fun (m', w) => w == t && m' != m).map (san rs p ·.1)
        IO.println s!"{label}  ({v}; as fast: {if also.isEmpty then "none" else String.intercalate " " also})"
      else
        let opts := options.map fun (m', w) => s!"{san rs p m'} {forMover w}"
        IO.println s!"{label}  ({v}; plies after each option: {String.intercalate ", " opts})"
      p := p.play m
    IO.println s!"final position: {p.toFen}  ({rs.status p})"
  | ["longest-wins", material, name, count] => do
    -- the positions of K+MATERIAL v K with the longest forced wins under a rule set
    let (rs, k) := (← getRules name, ← getNat count)
    let extra := material.toList.filterMap Piece.ofChar?
    let start := (allPlacements extra).filter Standard.rules.isValid
    let (vs, _) := Grid.startValues rs start
    let wins := (start.zip vs).filter (·.2.sign == 1)
    for (p, v) in (wins.qsort fun a b => a.2.plies > b.2.plies).toList.take k do
      IO.println s!"{p.toFen}\t{v}"
  | ["grid-verdicts", horizon] => do
    let h ← getNat horizon
    let sets := Variants.grid ++ Variants.gridBridges.map (·.1)
    let lines ← readLines
    IO.println ("fen\t" ++ String.intercalate "\t" (sets.map (·.name)))
    let rows := parallelMap (fun (fen : String) =>
      match Position.ofFen fen with
      | .error e => s!"{fen}\tERROR {e}"
      | .ok pos => String.intercalate "\t" (fen :: Grid.gridVerdicts sets pos h)) lines (chunk := 4)
    for r in rows do IO.println r
  | ["miniature", extras] => do
    let k ← getNat extras
    let jobs := Hunt.castlingConfigs.flatMap fun sides => Square.all.map fun bk => (sides, bk)
    let tasks := jobs.map fun (sides, bk) => Task.spawn fun _ => Hunt.castlingEscapes sides bk k
    let results := tasks.map Task.get
    for (found, _, _) in results do
      for p in found do IO.println p.toFen
    let total := results.foldl (fun (v, m, f) (found, v', m') => (v + v', m + m', f + found.size)) (0, 0, 0)
    IO.eprintln s!"{total.1} valid positions, {total.2.1} checkmates, {total.2.2} with a safe castling"
  | _ => IO.println "usage: see the header of Main.lean (chess rules | variants | diff | show | play | perft | stats | divide | solve | legal-batch | compare)"

def main (args : List String) : IO Unit := run args
