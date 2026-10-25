// The Spin2Win win popup, as the reference design's "Win popup" board draws it (420 x 326 dp): a pink
// "YOU WIN!" banner with ribbons over a gold-framed purple card holding the winning NUMBER tile ×
// the BONUS tile, and the WIN AMOUNT in large gold figures, with twinkling sparkles and floating
// coins around it. Behind it the screen darkens and slow gold rays turn.
//
// Given the number, the bonus and the amount, nothing else. It pops in when built (the design's
// `wpPop`); the provider decides when it is shown (2.5 s, from 1.5 s after the wheel stops).
// It takes no taps.
//
// Belongs to Spin2Win only.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'spin2win_palette.dart';

/// The bonus tile's five shades (the popup's own `BON` table: N is a pale steel).
Spin2WinShades _bonusTileShades(int multiplier) => switch (multiplier) {
      2 => spin2WinShades(0),
      3 => spin2WinShades(3),
      4 => spin2WinShades(5),
      _ => const Spin2WinShades(Color(0xFFE3E9F7), Color(0xFFC7D3EE), Color(0xFF7A8AAE), Color(0xFF5A6A8E), Color(0xFF2A3450)),
    };

/// The darkened screen with the turning rays, and the popup in the middle. Fills its box (and
/// reaches past it, so a screen wider or taller than the design is darkened too).
class Spin2WinWinOverlay extends StatefulWidget {
  const Spin2WinWinOverlay({super.key, required this.number, required this.bonusMultiplier, required this.amount});

  final int number;
  final int bonusMultiplier;
  final int amount;

  @override
  State<Spin2WinWinOverlay> createState() => _Spin2WinWinOverlayState();
}

class _Spin2WinWinOverlayState extends State<Spin2WinWinOverlay> with TickerProviderStateMixin {
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  late final AnimationController _rays = AnimationController(vsync: this, duration: const Duration(seconds: 26))..repeat();
  late final AnimationController _beat =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  static const Cubic _popCurve = Cubic(.2, 1.5, .4, 1);

  @override
  void dispose() {
    _enter.dispose();
    _rays.dispose();
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _rays, _beat]),
        builder: (context, _) {
          final fade = (_enter.value / (350 / 600)).clamp(0.0, 1.0);
          final pop = _popCurve.transform(_enter.value);
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // radial-gradient(circle, rgba(30,12,80,.55), rgba(3,8,25,.84) 70%), reaching past the box.
              Positioned(
                left: -2000,
                right: -2000,
                top: -2000,
                bottom: -2000,
                child: Opacity(
                  opacity: fade,
                  child: const DecoratedBox(decoration: BoxDecoration(color: Color(0xD6030819))),
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: fade,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.9,
                        colors: [Color(0x8C1E0C50), Color(0xD6030819)],
                        stops: [0, .7],
                      ),
                    ),
                  ),
                ),
              ),
              // The turning rays.
              Positioned.fill(
                child: Opacity(
                  opacity: fade,
                  child: CustomPaint(painter: _RaysPainter(_rays.value * 2 * math.pi)),
                ),
              ),
              Opacity(
                opacity: _enter.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 40 * (1 - pop)),
                  child: Transform.scale(
                    scale: 0.3 + 0.7 * pop,
                    child: Spin2WinWinPopup(
                      number: widget.number,
                      bonusMultiplier: widget.bonusMultiplier,
                      amount: widget.amount,
                      beat: _beat.value,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// `repeating-conic-gradient(rgba(255,212,90,.2) 0 9deg, transparent 9deg 20deg)`, fading out from
/// the middle by 42% of a 1400 dp square, turned by [turn].
class _RaysPainter extends CustomPainter {
  _RaysPainter(this.turn);

  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const reach = 700.0;
    final rect = Rect.fromCircle(center: c, radius: reach);
    canvas.saveLayer(rect, Paint());
    final ray = Paint()..color = const Color(0x33FFD45A);
    for (var a = 0.0; a < 360; a += 20) {
      canvas.drawArc(rect, (a - 90) * math.pi / 180 + turn, 9 * math.pi / 180, true, ray);
    }
    canvas.drawCircle(
      c,
      reach,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const RadialGradient(
          colors: [Color(0xFF000000), Color(0x00000000)],
          stops: [0, .42 * 1.4142],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => oldDelegate.turn != turn;
}

/// The popup itself, 420 x 326 dp.
class Spin2WinWinPopup extends StatelessWidget {
  const Spin2WinWinPopup({
    super.key,
    required this.number,
    required this.bonusMultiplier,
    required this.amount,
    this.beat = 0,
  });

  final int number;
  final int bonusMultiplier;
  final int amount;

  /// Where the sparkles and floating coins are in their slow beat, 0 to 1.
  final double beat;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeInOut.transform(beat);
    Widget sparkle(double left, double top, double size, Color color, double phase) {
      final p = (t + phase) % 1;
      return Positioned(
        left: left,
        top: top,
        width: size,
        height: size,
        child: Opacity(
          opacity: 0.4 + 0.6 * p,
          child: Transform.rotate(
            angle: 20 * p * math.pi / 180,
            child: Transform.scale(scale: 0.6 + 0.55 * p, child: CustomPaint(painter: _SparklePainter(color))),
          ),
        ),
      );
    }

    Widget coin(double left, double top, double size, double phase) {
      final p = (t + phase) % 1;
      return Positioned(
        left: left,
        top: top - 10 * p,
        width: size,
        height: size,
        child: Transform.rotate(
          angle: (-10 + 22 * p) * math.pi / 180,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFF0C0), width: 3),
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.4),
                colors: [Color(0xFFFFF0C0), Color(0xFFFFB52E), Color(0xFFB06A00)],
                stops: [0, .55, 1],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0xFF5A3500), offset: Offset(0, 3)),
                BoxShadow(color: Color(0xB3FFB52E), blurRadius: 10),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      key: const ValueKey('spin2win-win-popup'),
      width: 420,
      height: 326,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The gold-framed card.
          Positioned(
            left: 20,
            top: 40,
            width: 380,
            height: 272,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF0C0), Color(0xFFFFB52E), Color(0xFFD98300), Color(0xFFFFD45A)],
                  stops: [0, .35, .7, 1],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x8CFFB52E), blurRadius: 44),
                  BoxShadow(color: Color(0xFF5A3500), offset: Offset(0, 8)),
                  BoxShadow(color: Color(0xB3000000), offset: Offset(0, 18), blurRadius: 36),
                ],
              ),
              child: _CardFace(number: number, bonusMultiplier: bonusMultiplier, amount: amount),
            ),
          ),
          // The ribbons, then the banner over them.
          Positioned(left: 44, top: 30, width: 70, height: 44, child: CustomPaint(painter: _RibbonPainter(left: true))),
          Positioned(right: 44, top: 30, width: 70, height: 44, child: CustomPaint(painter: _RibbonPainter(left: false))),
          Positioned(
            left: 80,
            top: 12,
            width: 260,
            height: 58,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kS2wGold, width: 3),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFF8AE2), Color(0xFFFF35C7), Color(0xFFC20E92)],
                  stops: [0, .45, 1],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x80FF35C7), blurRadius: 20),
                  BoxShadow(color: Color(0xFF5A0445), offset: Offset(0, 5)),
                  BoxShadow(color: Color(0x8C000000), offset: Offset(0, 10), blurRadius: 18),
                ],
              ),
              child: const Spin2WinOutlinedText(
                'YOU WIN!',
                size: 32,
                height: 1,
                letterSpacing: 1.5,
                stroke: Color(0xE65A0445),
                strokeWidth: 5,
                shadows: [Shadow(color: Color(0x59000000), offset: Offset(0, 4))],
              ),
            ),
          ),
          sparkle(4, 70, 26, const Color(0xFFFFF6C8), 0),
          sparkle(386, 96, 20, const Color(0xFF6FF3FF), 0.35),
          sparkle(26, 256, 18, const Color(0xFFFF8AE2), 0.6),
          sparkle(378, 236, 24, const Color(0xFFFFF6C8), 0.15),
          coin(-6, 150, 28, 0),
          coin(398, 166, 22, 0.4),
          coin(356, 18, 24, 0.2),
        ],
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.number, required this.bonusMultiplier, required this.amount});

  final int number;
  final int bonusMultiplier;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final bonusText = spin2WinBonusText(bonusMultiplier);
    return ClipRRect(
      borderRadius: BorderRadius.circular(23),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0x8C00E5FF), width: 2),
          gradient: const RadialGradient(
            center: Alignment(0, -0.3),
            radius: 0.95,
            colors: [Color(0xFF4A22A8), Color(0xFF25207A), Color(0xFF102650), kS2wBgDeep],
            stops: [0, .4, .75, 1],
          ),
        ),
        child: Stack(
          children: [
            // The shine along the top.
            Positioned(
              left: 37,
              right: 37,
              top: 2,
              height: 70,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20), bottom: Radius.elliptical(140, 35)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFFFFFFFF).withValues(alpha: 0.18), const Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _labelled(
                        'NUMBER',
                        const Color(0xFF6FF3FF),
                        const Color(0xB300E5FF),
                        _Tile(
                          key: const ValueKey('spin2win-win-number'),
                          shades: spin2WinShades(number),
                          text: '$number',
                          size: 56,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Padding(padding: const EdgeInsets.only(bottom: 26), child: _times()),
                      const SizedBox(width: 14),
                      _labelled(
                        'BONUS',
                        const Color(0xFFFF8AE2),
                        const Color(0xB3FF35C7),
                        _Tile(
                          key: const ValueKey('spin2win-win-bonus'),
                          shades: _bonusTileShades(bonusMultiplier),
                          text: bonusText,
                          size: bonusText.length > 2 ? 32 : 40,
                          glow: bonusMultiplier > 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'WIN AMOUNT',
                    style: TextStyle(
                      fontFamily: kSpin2WinFont,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 3,
                      color: kS2wGold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CustomPaint(size: Size(34, 34), painter: _StarCoinPainter()),
                      const SizedBox(width: 10),
                      _amount('+${spin2WinAmountText(amount)}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _labelled(String label, Color color, Color glow, Widget tile) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: kSpin2WinFont,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 2.5,
              color: color,
              shadows: [Shadow(color: glow, blurRadius: 6)],
            ),
          ),
          const SizedBox(height: 6),
          tile,
        ],
      );

  static Widget _times() => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: Color(0xFFFFF0C0), width: 2)),
          gradient: RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFFFE07A), Color(0xFFD98300)]),
          boxShadow: [BoxShadow(color: Color(0xFF5A3500), offset: Offset(0, 3))],
        ),
        child: const Spin2WinOutlinedText('×', size: 22, height: 1, stroke: Color(0xFF5A3500), shadows: []),
      );

  /// The amount in tall gold figures fading from pale to orange, with a brown drop and a glow.
  static Widget _amount(String text) {
    const style = TextStyle(
      fontFamily: kSpin2WinDigitsFont,
      fontWeight: FontWeight.w700,
      fontSize: 44,
      height: 52 / 44,
      letterSpacing: 1,
    );
    return Stack(
      children: [
        Transform.translate(
          offset: const Offset(0, 3),
          child: Text(
            text,
            style: style.copyWith(
              color: const Color(0xFF5A3500),
              shadows: const [Shadow(color: Color(0x99FFB52E), blurRadius: 12)],
            ),
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF6C8), kS2wGold, Color(0xFFFF9A1F)],
            stops: [0, .45, 1],
          ).createShader(bounds),
          child: Text(text, key: const ValueKey('spin2win-win-amount'), style: style.copyWith(color: const Color(0xFFFFFFFF))),
        ),
      ],
    );
  }
}

/// An 84 dp tile: a light rim, the shaded face with its shine, and big outlined text.
class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.shades, required this.text, required this.size, this.glow = false});

  final Spin2WinShades shades;
  final String text;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [shades.edge, shades.dark]),
        boxShadow: [
          if (glow) BoxShadow(color: shades.light, blurRadius: 18),
          BoxShadow(color: shades.under, offset: const Offset(0, 6)),
          const BoxShadow(color: Color(0x8C000000), offset: Offset(0, 10), blurRadius: 16),
        ],
      ),
      child: Spin2WinGlossBox(
        radius: 15,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), gradient: shades.face),
        child: Center(
          child: Spin2WinOutlinedText(
            text,
            size: size,
            height: 1,
            strokeWidth: 5,
            stroke: const Color(0xCC100A28),
            shadows: const [Shadow(color: Color(0x59000000), offset: Offset(0, 4))],
          ),
        ),
      ),
    );
  }
}

/// A four-pointed sparkle (viewBox 24).
class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final p = Path()
      ..moveTo(12, 0)
      ..lineTo(14.5, 9.5)
      ..lineTo(24, 12)
      ..lineTo(14.5, 14.5)
      ..lineTo(12, 24)
      ..lineTo(9.5, 14.5)
      ..lineTo(0, 12)
      ..lineTo(9.5, 9.5)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.color != color;
}

/// The coin with a star beside the amount (viewBox 34).
class _StarCoinPainter extends CustomPainter {
  const _StarCoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 34, size.height / 34);
    canvas.drawCircle(const Offset(17, 18), 15, Paint()..color = const Color(0xFF8A5000));
    canvas.drawCircle(const Offset(17, 16), 15, Paint()..color = const Color(0xFFFFB52E));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFFFF0C0);
    canvas.drawCircle(const Offset(17, 16), 15, ring..strokeWidth = 2);
    canvas.drawCircle(const Offset(17, 16), 10, ring..strokeWidth = 1.6);
    final star = Path()
      ..moveTo(17, 9.5)
      ..relativeLineTo(1.9, 4)
      ..relativeLineTo(4.3, .5)
      ..relativeLineTo(-3.2, 3)
      ..relativeLineTo(.9, 4.3)
      ..relativeLineTo(-3.9, -2.2)
      ..relativeLineTo(-3.9, 2.2)
      ..relativeLineTo(.9, -4.3)
      ..relativeLineTo(-3.2, -3)
      ..relativeLineTo(4.3, -.5)
      ..close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFF6C8));
  }

  @override
  bool shouldRepaint(_StarCoinPainter oldDelegate) => false;
}

/// One of the two magenta ribbon tails behind the banner, notched on its outer end.
class _RibbonPainter extends CustomPainter {
  const _RibbonPainter({required this.left});

  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = left
        ? (Path()
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..lineTo(w * .24, h / 2)
          ..close())
        : (Path()
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(w * .76, h / 2)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close());
    canvas.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC20E92), Color(0xFF6A0450)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => oldDelegate.left != left;
}
