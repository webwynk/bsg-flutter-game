// The live numbers drawn on the pictures: what they say, and how they are sized
// so they always stay readable.
//
// The rules are the user's of 2026-10-06 (spec §17O) and the Q38 rule of §12.1, as changed by
// the reference-design redesign of 2026-10-23:
//   * a card with no coins shows the word "Play"; a suit bar or rank badge with nothing
//     on it shows its own name (the pieces draw that, not this file), and its total once
//     there is one;
//   * every number is written IN FULL, with no separators, however big (150000 on a suit
//     bar, 200000 on a rank badge): the user decided on 2026-10-23 that nothing is shortened
//     (the rank badge used to write 100,000 and up as 100K);
//   * the text is sized from the canvas, never below 11 dp. When it is wider than
//     its slot it shrinks to fit, but not below 11 dp; then it is allowed to run
//     a little over the gold frame, which is ornament, not information;
//   * the phone's font-size setting has no effect.
//
// Copied from lib/widgets/lucky_card/lucky_card_stake_text.dart (Lucky Card); the names changed, and the
// counts are Lucky 16 Card's (16 cards, 4 on a suit bar, 4 rank selectors A, J, Q, K).
//
// Belongs to Lucky 16 Card only.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'lucky16_layout.dart';

/// What a card's ribbon says: the word "Play" when nothing is on it, otherwise the
/// amount.
String lucky16RibbonLabel(int stake) => stake <= 0 ? lucky16PlayWord : '$stake';

/// The word on an empty card.
const String lucky16PlayWord = 'Play';

/// What a suit bar's plate says once the suit has a total: the whole number, or nothing at 0
/// (the bar then shows its name instead).
String lucky16SuitLabel(int total) => total <= 0 ? '' : '$total';

/// What a rank badge's plate says once the rank has a total: the whole number, never
/// shortened, or nothing at 0 (the badge then shows its name instead).
String lucky16RankLabel(int total) => total <= 0 ? '' : '$total';

/// The text size for [text] in a slot [maxWidth] wide: [preferred], made smaller
/// if the text is wider than the slot, but never below [min] (11 dp by default).
/// At the minimum the text may be wider than the slot.
double fitLucky16FontSize({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required double preferred,
  double min = kLucky16MinReadableDp,
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

/// A number or word centred in a slot, one line, in the Lucky 16 Card number font.
class Lucky16StakeText extends StatelessWidget {
  const Lucky16StakeText(
    this.text, {
    super.key,
    required this.maxWidth,
    required this.preferredSize,
    this.color = const Color(0xFFFFF3C4),
    this.shadowColor = const Color(0xCC3A0000),
    this.weight = FontWeight.w500,
    this.shadowOffset = const Offset(0, 1),
    this.shadowBlur = 1.5,
    this.fontFamily,
  });

  final String text;

  /// How wide the slot is, in dp.
  final double maxWidth;

  /// The size to use if it fits, in dp (made at least 11 dp).
  final double preferredSize;

  final Color color;
  final Color shadowColor;

  /// The weight of the digits (the reference design's board numbers are bold), and the offset
  /// and blur of the shadow under them (the design's is a hard 2 dp shadow with no blur).
  final FontWeight weight;
  final Offset shadowOffset;
  final double shadowBlur;
  final String? fontFamily;

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
    final baseStyle = fontFamily == null ? _base : _base.copyWith(fontFamily: fontFamily);
    final size = fitLucky16FontSize(
      text: text,
      style: baseStyle.copyWith(fontWeight: weight),
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
          style: baseStyle.copyWith(
            fontSize: size,
            fontWeight: weight,
            color: color,
            shadows: [Shadow(color: shadowColor, blurRadius: shadowBlur, offset: shadowOffset)],
          ),
        ),
      ),
    );
  }
}
