// The bet panel's readouts: PLAY and WIN, and the results. Built to the reference design.
//
// Given plain values, nothing else: no provider (lucky_card_readouts_binding.dart
// connects them).
//
//   * PLAY is what the player has on the board (the stake); WIN is what the last round
//     paid, written "+1500" for a win and "0" otherwise.
//   * The results are the ten latest rounds in two rows of five, newest first: each a card
//     with the rank letter and the suit's picture side by side and the bonus under them (N
//     when the round had none). The newest is white, the nine before it dark purple. Missing
//     rounds (a new table) are empty slots.
//   * All text is at least 11 dp and never follows the phone's font-size setting.
//
// The game's limits (MIN and MAX) are no longer drawn on the screen (the user's decision of
// 2026-10-23); they stay in the Info dialog and in the server's refusals.
//
// Belongs to Lucky Card only.

import 'package:flutter/material.dart';

import '../../models/lucky_card_models.dart';
import 'lucky_card_art.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_panel.dart' show luckyCardGrouped;
import 'lucky_card_palette.dart';
import 'lucky_card_stake_text.dart';

/// What the WIN cell says: "+1500" for a win, "0" for anything else.
String luckyCardWinText(int payout) => payout > 0 ? '+${luckyCardGrouped(payout)}' : '0';

/// What a result card says beside its suit: the rank letter.
String luckyCardResultRank(LuckyCard card) => card.rank.dbValue;

/// What a screen reader says for a result.
String luckyCardResultSemantics(LuckyCardRecentRound round) {
  final bonus = round.bonusMultiplier > 1 ? ', bonus ${luckyCardBonusLabel(round.bonusMultiplier)}' : ', no bonus';
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

/// TOTAL BET or WIN: a small label over a big figure, on a glossy coloured cell with a hard
/// shadow under it.
class LuckyCardTotalCell extends StatelessWidget {
  const LuckyCardTotalCell({
    super.key,
    required this.layout,
    required this.label,
    required this.value,
    required this.fill,
    required this.labelColor,
    required this.under,
  });

  final LuckyCardLayout layout;
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
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: fill, stops: const [0.0, 0.6, 1.0]),
          boxShadow: [BoxShadow(color: under, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: LayoutBuilder(
            builder: (context, c) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  textScaler: TextScaler.noScaling,
                  style: _caption(layout.designTotalLabelFont, labelColor),
                ),
                SizedBox(
                  height: valueSize * LuckyCardLayout.designTotalValueLine,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _fitted(
                      value,
                      c.maxWidth,
                      TextStyle(
                        fontFamily: 'Oswald',
                        fontWeight: FontWeight.w700,
                        fontSize: valueSize,
                        height: LuckyCardLayout.designTotalValueLine,
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
    final size = fitLuckyCardFontSize(text: text, style: style, maxWidth: maxWidth, preferred: style.fontSize!);
    return Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, textScaler: TextScaler.noScaling, style: style.copyWith(fontSize: size));
  }
}

/// The suit's picture at [size] dp square.
Widget _suitPicture(LuckyCardLayout layout, LuckyCardArt art, BuildContext context, LuckyCardSuit suit, double size) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return Image(
    image: art.image(LuckyCardArtKey.suitIcon(suit), cacheWidth: layout.resultIconCacheWidth(dpr)),
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    gaplessPlayback: true,
    excludeFromSemantics: true,
  );
}

/// One finished round: the rank letter and the suit's picture side by side, and the bonus under
/// them (N when there was none). The newest round ([latest]) is a white card; the nine before it
/// are dark purple cards with light writing. A null round draws an empty slot.
class LuckyCardResultTile extends StatelessWidget {
  const LuckyCardResultTile({super.key, required this.layout, required this.art, required this.round, this.latest = false});

  final LuckyCardLayout layout;
  final LuckyCardArt art;

  /// Null draws an empty slot.
  final LuckyCardRecentRound? round;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final round = this.round;
    if (round == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(color: Color(0x1FFFFFFF), borderRadius: BorderRadius.all(Radius.circular(6))),
        child: SizedBox.expand(),
      );
    }
    final card = round.winningCard;
    final hasBonus = round.bonusMultiplier > 1;
    final letterColor = latest ? kDesignTileLetter : kDesignOldTileLetter;
    final bonusColor = hasBonus ? (latest ? kDesignTileBonus : kDesignOldTileBonus) : (latest ? kDesignTileNoBonus : kDesignOldTileNoBonus);
    return Semantics(
      label: '${latest ? 'Latest result: ' : 'Earlier result: '}${luckyCardResultSemantics(round)}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: latest ? kDesignTileFill : kDesignOldTileFill),
          border: latest ? null : Border.all(color: kDesignOldTileEdge, width: 1),
          boxShadow: [BoxShadow(color: latest ? kDesignTileUnder : kDesignOldTileUnder, offset: const Offset(0, 3))],
        ),
        child: LayoutBuilder(
          builder: (context, c) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    luckyCardResultRank(card),
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: 'Oswald',
                      fontWeight: FontWeight.w700,
                      fontSize: LuckyCardLayout.designTileLetterFont,
                      height: 1.0,
                      color: letterColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  _suitPicture(layout, art, context, card.suit, LuckyCardLayout.designTileIcon),
                ],
              ),
              const SizedBox(height: 1),
              SizedBox(
                height: LuckyCardLayout.designTileBonusFont,
                child: LuckyCardStakeText(
                  luckyCardBonusLabel(round.bonusMultiplier),
                  maxWidth: c.maxWidth,
                  preferredSize: LuckyCardLayout.designTileBonusFont,
                  color: bonusColor,
                  shadowColor: const Color(0x00000000),
                  weight: FontWeight.w700,
                  shadowBlur: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ten latest rounds, two rows of five, newest first. [history] is newest first.
class LuckyCardResultsPanel extends StatelessWidget {
  const LuckyCardResultsPanel({super.key, required this.layout, required this.art, required this.history});

  final LuckyCardLayout layout;
  final LuckyCardArt art;
  final List<LuckyCardRecentRound> history;

  @override
  Widget build(BuildContext context) {
    final panel = layout.resultsPanel;
    Rect inPanel(Rect r) => layout.within(panel, r);
    LuckyCardRecentRound? at(int i) => i < history.length ? history[i] : null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: kDesignResultsFill),
            ),
          ),
        ),
        for (var i = 0; i < LuckyCardLayout.designResultTiles; i++)
          Positioned.fromRect(
            rect: inPanel(layout.resultTile(i)),
            child: LuckyCardResultTile(
              // The newest keeps its own name; the nine before it are result-0 to result-8.
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

/// Loads the four suit icons into the image cache, so the results never pop in.
Future<void> precacheLuckyCardResults(BuildContext context, LuckyCardLayout layout, LuckyCardArt art) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return Future.wait([
    for (final suit in LuckyCardSuit.values)
      precacheImage(art.image(LuckyCardArtKey.suitIcon(suit), cacheWidth: layout.resultIconCacheWidth(dpr)), context),
  ]);
}
