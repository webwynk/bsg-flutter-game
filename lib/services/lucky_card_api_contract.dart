// The names Lucky Card uses to talk to the database.
//
// Everything here was checked against the LIVE database (project
// ezcmxxfhjtzqolbtmshr) on 2026-10-06 and mirrors the migrations
// 20261005110000 (current round), 20261005120000 (place bet) and
// 20261005140000 (my result, recent results). A name that differs from the
// database by even one character fails at runtime, never at compile time, so
// every string lives here, in one place, and is covered by
// test/lucky_card/lucky_card_api_service_test.dart.
//
// This file belongs to Lucky Card only. It deliberately does not reuse or
// extend the Triple Chance contract (api_contract.dart): that file is frozen.

/// The four functions a signed-in player may call.
///
/// The database has six more `lucky_card_*` functions (draw, settle, tick,
/// boost, coin movement, random helper). They are server-only; the app has no
/// permission to call them and never does.
class LuckyCardRpc {
  LuckyCardRpc._();

  /// `lucky_card_get_current_round() -> jsonb`. Creates the round on demand and
  /// draws and settles it once the cycle passes `draw_at_second`.
  static const getCurrentRound = 'lucky_card_get_current_round';

  /// `lucky_card_place_bet(p_round_id uuid, p_bets jsonb) -> jsonb`. Places or
  /// replaces this player's bet; only the difference is charged or refunded.
  static const placeBet = 'lucky_card_place_bet';

  /// `lucky_card_get_my_round_result(p_round_id uuid) -> jsonb`.
  static const getMyRoundResult = 'lucky_card_get_my_round_result';

  /// `lucky_card_get_recent_rounds(p_limit integer) -> jsonb` (a JSON list).
  static const getRecentRounds = 'lucky_card_get_recent_rounds';
}

/// Parameter names of the functions above.
class LuckyCardRpcParam {
  LuckyCardRpcParam._();

  static const roundId = 'p_round_id';
  static const bets = 'p_bets';
  static const limit = 'p_limit';
}

/// Keys of the JSON the functions return.
class LuckyCardField {
  LuckyCardField._();

  // The current round.
  static const roundId = 'round_id';
  static const roundNumber = 'round_number';
  static const phase = 'phase';
  static const scheduledAt = 'scheduled_at';
  static const secondsRemaining = 'seconds_remaining';
  static const secondsInto = 'seconds_into';
  static const drawAtSecond = 'draw_at_second';

  /// `null` until the round is drawn, like [bonusMultiplier].
  static const winningRank = 'winning_rank';
  static const winningSuit = 'winning_suit';

  /// The round's own pinned bonus. `null` until the draw, so a player cannot
  /// learn the bonus while betting is open.
  static const bonusMultiplier = 'bonus_multiplier';

  // A bet and a player's result.
  static const success = 'success';
  static const totalStake = 'total_stake';
  static const totalPayout = 'total_payout';
  static const coinBalance = 'coin_balance';
  static const ledgerVersion = 'ledger_version';
  static const placedBet = 'placed_bet';
  static const isSettled = 'is_settled';
}

/// SQLSTATE codes the database raises, as seen in `PostgrestException.code`.
///
/// P0100, P0112, P0113, P0114, P0120, P0121, P0123, P0124 and P0125 are shared
/// with Triple Chance's functions; P0126 is new with Lucky Card's bet function.
/// Each code and its message was captured from the real database
/// (test/lucky_card/fixtures/errors.json).
class LuckyCardErrCode {
  LuckyCardErrCode._();

  /// `auth.uid()` was null: no signed-in user.
  static const unauthenticated = 'P0100';

  /// `INSUFFICIENT_COINS`: the stake would take the balance below zero.
  static const insufficient = 'P0112';

  /// `ACCOUNT_BLOCKED`.
  static const accountBlocked = 'P0113';

  /// `Only players may place bets`: an agent or superadmin account.
  static const notAPlayer = 'P0114';

  /// `ROUND_NOT_FOUND`.
  static const roundNotFound = 'P0120';

  /// `ROUND_CLOSED`: already drawn, past the cutoff second, or not the current
  /// cycle's round.
  static const roundClosed = 'P0121';

  /// `BELOW_MIN`: a card holds 1 to 4, or a negative amount.
  static const belowMin = 'P0123';

  /// `EXCEEDS_MAX`: a card holds more than 50,000.
  static const exceedsMax = 'P0124';

  /// `EMPTY_BET`: nothing above zero was sent.
  static const emptyBet = 'P0125';

  /// `BAD_BET:<key>`: the bet is not an object, a key is not one of the 12
  /// cards, or an amount is not a whole number.
  static const badBet = 'P0126';
}
