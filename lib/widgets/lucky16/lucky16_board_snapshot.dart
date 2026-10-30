// What the board widgets need to know about the player's board, and nothing else:
// the 16 stakes, the 8 totals the labels show, whether the board is locked, and
// the chip in hand. Immutable, and equal to another snapshot when nothing differs,
// so a screen that rebuilds every second (the countdown) does not redraw the board
// unless the board changed.
//
// The widgets take this instead of the provider so they are tested without a game
// or a server; the screen (App Step 8) builds one from the provider.
//
// Copied from lib/widgets/lucky_card/lucky_card_board_snapshot.dart (Lucky Card); the names changed, and the
// counts are Lucky 16 Card's (16 cards, 4 on a suit bar, 4 rank selectors A, J, Q, K).
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/foundation.dart';

import '../../models/lucky16_board.dart';
import '../../models/lucky16_models.dart';

@immutable
class Lucky16BoardSnapshot {
  const Lucky16BoardSnapshot._(this._stakes, this.isLocked, this.activeChip);

  /// The board as the player has built it: [stakes] holds an amount per card (a
  /// card left out holds nothing). Every total is worked out from the 16 stakes,
  /// never stored separately, so the labels can never disagree with the cards
  /// (spec §3.1, rule 5).
  factory Lucky16BoardSnapshot.fromStakes(
    Map<Lucky16Card, int> stakes, {
    bool isLocked = false,
    Lucky16Chip? activeChip,
  }) {
    final all = <Lucky16Card, int>{
      for (final card in Lucky16Card.all) card: stakes[card] ?? 0,
    };
    assert(all.values.every((v) => v >= 0), 'a stake cannot be negative');
    return Lucky16BoardSnapshot._(Map.unmodifiable(all), isLocked, activeChip);
  }

  /// An empty, unlocked board with no chip in hand.
  factory Lucky16BoardSnapshot.empty() => Lucky16BoardSnapshot.fromStakes(const {});

  final Map<Lucky16Card, int> _stakes;

  /// True while the player cannot place or remove chips.
  final bool isLocked;

  /// The chip in hand, or null when none is held (taps then remove chips).
  final Lucky16Chip? activeChip;

  int stakeOn(Lucky16Card card) => _stakes[card] ?? 0;

  /// The sum of a suit's four cards.
  int suitTotal(Lucky16Suit suit) => Lucky16Card.ofSuit(suit).fold(0, (sum, card) => sum + stakeOn(card));

  /// The sum of a rank's four cards.
  int rankTotal(Lucky16Rank rank) => Lucky16Card.ofRank(rank).fold(0, (sum, card) => sum + stakeOn(card));

  /// The sum of all 16 cards: what the player is staking this round.
  int get total => _stakes.values.fold(0, (sum, v) => sum + v);

  bool get isEmpty => total == 0;

  @override
  bool operator ==(Object other) =>
      other is Lucky16BoardSnapshot &&
      other.isLocked == isLocked &&
      other.activeChip == activeChip &&
      mapEquals(other._stakes, _stakes);

  @override
  int get hashCode => Object.hash(isLocked, activeChip, Object.hashAll(_stakes.values));
}
