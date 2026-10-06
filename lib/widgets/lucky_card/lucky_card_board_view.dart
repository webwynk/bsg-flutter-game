// The whole betting board, assembled: the suit headers and the 12 cards in the grid
// zone, the three rank selectors in the rank column. Given a snapshot and the tap
// handlers, nothing else: no provider, no server (the binding in
// lucky_card_board_binding.dart connects it to the provider).
//
// The canvas places the two zones; this hands it a builder for each:
//
//   LuckyCardCanvas(grid: zones.grid, rankColumn: zones.rankColumn, ...)
//
// Every tap that is refused, whichever piece it was on, arrives at one callback
// that says which card, suit or rank it was and why.
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky_card_board.dart';
import '../../models/lucky_card_models.dart';
import 'lucky_card_art.dart';
import 'lucky_card_board_snapshot.dart';
import 'lucky_card_cards.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_shortcuts.dart';

/// What a refused tap was on.
sealed class LuckyCardBoardTarget {
  const LuckyCardBoardTarget();
}

final class LuckyCardCardTarget extends LuckyCardBoardTarget {
  const LuckyCardCardTarget(this.card);

  final LuckyCard card;

  @override
  bool operator ==(Object other) => other is LuckyCardCardTarget && other.card == card;

  @override
  int get hashCode => card.hashCode;

  @override
  String toString() => 'card ${card.key}';
}

final class LuckyCardSuitTarget extends LuckyCardBoardTarget {
  const LuckyCardSuitTarget(this.suit);

  final LuckyCardSuit suit;

  @override
  bool operator ==(Object other) => other is LuckyCardSuitTarget && other.suit == suit;

  @override
  int get hashCode => suit.hashCode;

  @override
  String toString() => 'suit ${suit.dbValue}';
}

final class LuckyCardRankTarget extends LuckyCardBoardTarget {
  const LuckyCardRankTarget(this.rank);

  final LuckyCardRank rank;

  @override
  bool operator ==(Object other) => other is LuckyCardRankTarget && other.rank == rank;

  @override
  int get hashCode => rank.hashCode;

  @override
  String toString() => 'rank ${rank.dbValue}';
}

/// Called when any tap on the board was refused (in whole or in part).
typedef LuckyCardBoardRefused = void Function(LuckyCardBoardTarget target, Set<LuckyCardBoardIssue> issues);

class LuckyCardBoardZones {
  const LuckyCardBoardZones({
    required this.art,
    required this.snapshot,
    required this.onTapCard,
    required this.onTapSuit,
    required this.onTapRank,
    this.onRefused,
  });

  final LuckyCardArt art;
  final LuckyCardBoardSnapshot snapshot;
  final LuckyCardCardTap onTapCard;
  final LuckyCardSuitTap onTapSuit;
  final LuckyCardRankTap onTapRank;
  final LuckyCardBoardRefused? onRefused;

  /// The grid zone: four suit headers over the 12 cards.
  Widget grid(BuildContext context, LuckyCardLayout layout) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final suit in LuckyCardSuit.values)
          Positioned.fromRect(
            rect: layout.suitHeader(suit.index).shift(-layout.grid.topLeft),
            child: LuckyCardSuitHeader(
              key: ValueKey('suit-${suit.dbValue}'),
              suit: suit,
              layout: layout,
              art: art,
              total: snapshot.suitTotal(suit),
              isLocked: snapshot.isLocked,
              onTap: onTapSuit,
              onRefused: onRefused == null ? null : (s, issues) => onRefused!(LuckyCardSuitTarget(s), issues),
            ),
          ),
        Positioned.fill(
          child: LuckyCardCardLayer(
            layout: layout,
            art: art,
            snapshot: snapshot,
            onTapCard: onTapCard,
            onRefused: onRefused == null ? null : (c, issues) => onRefused!(LuckyCardCardTarget(c), issues),
          ),
        ),
      ],
    );
  }

  /// The rank column: the three selectors, level with the card rows.
  Widget rankColumn(BuildContext context, LuckyCardLayout layout) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final rank in LuckyCardRank.values)
          Positioned.fromRect(
            rect: layout.rankSelector(rank.index).shift(-layout.rankColumn.topLeft),
            child: LuckyCardRankSelector(
              key: ValueKey('rank-${rank.dbValue}'),
              rank: rank,
              layout: layout,
              art: art,
              total: snapshot.rankTotal(rank),
              isLocked: snapshot.isLocked,
              onTap: onTapRank,
              onRefused: onRefused == null ? null : (r, issues) => onRefused!(LuckyCardRankTarget(r), issues),
            ),
          ),
      ],
    );
  }
}

/// Loads the 19 board pictures into the image cache at exactly the sizes the
/// widgets draw them, so nothing pops in when the screen opens. The chips are
/// loaded with the chip rail.
Future<void> precacheLuckyCardBoard(BuildContext context, LuckyCardLayout layout, LuckyCardArt art) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return Future.wait([
    for (final card in LuckyCard.all)
      precacheImage(art.image(LuckyCardArtKey.card(card), cacheWidth: layout.cardCacheWidth(dpr)), context),
    for (final suit in LuckyCardSuit.values)
      precacheImage(art.image(LuckyCardArtKey.suitBar(suit), cacheWidth: layout.barCacheWidth(dpr)), context),
    for (final rank in LuckyCardRank.values)
      precacheImage(art.image(LuckyCardArtKey.rankSelector(rank), cacheWidth: layout.selectorCacheWidth(dpr)), context),
  ]);
}
