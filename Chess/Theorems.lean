import Chess.Rules.Variants
import Chess.Perft
import Chess.Solver

/-!
# Theorems relating standard and natural chess

1. General facts, proved for *every* position (by reasoning about the rule sets):
   * natural chess legal moves are exactly the candidate ("pseudo-legal") moves, as long as both
     kings are on the board;
   * hence every standard legal move is a natural legal move.
2. Facts about particular positions, established by evaluation (`decide`/`native_decide`):
   standard and natural chess differ.
-/

namespace Chess

/-- Natural chess has a single legality rule: no move after a king has been captured. -/
theorem natural_legality : Natural.rules.legality = [Natural.noMoveAfterKingCapture] := by
  rfl

theorem natural_movement : Natural.rules.movement = Standard.rules.movement := rfl

theorem natural_fallback : Natural.rules.fallback = [] := rfl

theorem standard_fallback : Standard.rules.fallback = [] := rfl

/-- While both kings are on the board, the legal moves of natural chess are exactly the
candidate moves: the moves allowed by the movement rules of FIDE chess, ignoring check. -/
theorem natural_legalMoves (pos : Position) (h : Natural.bothKingsOnBoard pos = true) :
    Natural.rules.legalMoves pos = Natural.rules.candidates pos := by
  have tests : ((Natural.rules.legality.map fun r => r.permits pos).filter
      fun t => !t.permitsAll) = [] := by
    rw [natural_legality]
    simp [Natural.noMoveAfterKingCapture, h]
  unfold RuleSet.legalMoves
  dsimp only
  rw [tests]
  simp only [List.all_nil]
  split
  · next heq =>
    rw [natural_fallback]
    rw [List.filter_eq_self.mpr (by simp)] at heq
    simp [heq]
  · exact List.filter_eq_self.mpr (by simp)

/-- Standard legal moves are candidates (standard chess has no fallback moves). -/
theorem standard_legal_is_candidate (pos : Position) (m : Move)
    (hm : m ∈ Standard.rules.legalMoves pos) : m ∈ Standard.rules.candidates pos := by
  unfold RuleSet.legalMoves at hm
  dsimp only at hm
  split at hm
  · rw [standard_fallback] at hm
    simp at hm
  · exact (List.mem_filter.mp hm).1

/-- **Every legal move of standard chess is a legal move of natural chess** (in any position
where both kings are on the board). The converse fails: see below. -/
theorem standard_legal_subset_natural (pos : Position) (h : Natural.bothKingsOnBoard pos = true)
    (m : Move) (hm : m ∈ Standard.rules.legalMoves pos) : m ∈ Natural.rules.legalMoves pos := by
  rw [natural_legalMoves pos h]
  exact standard_legal_is_candidate pos m hm

/-! ## Particular positions

These statements are checked by evaluating the engines (`native_decide`, which trusts the Lean
compiler in addition to the kernel). Positions marked "Lichess" occurred in real games of
September 2026 (https://lichess.org/<id>), so they are legal (reachable) positions. -/

def uci! (s : String) : Move := (Move.ofUci? s).getD Move.null

/-- Perft agrees up to depth 3 from the initial position and differs at depth 4. -/
theorem perft_initial_3 : perft Standard.rules Position.start 3 = perft Natural.rules Position.start 3 := by
  native_decide

theorem perft_initial_4 :
    perft Standard.rules Position.start 4 = 197281 ∧ perft Natural.rules Position.start 4 = 197742 := by
  native_decide

/-- Lichess RSJfq4Su, after 9... Qe2#: White is checkmated, but in natural chess White castles
out of check, after which the white king is not attacked (it cannot be captured next move). -/
def lichessRSJfq4Su : Position :=
  Position.ofFen! "r1b1kb1r/ppp1pppp/5n2/4N3/3n1B2/N7/PPP1qPPP/R3K2R w KQkq - 0 10"

theorem castling_escape :
    Standard.rules.status lichessRSJfq4Su = .over ⟨.blackWins, "checkmate"⟩ ∧
    uci! "e1g1" ∈ Natural.rules.legalMoves lichessRSJfq4Su ∧
    (lichessRSJfq4Su.play (uci! "e1g1")).isInCheck .white = false ∧
    mustLose Natural.rules lichessRSJfq4Su 4 = false := by
  native_decide

/-- Lichess NZ2sKoBF, final position: a stalemate (draw) in standard chess, a loss in natural
chess (every move of the black king exposes it to capture). -/
def lichessNZ2sKoBF : Position := Position.ofFen! "7k/7P/7K/8/8/8/8/8 b - - 2 72"

theorem stalemate_loses :
    Standard.rules.status lichessNZ2sKoBF = .over ⟨.draw, "stalemate"⟩ ∧
    mustLose Natural.rules lichessNZ2sKoBF 2 = true := by
  native_decide

/-- Lichess t82cDrIb, before 19... Nd3+: Black mates in 2 (3 plies) in standard chess, but cannot
force the capture of the white king within 5 plies (the natural counterpart of a mate in 2) in
natural chess: after 19... Nd3+ White castles out of check. -/
def lichessT82cDrIb : Position :=
  Position.ofFen! "2k2r2/ppp3pp/5n2/4n1B1/3Np1b1/1P6/P1q2QPP/R3K2R b KQ - 1 19"

theorem mate_in_two_lost :
    canWin Standard.rules lichessT82cDrIb 3 = true ∧ canWin Natural.rules lichessT82cDrIb 5 = false := by
  native_decide

/-- Lichess NZ2sKoBF, before White's 72nd move: 72. Kh6, the stalemating move played in the game,
is the winning move of natural chess. (That the position is a standard draw comes from the KPK
tablebase, `chess endgame-value P standard …`.) -/
def lichessNZ2sKoBF72 : Position := Position.ofFen! "7k/7P/6K1/8/8/8/8/8 w - - 1 72"

theorem stalemating_move_wins :
    Standard.rules.status (lichessNZ2sKoBF72.play (uci! "g6h6")) = .over ⟨.draw, "stalemate"⟩ ∧
    canWin Natural.rules lichessNZ2sKoBF72 3 = true := by
  native_decide

/-- Lichess A8iBWO7I, final position: a dead position (draw, game over) in standard chess, a win
for Black in natural chess (108... Kf2, after which every white move exposes the king). -/
def lichessA8iBWO7I : Position := Position.ofFen! "8/8/8/8/8/8/8/4k1bK b - - 0 108"

theorem dead_position_wins :
    Standard.rules.status lichessA8iBWO7I = .over ⟨.draw, "deadPosition"⟩ ∧
    canWin Natural.rules lichessA8iBWO7I 3 = true := by
  native_decide

/-- King and bishop against king: a dead position (draw) in standard chess, but White wins in
natural chess by 1. Kc2, after which every move of the black king exposes it to capture (in
standard chess, 1. Kc2 is stalemate). -/
def bishopCorner : Position := Position.ofFen! "8/8/8/8/8/8/8/kBK5 w - - 0 1"

theorem bishop_wins :
    Standard.rules.status bishopCorner = .over ⟨.draw, "deadPosition"⟩ ∧
    canWin Natural.rules bishopCorner 3 = true ∧
    Standard.rules.status (bishopCorner.play (uci! "c1c2")) = .over ⟨.draw, "stalemate"⟩ := by
  native_decide

/-- **Opposite outcomes** (Hamkins' third kind): White is checkmated in standard chess (Black
wins), but in natural chess White castles out of check, 1. O-O-O+, and wins by force within 5
plies (e.g. 1... Qxd1+ 2. Kxd1 and every move of the black king exposes it). -/
def oppositeOutcome : Position := Position.ofFen! "8/8/8/8/1Q6/3k4/4qP2/R3K3 w Q - 0 1"

theorem opposite_outcome :
    Standard.rules.status oppositeOutcome = .over ⟨.blackWins, "checkmate"⟩ ∧
    canWin Natural.rules oppositeOutcome 5 = true := by
  native_decide

/-- The 75-move rule (FIDE 9.6.2) gives precedence to a checkmate delivered on the last move, but
natural chess needs two more plies to capture the king. Here (148 half-moves without capture or
pawn move) 1. Rc8 mates in standard chess, while in natural chess 1. Rc8 Kb7 reaches 150
half-moves first: a draw. Forty half-moves earlier, natural chess wins as expected. -/
def lateMate (clock : Nat) : Position :=
  { Position.ofFen! "k7/8/1K6/8/8/8/8/2R5 w - - 0 120" with halfmoveClock := clock }

theorem seventy_five_moves :
    canWin Standard.rules (lateMate 148) 1 = true ∧
    canWin Natural.rules (lateMate 148) 5 = false ∧
    canWin Natural.rules (lateMate 140) 3 = true := by
  native_decide

/-- A checkmate in standard chess where the checkmated player has no move at all, not even one
exposing the king: in natural chess the king can never be captured and the game is drawn —
unless the rules let a player without moves pass (`Variants.naturalPass`). -/
def noMoveMate : Position := Position.ofFen! "KN1q4/PPpPk3/PnP5/8/8/8/8/8 w - - 0 1"

theorem no_move_checkmate :
    Standard.rules.status noMoveMate = .over ⟨.blackWins, "checkmate"⟩ ∧
    Natural.rules.status noMoveMate = .over ⟨.draw, "noLegalMove"⟩ ∧
    mustLose Variants.naturalPass noMoveMate 2 = true := by
  native_decide

end Chess
