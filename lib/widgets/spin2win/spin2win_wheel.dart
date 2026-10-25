// The Spin2Win wheel, as the reference design draws it in its 316 dp column: a soft glow behind,
// the gold rim with its ring of 30 bulbs, the coloured face with the ten numbers (1 to 9, then 0,
// clockwise from the pointer), gold dividers and pegs, the gold hub with the blue dome in the
// middle, and the jewel pointer at the top.
//
// [Spin2WinWheel] draws one still frame: given the face's angle, what the dome shows and where each
// small animation is (the bulbs' twinkle, the glow's pulse, the winning segment's highlight, the
// pointer's bounce, the dome's pop), nothing else. spin2win_wheel_spin.dart moves them.
//
// Belongs to Spin2Win only.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'spin2win_icons.dart';
import 'spin2win_palette.dart';

/// What the dome in the middle of the wheel shows.
sealed class Spin2WinDome {
  const Spin2WinDome();
}

/// While the wheel spins: "BONUS" over the bonus being shuffled.
class Spin2WinDomeShuffling extends Spin2WinDome {
  const Spin2WinDomeShuffling(this.bonusMultiplier);

  final int bonusMultiplier;
}

/// Once the wheel has stopped: the winning number, with its bonus badge under it.
class Spin2WinDomeLanded extends Spin2WinDome {
  const Spin2WinDomeLanded(this.number, this.bonusMultiplier);

  final int number;
  final int bonusMultiplier;
}

/// The face's angle, in degrees clockwise, that puts [number] under the pointer.
double spin2WinAngleFor(int number) => -36.0 * kSpin2WinWheelOrder.indexOf(number);

class Spin2WinWheel extends StatelessWidget {
  const Spin2WinWheel({
    super.key,
    required this.angle,
    required this.dome,
    this.twinkle = 0,
    this.halo = 1,
    this.highlight,
    this.pointerDrop = 0,
    this.domeReveal = 1,
    this.reel = 0,
  });

  /// The face's turn, in degrees clockwise from the design's resting place (1 under the pointer).
  final double angle;
  final Spin2WinDome dome;

  /// Where the bulbs are in their twinkle, 0 to 1: at 0 every other bulb is bright, at 1 the others.
  final double twinkle;

  /// Where the glow behind the wheel is in its slow pulse, 0 (soft, small) to 1 (full, large).
  final double halo;

  /// The winning segment's highlight once the wheel has stopped: the segment under the pointer is
  /// lit and the others dimmed, at this strength (it pulses between 1 and 0.45); null for none.
  final double? highlight;

  /// How far the pointer is moved down, in dp (negative moves it up): its bounce when the wheel stops.
  final double pointerDrop;

  /// How far the landed dome's pop has got, 0 to 1 (the number grows in, the badge drops in).
  final double domeReveal;

  /// Where the shuffling bonus is in its quick jiggle, 0 to 1.
  final double reel;

  /// The design's column: 316 dp wide, the rim 268 dp across at (24, 8).
  static const double columnWidth = 316;
  static const double rimSize = 268;
  static const Offset rimOrigin = Offset(24, 8);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: columnWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glow behind the wheel: opacity .65 to 1, size 97% to 103%, as the design's `halo`.
          Positioned(
            left: 4,
            top: -12,
            width: 308,
            height: 308,
            child: Opacity(
              opacity: 0.65 + 0.35 * halo,
              child: Transform.scale(
                scale: 0.97 + 0.06 * halo,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      radius: 0.7071,
                      colors: [Color(0x73FFD45A), Color(0x38FF35C7), Color(0x1F853BFF), Color(0x00000000)],
                      stops: [0, 0.42, 0.58, 0.72],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: rimOrigin.dx,
            top: rimOrigin.dy,
            width: rimSize,
            height: rimSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: CustomPaint(painter: _RimPainter(twinkle))),
                Positioned(
                  left: 20,
                  top: 20,
                  width: 228,
                  height: 228,
                  child: Transform.rotate(
                    key: const ValueKey('spin2win-wheel-face'),
                    angle: angle * math.pi / 180,
                    child: const CustomPaint(painter: _FacePainter()),
                  ),
                ),
                const Positioned(
                  left: 20,
                  top: 20,
                  width: 228,
                  height: 228,
                  child: IgnorePointer(child: CustomPaint(painter: _LightingPainter())),
                ),
                if (highlight != null && dome is Spin2WinDomeLanded)
                  Positioned(
                    left: 20,
                    top: 20,
                    width: 228,
                    height: 228,
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: const ValueKey('spin2win-wheel-highlight'),
                        painter: _HighlightPainter((dome as Spin2WinDomeLanded).number, highlight!),
                      ),
                    ),
                  ),
                Positioned(
                  left: 78,
                  top: 78,
                  width: 112,
                  height: 112,
                  child: _Hub(dome: dome, reveal: domeReveal, reel: reel),
                ),
              ],
            ),
          ),
          Positioned(
            left: 135,
            top: -4 + pointerDrop,
            width: 46,
            height: 54,
            child: const CustomPaint(painter: Spin2WinPointerPainter()),
          ),
        ],
      ),
    );
  }
}

Rect _circle(Offset c, double r) => Rect.fromCircle(center: c, radius: r);

/// The rim (a gold sweep), the dark channel inside it and the 30 bulbs.
class _RimPainter extends CustomPainter {
  const _RimPainter(this.twinkle);

  /// 0 to 1: see [Spin2WinWheel.twinkle].
  final double twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // box-shadow: 0 6px 0 #4a2f00, 0 16px 28px rgba(0,0,0,.75), 0 0 34px rgba(255,181,46,.5)
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0x80FFB52E)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 17),
    );
    canvas.drawCircle(
      c + const Offset(0, 16),
      r,
      Paint()
        ..color = const Color(0xBF000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(c + const Offset(0, 6), r, Paint()..color = kS2wGoldUnder);
    // conic-gradient(from 20deg, ...)
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFFF0C0), Color(0xFFFFB52E), Color(0xFF8A5000), Color(0xFFFFD45A), Color(0xFFFFF0C0), //
            Color(0xFFD98300), Color(0xFF7A4500), Color(0xFFFFD45A), Color(0xFFFFF0C0),
          ],
          stops: [0, .12, .25, .38, .5, .63, .76, .88, 1],
          transform: GradientRotation((20 - 90) * math.pi / 180),
        ).createShader(_circle(c, r)),
    );
    // inset 0 3px 2px rgba(255,255,255,.75): a light line along the top inside edge.
    canvas.drawArc(
      _circle(c, r - 1.5),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x99FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );

    // The bulb channel, 8 dp in: radial-gradient(circle, #2a1600 0 82%, #0e0700 100%).
    final channel = r - 8;
    canvas.drawCircle(
      c,
      channel,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.7071,
          colors: [Color(0xFF2A1600), Color(0xFF2A1600), Color(0xFF0E0700)],
          stops: [0, 0.82, 1],
        ).createShader(_circle(c, channel)),
    );

    // 30 bulbs on a 120 dp circle; every other one twinkles opposite its neighbours (the design's
    // `tw`: opacity 1 to .4 and the glow 9 dp to 2 dp, the odd ones half a beat later).
    for (var i = 0; i < 30; i++) {
      final a = i * 12 * math.pi / 180;
      final p = c + Offset(120 * math.sin(a), -120 * math.cos(a));
      final t = i.isOdd ? 1 - twinkle : twinkle; // 0 = bright, 1 = dim
      final opacity = 1 - 0.6 * t;
      canvas.drawCircle(
        p,
        6 - 2 * t,
        Paint()
          ..color = kS2wGold.withValues(alpha: 0.9 * opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.5 - 3.5 * t),
      );
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: [
              const Color(0xFFFFFFFF).withValues(alpha: opacity),
              const Color(0xFFFFE07A).withValues(alpha: opacity),
              const Color(0xFFD98300).withValues(alpha: opacity),
            ],
            stops: const [0, .45, 1],
          ).createShader(_circle(p, 4)),
      );
    }
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) => oldDelegate.twinkle != twinkle;
}

/// The turning face: the ten coloured segments with their bevel, the gold dividers, the shine,
/// the ten pegs and the numbers. Segment i is centred at 36 x i degrees clockwise from the top.
class _FacePainter extends CustomPainter {
  const _FacePainter();

  static double _rad(double deg) => deg * math.pi / 180;

  /// Canvas angle (0 = three o'clock) of a design angle (0 = twelve o'clock, clockwise).
  static double _canvas(double deg) => _rad(deg - 90);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final face = _circle(c, r);

    // box-shadow: 0 0 0 3px #FFD45A, 0 0 0 5px #5a3500
    canvas.drawCircle(c, r + 5, Paint()..color = const Color(0xFF5A3500));
    canvas.drawCircle(c, r + 3, Paint()..color = kS2wGold);

    for (var i = 0; i < 10; i++) {
      final start = -18.0 + 36 * i;
      canvas.drawArc(face, _canvas(start), _rad(36), true, Paint()..color = kSpin2WinSegmentColors[i]);
      // The bevel: the first half of each segment lighter, the second darker.
      canvas.drawArc(face, _canvas(start), _rad(18), true, Paint()..color = const Color(0x3DFFFFFF));
      canvas.drawArc(face, _canvas(start + 18), _rad(18), true, Paint()..color = const Color(0x29000000));
      // The divider at the segment's start: a light line then a dark one.
      canvas.drawArc(face, _canvas(start), _rad(0.9), true, Paint()..color = const Color(0xFFFFF0C0));
      canvas.drawArc(face, _canvas(start + 0.9), _rad(1.0), true, Paint()..color = const Color(0xFF7A4500));
    }

    // The shine: radial-gradient(circle, rgba(255,255,255,.38) 0 26%, transparent 50%, 68%,
    // rgba(0,0,0,.4) 100%), measured to the box's corner as CSS does.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.7071,
          colors: [Color(0x61FFFFFF), Color(0x61FFFFFF), Color(0x00FFFFFF), Color(0x00000000), Color(0x66000000)],
          stops: [0, .26, .5, .68, 1],
        ).createShader(face),
    );

    // Ten pegs on a 104 dp circle, on the dividers.
    for (var i = 0; i < 10; i++) {
      final a = _rad(-18.0 + 36 * i);
      final p = c + Offset(104 * math.sin(a), -104 * math.cos(a));
      canvas.drawCircle(
        p + const Offset(0, 2),
        4.5,
        Paint()
          ..color = const Color(0x99000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
      canvas.drawCircle(
        p,
        4.5,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Color(0xFFFFFFFF), Color(0xFFFFE07A), Color(0xFFD98300), Color(0xFF5A3500)],
            stops: [0, .35, .75, 1],
          ).createShader(_circle(p, 4.5)),
      );
    }

    // The numbers, 84 dp out, each turned with its segment.
    for (var i = 0; i < 10; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(_rad(36.0 * i));
      _paintNumber(canvas, '${kSpin2WinWheelOrder[i]}', const Offset(0, -84));
      canvas.restore();
    }
  }

  /// The design's `.wl.num`: 33 dp white, a 4 dp dark outline, a drop shadow and a faint glow.
  static void _paintNumber(
    Canvas canvas,
    String text,
    Offset centre, {
    double size = 33,
    Color fill = const Color(0xFFFFFFFF),
    Color outline = const Color(0xCC100A28),
    List<Shadow> shadows = const [
      Shadow(color: Color(0x73000000), offset: Offset(0, 3)),
      Shadow(color: Color(0x59FFFFFF), blurRadius: 10),
    ],
  }) {
    TextPainter layout(TextStyle style) =>
        TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    final base = TextStyle(fontFamily: kSpin2WinFont, fontWeight: FontWeight.w900, fontSize: size, height: 1);
    final stroke = layout(base.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * size / 33
        ..strokeJoin = StrokeJoin.round
        ..color = outline,
      shadows: shadows,
    ));
    final fillText = layout(base.copyWith(color: fill));
    final at = centre - Offset(fillText.width / 2, fillText.height / 2);
    stroke.paint(canvas, at);
    fillText.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_FacePainter oldDelegate) => false;
}

/// The winning segment lit up once the wheel has stopped on it, as the design's `hl` layers: the
/// nine other segments dimmed, the one under the pointer filled with a pale gold light between two
/// bright edges, and its number drawn larger in pale gold. All of it outside the hub (52 dp round).
class _HighlightPainter extends CustomPainter {
  const _HighlightPainter(this.number, this.strength);

  final int number;

  /// The light's strength, 0.45 to 1 as it pulses.
  final double strength;

  static double _canvas(double deg) => (deg - 90) * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final face = _circle(c, r);
    canvas.save();
    // Keep the hub's 52 dp middle clear.
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(face)
      ..addOval(_circle(c, 52.5)));
    // The other nine segments, dimmed: conic(transparent 0-36deg, rgba(4,8,30,.5) 36-360deg) from -18deg.
    canvas.drawArc(face, _canvas(18), 324 * math.pi / 180, true, Paint()..color = const Color(0x8004081E));
    // The winner: its fill and its two bright edges, pulsing.
    final glow = Paint()..color = const Color(0x6BFFF6C8).withValues(alpha: 0.42 * strength);
    canvas.drawArc(face, _canvas(-18), 36 * math.pi / 180, true, glow);
    final edge = Paint()..color = const Color(0xFFFFF0C0).withValues(alpha: strength);
    canvas.drawArc(face, _canvas(-18), 1.8 * math.pi / 180, true, edge);
    canvas.drawArc(face, _canvas(16.2), 1.8 * math.pi / 180, true, edge);
    canvas.restore();
    // Its number, 1.3 times as large, in pale gold with a brown outline and a gold glow.
    _FacePainter._paintNumber(
      canvas,
      '$number',
      c + const Offset(0, -84),
      size: 33 * 1.3,
      fill: const Color(0xFFFFF6C8),
      outline: const Color(0xFF5A3500),
      shadows: const [
        Shadow(color: Color(0xFFFFD45A), blurRadius: 12),
        Shadow(color: Color(0xFFFFB52E), blurRadius: 26),
      ],
    );
  }

  @override
  bool shouldRepaint(_HighlightPainter oldDelegate) =>
      oldDelegate.number != number || oldDelegate.strength != strength;
}

/// The light that stays still while the face turns: a dark inner edge and a soft shine at the
/// top left.
class _LightingPainter extends CustomPainter {
  const _LightingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final face = _circle(c, r);
    canvas.save();
    canvas.clipPath(Path()..addOval(face));
    // inset 0 0 22px rgba(0,0,0,.6), inset 0 -10px 18px rgba(0,0,0,.35)
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00000000), Color(0x00000000), Color(0x8C000000)],
          stops: [0, .8, 1],
        ).createShader(face),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x00000000), Color(0x40000000)],
          stops: [0, .78, 1],
        ).createShader(face),
    );
    // radial-gradient(ellipse 62% 34% at 38% 16%, rgba(255,255,255,.38), transparent 72%)
    final rx = size.width * 0.62;
    final ry = size.height * 0.34;
    final spot = Offset(size.width * 0.38, size.height * 0.16);
    canvas.translate(spot.dx, spot.dy);
    canvas.scale(1, ry / rx);
    canvas.drawCircle(
      Offset.zero,
      rx,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x61FFFFFF), Color(0x00FFFFFF)],
          stops: [0, .72],
        ).createShader(_circle(Offset.zero, rx)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LightingPainter oldDelegate) => false;
}

/// The gold hub and the blue dome inside it, with what the dome shows.
class _Hub extends StatelessWidget {
  const _Hub({required this.dome, required this.reveal, required this.reel});

  final Spin2WinDome dome;

  /// 0 to 1: see [Spin2WinWheel.domeReveal].
  final double reveal;

  /// 0 to 1: see [Spin2WinWheel.reel].
  final double reel;

  /// The number's pop (the design's `pop`: from 20% to full size, overshooting, after 0.3 s of the
  /// 0.85 s reveal) and the badge's drop (`shrink`: from 2.5 times its size, 34 dp up, settling).
  static const Cubic _popCurve = Cubic(.2, 1.6, .4, 1);
  static const Cubic _dropCurve = Cubic(.3, 1.35, .5, 1);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            Color(0xFFFFF0C0), Color(0xFFFFB52E), Color(0xFF8A5000), Color(0xFFFFD45A), //
            Color(0xFFFFF0C0), Color(0xFFD98300), Color(0xFFFFF0C0),
          ],
          stops: [0, .2, .4, .6, .75, .9, 1],
          transform: GradientRotation(-math.pi / 2),
        ),
        boxShadow: const [
          BoxShadow(color: kS2wGoldUnder, offset: Offset(0, 6)),
          BoxShadow(color: Color(0xBF000000), offset: Offset(0, 10), blurRadius: 20),
        ],
      ),
      child: Center(
        child: Container(
          key: const ValueKey('spin2win-dome'),
          width: 94,
          height: 94,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(0, -0.4),
              radius: 0.86,
              colors: [Color(0xFF2A5CB8), Color(0xFF102A64), Color(0xFF050D24)],
              stops: [0, .45, 1],
            ),
            boxShadow: [
              BoxShadow(color: Color(0xBF00E5FF), blurRadius: 18),
              BoxShadow(color: kS2wCyan, spreadRadius: 2),
            ],
          ),
          child: ClipOval(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The inner shadow at the bottom of the dome.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x2600E5FF), Color(0x00000000), Color(0x00000000), Color(0x99000000)],
                        stops: [0, .2, .7, 1],
                      ),
                    ),
                  ),
                ),
                _domeContent(),
                // The shine at the top: 62 x 28 dp at (16, 5).
                const Positioned(
                  left: 16,
                  top: 5,
                  width: 62,
                  height: 28,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.elliptical(31, 14)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x6BFFFFFF), Color(0x00FFFFFF)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _domeContent() {
    switch (dome) {
      case Spin2WinDomeShuffling(:final bonusMultiplier):
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'BONUS',
              style: TextStyle(
                fontFamily: kSpin2WinFont,
                fontWeight: FontWeight.w900,
                fontSize: 9,
                height: 10 / 9,
                letterSpacing: 2.5,
                color: kS2wCyan,
                shadows: [Shadow(color: Color(0xCC00E5FF), blurRadius: 6)],
              ),
            ),
            // The design's `reel`: up and down 2 dp, a little larger and smaller, 8 times a second.
            Transform.translate(
              offset: Offset(0, 2 * math.cos(reel * 2 * math.pi) * -1),
              child: Transform.scale(
                scale: 1.005 + 0.035 * math.cos(reel * 2 * math.pi),
                child: Spin2WinOutlinedText(
                  spin2WinBonusText(bonusMultiplier),
                  key: const ValueKey('spin2win-dome-bonus'),
                  size: 36,
                  height: 40 / 36,
                  color: spin2WinBonusShades(bonusMultiplier).light,
                  stroke: const Color(0xD90A061E),
                ),
              ),
            ),
          ],
        );
      case Spin2WinDomeLanded(:final number, :final bonusMultiplier):
        final shades = spin2WinBonusShades(bonusMultiplier);
        // The number pops the moment the wheel reaches it: full size in 0.22 s (Hasan, 2026-10-25;
        // it used to wait 0.3 s and grow for 0.55 s), the badge drops in over 0.35 s.
        final popT = (reveal * 0.85 / 0.22).clamp(0.0, 1.0);
        final pop = _popCurve.transform(popT);
        final drop = _dropCurve.transform((reveal * 0.85 / 0.35).clamp(0.0, 1.0));
        Widget badge(Widget child) => Transform.translate(
              offset: Offset(0, -34 * (1 - drop)),
              child: Transform.scale(scale: 1 + 1.5 * (1 - drop), child: child),
            );
        // A little lower than before, clear of the dome's top (Hasan, 2026-10-25).
        return Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: (popT * 3).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.5 + 0.5 * pop,
                  child: Spin2WinOutlinedText(
                    '$number',
                    key: const ValueKey('spin2win-dome-number'),
                    size: 60,
                    height: 52 / 60,
                    color: kS2wGold,
                    stroke: const Color(0xFF5A3500),
                    strokeWidth: 4,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              badge(_BonusCapsule(bonusMultiplier: bonusMultiplier, shades: shades)),
            ],
          ),
        );
    }
  }
}

/// The landed bonus under the number (redesigned at Hasan's request, 2026-10-25): a dark glass
/// capsule tinted and ringed in the bonus's colour, glowing softly, with a shine on top and the
/// bonus in white.
class _BonusCapsule extends StatelessWidget {
  const _BonusCapsule({required this.bonusMultiplier, required this.shades});

  final int bonusMultiplier;
  final Spin2WinBonusShades shades;

  @override
  Widget build(BuildContext context) {
    final none = bonusMultiplier <= 1;
    return Container(
      height: 18,
      constraints: const BoxConstraints(minWidth: 38),
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [shades.light, shades.dark],
        ),
        boxShadow: [
          const BoxShadow(color: Color(0x99000000), offset: Offset(0, 2), blurRadius: 3),
          BoxShadow(color: shades.light.withValues(alpha: none ? 0.25 : 0.6), blurRadius: 8),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(shades.dark, const Color(0xFF0A1636), 0.25)!, const Color(0xFF0A1636)],
          ),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
          ),
        ),
        // widthFactor 1: the capsule hugs its word instead of filling the dome.
        child: Center(
          widthFactor: 1,
          child: Spin2WinCapsCentred(
            size: 12,
            child: Text(
              spin2WinBonusText(bonusMultiplier),
              style: TextStyle(
                fontFamily: kSpin2WinFont,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                height: 1,
                letterSpacing: 0.8,
                color: const Color(0xFFFFFFFF),
                shadows: [Shadow(color: shades.light.withValues(alpha: none ? 0.3 : 0.9), blurRadius: 6)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
