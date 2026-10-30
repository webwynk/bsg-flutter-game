// The gold-edged dark panel the Lucky 16 Card dialogs will be drawn on (Info, Exit, History: later
// phases), and the one place its colours live. Drawn in code (no picture).
//
// Copied from lib/widgets/lucky_card/lucky_card_panel.dart (Lucky Card); only the names changed.
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import 'lucky16_layout.dart';

/// The gold of the rims and of every label.
const Color kLucky16Gold = Color(0xFFD4AF37);

/// The bright gold of a highlighted rim and of the countdown.
const Color kLucky16GoldBright = Color(0xFFFFD84A);

/// The cream of every number.
const Color kLucky16Cream = Color(0xFFF5E6C4);

/// The red of a warning: the last five seconds.
const Color kLucky16Alert = Color(0xFFFF5A4A);

/// The green of a win.
const Color kLucky16Win = Color(0xFF7CE08A);

/// A dark red panel with a gold rim. [highlighted] draws the rim brighter and
/// thicker; [dimmed] fades the whole panel (a control that cannot be used).
class Lucky16Panel extends StatelessWidget {
  const Lucky16Panel({
    super.key,
    required this.layout,
    required this.child,
    this.highlighted = false,
    this.dimmed = false,
    this.padding = EdgeInsets.zero,
    this.radiusUnits = 16,
  });

  final Lucky16Layout layout;
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
        border: Border.all(color: highlighted ? kLucky16GoldBright : kLucky16Gold, width: rim),
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
String lucky16Grouped(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
