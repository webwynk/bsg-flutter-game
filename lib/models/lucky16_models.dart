// The data Lucky 16 Card works with: the 16 cards, a round, a bet's outcome, a
// player's result and the history list, plus the reasons a call can fail.
//
// Copied from lib/models/lucky_card_models.dart (Lucky Card) and changed for
// Lucky 16 Card: a fourth rank, A, so 16 cards instead of 12, and a maximum of
// 10,000 per card instead of 50,000. It imports nothing from Lucky Card, so
// the two games can never affect each other.
//
// Pure Dart: nothing here talks to the network, the screen or the sound.
// Parsing is checked against the answers in test/lucky16/fixtures/, which are
// adapted from Lucky Card's live-database captures (the two games' functions
// return the same JSON shape). Belongs to Lucky 16 Card only; it does not
// reuse or extend any Triple Chance or Lucky Card model.

import 'package:flutter/foundation.dart';

import '../services/lucky16_api_contract.dart';

/// The rank of a card. Declared in the order the betting grid lists its rows,
/// top to bottom (A, J, Q, K); the database stores the one-letter [dbValue].
enum Lucky16Rank {
  ace('A', 'Ace'),
  jack('J', 'Jack'),
  queen('Q', 'Queen'),
  king('K', 'King');

  const Lucky16Rank(this.dbValue, this.label);

  /// `A`, `J`, `Q` or `K`, exactly as `lucky16_rounds.winning_rank` stores it.
  final String dbValue;

  /// Singular word, for example "Queen".
  final String label;

  /// Throws a [FormatException] for anything but `A`, `J`, `Q` or `K`, so a
  /// changed database value is caught loudly instead of becoming a wrong card.
  static Lucky16Rank fromDb(String value) {
    for (final r in values) {
      if (r.dbValue == value) return r;
    }
    throw FormatException('Unknown Lucky 16 Card rank: "$value"');
  }
}

/// The suit of a card, in the database's own order (hearts, spades, diamonds,
/// clubs). How the suits are arranged on screen is decided by the screen, not
/// by this order.
enum Lucky16Suit {
  hearts('hearts', 'Hearts', '♥', true),
  spades('spades', 'Spades', '♠', false),
  diamonds('diamonds', 'Diamonds', '♦', true),
  clubs('clubs', 'Clubs', '♣', false);

  const Lucky16Suit(this.dbValue, this.label, this.glyph, this.isRed);

  /// `hearts`, `spades`, `diamonds` or `clubs`, exactly as
  /// `lucky16_rounds.winning_suit` stores it.
  final String dbValue;

  /// Plural word, for example "Hearts".
  final String label;

  /// The text symbol of the suit.
  final String glyph;

  /// Hearts and diamonds are red; spades and clubs are black.
  final bool isRed;

  /// Throws a [FormatException] for any value that is not one of the four suits.
  static Lucky16Suit fromDb(String value) {
    for (final s in values) {
      if (s.dbValue == value) return s;
    }
    throw FormatException('Unknown Lucky 16 Card suit: "$value"');
  }
}

/// One of the 16 cards a player can bet on (A, J, Q or K of a suit).
@immutable
class Lucky16Card {
  const Lucky16Card(this.rank, this.suit);

  final Lucky16Rank rank;
  final Lucky16Suit suit;

  /// The key the database uses for this card in a bet and in the bets table,
  /// for example `a_hearts` or `k_clubs`.
  String get key => '${rank.dbValue.toLowerCase()}_${suit.dbValue}';

  /// Short name for the screen, for example `A♥`.
  String get shortName => '${rank.dbValue}${suit.glyph}';

  /// All 16 cards in the database's column order: A hearts, A spades, A
  /// diamonds, A clubs, then the same for J, Q and K.
  static const List<Lucky16Card> all = [
    Lucky16Card(Lucky16Rank.ace, Lucky16Suit.hearts),
    Lucky16Card(Lucky16Rank.ace, Lucky16Suit.spades),
    Lucky16Card(Lucky16Rank.ace, Lucky16Suit.diamonds),
    Lucky16Card(Lucky16Rank.ace, Lucky16Suit.clubs),
    Lucky16Card(Lucky16Rank.jack, Lucky16Suit.hearts),
    Lucky16Card(Lucky16Rank.jack, Lucky16Suit.spades),
    Lucky16Card(Lucky16Rank.jack, Lucky16Suit.diamonds),
    Lucky16Card(Lucky16Rank.jack, Lucky16Suit.clubs),
    Lucky16Card(Lucky16Rank.queen, Lucky16Suit.hearts),
    Lucky16Card(Lucky16Rank.queen, Lucky16Suit.spades),
    Lucky16Card(Lucky16Rank.queen, Lucky16Suit.diamonds),
    Lucky16Card(Lucky16Rank.queen, Lucky16Suit.clubs),
    Lucky16Card(Lucky16Rank.king, Lucky16Suit.hearts),
    Lucky16Card(Lucky16Rank.king, Lucky16Suit.spades),
    Lucky16Card(Lucky16Rank.king, Lucky16Suit.diamonds),
    Lucky16Card(Lucky16Rank.king, Lucky16Suit.clubs),
  ];

  /// The 4 cards of one suit, in rank order A, J, Q, K: the cards a suit bar
  /// places chips on.
  static List<Lucky16Card> ofSuit(Lucky16Suit suit) =>
      [for (final c in all) if (c.suit == suit) c];

  /// The 4 cards of one rank, in suit order hearts, spades, diamonds, clubs:
  /// the cards a rank selector places chips on.
  static List<Lucky16Card> ofRank(Lucky16Rank rank) =>
      [for (final c in all) if (c.rank == rank) c];

  /// The card for a database [key] such as `q_spades`. Throws a
  /// [FormatException] for a key that is not one of the 16.
  static Lucky16Card fromKey(String key) {
    for (final c in all) {
      if (c.key == key) return c;
    }
    throw FormatException('Unknown Lucky 16 Card key: "$key"');
  }

  @override
  bool operator ==(Object other) =>
      other is Lucky16Card && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);

  @override
  String toString() => 'Lucky16Card($key)';
}

/// The bonus as text: 1 (or less) is "N" (no bonus), otherwise "2X" to "10X".
String lucky16BonusLabel(int bonus) => bonus <= 1 ? 'N' : '${bonus}X';

/// Why a Lucky 16 Card call failed, as the app should treat it.
enum Lucky16Error {
  /// Not enough coins for the stake (P0112).
  insufficientCoins,

  /// A card holds less than the minimum of 5 (P0123).
  belowMin,

  /// A card holds more than the maximum of 10,000 (P0124).
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

/// The Lucky 16 Card round the server clock is in.
@immutable
class Lucky16RoundState {
  const Lucky16RoundState({
    required this.roundId,
    required this.roundNumber,
    required this.phase,
    required this.scheduledAt,
    required this.secondsRemaining,
    required this.secondsInto,
    required this.drawAtSecond,
    this.winningCard,
    this.bonusMultiplier,
  });

  final String roundId;
  final int roundNumber;

  /// `betting`, `drawing` or `settled`.
  final String phase;

  /// The end of this round's 103-second cycle.
  final DateTime scheduledAt;
  final int secondsRemaining;
  final int secondsInto;

  /// The second of the cycle the draw happens at (89).
  final int drawAtSecond;

  /// The winning card; `null` until the round is drawn.
  final Lucky16Card? winningCard;

  /// The round's own pinned bonus (1 = N, 2 to 10); `null` until the draw,
  /// delivered in the same answer as [winningCard].
  final int? bonusMultiplier;

  /// True once the winning card is known.
  bool get isDrawn => winningCard != null;

  /// A hint that the server will still take a bet: not drawn and before the
  /// draw second. The server decides; its own cutoff is one second earlier than
  /// the draw second and is not part of the answer, so this can say true for one
  /// second in which the server already refuses, and never the other way round.
  bool get acceptsBets => !isDrawn && secondsInto < drawAtSecond;

  /// Throws a [FormatException] (or a [TypeError]) if the answer is not shaped
  /// as expected, which the API service turns into [Lucky16Error.unknown].
  factory Lucky16RoundState.fromJson(Map<String, dynamic> j) {
    final rank = j[Lucky16Field.winningRank] as String?;
    final suit = j[Lucky16Field.winningSuit] as String?;
    if ((rank == null) != (suit == null)) {
      throw const FormatException(
          'Lucky 16 Card round has only one of winning_rank and winning_suit');
    }
    return Lucky16RoundState(
      roundId: j[Lucky16Field.roundId] as String,
      roundNumber: (j[Lucky16Field.roundNumber] as num).toInt(),
      phase: j[Lucky16Field.phase] as String,
      scheduledAt: DateTime.parse(j[Lucky16Field.scheduledAt] as String),
      secondsRemaining: (j[Lucky16Field.secondsRemaining] as num).toInt(),
      secondsInto: (j[Lucky16Field.secondsInto] as num).toInt(),
      drawAtSecond: (j[Lucky16Field.drawAtSecond] as num).toInt(),
      winningCard: rank == null
          ? null
          : Lucky16Card(Lucky16Rank.fromDb(rank), Lucky16Suit.fromDb(suit!)),
      bonusMultiplier: (j[Lucky16Field.bonusMultiplier] as num?)?.toInt(),
    );
  }
}

/// The outcome of placing a bet.
@immutable
class Lucky16PlaceBetResult {
  const Lucky16PlaceBetResult({
    required this.success,
    this.totalStake = 0,
    this.coinBalance = 0,
    this.ledgerVersion = 0,
    this.error,
  });

  /// A failed bet carrying only the reason; nothing was charged.
  const Lucky16PlaceBetResult.failure(Lucky16Error this.error)
      : success = false,
        totalStake = 0,
        coinBalance = 0,
        ledgerVersion = 0;

  final bool success;

  /// The server-computed total stake of the bet now on record (the app sends no
  /// total; the database adds up the cards).
  final int totalStake;

  /// The player's balance after the bet, as stored.
  final int coinBalance;

  /// The balance's version counter, used to ignore an older balance that
  /// arrives late.
  final int ledgerVersion;

  /// Why it failed; `null` on success.
  final Lucky16Error? error;

  factory Lucky16PlaceBetResult.fromJson(Map<String, dynamic> j) =>
      Lucky16PlaceBetResult(
        success: j[Lucky16Field.success] as bool? ?? true,
        totalStake: (j[Lucky16Field.totalStake] as num?)?.toInt() ?? 0,
        coinBalance: (j[Lucky16Field.coinBalance] as num?)?.toInt() ?? 0,
        ledgerVersion: (j[Lucky16Field.ledgerVersion] as num?)?.toInt() ?? 0,
      );
}

/// This player's own outcome for one round.
@immutable
class Lucky16MyResult {
  const Lucky16MyResult({
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

  factory Lucky16MyResult.fromJson(Map<String, dynamic> j) =>
      Lucky16MyResult(
        placedBet: j[Lucky16Field.placedBet] as bool? ?? false,
        totalStake: (j[Lucky16Field.totalStake] as num?)?.toInt() ?? 0,
        totalPayout: (j[Lucky16Field.totalPayout] as num?)?.toInt() ?? 0,
        isSettled: j[Lucky16Field.isSettled] as bool? ?? false,
        coinBalance: (j[Lucky16Field.coinBalance] as num?)?.toInt() ?? 0,
        ledgerVersion: (j[Lucky16Field.ledgerVersion] as num?)?.toInt() ?? 0,
      );
}

/// One finished round in the history strip.
@immutable
class Lucky16RecentRound {
  const Lucky16RecentRound({
    required this.roundId,
    required this.roundNumber,
    required this.winningCard,
    required this.bonusMultiplier,
    required this.scheduledAt,
  });

  final String roundId;
  final int roundNumber;
  final Lucky16Card winningCard;

  /// The bonus that round was paid with (1 = N).
  final int bonusMultiplier;
  final DateTime scheduledAt;

  factory Lucky16RecentRound.fromJson(Map<String, dynamic> j) =>
      Lucky16RecentRound(
        roundId: j[Lucky16Field.roundId] as String,
        roundNumber: (j[Lucky16Field.roundNumber] as num).toInt(),
        winningCard: Lucky16Card(
          Lucky16Rank.fromDb(j[Lucky16Field.winningRank] as String),
          Lucky16Suit.fromDb(j[Lucky16Field.winningSuit] as String),
        ),
        bonusMultiplier: (j[Lucky16Field.bonusMultiplier] as num).toInt(),
        scheduledAt: DateTime.parse(j[Lucky16Field.scheduledAt] as String),
      );
}

/// A round's finished outcome, handed to the rest of the app once, by the round
/// sync, when it is time to show it.
@immutable
class Lucky16RoundResult {
  const Lucky16RoundResult({
    required this.roundId,
    required this.roundNumber,
    required this.winningCard,
    required this.bonusMultiplier,
    required this.scheduledAt,
    required this.isCatchUpReplay,
  });

  final String roundId;
  final int roundNumber;
  final Lucky16Card winningCard;

  /// The round's own pinned bonus (1 = N, 2 to 10).
  final int bonusMultiplier;
  final DateTime scheduledAt;

  /// True when the player only caught this round after it had already finished
  /// (they opened the game screen late), so it must not be offered for Rebet,
  /// exactly as Triple Chance treats a replay.
  final bool isCatchUpReplay;

  /// Builds the result from a drawn round. Throws a [StateError] if the round
  /// has not been drawn.
  factory Lucky16RoundResult.fromRound(
    Lucky16RoundState round, {
    required bool isCatchUpReplay,
  }) {
    final card = round.winningCard;
    if (card == null) {
      throw StateError('Round ${round.roundNumber} has not been drawn');
    }
    return Lucky16RoundResult(
      roundId: round.roundId,
      roundNumber: round.roundNumber,
      winningCard: card,
      bonusMultiplier: round.bonusMultiplier ?? 1,
      scheduledAt: round.scheduledAt,
      isCatchUpReplay: isCatchUpReplay,
    );
  }
}
