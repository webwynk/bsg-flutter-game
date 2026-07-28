import 'dart:math';
import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────────────────────────
// HubSmokeAnimation  —  Heavy eruption-style smoke for the wheel hub
//
// Emits large cloud-burst particles from the hub center in all directions,
// creating a dramatic "volcano eruption" effect visible on the gold hub.
// ──────────────────────────────────────────────────────────────────────────────

class HubSmokeAnimation extends StatefulWidget {
  final double size;
  const HubSmokeAnimation({super.key, required this.size});

  @override
  State<HubSmokeAnimation> createState() => _HubSmokeAnimationState();
}

class _HubSmokeAnimationState extends State<HubSmokeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late _SmokeSystem _system;

  @override
  void initState() {
    super.initState();
    _system = _SmokeSystem();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    _ctrl.addListener(() {
      _system.tick(0.016);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SmokePainter(_system.particles),
      size: Size(widget.size, widget.size),
    );
  }
}

// ─── Particle ─────────────────────────────────────────────────────────────────
class _Particle {
  double x, y;         // normalised: 0=center, ±1=edge
  double radius;       // normalised
  double alpha;
  double vx, vy;       // velocity per second
  double growth;       // radius growth per second
  double decay;        // alpha decay per second
  double age;
  Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
    required this.vx,
    required this.vy,
    required this.growth,
    required this.decay,
    required this.color,
  }) : age = 0;

  bool get isDead => alpha <= 0 || radius > 1.2;

  void update(double dt) {
    age += dt;
    x += vx * dt;
    y += vy * dt;
    radius += growth * dt;
    alpha = (alpha - decay * dt).clamp(0.0, 1.0);
    // gentle organic drift
    x += sin(age * 4.2 + vx) * 0.012 * dt;
    y += cos(age * 3.1 + vy) * 0.008 * dt;
  }
}

// ─── Smoke System ─────────────────────────────────────────────────────────────
class _SmokeSystem {
  final Random _rng = Random();
  final List<_Particle> particles = [];
  double _timer = 0;

  // Spawn a burst every 28ms — roughly 3× more frequent than before
  static const double _interval = 0.028;

  // Colour palette: white, warm-white, very light orange for fire-glow effect
  static const List<Color> _palette = [
    Color(0xFFFFFFFF),   // pure white
    Color(0xFFFFF8F0),   // warm white
    Color(0xFFFFEFD5),   // papaya / warm cream
    Color(0xFFFFDDAA),   // soft orange glow (bottom of cloud)
  ];

  void tick(double dt) {
    _timer += dt;
    int spawns = 0;
    while (_timer >= _interval && spawns < 4) {
      _timer -= _interval;
      _spawn();
      spawns++;
    }
    for (final p in particles) { p.update(dt); }
    particles.removeWhere((p) => p.isDead);
  }

  void _spawn() {
    // Emit from near-center with outward burst
    final angle = _rng.nextDouble() * 2 * pi;
    final originDist = _rng.nextDouble() * 0.08; // very close to center
    final ox = cos(angle) * originDist;
    final oy = sin(angle) * originDist;

    // Speed: fast outward + upward bias
    final speed = 0.35 + _rng.nextDouble() * 0.45;
    final vx = cos(angle) * speed * (0.5 + _rng.nextDouble() * 0.5);
    // y: upward bias — vy negative = up in our coord system
    final vy = -(0.30 + _rng.nextDouble() * 0.45)
               + sin(angle) * speed * 0.35;

    // Pick color: more white, less warm
    final colorIdx = _rng.nextDouble() < 0.65
        ? 0  // pure white — most common
        : (_rng.nextDouble() < 0.5 ? 1 : (_rng.nextDouble() < 0.5 ? 2 : 3));
    final color = _palette[colorIdx];

    particles.add(_Particle(
      x:      ox,
      y:      oy,
      radius: 0.10 + _rng.nextDouble() * 0.14, // big puffs
      alpha:  0.72 + _rng.nextDouble() * 0.26, // high starting opacity
      vx:     vx,
      vy:     vy,
      growth: 0.08 + _rng.nextDouble() * 0.12, // expand fast
      decay:  0.22 + _rng.nextDouble() * 0.18, // linger moderately
      color:  color,
    ));
  }
}

// ─── Painter ──────────────────────────────────────────────────────────────────
class _SmokePainter extends CustomPainter {
  final List<_Particle> particles;
  const _SmokePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final scale = size.width / 2;

    for (final p in particles) {
      final px = cx + p.x * scale;
      final py = cy - p.y * scale;  // flip Y: negative=up on screen
      final pr = p.radius * scale;
      if (pr <= 0) continue;

      // Radial gradient: solid centre → translucent edge
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            p.color.withValues(alpha: p.alpha),
            p.color.withValues(alpha: p.alpha * 0.55),
            p.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.50, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(px, py), radius: pr));

      // Slightly squash each puff organically
      canvas.save();
      canvas.translate(px, py);
      final wobble = sin(p.age * 3.0) * 0.07;
      canvas.scale(1.0 + wobble, 1.0 - wobble * 0.5);
      canvas.translate(-px, -py);
      canvas.drawCircle(Offset(px, py), pr, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SmokePainter old) => true;
}
