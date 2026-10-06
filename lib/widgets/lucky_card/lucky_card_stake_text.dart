// The live numbers drawn on the pictures: what they say, and how they are sized
// so they always stay readable.
//
// The rules are the user's of 2026-10-06 (spec §17O) and the Q38 rule of §12.1:
//   * a card with no coins shows the word "Play"; a suit bar or rank selector with
//     nothing on it shows nothing;
//   * a rank disc abbreviates a total of 100,000 or more (200K, whole thousands,
//     rounded down); every other number is written in full, with no separators;
//   * the text is sized from the canvas, never below 11 dp. When it is wider than
//     its slot it shrinks to fit, but not below 11 dp; then it is allowed to run
//     a little over the gold frame, which is ornament, not information;
//   * the phone's font-size setting has no effect.
//
// Belongs to Lucky Card only.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'lucky_card_layout.dart';

/// What a card's ribbon says: the word "Play" when nothing is on it, otherwise the
/// amount.
String luckyCardRibbonLabel(int stake) => stake <= 0 ? luckyCardPlayWord : '$stake';

/// The word on an empty card.
const String luckyCardPlayWord = 'Play';

/// What a suit bar's panel says: the total, or nothing at 0.
String luckyCardSuitLabel(int total) => total <= 0 ? '' : '$total';

/// What a rank disc says: the total, or nothing at 0; from 100,000 up, whole
/// thousands rounded down with a K (123,500 is 123K).
String luckyCardRankLabel(int total) {
  if (total <= 0) return '';
  if (total >= 100000) return '${total ~/ 1000}K';
  return '$total';
}

/// The text size for [text] in a slot [maxWidth] wide: [preferred], made smaller
/// if the text is wider than the slot, but never below [min] (11 dp by default).
/// At the minimum the text may be wider than the slot.
double fitLuckyCardFontSize({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required double preferred,
  double min = kLuckyCardMinReadableDp,
}) {
  final size = math.max(preferred, min);
  if (text.isEmpty || maxWidth <= 0) return size;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  if (width <= maxWidth) return size;
  return math.max(size * maxWidth / width, min);
}

/// A number or word centred in a slot, one line, in the Lucky Card number font.
class LuckyCardStakeText extends StatelessWidget {
  const LuckyCardStakeText(
    this.text, {
    super.key,
    required this.maxWidth,
    required this.preferredSize,
    this.color = const Color(0xFFFFF3C4),
    this.shadowColor = const Color(0xCC3A0000),
  });

  final String text;

  /// How wide the slot is, in dp.
  final double maxWidth;

  /// The size to use if it fits, in dp (made at least 11 dp).
  final double preferredSize;

  final Color color;
  final Color shadowColor;

  static const TextStyle _base = TextStyle(
    fontFamily: 'Oswald',
    fontWeight: FontWeight.w500,
    height: 1.0,
    // Digits keep one width, so a number does not jiggle as it changes.
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final size = fitLuckyCardFontSize(
      text: text,
      style: _base,
      maxWidth: maxWidth,
      preferred: preferredSize,
    );
    return Center(
      // Allowed to be wider than the slot (at the 11 dp minimum): it paints a little
      // over the frame instead of being squeezed or cut.
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          textScaler: TextScaler.noScaling,
          style: _base.copyWith(
            fontSize: size,
            color: color,
            shadows: [Shadow(color: shadowColor, blurRadius: 1.5, offset: const Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}
