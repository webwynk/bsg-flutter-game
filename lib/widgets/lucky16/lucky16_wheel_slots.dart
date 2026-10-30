// Which slot of each rim the Lucky 16 Card wheel stops on for a given card.
//
// Copied from lib/widgets/lucky_card/lucky_card_wheel_slots.dart (Lucky Card), with Lucky 16's four
// ranks. The wheel has two rims of 12 segments each:
//   * the outer rim, segment i, carries the rank letter [kLucky16WheelRanks][i mod 4]: A J K Q A J K Q
//     A J K Q (the order Hasan chose, 2026-10-28; not the A J Q K the mockup drew), so each rank has
//     three segments;
//   * the inner rim, segment i, carries the suit [kLucky16WheelSuits][i mod 4]: diamonds, clubs,
//     hearts, spades, repeated, so each suit has three segments (exactly Lucky Card's inner rim).
// Segments are numbered 0 to 11 clockwise from the top.
//
// The server decides the card; which of its three outer and three inner segments the wheel stops on
// is purely cosmetic. It is worked out from the round number, the way Lucky Card does it, so every
// player sees the same wheel position in the same round and it still varies from round to round. It
// never reaches the ledger and nothing about the result can be read from it.
//
// Belongs to Lucky 16 Card only.

import '../../models/lucky16_models.dart';

/// The letters on the outer rim, in segment order (Hasan's choice: A J K Q).
const List<String> kLucky16WheelRanks = ['A', 'J', 'K', 'Q'];

/// The suits on the inner rim, in segment order (Lucky Card's).
const List<Lucky16Suit> kLucky16WheelSuits = [
  Lucky16Suit.diamonds,
  Lucky16Suit.clubs,
  Lucky16Suit.hearts,
  Lucky16Suit.spades,
];

/// Segments on each rim.
const int kLucky16WheelSegments = 12;

/// The two segments the wheel stops on.
class Lucky16WheelStop {
  const Lucky16WheelStop(this.outerIndex, this.innerIndex);

  /// The outer-rim segment (0 to 11) that ends under the pointer: carries the rank.
  final int outerIndex;

  /// The inner-rim segment (0 to 11) that ends under the pointer: carries the suit.
  final int innerIndex;

  @override
  bool operator ==(Object other) =>
      other is Lucky16WheelStop && other.outerIndex == outerIndex && other.innerIndex == innerIndex;

  @override
  int get hashCode => Object.hash(outerIndex, innerIndex);

  @override
  String toString() => 'Lucky16WheelStop(outer $outerIndex, inner $innerIndex)';
}

/// The segments of the two rims that carry [card]'s rank and suit, and which of them this round uses
/// (Lucky Card's rule with Lucky 16's counts): the outer one is the candidate at `roundNumber mod 3`,
/// the inner one the candidate at `(roundNumber div 3) mod 3`.
Lucky16WheelStop lucky16WheelStopFor(Lucky16Card card, int roundNumber) {
  final rankPosition = kLucky16WheelRanks.indexOf(card.rank.dbValue);
  final suitPosition = kLucky16WheelSuits.indexOf(card.suit);
  assert(rankPosition >= 0 && suitPosition >= 0, 'every card has a segment on each rim');
  final outerCandidates = kLucky16WheelSegments ~/ kLucky16WheelRanks.length; // 3
  final innerCandidates = kLucky16WheelSegments ~/ kLucky16WheelSuits.length; // 3
  final outerStep = roundNumber % outerCandidates;
  final innerStep = (roundNumber ~/ outerCandidates) % innerCandidates;
  return Lucky16WheelStop(
    rankPosition + outerStep * kLucky16WheelRanks.length,
    suitPosition + innerStep * kLucky16WheelSuits.length,
  );
}

/// The card that the segments under the pointer spell out.
Lucky16Card lucky16CardAtWheelStop(int outerIndex, int innerIndex) => Lucky16Card(
      Lucky16Rank.fromDb(kLucky16WheelRanks[outerIndex % kLucky16WheelRanks.length]),
      kLucky16WheelSuits[innerIndex % kLucky16WheelSuits.length],
    );
