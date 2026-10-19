import Chess.GridTheorems
import Chess.Game

/-!
# Proof games: the constructed positions are legal positions

FIDE 3.10.3: "A position is illegal when it cannot have been reached by any series of legal
moves." The positions found by search, built by hand, or transcribed from Hamkins' diagrams are
reached here by a game from the initial position (`data/proofgames/`, found with python-chess;
`scripts/proofgame_check.py` checks them there). Each theorem replays the game with the
standard engine: every move must be legal, the game must not be over before the last move
(checkmate, stalemate, dead position, 75 moves, fivefold repetition), and the final position must
be the target (placement, side to move, castling rights, en passant possibility; and the move
counters for the 75-move position).
-/

namespace Chess

/-- The game `moves` (UCI, from the initial position) is a game of standard chess that reaches
`target`. -/
def reaches (moves : String) (target : Position) (counters : Bool := false) : Bool :=
  match (Game.new Standard.rules).playAll (moves.splitOn " ") with
  | .error _ => false
  | .ok g =>
    let p := g.current
    let ep := Standard.effectiveEpTarget Standard.rules.legalMoves
    p.board == target.board && p.turn == target.turn && p.castling == target.castling &&
      ep p == ep target &&
      (!counters || (p.halfmoveClock == target.halfmoveClock &&
                     p.fullmoveNumber == target.fullmoveNumber))

/-- `opposite-outcome`: 8/8/8/8/1Q6/3k4/4qP2/R3K3 w Q - 0 1, reached in 46 plies. -/
theorem proofGame_opposite_outcome :
    reaches
    ("g1h3 g7g5 h3g5 f8h6 g5f7 e8f7 b1a3 d8e8 a3b5 f7g6 b5a7 h6d2 d1d2 g6f5 d2b4 g8h6 c1h6 " ++
    "a8a7 b4b7 a7a2 b7b8 f5e4 b8c7 c8a6 c7d7 a6e2 d7e7 e4d4 f1e2 a2b2 e7h7 b2c2 h7e7 h8h6 " ++
    "e2d3 h6h2 h1h2 d4d3 h2h5 e8h5 g2g4 c2c5 e7c5 h5g4 c5b4 g4e2")
    (oppositeOutcome) = true := by
  native_decide

/-- `castle-escape-small`: 8/8/8/8/4k3/8/1r6/1q2K2R w K - 0 1, reached in 46 plies. -/
theorem proofGame_castle_escape_small :
    reaches
    ("g1h3 g7g5 h3g5 f8h6 g5f7 e8f7 b1a3 h6d2 c1d2 f7g6 d2g5 g6f5 d1d7 f5e4 d7c8 d8d3 g5e7 " ++
    "d3c2 c8b8 c2b2 b8a8 b2a2 a8a7 g8e7 e2e3 h8b8 a7b7 e7d5 b7c7 d5e3 f2e3 b8b2 f1d3 e4d3 " ++
    "c7h7 d3e3 h7e4 e3e4 a1b1 b2g2 b1b3 g2h2 b3b2 h2b2 a3b1 a2b1")
    (Position.ofFen! "8/8/8/8/4k3/8/1r6/1q2K2R w K - 0 1") = true := by
  native_decide

/-- `castle-attack`: 1B2k2r/2N3r1/4r3/8/8/8/8/5K2 b k - 0 1, reached in 45 plies. -/
theorem proofGame_castle_attack :
    reaches
    ("b1c3 g7g5 c3d5 g5g4 d5e7 g4g3 e7d5 g3h2 g2g4 h2g1r h1h7 g1g2 h7f7 g8h6 f7d7 h6g4 " ++
    "d7c7 g4f2 c7c8 f2d1 c8b8 d1b2 c1b2 f8g7 b2e5 d8b8 e5b8 g7a1 c2c3 a1c3 b8a7 g2g7 a7b8 " ++
    "a8a2 f1g2 a2d2 e1f1 d2e2 d5c3 e2e6 g2b7 g7b7 c3d5 b7g7 d5c7")
    (Position.ofFen! "1B2k2r/2N3r1/4r3/8/8/8/8/5K2 b k - 0 1") = true := by
  native_decide

/-- `no-move-mate`: KN1q4/PPpPk3/PnP5/8/8/8/8/8 w - - 0 1, reached in 98 plies. -/
theorem proofGame_no_move_mate :
    reaches
    ("g1f3 g8f6 f3e5 b8c6 e5c6 g7g5 b2b3 f8h6 f2f4 g5f4 e1f2 f4f3 f2f3 b7b5 b1a3 c8a6 a3b5 " ++
    "a6b5 c6b8 b5d3 e2d3 h6f4 c1a3 f4h2 a3e7 d8e7 g2g3 h2g3 h1h7 h8f8 h7f7 e7f7 d1e1 g3e1 " ++
    "f3e3 f7h7 e3d4 a7a5 d4c5 a5a4 b3a4 d7d6 c5c6 f8g8 c6b7 g8g1 b7a8 g1f1 a1b1 e1g3 b1b6 " ++
    "f1b1 b6d6 b1b3 c2b3 g3e5 d6d7 e5c3 d2c3 h7h8 d7h7 h8h7 a4a5 f6g4 a5a6 g4f6 a6a7 f6g4 " ++
    "b3b4 g4f6 b4b5 f6g4 b5b6 g4f6 b6b7 f6g4 c3c4 g4f6 c4c5 f6g4 c5c6 g4f6 d3d4 f6g4 d4d5 " ++
    "g4f6 d5d6 h7h8 d6d7 e8f7 a2a3 h8d8 a3a4 f7e7 a4a5 f6d5 a5a6 d5b6")
    (noMoveMate) = true := by
  native_decide

/-- `bishop-corner`: 8/8/8/8/8/8/8/kBK5 w - - 0 1, reached in 62 plies. -/
theorem proofGame_bishop_corner :
    reaches
    ("b1a3 g8h6 g2g4 h6g4 g1h3 g4f2 h3g5 f2d3 e2d3 b8a6 g5f7 e8f7 f1g2 f7e6 g2b7 g7g5 b7c8 " ++
    "f8h6 c8d7 e6d5 d7f5 e7e6 b2b4 a6b4 f5h7 b4c2 a3c2 e6e5 d3d4 d5c4 d4e5 d8d2 d1d2 c7c6 " ++
    "d2g5 h6g5 e1d1 g5c1 d1c1 c4c3 h7e4 h8h2 a2a3 c3b3 a1a2 b3a2 c2a1 h2h7 h1h7 a8e8 h7a7 " ++
    "e8e5 e4c6 e5a5 c6e4 a5a3 a7a3 a2a3 e4h7 a3a2 h7b1 a2a1")
    (bishopCorner) = true := by
  native_decide

/-- `seventy-five`: k7/8/1K6/8/8/8/8/2R5 w - - 148 120, reached in 238 plies. -/
theorem proofGame_seventy_five :
    reaches
    ("b1c3 g8h6 g1h3 b8a6 h3g5 h6g4 g5h7 g4e3 h7f8 h8h2 f8d7 e8d7 c3d5 e3f1 h1f1 h2g2 f1g1 " ++
    "g2f2 g1g7 d7d6 g7f7 d6c5 f7e7 c8d7 e7d7 d8d7 d5b4 d7d2 d1d2 c7c6 d2d5 c6d5 c1f4 a8b8 " ++
    "f4b8 a6b8 a1c1 b8c6 b4c6 d5d4 c6b4 a7a6 e2e3 f2c2 e3d4 c5d4 b4a6 d4c4 a6b4 b7b5 a2a4 " ++
    "c4b3 b4a2 b3b2 a4b5 b2a3 b5b6 c2c6 a2b4 c6b6 b4a2 b6b1 c1d1 b1c1 d1c1 a3a4 e1d2 a4b3 " ++
    "c1c3 b3a4 d2d3 a4a5 c3c7 a5a6 c7e7 a6b5 e7g7 b5a4 d3e4 a4b5 e4e3 b5a6 e3e2 a6a5 g7c7 " ++
    "a5a4 c7c1 a4a3 e2e1 a3a2 c1d1 a2b2 e1e2 b2b3 d1d8 b3c4 d8d7 c4c3 d7g7 c3b4 e2f2 b4b5 " ++
    "g7f7 b5c6 f7f8 c6b6 f8f3 b6a5 f2e2 a5a6 f3f5 a6b6 f5f4 b6b7 e2d3 b7a8 f4g4 a8b8 g4h4 " ++
    "b8c7 h4b4 c7d8 d3c4 d8c7 c4c3 c7c8 b4f4 c8b8 c3d3 b8c8 f4a4 c8b7 d3c3 b7b8 a4g4 b8c7 " ++
    "c3d4 c7b8 g4g7 b8c8 g7g6 c8d8 d4c3 d8d7 g6g1 d7c7 g1e1 c7b6 e1f1 b6a5 c3d4 a5b4 f1f3 " ++
    "b4b5 f3f6 b5b4 f6f8 b4b3 d4e3 b3c4 f8g8 c4b3 g8g2 b3a3 e3d3 a3b3 g2g8 b3a4 g8g6 a4b4 " ++
    "g6g2 b4a3 g2g4 a3b3 g4g5 b3a4 d3c4 a4a3 g5e5 a3a2 e5e4 a2a1 e4d4 a1b2 d4d1 b2c2 d1e1 " ++
    "c2d2 e1h1 d2e2 h1d1 e2f2 d1b1 f2e3 b1b7 e3f4 b7g7 f4e3 g7g2 e3f4 g2d2 f4g4 d2d7 g4f4 " ++
    "d7d4 f4f3 c4d5 f3e3 d4d2 e3f4 d2a2 f4g5 a2c2 g5g4 d5e4 g4g5 c2c5 g5h4 c5e5 h4g3 e4d5 " ++
    "g3h4 d5c4 h4g3 e5e2 g3f4 e2e4 f4f5 e4h4 f5e6 h4h1 e6d7 c4c5 d7c8 c5b6 c8b8 h1c1 b8a8")
    (lateMate 148) (counters := true) = true := by
  native_decide

/-- `hamkins-nomove-mate`: KRBkn3/PP1P4/8/8/8/8/8/8 b - - 0 1, reached in 77 plies. -/
theorem proofGame_hamkins_nomove_mate :
    reaches
    ("g2g4 g8f6 f1h3 b8a6 c2c4 e7e6 c4c5 f8d6 c5d6 f6g4 e2e4 g4f2 e1f2 d8g5 h3e6 g5d2 f2f3 " ++
    "d2c1 b2b4 e8d8 b4b5 c1b1 b5b6 b1d1 f3f4 d1g1 b6a7 g1h2 h1h2 g7g5 f4e5 g5g4 h2h7 h8g8 " ++
    "h7f7 g8f8 e5d5 f8f7 a1b1 a8b8 b1b7 b8a8 b7b8 f7f8 e6d7 f8h8 d7c8 h8g8 d5c6 g8h8 c6b7 " ++
    "h8g8 b7a8 g8e8 a2a4 e8e4 a4a5 c7c6 d6d7 a6c7 a8b7 c7e8 a5a6 e4a4 b7a8 c6c5 b8b4 c5c4 " ++
    "b4c4 a4b4 c4g4 b4b7 g4b4 b7c7 b4b8 c7b7 a6b7")
    (hamkinsNoMoveMate) = true := by
  native_decide

/-- `hamkins-madore-stalemate`: 1r6/K6k/8/1q6/8/8/8/8 w - - 0 1, reached in 46 plies. -/
theorem proofGame_hamkins_madore_stalemate :
    reaches
    ("g1h3 g7g5 h3g5 f8h6 g5f7 e8f7 b1a3 h6d2 e1d2 d8e8 d2e3 f7g7 d1d7 g8h6 d7c8 e8b5 c8b7 " ++
    "b5b2 b7a7 b2c2 a7c7 c2e2 e3d4 e2f1 c7b8 h8b8 d4c5 a8a3 c1h6 g7h6 a1e1 a3a2 e1e7 a2f2 " ++
    "e7b7 f2g2 c5b6 g2h2 b6a7 f1b5 b7h7 h6h7 h1h2 h7g8 h2h7 g8h7")
    (hamkinsMadore) = true := by
  native_decide

/-- `hamkins-castling`: 5kr1/4p1p1/6B1/1b6/8/2p5/3q3P/1R2K2R w K - 0 1, reached in 44 plies. -/
theorem proofGame_hamkins_castling :
    reaches
    ("b1a3 c7c5 a1b1 c5c4 g1h3 c4c3 h3g5 g8h6 g5f7 e8f7 g2g4 h6g4 e2e3 g4e3 f1d3 e3c2 d3c2 " ++
    "b7b6 c2h7 c8a6 a3b5 a6b5 d1a4 h8g8 a4a7 f7e8 a7b8 a8a2 b8b6 a2b2 b6f6 b2d2 f6f8 e8f8 " ++
    "h7g6 d2f2 c1f4 d7d6 f4d6 f2f7 g6f7 d8d6 f7g6 d6d2")
    (hamkinsCastling) = true := by
  native_decide

/-- `hamkins-double-stalemate`: k7/P1p5/KpP5/1P6/8/8/8/8 b - - 0 1, reached in 63 plies. -/
theorem proofGame_hamkins_double_stalemate :
    reaches
    ("e2e4 b8c6 c2c4 c6e5 d1g4 e5c4 g4g7 c4d2 g7g8 e7e6 b2b4 d8g5 b4b5 e8d8 a2a4 g5g2 a4a5 " ++
    "g2g1 a5a6 d7d5 e4d5 d2c4 g8f8 d8d7 f8c8 d7c8 e1e2 c8b8 e2d3 g1f1 d3c3 f1c1 c3b4 c1g1 " ++
    "b1a3 g1h2 a1a2 h2f2 h1h7 c4a3 h7f7 a3c4 f7f6 h8h2 f6e6 f2b6 e6b6 a7b6 a2h2 b8a7 h2h6 " ++
    "a8h8 h6b6 h8h6 b6c6 h6c6 d5c6 a7a8 a6a7 c4a5 b4a5 b7b6 a5a6")
    (hamkinsDoubleStalemate) = true := by
  native_decide

/-- `hamkins-lose-turn`: kqn5/prp1p3/KpPpP3/1P1P4/8/8/8/8 b - - 0 1, reached in 91 plies. -/
theorem proofGame_hamkins_lose_turn :
    reaches
    ("d2d4 f7f5 e1d2 b8a6 d2c3 b7b6 a2a3 c8b7 h2h3 b7g2 a3a4 g2h1 a4a5 a8b8 g1f3 e8f7 h3h4 " ++
    "f7e6 h4h5 e6d5 f3g1 d5c6 g1f3 c6b7 f3g1 b7a8 c3c4 b8b7 c4b5 d8b8 g1f3 a6c5 f3g1 c5e4 " ++
    "b5a6 e4d6 g1f3 d6c8 f1h3 h1f3 h3f5 g8h6 f5h7 h8h7 c1h6 f3h5 f2f3 h5f3 d1h1 f3h1 h6g7 " ++
    "h7h6 g7h6 h1f3 h6c1 f8h6 b1d2 h6d2 a1a3 d2a5 a3f3 a5d2 f3f4 d2f4 c1f4 c8d6 f4c1 d6c8 " ++
    "b2b4 c8d6 b4b5 d6c8 c2c4 c8d6 c4c5 d6c8 c5c6 c8d6 c1a3 d6c8 a3d6 c8d6 d4d5 d6c8 e2e3 " ++
    "c8d6 e3e4 d6c8 e4e5 d7d6 e5e6")
    (hamkinsLoseTurn) = true := by
  native_decide

/-- `hamkins-pinned`: k6q/4K3/4P3/8/1r6/b4B2/8/Q7 b - - 0 1, reached in 61 plies. -/
theorem proofGame_hamkins_pinned :
    reaches
    ("g2g4 g8h6 f1g2 h6g4 g2b7 g4f2 e1f2 b8c6 f2g3 a8b8 g3h4 c6d4 h4g5 d4c2 e2e4 c2a1 e4e5 " ++
    "a1b3 e5e6 b3c1 d1c1 g7g6 b7f3 b8b2 c1c7 b2b1 c7a7 c8a6 g1e2 a6e2 f3e2 b1b4 e2f3 d8a8 " ++
    "d2d4 e8d8 d4d5 d8c8 a7d7 c8b8 d7e7 a8d5 g5f6 d5a2 e7f7 a2h2 f7h7 h2h1 h7h8 b4b7 f6g6 " ++
    "b8a8 h8a1 f8a3 f3g4 b7b4 g6f7 h1h6 f7e7 h6h8 g4f3")
    (hamkinsPinned) = true := by
  native_decide

/-- `hamkins-krk-passing`: 8/8/8/8/2r5/4k3/8/3K4 w - - 0 1, reached in 46 plies. -/
theorem proofGame_hamkins_krk_passing :
    reaches
    ("g1h3 g7g5 h3g5 f8h6 g5f7 e8f7 b1a3 h6d2 c1d2 f7g6 d2g5 g6g5 d1d7 g5f4 d7d8 c8h3 d8b8 " ++
    "h3g2 b8b7 g2f1 b7a7 f1e2 c2c4 e2c4 e1d1 c4a2 a1a2 f4f3 a7c7 a8a4 c7e7 f3f2 e7h7 f2e3 " ++
    "h7g8 h8h2 a3c4 a4c4 g8c8 h2b2 h1h2 b2h2 a2c2 h2c2 c8c4 c2c4")
    (hamkinsRookPassing) = true := by
  native_decide

/-- `opposite-outcome-5`: 8/8/8/8/8/8/3Q4/R3Kqk1 w Q - 0 1, reached in 52 plies. -/
theorem proofGame_opposite_outcome_5 :
    reaches
    ("g1h3 g7g5 h3g5 f8h6 g5f7 e8f7 b1a3 d8f8 e2e3 f7g6 f1a6 h6e3 a6b7 g6g5 b7c8 g5h4 c8d7 " ++
    "b8d7 g2g3 h4h3 b2b4 e3d2 d1d2 h3g2 d2d7 g8h6 c1h6 a7a5 b4a5 a8a5 d7e7 a5a3 e7d8 a3a2 " ++
    "d8d2 a2c2 h6f4 f8f4 d2c2 g2h1 c2h7 h1g1 h7c7 h8d8 c7d8 f4g3 h2h3 g3h3 f2f3 h3f3 d8d2 " ++
    "f3f1")
    (oppositeOutcome5) = true := by
  native_decide

end Chess
