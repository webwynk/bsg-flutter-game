// How the Lucky 16 Card app calls the database.
//
// [Lucky16Api] is the small contract the rest of the Lucky 16 Card code talks
// to; [Lucky16ApiService] is the real implementation over the signed-in
// Supabase client. Everything that decides what to do (the betting board, the
// countdown, the reveal) depends only on [Lucky16Api], so it can be tested
// offline with a fake that answers from a script.
//
// Copied from lib/services/lucky_card_api_service.dart (Lucky Card); only the
// names changed, because lucky16_* functions answer with the same JSON fields
// and raise the same error codes as Lucky Card's.
//
// Belongs to Lucky 16 Card only. It uses the shared Supabase client the app
// already initialised (`Supabase.instance.client`, the same one Triple
// Chance's services use) and nothing else from Triple Chance or Lucky Card.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lucky16_models.dart';
import 'lucky16_api_contract.dart';

/// What the Lucky 16 Card code needs from the database.
abstract class Lucky16Api {
  /// Why the last [getCurrentRound] returned null; `null` after a success.
  /// Lets the screen tell "offline" from "your sign-in expired".
  Lucky16Error? get lastRoundError;

  /// The round the server clock is in. Creates it on demand and, once the cycle
  /// passes the draw second, draws and settles it. Returns null on any failure.
  Future<Lucky16RoundState?> getCurrentRound();

  /// Places this player's bet for [roundId]; sending again replaces it and only
  /// the difference is charged or refunded. Cards holding 0 are not sent. An
  /// empty bet is refused here, without a network call, as
  /// [Lucky16Error.emptyBet].
  Future<Lucky16PlaceBetResult> placeBet({
    required String roundId,
    required Map<Lucky16Card, int> bets,
  });

  /// This player's outcome for [roundId]. Null only when no answer arrived, so
  /// the caller can tell "no answer" from "no bet".
  Future<Lucky16MyResult?> getMyRoundResult(String roundId);

  /// The most recent drawn rounds, newest first, the same for every player. An
  /// empty list when nothing came back.
  Future<List<Lucky16RecentRound>> getRecentRounds({int limit = 10});
}

/// Sends one database function call and returns its decoded JSON. The real
/// version calls `Supabase.instance.client.rpc`; tests pass a scripted one.
typedef Lucky16RpcCall = Future<dynamic> Function(
    String function, Map<String, dynamic>? params);

Future<dynamic> _supabaseRpc(String function, Map<String, dynamic>? params) =>
    Supabase.instance.client.rpc(function, params: params);

/// The real [Lucky16Api], over the signed-in Supabase client.
class Lucky16ApiService implements Lucky16Api {
  /// Pass [rpc] only in tests; by default every call goes through the app's
  /// authenticated Supabase client.
  Lucky16ApiService({Lucky16RpcCall? rpc}) : _rpc = rpc ?? _supabaseRpc;

  final Lucky16RpcCall _rpc;

  Lucky16Error? _lastRoundError;

  @override
  Lucky16Error? get lastRoundError => _lastRoundError;

  /// Turns whatever a call threw into a [Lucky16Error].
  ///
  /// The database's SQLSTATE code is matched first, never the message text (the
  /// old Triple Chance mapper once matched an English message that the database
  /// never produced, so a branch silently never fired). Only when there is no
  /// recognised code are sign-in problems and network failures told apart, so
  /// an expired session is not reported as "no internet".
  static Lucky16Error mapError(Object error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case Lucky16ErrCode.unauthenticated:
          return Lucky16Error.unauthenticated;
        case Lucky16ErrCode.insufficient:
          return Lucky16Error.insufficientCoins;
        case Lucky16ErrCode.accountBlocked:
          return Lucky16Error.accountBlocked;
        case Lucky16ErrCode.notAPlayer:
          return Lucky16Error.notAPlayer;
        case Lucky16ErrCode.roundNotFound:
        case Lucky16ErrCode.roundClosed:
          return Lucky16Error.roundClosed;
        case Lucky16ErrCode.belowMin:
          return Lucky16Error.belowMin;
        case Lucky16ErrCode.exceedsMax:
          return Lucky16Error.exceedsMax;
        case Lucky16ErrCode.emptyBet:
          return Lucky16Error.emptyBet;
        case Lucky16ErrCode.badBet:
          return Lucky16Error.badBet;
      }
      // PostgREST's own token problems ("JWT expired" and similar) carry a
      // PGRST30x code and no Lucky 16 Card code.
      final code = error.code ?? '';
      if (code.startsWith('PGRST30') ||
          error.message.toLowerCase().contains('jwt')) {
        return Lucky16Error.unauthenticated;
      }
      return Lucky16Error.unknown;
    }
    // The sign-in library reports a dropped connection as a retryable fetch
    // error; every other auth error means the session itself is no good.
    if (error is AuthRetryableFetchException) return Lucky16Error.offline;
    if (error is AuthException) return Lucky16Error.unauthenticated;
    if (error is SocketException || error is TimeoutException) {
      return Lucky16Error.offline;
    }
    // The HTTP package's ClientException is not imported here (it is not a
    // direct dependency of this app), so it is recognised by name.
    final type = error.runtimeType.toString();
    if (type.contains('ClientException') || type.contains('HandshakeException')) {
      return Lucky16Error.offline;
    }
    return Lucky16Error.unknown;
  }

  @override
  Future<Lucky16RoundState?> getCurrentRound() async {
    try {
      final res = await _rpc(Lucky16Rpc.getCurrentRound, null);
      if (res == null) {
        _lastRoundError = Lucky16Error.offline;
        return null;
      }
      final round = Lucky16RoundState.fromJson(_asMap(res));
      _lastRoundError = null;
      return round;
    } catch (e) {
      _lastRoundError = mapError(e);
      debugPrint('Lucky16ApiService.getCurrentRound failed: '
          '${_lastRoundError!.name} ($e)');
      return null;
    }
  }

  @override
  Future<Lucky16PlaceBetResult> placeBet({
    required String roundId,
    required Map<Lucky16Card, int> bets,
  }) async {
    // Only cards that really hold chips are sent; the board never holds a zero,
    // and the database would treat one as "no chips" anyway.
    final payload = <String, int>{
      for (final entry in bets.entries)
        if (entry.value > 0) entry.key.key: entry.value,
    };
    if (payload.isEmpty) {
      return const Lucky16PlaceBetResult.failure(Lucky16Error.emptyBet);
    }
    try {
      final res = await _rpc(Lucky16Rpc.placeBet, {
        Lucky16RpcParam.roundId: roundId,
        Lucky16RpcParam.bets: payload,
      });
      if (res == null) {
        return const Lucky16PlaceBetResult.failure(Lucky16Error.offline);
      }
      return Lucky16PlaceBetResult.fromJson(_asMap(res));
    } catch (e) {
      final mapped = mapError(e);
      debugPrint('Lucky16ApiService.placeBet rejected: ${mapped.name} ($e)');
      return Lucky16PlaceBetResult.failure(mapped);
    }
  }

  @override
  Future<Lucky16MyResult?> getMyRoundResult(String roundId) async {
    try {
      final res = await _rpc(Lucky16Rpc.getMyRoundResult, {
        Lucky16RpcParam.roundId: roundId,
      });
      if (res == null) return null;
      return Lucky16MyResult.fromJson(_asMap(res));
    } catch (e) {
      debugPrint('Lucky16ApiService.getMyRoundResult failed: $e');
      return null;
    }
  }

  @override
  Future<List<Lucky16RecentRound>> getRecentRounds({int limit = 10}) async {
    try {
      final res = await _rpc(Lucky16Rpc.getRecentRounds, {
        Lucky16RpcParam.limit: limit,
      });
      if (res is! List) return const [];
      // One row that cannot be understood (a changed card or suit word, say)
      // throws here and the whole list is dropped: an honest empty history is
      // better than a strip that silently skips a round.
      return [
        for (final item in res) Lucky16RecentRound.fromJson(_asMap(item)),
      ];
    } catch (e) {
      debugPrint('Lucky16ApiService.getRecentRounds failed: $e');
      return const [];
    }
  }

  static Map<String, dynamic> _asMap(Object? value) =>
      Map<String, dynamic>.from(value as Map);
}
