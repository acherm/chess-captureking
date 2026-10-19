import Chess.Theorems
import Chess.Analysis.Grid

/-!
# Theorems about Hamkins' grid of variants

Witness positions separating the eight games of the grid (GRID_VARIANTS.md), checked by
evaluation (`native_decide`). Values are stated with the tools that establish them:

* `status` for games already over;
* `canWin` / `mustLose` for wins and losses within a number of plies (exact facts: a forced win
  within `d` plies is a forced win);
* `Grid.exactValue` for draws: retrograde analysis of every position reachable from the
  position (move counters ignored, a game that goes on forever is drawn).
-/

namespace Chess

open Variants

/-- Hamkins' lose-your-turn position, Black to move: a stalemate in standard chess, and a
position where Black cannot move at all in natural chess (no move exposes the king either).
It separates the conventions: normal play loses it for Black, passing draws it, and losing the
turn wins it for Black (1... pass 2. cxb7+, forced, Qxb7, after which the white king is lost). -/
def hamkinsLoseTurn : Position := Position.ofFen! "kqn5/prp1p3/KpPpP3/1P1P4/8/8/8/8 b - - 0 1"

theorem hamkins_lose_turn :
    Standard.rules.status hamkinsLoseTurn = .over ⟨.draw, "stalemate"⟩ ∧
    standardNormal.status hamkinsLoseTurn = .over ⟨.whiteWins, "noLegalMoveLoses"⟩ ∧
    (Grid.exactValue standardPassing hamkinsLoseTurn).1 = .draw ∧
    canWin standardLoseTurn hamkinsLoseTurn 3 = true ∧
    Natural.rules.status hamkinsLoseTurn = .over ⟨.draw, "noLegalMove"⟩ ∧
    naturalNormal.status hamkinsLoseTurn = .over ⟨.whiteWins, "noLegalMoveLoses"⟩ ∧
    (Grid.exactValue naturalPassing hamkinsLoseTurn).1 = .draw ∧
    canWin naturalLoseTurn hamkinsLoseTurn 5 = true := by
  native_decide

/-- Hamkins' double stalemate, Black to move: neither player has a legal move in standard
chess. With passing (at any time, or when stalemated) both players pass forever: a draw. In
natural chess Black must expose his king, whatever the convention, unless he may pass at will. -/
def hamkinsDoubleStalemate : Position := Position.ofFen! "k7/P1p5/KpP5/1P6/8/8/8/8 b - - 0 1"

theorem hamkins_double_stalemate :
    Standard.rules.status hamkinsDoubleStalemate = .over ⟨.draw, "stalemate"⟩ ∧
    standardNormal.status hamkinsDoubleStalemate = .over ⟨.whiteWins, "noLegalMoveLoses"⟩ ∧
    (Grid.exactValue standardPassing hamkinsDoubleStalemate).1 = .draw ∧
    (Grid.exactValue standardLoseTurn hamkinsDoubleStalemate).1 = .draw ∧
    mustLose Natural.rules hamkinsDoubleStalemate 2 = true ∧
    mustLose naturalNormal hamkinsDoubleStalemate 2 = true ∧
    (Grid.exactValue naturalPassing hamkinsDoubleStalemate).1 = .draw ∧
    mustLose naturalLoseTurn hamkinsDoubleStalemate 2 = true := by
  native_decide

/-- Hamkins' K+R v K position, White to move: 1. Ke1 Rc1# in standard chess (a zugzwang), but
with passing White never has to step into the mating net: a draw, in standard and natural
chess alike. The losses are proved here; the draws need the whole K+R v K game graph, too large
for `native_decide` (which interprets the code), and are checked by the compiled test suite
(`tests --deep`) and by `chess exact standard-passing "8/8/8/8/2r5/4k3/8/3K4 w - - 0 1"`. -/
def hamkinsRookPassing : Position := Position.ofFen! "8/8/8/8/2r5/4k3/8/3K4 w - - 0 1"

theorem hamkins_rook_zugzwang :
    mustLose Standard.rules hamkinsRookPassing 2 = true ∧
    mustLose Natural.rules hamkinsRookPassing 4 = true ∧
    mustLose standardLoseTurn hamkinsRookPassing 2 = true ∧
    mustLose standardPassing hamkinsRookPassing 2 = false ∧
    mustLose naturalPassing hamkinsRookPassing 4 = false := by
  native_decide

/-- Hamkins' castling position (`hamkinsCastling`, Black has just played 1... Qd2#) separates
every standard game of the grid from every natural one: White is checkmated under the four
standard conventions, and wins by castling out of and through check under the four natural
ones. -/
theorem hamkins_castling_grid :
    Standard.rules.status hamkinsCastling = .over ⟨.blackWins, "checkmate"⟩ ∧
    standardNormal.status hamkinsCastling = .over ⟨.blackWins, "noLegalMoveLoses"⟩ ∧
    standardPassing.status hamkinsCastling = .over ⟨.blackWins, "checkmate"⟩ ∧
    standardLoseTurn.status hamkinsCastling = .over ⟨.blackWins, "checkmate"⟩ ∧
    canWin Natural.rules hamkinsCastling 7 = true ∧
    canWin naturalNormal hamkinsCastling 7 = true ∧
    canWin naturalPassing hamkinsCastling 7 = true ∧
    canWin naturalLoseTurn hamkinsCastling 7 = true := by
  native_decide

/-- Hamkins' first position after 1... Nc7#: White has no move at all. Natural chess draws
it; normal play loses it for White, and so does any passing rule (after the pass, Black takes
the king). -/
theorem hamkins_no_move_grid :
    Natural.rules.status (hamkinsNoMoveMate.play (uci! "e8c7")) = .over ⟨.draw, "noLegalMove"⟩ ∧
    naturalNormal.status (hamkinsNoMoveMate.play (uci! "e8c7")) = .over ⟨.blackWins, "noLegalMoveLoses"⟩ ∧
    mustLose naturalPassing (hamkinsNoMoveMate.play (uci! "e8c7")) 2 = true ∧
    mustLose naturalLoseTurn (hamkinsNoMoveMate.play (uci! "e8c7")) 2 = true := by
  native_decide

end Chess
