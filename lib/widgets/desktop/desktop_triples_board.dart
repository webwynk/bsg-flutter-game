import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bet_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';
import '../panels/grid_cells.dart';
import 'desktop_board_header.dart';

/// The Triples board (000 to 999) of the desktop screen: a gold-framed panel
/// with its header (name, PLAY, WIN), ten page tabs (000, 100, ... 900) above
/// a 10 x 10 grid showing one hundred numbers at a time, a row arrow at the
/// start of every row, a column arrow under every column, and the RANDOM PICK
/// buttons in a row under the grid.
///
/// Everything is the game's own: `NumberCell` for the cells, `RowArrowButton`
/// / `ColArrowButton` for the arrows (they already follow the page being
/// shown), `RandomShortcutButton` for the random picks (5, 10, 15, 20, 25, 50
/// and 100, the same counts as the phone's Triples grid), and the page tabs
/// work like the phone's: a tap calls `game.setTriplePage(page, auth)`, and a
/// tab is highlighted when it is the page being shown or when it holds a bet
/// (`int.parse(key) ~/ 100` for every key in `game.board.triple`). A cell tap
/// makes the call the phone's Triples grid makes: with a chip selected
/// `game.placeBet(BoardType.triple, number, auth)`, with none selected
/// `game.removeChipFromCell(BoardType.triple, number, auth)`. Only the
/// arrangement (random picks under the grid, not in a column beside it) is new.
class DesktopTriplesBoard extends StatelessWidget {
  const DesktopTriplesBoard({super.key});

  // Same sizes as the Doubles board so the two boards line up.
  static const double _gridSize = 336;
  static const double _frame = 4;
  static const double _cell = (_gridSize - 2 * _frame) / 10;
  static const double _rowArrowWidth = 26;
  static const double _colArrowHeight = 24;
  static const double _tabHeight = 22;
  // Same counts as the phone's Triples grid (`_tripleRandomCounts` in grids.dart).
  static const List<int> _randomCounts = [5, 10, 15, 20, 25, 50, 100];

  Widget _pageTabs(GameProvider game, AuthProvider auth) {
    // Hundred-groups (000-099, 100-199, ...) that hold at least one bet,
    // whichever page is being viewed.
    final groupsWithBets = game.board.triple.keys.map((k) => int.parse(k) ~/ 100).toSet();
    return Padding(
      padding: const EdgeInsets.only(left: _rowArrowWidth + 2),
      child: SizedBox(
        width: _gridSize,
        height: _tabHeight,
        child: Row(
          children: List.generate(10, (p) {
            final highlighted = game.triplePage == p || groupsWithBets.contains(p);
            return Expanded(
              child: GestureDetector(
                onTap: () => game.setTriplePage(p, auth),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    gradient: highlighted
                        ? const LinearGradient(
                            colors: [Color(0xFFFFEE66), Color(0xFFCC8800)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF440800), Color(0xFF1A0000)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: highlighted ? AppColors.goldBright : const Color(0xFF661100),
                      width: highlighted ? 1.5 : 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      (p * 100).toString().padLeft(3, '0'),
                      style: TextStyle(
                        fontFamily: 'Oswald',
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        height: 1.0,
                        color: highlighted ? const Color(0xFF2A1000) : Colors.white60,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

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
            const DesktopBoardHeader(title: 'TRIPLES', mode: 'triple'),
            const SizedBox(height: 4),
            _pageTabs(game, auth),
            const SizedBox(height: 2),

            // Row arrows | the 10 x 10 grid (the page being shown)
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
                            boardType: BoardType.triple,
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
                      final number = (game.triplePage * 100 + i).toString().padLeft(3, '0');
                      return NumberCell(
                        number: number,
                        stakedAmount: game.board.triple[number],
                        isEven: ((i ~/ 10) + (i % 10)) % 2 == 0,
                        onTap: () => game.activeChip != null
                            ? game.placeBet(BoardType.triple, number, auth)
                            : game.removeChipFromCell(BoardType.triple, number, auth),
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
                      boardType: BoardType.triple,
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
                      boardType: BoardType.triple,
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
