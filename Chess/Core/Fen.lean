import Chess.Core.Position

/-!
# Forsyth–Edwards Notation

Reading and writing positions as FEN strings. The parser checks the *syntax* of a FEN only;
whether the position makes sense (one king per side, …) depends on the rules and is checked
by `RuleSet.validate`.
-/

namespace Chess

/-- Split on single spaces, dropping empty pieces. -/
def words (s : String) : List String := (s.splitOn " ").filter (· ≠ "")

private def parseBoard (s : String) : Except String Board := do
  let rows := s.splitOn "/"
  unless rows.length == 8 do throw s!"FEN board needs 8 ranks, got {rows.length}"
  let mut board := Board.empty
  -- FEN lists the ranks from the eighth down to the first
  for (row, i) in rows.zip (List.range 8) do
    let rank := 7 - i
    let mut file := 0
    for c in row.toList do
      if c.isDigit then
        file := file + (c.toNat - '0'.toNat)
      else
        let some p := Piece.ofChar? c | throw s!"FEN: unknown piece letter '{c}'"
        unless file < 8 do throw s!"FEN: rank {rank + 1} is too long"
        board := board.set (Square.ofFileRank file rank) (some p)
        file := file + 1
    unless file == 8 do throw s!"FEN: rank {rank + 1} has {file} squares instead of 8"
  return board

private def parseCastling (s : String) : Except String CastlingRights :=
  if s == "-" then return {} else
  s.toList.foldlM (init := {}) fun cr c =>
    match c with
    | 'K' => return { cr with whiteKingside := true }
    | 'Q' => return { cr with whiteQueenside := true }
    | 'k' => return { cr with blackKingside := true }
    | 'q' => return { cr with blackQueenside := true }
    | _ => throw s!"FEN: bad castling field '{s}'"

/-- Parse a FEN string. The two move counters may be omitted (as in EPD). -/
def Position.ofFen (s : String) : Except String Position := do
  let fields := words s
  let (boardF, turnF, castlingF, epF, half, full) ← match fields with
    | [b, t, c, e] => pure (b, t, c, e, "0", "1")
    | [b, t, c, e, h, f] => pure (b, t, c, e, h, f)
    | _ => throw s!"FEN needs 4 or 6 fields, got {fields.length}: '{s}'"
  let board ← parseBoard boardF
  let turn ← match turnF with
    | "w" => pure Color.white
    | "b" => pure Color.black
    | _ => throw s!"FEN: bad side to move '{turnF}'"
  let castling ← parseCastling castlingF
  let epTarget ← if epF == "-" then pure none else
    match Square.ofName? epF with
    | some sq => pure (some sq)
    | none => throw s!"FEN: bad en passant square '{epF}'"
  let some halfmoveClock := half.toNat? | throw s!"FEN: bad halfmove clock '{half}'"
  let some fullmoveNumber := full.toNat? | throw s!"FEN: bad fullmove number '{full}'"
  return { board, turn, castling, epTarget, halfmoveClock, fullmoveNumber }

/-- Parse a FEN that is known to be well-formed (panics otherwise). -/
def Position.ofFen! (s : String) : Position :=
  match Position.ofFen s with
  | .ok p => p
  | .error e => panic! e

def Board.toFen (b : Board) : String := Id.run do
  let mut out := ""
  for i in List.range 8 do
    let rank := 7 - i
    let mut empties := 0
    for file in List.range 8 do
      match b.get (Square.ofFileRank file rank) with
      | none => empties := empties + 1
      | some p =>
        if empties > 0 then out := out ++ toString empties
        empties := 0
        out := out.push p.toChar
    if empties > 0 then out := out ++ toString empties
    if rank > 0 then out := out.push '/'
  return out

def CastlingRights.toFen (cr : CastlingRights) : String :=
  let s := (if cr.whiteKingside then "K" else "") ++ (if cr.whiteQueenside then "Q" else "") ++
    (if cr.blackKingside then "k" else "") ++ (if cr.blackQueenside then "q" else "")
  if s.isEmpty then "-" else s

def Position.toFen (p : Position) : String :=
  let turn := match p.turn with
    | .white => "w"
    | .black => "b"
  let ep := match p.epTarget with
    | some s => s.name
    | none => "-"
  s!"{p.board.toFen} {turn} {p.castling.toFen} {ep} {p.halfmoveClock} {p.fullmoveNumber}"

instance : ToString Position := ⟨Position.toFen⟩

def startFen : String := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

/-- The initial position of a game (FIDE 2.3). -/
def Position.start : Position := Position.ofFen! startFen

/-- A picture of the board, for humans (White at the bottom). -/
def Board.toAscii (b : Board) : String := Id.run do
  let mut out := ""
  for i in List.range 8 do
    let rank := 7 - i
    out := out ++ toString (rank + 1) ++ " "
    for file in List.range 8 do
      let c := match b.get (Square.ofFileRank file rank) with
        | some p => p.toChar
        | none => '.'
      out := out.push c |>.push ' '
    out := out.push '\n'
  return out ++ "  a b c d e f g h\n"

end Chess
