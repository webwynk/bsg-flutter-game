// lucky_card_wheel.dart — the Lucky Card wheel.
//
// The DESIGN is the user's wheel v3 (game palette, 3D, no stand), unchanged: a gold
// bezel with warm bulbs and red and green gems; an outer rim of J K Q on red and
// dark green with gold 3D letters; an inner rim of suits on cream; a hub that is a
// mystery gift box and pops to the result; both rims start together, the outer one
// stops at 3 s and the inner one at 5 s. Every painter, the palette, the geometry,
// the spin curve and the timings are the user's. The original is kept in
// docs/lucky_card/user_wheel_v3_original.dart.txt.
//
// The LOGIC was rewritten for the game (spec §7.5, §17S):
//   * `spin` takes the two segments and the bonus the SERVER's result gives, with no
//     default and no random fallback; a value out of range throws. The wheel never
//     decides anything.
//   * The hub is not a button: tapping it does nothing.
//   * `onOuterLand` fires when the outer rim stops (3 s: the first "ding") and
//     `onInnerLand` when the inner rim stops (5 s: both rims have landed, the card
//     is shown; the game's reveal is timed from this moment).
//   * The bonus reads "N", "2X" ... "10X".
//   * The size comes from the caller (the layout), not from a fixed number.
//   * Nothing public is named like anything in Triple Chance's wheel.
//
// The wheel needs no pictures and no packages. Its fonts, Oswald and DMSans at
// weight 700, are the ones already in pubspec.yaml.
//
// Belongs to Lucky Card only.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/lucky_card_models.dart';
import 'lucky_card_wheel_slots.dart';

/// What the wheel shows once both rims have stopped: the card its two segments
/// spell out, and the bonus.
class LuckyCardWheelOutcome {
  const LuckyCardWheelOutcome(this.card, this.bonus);

  final LuckyCard card;

  /// 1 shows "N" (no bonus), 2 to 10 show "2X" to "10X".
  final int bonus;

  String get rank => card.rank.dbValue;
  LuckyCardSuit get suit => card.suit;
  bool get hasBonus => bonus > 1;

  @override
  String toString() => '${card.shortName}${hasBonus ? ' bonus ${bonus}X' : ''}';
}

/// Bonus text: 1 (or less) is "N", otherwise "2X" ... "10X".
String luckyCardWheelBonusLabel(int v) => v <= 1 ? 'N' : '${v}X';

const double _kSeg = 2 * math.pi / kLuckyCardWheelSegments;

// Radii as fractions of the wheel radius.
const double _rBezelIn = 0.82;
const double _rBulbs = 0.91;
const double _rOuterIn = 0.53;
const double _rInnerIn = 0.28;
const double _rHub = 0.28; // centre hub size (was 0.33)

// ─────────────────────────────────────────────────────────────────────────────
// Palette
// ─────────────────────────────────────────────────────────────────────────────

class _WheelColors {
  const _WheelColors._();
  // Brand
  static const red = Color(0xFFDD020C);
  static const darkRed = Color(0xFF880103);
  static const green = Color(0xFF01C722);
  static const darkGreen = Color(0xFF01480A);
  static const orange = Color(0xFFE37E01);
  static const cream = Color(0xFFFFFD9D);
  // Derived shades for depth
  static const deepRed = Color(0xFF4A0002);
  static const deepGreen = Color(0xFF012A06);
  static const bronze = Color(0xFF8A4A00);
  static const brown = Color(0xFF4A2200);
  static const honey = Color(0xFFF7C25A);
}

const List<Color> _kGoldSweep = [
  _WheelColors.bronze,
  _WheelColors.cream,
  _WheelColors.orange,
  _WheelColors.cream,
  _WheelColors.bronze,
  _WheelColors.honey,
  _WheelColors.bronze,
];

/// Font for rim letters, the result and the "?" on the gift.
/// Bundle Oswald in pubspec.yaml (see setup notes) so it is ready on the
/// first frame — the rims are painted once and cached.
const String _kWheelFont = 'Oswald';

/// Font for the bonus ("N", "2x" …). Bundle DM Sans in pubspec.yaml.
const String _kBonusFont = 'DMSans';

/// Gentle ramp-up, long smooth slow-down (no jump at the start).
const Curve _kSpinCurve = Cubic(0.25, 0.1, 0.15, 1.0);

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class LuckyCardWheel extends StatefulWidget {
  const LuckyCardWheel({
    super.key,
    required this.size,
    this.outerSpinDuration = const Duration(seconds: 3),
    this.innerSpinDuration = const Duration(seconds: 5),
    this.innerClockwise = false,
    this.onSpinStart,
    this.onOuterLand,
    this.onInnerLand,
  });

  /// Wheel diameter. Widget height is size × 1.06 (room for the pointer).
  final double size;

  /// Both rims start together; outer stops after this.
  final Duration outerSpinDuration;

  /// Inner rim stops after this (measured from the same start).
  final Duration innerSpinDuration;

  /// false = inner rim turns counter-clockwise.
  final bool innerClockwise;

  final VoidCallback? onSpinStart;

  /// The outer rim (the rank) has stopped: the first "ding".
  final VoidCallback? onOuterLand;

  /// Both rims have stopped and the card is shown. The reveal is timed from here.
  final ValueChanged<LuckyCardWheelOutcome>? onInnerLand;

  @override
  State<LuckyCardWheel> createState() => LuckyCardWheelState();
}

enum _LightMode { idle, chase, blink }

class LuckyCardWheelState extends State<LuckyCardWheel>
    with TickerProviderStateMixin {
  late final AnimationController _outerCtrl;
  late final AnimationController _innerCtrl;
  late final AnimationController _hubCtrl;
  late final AnimationController _smokeCtrl;
  int _pendingBonus = 1;

  Animation<double> _outerRot = const AlwaysStoppedAnimation(0);
  Animation<double> _innerRot = const AlwaysStoppedAnimation(0);
  double _outerAngle = 0;
  double _innerAngle = 0;

  final ValueNotifier<(_LightMode, int)> _lights =
      ValueNotifier((_LightMode.idle, 0));
  Timer? _lightTimer;
  Timer? _idleLightsTimer;

  bool _spinning = false;
  LuckyCardWheelOutcome? _result; // null = show mystery gift

  /// Identifies the current spin; a spin that is no longer the latest (the wheel was
  /// removed, or another began) calls nothing back.
  int _spinGeneration = 0;

  bool get isSpinning => _spinning;
  LuckyCardWheelOutcome? get result => _result;

  /// The segments of the two rims that are under the pointer at the moment (0 to
  /// 11, clockwise from the top), read from the rims' resting angles.
  @visibleForTesting
  (int outer, int inner) get restingSegments =>
      (_segmentUnder(_outerAngle), _segmentUnder(_innerAngle));

  /// The rims' current turning angles in radians (outer, inner): the outer one
  /// turns clockwise (growing), the inner one counter-clockwise (shrinking).
  @visibleForTesting
  (double outer, double inner) get currentAngles => (_outerRot.value, _innerRot.value);

  static int _segmentUnder(double angle) {
    final i = (-angle / _kSeg).round() % kLuckyCardWheelSegments;
    return (i + kLuckyCardWheelSegments) % kLuckyCardWheelSegments;
  }

  @override
  void initState() {
    super.initState();
    _outerCtrl =
        AnimationController(vsync: this, duration: widget.outerSpinDuration);
    _innerCtrl =
        AnimationController(vsync: this, duration: widget.innerSpinDuration);
    _smokeCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4));
    _hubCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..value = 1.0;
  }

  @override
  void dispose() {
    _lightTimer?.cancel();
    _idleLightsTimer?.cancel();
    _outerCtrl.dispose();
    _innerCtrl.dispose();
    _hubCtrl.dispose();
    _smokeCtrl.dispose();
    _lights.dispose();
    super.dispose();
  }

  void _setLights(_LightMode mode) {
    _lightTimer?.cancel();
    _lights.value = (mode, 0);
    if (mode == _LightMode.idle) return;
    final period = Duration(milliseconds: mode == _LightMode.chase ? 100 : 200);
    _lightTimer = Timer.periodic(period, (_) {
      final (m, p) = _lights.value;
      _lights.value = (m, p + 1);
    });
  }

  double _targetAngle(double current, int index,
      {required bool clockwise, required int spins}) {
    const full = 2 * math.pi;
    final desired = (-index * _kSeg) % full;
    final cur = current % full;
    if (clockwise) {
      return current + spins * full + (desired - cur) % full;
    }
    return current - spins * full - (cur - desired) % full;
  }

  /// Turns per spin scale with duration so both rims move at a similar speed.
  int _spinsFor(Duration d) => math.max(2, (d.inMilliseconds / 1000 * 1.4).round());

  /// Spins the wheel to the result the SERVER gave.
  ///
  /// [outerIndex] and [innerIndex] are the segments (0 to 11, clockwise from the
  /// top) that end under the pointer: they carry the rank and the suit. [bonus]
  /// is 1 for "N" (no bonus) up to 10 for "10X". There is no default for any of
  /// them: the wheel never invents an outcome. A value out of range throws, even
  /// if a spin is already running.
  ///
  /// Returns null if a spin is already running, or if the wheel was removed before
  /// it finished. A bad value throws at the call itself (not later, through the
  /// returned future).
  Future<LuckyCardWheelOutcome?> spin({
    required int outerIndex,
    required int innerIndex,
    required int bonus,
  }) {
    if (outerIndex < 0 || outerIndex >= kLuckyCardWheelSegments) {
      throw ArgumentError.value(outerIndex, 'outerIndex', 'must be 0 to 11');
    }
    if (innerIndex < 0 || innerIndex >= kLuckyCardWheelSegments) {
      throw ArgumentError.value(innerIndex, 'innerIndex', 'must be 0 to 11');
    }
    if (bonus < 1 || bonus > 10) {
      throw ArgumentError.value(bonus, 'bonus', 'must be 1 (N) to 10 (10X)');
    }
    return _spin(outerIndex, innerIndex, bonus);
  }

  Future<LuckyCardWheelOutcome?> _spin(int outerIndex, int innerIndex, int bonus) async {
    if (_spinning) return null;
    final generation = ++_spinGeneration;
    final oi = outerIndex;
    final ii = innerIndex;

    _idleLightsTimer?.cancel();
    setState(() {
      _spinning = true;
      _result = null;
    });
    _hubCtrl.value = 1.0;

    _pendingBonus = bonus;
    _smokeCtrl.repeat();
    _setLights(_LightMode.chase);
    widget.onSpinStart?.call();

    final outerEnd = _targetAngle(_outerAngle, oi,
        clockwise: true, spins: _spinsFor(widget.outerSpinDuration));
    final innerEnd = _targetAngle(_innerAngle, ii,
        clockwise: widget.innerClockwise,
        spins: _spinsFor(widget.innerSpinDuration));

    _outerRot = Tween(begin: _outerAngle, end: outerEnd)
        .animate(CurvedAnimation(parent: _outerCtrl, curve: _kSpinCurve));
    _innerRot = Tween(begin: _innerAngle, end: innerEnd)
        .animate(CurvedAnimation(parent: _innerCtrl, curve: _kSpinCurve));
    _outerCtrl.duration = widget.outerSpinDuration;
    _innerCtrl.duration = widget.innerSpinDuration;

    // Both start on the same frame. The outer one tells the game when it stops.
    final outerDone = _outerCtrl.forward(from: 0).then((_) {
      if (mounted && generation == _spinGeneration) widget.onOuterLand?.call();
    });
    final innerDone = _innerCtrl.forward(from: 0);
    await Future.wait<void>([outerDone, innerDone]);
    if (!mounted || generation != _spinGeneration) return null;
    _outerAngle = outerEnd % (2 * math.pi);
    _innerAngle = innerEnd % (2 * math.pi);

    final res = LuckyCardWheelOutcome(luckyCardAtWheelStop(oi, ii), _pendingBonus);
    setState(() {
      _spinning = false;
      _result = res;
    });
    // Smoke blows away while the result pops in, then stops ticking.
    _hubCtrl.forward(from: 0).then((_) {
      if (mounted && !_spinning) _smokeCtrl.stop();
    });
    HapticFeedback.mediumImpact();
    _setLights(_LightMode.blink);
    _idleLightsTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted && !_spinning) _setLights(_LightMode.idle);
    });
    widget.onInnerLand?.call(res);
    return res;
  }

  /// Spins to [card], on the segments [luckyCardWheelStopFor] gives for this
  /// round: the same on every phone in the same round.
  Future<LuckyCardWheelOutcome?> spinTo({
    required LuckyCard card,
    required int roundNumber,
    required int bonus,
  }) {
    final stop = luckyCardWheelStopFor(card, roundNumber);
    return spin(outerIndex: stop.outerIndex, innerIndex: stop.innerIndex, bonus: bonus);
  }

  /// The hub is a display only: it is not a button.
  Widget _buildHub(double size) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(colors: _kGoldSweep),
        boxShadow: [
          BoxShadow(
            color: const Color(0xAA000000),
            blurRadius: size * 0.12,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(size * 0.02),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _WheelColors.brown,
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const RepaintBoundary(
                child: CustomPaint(painter: _HubBackgroundPainter()),
              ),
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation:
                      Listenable.merge([_hubCtrl, _smokeCtrl, _innerCtrl]),
                  builder: (_, __) => CustomPaint(
                    painter: _HubFxPainter(
                      result: _result,
                      spinning: _spinning,
                      phase: _smokeCtrl.value * 2 * math.pi,
                      pop: _hubCtrl.value,
                      innerProgress: _innerCtrl.value,
                      bonusText: luckyCardWheelBonusLabel(_pendingBonus),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rotating(Listenable anim, double Function() angle,
      CustomPainter painter, double d) {
    return AnimatedBuilder(
      animation: anim,
      // Painted once, cached; each frame only rotates the cached layer.
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(d),
          painter: painter,
          isComplex: true,
          willChange: false,
        ),
      ),
      builder: (_, child) => Transform.rotate(angle: angle(), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.size;
    final topPad = d * 0.06;
    final pw = d * 0.12;
    final ph = topPad + d * 0.1;

    return SizedBox(
      width: d,
      height: topPad + d,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: topPad,
            left: 0,
            width: d,
            height: d,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                        painter: _BezelPainter(), isComplex: true),
                  ),
                ),
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _BulbsPainter(_lights)),
                  ),
                ),
                _rotating(
                    _outerCtrl, () => _outerRot.value, _OuterRimPainter(), d),
                _rotating(
                    _innerCtrl, () => _innerRot.value, _InnerRimPainter(), d),
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(painter: _OverlayPainter(_hubCtrl)),
                    ),
                  ),
                ),
                // The hub's DIAMETER is _rHub of the wheel's diameter, so its radius is
                // _rHub of the wheel radius, flush with the inner rim's inner edge. (The
                // supplied code doubled it, which made the hub cover the whole inner
                // rim: the user chose the fitted hub on 2026-10-06, spec §17T.)
                _buildHub(d * _rHub),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: (d - pw) / 2,
            width: pw,
            height: ph,
            child: IgnorePointer(
              child: CustomPaint(painter: _PointerPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bezel (static) + bulbs (animated, cheap)
// ─────────────────────────────────────────────────────────────────────────────

class _BezelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Drop shadow + warm glow
    canvas.drawCircle(
      c.translate(0, r * 0.05),
      r * 0.98,
      Paint()
        ..color = const Color(0xAA000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0x66E37E01)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );

    // Gold ring
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(rect)
      ..addOval(Rect.fromCircle(center: c, radius: r * _rBezelIn));
    canvas.drawPath(
      ring,
      Paint()
        ..shader = const SweepGradient(colors: _kGoldSweep).createShader(rect),
    );
    // Bevel: dark lip, bright crown, dark outer edge
    canvas.drawPath(
      ring,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xAA2A1000),
            Color(0x00000000),
            Color(0x55FFFFFF),
            Color(0x00000000),
            Color(0xBB2A1000),
          ],
          stops: [_rBezelIn, _rBezelIn + 0.035, 0.91, 0.965, 1.0],
        ).createShader(rect),
    );
    // Recessed bulb track
    canvas.drawCircle(
      c,
      r * _rBulbs,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.075
        ..color = const Color(0x55000000),
    );
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _WheelColors.brown,
    );

    // Gems: red at 3/6/9 o'clock, green on diagonals (12 o'clock = pointer)
    for (var k = 1; k < 8; k++) {
      final a = -math.pi / 2 + k * math.pi / 4;
      final p = c + Offset(math.cos(a), math.sin(a)) * (r * _rBulbs);
      final red = k.isEven;
      _drawGem(
        canvas,
        p,
        r * (red ? 0.055 : 0.045),
        red ? _WheelColors.red : _WheelColors.green,
        red ? _WheelColors.darkRed : _WheelColors.darkGreen,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BulbsPainter extends CustomPainter {
  _BulbsPainter(this.lights) : super(repaint: lights);
  final ValueNotifier<(_LightMode, int)> lights;
  static const int slots = 32; // every 4th slot is a gem

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final (mode, phase) = lights.value;
    var n = 0;
    for (var i = 0; i < slots; i++) {
      if (i % 4 == 0) continue;
      final a = -math.pi / 2 + i * 2 * math.pi / slots;
      final p = c + Offset(math.cos(a), math.sin(a)) * (r * _rBulbs);
      final on = switch (mode) {
        _LightMode.idle => true,
        _LightMode.chase => (n - phase) % 3 == 0,
        _LightMode.blink => phase.isEven,
      };
      _drawBulb(canvas, p, r * 0.034, on);
      n++;
    }
  }

  @override
  bool shouldRepaint(covariant _BulbsPainter old) => false;
}

/// Bulb with a gradient halo (no blur → cheap to repaint).
void _drawBulb(Canvas canvas, Offset p, double r, bool on) {
  canvas.drawCircle(p, r * 1.35, Paint()..color = _WheelColors.bronze);
  if (on) {
    canvas.drawCircle(
      p,
      r * 2.4,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xCCFFFD9D), Color(0x00FFFD9D)],
        ).createShader(Rect.fromCircle(center: p, radius: r * 2.4)),
    );
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, _WheelColors.cream, _WheelColors.honey],
          stops: [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
  } else {
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFC98A2E), _WheelColors.bronze, _WheelColors.brown],
          stops: [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
  }
}

/// Faceted diamond-shaped gem in a gold setting.
void _drawGem(Canvas canvas, Offset p, double s, Color base, Color dark) {
  Path diamond(double k) => Path()
    ..moveTo(p.dx, p.dy - k)
    ..lineTo(p.dx + k, p.dy)
    ..lineTo(p.dx, p.dy + k)
    ..lineTo(p.dx - k, p.dy)
    ..close();

  final frame = diamond(s * 1.35);
  canvas.drawPath(
    frame,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_WheelColors.cream, _WheelColors.orange, _WheelColors.bronze],
      ).createShader(frame.getBounds()),
  );
  canvas.drawPath(
    frame,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.12
      ..color = _WheelColors.brown,
  );

  final light = Color.lerp(base, Colors.white, 0.45)!;
  final top = p.translate(0, -s), right = p.translate(s, 0);
  final bottom = p.translate(0, s), left = p.translate(-s, 0);
  void facet(Offset a, Offset b, Color col) {
    canvas.drawPath(
      Path()
        ..moveTo(p.dx, p.dy)
        ..lineTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..close(),
      Paint()..color = col,
    );
  }

  facet(left, top, light);
  facet(top, right, base);
  facet(right, bottom, dark);
  facet(bottom, left, Color.lerp(base, dark, 0.5)!);
  canvas.drawCircle(p.translate(-s * 0.3, -s * 0.3), s * 0.16,
      Paint()..color = const Color(0xDDFFFFFF));
}

// ─────────────────────────────────────────────────────────────────────────────
// Rims
// ─────────────────────────────────────────────────────────────────────────────

void _paintBand(
  Canvas canvas,
  Offset c,
  double r,
  double rIn,
  double rOut,
  (Color, Color) Function(int) colorsOf, // (light, dark)
) {
  final outerRect = Rect.fromCircle(center: c, radius: rOut);
  final innerRect = Rect.fromCircle(center: c, radius: rIn);
  final k = rIn / rOut;

  for (var i = 0; i < kLuckyCardWheelSegments; i++) {
    final start = -math.pi / 2 + i * _kSeg - _kSeg / 2;
    final path = Path()
      ..arcTo(outerRect, start, _kSeg, true)
      ..arcTo(innerRect, start + _kSeg, -_kSeg, false)
      ..close();
    final (light, dark) = colorsOf(i);
    // Pillow shading: dark edges, light middle → raised 3D look.
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [dark, light, light, dark],
          stops: [k, k + (1 - k) * 0.35, k + (1 - k) * 0.7, 1.0],
        ).createShader(outerRect),
    );
  }

  // Gold dividers with a dark shadow line for depth.
  final shadow = Paint()
    ..color = const Color(0x66000000)
    ..strokeWidth = r * 0.012;
  final gold = Paint()
    ..color = _WheelColors.orange
    ..strokeWidth = r * 0.007;
  for (var i = 0; i < kLuckyCardWheelSegments; i++) {
    final a = -math.pi / 2 + i * _kSeg - _kSeg / 2;
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(c + dir * rIn, c + dir * rOut, shadow);
    canvas.drawLine(c + dir * rIn, c + dir * rOut, gold);
  }
}

void _paintLetter(Canvas canvas, String text, double fs) {
  final base = TextStyle(
    fontSize: fs,
    fontWeight: FontWeight.w700,
    fontFamily: _kWheelFont,
    letterSpacing: 0,
    height: 1.0,
  );
  TextPainter layout(TextStyle s) => TextPainter(
        text: TextSpan(text: text, style: s),
        textDirection: TextDirection.ltr,
      )..layout();

  final probe = layout(base);
  final w = probe.width, h = probe.height;
  final rect = Rect.fromLTWH(-w / 2, -h / 2, w, h);

  // No outline — gradient fill with a soft drop shadow for depth.
  final fill = layout(base.copyWith(
    foreground: Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, _WheelColors.cream, _WheelColors.honey, _WheelColors.orange],
        stops: [0.0, 0.3, 0.65, 1.0],
      ).createShader(rect),
    shadows: [
      Shadow(
        color: const Color(0x99000000),
        blurRadius: fs * 0.08,
        offset: Offset(0, fs * 0.05),
      ),
    ],
  ));
  fill.paint(canvas, Offset(-fill.width / 2, -fill.height / 2));
}

class _OuterRimPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rIn = r * _rOuterIn, rOut = r * _rBezelIn;
    _paintBand(
      canvas,
      c,
      r,
      rIn,
      rOut,
      (i) => i.isEven
          ? (const Color(0xFF02621A), _WheelColors.deepGreen) // dark green
          : (_WheelColors.red, _WheelColors.darkRed), // red
    );
    final mid = (rIn + rOut) / 2;
    for (var i = 0; i < kLuckyCardWheelSegments; i++) {
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(i * _kSeg)
        ..translate(0, -mid);
      _paintLetter(canvas, kLuckyCardWheelRanks[i % 3], r * 0.17);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InnerRimPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rIn = r * _rInnerIn, rOut = r * _rOuterIn;
    _paintBand(
      canvas,
      c,
      r,
      rIn,
      rOut,
      (i) => i.isEven
          ? (_WheelColors.cream, _WheelColors.honey)
          : (const Color(0xFFFFE08A), const Color(0xFFE39A2A)),
    );
    final mid = (rIn + rOut) / 2;
    for (var i = 0; i < kLuckyCardWheelSegments; i++) {
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(i * _kSeg)
        ..translate(0, -mid);
      _paintSuit(canvas, kLuckyCardWheelSuits[i % 4], Offset.zero, r * 0.065);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Static: gold rings between rims, glass sheen, win pulse on top segment.
class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.pulse) : super(repaint: pulse);
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final face = Rect.fromCircle(center: c, radius: r * _rBezelIn);

    // Inner shadow at the bezel lip (wheel face sits recessed)
    canvas.drawCircle(
      c,
      r * _rBezelIn,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00000000), Color(0x00000000), Color(0x77000000)],
          stops: [0.0, 0.86, 1.0],
        ).createShader(face),
    );
    // Soft sheen
    canvas.drawCircle(
      c,
      r * _rBezelIn,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.45, -0.55),
          radius: 0.8,
          colors: [Color(0x22FFFFFF), Color(0x00FFFFFF)],
        ).createShader(face),
    );

    _goldRing(canvas, c, r * _rOuterIn, r * 0.03);
    _goldRing(canvas, c, r * _rBezelIn, r * 0.035);

    // Selection window: always marks the segment under the pointer on
    // both rims, and flashes brighter when a result lands.
    final win = pulse.value < 1 ? 1 - pulse.value : 0.0;
    _selectWindow(canvas, c, r, r * (_rOuterIn + 0.012),
        r * (_rBezelIn - 0.014), win);
    _selectWindow(canvas, c, r, r * (_rInnerIn + 0.01),
        r * (_rOuterIn - 0.012), win);
  }

  /// Glowing gold frame + light wash over the top segment between [rIn]/[rOut].
  void _selectWindow(Canvas canvas, Offset c, double r, double rIn,
      double rOut, double win) {
    const inset = 0.035; // radians, keeps the frame inside the dividers
    final start = -math.pi / 2 - _kSeg / 2 + inset;
    const sweep = _kSeg - inset * 2;
    final wedge = Path()
      ..arcTo(Rect.fromCircle(center: c, radius: rOut), start, sweep, true)
      ..arcTo(Rect.fromCircle(center: c, radius: rIn), start + sweep, -sweep,
          false)
      ..close();
    final bounds = wedge.getBounds();

    // Light wash → segment looks lit up / brighter than its neighbours
    canvas.drawPath(
      wedge,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0x66FFFD9D), const Color(0xCCFFFD9D), win)!,
            Color.lerp(const Color(0x10FFFD9D), const Color(0x55FFFD9D), win)!,
          ],
        ).createShader(bounds),
    );
    // Outer glow
    canvas.drawPath(
      wedge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * (0.03 + 0.03 * win)
        ..strokeJoin = StrokeJoin.round
        ..color = Color.lerp(_WheelColors.orange, _WheelColors.cream, win)!
            .withAlpha(220)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * (0.02 + 0.03 * win)),
    );
    // Crisp double frame: cream outside, orange inside
    canvas.drawPath(
      wedge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.016
        ..strokeJoin = StrokeJoin.round
        ..color = _WheelColors.cream,
    );
    canvas.drawPath(
      wedge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.006
        ..strokeJoin = StrokeJoin.round
        ..color = _WheelColors.orange,
    );
  }

  void _goldRing(Canvas canvas, Offset c, double radius, double w) {
    final rect = Rect.fromCircle(center: c, radius: radius + w);
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..shader = const SweepGradient(colors: _kGoldSweep).createShader(rect),
    );
    // Bevel: light top edge, dark bottom edge
    canvas.drawCircle(
      c,
      radius - w * 0.4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.2
        ..color = const Color(0x88FFFFFF),
    );
    canvas.drawCircle(
      c,
      radius + w * 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.2
        ..color = const Color(0xAA2A1000),
    );
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) => false;
}

/// Gold drop pointer with a red gem.
class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2, cy = w / 2, r = w * 0.42;
    final body = Path.combine(
      PathOperation.union,
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      Path()
        ..moveTo(cx - r * 0.82, cy + r * 0.55)
        ..lineTo(cx, h - 1)
        ..lineTo(cx + r * 0.82, cy + r * 0.55)
        ..close(),
    );
    canvas.drawPath(
      body.shift(Offset(0, w * 0.07)),
      Paint()
        ..color = const Color(0x99000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06),
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_WheelColors.cream, _WheelColors.orange, _WheelColors.bronze],
        ).createShader(body.getBounds()),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeJoin = StrokeJoin.round
        ..color = _WheelColors.brown,
    );
    _drawGem(canvas, Offset(cx, cy), r * 0.42, _WheelColors.red, _WheelColors.darkRed);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Suits
// ─────────────────────────────────────────────────────────────────────────────

Path _stem(double s) => Path()
  ..moveTo(0, s * 0.1)
  ..quadraticBezierTo(s * 0.08, s * 0.8, s * 0.42, s)
  ..lineTo(-s * 0.42, s)
  ..quadraticBezierTo(-s * 0.08, s * 0.8, 0, s * 0.1)
  ..close();

Path _suitPath(LuckyCardSuit suit, double s) {
  switch (suit) {
    case LuckyCardSuit.diamonds:
      return Path()
        ..moveTo(0, -s)
        ..lineTo(s * 0.72, 0)
        ..lineTo(0, s)
        ..lineTo(-s * 0.72, 0)
        ..close();
    case LuckyCardSuit.hearts:
      return Path()
        ..moveTo(0, s * 0.95)
        ..cubicTo(-s * 1.25, s * 0.05, -s * 0.95, -s * 1.05, 0, -s * 0.42)
        ..cubicTo(s * 0.95, -s * 1.05, s * 1.25, s * 0.05, 0, s * 0.95)
        ..close();
    case LuckyCardSuit.spades:
      final top = Path()
        ..moveTo(0, -s)
        ..cubicTo(s * 1.25, -s * 0.15, s * 0.95, s * 0.9, 0, s * 0.35)
        ..cubicTo(-s * 0.95, s * 0.9, -s * 1.25, -s * 0.15, 0, -s)
        ..close();
      return Path.combine(PathOperation.union, top, _stem(s));
    case LuckyCardSuit.clubs:
      final rr = s * 0.36;
      final leaves = Path()
        ..addOval(Rect.fromCircle(center: Offset(0, -s * 0.5), radius: rr))
        ..addOval(
            Rect.fromCircle(center: Offset(-s * 0.46, s * 0.1), radius: rr))
        ..addOval(
            Rect.fromCircle(center: Offset(s * 0.46, s * 0.1), radius: rr))
        ..addOval(
            Rect.fromCircle(center: Offset(0, -s * 0.05), radius: rr * 0.7));
      return Path.combine(PathOperation.union, leaves, _stem(s));
  }
}

/// Red suits in brand red, spades and clubs in glossy black.
/// [rim] adds a light outline so black suits stay visible on dark backgrounds.
void _paintSuit(Canvas canvas, LuckyCardSuit suit, Offset center, double s,
    {Color? rim}) {
  final path = _suitPath(suit, s).shift(center);
  if (rim != null) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.22
        ..strokeJoin = StrokeJoin.round
        ..color = rim,
    );
  }
  canvas.drawPath(
    path.shift(Offset(s * 0.06, s * 0.14)),
    Paint()..color = const Color(0x55000000),
  );
  final colors = suit.isRed
      ? const [Color(0xFFFF5A4F), _WheelColors.red, _WheelColors.darkRed]
      : const [Color(0xFF5A5A5A), Color(0xFF1C1C1C), Colors.black];
  canvas.drawPath(
    path,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.95,
        colors: colors,
        stops: const [0.0, 0.5, 1.0],
      ).createShader(path.getBounds()),
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..color = const Color(0x66FFFFFF),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Hub
// ─────────────────────────────────────────────────────────────────────────────

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Dark recessed bowl with faint gold rays.
class _HubBackgroundPainter extends CustomPainter {
  const _HubBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF3A0A04), Color(0xFF1C0302), Color(0xFF0A0000)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(rect),
    );
    // Faint gold rays (subtle, so icons stay readable)
    const rays = 16;
    final rayPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x44E37E01), Color(0x00E37E01)],
      ).createShader(rect);
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      final ray = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - 0.09) * r, c.dy + math.sin(a - 0.09) * r)
        ..lineTo(c.dx + math.cos(a + 0.09) * r, c.dy + math.sin(a + 0.09) * r)
        ..close();
      canvas.drawPath(ray, rayPaint);
    }
    // Inner shadow → recessed bowl
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00000000), Color(0x00000000), Color(0x99000000)],
          stops: [0.0, 0.7, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Hub content:
///  idle      → mystery gift
///  spinning  → smoke fills the hub, then the admin's bonus ("N", "2x"…)
///              grows out of the smoke from small to large
///  stopped   → smoke blows away, the bonus glides down under the result
///              with a bounce and a shine, and the result pops in above it
class _HubFxPainter extends CustomPainter {
  _HubFxPainter({
    required this.result,
    required this.spinning,
    required this.phase,
    required this.pop,
    required this.innerProgress,
    required this.bonusText,
  });

  final LuckyCardWheelOutcome? result;
  final bool spinning;
  final double phase; // 0..2π, loops seamlessly
  final double pop; // 0..1 reveal progress
  final double innerProgress; // 0..1 inner-rim spin progress
  final String bonusText;

  static const double _bonusBigScale = 1.8; // size while in the smoke
  static const double _resultY = -0.16; // × r, result above centre
  static const double _bonusY = 0.48; // × r, bonus below centre

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    if (spinning) {
      // Smoke first, then the bonus emerges and grows.
      final e = ((innerProgress - 0.2) / 0.8).clamp(0.0, 1.0);
      _smoke(canvas, c, r, phase, 1.0, 0.0);
      if (e > 0) {
        final grow = Curves.easeOutBack.transform(e);
        _bonus(canvas, c, r,
            scale: 0.3 + (_bonusBigScale - 0.3) * grow,
            alpha: math.min(1.0, e * 1.6));
      }
      // Wisps in front thin out as the bonus becomes clear.
      _smoke(canvas, c, r, phase + 1.7, 0.55 * (1 - 0.6 * e), 0.0, front: true);
      return;
    }

    if (result == null) {
      final t = Curves.elasticOut.transform(pop);
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..scale(0.3 + 0.7 * t)
        ..translate(-c.dx, -c.dy);
      _gift(canvas, c, r * 0.62);
      canvas.restore();
      return;
    }

    // 1) Result pops in above centre.
    final rp = ((pop - 0.25) / 0.75).clamp(0.0, 1.0);
    if (rp > 0) _result(canvas, c, r, Curves.elasticOut.transform(rp));

    // 2) Bonus glides from the middle down under the result, lands with a
    //    little bounce, then a shine sweeps across it.
    final m = Curves.easeInOutCubic.transform((pop / 0.45).clamp(0.0, 1.0));
    final land = ((pop - 0.45) / 0.3).clamp(0.0, 1.0);
    final bump = math.sin(math.pi * land) * 0.22;
    _bonus(
      canvas,
      Offset(c.dx, _lerp(c.dy, c.dy + r * _bonusY, m)),
      r,
      scale: _lerp(_bonusBigScale, 1.0, m) + bump,
      alpha: 1.0,
      shine: ((pop - 0.6) / 0.4).clamp(0.0, 1.0),
    );

    // 3) Smoke blows outward and fades.
    if (pop < 0.6) {
      final b = pop / 0.6;
      _smoke(canvas, c, r, phase, 1 - b, b);
    }
  }

  /// Soft puffs orbiting the centre. [burst] 0→1 pushes them out and fades.
  void _smoke(Canvas canvas, Offset c, double r, double phase, double alpha,
      double burst,
      {bool front = false}) {
    if (alpha <= 0) return;
    final n = front ? 5 : 9;
    final col = front ? const Color(0xFFFFF4E0) : const Color(0xFFD9C7B8);
    final a0 = ((front ? 0.22 : 0.4) * alpha * 255).round();
    for (var i = 0; i < n; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final a = i * 2 * math.pi / n + dir * phase;
      final orbit =
          r * (0.18 + 0.14 * math.sin(phase * 2 + i)) * (1 + burst * 1.8);
      final p = c + Offset(math.cos(a), math.sin(a)) * orbit;
      final pr = r *
          (0.32 + 0.08 * math.sin(phase * 3 + i * 1.3)) *
          (1 + burst * 0.8) *
          (front ? 0.7 : 1.0);
      canvas.drawCircle(
        p,
        pr,
        Paint()
          ..shader = RadialGradient(
            colors: [col.withAlpha(a0), col.withAlpha(0)],
          ).createShader(Rect.fromCircle(center: p, radius: pr)),
      );
    }
  }

  /// Gold glowing bonus text ("N", "2x" …). [shine] 0→1 sweeps a highlight.
  void _bonus(Canvas canvas, Offset center, double r,
      {required double scale, required double alpha, double shine = 0}) {
    final fs = r * 0.44; // a little bigger than before (0.36)
    final base = TextStyle(
      fontFamily: _kBonusFont,
      fontWeight: FontWeight.w700,
      fontSize: fs,
      height: 1.0,
    );
    final probe = TextPainter(
      text: TextSpan(text: bonusText, style: base),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = probe.width, h = probe.height;
    final rect = Rect.fromLTWH(-w / 2, -h / 2, w, h);
    final a = (alpha * 255).round();

    final tp = TextPainter(
      text: TextSpan(
        text: bonusText,
        style: base.copyWith(
          foreground: Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // Yellow: light cream on top → bright yellow → golden yellow
              colors: [
                const Color(0xFFFFFFE0).withAlpha(a),
                _WheelColors.cream.withAlpha(a),
                const Color(0xFFFFE14A).withAlpha(a),
                const Color(0xFFF5B800).withAlpha(a),
              ],
              stops: const [0.0, 0.3, 0.65, 1.0],
            ).createShader(rect),
          shadows: [
            Shadow(
              color: const Color(0xFFFFB800).withAlpha((alpha * 200).round()),
              blurRadius: fs * 0.3,
            ),
            Shadow(
              color: Color.fromARGB((alpha * 150).round(), 0, 0, 0),
              blurRadius: fs * 0.06,
              offset: Offset(0, fs * 0.05),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(scale);
    final o = Offset(-w / 2, -h / 2);
    if (shine > 0 && shine < 1) {
      final bounds = rect.inflate(fs * 0.15);
      canvas.saveLayer(bounds, Paint());
      tp.paint(canvas, o);
      final sx = _lerp(bounds.left - fs * 0.5, bounds.right + fs * 0.5, shine);
      canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..shader = const LinearGradient(
            begin: Alignment(-1, -0.4),
            end: Alignment(1, 0.4),
            colors: [Color(0x00FFFFFF), Color(0xDDFFFFFF), Color(0x00FFFFFF)],
          ).createShader(
              Rect.fromLTWH(sx - fs * 0.4, bounds.top, fs * 0.8, bounds.height)),
      );
      canvas.restore();
    } else {
      tp.paint(canvas, o);
    }
    canvas.restore();
  }

  /// Rank + suit, a little larger than before.
  void _result(Canvas canvas, Offset c, double r, double t) {
    final res = result!;
    canvas
      ..save()
      ..translate(c.dx, c.dy + r * _resultY)
      ..scale(0.3 + 0.7 * t);
    canvas
      ..save()
      ..translate(-r * 0.25, 0);
    _paintLetter(canvas, res.rank, r * 0.72);
    canvas.restore();
    _paintSuit(canvas, res.suit, Offset(r * 0.34, 0), r * 0.28,
        rim: _WheelColors.cream);
    canvas.restore();
  }

  void _gift(Canvas canvas, Offset c, double s) {
    final cx = c.dx, cy = c.dy + s * 0.12;
    Offset o(double x, double y) => Offset(cx + x * s, cy + y * s);
    Path poly(List<Offset> pts) => Path()..addPolygon(pts, true);

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: o(0, 0.98), width: s * 1.6, height: s * 0.3),
      Paint()..color = const Color(0x66000000),
    );

    final topFace = poly([o(0, -0.9), o(0.8, -0.5), o(0, -0.1), o(-0.8, -0.5)]);
    final leftFace = poly([o(-0.8, -0.5), o(0, -0.1), o(0, 0.9), o(-0.8, 0.5)]);
    final rightFace = poly([o(0, -0.1), o(0.8, -0.5), o(0.8, 0.5), o(0, 0.9)]);

    canvas.drawPath(leftFace, Paint()..color = _WheelColors.red);
    canvas.drawPath(rightFace, Paint()..color = _WheelColors.darkRed);
    canvas.drawPath(topFace, Paint()..color = const Color(0xFFFF3A2E));

    // Ribbons
    final ribbon = Paint()
      ..color = _WheelColors.honey
      ..strokeWidth = s * 0.16
      ..strokeCap = StrokeCap.butt;
    final ribbonHi = Paint()
      ..color = _WheelColors.cream
      ..strokeWidth = s * 0.05;
    for (final (a, b) in [
      (o(-0.4, -0.3), o(-0.4, 0.7)),
      (o(0.4, -0.3), o(0.4, 0.7)),
      (o(-0.4, -0.7), o(0.4, -0.3)),
      (o(0.4, -0.7), o(-0.4, -0.3)),
    ]) {
      canvas.drawLine(a, b, ribbon);
      canvas.drawLine(a, b, ribbonHi);
    }

    // Edges
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03
      ..strokeJoin = StrokeJoin.round
      ..color = _WheelColors.deepRed;
    for (final f in [leftFace, rightFace, topFace]) {
      canvas.drawPath(f, edge);
    }

    // Bow
    final bowPaint = Paint()
      ..shader = const LinearGradient(
        colors: [_WheelColors.cream, _WheelColors.orange],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: o(0, -0.6), radius: s * 0.4));
    final bowEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03
      ..color = _WheelColors.bronze;
    for (final dir in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(o(0, -0.55).dx, o(0, -0.55).dy);
      canvas.rotate(dir * 0.5);
      final loop = Rect.fromCenter(
          center: Offset(dir * s * 0.22, -s * 0.1),
          width: s * 0.42,
          height: s * 0.26);
      canvas.drawOval(loop, bowPaint);
      canvas.drawOval(loop, bowEdge);
      canvas.restore();
    }
    canvas.drawCircle(o(0, -0.58), s * 0.09, Paint()..color = _WheelColors.orange);

    // "?" on both side faces
    for (final x in [-0.2, 0.2]) {
      final tp = TextPainter(
        text: TextSpan(
          text: '?',
          style: TextStyle(
            fontSize: s * 0.42,
            fontWeight: FontWeight.w700,
            fontFamily: _kWheelFont,
            color: _WheelColors.cream,
            height: 1.0,
            shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o(x, 0.32) - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _HubFxPainter old) => true;
}
