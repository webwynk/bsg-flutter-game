// The whole betting board, assembled: the suit headers and the 16 cards in the grid
// zone, the four rank selectors in the rank column. Given a snapshot and the tap
// handlers, nothing else: no provider, no server (the binding in
// lucky16_board_binding.dart connects it to the provider).
//
// The canvas places the two zones; this hands it a builder for each:
//
//   Lucky16Canvas(grid: zones.grid, rankColumn: zones.rankColumn, ...)
//
// Every tap that is refused, whichever piece it was on, arrives at one callback
// that says which card, suit or rank it was and why.
//
// Copied from lib/widgets/lucky_card/lucky_card_board_view.dart (Lucky Card); the names changed, and the
// counts are Lucky 16 Card's (16 cards, 4 on a suit bar, 4 rank selectors A, J, Q, K).
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky16_board.dart';
import '../../models/lucky16_models.dart';
import 'lucky16_art.dart';
import 'lucky16_board_snapshot.dart';
import 'lucky16_cards.dart';
import 'lucky16_layout.dart';
import 'lucky16_shortcuts.dart';

/// What a refused tap was on.
sealed class Lucky16BoardTarget {
  const Lucky16BoardTarget();
}

final class Lucky16CardTarget extends Lucky16BoardTarget {
  const Lucky16CardTarget(this.card);

  final Lucky16Card card;

  @override
  bool operator ==(Object other) => other is Lucky16CardTarget && other.card == card;

  @override
  int get hashCode => card.hashCode;

  @override
  String toString() => 'card ${card.key}';
}

final class Lucky16SuitTarget extends Lucky16BoardTarget {
  const Lucky16SuitTarget(this.suit);

  final Lucky16Suit suit;

  @override
  bool operator ==(Object other) => other is Lucky16SuitTarget && other.suit == suit;

  @override
  int get hashCode => suit.hashCode;

  @override
  String toString() => 'suit ${suit.dbValue}';
}

final class Lucky16RankTarget extends Lucky16BoardTarget {
  const Lucky16RankTarget(this.rank);

  final Lucky16Rank rank;

  @override
  bool operator ==(Object other) => other is Lucky16RankTarget && other.rank == rank;

  @override
  int get hashCode => rank.hashCode;

  @override
  String toString() => 'rank ${rank.dbValue}';
}

/// Called when any tap on the board was refused (in whole or in part).
typedef Lucky16BoardRefused = void Function(Lucky16BoardTarget target, Set<Lucky16BoardIssue> issues);

class Lucky16BoardZones {
  const Lucky16BoardZones({
    required this.art,
    required this.snapshot,
    required this.onTapCard,
    required this.onTapSuit,
    required this.onTapRank,
    this.onRefused,
  });

  final Lucky16Art art;
  final Lucky16BoardSnapshot snapshot;
  final Lucky16CardTap onTapCard;
  final Lucky16SuitTap onTapSuit;
  final Lucky16RankTap onTapRank;
  final Lucky16BoardRefused? onRefused;

  /// The grid zone: four suit headers over the 16 cards.
  Widget grid(BuildContext context, Lucky16Layout layout) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final suit in Lucky16Suit.values)
          Positioned.fromRect(
            rect: layout.suitHeader(suit.index).shift(-layout.grid.topLeft),
            child: Lucky16SuitHeader(
              key: ValueKey('suit-${suit.dbValue}'),
              suit: suit,
              layout: layout,
              art: art,
              total: snapshot.suitTotal(suit),
              isLocked: snapshot.isLocked,
              onTap: onTapSuit,
              onRefused: onRefused == null ? null : (s, issues) => onRefused!(Lucky16SuitTarget(s), issues),
            ),
          ),
        Positioned.fill(
          child: Lucky16CardLayer(
            layout: layout,
            art: art,
            snapshot: snapshot,
            onTapCard: onTapCard,
            onRefused: onRefused == null ? null : (c, issues) => onRefused!(Lucky16CardTarget(c), issues),
          ),
        ),
      ],
    );
  }

  /// The rank column: the four selectors, level with the card rows.
  Widget rankColumn(BuildContext context, Lucky16Layout layout) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final rank in Lucky16Rank.values)
          Positioned.fromRect(
            rect: layout.rankSelector(rank.index).shift(-layout.rankColumn.topLeft),
            child: Lucky16RankSelector(
              key: ValueKey('rank-${rank.dbValue}'),
              rank: rank,
              layout: layout,
              art: art,
              total: snapshot.rankTotal(rank),
              isLocked: snapshot.isLocked,
              onTap: onTapRank,
              onRefused: onRefused == null ? null : (r, issues) => onRefused!(Lucky16RankTarget(r), issues),
            ),
          ),
      ],
    );
  }
}

/// Loads the 24 board pictures into the image cache at exactly the sizes the
/// widgets draw them, so nothing pops in when the screen opens. The chips are
/// loaded with the chip rail.
Future<void> precacheLucky16Board(BuildContext context, Lucky16Layout layout, Lucky16Art art) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return Future.wait([
    for (final card in Lucky16Card.all)
      precacheImage(art.image(Lucky16ArtKey.card(card), cacheWidth: layout.cardCacheWidth(dpr)), context),
    for (final suit in Lucky16Suit.values)
      precacheImage(art.image(Lucky16ArtKey.suitBar(suit), cacheWidth: layout.barCacheWidth(dpr)), context),
    for (final rank in Lucky16Rank.values)
      precacheImage(art.image(Lucky16ArtKey.rankSelector(rank), cacheWidth: layout.selectorCacheWidth(dpr)), context),
  ]);
}
