import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';

/// The PLAY / WIN box under the results table on the desktop screen: the total
/// staked across all three boards and what the last round paid, small amounts
/// starting from the left of their half. The balance is not here (it is in the
/// top bar).
///
/// Same numbers as the phone's stats panel (`_StatsPanel` in right_panel.dart):
/// PLAY is `game.totalBet`; WIN is the last round's `winAmount` when it won,
/// otherwise 0, shown with a leading "+". Only reads `GameProvider`.
class DesktopStatsBox extends StatelessWidget {
  const DesktopStatsBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (_, game, __) {
        final last = game.lastWinBoxResult;
        final lastWin = last != null && last.won ? last.winAmount : 0;
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E0800), Color(0xFF150200)],
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
          child: Row(
            children: [
              Expanded(child: _half('PLAY', '${game.totalBet}', Colors.white)),
              Container(width: 1.5, height: 36, color: AppColors.goldPrimary.withValues(alpha: 0.3)),
              Expanded(child: _half('WIN', '+$lastWin', const Color(0xFF4DDF7C))),
            ],
          ),
        );
      },
    );
  }

  Widget _half(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 18, right: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.5,
              color: AppColors.textGoldLight,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'Oswald',
                  fontWeight: FontWeight.w500,
                  fontSize: 19,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
