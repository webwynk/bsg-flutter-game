// The big card of the reveal: it stands right of the wheel while the wheel turns (the approved
// mockup's ?state=spin), in the card picture's own wide shape ([Lucky16Layout.revealCard]).
// Copied from lib/widgets/lucky_card/lucky_card_reveal_card.dart (Lucky Card), whose card is square
// and takes the rank selectors' place; the flips and the timing are unchanged. Resting, it shows a
// card back. When the spin starts it
// flips through the faces of `lucky16RevealPlan` at random, slowing down. When
// the provider reveals the winner it turns over to it one last time and pops: the
// column then shows that card alone.
//
// It never shows the winner by itself: the winner appears only when `settle` is
// called (the binding calls it when the provider says the card is revealed), so it
// cannot get ahead of the hub.
//
// Belongs to Lucky 16 Card only.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/lucky16_models.dart';
import 'lucky16_art.dart';
import 'lucky16_layout.dart';
import 'lucky16_reveal_plan.dart';

class Lucky16RevealCard extends StatefulWidget {
  const Lucky16RevealCard({
    super.key,
    required this.layout,
    required this.art,
    this.onFlip,
    this.semanticsLabel,
  });

  final Lucky16Layout layout;
  final Lucky16Art art;

  /// Called every time the card starts a flip (the tick of the shuffle, and the
  /// final turn to the winner).
  final VoidCallback? onFlip;

  /// What a screen reader announces. Null while the shuffle runs: nothing is
  /// announced until the winner is known.
  final String? semanticsLabel;

  @override
  State<Lucky16RevealCard> createState() => Lucky16RevealCardState();
}

class Lucky16RevealCardState extends State<Lucky16RevealCard> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this);
  late final AnimationController _settle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  Lucky16RevealPlan? _plan;
  Lucky16Card? _winner;
  Lucky16Card? _settleFrom;
  bool _settled = false;
  int _announced = 0;

  @override
  void initState() {
    super.initState();
    _spin.addListener(_announceFlips);
    _settle.addStatusListener((status) {
      if (status == AnimationStatus.completed && _settled && _pop.value == 0) _pop.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    _settle.dispose();
    _pop.dispose();
    super.dispose();
  }

  /// True once the card has turned to the winner (or is turning).
  bool get isSettled => _settled;

  /// True while the random faces are flipping, before the card settles.
  bool get isShuffling => _plan != null && !_settled && _spin.isAnimating;

  /// The face on show right now (the one that would be seen face-on at this moment
  /// of a flip), or null for the card's back.
  Lucky16Card? get shownCard => _frame().visible;

  /// How much the card is enlarged by its pop on settling (1 when at rest).
  @visibleForTesting
  double get popScale => 1 + 0.08 * math.sin(math.pi * _pop.value);

  /// Starts the shuffle for a round. The faces and their order come from the round
  /// number, so every phone shows the same.
  void spin({required Lucky16Card winner, required int roundNumber}) {
    final plan = lucky16RevealPlan(winner: winner, roundNumber: roundNumber);
    setState(() {
      _plan = plan;
      _winner = null;
      _settled = false;
      _settleFrom = null;
      _announced = 0;
    });
    _settle.value = 0;
    _pop.value = 0;
    _spin
      ..duration = plan.total
      ..forward(from: 0);
  }

  /// Turns over to [winner] and pops: the winner alone.
  void settle(Lucky16Card winner) {
    if (_settled) return;
    final from = shownCard;
    setState(() {
      _settleFrom = from;
      _winner = winner;
      _settled = true;
    });
    _spin.stop();
    widget.onFlip?.call();
    _settle.forward(from: 0);
  }

  /// Shows [winner] at once, with no animation (a screen that opens after the
  /// reveal).
  void showWinner(Lucky16Card winner) {
    _spin.stop();
    setState(() {
      _plan = null;
      _winner = winner;
      _settleFrom = winner;
      _settled = true;
    });
    // The pop is set first. (Either order ends the same: finishing the turn with the
    // pop at 0 starts it, and setting it to 1 afterwards cancels that. This order
    // just never starts it.)
    _pop.value = 1;
    _settle.value = 1;
  }

  void _announceFlips() {
    final plan = _plan;
    if (plan == null || _settled) return;
    final elapsed = Duration(microseconds: (_spin.value * plan.total.inMicroseconds).round());
    var due = 0;
    for (final step in plan.steps) {
      if (step.at <= elapsed) due++;
    }
    while (_announced < due) {
      _announced++;
      widget.onFlip?.call();
    }
  }

  Lucky16RevealFrame _frame() {
    if (_settled) return Lucky16RevealFrame(_settleFrom, _winner, _settle.value);
    final plan = _plan;
    if (plan == null) return const Lucky16RevealFrame(null, null, 1);
    return lucky16RevealFrameAt(plan, Duration(microseconds: (_spin.value * plan.total.inMicroseconds).round()));
  }

  /// The winning card lights up (phone phase 5): once the card has turned to the winner, a gold glow
  /// grows round it with the settling flip, as the approved mockup draws the revealed card. Before that
  /// (the shuffle, a card back) nothing is lit.
  Widget _lit(Widget face, Size size) {
    if (!_settled) return face;
    final t = _settle.value;
    return DecoratedBox(
      key: const ValueKey('reveal-winner-glow'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size.height * 0.05),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFFD34D).withValues(alpha: 0.67 * t), blurRadius: size.height * 0.16),
          BoxShadow(color: const Color(0xFFFFE58A).withValues(alpha: 0.5 * t), spreadRadius: size.height * 0.015),
        ],
      ),
      child: face,
    );
  }

  Widget _face(Lucky16Card? card, Size size, double dpr) {
    if (card == null) {
      return SizedBox(
        key: const ValueKey('reveal-face-back'),
        width: size.width,
        height: size.height,
        child: const CustomPaint(painter: _CardBackPainter()),
      );
    }
    return Image(
      key: ValueKey('reveal-face-${card.key}'),
      image: widget.art.image(Lucky16ArtKey.card(card), cacheWidth: widget.layout.revealCacheWidth(dpr)),
      width: size.width,
      height: size.height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.layout.revealCard.size;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final label = widget.semanticsLabel;
    return SizedBox.expand(
      child: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Semantics(
            liveRegion: label != null,
            label: label,
            excludeSemantics: true,
            child: AnimatedBuilder(
              animation: Listenable.merge([_spin, _settle, _pop]),
              builder: (context, _) {
                final frame = _frame();
                final p = frame.progress;
                final angle = p < 0.5 ? p * math.pi : (1 - p) * math.pi;
                final scale = popScale;
                return Transform.scale(
                  scale: scale,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..rotateY(angle),
                    child: _lit(_face(frame.visible, size, dpr), size),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The face-down card: the game's red and gold, a gold diamond with a "?".
class _CardBackPainter extends CustomPainter {
  const _CardBackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final rect = Offset.zero & size;
    final body = RRect.fromRectAndRadius(rect.deflate(w * 0.03), Radius.circular(w * 0.09));
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B0000), Color(0xFF3A0204)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..color = const Color(0xFFD4AF37),
    );
    canvas.drawRRect(
      body.deflate(w * 0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..color = const Color(0x88F5E6C4),
    );
    final c = size.center(Offset.zero);
    final d = w * 0.22;
    final diamond = Path()
      ..moveTo(c.dx, c.dy - d)
      ..lineTo(c.dx + d * 0.78, c.dy)
      ..lineTo(c.dx, c.dy + d)
      ..lineTo(c.dx - d * 0.78, c.dy)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE066), Color(0xFFD4AF37), Color(0xFF8B6914)],
        ).createShader(diamond.getBounds()),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          fontFamily: 'Oswald',
          fontWeight: FontWeight.w700,
          fontSize: w * 0.3,
          height: 1.0,
          color: const Color(0xFF3A0204),
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
