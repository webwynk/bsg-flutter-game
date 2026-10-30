// The bet panel's readouts: PLAY and WIN, and the results. Built to the reference design.
//
// Given plain values, nothing else: no provider (lucky16_readouts_binding.dart
// connects them).
//
//   * PLAY is what the player has on the board (the stake); WIN is what the last round
//     paid, written "+1500" for a win and "0" otherwise.
//   * The results are the twelve latest rounds as cards, four across and three down, newest first
//     (Lucky Card spec §17BO, the user's design): a cream card with a gold frame (the newest on a green one),
//     the rank letter at the top left, the suit's picture at the bottom middle and a red bubble at
//     the top right with the bonus that round had ("N" when none, else 2X to 10X). Missing rounds
//     (a new table) are faint empty frames.
//   * All text is at least 11 dp and never follows the phone's font-size setting.
//
// The game's limits (MIN and MAX) are no longer drawn on the screen (the user's decision of
// 2026-10-23); they stay in the Info dialog and in the server's refusals.
//
// Copied from lib/widgets/lucky_card/lucky_card_readouts.dart (Lucky Card); the names changed, and it is
// the phone arrangement only.
//
// Belongs to Lucky 16 Card only.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/lucky16_models.dart';
import 'lucky16_art.dart';
import 'lucky16_layout.dart';
import 'lucky16_panel.dart' show lucky16Grouped;
import 'lucky16_palette.dart';
import 'lucky16_stake_text.dart';

/// What the WIN cell says: "+1500" for a win, "0" for anything else.
String lucky16WinText(int payout) => payout > 0 ? '+${lucky16Grouped(payout)}' : '0';

/// What a result card says beside its suit: the rank letter.
String lucky16ResultRank(Lucky16Card card) => card.rank.dbValue;

/// What a screen reader says for a result.
String lucky16ResultSemantics(Lucky16RecentRound round) {
  final bonus = round.bonusMultiplier > 1 ? ', bonus ${lucky16BonusLabel(round.bonusMultiplier)}' : ', no bonus';
  return '${round.winningCard.rank.label} of ${round.winningCard.suit.label}$bonus';
}

/// The small capitals the design puts over a figure and on the results line.
TextStyle _caption(double size, Color color, {FontWeight weight = FontWeight.w800, double spacing = 1}) => TextStyle(
      fontFamily: 'DMSans',
      fontWeight: weight,
      fontSize: size,
      letterSpacing: spacing,
      height: 1.2,
      color: color,
    );

/// PLAY (the stake) or WIN: a small label over a big figure, on a glossy coloured cell with a hard
/// shadow under it.
class Lucky16TotalCell extends StatelessWidget {
  const Lucky16TotalCell({
    super.key,
    required this.layout,
    required this.label,
    required this.value,
    required this.fill,
    required this.labelColor,
    required this.under,
  });

  final Lucky16Layout layout;
  final String label;
  final String value;
  final List<Color> fill;
  final Color labelColor;
  final Color under;

  @override
  Widget build(BuildContext context) {
    final valueSize = layout.designTotalValueFont;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(layout.totalCellRadius),
          gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: fill, stops: const [0.0, 0.6, 1.0]),
          boxShadow: [BoxShadow(color: under, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.totalPadX, vertical: layout.totalPadY),
          child: LayoutBuilder(
            builder: (context, c) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A box of exactly the line the layout counted: the text engine rounds the height of a
                // line up when the size is not a whole number, by under a dp.
                SizedBox(
                  height: layout.designTotalLabelFont * Lucky16Layout.designTotalLabelLine,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      textScaler: TextScaler.noScaling,
                      style: _caption(layout.designTotalLabelFont, labelColor),
                    ),
                  ),
                ),
                SizedBox(
                  height: valueSize * Lucky16Layout.designTotalValueLine,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _fitted(
                      value,
                      c.maxWidth,
                      TextStyle(
                        fontFamily: 'Oswald',
                        fontWeight: FontWeight.w700,
                        fontSize: valueSize,
                        height: Lucky16Layout.designTotalValueLine,
                        color: const Color(0xFFFFFFFF),
                        shadows: [Shadow(color: under, offset: const Offset(0, 2))],
                        fontFeatures: const [FontFeature.tabularFigures()],
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

  /// [text] at [style]'s size, made smaller to fit [maxWidth] (never under 11 dp).
  static Widget _fitted(String text, double maxWidth, TextStyle style) {
    final size = fitLucky16FontSize(text: text, style: style, maxWidth: maxWidth, preferred: style.fontSize!);
    return Text(text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        textScaler: TextScaler.noScaling,
        style: style.copyWith(fontSize: size));
  }
}

/// The suit's picture at [size] dp square.
Widget _suitPicture(Lucky16Layout layout, Lucky16Art art, BuildContext context, Lucky16Suit suit, double size) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return Image(
    image: art.image(Lucky16ArtKey.suitIcon(suit), cacheWidth: layout.resultIconCacheWidth(dpr)),
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    gaplessPlayback: true,
    excludeFromSemantics: true,
  );
}

/// The empty frame of a history card, the user's own picture (Lucky Card spec §17BO), drawn nine-slice so its
/// gold border keeps the thin, even size [Lucky16Layout.tileBorder] however wide or tall the card is.
///
/// The picture is measured as it arrives (the real app decodes it small, [Lucky16Layout.historyFrameCacheWidth]
/// pixels wide; a test may hand it over at full size), so the corners and the border are always the
/// picture's own 7.5% and 3% of its width, scaled to [Lucky16Layout.tileBorder] dp.
class Lucky16HistoryFrame extends StatefulWidget {
  const Lucky16HistoryFrame({super.key, required this.layout, required this.art, required this.latest});

  final Lucky16Layout layout;
  final Lucky16Art art;

  /// The green frame of the newest round, else the cream one.
  final bool latest;

  @override
  State<Lucky16HistoryFrame> createState() => _Lucky16HistoryFrameState();
}

class _Lucky16HistoryFrameState extends State<Lucky16HistoryFrame> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final ImageStreamListener _listener = ImageStreamListener(_onImage);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(Lucky16HistoryFrame old) {
    super.didUpdateWidget(old);
    _resolve();
  }

  void _resolve() {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final provider = widget.art.image(
      widget.latest ? Lucky16ArtKey.latestHistoryCard : Lucky16ArtKey.historyCard,
      cacheWidth: widget.layout.historyFrameCacheWidth(dpr),
    );
    final next = provider.resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = next..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    // The old picture stays until the new one is ready, so the frame never blinks.
    setState(() {
      _info?.dispose();
      _info = info.clone();
    });
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) return const SizedBox.shrink();
    return SizedBox(
      width: widget.layout.designTileWidth,
      height: widget.layout.designTileHeight,
      child: CustomPaint(painter: Lucky16HistoryFramePainter(info.image, widget.layout.tileBorder)),
    );
  }
}

/// Paints a history frame nine-slice: the picture's corners and border are scaled so that its border
/// (18 of its 604 px) comes out [border] dp thick, and the middle is stretched over the rest.
class Lucky16HistoryFramePainter extends CustomPainter {
  const Lucky16HistoryFramePainter(this.image, this.border);

  final ui.Image image;
  final double border;

  /// The border of the supplied picture, in its 604 px width, and the corner's reach (a rounded
  /// corner of about 45 px), as shares of that width.
  static const double borderShare = 18 / 604;
  static const double cornerShare = 0.075;

  /// How many dp one pixel of a picture [pictureWidth] wide is drawn as, so that its border is [border] dp.
  static double scaleFor(double pictureWidth, double border) => border / (pictureWidth * borderShare);

  /// The middle of a picture [width] x [height] px: what is stretched.
  static Rect centerOf(double width, double height) {
    final inset = width * cornerShare;
    return Rect.fromLTRB(inset, inset, width - inset, height - inset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final k = scaleFor(w, border);
    canvas.save();
    canvas.scale(k);
    canvas.drawImageNine(
      image,
      centerOf(w, h),
      Rect.fromLTWH(0, 0, size.width / k, size.height / k),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(Lucky16HistoryFramePainter old) => old.image != image || old.border != border;
}

/// One finished round as a card (Lucky Card spec §17BO): the frame, the rank letter at the top left (red for
/// hearts and diamonds, black for spades and clubs; on the green newest card white with a thin dark
/// outline), the suit's picture at the bottom middle (on the newest card on a small cream patch) and
/// a red bubble at the top right with the round's bonus. A null round draws a faint empty frame.
class Lucky16ResultTile extends StatelessWidget {
  const Lucky16ResultTile(
      {super.key, required this.layout, required this.art, required this.round, this.latest = false});

  final Lucky16Layout layout;
  final Lucky16Art art;

  /// Null draws an empty slot.
  final Lucky16RecentRound? round;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final round = this.round;
    final w = layout.designTileWidth;
    final h = layout.designTileHeight;
    if (round == null) {
      return Opacity(opacity: 0.3, child: Lucky16HistoryFrame(layout: layout, art: art, latest: false));
    }
    final card = round.winningCard;
    final b = layout.tileBorder;
    final icon = layout.tileIconSize;
    final bubbleH = layout.tileBubbleHeight;
    final bonusText = lucky16BonusLabel(round.bonusMultiplier);
    final letterStyle = TextStyle(
      fontFamily: 'Oswald',
      fontWeight: FontWeight.w700,
      fontSize: layout.tileLetterFont,
      height: 1.0,
    );
    TextStyle bubbleStyle(double size) => TextStyle(
          fontFamily: 'DMSans',
          fontWeight: FontWeight.w800,
          fontSize: size,
          height: 1.0,
          color: kLucky16HistoryBubbleText,
        );
    double measure(String text, TextStyle style) => (TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          maxLines: 1,
        )..layout())
            .width;

    final bubbleRight = b + math.max(1.0, w * 0.02);
    final bubbleTop = b + math.max(1.0, h * 0.03);
    final letterLeft = b + w * 0.06;
    final letterRight = letterLeft + measure(lucky16ResultRank(card), letterStyle);

    // A longer bonus ("10X") widens the bubble. If that would run into the rank letter (a narrow
    // card), the writing is made smaller, to the 11 dp floor, and then the bubble's
    // padding thinner, until it clears the letter; it is never made smaller than that.
    var bubbleFont = layout.tileBubbleFont;
    var padShare = 0.45;
    final room = w - bubbleRight - (letterRight + 1.5);
    double bubbleWidth() => math.max(bubbleH, measure(bonusText, bubbleStyle(bubbleFont)) + bubbleH * padShare);
    while (bubbleWidth() > room && bubbleFont > kLucky16MinReadableDp) {
      bubbleFont = math.max(kLucky16MinReadableDp, bubbleFont - 0.5);
    }
    while (bubbleWidth() > room && padShare > 0.2) {
      padShare -= 0.05;
    }
    final bubbleW = bubbleWidth();
    final bubbleLeft = w - bubbleRight - bubbleW;

    // The suit picture is centred at the bottom; on a wide, short card, where the bubble comes down
    // beside it, it moves left until it clears the bubble (to within 2 dp).
    final patch = latest ? icon * 1.15 : icon;
    final iconTop = h - (b + h * 0.03) - patch;
    var iconLeft = (w - patch) / 2;
    if (iconTop < bubbleTop + bubbleH) iconLeft = math.min(iconLeft, math.max(b + 1, bubbleLeft + 2 - patch));

    final letterColor =
        latest ? kLucky16HistoryLatestLetter : (card.suit.isRed ? kLucky16HistoryRed : kLucky16HistoryBlack);
    final outline = latest
        ? [
            for (final dx in const [-0.8, 0.8])
              for (final dy in const [-0.8, 0.8]) Shadow(color: kLucky16HistoryLatestOutline, offset: Offset(dx, dy)),
          ]
        : null;

    return Semantics(
      label: '${latest ? 'Latest result: ' : 'Earlier result: '}${lucky16ResultSemantics(round)}',
      excludeSemantics: true,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: Lucky16HistoryFrame(layout: layout, art: art, latest: latest)),
            Positioned(
              left: letterLeft,
              top: b + h * 0.03,
              child: Text(
                lucky16ResultRank(card),
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: letterStyle.copyWith(color: letterColor, shadows: outline),
              ),
            ),
            Positioned(
              left: iconLeft,
              top: iconTop,
              width: patch,
              height: patch,
              child: DecoratedBox(
                decoration: latest
                    ? const BoxDecoration(shape: BoxShape.circle, color: kLucky16HistoryPatch)
                    : const BoxDecoration(),
                child: Center(child: _suitPicture(layout, art, context, card.suit, icon)),
              ),
            ),
            Positioned(
              right: bubbleRight,
              top: bubbleTop,
              width: bubbleW,
              height: bubbleH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(bubbleH / 2),
                  gradient: const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: kLucky16HistoryBubbleFill),
                  border: Border.all(color: kLucky16HistoryBubbleRing, width: math.max(1.0, bubbleH * 0.06)),
                ),
                child: Center(
                  child: Text(bonusText,
                      maxLines: 1, softWrap: false, textScaler: TextScaler.noScaling, style: bubbleStyle(bubbleFont)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The twelve latest rounds, four across and three down, newest first ([history] is newest first).
/// Missing rounds (a new table) are faint empty frames.
class Lucky16ResultsPanel extends StatelessWidget {
  const Lucky16ResultsPanel({super.key, required this.layout, required this.art, required this.history});

  final Lucky16Layout layout;
  final Lucky16Art art;
  final List<Lucky16RecentRound> history;

  @override
  Widget build(BuildContext context) {
    final panel = layout.resultsPanel;
    Rect inPanel(Rect r) => layout.within(panel, r);
    Lucky16RecentRound? at(int i) => i < history.length ? history[i] : null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              gradient:
                  LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: kLucky16ResultsFill),
            ),
          ),
        ),
        for (var i = 0; i < layout.resultCount; i++)
          Positioned.fromRect(
            rect: inPanel(layout.resultTile(i)),
            child: Lucky16ResultTile(
              // The newest keeps its own name; the eleven before it are result-0 to result-10.
              key: ValueKey(i == 0 ? 'result-latest' : 'result-${i - 1}'),
              layout: layout,
              art: art,
              round: at(i),
              latest: i == 0,
            ),
          ),
      ],
    );
  }
}

/// Loads the four suit icons and the two card frames into the image cache, so the results never
/// pop in.
Future<void> precacheLucky16Results(BuildContext context, Lucky16Layout layout, Lucky16Art art) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return Future.wait([
    for (final suit in Lucky16Suit.values)
      precacheImage(art.image(Lucky16ArtKey.suitIcon(suit), cacheWidth: layout.resultIconCacheWidth(dpr)), context),
    for (final key in [Lucky16ArtKey.historyCard, Lucky16ArtKey.latestHistoryCard])
      precacheImage(art.image(key, cacheWidth: layout.historyFrameCacheWidth(dpr)), context),
  ]);
}
