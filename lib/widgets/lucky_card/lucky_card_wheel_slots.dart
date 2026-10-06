// Which slot of each rim the wheel stops on for a given card.
//
// The wheel has two rims of 12 segments each (spec §7.3, Q22, Q46):
//   * the outer rim, segment i, carries the rank letter [kLuckyCardWheelRanks]
//     [i mod 3]: J K Q J K Q ... so each rank has four segments;
//   * the inner rim, segment i, carries the suit [kLuckyCardWheelSuits][i mod 4]:
//     diamonds, clubs, hearts, spades, repeated, so each suit has three segments.
// Segments are numbered 0 to 11 clockwise from the top.
//
// The server decides the card; which of its four outer and three inner segments
// the wheel stops on is purely cosmetic. It is worked out from the round number
// (the user's decision of 2026-10-06, §17S), so every player sees the same wheel
// position in the same round and it still varies from round to round. It never
// reaches the ledger and nothing about the result can be read from it.
//
// Belongs to Lucky Card only.

import '../../models/lucky_card_models.dart';

/// The letters on the outer rim, in segment order (spec Q46: J K Q).
const List<String> kLuckyCardWheelRanks = ['J', 'K', 'Q'];

/// The suits on the inner rim, in segment order.
const List<LuckyCardSuit> kLuckyCardWheelSuits = [
  LuckyCardSuit.diamonds,
  LuckyCardSuit.clubs,
  LuckyCardSuit.hearts,
  LuckyCardSuit.spades,
];

/// Segments on each rim.
const int kLuckyCardWheelSegments = 12;

/// The two segments the wheel stops on.
class LuckyCardWheelStop {
  const LuckyCardWheelStop(this.outerIndex, this.innerIndex);

  /// The outer-rim segment (0 to 11) that ends under the pointer: carries the rank.
  final int outerIndex;

  /// The inner-rim segment (0 to 11) that ends under the pointer: carries the suit.
  final int innerIndex;

  @override
  bool operator ==(Object other) =>
      other is LuckyCardWheelStop && other.outerIndex == outerIndex && other.innerIndex == innerIndex;

  @override
  int get hashCode => Object.hash(outerIndex, innerIndex);

  @override
  String toString() => 'LuckyCardWheelStop(outer $outerIndex, inner $innerIndex)';
}

/// The segments of the two rims that carry [card]'s rank and suit, and which of
/// them this round uses: the outer one is the candidate at `roundNumber mod 4`, the
/// inner one the candidate at `(roundNumber div 4) mod 3`.
LuckyCardWheelStop luckyCardWheelStopFor(LuckyCard card, int roundNumber) {
  final rankPosition = kLuckyCardWheelRanks.indexOf(card.rank.dbValue);
  final suitPosition = kLuckyCardWheelSuits.indexOf(card.suit);
  assert(rankPosition >= 0 && suitPosition >= 0, 'every card has a segment on each rim');
  final outerCandidates = kLuckyCardWheelSegments ~/ kLuckyCardWheelRanks.length; // 4
  final innerCandidates = kLuckyCardWheelSegments ~/ kLuckyCardWheelSuits.length; // 3
  final outerStep = roundNumber % outerCandidates;
  final innerStep = (roundNumber ~/ outerCandidates) % innerCandidates;
  return LuckyCardWheelStop(
    rankPosition + outerStep * kLuckyCardWheelRanks.length,
    suitPosition + innerStep * kLuckyCardWheelSuits.length,
  );
}

/// The card that the segments under the pointer spell out.
LuckyCard luckyCardAtWheelStop(int outerIndex, int innerIndex) => LuckyCard(
      LuckyCardRank.fromDb(kLuckyCardWheelRanks[outerIndex % kLuckyCardWheelRanks.length]),
      kLuckyCardWheelSuits[innerIndex % kLuckyCardWheelSuits.length],
    );
