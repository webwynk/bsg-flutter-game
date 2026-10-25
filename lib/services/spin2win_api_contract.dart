// The names Spin2Win uses to talk to the database.
//
// Everything here mirrors the migration 20261024250000_spin2win_player_functions.sql,
// applied to the LIVE database (project ezcmxxfhjtzqolbtmshr) on 2026-10-24,
// and the tables of 20261024210000_spin2win_core_tables.sql. A name that differs from the
// database by even one character fails at runtime, never at compile time, so
// every string lives here, in one place, and is covered by
// test/spin2win/spin2win_api_service_test.dart.
//
// This file belongs to Spin2Win only. It deliberately does not reuse or
// extend the Triple Chance or Lucky Card contracts: those files are protected.

/// The four functions a signed-in player may call.
///
/// The database has six more `spin2win_*` functions (draw, settle, tick,
/// boost, coin movement, random helper). They are server-only; the app has no
/// permission to call them and never does.
class Spin2WinRpc {
  Spin2WinRpc._();

  /// `spin2win_get_current_round() -> jsonb`. Creates the round on demand and
  /// draws and settles it once the cycle passes `draw_at_second`.
  static const getCurrentRound = 'spin2win_get_current_round';

  /// `spin2win_place_bet(p_round_id uuid, p_bets jsonb) -> jsonb`. Places or
  /// replaces this player's bet; only the difference is charged or refunded.
  static const placeBet = 'spin2win_place_bet';

  /// `spin2win_get_my_round_result(p_round_id uuid) -> jsonb`.
  static const getMyRoundResult = 'spin2win_get_my_round_result';

  /// `spin2win_get_recent_rounds(p_limit integer) -> jsonb` (a JSON list).
  static const getRecentRounds = 'spin2win_get_recent_rounds';
}

/// The two tables the app reads directly, for the player's own session history
/// (not through a function, exactly as Triple Chance's history reads `bets`).
/// Row-level security shows a
/// player only their own bets and only rounds that are `settled`, so a join to
/// the rounds table leaves out a round that is still running.
class Spin2WinTable {
  Spin2WinTable._();

  static const bets = 'spin2win_bets';
  static const rounds = 'spin2win_rounds';
}

/// Parameter names of the functions above.
class Spin2WinRpcParam {
  Spin2WinRpcParam._();

  static const roundId = 'p_round_id';
  static const bets = 'p_bets';
  static const limit = 'p_limit';
}

/// Keys of the JSON the functions return.
class Spin2WinField {
  Spin2WinField._();

  // The current round.
  static const roundId = 'round_id';
  static const roundNumber = 'round_number';
  static const phase = 'phase';
  static const scheduledAt = 'scheduled_at';
  static const secondsRemaining = 'seconds_remaining';
  static const secondsInto = 'seconds_into';
  static const drawAtSecond = 'draw_at_second';

  /// 0 to 9; `null` until the round is drawn, like [bonusMultiplier].
  static const winningNumber = 'winning_number';

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

  /// When the bet was placed (`spin2win_bets.created_at`), used to list only
  /// the bets made since the player logged in.
  static const createdAt = 'created_at';
}

/// SQLSTATE codes the database raises, as seen in `PostgrestException.code`.
///
/// The same codes, with the same meanings, as Lucky Card's bet function: the
/// Spin2Win functions raise exactly these (20261024250000, read 2026-10-24).
class Spin2WinErrCode {
  Spin2WinErrCode._();

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

  /// `BELOW_MIN`: a number holds 1 to 4, or a negative amount.
  static const belowMin = 'P0123';

  /// `EXCEEDS_MAX`: a number holds more than 10,000.
  static const exceedsMax = 'P0124';

  /// `EMPTY_BET`: nothing above zero was sent.
  static const emptyBet = 'P0125';

  /// `BAD_BET:<key>`: the bet is not an object, a key is not one of `n0`
  /// to `n9`, or an amount is not a whole number.
  static const badBet = 'P0126';
}
