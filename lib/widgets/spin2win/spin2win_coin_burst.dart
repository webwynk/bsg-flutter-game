// The Spin2Win coin burst: when a winner's number is revealed, gold coins burst out of the wheel's
// hub, fly up and out, then fall away, with two bright rings flashing at the hub (the reference
// design's `coinflash` and `flycoin`, the same 80 coins from the same seed).
//
// The design plays it over about 3 s; here it is fitted into the 1.5 s between the reveal and the
// win popup (Hasan's timing, 2026-10-24): out in the first 0.75 s, falling and fading by 1.5 s.
// It is shown only for a win of [kSpin2WinCoinBurstMinWin] or more (Hasan, 2026-10-25); a smaller
// win keeps the same 1.5 s before its popup, without the coins.
//
// Plays once each time it is built with a new [Spin2WinCoinBurst.burstKey]. Nothing here takes a
// tap.
//
// Belongs to Spin2Win only.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'spin2win_palette.dart';

/// The smallest win that gets the coin burst.
const int kSpin2WinCoinBurstMinWin = 900;

/// Whether a win of [payout] gets the coin burst.
bool spin2WinShowsCoinBurst(int payout) => payout >= kSpin2WinCoinBurstMinWin;

/// Where the coins come from, in the phone design's space: the middle of the wheel's hub
/// (10 + 24 + 134 across, 6 + 40 + 6 + 8 + 134 down).
const Offset kSpin2WinHubCentre = Offset(168, 194);

/// One coin's flight, worked out once from the design's seeded numbers.
class _Coin {
  const _Coin({
    required this.size,
    required this.burst,
    required this.fall,
    required this.spinOut,
    required this.spinFall,
    required this.delay,
    required this.flip,
  });

  final double size;

  /// Where it is at the top of its burst, and at the end of its fall, from the hub.
  final Offset burst;
  final Offset fall;

  /// Its turn at those two moments, in degrees.
  final double spinOut;
  final double spinFall;

  /// Its start after the burst begins, 0 to 0.28 of the design's second (halved here).
  final double delay;

  /// How long one of its flips takes, in seconds.
  final double flip;
}

/// The design's 80 coins (`COINS`, seed 11).
final List<_Coin> _coins = () {
  var seed = 11;
  double rnd() {
    seed = (seed * 16807) % 2147483647;
    return seed / 2147483647;
  }

  final coins = <_Coin>[];
  for (var i = 0; i < 80; i++) {
    final ang = (-90 + (rnd() * 260 - 130)) * math.pi / 180;
    final sp = 170 + rnd() * 230;
    const g = 480.0;
    final vx = sp * math.cos(ang);
    final vy = sp * math.sin(ang);
    final z = (22 * (0.7 + rnd() * 0.5)).roundToDouble();
    const pt = 0.7, ft = 2.0;
    final burst = Offset(vx * pt, vy * pt + 0.5 * g * pt * pt);
    final fall = Offset(vx * ft, vy * ft + 0.5 * g * ft * ft);
    final r1 = ((rnd() - 0.5) * 400).roundToDouble();
    final r2 = ((rnd() - 0.5) * 1200).roundToDouble();
    final d = (rnd() * 280).roundToDouble();
    final flip = 0.25 + rnd() * 0.2;
    coins.add(_Coin(size: z, burst: burst, fall: fall, spinOut: r1, spinFall: r2, delay: d / 1000, flip: flip));
  }
  return coins;
}();

class Spin2WinCoinBurst extends StatefulWidget {
  const Spin2WinCoinBurst({super.key, required this.burstKey});

  /// The round being celebrated; a new key plays the burst again.
  final String burstKey;

  /// The whole burst.
  static const Duration duration = Duration(milliseconds: 1500);

  @override
  State<Spin2WinCoinBurst> createState() => _Spin2WinCoinBurstState();
}

class _Spin2WinCoinBurstState extends State<Spin2WinCoinBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: Spin2WinCoinBurst.duration)..forward();

  @override
  void didUpdateWidget(Spin2WinCoinBurst old) {
    super.didUpdateWidget(old);
    if (old.burstKey != widget.burstKey) _t.forward(from: 0);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) => CustomPaint(
          key: const ValueKey('spin2win-coin-burst'),
          painter: _BurstPainter(_t.value * Spin2WinCoinBurst.duration.inMilliseconds / 1000),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.seconds);

  /// Time since the burst began.
  final double seconds;

  static const Cubic _out = Cubic(.2, .8, .35, 1);
  static const Cubic _drop = Cubic(.55, 0, .9, .55);
  static const Cubic _fade = Cubic(.8, 0, 1, 1);

  /// The burst out takes this long (the design's 0.75 s, halved) and the fall starts here and
  /// takes the rest (the design's 1.45 s and 1.35 s, fitted into 1.5 s).
  static const double _outTime = 0.4;
  static const double _fallStart = 0.72;
  static const double _fallTime = 0.66;

  @override
  void paint(Canvas canvas, Size size) {
    const hub = kSpin2WinHubCentre;

    // Two rings flash at the hub, the second 0.18 s later (`coinflash`: 0.6 s, 20% to 240%).
    for (final start in const [0.0, 0.18]) {
      final p = ((seconds - start) / 0.6).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final r = 35 * (0.2 + 2.2 * Curves.easeOut.transform(p));
      final a = 1 - p;
      canvas.drawCircle(
        hub,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFFFE07A).withValues(alpha: a),
      );
      canvas.drawCircle(
        hub,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = kS2wGold.withValues(alpha: 0.6 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    for (final c in _coins) {
      final delay = c.delay / 2;
      final Offset at;
      double spin;
      double scale;
      double opacity;
      final tOut = (seconds - delay) / _outTime;
      if (tOut <= 0) continue;
      final tFall = (seconds - _fallStart - delay) / _fallTime;
      if (tFall <= 0) {
        final p = _out.transform(tOut.clamp(0.0, 1.0));
        at = hub + c.burst * p;
        spin = c.spinOut * p;
        scale = 0.3 + 0.85 * p;
        opacity = (tOut / 0.2).clamp(0.0, 1.0);
      } else {
        final p = tFall.clamp(0.0, 1.0);
        final move = _drop.transform(p);
        at = hub + c.burst + (c.fall - c.burst) * move;
        spin = c.spinOut + (c.spinFall - c.spinOut) * move;
        scale = 1.15 - 0.35 * move;
        opacity = 1 - _fade.transform(p);
      }
      if (opacity <= 0) continue;
      // The flip (`coinFlip`): squeezed sideways to 18% and back.
      final flipPhase = (seconds / c.flip) % 2;
      final squeeze = 1 - 0.82 * Curves.easeInOut.transform(flipPhase < 1 ? flipPhase : 2 - flipPhase);
      _paintCoin(canvas, at, c.size * scale, spin, squeeze, opacity);
    }
  }

  /// A gold coin with a "$" on it (`.flycoin`).
  static void _paintCoin(Canvas canvas, Offset at, double size, double spinDeg, double squeeze, double opacity) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(spinDeg * math.pi / 180);
    canvas.scale(squeeze, 1);
    final r = size / 2;
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(const Offset(0, 2), r, Paint()..color = const Color(0xFF5A3500).withValues(alpha: opacity));
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [
            const Color(0xFFFFF6C8).withValues(alpha: opacity),
            const Color(0xFFFFB52E).withValues(alpha: opacity),
            const Color(0xFFB06A00).withValues(alpha: opacity),
          ],
          stops: const [0, .55, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset.zero,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFF0C0).withValues(alpha: opacity),
    );
    final label = TextPainter(
      text: TextSpan(
        text: r'$',
        style: TextStyle(
          fontFamily: kSpin2WinDigitsFont,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.62,
          height: 1,
          color: const Color(0xFF8A4A00).withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(-label.width / 2, -label.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => oldDelegate.seconds != seconds;
}
