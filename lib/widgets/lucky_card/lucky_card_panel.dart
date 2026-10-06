// The gold-edged dark panel every readout in the Lucky Card side column and top bar
// is drawn on, and the one place its colours live. Drawn in code (no picture), in
// the same palette as the board's artwork.
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import 'lucky_card_layout.dart';

/// The gold of the rims and of every label.
const Color kLuckyCardGold = Color(0xFFD4AF37);

/// The bright gold of a highlighted rim and of the countdown.
const Color kLuckyCardGoldBright = Color(0xFFFFD84A);

/// The cream of every number.
const Color kLuckyCardCream = Color(0xFFF5E6C4);

/// The red of a warning: the last five seconds.
const Color kLuckyCardAlert = Color(0xFFFF5A4A);

/// The green of a win.
const Color kLuckyCardWin = Color(0xFF7CE08A);

/// A dark red panel with a gold rim. [highlighted] draws the rim brighter and
/// thicker; [dimmed] fades the whole panel (a control that cannot be used).
class LuckyCardPanel extends StatelessWidget {
  const LuckyCardPanel({
    super.key,
    required this.layout,
    required this.child,
    this.highlighted = false,
    this.dimmed = false,
    this.padding = EdgeInsets.zero,
    this.radiusUnits = 16,
  });

  final LuckyCardLayout layout;
  final Widget child;
  final bool highlighted;
  final bool dimmed;
  final EdgeInsets padding;
  final double radiusUnits;

  @override
  Widget build(BuildContext context) {
    final rim = (layout.dp(highlighted ? 6 : 4)).clamp(1.2, 4.0).toDouble();
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A0A0C), Color(0xFF160203)],
        ),
        borderRadius: BorderRadius.circular(layout.dp(radiusUnits)),
        border: Border.all(color: highlighted ? kLuckyCardGoldBright : kLuckyCardGold, width: rim),
        boxShadow: highlighted
            ? const [BoxShadow(color: Color(0x66FFD84A), blurRadius: 6)]
            : const [BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Padding(padding: padding, child: child),
    );
    return dimmed ? Opacity(opacity: 0.4, child: panel) : panel;
  }
}

/// A group of digits with a comma every three: 50000 is "50,000". The board writes
/// its numbers without separators because they sit on small pictures; the fixed
/// limits are written the usual way.
String luckyCardGrouped(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
