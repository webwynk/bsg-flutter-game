// Unit tests for lib/services/lucky16_api_service.dart.
//
// Copied from test/lucky_card/lucky_card_api_service_test.dart and changed for
// the lucky16_* names, the A rank, 16 cards and 14x. The database is replaced
// by a scripted function, so every test runs offline. Error codes, messages
// and answers come from test/lucky16/fixtures/, adapted from Lucky Card's live
// captures (see fixtures/README.md).

import 'dart:async';
import 'dart:io';

import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/services/lucky16_api_contract.dart';
import 'package:best_smart_game/services/lucky16_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_lucky16_api.dart';
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

const _ace = Lucky16Card(Lucky16Rank.ace, Lucky16Suit.hearts);
const _jack = Lucky16Card(Lucky16Rank.jack, Lucky16Suit.hearts);
const _queen = Lucky16Card(Lucky16Rank.queen, Lucky16Suit.hearts);
const _king = Lucky16Card(Lucky16Rank.king, Lucky16Suit.hearts);

void main() {
  group('the names sent to the database', () {
    test('match the live function and parameter names exactly', () {
      expect(Lucky16Rpc.getCurrentRound, 'lucky16_get_current_round');
      expect(Lucky16Rpc.placeBet, 'lucky16_place_bet');
      expect(Lucky16Rpc.getMyRoundResult, 'lucky16_get_my_round_result');
      expect(Lucky16Rpc.getRecentRounds, 'lucky16_get_recent_rounds');
      expect(Lucky16RpcParam.roundId, 'p_round_id');
      expect(Lucky16RpcParam.bets, 'p_bets');
      expect(Lucky16RpcParam.limit, 'p_limit');
    });
  });

  group('getCurrentRound', () {
    test('asks the right function with no parameters and understands the answer', () async {
      final rec = _Recorder((_, __) async => loadFixture('current_round_betting.json'));
      final api = Lucky16ApiService(rpc: rec.call);
      final round = await api.getCurrentRound();
      expect(rec.calls, [('lucky16_get_current_round', null)]);
      expect(round, isNotNull);
      expect(round!.isDrawn, isFalse);
      expect(api.lastRoundError, isNull);
    });

    test('a drawn round carries the card and the bonus', () async {
      final api = Lucky16ApiService(rpc: (_, __) async => loadFixture('current_round_drawn.json'));
      final round = await api.getCurrentRound();
      expect(round!.winningCard, const Lucky16Card(Lucky16Rank.ace, Lucky16Suit.hearts));
      expect(round.bonusMultiplier, 3);
    });

    test('no answer at all is reported as offline', () async {
      final api = Lucky16ApiService(rpc: (_, __) async => null);
      expect(await api.getCurrentRound(), isNull);
      expect(api.lastRoundError, Lucky16Error.offline);
    });

    test('each kind of failure is told apart', () async {
      final cases = <Object, Lucky16Error>{
        const PostgrestException(message: 'Unauthenticated', code: 'P0100'): Lucky16Error.unauthenticated,
        const PostgrestException(message: 'JWT expired', code: 'PGRST301'): Lucky16Error.unauthenticated,
        const SocketException('no route to host'): Lucky16Error.offline,
        TimeoutException('too slow'): Lucky16Error.offline,
        StateError('something else'): Lucky16Error.unknown,
      };
      for (final entry in cases.entries) {
        final api = Lucky16ApiService(rpc: (_, __) => Future<dynamic>.error(entry.key));
        expect(await api.getCurrentRound(), isNull, reason: '${entry.key}');
        expect(api.lastRoundError, entry.value, reason: '${entry.key}');
      }
    });

    test('an answer in an unexpected shape is "unknown", never a crash', () async {
      final broken = loadFixtureMap('current_round_betting.json')..remove('round_id');
      final api = Lucky16ApiService(rpc: (_, __) async => broken);
      expect(await api.getCurrentRound(), isNull);
      expect(api.lastRoundError, Lucky16Error.unknown);
    });

    test('the failure reason is cleared by the next success', () async {
      var first = true;
      final api = Lucky16ApiService(rpc: (_, __) async {
        if (first) {
          first = false;
          throw const SocketException('blip');
        }
        return loadFixture('current_round_betting.json');
      });
      expect(await api.getCurrentRound(), isNull);
      expect(api.lastRoundError, Lucky16Error.offline);
      expect(await api.getCurrentRound(), isNotNull);
      expect(api.lastRoundError, isNull);
    });
  });

  group('placeBet', () {
    test('sends the round id and only the cards that hold chips, by their database keys', () async {
      final rec = _Recorder((_, __) async => loadFixture('place_bet_success.json'));
      final api = Lucky16ApiService(rpc: rec.call);
      final result = await api.placeBet(
        roundId: 'round-1',
        bets: {_jack: 100, _queen: 50, _king: 0},
      );
      expect(rec.calls.length, 1);
      expect(rec.calls.single.$1, 'lucky16_place_bet');
      expect(rec.calls.single.$2, {
        'p_round_id': 'round-1',
        'p_bets': {'j_hearts': 100, 'q_hearts': 50},
      });
      expect(result.success, isTrue);
      expect(result.totalStake, 160);
      expect(result.coinBalance, 67282);
      expect(result.ledgerVersion, 1460);
    });

    test('an ace goes out under its a_ key, next to the other ranks', () async {
      final rec = _Recorder((_, __) async => loadFixture('place_bet_success.json'));
      await Lucky16ApiService(rpc: rec.call).placeBet(
        roundId: 'round-2',
        bets: {_ace: 10000, _king: 5},
      );
      expect(rec.calls.single.$2, {
        'p_round_id': 'round-2',
        'p_bets': {'a_hearts': 10000, 'k_hearts': 5},
      });
    });

    test('an empty board, or one holding only zeros, is refused without calling the database', () async {
      final rec = _Recorder((_, __) async => fail('the database must not be called'));
      final api = Lucky16ApiService(rpc: rec.call);
      for (final bets in <Map<Lucky16Card, int>>[{}, {_jack: 0, _queen: 0}]) {
        final result = await api.placeBet(roundId: 'r', bets: bets);
        expect(result.success, isFalse);
        expect(result.error, Lucky16Error.emptyBet);
      }
      expect(rec.calls, isEmpty);
    });

    test('no answer is reported as offline', () async {
      final api = Lucky16ApiService(rpc: (_, __) async => null);
      final result = await api.placeBet(roundId: 'r', bets: {_jack: 50});
      expect(result.success, isFalse);
      expect(result.error, Lucky16Error.offline);
    });

    test('a rejected bet comes back as a failure carrying its reason', () async {
      final api = Lucky16ApiService(
        rpc: (_, __) => Future<dynamic>.error(const PostgrestException(message: 'ROUND_CLOSED', code: 'P0121')),
      );
      final result = await api.placeBet(roundId: 'r', bets: {_jack: 50});
      expect(result.success, isFalse);
      expect(result.error, Lucky16Error.roundClosed);
      expect(result.error!.isRetryable, isFalse);
    });
  });

  group('every database error the player functions raise is understood', () {
    final real = (loadFixture('errors.json') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    const expected = <String, Lucky16Error>{
      'P0100': Lucky16Error.unauthenticated,
      'P0112': Lucky16Error.insufficientCoins,
      'P0113': Lucky16Error.accountBlocked,
      'P0114': Lucky16Error.notAPlayer,
      'P0120': Lucky16Error.roundClosed,
      'P0121': Lucky16Error.roundClosed,
      'P0123': Lucky16Error.belowMin,
      'P0124': Lucky16Error.exceedsMax,
      'P0125': Lucky16Error.emptyBet,
      'P0126': Lucky16Error.badBet,
    };

    test('the captured set covers all ten codes the player functions can raise', () {
      expect(real.map((e) => e['sqlstate']).toSet(), expected.keys.toSet());
    });

    for (final e in real) {
      test('${e['sqlstate']} "${e['message']}" (${e['scenario']})', () async {
        final error = PostgrestException(message: e['message'] as String, code: e['sqlstate'] as String);
        expect(Lucky16ApiService.mapError(error), expected[e['sqlstate']]);
        final api = Lucky16ApiService(rpc: (_, __) => Future<dynamic>.error(error));
        final result = await api.placeBet(roundId: 'r', bets: {_jack: 50});
        expect(result.error, expected[e['sqlstate']]);
        expect(result.success, isFalse);
      });
    }
  });

  group('mapError for failures that are not Lucky 16 Card codes', () {
    test('a token problem is a sign-in problem, not "no internet"', () {
      expect(Lucky16ApiService.mapError(const PostgrestException(message: 'JWT expired')), Lucky16Error.unauthenticated);
      expect(Lucky16ApiService.mapError(const PostgrestException(message: 'x', code: 'PGRST303')), Lucky16Error.unauthenticated);
      expect(Lucky16ApiService.mapError(const AuthException('session gone')), Lucky16Error.unauthenticated);
    });

    test('a dropped connection is offline', () {
      expect(Lucky16ApiService.mapError(AuthRetryableFetchException()), Lucky16Error.offline);
      expect(Lucky16ApiService.mapError(const SocketException('x')), Lucky16Error.offline);
      expect(Lucky16ApiService.mapError(TimeoutException('x')), Lucky16Error.offline);
      expect(Lucky16ApiService.mapError(ClientException()), Lucky16Error.offline);
    });

    test('an unrecognised database error and an unrelated exception are "unknown"', () {
      expect(Lucky16ApiService.mapError(const PostgrestException(message: 'duplicate key', code: '23505')), Lucky16Error.unknown);
      expect(Lucky16ApiService.mapError(StateError('x')), Lucky16Error.unknown);
    });

    test('a Triple Chance code that Lucky 16 Card never raises is not mistaken for a card error', () {
      // P0122 is Triple Chance's bad-key code; Lucky 16 Card's own is P0126.
      expect(Lucky16ApiService.mapError(const PostgrestException(message: 'BAD_SINGLE_KEY:x', code: 'P0122')), Lucky16Error.unknown);
    });
  });

  group('getMyRoundResult', () {
    test('asks for the round and understands a settled win', () async {
      final rec = _Recorder((_, __) async => loadFixture('my_result_settled_win.json'));
      final result = await Lucky16ApiService(rpc: rec.call).getMyRoundResult('round-9');
      expect(rec.calls.single.$1, 'lucky16_get_my_round_result');
      expect(rec.calls.single.$2, {'p_round_id': 'round-9'});
      expect(result!.isSettled, isTrue);
      expect(result.totalPayout, 420);
    });

    test('"no bet" is an answer; no answer is null', () async {
      final noBet = await Lucky16ApiService(rpc: (_, __) async => loadFixture('my_result_no_bet.json')).getMyRoundResult('r');
      expect(noBet!.placedBet, isFalse);
      expect(await Lucky16ApiService(rpc: (_, __) async => null).getMyRoundResult('r'), isNull);
      expect(await Lucky16ApiService(rpc: (_, __) => Future<dynamic>.error(const SocketException('x'))).getMyRoundResult('r'), isNull);
    });
  });

  group('getRecentRounds', () {
    test('asks for the limit (10 by default) and understands the list', () async {
      final rec = _Recorder((_, __) async => loadFixture('recent_rounds.json'));
      final api = Lucky16ApiService(rpc: rec.call);
      final list = await api.getRecentRounds();
      expect(rec.calls.single.$1, 'lucky16_get_recent_rounds');
      expect(rec.calls.single.$2, {'p_limit': 10});
      expect(list.length, 3);
      await api.getRecentRounds(limit: 3);
      expect(rec.calls.last.$2, {'p_limit': 3});
    });

    test('an answer that is not a list, a failure, or a bad row all give an empty list', () async {
      expect(await Lucky16ApiService(rpc: (_, __) async => null).getRecentRounds(), isEmpty);
      expect(await Lucky16ApiService(rpc: (_, __) async => {'a': 1}).getRecentRounds(), isEmpty);
      expect(await Lucky16ApiService(rpc: (_, __) => Future<dynamic>.error(const SocketException('x'))).getRecentRounds(), isEmpty);
      final bad = [
        {'round_id': 'x', 'round_number': 1, 'scheduled_at': '2026-10-06T00:00:00+00:00', 'winning_rank': 'X', 'winning_suit': 'hearts', 'bonus_multiplier': 1},
      ];
      expect(await Lucky16ApiService(rpc: (_, __) async => bad).getRecentRounds(), isEmpty);
    });
  });

  group('the fake used by later steps', () {
    test('satisfies the same contract as the real service and records its calls', () async {
      final Lucky16Api api = FakeLucky16Api(
        rounds: [Lucky16RoundState.fromJson(loadFixtureMap('current_round_betting.json'))],
        betResults: const [Lucky16PlaceBetResult.failure(Lucky16Error.roundClosed)],
      );
      expect((await api.getCurrentRound())!.isDrawn, isFalse);
      final result = await api.placeBet(roundId: 'r1', bets: {_jack: 50});
      expect(result.error, Lucky16Error.roundClosed);
      expect((api as FakeLucky16Api).calls, ['getCurrentRound()', 'placeBet(r1, j_hearts:50)']);
    });
  });
}
