// The side column's readouts: PLAY and WIN, the limits, and the results.
//
// Given plain values, nothing else: no provider (lucky_card_readouts_binding.dart
// connects them).
//
//   * PLAY is what the player has on the board (the stake); WIN is what the last
//     round paid, written "+1500" for a win and "0" otherwise.
//   * The limits are fixed numbers from the spec (§8): the smallest stake 5 pays 50
//     at most before the bonus, the largest stake 50,000 pays 500,000 (IN is what
//     you stake, OUT is what it can pay).
//   * The results show the latest round large and the nine before it in a 3 x 3
//     grid: the suit's gold icon, the rank letter and the bonus (N, 2X to 10X).
//     Missing rounds (a new table) are empty tiles.
//   * All text is at least 11 dp and never follows the phone's font-size setting.
//
// Belongs to Lucky Card only.

import 'package:flutter/material.dart';

import '../../models/lucky_card_models.dart';
import 'lucky_card_art.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_panel.dart';
import 'lucky_card_stake_text.dart';

/// The fixed limits of the game (spec §8). IN is the stake, OUT what it can pay at
/// most before the bonus.
abstract final class LuckyCardLimits {
  static const int minIn = 5;
  static const int minOut = 50;
  static const int maxIn = 50000;
  static const int maxOut = 500000;
}

/// What the WIN cell says: "+1500" for a win, "0" for anything else.
String luckyCardWinText(int payout) => payout > 0 ? '+${luckyCardGrouped(payout)}' : '0';

/// What a result tile says under or beside its icon: the rank letter.
String luckyCardResultRank(LuckyCard card) => card.rank.dbValue;

/// What a screen reader says for a result.
String luckyCardResultSemantics(LuckyCardRecentRound round) {
  final bonus = round.bonusMultiplier > 1 ? ', bonus ${luckyCardBonusLabel(round.bonusMultiplier)}' : ', no bonus';
  return '${round.winningCard.rank.label} of ${round.winningCard.suit.label}$bonus';
}

/// PLAY or WIN: a small label over a big number.
class LuckyCardAmountCell extends StatelessWidget {
  const LuckyCardAmountCell({
    super.key,
    required this.layout,
    required this.label,
    required this.value,
    this.valueColor = kLuckyCardCream,
    this.highlighted = false,
  });

  final LuckyCardLayout layout;
  final String label;
  final String value;
  final Color valueColor;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: LuckyCardPanel(
        layout: layout,
        highlighted: highlighted,
        padding: EdgeInsets.symmetric(horizontal: layout.dp(10), vertical: layout.dp(2)),
        child: LayoutBuilder(
          builder: (context, c) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: layout.fontSize(30) * 1.1,
                child: LuckyCardStakeText(label, maxWidth: c.maxWidth, preferredSize: layout.fontSize(30), color: kLuckyCardGold),
              ),
              SizedBox(
                height: layout.fontSize(46) * 1.1,
                child: LuckyCardStakeText(value, maxWidth: c.maxWidth, preferredSize: layout.fontSize(46), color: valueColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// MIN and MAX.
class LuckyCardLimitsPanel extends StatelessWidget {
  const LuckyCardLimitsPanel({super.key, required this.layout});

  final LuckyCardLayout layout;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Limits. Minimum: stake ${LuckyCardLimits.minIn}, pays up to ${LuckyCardLimits.minOut}. '
          'Maximum: stake ${luckyCardGrouped(LuckyCardLimits.maxIn)}, pays up to ${luckyCardGrouped(LuckyCardLimits.maxOut)}.',
      excludeSemantics: true,
      child: LuckyCardPanel(
        layout: layout,
        padding: EdgeInsets.symmetric(horizontal: layout.dp(14), vertical: layout.dp(6)),
        child: Column(
          children: [
            Expanded(child: _row('MIN', LuckyCardLimits.minIn, LuckyCardLimits.minOut)),
            Expanded(child: _row('MAX', LuckyCardLimits.maxIn, LuckyCardLimits.maxOut)),
          ],
        ),
      ),
    );
  }

  Widget _row(String name, int stake, int pays) {
    return LayoutBuilder(
      builder: (context, c) {
        // The name, the stake and the payout share the row 2 : 4 : 5.
        final w = c.maxWidth / 11;
        Widget cell(String text, double width, Color color) => SizedBox(
              width: width,
              child: LuckyCardStakeText(text, maxWidth: width, preferredSize: layout.fontSize(30), color: color),
            );
        return Row(
          children: [
            cell(name, w * 2, kLuckyCardGold),
            cell('IN ${luckyCardGrouped(stake)}', w * 4, kLuckyCardCream),
            cell('OUT ${luckyCardGrouped(pays)}', w * 5, kLuckyCardCream),
          ],
        );
      },
    );
  }
}

Color _suitColor(LuckyCardSuit suit) => suit.isRed ? const Color(0xFFFF6B5E) : kLuckyCardCream;

/// One finished round: the suit's icon, the rank and the bonus. [large] is the
/// latest result, drawn wide with everything in one row.
class LuckyCardResultTile extends StatelessWidget {
  const LuckyCardResultTile({
    super.key,
    required this.layout,
    required this.art,
    required this.round,
    this.large = false,
  });

  final LuckyCardLayout layout;
  final LuckyCardArt art;

  /// Null draws an empty tile.
  final LuckyCardRecentRound? round;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final round = this.round;
    final panel = LuckyCardPanel(
      layout: layout,
      highlighted: large && round != null,
      dimmed: round == null,
      radiusUnits: large ? 18 : 12,
      padding: EdgeInsets.all(layout.dp(4)),
      child: round == null ? const SizedBox.expand() : _content(context, round),
    );
    if (round == null) return panel;
    return Semantics(
      label: '${large ? 'Latest result: ' : 'Earlier result: '}${luckyCardResultSemantics(round)}',
      excludeSemantics: true,
      child: panel,
    );
  }

  Widget _content(BuildContext context, LuckyCardRecentRound round) {
    final card = round.winningCard;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final side = large ? layout.resultCurrentIcon : layout.resultTileIcon;
    final icon = Image(
      image: art.image(LuckyCardArtKey.suitIcon(card.suit), cacheWidth: layout.resultIconCacheWidth(dpr)),
      width: side,
      height: side,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
    final rank = luckyCardResultRank(card);
    final bonus = luckyCardBonusLabel(round.bonusMultiplier);
    final hasBonus = round.bonusMultiplier > 1;
    return LayoutBuilder(
      builder: (context, c) {
        final textUnits = large ? 56.0 : 32.0;
        Widget text(String value, Color color, double width) => SizedBox(
              width: width,
              child: LuckyCardStakeText(value, maxWidth: width, preferredSize: layout.fontSize(textUnits), color: color),
            );
        if (large) {
          // One row: icon, rank, bonus.
          final rest = (c.maxWidth - side) / 2;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              text(rank, _suitColor(card.suit), rest),
              text(bonus, hasBonus ? kLuckyCardGoldBright : kLuckyCardGold, rest),
            ],
          );
        }
        // The icon over a line holding the rank and the bonus.
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            SizedBox(height: layout.dp(2)),
            SizedBox(
              height: layout.fontSize(textUnits) * 1.1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  text(rank, _suitColor(card.suit), c.maxWidth * 0.34),
                  text(bonus, hasBonus ? kLuckyCardGoldBright : kLuckyCardGold, c.maxWidth * 0.5),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The latest result and the nine before it. [history] is newest first.
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
        Positioned.fill(child: LuckyCardPanel(layout: layout, radiusUnits: 20, child: const SizedBox.expand())),
        Positioned.fromRect(
          rect: inPanel(layout.resultCurrent),
          child: LuckyCardResultTile(key: const ValueKey('result-latest'), layout: layout, art: art, round: at(0), large: true),
        ),
        for (var i = 0; i < 9; i++)
          Positioned.fromRect(
            rect: inPanel(layout.resultTile(i)),
            child: LuckyCardResultTile(key: ValueKey('result-$i'), layout: layout, art: art, round: at(i + 1)),
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
