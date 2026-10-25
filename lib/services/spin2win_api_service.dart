// How the Spin2Win app calls the database.
//
// [Spin2WinApi] is the small contract the rest of the Spin2Win code talks
// to; [Spin2WinApiService] is the real implementation over the signed-in
// Supabase client. Everything that decides what to do (the betting board, the
// countdown, the reveal) depends only on [Spin2WinApi], so it can be tested
// offline with a fake that answers from a script.
//
// Belongs to Spin2Win only. It uses the shared Supabase client the app
// already initialised (`Supabase.instance.client`, the same one Triple
// Chance's services use) and nothing else from Triple Chance.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/spin2win_models.dart';
import 'spin2win_api_contract.dart';

/// What the Spin2Win code needs from the database.
abstract class Spin2WinApi {
  /// Why the last [getCurrentRound] returned null; `null` after a success.
  /// Lets the screen tell "offline" from "your sign-in expired".
  Spin2WinError? get lastRoundError;

  /// The round the server clock is in. Creates it on demand and, once the cycle
  /// passes the draw second, draws and settles it. Returns null on any failure.
  Future<Spin2WinRoundState?> getCurrentRound();

  /// Places this player's bet for [roundId]; sending again replaces it and only
  /// the difference is charged or refunded. [bets] maps a number (0 to 9) to
  /// its stake; numbers holding 0 are not sent. An
  /// empty bet is refused here, without a network call, as
  /// [Spin2WinError.emptyBet].
  Future<Spin2WinPlaceBetResult> placeBet({
    required String roundId,
    required Map<int, int> bets,
  });

  /// This player's outcome for [roundId]. Null only when no answer arrived, so
  /// the caller can tell "no answer" from "no bet".
  Future<Spin2WinMyResult?> getMyRoundResult(String roundId);

  /// The most recent drawn rounds, newest first, the same for every player. An
  /// empty list when nothing came back.
  Future<List<Spin2WinRecentRound>> getRecentRounds({int limit = 10});
}

/// Sends one database function call and returns its decoded JSON. The real
/// version calls `Supabase.instance.client.rpc`; tests pass a scripted one.
typedef Spin2WinRpcCall = Future<dynamic> Function(
    String function, Map<String, dynamic>? params);

Future<dynamic> _supabaseRpc(String function, Map<String, dynamic>? params) =>
    Supabase.instance.client.rpc(function, params: params);

/// The real [Spin2WinApi], over the signed-in Supabase client.
class Spin2WinApiService implements Spin2WinApi {
  /// Pass [rpc] only in tests; by default every call goes through the app's
  /// authenticated Supabase client.
  Spin2WinApiService({Spin2WinRpcCall? rpc}) : _rpc = rpc ?? _supabaseRpc;

  final Spin2WinRpcCall _rpc;

  Spin2WinError? _lastRoundError;

  @override
  Spin2WinError? get lastRoundError => _lastRoundError;

  /// Turns whatever a call threw into a [Spin2WinError].
  ///
  /// The database's SQLSTATE code is matched first, never the message text (the
  /// old Triple Chance mapper once matched an English message that the database
  /// never produced, so a branch silently never fired). Only when there is no
  /// recognised code are sign-in problems and network failures told apart, so
  /// an expired session is not reported as "no internet".
  static Spin2WinError mapError(Object error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case Spin2WinErrCode.unauthenticated:
          return Spin2WinError.unauthenticated;
        case Spin2WinErrCode.insufficient:
          return Spin2WinError.insufficientCoins;
        case Spin2WinErrCode.accountBlocked:
          return Spin2WinError.accountBlocked;
        case Spin2WinErrCode.notAPlayer:
          return Spin2WinError.notAPlayer;
        case Spin2WinErrCode.roundNotFound:
        case Spin2WinErrCode.roundClosed:
          return Spin2WinError.roundClosed;
        case Spin2WinErrCode.belowMin:
          return Spin2WinError.belowMin;
        case Spin2WinErrCode.exceedsMax:
          return Spin2WinError.exceedsMax;
        case Spin2WinErrCode.emptyBet:
          return Spin2WinError.emptyBet;
        case Spin2WinErrCode.badBet:
          return Spin2WinError.badBet;
      }
      // PostgREST's own token problems ("JWT expired" and similar) carry a
      // PGRST30x code and no Spin2Win code.
      final code = error.code ?? '';
      if (code.startsWith('PGRST30') ||
          error.message.toLowerCase().contains('jwt')) {
        return Spin2WinError.unauthenticated;
      }
      return Spin2WinError.unknown;
    }
    // The sign-in library reports a dropped connection as a retryable fetch
    // error; every other auth error means the session itself is no good.
    if (error is AuthRetryableFetchException) return Spin2WinError.offline;
    if (error is AuthException) return Spin2WinError.unauthenticated;
    if (error is SocketException || error is TimeoutException) {
      return Spin2WinError.offline;
    }
    // The HTTP package's ClientException is not imported here (it is not a
    // direct dependency of this app), so it is recognised by name.
    final type = error.runtimeType.toString();
    if (type.contains('ClientException') || type.contains('HandshakeException')) {
      return Spin2WinError.offline;
    }
    return Spin2WinError.unknown;
  }

  @override
  Future<Spin2WinRoundState?> getCurrentRound() async {
    try {
      final res = await _rpc(Spin2WinRpc.getCurrentRound, null);
      if (res == null) {
        _lastRoundError = Spin2WinError.offline;
        return null;
      }
      final round = Spin2WinRoundState.fromJson(_asMap(res));
      _lastRoundError = null;
      return round;
    } catch (e) {
      _lastRoundError = mapError(e);
      debugPrint('Spin2WinApiService.getCurrentRound failed: '
          '${_lastRoundError!.name} ($e)');
      return null;
    }
  }

  @override
  Future<Spin2WinPlaceBetResult> placeBet({
    required String roundId,
    required Map<int, int> bets,
  }) async {
    // Only numbers that really hold chips are sent; the board never holds a zero,
    // and the database would treat one as "no chips" anyway.
    final payload = <String, int>{
      for (final entry in bets.entries)
        if (entry.value > 0) spin2WinKey(entry.key): entry.value,
    };
    if (payload.isEmpty) {
      return const Spin2WinPlaceBetResult.failure(Spin2WinError.emptyBet);
    }
    try {
      final res = await _rpc(Spin2WinRpc.placeBet, {
        Spin2WinRpcParam.roundId: roundId,
        Spin2WinRpcParam.bets: payload,
      });
      if (res == null) {
        return const Spin2WinPlaceBetResult.failure(Spin2WinError.offline);
      }
      return Spin2WinPlaceBetResult.fromJson(_asMap(res));
    } catch (e) {
      final mapped = mapError(e);
      debugPrint('Spin2WinApiService.placeBet rejected: ${mapped.name} ($e)');
      return Spin2WinPlaceBetResult.failure(mapped);
    }
  }

  @override
  Future<Spin2WinMyResult?> getMyRoundResult(String roundId) async {
    try {
      final res = await _rpc(Spin2WinRpc.getMyRoundResult, {
        Spin2WinRpcParam.roundId: roundId,
      });
      if (res == null) return null;
      return Spin2WinMyResult.fromJson(_asMap(res));
    } catch (e) {
      debugPrint('Spin2WinApiService.getMyRoundResult failed: $e');
      return null;
    }
  }

  @override
  Future<List<Spin2WinRecentRound>> getRecentRounds({int limit = 10}) async {
    try {
      final res = await _rpc(Spin2WinRpc.getRecentRounds, {
        Spin2WinRpcParam.limit: limit,
      });
      if (res is! List) return const [];
      // One row that cannot be understood (a number outside 0 to 9, say)
      // throws here and the whole list is dropped: an honest empty history is
      // better than a strip that silently skips a round.
      return [
        for (final item in res) Spin2WinRecentRound.fromJson(_asMap(item)),
      ];
    } catch (e) {
      debugPrint('Spin2WinApiService.getRecentRounds failed: $e');
      return const [];
    }
  }

  static Map<String, dynamic> _asMap(Object? value) =>
      Map<String, dynamic>.from(value as Map);
}
