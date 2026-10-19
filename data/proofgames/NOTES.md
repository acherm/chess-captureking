# Proof games for the constructed positions

FIDE 3.10.3 calls a position illegal when "it cannot have been reached by any series of legal
moves". Every constructed position used in the project, and every position transcribed from the
diagrams of Hamkins' essay *Every game of chess ends prematurely*, is reached here by a legal game
from the initial position. So all 14 positions are legal positions; none of them is unreachable.

* `proofgames.tsv`: one game per target (`name`, `target_fen`, `reached_fen`, `plies`, `uci_moves`).
* Check: `python3 -I scripts/proofgame_check.py data/proofgames/proofgames.tsv` replays every game
  with python-chess 1.11.2. Every move must be legal and the game must not end before the last
  move (checkmate, stalemate, insufficient material, fivefold repetition, 75-move rule;
  `claim_draw=False`). The final placement, side to move, castling rights and en passant square
  must match the target. Move counters are checked only for `seventy-five`. The final position
  may itself be over: several targets are mates, stalemates or dead positions.

## Method

Both sides cooperate (as in a helpmate). The games were found with a small weighted-A* search over
legal moves, written on top of python-chess and not kept in the repository. The heuristic is a
min-cost assignment of the current pieces to the target pieces: king/knight distances, 1 or 2
moves for line pieces, pawn moves (a file change needs as many captures), promotion cost, plus a
cost for each piece that still has to be captured. Pieces that must never move are frozen: a king
and rook that keep a castling right, and pawns on their starting rank. The search prunes every
position that ends the game. Lower weights gave shorter games, so each row keeps the shortest
verified game found. For hamkins-nomove-mate it keeps the shortest game without promotion: 77
plies, against 65 for a game with two underpromotions. Three positions are locked cages: no-move-mate, hamkins-double-stalemate and
hamkins-lose-turn. Almost nothing can move in them, so the order of the last moves matters, and the
search stalled just short of the target. Their games combine three parts:
search up to a hand-chosen intermediate position, a hand-written plan worked out by retrograde
analysis, and checking by python-chess. Promotions appear only where they are required
(`castle-attack`).

| target | plies | final position (python-chess) | built by |
|---|---:|---|---|
| opposite-outcome | 46 | White checkmated | search, Ke1/Ra1/Pf2 frozen |
| opposite-outcome-5 | 52 | White checkmated | search, Ke1/Ra1 frozen |
| castle-escape-small | 46 | White checkmated | search, Ke1/Rh1 frozen |
| castle-attack | 45 | Black in check (6 legal moves) | search, Ke8/Rh8 frozen |
| no-move-mate | 98 | White checkmated | search to a waypoint + hand-written plan |
| bishop-corner | 62 | dead position (K+B v K) | search to the position before the last capture |
| seventy-five | 238 | clocks `148 120` exactly | search + closed walk + random walk/BFS |
| hamkins-nomove-mate | 77 | Black to move, 6 legal moves | search, no promotion allowed |
| hamkins-madore-stalemate | 46 | White stalemated | search |
| hamkins-castling | 44 | White checkmated | search, Ke1/Rh1/Ph2/Pe7/Pg7 frozen |
| hamkins-double-stalemate | 63 | Black stalemated | search to a waypoint + 5 hand-written plies |
| hamkins-lose-turn | 91 | Black stalemated | hand-written cage + search (cage frozen) + hand-written finish |
| hamkins-pinned | 61 | Black in check (4 legal moves) | search |
| hamkins-krk-passing | 46 | White to move, one legal move (Ke1) | search |

## Notes per target

**opposite-outcome** `8/8/8/8/1Q6/3k4/4qP2/R3K3 w Q - 0 1`. White is checkmated: Qe2 is guarded by
Kd3, and O-O-O is not allowed out of check. Retro facts: the f2 pawn is on its starting square, so it
never moved. The castling right means that Ke1 and Ra1 never moved. These three units stay frozen
in the search. White lost 12 units and Black 14. Black's last move gave the check; a queen already
on d1, d2, f1 or on the open e-file would have been giving check before. In the game the last move is
23...Qg4-e2#.

**opposite-outcome-5** `8/8/8/8/8/8/3Q4/R3Kqk1 w Q - 0 1`. White is checkmated:
* Qf1 is guarded by Kg1.
* Qf1 covers d1 along the first rank and e2 on the diagonal.
* f2 is next to Kg1.
* O-O-O is not allowed out of check.

Retro facts:
* The castling right means that Ke1 and Ra1 never moved; both stay frozen in the search.
* White lost 13 units and Black 14.
* Black's last move gave the check, since no other black unit can check e1. A queen on e2 or f2
  would already have been checking, and a queen on d1, c1 or b1 could not cross e1. So the queen
  came from f3-f8, from d3, c4, b5 or a6 through e2, or from g2 or h3, possibly capturing on f1.

The game uses no promotion and ends 25. f3 Qxf3 26. Qd2 Qf1#.

**castle-escape-small** `8/8/8/8/4k3/8/1r6/1q2K2R w K - 0 1`. White is checkmated in FIDE chess:
Rb2 covers d2, e2 and f2, Qb1 covers d1 and f1, and castling out of check is not allowed. Ke1 and Rh1
never moved. Black's last move must give the check. A queen arriving from a1, c1 or d1 along an empty
first rank would already have been checking. So the queen came from a2, c2 or d3, or it captured a
blocker on b1. In the game it is 23. Nb1 Qa2xb1#.

**castle-attack** `1B2k2r/2N3r1/4r3/8/8/8/8/5K2 b k - 0 1`. Black is in check from Nc7, so O-O is
illegal. Black's legal moves are Kd7, Kd8, Ke7, Kf7, Kf8 and Rxc7. Black has three rooks, so at least
one is promoted: in the game, 4...gxh2 5...hxg1=R. Ke8 and Rh8 never moved, and Bb8 is White's
dark-squared bishop. White's last move is the knight check, 23. Nd5-c7+.

**no-move-mate** `KN1q4/PPpPk3/PnP5/8/8/8/8/8 w - - 0 1`. White is checkmated by Nb6 and has no
legal move at all: every white unit is blocked. Retro facts:
* The c7 pawn never moved.
* White's five pawns stand on files a, a, b, c, d, which needs at least 4 pawn captures. In the game
  they are exd3, bxa4, cxb3 and dxc3.
* The white king must reach a8 before a7, b7 and b8 are all filled.
* The black queen may come back to d8 only after b8 is occupied; otherwise it would attack a8 along
  the eighth rank.
* White's last move is a pawn move, since the king and the knight are boxed in. Black's last move
  is the knight check, from a4, c4, d5 or c8. In the game they are 49. a5-a6 Nd5-b6#.

Construction: a 62-ply search to a waypoint (White Ka8, Nb8, pawns a2 a4 b3 c3 d3; Black Ke8,
Qh7, Nf6, Pc7; White to move), then 36 hand-written plies. The pawns advance (a4-a7, b3-b7,
c3-c6, d3-d6) while the black knight shuttles f6-g4. Then 45. d7+ Kf7, Qh8-d8, Ke7, and the
second a-pawn advances a3-a4-a5-a6 while the knight goes ...Nf6-d5-b6#.

**bishop-corner** `8/8/8/8/8/8/8/kBK5 w - - 0 1`. K+B against K is a dead position, so with that
material the game would already have ended one ply earlier. The last move must therefore be a
capture, and only the black king can make it. Kb2xa1 is impossible because b2 touches c1, so the
last move is Ka2xa1, out of the check by Bb1. The game searches to `8/8/8/8/8/8/k7/NBK5 b`, with a
white knight on a1, and ends 30...Ka2 31. Bb1+ Kxa1.

**seventy-five** `k7/8/1K6/8/8/8/8/2R5 w - - 148 120`. Both counters match exactly: halfmove
clock 148 and fullmove number 120, after 238 plies. The last capture or pawn move is therefore at
ply 90, Black's 45th move. After it no pawn ever moves and nothing is captured, so the material is
already K+R v K by then. So ply 90 is a capture, not a pawn move: a black pawn moved at ply 90
would still be on the board. Black's only unit is the king, so the king makes that capture:
45...Ka3xa2 takes a white knight.
* Plies 1-65: search to `8/8/8/8/8/k7/N7/2R1K3 b`.
* Plies 66-89: a closed 24-ply walk that returns to the same position without repeating any other
  position, to hit ply 90 exactly.
* Ply 90: the capture.
* Plies 91-238: K+R v K with no capture and no position repeated in the random part, never
  mate or stalemate. A 138-ply random walk is followed by a 10-ply shortest path to the target.
  The last moves are ...Kb8-a8 (a7 and b7 touch Kb6).

No position occurs more than twice in the whole game. The clock never reaches 150, so the 75-move
rule never applies. A 50-move claim would have been available, but claims are optional.

**hamkins-nomove-mate** `KRBkn3/PP1P4/8/8/8/8/8/8 b - - 0 1`. Legal. This is the position before
Hamkins' 1... Nc7#: Black has 6 legal moves (Kc7, Ke7, Nc7#, Nd6, Nf6 and Ng7). The game uses no promotion, so Bc8 is White's original f1 bishop
(Bh3-e6xd7xc8). The last move is 39. a6xb7, which takes a rook.

**hamkins-madore-stalemate** `1r6/K6k/8/1q6/8/8/8/8 w - - 0 1`. Legal. White is stalemated:
a8, b7 and b6 are covered, b8 is guarded by Qb5 through b6-b7, and Qb5 covers a6. Black's last
move produces the stalemate. In the game it is 23...Kxh7, taking the last white rook.

**hamkins-castling** `5kr1/4p1p1/6B1/1b6/8/2p5/3q3P/1R2K2R w K - 0 1`. Legal. White is checkmated
in FIDE chess:
* Qd2 is guarded by c3.
* Bb5 covers f1.
* Castling out of check is illegal.

Retro facts:
* Ke1 and Rh1 never moved (castling right).
* h2, e7 and g7 are on their starting squares, so they never moved.
* Black's Bb5 is the light-squared c8 bishop, and White's Bg6 is the f1 bishop.

The game ends 22...Qd6-d2#.

**hamkins-double-stalemate** `k7/P1p5/KpP5/1P6/8/8/8/8 b - - 0 1`. Legal. Black is stalemated.
Retro facts:
* White's last move cannot have been b4-b5 or c5-c6, because Black would then have had no legal
  last move:
  * ...Kb7-a8 starts next to Ka6.
  * ...axb6 and ...cxb6 would have emptied a7 or c7.
  * ...b7-b6 would have left the white king on a6 in check with Black to move.
  * ...Kb8-a8 needs a previous white check from a7, which cannot be produced.
* So White's last move is a king move or a pawn capture.

The game searches to `k7/1pp5/P1P5/1P6/1Kn5/8/8/8 w` and ends 30. a7 Na5 31. Kxa5 b6+ 32. Ka6:
the king steps out of the pawn check into the stalemate.

**hamkins-lose-turn** `kqn5/prp1p3/KpPpP3/1P1P4/8/8/8/8 b - - 0 1`. Legal. Black is stalemated: all
nine black units are blocked. Retro facts:
* a7, c7 and e7 never moved.
* So the b6 pawn is the b-pawn, which played b7-b6.
* So Rb7 entered via b8 after b7-b6, since a7, c7 and b6 were then occupied for good.
* The white king cannot enter a6 while a black pawn stands on b7. Once b6 is occupied it cannot
  come from a5 either (b6 guards a5), so it came from b5 or b7.

Construction:
1. Hand-written cage, 38 plies. Black plays ...f5, ...Na6, ...b6, ...Bb7xg2xh1 and ...Rb8. The black
   king walks e8-f7-e6-d5-c6-b7-a8, then ...Rb7, ...Qb8 and the knight a6-c5-e4-d6-c8. Meanwhile the
   white king walks d2-c3-c4-b5-a6.
2. Search with the cage frozen, 30 plies, down to White K + pawns b2, c2, d4, e2 + Bc1.
3. Hand-written finish, 23 plies. The white pawns advance while the black knight shuttles c8-d6,
   which gives Black the tempo moves. The bishop is given up on d6 (41. Bd6 Nxd6). e2-e3-e4-e5
   fixes the parity. The game ends 44...Nc8 45. e5 d6 46. e6, stalemate.

**hamkins-pinned** `k6q/4K3/4P3/8/1r6/b4B2/8/Q7 b - - 0 1`. Legal. Black is in check from Bf3.
A bishop moving along the a8-h1 diagonal would already have been giving check, so the bishop came
from the d1-h5 diagonal (or the check was discovered). In the game the last move is 31. Bg4-f3+.
Black's legal moves are Kb8, Ka7, Re4+ and Rb7#. Rb7# blocks the check and uncovers Ba3 against Ke7.

**hamkins-krk-passing** `8/8/8/8/2r5/4k3/8/3K4 w - - 0 1`. Legal. White to move has exactly one
legal move, Ke1. The game ends 23...Rxc4, taking the last white piece.
