// One line of the player's Lucky Card history: a round they bet on and how it
// ended for them.
//
// Pure Dart, like lucky_card_models.dart: nothing here talks to the network or the
// screen. Parsing is checked against real rows captured from the live database
// (test/lucky_card/fixtures/history_rows.json). A row that is not shaped as expected
// throws, so a changed database column is caught loudly instead of becoming a wrong
// line in a real-money history.
//
// Belongs to Lucky Card only; it does not reuse Triple Chance's SpinResult.

import 'package:flutter/foundation.dart';

import '../services/lucky_card_api_contract.dart';
import 'lucky_card_models.dart';

@immutable
class LuckyCardHistoryEntry {
  const LuckyCardHistoryEntry({
    required this.roundId,
    required this.roundNumber,
    required this.winningCard,
    required this.bonusMultiplier,
    required this.stake,
    required this.payout,
    required this.placedAt,
  });

  final String roundId;

  /// The readable round number shown in the table and the popup, for example 17403942.
  final int roundNumber;

  /// The card that won that round.
  final LuckyCard winningCard;

  /// The bonus that round was paid with (1 = N, 2 to 10).
  final int bonusMultiplier;

  /// What the player staked in that round (`lucky_card_bets.total_stake`).
  final int stake;

  /// What the player was paid (`lucky_card_bets.total_payout`); 0 for a losing bet.
  final int payout;

  /// When the bet was placed.
  final DateTime placedAt;

  /// A round is a win when anything was paid, as Triple Chance counts it.
  bool get won => payout > 0;

  /// Builds a line from one row of `lucky_card_bets` with its round embedded under
  /// `lucky_card_rounds`. Throws a [FormatException] (or a [TypeError]) when the row
  /// is not shaped as expected, including a round that is missing or has no result.
  factory LuckyCardHistoryEntry.fromRow(Map<String, dynamic> row) {
    final round = row[LuckyCardTable.rounds];
    if (round is! Map) {
      throw const FormatException('Lucky Card history row has no round');
    }
    return LuckyCardHistoryEntry(
      roundId: row[LuckyCardField.roundId] as String,
      roundNumber: (round[LuckyCardField.roundNumber] as num).toInt(),
      winningCard: LuckyCard(
        LuckyCardRank.fromDb(round[LuckyCardField.winningRank] as String),
        LuckyCardSuit.fromDb(round[LuckyCardField.winningSuit] as String),
      ),
      bonusMultiplier: (round[LuckyCardField.bonusMultiplier] as num).toInt(),
      stake: (row[LuckyCardField.totalStake] as num).toInt(),
      payout: (row[LuckyCardField.totalPayout] as num).toInt(),
      placedAt: DateTime.parse(row[LuckyCardField.createdAt] as String),
    );
  }
}
