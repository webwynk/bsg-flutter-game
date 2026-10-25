// The data Spin2Win works with: the ten numbers, a round, a bet's outcome, a
// player's result and the history list, plus the reasons a call can fail.
//
// Pure Dart: nothing here talks to the network, the screen or the sound.
// Parsing is checked against answers shaped exactly as the live Spin2Win
// functions build them (test/spin2win/fixtures/, written from migration
// 20261024250000; to be replaced by captured answers once the app runs against
// the live database). Belongs to Spin2Win only; it does not reuse or extend
// any Triple Chance or Lucky Card model.

import 'package:flutter/foundation.dart';

import '../services/spin2win_api_contract.dart';

/// The ten numbers a player can bet on, in the order of the betting grid and
/// of the database's columns `n0` to `n9`.
const List<int> kSpin2WinNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

/// The numbers the ODD button places chips on.
const List<int> kSpin2WinOddNumbers = [1, 3, 5, 7, 9];

/// The numbers the EVEN button places chips on. 0 counts as even (the user's
/// rule, 2026-10-24).
const List<int> kSpin2WinEvenNumbers = [0, 2, 4, 6, 8];

/// What a winning stake is multiplied by before the bonus: a stake of 5 on the
/// winning number pays 45 with N, 90 with 2X, 135 with 3X, 180 with 4X.
const int kSpin2WinPayoutMultiplier = 9;

/// True for 0 to 9.
bool isSpin2WinNumber(int n) => n >= 0 && n <= 9;

/// The key the database uses for a number in a bet and in the bets table,
/// `n0` to `n9`. Throws an [ArgumentError] for anything else.
String spin2WinKey(int number) {
  if (!isSpin2WinNumber(number)) {
    throw ArgumentError.value(number, 'number', 'not a Spin2Win number');
  }
  return 'n$number';
}

/// Reads a winning number from the database. Throws a [FormatException] for
/// anything that is not 0 to 9, so a changed database value is caught loudly
/// instead of becoming a wrong result.
int spin2WinNumberFromDb(Object? value) {
  if (value is num && value == value.toInt() && isSpin2WinNumber(value.toInt())) {
    return value.toInt();
  }
  throw FormatException('Unknown Spin2Win number: "$value"');
}

/// The payout for [stakeOnWinner] on the winning number with [bonus]
/// (1 = N). The server is the authority; this is for the Payout table.
int spin2WinPayout(int stakeOnWinner, int bonus) =>
    stakeOnWinner * kSpin2WinPayoutMultiplier * (bonus < 1 ? 1 : bonus);

/// The bonus as text: 1 (or less) is "N" (no bonus), otherwise "2X" to "4X".
String spin2WinBonusLabel(int bonus) => bonus <= 1 ? 'N' : '${bonus}X';

/// Why a Spin2Win call failed, as the app should treat it.
enum Spin2WinError {
  /// Not enough coins for the stake (P0112).
  insufficientCoins,

  /// A number holds less than the minimum of 5 (P0123).
  belowMin,

  /// A number holds more than the maximum of 10,000 (P0124).
  exceedsMax,

  /// Betting is over for this round, or it is not the current round (P0120,
  /// P0121). Nothing was charged.
  roundClosed,

  /// Nothing above zero was sent (P0125).
  emptyBet,

  /// The bet itself is malformed (P0126): a bug in the app, never a player
  /// mistake.
  badBet,

  /// No signed-in user, or the sign-in no longer works (P0100).
  unauthenticated,

  /// The account has been blocked (P0113).
  accountBlocked,

  /// A staff account tried to bet (P0114).
  notAPlayer,

  /// No answer: the device is offline or the request timed out.
  offline,

  /// Anything not recognised.
  unknown;

  /// True for failures that may be a passing glitch and are worth one more try,
  /// exactly the set Triple Chance retries ([offline], [unauthenticated],
  /// [unknown]). Every other reason is a final answer from the server.
  bool get isRetryable =>
      this == offline || this == unauthenticated || this == unknown;
}

/// The Spin2Win round the server clock is in.
@immutable
class Spin2WinRoundState {
  const Spin2WinRoundState({
    required this.roundId,
    required this.roundNumber,
    required this.phase,
    required this.scheduledAt,
    required this.secondsRemaining,
    required this.secondsInto,
    required this.drawAtSecond,
    this.winningNumber,
    this.bonusMultiplier,
  });

  final String roundId;
  final int roundNumber;

  /// `betting`, `drawing` or `settled`.
  final String phase;

  /// The end of this round's 100-second cycle.
  final DateTime scheduledAt;
  final int secondsRemaining;
  final int secondsInto;

  /// The second of the cycle the draw happens at (90).
  final int drawAtSecond;

  /// The winning number (0 to 9); `null` until the round is drawn.
  final int? winningNumber;

  /// The round's own pinned bonus (1 = N, 2 to 4); `null` until the draw,
  /// delivered in the same answer as [winningNumber].
  final int? bonusMultiplier;

  /// True once the winning number is known.
  bool get isDrawn => winningNumber != null;

  /// A hint that the server will still take a bet: not drawn and before the
  /// draw second. The server decides; its own cutoff is one second earlier than
  /// the draw second and is not part of the answer, so this can say true for one
  /// second in which the server already refuses, and never the other way round.
  bool get acceptsBets => !isDrawn && secondsInto < drawAtSecond;

  /// Throws a [FormatException] (or a [TypeError]) if the answer is not shaped
  /// as expected, which the API service turns into [Spin2WinError.unknown].
  factory Spin2WinRoundState.fromJson(Map<String, dynamic> j) {
    final winning = j[Spin2WinField.winningNumber];
    return Spin2WinRoundState(
      roundId: j[Spin2WinField.roundId] as String,
      roundNumber: (j[Spin2WinField.roundNumber] as num).toInt(),
      phase: j[Spin2WinField.phase] as String,
      scheduledAt: DateTime.parse(j[Spin2WinField.scheduledAt] as String),
      secondsRemaining: (j[Spin2WinField.secondsRemaining] as num).toInt(),
      secondsInto: (j[Spin2WinField.secondsInto] as num).toInt(),
      drawAtSecond: (j[Spin2WinField.drawAtSecond] as num).toInt(),
      winningNumber: winning == null ? null : spin2WinNumberFromDb(winning),
      bonusMultiplier: (j[Spin2WinField.bonusMultiplier] as num?)?.toInt(),
    );
  }
}

/// The outcome of placing a bet.
@immutable
class Spin2WinPlaceBetResult {
  const Spin2WinPlaceBetResult({
    required this.success,
    this.totalStake = 0,
    this.coinBalance = 0,
    this.ledgerVersion = 0,
    this.error,
  });

  /// A failed bet carrying only the reason; nothing was charged.
  const Spin2WinPlaceBetResult.failure(Spin2WinError this.error)
      : success = false,
        totalStake = 0,
        coinBalance = 0,
        ledgerVersion = 0;

  final bool success;

  /// The server-computed total stake of the bet now on record (the app sends no
  /// total; the database adds up the numbers).
  final int totalStake;

  /// The player's balance after the bet, as stored.
  final int coinBalance;

  /// The balance's version counter, used to ignore an older balance that
  /// arrives late.
  final int ledgerVersion;

  /// Why it failed; `null` on success.
  final Spin2WinError? error;

  factory Spin2WinPlaceBetResult.fromJson(Map<String, dynamic> j) =>
      Spin2WinPlaceBetResult(
        success: j[Spin2WinField.success] as bool? ?? true,
        totalStake: (j[Spin2WinField.totalStake] as num?)?.toInt() ?? 0,
        coinBalance: (j[Spin2WinField.coinBalance] as num?)?.toInt() ?? 0,
        ledgerVersion: (j[Spin2WinField.ledgerVersion] as num?)?.toInt() ?? 0,
      );
}

/// This player's own outcome for one round.
@immutable
class Spin2WinMyResult {
  const Spin2WinMyResult({
    required this.placedBet,
    required this.totalStake,
    required this.totalPayout,
    required this.isSettled,
    required this.coinBalance,
    required this.ledgerVersion,
  });

  /// False when the player has no bet on that round (or the round is unknown).
  final bool placedBet;
  final int totalStake;

  /// 0 until the bet is settled, and 0 for a losing bet.
  final int totalPayout;

  /// True once the bet has been scored. A big round is settled in batches, so
  /// a bet can briefly be unsettled after the draw.
  final bool isSettled;
  final int coinBalance;
  final int ledgerVersion;

  factory Spin2WinMyResult.fromJson(Map<String, dynamic> j) =>
      Spin2WinMyResult(
        placedBet: j[Spin2WinField.placedBet] as bool? ?? false,
        totalStake: (j[Spin2WinField.totalStake] as num?)?.toInt() ?? 0,
        totalPayout: (j[Spin2WinField.totalPayout] as num?)?.toInt() ?? 0,
        isSettled: j[Spin2WinField.isSettled] as bool? ?? false,
        coinBalance: (j[Spin2WinField.coinBalance] as num?)?.toInt() ?? 0,
        ledgerVersion: (j[Spin2WinField.ledgerVersion] as num?)?.toInt() ?? 0,
      );
}

/// One finished round in the history strip.
@immutable
class Spin2WinRecentRound {
  const Spin2WinRecentRound({
    required this.roundId,
    required this.roundNumber,
    required this.winningNumber,
    required this.bonusMultiplier,
    required this.scheduledAt,
  });

  final String roundId;
  final int roundNumber;
  /// The winning number, 0 to 9.
  final int winningNumber;

  /// The bonus that round was paid with (1 = N).
  final int bonusMultiplier;
  final DateTime scheduledAt;

  factory Spin2WinRecentRound.fromJson(Map<String, dynamic> j) =>
      Spin2WinRecentRound(
        roundId: j[Spin2WinField.roundId] as String,
        roundNumber: (j[Spin2WinField.roundNumber] as num).toInt(),
        winningNumber: spin2WinNumberFromDb(j[Spin2WinField.winningNumber]),
        bonusMultiplier: (j[Spin2WinField.bonusMultiplier] as num).toInt(),
        scheduledAt: DateTime.parse(j[Spin2WinField.scheduledAt] as String),
      );
}

/// A round's finished outcome, handed to the rest of the app once, by the round
/// sync, when it is time to show it.
@immutable
class Spin2WinRoundResult {
  const Spin2WinRoundResult({
    required this.roundId,
    required this.roundNumber,
    required this.winningNumber,
    required this.bonusMultiplier,
    required this.scheduledAt,
    required this.isCatchUpReplay,
  });

  final String roundId;
  final int roundNumber;
  /// The winning number, 0 to 9.
  final int winningNumber;

  /// The round's own pinned bonus (1 = N, 2 to 4).
  final int bonusMultiplier;
  final DateTime scheduledAt;

  /// True when the player only caught this round after it had already finished
  /// (they opened the game screen late), so it must not be offered for Rebet,
  /// exactly as Triple Chance treats a replay.
  final bool isCatchUpReplay;

  /// Builds the result from a drawn round. Throws a [StateError] if the round
  /// has not been drawn.
  factory Spin2WinRoundResult.fromRound(
    Spin2WinRoundState round, {
    required bool isCatchUpReplay,
  }) {
    final number = round.winningNumber;
    if (number == null) {
      throw StateError('Round ${round.roundNumber} has not been drawn');
    }
    return Spin2WinRoundResult(
      roundId: round.roundId,
      roundNumber: round.roundNumber,
      winningNumber: number,
      bonusMultiplier: round.bonusMultiplier ?? 1,
      scheduledAt: round.scheduledAt,
      isCatchUpReplay: isCatchUpReplay,
    );
  }
}
