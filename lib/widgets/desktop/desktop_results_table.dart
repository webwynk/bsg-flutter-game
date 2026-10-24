import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';

/// The results table at the bottom left of the desktop screen: the last six
/// draws as three rows, TRIPLE (all three digits), DOUBLE (the last two) and
/// SINGLE (the last one), newest on the left and highlighted in gold, older
/// draws to its right; a draw that has not happened yet shows "-".
///
/// Only reads `GameProvider.globalHistory` (the same list the phone's history
/// grid reads; it keeps the last ten draws, newest first, and this table shows
/// the first six). A draw's digits are `red`, `green`, `black` of its
/// `SpinResult`: Triple = red + green + black, Double = green + black,
/// Single = black, the same rule the boards pay by.
class DesktopResultsTable extends StatelessWidget {
  const DesktopResultsTable({super.key});

  static const int _shown = 6;

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (_, game, __) {
        final hist = game.globalHistory;
        String? at(int i, String Function(int r, int g, int b) f) =>
            i < hist.length ? f(hist[i].red, hist[i].green, hist[i].black) : null;
        return Container(
          padding: const EdgeInsets.all(8),
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
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _row('TRIPLE', List.generate(_shown, (i) => at(i, (r, g, b) => '$r$g$b'))),
              _row('DOUBLE', List.generate(_shown, (i) => at(i, (r, g, b) => '$g$b'))),
              _row('SINGLE', List.generate(_shown, (i) => at(i, (r, g, b) => '$b'))),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, List<String?> values) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1,
              color: AppColors.goldBright,
            ),
          ),
        ),
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(child: _cell(values[i], newest: i == 0)),
        ],
      ],
    );
  }

  Widget _cell(String? value, {required bool newest}) {
    final filled = value != null;
    return Container(
      height: 25,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: filled && newest
            ? const LinearGradient(
                colors: [Color(0xFFFFEE66), Color(0xFFCC8800)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        color: filled && newest ? null : const Color(0xFF1E0400),
        borderRadius: BorderRadius.circular(3),
        boxShadow: filled && newest
            ? const [BoxShadow(color: Color(0x99FFD700), blurRadius: 6)]
            : null,
      ),
      child: Text(
        value ?? '-',
        style: TextStyle(
          fontFamily: 'Oswald',
          fontWeight: FontWeight.w600,
          fontSize: 17,
          height: 1.0,
          color: !filled
              ? Colors.white24
              : newest
                  ? const Color(0xFF2A1000)
                  : Colors.white,
        ),
      ),
    );
  }
}
