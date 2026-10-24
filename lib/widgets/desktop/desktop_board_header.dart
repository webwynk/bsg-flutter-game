import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';

/// The title bar of a desktop board panel: the board's name on the left, and
/// this board's own PLAY (what is staked on it) and WIN (what it won last
/// round) on the right, the same numbers the phone's tab badges show.
/// [mode] is 'single', 'double' or 'triple'. Only reads `GameProvider`.
class DesktopBoardHeader extends StatelessWidget {
  final String title;
  final String mode;
  final double height;
  final double titleSize;

  const DesktopBoardHeader({
    super.key,
    required this.title,
    required this.mode,
    this.height = 30,
    this.titleSize = 14,
  });

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'DMSans',
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 1,
          color: Color(0xFF99AAAA),
        ),
      );

  Widget _amount(int value, Color color) => Text(
        '$value',
        style: TextStyle(
          fontFamily: 'Oswald',
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: color,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (_, game, __) {
        final play = game.playForMode(mode);
        final win = game.winForMode(mode);
        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8A0A10), Color(0xFF4A0408), Color(0xFF2A0204)],
              stops: [0.0, 0.5, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.goldPrimary, width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0xFF120000), offset: Offset(0, 2))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w900,
                  fontSize: titleSize,
                  letterSpacing: 3,
                  color: AppColors.goldBright,
                  shadows: const [Shadow(color: Color(0xCC000000), offset: Offset(0, 1))],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _label('PLAY'),
                  const SizedBox(width: 4),
                  _amount(play, Colors.white),
                  const SizedBox(width: 10),
                  _label('WIN'),
                  const SizedBox(width: 4),
                  _amount(win, const Color(0xFF4DDF7C)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
