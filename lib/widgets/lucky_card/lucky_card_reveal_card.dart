// The big card of the reveal: it takes the place of the rank selectors while the
// wheel turns (spec §7.3). Resting, it shows a card back. When the spin starts it
// flips through the faces of `luckyCardRevealPlan` at random, slowing down. When
// the provider reveals the winner it turns over to it one last time and pops: the
// column then shows that card alone.
//
// It never shows the winner by itself: the winner appears only when `settle` is
// called (the binding calls it when the provider says the card is revealed), so it
// cannot get ahead of the hub.
//
// Belongs to Lucky Card only.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/lucky_card_models.dart';
import 'lucky_card_art.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_reveal_plan.dart';

class LuckyCardRevealCard extends StatefulWidget {
  const LuckyCardRevealCard({
    super.key,
    required this.layout,
    required this.art,
    this.onFlip,
    this.semanticsLabel,
  });

  final LuckyCardLayout layout;
  final LuckyCardArt art;

  /// Called every time the card starts a flip (the tick of the shuffle, and the
  /// final turn to the winner).
  final VoidCallback? onFlip;

  /// What a screen reader announces. Null while the shuffle runs: nothing is
  /// announced until the winner is known.
  final String? semanticsLabel;

  @override
  State<LuckyCardRevealCard> createState() => LuckyCardRevealCardState();
}

class LuckyCardRevealCardState extends State<LuckyCardRevealCard> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this);
  late final AnimationController _settle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  late final AnimationController _pop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  LuckyCardRevealPlan? _plan;
  LuckyCard? _winner;
  LuckyCard? _settleFrom;
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
  LuckyCard? get shownCard => _frame().visible;

  /// How much the card is enlarged by its pop on settling (1 when at rest).
  @visibleForTesting
  double get popScale => 1 + 0.08 * math.sin(math.pi * _pop.value);

  /// Starts the shuffle for a round. The faces and their order come from the round
  /// number, so every phone shows the same.
  void spin({required LuckyCard winner, required int roundNumber}) {
    final plan = luckyCardRevealPlan(winner: winner, roundNumber: roundNumber);
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
  void settle(LuckyCard winner) {
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
  void showWinner(LuckyCard winner) {
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

  LuckyCardRevealFrame _frame() {
    if (_settled) return LuckyCardRevealFrame(_settleFrom, _winner, _settle.value);
    final plan = _plan;
    if (plan == null) return const LuckyCardRevealFrame(null, null, 1);
    return luckyCardRevealFrameAt(plan, Duration(microseconds: (_spin.value * plan.total.inMicroseconds).round()));
  }

  Widget _face(LuckyCard? card, double side, double dpr) {
    if (card == null) {
      return SizedBox(
        key: const ValueKey('reveal-face-back'),
        width: side,
        height: side,
        child: const CustomPaint(painter: _CardBackPainter()),
      );
    }
    return Image(
      key: ValueKey('reveal-face-${card.key}'),
      image: widget.art.image(LuckyCardArtKey.card(card), cacheWidth: widget.layout.revealCacheWidth(dpr)),
      width: side,
      height: side,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.layout.revealCard.width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final label = widget.semanticsLabel;
    return SizedBox.expand(
      child: Center(
        child: SizedBox(
          width: side,
          height: side,
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
                    child: _face(frame.visible, side, dpr),
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
