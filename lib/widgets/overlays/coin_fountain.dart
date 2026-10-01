import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// ---------------------------------------------------------------------------
/// COIN FOUNTAIN — big-win celebration effect (Issue #106)
///
/// Coins burst from a single point and fall under gravity, tracing a
/// half-round arch. Used by `game_screen.dart` for wins of 900 coins or more,
/// during the 1.5s slot Issue #105 opened between the balance reveal
/// (wheel-stop + 0.300s) and the win popup (wheel-stop + 1.800s).
///
/// USAGE IN THIS APP — mounted and unmounted by a `Consumer` of
/// `GameProvider` gated on `showCoinFx`, with `autoPlay: true`, matching how
/// every other overlay in this app is driven:
///
/// ```dart
/// Consumer<GameProvider>(
///   builder: (_, game, __) => game.showCoinFx
///     ? const CoinFountain(autoPlay: true)
///     : const SizedBox.shrink(),
/// )
/// ```
///
/// Because the widget only exists while it should be running, unmounting is
/// the teardown: `dispose()` kills the ticker, so `abortSpin()` needs no
/// special handling. `play()` is public because `autoPlay` calls it from
/// `initState()`; it also restarts a running fountain. (Issue #117: the
/// imperative `stop()` / `clear()` that shipped with the supplied file were
/// removed -- nothing ever called them, since this app tears the fountain down
/// by unmounting it rather than by driving it through a `GlobalKey`.)
/// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// PER-COIN DRAW COST — CACHED ASSETS
//
// Drawn naively, paintCoin() would do, per coin, per frame: 3x
// TextPainter.layout() (glyph shaping — one of the more expensive calls in a
// paint loop), 2x Gradient.createShader() for the static face gradients, and a
// Path() allocation for the clip. At ~90 live coins x 60fps that is roughly
// 16,000 text layouts and 11,000 shader compiles a second — all producing the
// exact same output every time, since none of it depends on the coin's
// position, only on its radius.
//
// Fix: bucket by rounded radius (coins range roughly 15-21px here, so ~7
// buckets) and build each of those expensive objects once per bucket, not once
// per coin per frame. Sub-pixel radius differences within a bucket are
// invisible. The only things still computed fresh every frame are the literal
// Offset/rotation math (cheap) and the light streak (which must move, so it
// keeps its own per-frame shader).
// ---------------------------------------------------------------------------

const List<Color> _edgeColors = [
  Color(0xFF6B4700),
  Color(0xFF8A5A00),
  Color(0xFFB57C07),
  Color(0xFFE0A21A),
  Color(0xFFF5C542),
  Color(0xFFFFE27A),
  Color(0xFFF5C542),
  Color(0xFFD99A12),
];

// Top-level finals are lazily initialised in Dart, so these are built on FIRST
// USE rather than at load — either way, once for the whole process. Their
// colours never change, so the same Paint objects are reused for every coin,
// every frame, forever.
final List<Paint> _edgePaints =
    List.unmodifiable(_edgeColors.map((c) => Paint()..color = c));

final Paint _rimOuterPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 3
  ..color = const Color(0x8C7A5200);

final Paint _rimInnerPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.5
  ..color = const Color(0xB3FFF1A8);

class _CoinAssets {
  final Shader baseShader;
  final Shader innerShader;
  final TextPainter shadowText;
  final TextPainter highlightText;
  final TextPainter mainText;
  final Path clipPath;

  _CoinAssets({
    required this.baseShader,
    required this.innerShader,
    required this.shadowText,
    required this.highlightText,
    required this.mainText,
    required this.clipPath,
  });
}

final Map<int, _CoinAssets> _coinAssetCache = {};

/// Fetches (building and caching on first use) all the radius-dependent but
/// otherwise-static drawing objects for a coin of roughly radius [r].
_CoinAssets _assetsFor(double r) {
  final key = r.round().clamp(1, 1000);
  final cached = _coinAssetCache[key];
  if (cached != null) return cached;

  final rr = key.toDouble();
  final rect = Rect.fromCircle(center: Offset.zero, radius: rr);

  final baseShader = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF6B8), Color(0xFFF5C542), Color(0xFFA9750A)],
    stops: [0.0, 0.35, 0.7],
  ).createShader(rect);

  final innerShader = const RadialGradient(
    center: Alignment(0.75, 0.7),
    radius: 0.9,
    colors: [
      Color(0xFFFFEB8F),
      Color(0xFFF7C531),
      Color(0xFFD99A12),
      Color(0xFFB57C07),
    ],
    stops: [0.0, 0.45, 0.8, 1.0],
  ).createShader(rect);

  final dollarRect = Rect.fromCenter(center: Offset.zero, width: rr, height: rr * 2);
  final dollarShader = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF9D454), Color(0xFFC98F0C)],
  ).createShader(dollarRect);

  // fontFamily deliberately omitted: this project bundles DMSans and Oswald
  // only. A font it does not ship (the original draft asked for Georgia) would
  // silently fall back to Roboto on Android rather than failing loudly, so the
  // default is used instead. Pass a bundled family here if a specific look for
  // the "$" is wanted later.
  TextPainter makeText(Paint paint) => TextPainter(
        text: TextSpan(
          text: '\$',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: rr, foreground: paint),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

  final assets = _CoinAssets(
    baseShader: baseShader,
    innerShader: innerShader,
    shadowText: makeText(Paint()..color = const Color(0xFF8A5A00)),
    highlightText: makeText(Paint()..color = const Color(0xFFFFF3B0)),
    mainText: makeText(Paint()..shader = dollarShader),
    clipPath: Path()..addOval(rect),
  );
  _coinAssetCache[key] = assets;
  return assets;
}

/// Draws one shiny gold coin at [center] with the given [radius], rotated by
/// [spinAngle] (the flip, in radians) and [tilt] (a small constant in-plane
/// rotation). Kept as a top-level function rather than a method so there is
/// exactly one definition of "what a coin looks like" for any future caller.
void paintCoin(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required double spinAngle,
  required double tilt,
}) {
  final r = radius;
  final c = math.cos(spinAngle);
  final s = math.sin(spinAngle);
  final ac = math.max(0.03, c.abs()); // horizontal squash factor
  final thickness = r * 0.32;
  final sign = c >= 0 ? 1.0 : -1.0;
  final xNear = sign * (thickness / 2) * s;
  final xFar = -xNear;

  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(tilt);

  // --- Edge (the metal "side" of the coin, visible as it turns) ---
  // Paint objects are pre-built constants (_edgePaints); only the oval's
  // position/size is computed fresh, since that genuinely changes per frame.
  for (int k = 0; k < _edgePaints.length; k++) {
    final ox = xFar + (xNear - xFar) * (k / (_edgePaints.length - 1));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(ox, 0), width: 2 * r * ac, height: 2 * r),
      _edgePaints[k],
    );
  }

  // --- Face (front or back, whichever is toward the camera) ---
  final faceVisible = (0.5 + 0.5 * s * sign).clamp(0.0, 1.0);
  canvas.save();
  canvas.translate(xNear, 0);
  canvas.scale(ac, 1);
  _paintFace(canvas, r, faceVisible);
  canvas.restore();

  // --- Sparkle flash, brightest when the face is nearly flat-on ---
  final sparkleStrength =
      (1 - ((faceVisible - 0.5).abs() / 0.14)).clamp(0.0, 1.0) * ac;
  if (sparkleStrength > 0.05) {
    _drawSparkle(canvas, Offset(xNear - r * 0.28, -r * 0.28),
        r * 1.3 * sparkleStrength, sparkleStrength);
  }

  canvas.restore();
}

void _paintFace(Canvas canvas, double r, double lightPos) {
  final assets = _assetsFor(r);
  final rect = Rect.fromCircle(center: Offset.zero, radius: r);

  // Base gold disc + recessed inner face — cached shaders, just drawn here.
  canvas.drawCircle(Offset.zero, r, Paint()..shader = assets.baseShader);
  canvas.drawCircle(Offset.zero, r * 0.86, Paint()..shader = assets.innerShader);

  // Rim rings — cached constant Paints (colour/strokeWidth never vary).
  canvas.drawCircle(Offset.zero, r * 0.62, _rimOuterPaint);
  canvas.drawCircle(const Offset(1, 1), r * 0.62, _rimInnerPaint);

  // Embossed "$" (shadow, highlight, then gradient-filled main) — all three
  // TextPainters are pre-laid-out and cached; paint() here is just a blit,
  // not a re-shape.
  assets.shadowText.paint(
    canvas,
    const Offset(2, 5) - Offset(assets.shadowText.width / 2, assets.shadowText.height / 2),
  );
  assets.highlightText.paint(
    canvas,
    const Offset(-2, 1) -
        Offset(assets.highlightText.width / 2, assets.highlightText.height / 2),
  );
  assets.mainText.paint(
    canvas,
    const Offset(0, 3) - Offset(assets.mainText.width / 2, assets.mainText.height / 2),
  );

  // Light streak sweeping across the coin as it spins. This is the one thing
  // that genuinely must be recomputed every frame — its position (lightPos) is
  // what makes the coin look like it is catching the light as it turns. The
  // colour list stays a compile-time const (alpha 0xCC is fixed and never
  // animated); only the gradient's `stops`, which depend on lightPos and so
  // cannot be const, are rebuilt per frame.
  canvas.save();
  canvas.clipPath(assets.clipPath);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Colors.transparent, Color(0xCCFFFFFF), Colors.transparent],
        stops: [
          (lightPos - 0.14).clamp(0.0, 1.0),
          lightPos.clamp(0.0, 1.0),
          (lightPos + 0.14).clamp(0.0, 1.0),
        ],
      ).createShader(rect),
  );
  canvas.restore();
}

void _drawSparkle(Canvas canvas, Offset center, double g, double opacity) {
  if (g <= 0) return;
  final path = Path()
    ..moveTo(center.dx, center.dy - g)
    ..quadraticBezierTo(center.dx, center.dy, center.dx + g, center.dy)
    ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + g)
    ..quadraticBezierTo(center.dx, center.dy, center.dx - g, center.dy)
    ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - g)
    ..close();
  // Genuinely needs a dynamic alpha (the sparkle fades in and out), so this is
  // the one place in this file that computes a colour per frame.
  canvas.drawPath(
    path,
    Paint()..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
  );
}

class _FountainCoin {
  double t = 0;
  final double vx, vy, r, spin, spinV, tilt, tiltV;
  _FountainCoin(this.vx, this.vy, this.r, this.spin, this.spinV, this.tilt, this.tiltV);
}

/// Minimal ChangeNotifier used purely as a repaint signal for CustomPainter.
/// No listeners other than the framework's internal RenderCustomPaint ever
/// need to know about this.
class _RepaintTicks extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// Coins burst from [originFraction] and fall under gravity.
///
/// Performance notes:
///  - All coins for one frame are drawn in a single CustomPaint pass (one
///    canvas, one layer), not one Positioned+CustomPaint per coin.
///  - Each coin's expensive-but-static draw assets (shaders, laid-out "$"
///    text, clip path) are cached per rounded radius bucket — built once,
///    reused by every coin of similar size, every frame. See _assetsFor().
///  - Coins are removed from the list the moment they leave the visible
///    bounds, so per-frame work shrinks back to zero instead of lingering for
///    seconds after everything is invisible.
///  - Repainting is driven by a Listenable passed to CustomPainter's `repaint:`
///    parameter, not by calling setState() every tick — so the surrounding
///    LayoutBuilder's build callback does NOT re-run 60 times a second, only
///    the canvas repaints. (LayoutBuilder still re-runs on its own if the
///    incoming constraints actually change, e.g. a rotation, which is how
///    _lastSize/_origin stay correct without any extra wiring.)
class CoinFountain extends StatefulWidget {
  /// How many coins are emitted per second while pouring.
  final double coinsPerSecond;

  /// Launch speed in logical pixels/second. Higher = taller arch.
  final double power;

  /// Half-angle of the spray, in degrees, measured from straight up.
  /// Higher = wider arch.
  final double spreadDegrees;

  /// How long the pour lasts. Coins already in the air keep falling after
  /// this, until they leave the screen — so the visible effect outlives this
  /// value. In this app the widget is unmounted at wheel-stop + 1.800s, which
  /// cuts any still-airborne coins; the win popup's unanimated blur and 80%
  /// scrim land on the same frame and hide that cut.
  final Duration duration;

  /// Origin point of the burst, as a fraction of the widget's size.
  /// Defaults to the exact centre: Offset(0.5, 0.5).
  final Offset originFraction;

  /// Starts the pour as soon as the widget is mounted, instead of waiting for
  /// an imperative `play()`. Required by the Consumer mount/unmount pattern
  /// this app uses, where the widget only exists while it should be running
  /// and there is no GlobalKey for a caller to reach through.
  final bool autoPlay;

  const CoinFountain({
    super.key,
    this.coinsPerSecond = 99,
    this.power = 350,
    this.spreadDegrees = 50,
    this.duration = const Duration(milliseconds: 1500),
    this.originFraction = const Offset(0.5, 0.5),
    this.autoPlay = false,
  });

  @override
  State<CoinFountain> createState() => CoinFountainState();
}

class CoinFountainState extends State<CoinFountain>
    with SingleTickerProviderStateMixin {
  static const double _gravity = 900; // px/s^2
  static const double _margin = 40; // off-screen slack before culling

  /// Hard ceiling on how long the ticker can run past _emitUntil before it
  /// force-stops regardless of whether pruning ever found the coins
  /// off-screen. This is what makes termination unconditional rather than
  /// dependent on _lastSize ever becoming non-zero.
  static const Duration _maxFlightBackstop = Duration(seconds: 6);

  final math.Random _rng = math.Random();
  final List<_FountainCoin> _coins = [];
  final _RepaintTicks _repaint = _RepaintTicks();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Duration _elapsed = Duration.zero;
  Duration _emitUntil = Duration.zero;
  double _spawnAccumulator = 0;
  bool _running = false;
  Size _lastSize = Size.zero;
  Offset _origin = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.autoPlay) play();
  }

  /// Starts (or restarts) the coin pour.
  void play() {
    _coins.clear();
    _elapsed = Duration.zero;
    _lastTick = Duration.zero;
    _spawnAccumulator = 0;
    _emitUntil = widget.duration;
    if (!_running) {
      _running = true;
      _ticker.start();
    }
    _repaint.bump();
  }

  void _spawnCoin() {
    final spreadRad = widget.spreadDegrees * math.pi / 180;
    final angle = (_rng.nextDouble() * 2 - 1) * spreadRad;
    final speed = widget.power * (0.85 + _rng.nextDouble() * 0.3);
    _coins.add(_FountainCoin(
      math.sin(angle) * speed,
      -math.cos(angle) * speed,
      15 + _rng.nextDouble() * 6,
      _rng.nextDouble() * 2 * math.pi,
      (4 + _rng.nextDouble() * 8) * (_rng.nextBool() ? 1 : -1),
      (_rng.nextDouble() - 0.5) * 1.2,
      (_rng.nextDouble() - 0.5) * 3,
    ));
  }

  void _onTick(Duration now) {
    final dt = _lastTick == Duration.zero
        ? 0.0
        : (now - _lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    _elapsed += Duration(microseconds: (dt * 1e6).round());

    if (_elapsed <= _emitUntil) {
      _spawnAccumulator += dt * widget.coinsPerSecond;
      while (_spawnAccumulator >= 1) {
        _spawnAccumulator -= 1;
        _spawnCoin();
      }
    }

    for (final c in _coins) {
      c.t += dt;
    }

    // Prune coins that have left the visible area so the list — and the
    // per-frame work — actually shrinks back to zero instead of lingering.
    final w = _lastSize.width;
    final h = _lastSize.height;
    if (w > 0 && h > 0) {
      _coins.removeWhere((c) {
        final x = _origin.dx + c.vx * c.t;
        final y = _origin.dy + c.vy * c.t + 0.5 * _gravity * c.t * c.t;
        return y > h + _margin || x < -_margin || x > w + _margin;
      });
    }

    // Guaranteed termination, independent of layout: pruning (above) only runs
    // once _lastSize is non-zero, which comes from LayoutBuilder. If this
    // widget were ever laid out with zero constraints, pruning would never
    // fire, _coins would never empty, and the ticker would run forever.
    // _maxFlightBackstop is a fixed, generous ceiling — well beyond any real
    // screen size and power setting — so termination no longer depends on
    // layout ever having happened at all.
    final timedOut = _elapsed > _emitUntil + _maxFlightBackstop;
    if (_elapsed > _emitUntil && (_coins.isEmpty || timedOut)) {
      if (timedOut) _coins.clear();
      _ticker.stop();
      _running = false;
    }

    // Signal the canvas to repaint WITHOUT calling setState — this skips
    // rebuilding the surrounding widget tree (and re-running LayoutBuilder's
    // callback) every single frame.
    _repaint.bump();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          _lastSize = Size(constraints.maxWidth, constraints.maxHeight);
          _origin = Offset(
            _lastSize.width * widget.originFraction.dx,
            _lastSize.height * widget.originFraction.dy,
          );

          return CustomPaint(
            size: _lastSize,
            painter: _FountainPainter(
              coins: _coins,
              origin: _origin,
              gravity: _gravity,
              repaint: _repaint,
            ),
          );
        },
      ),
    );
  }
}

/// Paints every live coin in one pass over one canvas. Repainting is driven by
/// the `repaint` listenable (see CoinFountainState._onTick), so shouldRepaint's
/// return value only matters for the rare case where a new painter instance
/// replaces this one outside of that listenable (e.g. on resize) — returning
/// true keeps that path correct with no measurable cost, since it is a single
/// bool check, not a repaint by itself.
class _FountainPainter extends CustomPainter {
  final List<_FountainCoin> coins;
  final Offset origin;
  final double gravity;

  _FountainPainter({
    required this.coins,
    required this.origin,
    required this.gravity,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in coins) {
      final x = origin.dx + c.vx * c.t;
      final y = origin.dy + c.vy * c.t + 0.5 * gravity * c.t * c.t;
      paintCoin(
        canvas,
        center: Offset(x, y),
        radius: c.r,
        spinAngle: c.spin + c.spinV * c.t,
        tilt: c.tilt + c.tiltV * c.t,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FountainPainter old) => true;
}
