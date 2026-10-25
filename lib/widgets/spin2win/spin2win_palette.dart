// The colours, gradients and text of the Spin2Win screen, copied from the reference design
// (`reference-design/spin2win/Lucky Wheel Game UI.html`, the phone board, 844 x 390). Values and two
// small drawing helpers only: no state, no provider.
//
// Belongs to Spin2Win only.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The design's two fonts, as `pubspec.yaml` names them.
const String kSpin2WinFont = 'DMSans';
const String kSpin2WinDigitsFont = 'Oswald';

// ── Shared colours ────────────────────────────────────────────────────────

const Color kS2wGold = Color(0xFFFFD45A);
const Color kS2wGoldBorder = Color(0xFFFFB52E);
const Color kS2wGoldUnder = Color(0xFF4A2F00);
const Color kS2wCyan = Color(0xFF00E5FF);
const Color kS2wNavyWell = Color(0xFF061030);
const Color kS2wBgDeep = Color(0xFF07132E);

/// The top-bar boxes' fill (coin box and PLAY/WIN bar).
const LinearGradient kS2wBarFill = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF183A78), Color(0xFF0B1C3F)],
);

/// The betting panel's fill.
const LinearGradient kS2wPanelFill = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF14306A), Color(0xFF102650), Color(0xFF0A1A3E)],
  stops: [0, 0.4, 1],
);

/// The history strip's fill.
const LinearGradient kS2wStripFill = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF14306A), Color(0xFF0A1A3E)],
);

/// The screen's background: `radial-gradient(ellipse 70% 80% at 28% 45%, #173a80, #0c2155 45%,
/// #07132E)`, stretched to the box it fills so it keeps the design's oval on any screen.
const RadialGradient kS2wBackground = RadialGradient(
  center: Alignment(-0.44, -0.1),
  radius: 0.8,
  colors: [Color(0xFF173A80), Color(0xFF0C2155), kS2wBgDeep],
  stops: [0, 0.45, 1],
  transform: _StretchToBox(),
);

/// Makes a [RadialGradient] an oval the shape of its box (CSS `ellipse` with percentage radii):
/// the gradient's circle is sized from the box's height and stretched sideways by width / height.
class _StretchToBox extends GradientTransform {
  const _StretchToBox();

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    if (bounds.height <= 0) return null;
    // The design's radii are 70% of the width and 80% of the height; the circle is 80% of the
    // shorter side (the height on a landscape screen), so stretch x by (0.7 w) / (0.8 h).
    final shortest = math.min(bounds.width, bounds.height);
    final sx = (0.7 * bounds.width) / (0.8 * shortest);
    final sy = (0.8 * bounds.height) / (0.8 * shortest);
    final cx = bounds.left + bounds.width * 0.28;
    final cy = bounds.top + bounds.height * 0.45;
    return Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..scaleByDouble(sx, sy, 1, 1)
      ..translateByDouble(-cx, -cy, 0, 1);
  }
}

// ── Number colours ────────────────────────────────────────────────────────

/// The five shades of one number's colour, as the design's `COL` table lists them: [edge] (the
/// light rim), [light], [mid] and [dark] (the face, top to bottom) and [under] (the solid
/// shadow under a card or tile).
class Spin2WinShades {
  const Spin2WinShades(this.edge, this.light, this.mid, this.dark, this.under);

  final Color edge;
  final Color light;
  final Color mid;
  final Color dark;
  final Color under;

  /// The card's outer rim: edge at the top to dark at the bottom.
  LinearGradient get rim => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [edge, dark],
      );

  /// The face: light, mid at half way, dark.
  LinearGradient get face => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [light, mid, dark],
      );
}

const Spin2WinShades _cyan =
    Spin2WinShades(Color(0xFFB8FBFF), Color(0xFF6FF3FF), Color(0xFF00B8E6), Color(0xFF0077A8), Color(0xFF003A58));
const Spin2WinShades _red =
    Spin2WinShades(Color(0xFFFFC2CC), Color(0xFFFF7A8E), Color(0xFFFF3155), Color(0xFFC8102E), Color(0xFF5E0716));
const Spin2WinShades _yellow =
    Spin2WinShades(Color(0xFFFFF4C2), Color(0xFFFFE98A), Color(0xFFFFC928), Color(0xFFE09A00), Color(0xFF6B4500));
const Spin2WinShades _green =
    Spin2WinShades(Color(0xFFC8FFDD), Color(0xFF7DFFAE), Color(0xFF19D96B), Color(0xFF0A9A45), Color(0xFF04461F));
const Spin2WinShades _purple =
    Spin2WinShades(Color(0xFFE0CCFF), Color(0xFFB98BFF), Color(0xFF853BFF), Color(0xFF5A1FC2), Color(0xFF2A0C5E));
const Spin2WinShades _blue =
    Spin2WinShades(Color(0xFFC4DEFF), Color(0xFF6FB0FF), Color(0xFF1677FF), Color(0xFF0A4FC4), Color(0xFF052866));
const Spin2WinShades _orange =
    Spin2WinShades(Color(0xFFFFF0C0), Color(0xFFFFE07A), Color(0xFFFFB52E), Color(0xFFD98300), Color(0xFF663C00));
const Spin2WinShades _pink =
    Spin2WinShades(Color(0xFFFFD0F3), Color(0xFFFF8AE2), Color(0xFFFF35C7), Color(0xFFC20E92), Color(0xFF5A0445));

/// Each number's shades, 0 to 9 (1 and 6 share red, 4 and 8 share purple, as in the design).
const List<Spin2WinShades> kSpin2WinShades = [
  _cyan, _red, _yellow, _green, _purple, _blue, _red, _orange, _purple, _pink, //
];

Spin2WinShades spin2WinShades(int number) => kSpin2WinShades[number];

/// The wheel's ten segments clockwise from the pointer, as the design draws them.
const List<int> kSpin2WinWheelOrder = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0];

/// Each segment's colour, in [kSpin2WinWheelOrder]'s order.
const List<Color> kSpin2WinSegmentColors = [
  Color(0xFFFF3155), Color(0xFFFFC928), Color(0xFF19D96B), Color(0xFF853BFF), Color(0xFF1677FF), //
  Color(0xFFFF3155), Color(0xFFFFB52E), Color(0xFF853BFF), Color(0xFFFF35C7), Color(0xFF00C8F0),
];

// ── Bonus colours ─────────────────────────────────────────────────────────

/// The light and dark colour of a bonus badge.
class Spin2WinBonusShades {
  const Spin2WinBonusShades(this.light, this.dark);

  final Color light;
  final Color dark;

  LinearGradient get fill => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [light, dark],
      );
}

/// N, 2x, 3x and 4x, from the design's `BONUS` table.
Spin2WinBonusShades spin2WinBonusShades(int multiplier) => switch (multiplier) {
      2 => const Spin2WinBonusShades(Color(0xFF6FF3FF), Color(0xFF0077A8)),
      3 => const Spin2WinBonusShades(Color(0xFF7DFFAE), Color(0xFF0A9A45)),
      4 => const Spin2WinBonusShades(Color(0xFF6FB0FF), Color(0xFF0A4FC4)),
      _ => const Spin2WinBonusShades(Color(0xFFC7D3EE), Color(0xFF5A6A8E)),
    };

/// The bonus as the screen writes it: N, 2x, 3x or 4x (the design's lower-case x).
String spin2WinBonusText(int multiplier) => multiplier <= 1 ? 'N' : '${multiplier}x';

// ── Numbers as text ───────────────────────────────────────────────────────

/// A whole number written with thousands commas, as the design's `toLocaleString('en-US')`:
/// 1250 -> "1,250".
String spin2WinAmountText(int amount) {
  final digits = amount.abs().toString();
  final out = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

// ── The design's outlined text (`.num`) ───────────────────────────────────

/// White (or [color]) heavy text with a dark outline and a drop shadow under it: the design's
/// `.num` class (`-webkit-text-stroke` painted under the fill, so only its outer half shows).
/// How far above the middle of a one-line box (`height: 1`) capitals and digits sit, as a share
/// of the font size: the font's ascent is larger than its descent, so the line's middle falls below
/// the middle of the letters. DM Sans Black: ascent 992, descent 310, cap height 700 (per 1000);
/// Oswald: ascent 1193, descent 289, cap height 810. Moving a label down by this much centres its
/// letters in the box (Hasan's phone test, 2026-10-25: the button words looked a little high).
const double kSpin2WinFontCapsLift = 0.088;
const double kSpin2WinDigitsFontCapsLift = 0.10;

/// Moves one line of text (`height: 1`) down so its capitals and digits sit in the true middle of
/// their box: by [kSpin2WinFontCapsLift] of the font size for DM Sans, [kSpin2WinDigitsFontCapsLift]
/// for Oswald.
class Spin2WinCapsCentred extends StatelessWidget {
  const Spin2WinCapsCentred({super.key, required this.size, required this.child, this.digitsFont = false});

  /// The font size of [child]'s text.
  final double size;

  /// True when [child] is in Oswald ([kSpin2WinDigitsFont]).
  final bool digitsFont;
  final Widget child;

  @override
  Widget build(BuildContext context) => Transform.translate(
        offset: Offset(0, size * (digitsFont ? kSpin2WinDigitsFontCapsLift : kSpin2WinFontCapsLift)),
        child: child,
      );
}

class Spin2WinOutlinedText extends StatelessWidget {
  const Spin2WinOutlinedText(
    this.text, {
    super.key,
    required this.size,
    this.color = const Color(0xFFFFFFFF),
    this.stroke = const Color(0xBF100A28),
    this.strokeWidth = 3,
    this.letterSpacing = 0.3,
    this.height,
    this.shadows = kS2wNumShadows,
    this.centreCaps = false,
  });

  /// Moves the word down by [kSpin2WinFontCapsLift] so its capitals sit in the true middle of a
  /// button (use with `height: 1`).
  final bool centreCaps;

  final String text;
  final double size;
  final Color color;
  final Color stroke;
  final double strokeWidth;
  final double letterSpacing;
  final double? height;
  final List<Shadow> shadows;

  @override
  Widget build(BuildContext context) {
    TextStyle style(Paint? foreground, List<Shadow>? shadows) => TextStyle(
          fontFamily: kSpin2WinFont,
          fontWeight: FontWeight.w900,
          fontSize: size,
          height: height,
          letterSpacing: letterSpacing,
          color: foreground == null ? color : null,
          foreground: foreground,
          shadows: shadows,
        );
    final word = Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: style(
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
            shadows,
          ),
        ),
        Text(text, textAlign: TextAlign.center, maxLines: 1, softWrap: false, style: style(null, null)),
      ],
    );
    if (!centreCaps) return word;
    return Transform.translate(offset: Offset(0, size * kSpin2WinFontCapsLift), child: word);
  }
}

/// The `.num` drop shadow: `0 3px 0 rgba(0,0,0,.35), 0 4px 6px rgba(0,0,0,.35)`.
const List<Shadow> kS2wNumShadows = [
  Shadow(color: Color(0x59000000), offset: Offset(0, 3)),
  Shadow(color: Color(0x59000000), offset: Offset(0, 4), blurRadius: 6),
];

// ── The design's gloss (`.gloss::before`) ────────────────────────────────

/// Paints the design's shine on a button or card: a white fade over the top 44% of the box,
/// 6% in from each side and 2 dp down, rounded 10 dp at the top and in a half oval at the bottom.
/// Drawn under the child, so the label sits on top of it.
class Spin2WinGlossPainter extends CustomPainter {
  const Spin2WinGlossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(size.width * 0.06, 2, size.width * 0.88, size.height * 0.44);
    if (rect.width <= 0 || rect.height <= 0) return;
    final bottom = Radius.elliptical(rect.width / 2, rect.height / 2);
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(10),
      topRight: const Radius.circular(10),
      bottomLeft: bottom,
      bottomRight: bottom,
    ).scaleRadii();
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x80FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(Spin2WinGlossPainter oldDelegate) => false;
}

/// A box drawn the way the design draws its buttons: [decoration] (fill, border and the solid
/// shadow under it), the gloss over the fill, clipped to [radius] (or to a circle), then [child].
class Spin2WinGlossBox extends StatelessWidget {
  const Spin2WinGlossBox({
    super.key,
    required this.decoration,
    required this.child,
    this.radius = 0,
    this.circle = false,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.borderWidth = 0,
  });

  final BoxDecoration decoration;
  final Widget child;
  final double radius;
  final bool circle;
  final double? width;
  final double? height;
  final EdgeInsets padding;

  /// The border's width, so the gloss and the child sit inside it.
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final innerRadius = math.max(0.0, radius - borderWidth);
    Widget inside = CustomPaint(
      painter: const Spin2WinGlossPainter(),
      child: Padding(padding: padding, child: child),
    );
    inside = circle
        ? ClipOval(child: inside)
        : ClipRRect(borderRadius: BorderRadius.circular(innerRadius), child: inside);
    return Container(
      width: width,
      height: height,
      decoration: decoration,
      padding: EdgeInsets.all(borderWidth),
      child: inside,
    );
  }
}
