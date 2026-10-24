import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bet_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';
import '../panels/grid_cells.dart';
import 'desktop_board_header.dart';

/// The Doubles board (00 to 99) of the desktop screen: a gold-framed panel
/// with its header (name, PLAY, WIN), the 10 x 10 grid with a row arrow at the
/// start of every row and a column arrow under every column, and the RANDOM
/// PICK buttons in a row under the grid.
///
/// Everything is the game's own: the cells are `NumberCell`, the arrows are
/// `RowArrowButton` / `ColArrowButton` (they stake a whole row or column) and
/// the random picks are `RandomShortcutButton` (5, 10, 15, 20, 25, 50 and 75,
/// the same counts as the phone's Doubles grid). A cell tap makes exactly the
/// call the phone's Doubles grid makes: with a chip selected
/// `game.placeBet(BoardType.double_, number, auth)`, with none selected
/// (REMOVE mode) `game.removeChipFromCell(BoardType.double_, number, auth)`.
/// Only the arrangement (random picks under the grid, not in a column beside
/// it) is new.
class DesktopDoublesBoard extends StatelessWidget {
  const DesktopDoublesBoard({super.key});

  // The grid frame is 336 square (2 border + 2 padding on each side, so the
  // cells are 32.8); arrows are sized to line up with the cells.
  static const double _gridSize = 336;
  static const double _frame = 4;
  static const double _cell = (_gridSize - 2 * _frame) / 10;
  static const double _rowArrowWidth = 26;
  static const double _colArrowHeight = 24;
  // Same counts as the phone's Doubles grid (`_doubleRandomCounts` in grids.dart).
  static const List<int> _randomCounts = [5, 10, 15, 20, 25, 50, 75];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A0805), Color(0xFF150200)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldPrimary, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF120000), offset: Offset(0, 5)),
          BoxShadow(color: Color(0x99000000), blurRadius: 16, offset: Offset(0, 10)),
        ],
      ),
      child: Consumer2<GameProvider, AuthProvider>(
        builder: (_, game, auth, __) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DesktopBoardHeader(title: 'DOUBLES', mode: 'double'),
            const SizedBox(height: 4),

            // Row arrows | the 10 x 10 grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _rowArrowWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(top: _frame),
                    child: Column(
                      children: List.generate(
                        10,
                        (row) => SizedBox(
                          height: _cell,
                          child: RowArrowButton(
                            rowIndex: row,
                            boardType: BoardType.double_,
                            game: game,
                            auth: auth,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: _gridSize,
                  height: _gridSize,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D1A00),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.goldPrimary, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                  ),
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 10,
                      childAspectRatio: 1,
                    ),
                    itemCount: 100,
                    itemBuilder: (_, i) {
                      final number = i.toString().padLeft(2, '0');
                      return NumberCell(
                        number: number,
                        stakedAmount: game.board.double_[number],
                        isEven: ((i ~/ 10) + (i % 10)) % 2 == 0,
                        onTap: () => game.activeChip != null
                            ? game.placeBet(BoardType.double_, number, auth)
                            : game.removeChipFromCell(BoardType.double_, number, auth),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Column arrows, one under each column of the grid
            Padding(
              padding: const EdgeInsets.only(left: _rowArrowWidth + 2 + _frame, top: 2),
              child: Row(
                children: List.generate(
                  10,
                  (col) => SizedBox(
                    width: _cell,
                    height: _colArrowHeight,
                    child: ColArrowButton(
                      colIndex: col,
                      boardType: BoardType.double_,
                      game: game,
                      auth: auth,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // RANDOM PICK: label, then one button for each count
            Row(
              children: [
                const SizedBox(
                  width: 58,
                  child: Text(
                    'RANDOM\nPICK',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                      height: 1.1,
                      letterSpacing: 1,
                      color: AppColors.textGoldLight,
                    ),
                  ),
                ),
                ..._randomCounts.map(
                  (count) => Expanded(
                    child: RandomShortcutButton(
                      count: count,
                      boardType: BoardType.double_,
                      game: game,
                      auth: auth,
                      height: 28,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
