// What the board widgets need to know about the player's board, and nothing else:
// the 12 stakes, the 7 totals the labels show, whether the board is locked, and
// the chip in hand. Immutable, and equal to another snapshot when nothing differs,
// so a screen that rebuilds every second (the countdown) does not redraw the board
// unless the board changed.
//
// The widgets take this instead of the provider so they are tested without a game
// or a server; the screen (App Step 8) builds one from the provider.
//
// Belongs to Lucky Card only.

import 'package:flutter/foundation.dart';

import '../../models/lucky_card_board.dart';
import '../../models/lucky_card_models.dart';

@immutable
class LuckyCardBoardSnapshot {
  const LuckyCardBoardSnapshot._(this._stakes, this.isLocked, this.activeChip);

  /// The board as the player has built it: [stakes] holds an amount per card (a
  /// card left out holds nothing). Every total is worked out from the 12 stakes,
  /// never stored separately, so the labels can never disagree with the cards
  /// (spec §3.1, rule 5).
  factory LuckyCardBoardSnapshot.fromStakes(
    Map<LuckyCard, int> stakes, {
    bool isLocked = false,
    LuckyCardChip? activeChip,
  }) {
    final all = <LuckyCard, int>{
      for (final card in LuckyCard.all) card: stakes[card] ?? 0,
    };
    assert(all.values.every((v) => v >= 0), 'a stake cannot be negative');
    return LuckyCardBoardSnapshot._(Map.unmodifiable(all), isLocked, activeChip);
  }

  /// An empty, unlocked board with no chip in hand.
  factory LuckyCardBoardSnapshot.empty() => LuckyCardBoardSnapshot.fromStakes(const {});

  final Map<LuckyCard, int> _stakes;

  /// True while the player cannot place or remove chips.
  final bool isLocked;

  /// The chip in hand, or null when none is held (taps then remove chips).
  final LuckyCardChip? activeChip;

  int stakeOn(LuckyCard card) => _stakes[card] ?? 0;

  /// The sum of a suit's three cards.
  int suitTotal(LuckyCardSuit suit) =>
      LuckyCard.ofSuit(suit).fold(0, (sum, card) => sum + stakeOn(card));

  /// The sum of a rank's four cards.
  int rankTotal(LuckyCardRank rank) =>
      LuckyCard.ofRank(rank).fold(0, (sum, card) => sum + stakeOn(card));

  /// The sum of all 12 cards: what the player is staking this round.
  int get total => _stakes.values.fold(0, (sum, v) => sum + v);

  bool get isEmpty => total == 0;

  @override
  bool operator ==(Object other) =>
      other is LuckyCardBoardSnapshot &&
      other.isLocked == isLocked &&
      other.activeChip == activeChip &&
      mapEquals(other._stakes, _stakes);

  @override
  int get hashCode => Object.hash(isLocked, activeChip, Object.hashAll(_stakes.values));
}
