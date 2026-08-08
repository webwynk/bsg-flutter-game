/// The v2 backend contract.
///
/// Every name here mirrors one object in
/// `bsg_web_dashboard/supabase/migrations/20260807000200_rebuild_v2_functions.sql`.
/// If an RPC's name or response shape changes in SQL, change it here in the
/// same commit — this file is the single place the app and the database are
/// reconciled.
///
/// WHY THIS EXISTS
///   v1 spelled RPC names and response keys inline at each call site. That is
///   how `agentName` vs `agent_name` survived for months (the key was simply
///   never read), and how the app kept calling `submit_round_bet` with a
///   parameter the function ignored. Naming them once makes a rename a compile
///   error rather than a silent no-op.
///
/// CONVENTION
///   Every payload key is snake_case, matching the database exactly. Dart
///   fields are camelCase only as local identifiers; nothing is translated on
///   the wire.
library;

/// Remote procedure names. Each has exactly one signature in the database.
class Rpc {
  Rpc._();

  // ── Session ────────────────────────────────────────────────────────────────
  /// `session_login(p_session_token text) -> jsonb`
  /// Refuses while another device is still heartbeating (see [ReasonCode]).
  static const sessionLogin = 'session_login';

  /// `session_heartbeat(p_session_token text) -> jsonb`
  static const sessionHeartbeat = 'session_heartbeat';

  /// `session_logout() -> jsonb`
  static const sessionLogout = 'session_logout';

  // ── Round lifecycle ────────────────────────────────────────────────────────
  /// `get_play_limits() -> jsonb`
  static const getPlayLimits = 'get_play_limits';

  /// `get_current_round() -> jsonb`
  /// Digits are null until `seconds_into >= draw_at_second`.
  static const getCurrentRound = 'get_current_round';

  /// `get_recent_rounds(p_limit int) -> jsonb`
  static const getRecentRounds = 'get_recent_rounds';

  // ── Betting ────────────────────────────────────────────────────────────────
  /// `place_bet(p_round_id uuid, p_single_bets jsonb, p_double_bets jsonb,
  ///            p_triple_bets jsonb) -> jsonb`
  ///
  /// The stake is NOT a parameter: the server recomputes it from the bet maps.
  /// v1 accepted `p_total_stake` and ignored it, which invited the client to
  /// believe it was authoritative.
  static const placeBet = 'place_bet';

  /// `get_my_round_result(p_round_id uuid) -> jsonb`
  /// Read-only. Settlement happens server-side in `settle_round`.
  static const getMyRoundResult = 'get_my_round_result';
}

/// Parameter names for the RPCs above.
class RpcParam {
  RpcParam._();

  static const sessionToken = 'p_session_token';
  static const roundId      = 'p_round_id';
  static const singleBets   = 'p_single_bets';
  static const doubleBets   = 'p_double_bets';
  static const tripleBets   = 'p_triple_bets';
  static const limit        = 'p_limit';
}

/// Response keys shared across payloads.
class Field {
  Field._();

  // Money. `coin_balance` everywhere — never `balance`.
  static const coinBalance   = 'coin_balance';
  static const ledgerVersion = 'ledger_version';
  static const totalStake    = 'total_stake';
  static const totalPayout   = 'total_payout';
  static const singlePayout  = 'single_payout';
  static const doublePayout  = 'double_payout';
  static const triplePayout  = 'triple_payout';

  // Session
  static const allowed          = 'allowed';
  static const reason           = 'reason';
  static const secondsUntilFree = 'seconds_until_free';
  static const role             = 'role';
  static const username         = 'username';
  static const userId           = 'user_id';

  // Round
  static const roundId          = 'round_id';
  static const roundNumber      = 'round_number';
  static const phase            = 'phase';
  static const scheduledAt      = 'scheduled_at';
  static const secondsRemaining = 'seconds_remaining';
  static const secondsInto      = 'seconds_into';
  static const drawAtSecond     = 'draw_at_second';
  static const red              = 'red';
  static const green            = 'green';
  static const black            = 'black';

  // Bet
  static const placedBet = 'placed_bet';
  static const isSettled = 'is_settled';
  static const success   = 'success';
}

/// Database tables the app reads directly (all writes go through RPCs).
class Tbl {
  Tbl._();

  static const profiles = 'profiles';
  static const bets     = 'bets';
  static const rounds   = 'rounds';
}

/// `reason` values returned by [Rpc.sessionLogin] and [Rpc.sessionHeartbeat]
/// when `allowed` is false.
class ReasonCode {
  ReasonCode._();

  /// The account is suspended.
  static const accountBlocked = 'account_blocked';

  /// Another device holds a live session. **The login is refused** — this is
  /// the Q6 behaviour: the first device keeps playing.
  static const sessionActiveElsewhere = 'session_active_elsewhere';

  /// This device's session was replaced by another. Only ever returned by the
  /// heartbeat, once a takeover has happened after the grace period.
  static const sessionDisplaced = 'session_displaced';
}

/// PostgreSQL error codes raised by the v2 functions, mapped to the sentinels
/// the UI reacts to. See the RAISE statements in the functions migration.
class ErrCode {
  ErrCode._();

  static const unauthenticated  = 'P0100';  // auth.uid() was null
  static const accountBlocked   = 'P0113';
  static const notAPlayer       = 'P0114';
  static const insufficient     = 'P0112';  // INSUFFICIENT_COINS
  static const roundNotFound    = 'P0120';
  static const roundClosed      = 'P0121';  // digits exist, or past the cutoff
  static const badBetKey        = 'P0122';
  static const belowMin         = 'P0123';
  static const exceedsMax       = 'P0124';
  // P0125 (EMPTY_BET) has no client-side mapping -- confirmed unreachable
  // from this app: place_bet is only ever called with a non-empty board,
  // guarded independently at three separate points (the automatic countdown-
  // driven submission, its backup at the draw moment, and submitBets()'s own
  // internal check). The database's own P0125 check stays as-is regardless --
  // this only removes the now-dead client-side recognition of that code.
}

/// UI-facing sentinels. Kept separate from [ErrCode] so the presentation layer
/// never has to know a Postgres error code.
class BetError {
  BetError._();

  static const insufficientCoins = 'INSUFFICIENT_COINS';
  static const belowMin          = 'BELOW_MIN';
  static const exceedsMax        = 'EXCEEDS_MAX';
  static const roundClosed       = 'ROUND_CLOSED';
  static const badKey            = 'BAD_KEY';
  static const unauthenticated   = 'UNAUTHENTICATED';
  static const accountBlocked    = 'ACCOUNT_BLOCKED';
  static const offline           = 'OFFLINE';
}
