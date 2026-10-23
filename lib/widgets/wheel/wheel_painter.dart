import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// The two shades that make one 3D segment tone: [edge] is the darker shade at
/// the segment's inner and outer rim, [mid] the lighter shade across its
/// middle, so each ring reads as a domed band.
class _RingShade {
  final Color edge;
  final Color mid;
  const _RingShade(this.edge, this.mid);
}

/// Paints the three digit rings (red, green, black), each turned by its own
/// angle, with a 3D look: domed, glossy segments lit from the top left, a
/// bevelled gold divider between rings, and one fixed shine over the whole
/// wheel. The spin logic, timing and result hub live in wheel_widget.dart;
/// this class only draws what it is given.
class WheelPainter extends CustomPainter {
  final double redAngle;
  final double greenAngle;
  final double blackAngle;
  final bool showRedGlow;
  final bool showGreenGlow;
  final bool showBlackGlow;

  const WheelPainter({
    required this.redAngle,
    required this.greenAngle,
    required this.blackAngle,
    this.showRedGlow = false,
    this.showGreenGlow = false,
    this.showBlackGlow = false,
  });

  static const List<int> _digits = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

  // Segment tones per ring (ruby, emerald, onyx). Index 0 is used for even
  // digits (the darker tone) and index 1 for odd digits (the brighter tone),
  // the same alternation the flat rings always had.
  static const List<_RingShade> _redShades = [
    _RingShade(Color(0xFF3A0208), Color(0xFF9A1424)),
    _RingShade(Color(0xFF5A050E), Color(0xFFC8283A)),
  ];
  static const List<_RingShade> _greenShades = [
    _RingShade(Color(0xFF03301A), Color(0xFF0F7A3A)),
    _RingShade(Color(0xFF064424), Color(0xFF1A9B4C)),
  ];
  static const List<_RingShade> _blackShades = [
    _RingShade(Color(0xFF040405), Color(0xFF1E1E24)),
    _RingShade(Color(0xFF09090C), Color(0xFF30303A)),
  ];
  // Lighter middle of the landed (blue) segment; its darker edge is AppColors.blueLens.
  static const Color _winMid = Color(0xFF3E7BEA);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Issue #101 follow-up (corrected): all three rings narrowed from
    // width 0.26 to width 0.24 uniformly (not just Black absorbing the
    // change) -- each ring gives up 0.02, so the hub edge moves 0.22 -> 0.28
    // total. Every ring's digit font size shrinks by the same proportion
    // (~-7.7%) since it's derived from ring width. Hub radius fraction
    // (wheel_widget.dart's hubSize calc) must match Black's innerFrac
    // exactly -- zero gap, unchanged principle.
    _drawRing(canvas, center, radius,
      outerFrac: 1.00, innerFrac: 0.76,   // red - width 0.24
      shades: _redShades,
      angle: redAngle,
      textColor: const Color(0xFFffbbbb),
      hasGlow: showRedGlow,
    );
    _drawRing(canvas, center, radius,
      outerFrac: 0.76, innerFrac: 0.52,   // green - width 0.24
      shades: _greenShades,
      angle: greenAngle,
      textColor: const Color(0xFFaaffcc),
      hasGlow: showGreenGlow,
    );
    _drawRing(canvas, center, radius,
      outerFrac: 0.52, innerFrac: 0.28,   // black - width 0.24, inner = hub edge
      shades: _blackShades,
      angle: blackAngle,
      textColor: Colors.white,
      hasGlow: showBlackGlow,
    );

    // Fixed layers, drawn after the rings so they never turn with them: shade
    // at the wheel's outer edge and around the hub, then the gold dividers,
    // then one shine over everything.
    _drawDepthShade(canvas, center, radius);
    _drawSeparators(canvas, center, radius);
    _drawGloss(canvas, center, radius);
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius, {
    required double outerFrac,
    required double innerFrac,
    required List<_RingShade> shades,
    required double angle,
    required Color textColor,
    required bool hasGlow,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(-center.dx, -center.dy);

    final double outerR = radius * outerFrac;
    final double innerR = radius * innerFrac;
    const double segAngle = 2 * pi / 10;
    const double startOffset = -pi / 2 - segAngle / 2;

    // Domed shading: a radial gradient centred on the wheel's middle (the
    // point the ring turns around), dark at the segment's inner and outer rim
    // and light across its middle. Because it is centred on the turning point
    // it looks the same at every angle, so the lighting does not spin with
    // the ring. One shader per tone is shared by that tone's five segments.
    ui.Shader domed(Color edge, Color mid) => ui.Gradient.radial(
      center,
      outerR,
      [edge, mid, edge],
      [innerR / outerR, (innerR / outerR + 1) / 2, 1.0],
    );
    final shaderEven = domed(shades[0].edge, shades[0].mid);
    final shaderOdd = domed(shades[1].edge, shades[1].mid);
    final shaderWin = domed(AppColors.blueLens, _winMid);

    for (int i = 0; i < 10; i++) {
      final double startAngle = startOffset + i * segAngle;

      final double localMidAngle = startAngle + segAngle / 2;
      final double worldMidAngle = localMidAngle + angle;
      double diff = (worldMidAngle - (-pi / 2)) % (2 * pi);
      if (diff < 0) diff += 2 * pi;
      if (diff > pi) diff = 2 * pi - diff;

      final bool isAtTop = diff < (segAngle / 2);
      // Landed segment: blue ONLY when locked-in (hasGlow).
      final bool isLanded = isAtTop && hasGlow;
      final Color numColor = isLanded ? Colors.white : textColor;

      final paint = Paint()
        ..shader = isLanded ? shaderWin : (i % 2 == 0 ? shaderEven : shaderOdd)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;

      final path = Path();
      final outerRect = Rect.fromCircle(center: center, radius: outerR);
      final innerRect = Rect.fromCircle(center: center, radius: innerR);

      path.addArc(outerRect, startAngle, segAngle);
      path.arcTo(innerRect, startAngle + segAngle, -segAngle, false);
      path.close();
      canvas.drawPath(path, paint);

      final borderPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      canvas.drawPath(path, borderPaint);

      // The landed segment also gets a light rim so it looks lit from within.
      if (isLanded) {
        final rimPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..isAntiAlias = true;
        canvas.drawPath(path, rimPaint);
      }

      final midAngle = startAngle + segAngle / 2;
      final midR = (outerR + innerR) / 2;
      final textX = center.dx + midR * cos(midAngle);
      final textY = center.dy + midR * sin(midAngle);

      // +1px flat on the ring digits, via a matching clamp-bound shift in
      // _drawNumber() so it applies uniformly across the size range.
      _drawNumber(canvas, _digits[i].toString(), Offset(textX, textY),
        midAngle + pi / 2, numColor,
        fontSize: (innerR - outerR).abs() * 0.46 + 1.0,
      );
    }

    canvas.restore();
  }

  void _drawNumber(Canvas canvas, String text, Offset pos,
      double rotation, Color color, {double fontSize = 14}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Oswald',
          fontWeight: FontWeight.w600,
          fontSize: fontSize.clamp(8.0, 25.0),
          color: color,
          shadows: [
            Shadow(
              color: Colors.black87,
              blurRadius: 1.5,
              offset: const Offset(0.5, 0.5),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rotation);
    canvas.translate(-tp.width / 2, -tp.height / 2);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  /// Shade that deepens the wheel at its outer edge (as if tucked under the
  /// rim) and around the hub. Fixed: it does not turn with the rings.
  void _drawDepthShade(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          Colors.black.withValues(alpha: 0.5),
          Colors.black.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.55),
        ],
        const [0.27, 0.36, 0.9, 1.0],
      );
    canvas.drawCircle(center, radius, paint);
  }

  /// Gold divider at each ring boundary, bevelled: a dark line underneath, the
  /// gold line (a lighter-to-darker gold sweep across the wheel), and a thin
  /// bright line along its outer side.
  void _drawSeparators(Canvas canvas, Offset center, double radius) {
    final under = Paint()
      ..color = const Color(0xFF2A1500)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;
    final gold = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - radius * 0.9, center.dy - radius * 0.9),
        Offset(center.dx + radius * 0.9, center.dy + radius * 0.9),
        const [Color(0xFFFFF0A8), AppColors.goldPrimary, AppColors.goldDark, AppColors.goldPrimary],
        const [0.0, 0.3, 0.6, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final light = Paint()
      ..color = const Color(0xFFFFF6C0).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Separators match ring boundaries (all three moved with the width
    // reduction above: 0.74/0.48/0.22 -> 0.76/0.52/0.28).
    for (double frac in [0.76, 0.52, 0.28]) {
      canvas.drawCircle(center, radius * frac, under);
      canvas.drawCircle(center, radius * frac, gold);
      canvas.drawCircle(center, radius * frac + 0.6, light);
    }
  }

  /// One fixed shine over the whole wheel: light from the top left fading to
  /// shade at the bottom right (a glassy dome). Fixed: it does not turn with
  /// the rings.
  void _drawGloss(Canvas canvas, Offset center, double radius) {
    final gloss = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - radius * 0.6, center.dy - radius),
        Offset(center.dx + radius * 0.6, center.dy + radius),
        [
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.28),
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawCircle(center, radius, gloss);
  }

  @override
  bool shouldRepaint(WheelPainter old) =>
    old.redAngle != redAngle ||
    old.greenAngle != greenAngle ||
    old.blackAngle != blackAngle ||
    old.showRedGlow != showRedGlow ||
    old.showGreenGlow != showGreenGlow ||
    old.showBlackGlow != showBlackGlow;
}
