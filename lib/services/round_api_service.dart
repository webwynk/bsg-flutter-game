import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_contract.dart';

/// The current global round.
///
/// `red`/`green`/`black` are null until the draw, which happens at
/// [drawAtSecond] — strictly after the betting cutoff. That ordering is
/// enforced in the database, so an outcome can never be visible while a bet is
/// still acceptable.
class GlobalRoundState {
  final String roundId;
  final int roundNumber;

  /// 'betting' | 'drawing' | 'settled'
  final String phase;

  final DateTime scheduledAt;
  final int secondsRemaining;
  final int secondsInto;
  final int drawAtSecond;
  final int? red;
  final int? green;
  final int? black;

  const GlobalRoundState({
    required this.roundId,
    required this.roundNumber,
    required this.phase,
    required this.scheduledAt,
    required this.secondsRemaining,
    required this.secondsInto,
    required this.drawAtSecond,
    this.red,
    this.green,
    this.black,
  });

  /// True while the server will still accept a bet for this round.
  bool get acceptsBets =>
      !(red != null && green != null && black != null) && secondsInto < drawAtSecond;

  factory GlobalRoundState.fromJson(Map<String, dynamic> j) => GlobalRoundState(
        roundId: j[Field.roundId] as String,
        roundNumber: (j[Field.roundNumber] as num).toInt(),
        phase: j[Field.phase] as String,
        scheduledAt: DateTime.parse(j[Field.scheduledAt] as String),
        secondsRemaining: (j[Field.secondsRemaining] as num).toInt(),
        secondsInto: (j[Field.secondsInto] as num).toInt(),
        drawAtSecond: (j[Field.drawAtSecond] as num).toInt(),
        red: (j[Field.red] as num?)?.toInt(),
        green: (j[Field.green] as num?)?.toInt(),
        black: (j[Field.black] as num?)?.toInt(),
      );
}

/// Outcome of [RoundApiService.placeBet].
class PlaceBetResult {
  final bool success;

  /// Server-computed stake. The client does not send a total; the database
  /// recomputes it from the bet maps and this is the authoritative figure.
  final int totalStake;
  final int coinBalance;
  final int ledgerVersion;

  /// One of the [BetError] sentinels when [success] is false.
  final String? error;

  const PlaceBetResult({
    required this.success,
    this.totalStake = 0,
    this.coinBalance = 0,
    this.ledgerVersion = 0,
    this.error,
  });

  factory PlaceBetResult.fromJson(Map<String, dynamic> j) => PlaceBetResult(
        success: j[Field.success] as bool? ?? true,
        totalStake: (j[Field.totalStake] as num?)?.toInt() ?? 0,
        coinBalance: (j[Field.coinBalance] as num?)?.toInt() ?? 0,
        ledgerVersion: (j[Field.ledgerVersion] as num?)?.toInt() ?? 0,
      );
}

/// This player's settled result for a round. Read-only: settlement happens
/// server-side in `settle_round`, so unlike v1 this call never credits coins.
class PlayerRoundResult {
  final bool placedBet;
  final int totalStake;
  final int singlePayout;
  final int doublePayout;
  final int triplePayout;
  final int totalPayout;
  final bool isSettled;
  final int coinBalance;
  final int ledgerVersion;

  const PlayerRoundResult({
    required this.placedBet,
    required this.totalStake,
    required this.singlePayout,
    required this.doublePayout,
    required this.triplePayout,
    required this.totalPayout,
    required this.isSettled,
    required this.coinBalance,
    required this.ledgerVersion,
  });

  factory PlayerRoundResult.fromJson(Map<String, dynamic> j) => PlayerRoundResult(
        placedBet: j[Field.placedBet] as bool? ?? false,
        totalStake: (j[Field.totalStake] as num?)?.toInt() ?? 0,
        singlePayout: (j[Field.singlePayout] as num?)?.toInt() ?? 0,
        doublePayout: (j[Field.doublePayout] as num?)?.toInt() ?? 0,
        triplePayout: (j[Field.triplePayout] as num?)?.toInt() ?? 0,
        totalPayout: (j[Field.totalPayout] as num?)?.toInt() ?? 0,
        isSettled: j[Field.isSettled] as bool? ?? false,
        coinBalance: (j[Field.coinBalance] as num?)?.toInt() ?? 0,
        ledgerVersion: (j[Field.ledgerVersion] as num?)?.toInt() ?? 0,
      );
}

/// A completed round, for the history strip.
class RecentRound {
  final String roundId;
  final int red;
  final int green;
  final int black;
  final DateTime scheduledAt;

  const RecentRound({
    required this.roundId,
    required this.red,
    required this.green,
    required this.black,
    required this.scheduledAt,
  });

  factory RecentRound.fromJson(Map<String, dynamic> j) => RecentRound(
        roundId: j[Field.roundId] as String,
        red: (j[Field.red] as num).toInt(),
        green: (j[Field.green] as num).toInt(),
        black: (j[Field.black] as num).toInt(),
        scheduledAt: DateTime.parse(j[Field.scheduledAt] as String),
      );
}

/// Talks to the v2 round RPCs.
///
/// Every call goes through the authenticated Supabase client. v1 sent the anon
/// key as a Bearer token for round reads, which meant round data — including
/// the winning digits — was retrievable without a session. v2 removes that
/// path entirely: `rounds` is hidden by RLS until settled, and the RPCs are
/// granted to `authenticated` only.
class RoundApiService {
  static final RoundApiService _instance = RoundApiService._internal();
  factory RoundApiService() => _instance;
  RoundApiService._internal();

  SupabaseClient get _db => Supabase.instance.client;

  /// Maps a PostgrestException to a [BetError] sentinel the UI can act on.
  ///
  /// v1 mapped only some codes and matched the insufficient-funds case on the
  /// string 'Insufficient balance' while the function raises
  /// 'INSUFFICIENT_COINS' — so that branch never fired. Matching on the error
  /// CODE rather than the message removes that class of mistake.
  static String mapError(Object e) {
    final code = e is PostgrestException ? (e.code ?? '') : '';
    final msg = e.toString().toLowerCase();

    bool has(String c, String text) => code == c || msg.contains(text.toLowerCase());

    if (has(ErrCode.unauthenticated, 'unauthenticated') ||
        msg.contains('jwt') ||
        msg.contains('token') ||
        msg.contains('401') ||
        msg.contains('auth')) {
      return BetError.unauthenticated;
    }
    if (has(ErrCode.accountBlocked, 'account_blocked') || msg.contains('blocked')) {
      return BetError.accountBlocked;
    }
    if (has(ErrCode.insufficient, 'insufficient_coins') || msg.contains('insufficient')) {
      return BetError.insufficientCoins;
    }
    if (has(ErrCode.belowMin, 'below_min')) return BetError.belowMin;
    if (has(ErrCode.exceedsMax, 'exceeds_max')) return BetError.exceedsMax;
    if (has(ErrCode.roundClosed, 'round_closed')) return BetError.roundClosed;
    if (has(ErrCode.roundNotFound, 'round_not_found')) return BetError.roundClosed;
    if (has(ErrCode.badBetKey, 'bad_')) return BetError.badKey;
    // Issue #23: a staff account somehow reached the game screen and tried
    // to bet -- exhaustively confirmed only place_bet can ever raise this,
    // never get_current_round, so this can only be produced from a bet
    // submission, never the background round-state poller.
    if (has(ErrCode.notAPlayer, 'only players may place bets')) return BetError.notAPlayer;

    // No case for EMPTY_BET (P0125): confirmed unreachable from this app --
    // place_bet is only ever called with a non-empty board, independently
    // guarded at three separate points before any request reaches the
    // server. See ErrCode's own comment for the full explanation. If this
    // ever changes, add the case back rather than letting it silently fall
    // through to the generic UNKNOWN case below.
    //
    // Issue #23: the true catch-all for anything genuinely unrecognized.
    // Previously defaulted to OFFLINE, which falsely blamed the player's
    // connection for literally any unmapped error -- including this file's
    // own documented design goal of not conflating server errors with real
    // network errors. UNKNOWN stays in the same retry bucket as OFFLINE
    // (round_sync_service.dart's retryableErrors) since an error this app
    // doesn't recognize might still be a transient blip worth one more try,
    // but displays its own honest "something went wrong" message instead of
    // a network-specific one.
    return BetError.unknown;
  }

  /// Why the last [getCurrentRound] failed, as a [BetError] sentinel.
  ///
  /// getCurrentRound returns null for every failure, so without this the UI
  /// could only ever say "no internet" — an expired session, an RLS denial and
  /// a genuinely dead network were indistinguishable. That is what made the
  /// emulator report "NO INTERNET CONNECTION" while the network was fine.
  String? lastRoundError;

  /// The current round. Creates it server-side on demand, and triggers the draw
  /// and settlement once the cycle passes `draw_at_second`.
  Future<GlobalRoundState?> getCurrentRound() async {
    try {
      final res = await _db.rpc(Rpc.getCurrentRound);
      if (res == null) {
        lastRoundError = BetError.offline;
        return null;
      }
      lastRoundError = null;
      return GlobalRoundState.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      lastRoundError = mapError(e);
      debugPrint('RoundApiService.getCurrentRound failed: $lastRoundError ($e)');
      return null;
    }
  }

  /// Places or replaces this player's bet for [roundId].
  ///
  /// Bet keys must already be canonical zero-padded strings: '0'-'9' for
  /// single, '00'-'99' for double, '000'-'999' for triple. The database
  /// validates them and rejects anything else, so settlement can do one lookup
  /// instead of v1's padded/unpadded/int triple fallback.
  Future<PlaceBetResult> placeBet({
    required String roundId,
    required Map<String, int> singleBets,
    required Map<String, int> doubleBets,
    required Map<String, int> tripleBets,
  }) async {
    try {
      final res = await _db.rpc(Rpc.placeBet, params: {
        RpcParam.roundId: roundId,
        RpcParam.singleBets: singleBets,
        RpcParam.doubleBets: doubleBets,
        RpcParam.tripleBets: tripleBets,
      });
      if (res == null) {
        return const PlaceBetResult(success: false, error: BetError.offline);
      }
      return PlaceBetResult.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      final mapped = mapError(e);
      debugPrint('RoundApiService.placeBet rejected: $mapped ($e)');
      return PlaceBetResult(success: false, error: mapped);
    }
  }

  /// This player's result for a round. Returns null only on a transport error,
  /// so the caller can distinguish "no answer" from "no bet".
  Future<PlayerRoundResult?> getMyRoundResult(String roundId) async {
    try {
      final res = await _db.rpc(Rpc.getMyRoundResult, params: {
        RpcParam.roundId: roundId,
      });
      if (res == null) return null;
      return PlayerRoundResult.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      debugPrint('RoundApiService.getMyRoundResult: $e');
      return null;
    }
  }

  /// Recently settled rounds for the history strip.
  ///
  /// Only real results are returned. v1 synthesised MD5 digits for rounds with
  /// no row, so the grid could show numbers that never settled a bet.
  Future<List<RecentRound>> getRecentRounds({int limit = 10}) async {
    try {
      final res = await _db.rpc(Rpc.getRecentRounds, params: {
        RpcParam.limit: limit,
      });
      if (res is! List) return const [];
      return res
          .map((e) => RecentRound.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('RoundApiService.getRecentRounds: $e');
      return const [];
    }
  }

  /// Per-board minimum and maximum stake per number.
  Future<Map<String, dynamic>?> getPlayLimits() async {
    try {
      final res = await _db.rpc(Rpc.getPlayLimits);
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('RoundApiService.getPlayLimits: $e');
      return null;
    }
  }
}
