// Unit tests for lib/services/spin2win_api_service.dart.
//
// The database is replaced by a scripted function, so every test runs offline.
// Error codes and messages are the ones the Spin2Win functions raise
// (test/spin2win/fixtures/errors.json, from migration 20261024250000); round,
// bet and result answers come from the other fixtures.

import 'dart:async';
import 'dart:io';

import 'package:best_smart_game/models/spin2win_models.dart';
import 'package:best_smart_game/services/spin2win_api_contract.dart';
import 'package:best_smart_game/services/spin2win_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_spin2win_api.dart';
import 'test_support.dart';

/// Records every call and answers from [handler].
class _Recorder {
  _Recorder(this.handler);

  final Future<dynamic> Function(String function, Map<String, dynamic>? params) handler;
  final List<(String, Map<String, dynamic>?)> calls = [];

  Future<dynamic> call(String function, Map<String, dynamic>? params) {
    calls.add((function, params));
    return handler(function, params);
  }
}

/// A class with the same name as the HTTP package's, to prove the service
/// recognises a dropped connection by name without importing that package.
class ClientException implements Exception {
  @override
  String toString() => 'ClientException: connection closed';
}

const _seven = 7;
const _three = 3;
const _zero = 0;

void main() {
  group('the names sent to the database', () {
    test('match the live function and parameter names exactly', () {
      expect(Spin2WinRpc.getCurrentRound, 'spin2win_get_current_round');
      expect(Spin2WinRpc.placeBet, 'spin2win_place_bet');
      expect(Spin2WinRpc.getMyRoundResult, 'spin2win_get_my_round_result');
      expect(Spin2WinRpc.getRecentRounds, 'spin2win_get_recent_rounds');
      expect(Spin2WinRpcParam.roundId, 'p_round_id');
      expect(Spin2WinRpcParam.bets, 'p_bets');
      expect(Spin2WinRpcParam.limit, 'p_limit');
    });
  });

  group('getCurrentRound', () {
    test('asks the right function with no parameters and understands the answer', () async {
      final rec = _Recorder((_, __) async => loadFixture('current_round_betting.json'));
      final api = Spin2WinApiService(rpc: rec.call);
      final round = await api.getCurrentRound();
      expect(rec.calls, [('spin2win_get_current_round', null)]);
      expect(round, isNotNull);
      expect(round!.isDrawn, isFalse);
      expect(api.lastRoundError, isNull);
    });

    test('a drawn round carries the number and the bonus', () async {
      final api = Spin2WinApiService(rpc: (_, __) async => loadFixture('current_round_drawn.json'));
      final round = await api.getCurrentRound();
      expect(round!.winningNumber, 7);
      expect(round.bonusMultiplier, 3);
    });

    test('no answer at all is reported as offline', () async {
      final api = Spin2WinApiService(rpc: (_, __) async => null);
      expect(await api.getCurrentRound(), isNull);
      expect(api.lastRoundError, Spin2WinError.offline);
    });

    test('each kind of failure is told apart', () async {
      final cases = <Object, Spin2WinError>{
        const PostgrestException(message: 'Unauthenticated', code: 'P0100'): Spin2WinError.unauthenticated,
        const PostgrestException(message: 'JWT expired', code: 'PGRST301'): Spin2WinError.unauthenticated,
        const SocketException('no route to host'): Spin2WinError.offline,
        TimeoutException('too slow'): Spin2WinError.offline,
        StateError('something else'): Spin2WinError.unknown,
      };
      for (final entry in cases.entries) {
        final api = Spin2WinApiService(rpc: (_, __) => Future<dynamic>.error(entry.key));
        expect(await api.getCurrentRound(), isNull, reason: '${entry.key}');
        expect(api.lastRoundError, entry.value, reason: '${entry.key}');
      }
    });

    test('an answer in an unexpected shape is "unknown", never a crash', () async {
      final broken = loadFixtureMap('current_round_betting.json')..remove('round_id');
      final api = Spin2WinApiService(rpc: (_, __) async => broken);
      expect(await api.getCurrentRound(), isNull);
      expect(api.lastRoundError, Spin2WinError.unknown);
    });

    test('the failure reason is cleared by the next success', () async {
      var first = true;
      final api = Spin2WinApiService(rpc: (_, __) async {
        if (first) {
          first = false;
          throw const SocketException('blip');
        }
        return loadFixture('current_round_betting.json');
      });
      expect(await api.getCurrentRound(), isNull);
      expect(api.lastRoundError, Spin2WinError.offline);
      expect(await api.getCurrentRound(), isNotNull);
      expect(api.lastRoundError, isNull);
    });
  });

  group('placeBet', () {
    test('sends the round id and only the numbers that hold chips, by their database keys', () async {
      final rec = _Recorder((_, __) async => loadFixture('place_bet_success.json'));
      final api = Spin2WinApiService(rpc: rec.call);
      final result = await api.placeBet(
        roundId: 'round-1',
        bets: {_seven: 100, _three: 50, _zero: 0},
      );
      expect(rec.calls.length, 1);
      expect(rec.calls.single.$1, 'spin2win_place_bet');
      expect(rec.calls.single.$2, {
        'p_round_id': 'round-1',
        'p_bets': {'n7': 100, 'n3': 50},
      });
      expect(result.success, isTrue);
      expect(result.totalStake, 100);
      expect(result.coinBalance, 67322);
      expect(result.ledgerVersion, 1460);
    });

    test('an empty board, or one holding only zeros, is refused without calling the database', () async {
      final rec = _Recorder((_, __) async => fail('the database must not be called'));
      final api = Spin2WinApiService(rpc: rec.call);
      for (final bets in <Map<int, int>>[{}, {_seven: 0, _three: 0}]) {
        final result = await api.placeBet(roundId: 'r', bets: bets);
        expect(result.success, isFalse);
        expect(result.error, Spin2WinError.emptyBet);
      }
      expect(rec.calls, isEmpty);
    });

    test('no answer is reported as offline', () async {
      final api = Spin2WinApiService(rpc: (_, __) async => null);
      final result = await api.placeBet(roundId: 'r', bets: {_seven: 50});
      expect(result.success, isFalse);
      expect(result.error, Spin2WinError.offline);
    });

    test('a rejected bet comes back as a failure carrying its reason', () async {
      final api = Spin2WinApiService(
        rpc: (_, __) => Future<dynamic>.error(const PostgrestException(message: 'ROUND_CLOSED', code: 'P0121')),
      );
      final result = await api.placeBet(roundId: 'r', bets: {_seven: 50});
      expect(result.success, isFalse);
      expect(result.error, Spin2WinError.roundClosed);
      expect(result.error!.isRetryable, isFalse);
    });
  });

  group('every real database error is understood', () {
    final real = (loadFixture('errors.json') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    const expected = <String, Spin2WinError>{
      'P0100': Spin2WinError.unauthenticated,
      'P0112': Spin2WinError.insufficientCoins,
      'P0113': Spin2WinError.accountBlocked,
      'P0114': Spin2WinError.notAPlayer,
      'P0120': Spin2WinError.roundClosed,
      'P0121': Spin2WinError.roundClosed,
      'P0123': Spin2WinError.belowMin,
      'P0124': Spin2WinError.exceedsMax,
      'P0125': Spin2WinError.emptyBet,
      'P0126': Spin2WinError.badBet,
    };

    test('the fixture set covers all ten codes the player functions can raise', () {
      expect(real.map((e) => e['sqlstate']).toSet(), expected.keys.toSet());
    });

    for (final e in real) {
      test('${e['sqlstate']} "${e['message']}" (${e['scenario']})', () async {
        final error = PostgrestException(message: e['message'] as String, code: e['sqlstate'] as String);
        expect(Spin2WinApiService.mapError(error), expected[e['sqlstate']]);
        final api = Spin2WinApiService(rpc: (_, __) => Future<dynamic>.error(error));
        final result = await api.placeBet(roundId: 'r', bets: {_seven: 50});
        expect(result.error, expected[e['sqlstate']]);
        expect(result.success, isFalse);
      });
    }
  });

  group('mapError for failures that are not Spin2Win codes', () {
    test('a token problem is a sign-in problem, not "no internet"', () {
      expect(Spin2WinApiService.mapError(const PostgrestException(message: 'JWT expired')), Spin2WinError.unauthenticated);
      expect(Spin2WinApiService.mapError(const PostgrestException(message: 'x', code: 'PGRST303')), Spin2WinError.unauthenticated);
      expect(Spin2WinApiService.mapError(const AuthException('session gone')), Spin2WinError.unauthenticated);
    });

    test('a dropped connection is offline', () {
      expect(Spin2WinApiService.mapError(AuthRetryableFetchException()), Spin2WinError.offline);
      expect(Spin2WinApiService.mapError(const SocketException('x')), Spin2WinError.offline);
      expect(Spin2WinApiService.mapError(TimeoutException('x')), Spin2WinError.offline);
      expect(Spin2WinApiService.mapError(ClientException()), Spin2WinError.offline);
    });

    test('an unrecognised database error and an unrelated exception are "unknown"', () {
      expect(Spin2WinApiService.mapError(const PostgrestException(message: 'duplicate key', code: '23505')), Spin2WinError.unknown);
      expect(Spin2WinApiService.mapError(StateError('x')), Spin2WinError.unknown);
    });

    test('a Triple Chance code that Spin2Win never raises is not mistaken for a Spin2Win error', () {
      // P0122 is Triple Chance's bad-key code; Spin2Win's own is P0126.
      expect(Spin2WinApiService.mapError(const PostgrestException(message: 'BAD_SINGLE_KEY:x', code: 'P0122')), Spin2WinError.unknown);
    });
  });

  group('getMyRoundResult', () {
    test('asks for the round and understands a settled win', () async {
      final rec = _Recorder((_, __) async => loadFixture('my_result_settled_win.json'));
      final result = await Spin2WinApiService(rpc: rec.call).getMyRoundResult('round-9');
      expect(rec.calls.single.$1, 'spin2win_get_my_round_result');
      expect(rec.calls.single.$2, {'p_round_id': 'round-9'});
      expect(result!.isSettled, isTrue);
      expect(result.totalPayout, 270);
    });

    test('"no bet" is an answer; no answer is null', () async {
      final noBet = await Spin2WinApiService(rpc: (_, __) async => loadFixture('my_result_no_bet.json')).getMyRoundResult('r');
      expect(noBet!.placedBet, isFalse);
      expect(await Spin2WinApiService(rpc: (_, __) async => null).getMyRoundResult('r'), isNull);
      expect(await Spin2WinApiService(rpc: (_, __) => Future<dynamic>.error(const SocketException('x'))).getMyRoundResult('r'), isNull);
    });
  });

  group('getRecentRounds', () {
    test('asks for the limit (10 by default) and understands the list', () async {
      final rec = _Recorder((_, __) async => loadFixture('recent_rounds.json'));
      final api = Spin2WinApiService(rpc: rec.call);
      final list = await api.getRecentRounds();
      expect(rec.calls.single.$1, 'spin2win_get_recent_rounds');
      expect(rec.calls.single.$2, {'p_limit': 10});
      expect(list.length, 3);
      await api.getRecentRounds(limit: 3);
      expect(rec.calls.last.$2, {'p_limit': 3});
    });

    test('an answer that is not a list, a failure, or a bad row all give an empty list', () async {
      expect(await Spin2WinApiService(rpc: (_, __) async => null).getRecentRounds(), isEmpty);
      expect(await Spin2WinApiService(rpc: (_, __) async => {'a': 1}).getRecentRounds(), isEmpty);
      expect(await Spin2WinApiService(rpc: (_, __) => Future<dynamic>.error(const SocketException('x'))).getRecentRounds(), isEmpty);
      final bad = [
        {'round_id': 'x', 'round_number': 1, 'scheduled_at': '2026-10-06T00:00:00+00:00', 'winning_number': 10, 'bonus_multiplier': 1},
      ];
      expect(await Spin2WinApiService(rpc: (_, __) async => bad).getRecentRounds(), isEmpty);
    });
  });

  group('the fake used by later steps', () {
    test('satisfies the same contract as the real service and records its calls', () async {
      final Spin2WinApi api = FakeSpin2WinApi(
        rounds: [Spin2WinRoundState.fromJson(loadFixtureMap('current_round_betting.json'))],
        betResults: const [Spin2WinPlaceBetResult.failure(Spin2WinError.roundClosed)],
      );
      expect((await api.getCurrentRound())!.isDrawn, isFalse);
      final result = await api.placeBet(roundId: 'r1', bets: {_seven: 50});
      expect(result.error, Spin2WinError.roundClosed);
      expect((api as FakeSpin2WinApi).calls, ['getCurrentRound()', 'placeBet(r1, n7:50)']);
    });
  });
}
