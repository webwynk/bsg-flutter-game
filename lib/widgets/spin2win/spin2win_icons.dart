// The small drawings of the Spin2Win screen, painted from the reference design's SVG paths (the
// app has no SVG package): the exit arrow, the coin stack, the trophy, the speaker and the jewel
// pointer over the wheel. Each painter draws in the design's own viewBox, scaled to its size.
//
// Belongs to Spin2Win only.

import 'package:flutter/widgets.dart';

/// Scales [canvas] so the design's viewBox ([box] wide and high) fills [size].
void _fit(Canvas canvas, Size size, Size box) => canvas.scale(size.width / box.width, size.height / box.height);

Paint _stroke(Color color, double width) => Paint()
  ..style = PaintingStyle.stroke
  ..color = color
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint _fill(Color color) => Paint()..color = color;

/// The exit button's arrow out of a door (viewBox 24).
class Spin2WinExitIconPainter extends CustomPainter {
  const Spin2WinExitIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _fit(canvas, size, const Size(24, 24));
    final p = _stroke(const Color(0xFFFFFFFF), 2.6);
    // M14 4h4a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-4
    final door = Path()
      ..moveTo(14, 4)
      ..lineTo(18, 4)
      ..arcToPoint(const Offset(20, 6), radius: const Radius.circular(2))
      ..lineTo(20, 18)
      ..arcToPoint(const Offset(18, 20), radius: const Radius.circular(2))
      ..lineTo(14, 20);
    canvas.drawPath(door, p);
    canvas.drawPath(Path()..moveTo(10, 8)..lineTo(6, 12)..lineTo(10, 16), p);
    canvas.drawLine(const Offset(6, 12), const Offset(16, 12), p);
  }

  @override
  bool shouldRepaint(Spin2WinExitIconPainter oldDelegate) => false;
}

/// The coin stack beside the balance (viewBox 28 x 26).
class Spin2WinCoinStackPainter extends CustomPainter {
  const Spin2WinCoinStackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _fit(canvas, size, const Size(28, 26));
    const edge = Color(0xFFD98300);
    void coin(double cy, Color face) {
      canvas.drawOval(Rect.fromCenter(center: Offset(11, cy + 2), width: 18, height: 8), _fill(const Color(0xFFB06A00)));
      final top = Rect.fromCenter(center: Offset(11, cy), width: 18, height: 8);
      canvas.drawOval(top, _fill(face));
      canvas.drawOval(top, _stroke(edge, 1));
    }

    coin(18, const Color(0xFFFFC928));
    coin(12, const Color(0xFFFFD45A));
    canvas.drawCircle(const Offset(20, 11), 7, _fill(const Color(0xFFFFB52E)));
    canvas.drawCircle(const Offset(20, 11), 7, _stroke(const Color(0xFFB06A00), 1.5));
    canvas.drawCircle(const Offset(20, 11), 4.2, _stroke(const Color(0xFFFFF0C0), 1.2));
  }

  @override
  bool shouldRepaint(Spin2WinCoinStackPainter oldDelegate) => false;
}

/// The records button's trophy (viewBox 24).
class Spin2WinTrophyPainter extends CustomPainter {
  const Spin2WinTrophyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _fit(canvas, size, const Size(24, 24));
    const gold = Color(0xFFFFD45A);
    const amber = Color(0xFFFFB52E);
    const brown = Color(0xFF7A4500);

    // Handles: M7 5H4.5a2.5 2.5 0 0 0 2.6 4.4 / M17 5h2.5a2.5 2.5 0 0 1-2.6 4.4
    final handles = Path()
      ..moveTo(7, 5)
      ..lineTo(4.5, 5)
      ..arcToPoint(const Offset(7.1, 9.4), radius: const Radius.circular(2.5), clockwise: false)
      ..moveTo(17, 5)
      ..lineTo(19.5, 5)
      ..arcToPoint(const Offset(16.9, 9.4), radius: const Radius.circular(2.5));
    canvas.drawPath(handles, _stroke(gold, 2.2));

    // Cup: M7 3h10v5.5a5 5 0 0 1-10 0z
    final cup = Path()
      ..moveTo(7, 3)
      ..lineTo(17, 3)
      ..lineTo(17, 8.5)
      ..arcToPoint(const Offset(7, 8.5), radius: const Radius.circular(5))
      ..close();
    canvas.drawPath(cup, _fill(gold));
    canvas.drawPath(cup, _stroke(brown, 1.4)..strokeCap = StrokeCap.butt);

    // Stem: M10.5 13.4h3v3.8h-3z
    const stem = Rect.fromLTWH(10.5, 13.4, 3, 3.8);
    canvas.drawRect(stem, _fill(amber));
    canvas.drawRect(stem, _stroke(brown, 1.2));

    // Base: M7.5 21v-1.5a2 2 0 0 1 2-2h5a2 2 0 0 1 2 2V21z
    final base = Path()
      ..moveTo(7.5, 21)
      ..lineTo(7.5, 19.5)
      ..arcToPoint(const Offset(9.5, 17.5), radius: const Radius.circular(2))
      ..lineTo(14.5, 17.5)
      ..arcToPoint(const Offset(16.5, 19.5), radius: const Radius.circular(2))
      ..lineTo(16.5, 21)
      ..close();
    canvas.drawPath(base, _fill(amber));
    canvas.drawPath(base, _stroke(brown, 1.4));

    // Star: M12 4.8l.9 1.8 2 .3-1.45 1.4.35 2-1.8-.95-1.8.95.35-2L9.1 6.9l2-.3z
    final star = Path()
      ..moveTo(12, 4.8)
      ..relativeLineTo(.9, 1.8)
      ..relativeLineTo(2, .3)
      ..relativeLineTo(-1.45, 1.4)
      ..relativeLineTo(.35, 2)
      ..relativeLineTo(-1.8, -.95)
      ..relativeLineTo(-1.8, .95)
      ..relativeLineTo(.35, -2)
      ..lineTo(9.1, 6.9)
      ..relativeLineTo(2, -.3)
      ..close();
    canvas.drawPath(star, _fill(const Color(0xFFFFFFFF)));
  }

  @override
  bool shouldRepaint(Spin2WinTrophyPainter oldDelegate) => false;
}

/// The sound button's speaker (viewBox 24): with its two sound waves, or, when [muted], with a
/// cross in their place.
class Spin2WinSpeakerPainter extends CustomPainter {
  const Spin2WinSpeakerPainter({required this.muted});

  final bool muted;

  @override
  void paint(Canvas canvas, Size size) {
    _fit(canvas, size, const Size(24, 24));
    const white = Color(0xFFFFFFFF);
    final p = _stroke(white, 2.4);
    // M4 9h4l5-4v14l-5-4H4z, filled and outlined.
    final body = Path()
      ..moveTo(4, 9)
      ..lineTo(8, 9)
      ..lineTo(13, 5)
      ..lineTo(13, 19)
      ..lineTo(8, 15)
      ..lineTo(4, 15)
      ..close();
    canvas.drawPath(body, _fill(white));
    canvas.drawPath(body, p);
    if (muted) {
      canvas.drawLine(const Offset(16.5, 9), const Offset(21.5, 15), p);
      canvas.drawLine(const Offset(21.5, 9), const Offset(16.5, 15), p);
    } else {
      // M16.5 8.5a5 5 0 0 1 0 7 / M19 6a8.5 8.5 0 0 1 0 12
      canvas.drawPath(
        Path()
          ..moveTo(16.5, 8.5)
          ..arcToPoint(const Offset(16.5, 15.5), radius: const Radius.circular(5))
          ..moveTo(19, 6)
          ..arcToPoint(const Offset(19, 18), radius: const Radius.circular(8.5)),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(Spin2WinSpeakerPainter oldDelegate) => oldDelegate.muted != muted;
}

/// The gold jewel pointer at the top of the wheel (viewBox 46 x 54), with its drop shadow.
class Spin2WinPointerPainter extends CustomPainter {
  const Spin2WinPointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _fit(canvas, size, const Size(46, 54));
    // The design's M23 52 L4 20 A19 19 0 1 1 42 20 Z with a shorter tip (Hasan, 2026-10-25): the
    // point is at y 47 instead of 52 and its sides meet the round head where they touch it.
    final body = Path()
      ..moveTo(23, 47)
      ..lineTo(9.49, 33.37)
      ..arcToPoint(const Offset(36.51, 33.37), radius: const Radius.circular(19), largeArc: true)
      ..close();
    // drop-shadow(0 5px 4px rgba(0,0,0,.65))
    canvas.drawPath(
      body.shift(const Offset(0, 5)),
      Paint()
        ..color = const Color(0xA6000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    const bodyRect = Rect.fromLTWH(0, 0, 46, 54);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF0C0), Color(0xFFFFB52E), Color(0xFF8A5000)],
          stops: [0, 0.45, 1],
        ).createShader(bodyRect),
    );
    canvas.drawPath(body, _stroke(const Color(0xFF5A3500), 2.5));

    const gemRect = Rect.fromLTWH(14, 11, 18, 18);
    canvas.drawCircle(
      const Offset(23, 20),
      9,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          radius: 0.75,
          colors: [Color(0xFFFFC2CC), Color(0xFFFF3155), Color(0xFF7A0A1E)],
          stops: [0, 0.45, 1],
        ).createShader(gemRect),
    );
    canvas.drawCircle(const Offset(23, 20), 9, _stroke(const Color(0xFF7A0A1E), 1.5));
    canvas.drawCircle(const Offset(20, 17), 2.6, _fill(const Color(0xD9FFFFFF)));
  }

  @override
  bool shouldRepaint(Spin2WinPointerPainter oldDelegate) => false;
}
