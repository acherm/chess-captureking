import Chess.Rules.Framework

/-!
# Standard Algebraic Notation (FIDE Appendix C)

SAN depends on the rules: disambiguation looks at the *legal* moves, and the suffix `+`/`#`
at the consequences of the move. Here `#` means that the move ends the game with a win for the
player who made it (checkmate in standard chess, capture of the king in natural chess) and `+`
that the opponent's king is attacked.
-/

namespace Chess

/-- SAN of the legal move `m` of `pos` under rule set `rs`. Disambiguation is with respect to
`among` (by default: the legal moves). -/
def san (rs : RuleSet) (pos : Position) (m : Move) (among : Option (List Move) := none) : String :=
  if m.isNull then "--" else
  let body := match pos.castlingSide? m, pos.board.get m.src with
    | some .kingside, _ => "O-O"
    | some .queenside, _ => "O-O-O"
    | none, some ⟨_, .pawn⟩ =>
      let capture := if pos.isCapture m then String.singleton (m.src.name.toList.headD 'a') ++ "x" else ""
      let promo := match m.promotion with
        | some k => "=" ++ String.singleton k.letter
        | none => ""
      capture ++ m.dst.name ++ promo
    | none, some p =>
      -- other moves of a piece of the same kind to the same square
      let rivals := (among.getD (rs.legalMoves pos)).filter fun m' =>
        m'.dst == m.dst && m'.src != m.src && pos.board.get m'.src == some p
      let disambiguation :=
        if rivals.isEmpty then ""
        else if rivals.all (·.src.file != m.src.file) then String.singleton (m.src.name.toList.headD 'a')
        else if rivals.all (·.src.rank != m.src.rank) then String.singleton (m.src.name.toList.getD 1 '1')
        else m.src.name
      String.singleton p.kind.letter ++ disambiguation ++ (if pos.isCapture m then "x" else "") ++
        m.dst.name
    | none, none => m.toUci
  let after := pos.play m
  let suffix :=
    match rs.outcome? (rs.situation after) with
    | some o => if o.result == Result.winner pos.turn then "#"
                else if after.isInCheck after.turn then "+" else ""
    | none => if after.isInCheck after.turn then "+" else ""
  body ++ suffix

/-- Drop annotations (`+ # ! ?`) and accept `0-0` for `O-O`. -/
private def normalizeSan (s : String) : String :=
  String.ofList ((s.replace "0-0-0" "O-O-O" |>.replace "0-0" "O-O").toList.filter
    fun c => !"+#!?".toList.contains c)

/-- The legal move of `pos` written `s` in SAN (annotations ignored), if any. -/
def parseSan (rs : RuleSet) (pos : Position) (s : String) : Option Move :=
  let target := normalizeSan s
  (rs.legalMoves pos).find? fun m => normalizeSan (san rs pos m) == target

/-- A legal move given either in UCI (`e2e4`) or in SAN (`e4`). -/
def parseMove (rs : RuleSet) (pos : Position) (s : String) : Option Move :=
  match Move.ofUci? s with
  | some m => if (rs.legalMoves pos).contains m then some m else parseSan rs pos s
  | none => parseSan rs pos s

/-- The *candidate* move (legal or not) written `s` in SAN or UCI, if any: used to explain why a
move is illegal. -/
def parseCandidate (rs : RuleSet) (pos : Position) (s : String) : Option Move :=
  let cands := rs.candidates pos
  match Move.ofUci? s with
  | some m => some m
  | none =>
    let target := normalizeSan s
    cands.find? fun m => normalizeSan (san rs pos m (among := some cands)) == target

end Chess
