import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

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

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Rings span 1.00 -> 0.22 (hub edge) evenly: (1.00-0.22)/3 = 0.26 each.
    // Black innerFrac=0.22 matches hub radius fraction -> zero gap.
    _drawRing(canvas, center, radius,
      outerFrac: 1.00, innerFrac: 0.74,   // red - width 0.26
      colors: [AppColors.redRing1, AppColors.redRing2],
      angle: redAngle,
      textColor: const Color(0xFFffbbbb),
      hasGlow: showRedGlow,
    );
    _drawRing(canvas, center, radius,
      outerFrac: 0.74, innerFrac: 0.48,   // green - width 0.26
      colors: [AppColors.greenRing1, AppColors.greenRing2],
      angle: greenAngle,
      textColor: const Color(0xFFaaffcc),
      hasGlow: showGreenGlow,
    );
    _drawRing(canvas, center, radius,
      outerFrac: 0.48, innerFrac: 0.22,   // black - width 0.26, inner = hub edge
      colors: [AppColors.blackRing1, AppColors.blackRing2],
      angle: blackAngle,
      textColor: Colors.white,
      hasGlow: showBlackGlow,
    );

    // Single gold separator at each ring boundary
    _drawSeparators(canvas, center, radius);
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius, {
    required double outerFrac,
    required double innerFrac,
    required List<Color> colors,
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

    for (int i = 0; i < 10; i++) {
      final double startAngle = startOffset + i * segAngle;

      final double localMidAngle = startAngle + segAngle / 2;
      final double worldMidAngle = localMidAngle + angle;
      double diff = (worldMidAngle - (-pi / 2)) % (2 * pi);
      if (diff < 0) diff += 2 * pi;
      if (diff > pi) diff = 2 * pi - diff;

      final bool isAtTop = diff < (segAngle / 2);
      // Landed segment: blue ONLY when locked-in (hasGlow).
      final Color segColor = (isAtTop && hasGlow) ? AppColors.blueLens : colors[i % 2];
      final Color numColor = (isAtTop && hasGlow) ? Colors.white : textColor;

      final paint = Paint()
        ..color = segColor
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
        ..color = Colors.black.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      canvas.drawPath(path, borderPaint);

      final midAngle = startAngle + segAngle / 2;
      final midR = (outerR + innerR) / 2;
      final textX = center.dx + midR * cos(midAngle);
      final textY = center.dy + midR * sin(midAngle);

      _drawNumber(canvas, _digits[i].toString(), Offset(textX, textY),
        midAngle + pi / 2, numColor,
        fontSize: (innerR - outerR).abs() * 0.46,
        isGlow: false, // Selected number does not glow
      );
    }

    canvas.restore();
  }

  void _drawNumber(Canvas canvas, String text, Offset pos,
      double rotation, Color color, {double fontSize = 14, bool isGlow = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Oswald',
          fontWeight: isGlow ? FontWeight.w900 : FontWeight.w600,
          fontSize: (isGlow ? fontSize * 1.15 : fontSize).clamp(7.0, 24.0),
          color: color,
          shadows: [
            if (isGlow)
              Shadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 4,
              ),
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

  void _drawSeparators(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = AppColors.goldPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Separators match ring boundaries
    for (double frac in [0.74, 0.48, 0.22]) {
      canvas.drawCircle(center, radius * frac, paint);
    }
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
