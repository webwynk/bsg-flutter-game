// One line of the player's Spin2Win history: a round they bet on and how it
// ended for them.
//
// Pure Dart, like spin2win_models.dart: nothing here talks to the network or the
// screen. Parsing is checked against rows shaped as the history query returns them
// (test/spin2win/fixtures/history_rows.json). A row that is not shaped as expected
// throws, so a changed database column is caught loudly instead of becoming a wrong
// line in a real-money history.
//
// Belongs to Spin2Win only; it does not reuse Triple Chance's SpinResult or
// Lucky Card's history entry.

import 'package:flutter/foundation.dart';

import '../services/spin2win_api_contract.dart';
import 'spin2win_models.dart';

@immutable
class Spin2WinHistoryEntry {
  const Spin2WinHistoryEntry({
    required this.roundId,
    required this.roundNumber,
    required this.winningNumber,
    required this.bonusMultiplier,
    required this.stake,
    required this.payout,
    required this.placedAt,
  });

  final String roundId;

  /// The readable round number shown in the table and the popup, for example 17403942.
  final int roundNumber;

  /// The number that won that round, 0 to 9.
  final int winningNumber;

  /// The bonus that round was paid with (1 = N, 2 to 4).
  final int bonusMultiplier;

  /// What the player staked in that round (`spin2win_bets.total_stake`).
  final int stake;

  /// What the player was paid (`spin2win_bets.total_payout`); 0 for a losing bet.
  final int payout;

  /// When the bet was placed.
  final DateTime placedAt;

  /// A round is a win when anything was paid, as Triple Chance counts it.
  bool get won => payout > 0;

  /// Builds a line from one row of `spin2win_bets` with its round embedded under
  /// `spin2win_rounds`. Throws a [FormatException] (or a [TypeError]) when the row
  /// is not shaped as expected, including a round that is missing or has no result.
  factory Spin2WinHistoryEntry.fromRow(Map<String, dynamic> row) {
    final round = row[Spin2WinTable.rounds];
    if (round is! Map) {
      throw const FormatException('Spin2Win history row has no round');
    }
    return Spin2WinHistoryEntry(
      roundId: row[Spin2WinField.roundId] as String,
      roundNumber: (round[Spin2WinField.roundNumber] as num).toInt(),
      winningNumber: spin2WinNumberFromDb(round[Spin2WinField.winningNumber]),
      bonusMultiplier: (round[Spin2WinField.bonusMultiplier] as num).toInt(),
      stake: (row[Spin2WinField.totalStake] as num).toInt(),
      payout: (row[Spin2WinField.totalPayout] as num).toInt(),
      placedAt: DateTime.parse(row[Spin2WinField.createdAt] as String),
    );
  }
}
