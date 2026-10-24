import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// The "Place your chips" / "No More Play" message of the tablet game screen,
/// shown as a pill above the wheel. On the phone the same message sits in the
/// right panel's header bar; the rule is the same: "No More Play" (flashing
/// between gold and red) when `countdown <= 5`, not spinning and `countdown > 0`,
/// otherwise "Place your chips". It only reads `GameProvider`; it changes nothing.
///
/// [scale] sizes the pill for the screen (1.0 is the 1280-wide design).
class TabletStatusPill extends StatefulWidget {
  final double scale;
  /// Whether the pill has its gold border. True on the tablet; the desktop top
  /// bar uses it without a border.
  final bool bordered;
  const TabletStatusPill({super.key, this.scale = 1.0, this.bordered = true});

  @override
  State<TabletStatusPill> createState() => _TabletStatusPillState();
}

class _TabletStatusPillState extends State<TabletStatusPill> with SingleTickerProviderStateMixin {
  late AnimationController _flashCtrl;
  late Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);
    _colorAnim = ColorTween(
      begin: AppColors.goldBright,
      end: AppColors.dangerRed,
    ).animate(_flashCtrl);
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  Widget _label(String text, Color? color) {
    final s = widget.scale;
    return Text(
      text,
      style: AppTextStyles.label(size: 19 * s, color: color).copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 2.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return Consumer<GameProvider>(
      builder: (_, game, __) {
        final warn = game.countdown <= 5 && !game.isSpinning && game.countdown > 0;
        return Container(
          // Fixed width so the pill does not change size when the message
          // switches between "Place your chips" and "No More Play".
          width: 320 * s,
          padding: EdgeInsets.symmetric(vertical: 9 * s),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6B0000), Color(0xFF2A0000)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12 * s),
            border: widget.bordered
                ? Border.all(color: AppColors.goldPrimary, width: 2 * s)
                : null,
            boxShadow: [
              BoxShadow(color: const Color(0xFF120000), offset: Offset(0, 4 * s)),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 10 * s,
                offset: Offset(0, 8 * s),
              ),
            ],
          ),
          child: warn
              ? AnimatedBuilder(
                  animation: _colorAnim,
                  builder: (_, __) => _label('No More Play', _colorAnim.value),
                )
              : _label('Place your chips', AppColors.goldBright),
        );
      },
    );
  }
}
