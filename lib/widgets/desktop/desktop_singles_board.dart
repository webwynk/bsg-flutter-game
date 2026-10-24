import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bet_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';
import '../panels/grid_cells.dart';
import 'desktop_board_header.dart';

/// The Singles board (0 to 9) of the desktop screen: ten cells in one row, in
/// a gold-framed panel with its own header (name, PLAY, WIN).
///
/// The cells are the game's own `NumberCell` (same look, same gold stake
/// dome) and a tap makes exactly the call the phone's Singles grid makes:
/// with a chip selected `game.placeBet(BoardType.single, key, auth)`, with no
/// chip selected (REMOVE mode) `game.removeChipFromCell(BoardType.single, key,
/// auth)`. Even digits are green and odd digits pink, as on the phone. Only
/// the arrangement (one row instead of a 2 x 5 block) is new.
class DesktopSinglesBoard extends StatelessWidget {
  const DesktopSinglesBoard({super.key});

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DesktopBoardHeader(title: 'SINGLES', mode: 'single', height: 24, titleSize: 12),
          const SizedBox(height: 4),
          Container(
            height: 46,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF3D1A00),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.goldPrimary, width: 2),
            ),
            child: Consumer2<GameProvider, AuthProvider>(
              builder: (_, game, auth, __) => Row(
                children: List.generate(10, (i) {
                  final key = '$i';
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: NumberCell(
                        number: key,
                        stakedAmount: game.board.single[key],
                        isEven: i % 2 == 0,
                        onTap: () => game.activeChip != null
                            ? game.placeBet(BoardType.single, key, auth)
                            : game.removeChipFromCell(BoardType.single, key, auth),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
