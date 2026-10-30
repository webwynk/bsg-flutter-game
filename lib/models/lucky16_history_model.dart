// One line of the player's Lucky 16 Card history: a round they bet on and how it
// ended for them.
//
// Copied from lib/models/lucky_card_history_model.dart (Lucky Card); only the
// names changed (the rows come from lucky16_bets with lucky16_rounds embedded,
// and a winning card may now be an A).
//
// Pure Dart, like lucky16_models.dart: nothing here talks to the network or the
// screen. Parsing is checked against test/lucky16/fixtures/history_rows.json,
// adapted from Lucky Card's live capture (see fixtures/README.md). A row that is not shaped as expected
// throws, so a changed database column is caught loudly instead of becoming a wrong
// line in a real-money history.
//
// Belongs to Lucky 16 Card only; it does not reuse Triple Chance's SpinResult or
// Lucky Card's history entry.

import 'package:flutter/foundation.dart';

import '../services/lucky16_api_contract.dart';
import 'lucky16_models.dart';

@immutable
class Lucky16HistoryEntry {
  const Lucky16HistoryEntry({
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
  final Lucky16Card winningCard;

  /// The bonus that round was paid with (1 = N, 2 to 10).
  final int bonusMultiplier;

  /// What the player staked in that round (`lucky16_bets.total_stake`).
  final int stake;

  /// What the player was paid (`lucky16_bets.total_payout`); 0 for a losing bet.
  final int payout;

  /// When the bet was placed.
  final DateTime placedAt;

  /// A round is a win when anything was paid, as Triple Chance counts it.
  bool get won => payout > 0;

  /// Builds a line from one row of `lucky16_bets` with its round embedded under
  /// `lucky16_rounds`. Throws a [FormatException] (or a [TypeError]) when the row
  /// is not shaped as expected, including a round that is missing or has no result.
  factory Lucky16HistoryEntry.fromRow(Map<String, dynamic> row) {
    final round = row[Lucky16Table.rounds];
    if (round is! Map) {
      throw const FormatException('Lucky 16 Card history row has no round');
    }
    return Lucky16HistoryEntry(
      roundId: row[Lucky16Field.roundId] as String,
      roundNumber: (round[Lucky16Field.roundNumber] as num).toInt(),
      winningCard: Lucky16Card(
        Lucky16Rank.fromDb(round[Lucky16Field.winningRank] as String),
        Lucky16Suit.fromDb(round[Lucky16Field.winningSuit] as String),
      ),
      bonusMultiplier: (round[Lucky16Field.bonusMultiplier] as num).toInt(),
      stake: (row[Lucky16Field.totalStake] as num).toInt(),
      payout: (row[Lucky16Field.totalPayout] as num).toInt(),
      placedAt: DateTime.parse(row[Lucky16Field.createdAt] as String),
    );
  }
}
