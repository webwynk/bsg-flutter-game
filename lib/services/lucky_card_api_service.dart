// How the Lucky Card app calls the database.
//
// [LuckyCardApi] is the small contract the rest of the Lucky Card code talks
// to; [LuckyCardApiService] is the real implementation over the signed-in
// Supabase client. Everything that decides what to do (the betting board, the
// countdown, the reveal) depends only on [LuckyCardApi], so it can be tested
// offline with a fake that answers from a script.
//
// Belongs to Lucky Card only. It uses the shared Supabase client the app
// already initialised (`Supabase.instance.client`, the same one Triple
// Chance's services use) and nothing else from Triple Chance.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lucky_card_models.dart';
import 'lucky_card_api_contract.dart';

/// What the Lucky Card code needs from the database.
abstract class LuckyCardApi {
  /// Why the last [getCurrentRound] returned null; `null` after a success.
  /// Lets the screen tell "offline" from "your sign-in expired".
  LuckyCardError? get lastRoundError;

  /// The round the server clock is in. Creates it on demand and, once the cycle
  /// passes the draw second, draws and settles it. Returns null on any failure.
  Future<LuckyCardRoundState?> getCurrentRound();

  /// Places this player's bet for [roundId]; sending again replaces it and only
  /// the difference is charged or refunded. Cards holding 0 are not sent. An
  /// empty bet is refused here, without a network call, as
  /// [LuckyCardError.emptyBet].
  Future<LuckyCardPlaceBetResult> placeBet({
    required String roundId,
    required Map<LuckyCard, int> bets,
  });

  /// This player's outcome for [roundId]. Null only when no answer arrived, so
  /// the caller can tell "no answer" from "no bet".
  Future<LuckyCardMyResult?> getMyRoundResult(String roundId);

  /// The most recent drawn rounds, newest first, the same for every player. An
  /// empty list when nothing came back.
  Future<List<LuckyCardRecentRound>> getRecentRounds({int limit = 10});
}

/// Sends one database function call and returns its decoded JSON. The real
/// version calls `Supabase.instance.client.rpc`; tests pass a scripted one.
typedef LuckyCardRpcCall = Future<dynamic> Function(
    String function, Map<String, dynamic>? params);

Future<dynamic> _supabaseRpc(String function, Map<String, dynamic>? params) =>
    Supabase.instance.client.rpc(function, params: params);

/// The real [LuckyCardApi], over the signed-in Supabase client.
class LuckyCardApiService implements LuckyCardApi {
  /// Pass [rpc] only in tests; by default every call goes through the app's
  /// authenticated Supabase client.
  LuckyCardApiService({LuckyCardRpcCall? rpc}) : _rpc = rpc ?? _supabaseRpc;

  final LuckyCardRpcCall _rpc;

  LuckyCardError? _lastRoundError;

  @override
  LuckyCardError? get lastRoundError => _lastRoundError;

  /// Turns whatever a call threw into a [LuckyCardError].
  ///
  /// The database's SQLSTATE code is matched first, never the message text (the
  /// old Triple Chance mapper once matched an English message that the database
  /// never produced, so a branch silently never fired). Only when there is no
  /// recognised code are sign-in problems and network failures told apart, so
  /// an expired session is not reported as "no internet".
  static LuckyCardError mapError(Object error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case LuckyCardErrCode.unauthenticated:
          return LuckyCardError.unauthenticated;
        case LuckyCardErrCode.insufficient:
          return LuckyCardError.insufficientCoins;
        case LuckyCardErrCode.accountBlocked:
          return LuckyCardError.accountBlocked;
        case LuckyCardErrCode.notAPlayer:
          return LuckyCardError.notAPlayer;
        case LuckyCardErrCode.roundNotFound:
        case LuckyCardErrCode.roundClosed:
          return LuckyCardError.roundClosed;
        case LuckyCardErrCode.belowMin:
          return LuckyCardError.belowMin;
        case LuckyCardErrCode.exceedsMax:
          return LuckyCardError.exceedsMax;
        case LuckyCardErrCode.emptyBet:
          return LuckyCardError.emptyBet;
        case LuckyCardErrCode.badBet:
          return LuckyCardError.badBet;
      }
      // PostgREST's own token problems ("JWT expired" and similar) carry a
      // PGRST30x code and no Lucky Card code.
      final code = error.code ?? '';
      if (code.startsWith('PGRST30') ||
          error.message.toLowerCase().contains('jwt')) {
        return LuckyCardError.unauthenticated;
      }
      return LuckyCardError.unknown;
    }
    // The sign-in library reports a dropped connection as a retryable fetch
    // error; every other auth error means the session itself is no good.
    if (error is AuthRetryableFetchException) return LuckyCardError.offline;
    if (error is AuthException) return LuckyCardError.unauthenticated;
    if (error is SocketException || error is TimeoutException) {
      return LuckyCardError.offline;
    }
    // The HTTP package's ClientException is not imported here (it is not a
    // direct dependency of this app), so it is recognised by name.
    final type = error.runtimeType.toString();
    if (type.contains('ClientException') || type.contains('HandshakeException')) {
      return LuckyCardError.offline;
    }
    return LuckyCardError.unknown;
  }

  @override
  Future<LuckyCardRoundState?> getCurrentRound() async {
    try {
      final res = await _rpc(LuckyCardRpc.getCurrentRound, null);
      if (res == null) {
        _lastRoundError = LuckyCardError.offline;
        return null;
      }
      final round = LuckyCardRoundState.fromJson(_asMap(res));
      _lastRoundError = null;
      return round;
    } catch (e) {
      _lastRoundError = mapError(e);
      debugPrint('LuckyCardApiService.getCurrentRound failed: '
          '${_lastRoundError!.name} ($e)');
      return null;
    }
  }

  @override
  Future<LuckyCardPlaceBetResult> placeBet({
    required String roundId,
    required Map<LuckyCard, int> bets,
  }) async {
    // Only cards that really hold chips are sent; the board never holds a zero,
    // and the database would treat one as "no chips" anyway.
    final payload = <String, int>{
      for (final entry in bets.entries)
        if (entry.value > 0) entry.key.key: entry.value,
    };
    if (payload.isEmpty) {
      return const LuckyCardPlaceBetResult.failure(LuckyCardError.emptyBet);
    }
    try {
      final res = await _rpc(LuckyCardRpc.placeBet, {
        LuckyCardRpcParam.roundId: roundId,
        LuckyCardRpcParam.bets: payload,
      });
      if (res == null) {
        return const LuckyCardPlaceBetResult.failure(LuckyCardError.offline);
      }
      return LuckyCardPlaceBetResult.fromJson(_asMap(res));
    } catch (e) {
      final mapped = mapError(e);
      debugPrint('LuckyCardApiService.placeBet rejected: ${mapped.name} ($e)');
      return LuckyCardPlaceBetResult.failure(mapped);
    }
  }

  @override
  Future<LuckyCardMyResult?> getMyRoundResult(String roundId) async {
    try {
      final res = await _rpc(LuckyCardRpc.getMyRoundResult, {
        LuckyCardRpcParam.roundId: roundId,
      });
      if (res == null) return null;
      return LuckyCardMyResult.fromJson(_asMap(res));
    } catch (e) {
      debugPrint('LuckyCardApiService.getMyRoundResult failed: $e');
      return null;
    }
  }

  @override
  Future<List<LuckyCardRecentRound>> getRecentRounds({int limit = 10}) async {
    try {
      final res = await _rpc(LuckyCardRpc.getRecentRounds, {
        LuckyCardRpcParam.limit: limit,
      });
      if (res is! List) return const [];
      // One row that cannot be understood (a changed card or suit word, say)
      // throws here and the whole list is dropped: an honest empty history is
      // better than a strip that silently skips a round.
      return [
        for (final item in res) LuckyCardRecentRound.fromJson(_asMap(item)),
      ];
    } catch (e) {
      debugPrint('LuckyCardApiService.getRecentRounds failed: $e');
      return const [];
    }
  }

  static Map<String, dynamic> _asMap(Object? value) =>
      Map<String, dynamic>.from(value as Map);
}
