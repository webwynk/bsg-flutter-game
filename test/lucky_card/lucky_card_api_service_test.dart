// Unit tests for lib/services/lucky_card_api_service.dart.
//
// The database is replaced by a scripted function, so every test runs offline.
// Error codes and messages come from the real database
// (test/lucky_card/fixtures/errors.json); round, bet and result answers from
// the other fixtures.

import 'dart:async';
import 'dart:io';

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/services/lucky_card_api_contract.dart';
import 'package:best_smart_game/services/lucky_card_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_lucky_card_api.dart';
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

const _jack = LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts);
const _queen = LuckyCard(LuckyCardRank.queen, LuckyCardSuit.hearts);
const _king = LuckyCard(LuckyCardRank.king, LuckyCardSuit.hearts);

void main() {
  group('the names sent to the database', () {
    test('match the live function and parameter names exactly', () {
      expect(LuckyCardRpc.getCurrentRound, 'lucky_card_get_current_round');
      expect(LuckyCardRpc.placeBet, 'lucky_card_place_bet');
      expect(LuckyCardRpc.getMyRoundResult, 'lucky_card_get_my_round_result');
      expect(LuckyCardRpc.getRecentRounds, 'lucky_card_get_recent_rounds');
      expect(LuckyCardRpcParam.roundId, 'p_round_id');
      expect(LuckyCardRpcParam.bets, 'p_bets');
      expect(LuckyCardRpcParam.limit, 'p_limit');
    });
  });

  group('getCurrentRound', () {
    test('asks the right function with no parameters and understands the answer', () async {
      final rec = _Recorder((_, __) async => loadFixture('current_round_betting.json'));
      final api = LuckyCardApiService(rpc: rec.call);
      final round = await api.getCurrentRound();
      expect(rec.calls, [('lucky_card_get_current_round', null)]);
      expect(round, isNotNull);
      expect(round!.isDrawn, isFalse);
      expect(api.lastRoundError, isNull);
    });

    test('a drawn round carries the card and the bonus', () async {
      final api = LuckyCardApiService(rpc: (_, __) async => loadFixture('current_round_drawn.json'));
      final round = await api.getCurrentRound();
      expect(round!.winningCard, const LuckyCard(LuckyCardRank.queen, LuckyCardSuit.clubs));
      expect(round.bonusMultiplier, 3);
    });

    test('no answer at all is reported as offline', () async {
      final api = LuckyCardApiService(rpc: (_, __) async => null);
      expect(await api.getCurrentRound(), isNull);
      expect(api.lastRoundError, LuckyCardError.offline);
    });

    test('each kind of failure is told apart', () async {
      final cases = <Object, LuckyCardError>{
        const PostgrestException(message: 'Unauthenticated', code: 'P0100'): LuckyCardError.unauthenticated,
        const PostgrestException(message: 'JWT expired', code: 'PGRST301'): LuckyCardError.unauthenticated,
        const SocketException('no route to host'): LuckyCardError.offline,
        TimeoutException('too slow'): LuckyCardError.offline,
        StateError('something else'): LuckyCardError.unknown,
      };
      for (final entry in cases.entries) {
        final api = LuckyCardApiService(rpc: (_, __) => Future<dynamic>.error(entry.key));
        expect(await api.getCurrentRound(), isNull, reason: '${entry.key}');
        expect(api.lastRoundError, entry.value, reason: '${entry.key}');
      }
    });

    test('an answer in an unexpected shape is "unknown", never a crash', () async {
      final broken = loadFixtureMap('current_round_betting.json')..remove('round_id');
      final api = LuckyCardApiService(rpc: (_, __) async => broken);
      expect(await api.getCurrentRound(), isNull);
      expect(api.lastRoundError, LuckyCardError.unknown);
    });

    test('the failure reason is cleared by the next success', () async {
      var first = true;
      final api = LuckyCardApiService(rpc: (_, __) async {
        if (first) {
          first = false;
          throw const SocketException('blip');
        }
        return loadFixture('current_round_betting.json');
      });
      expect(await api.getCurrentRound(), isNull);
      expect(api.lastRoundError, LuckyCardError.offline);
      expect(await api.getCurrentRound(), isNotNull);
      expect(api.lastRoundError, isNull);
    });
  });

  group('placeBet', () {
    test('sends the round id and only the cards that hold chips, by their database keys', () async {
      final rec = _Recorder((_, __) async => loadFixture('place_bet_success.json'));
      final api = LuckyCardApiService(rpc: rec.call);
      final result = await api.placeBet(
        roundId: 'round-1',
        bets: {_jack: 100, _queen: 50, _king: 0},
      );
      expect(rec.calls.length, 1);
      expect(rec.calls.single.$1, 'lucky_card_place_bet');
      expect(rec.calls.single.$2, {
        'p_round_id': 'round-1',
        'p_bets': {'j_hearts': 100, 'q_hearts': 50},
      });
      expect(result.success, isTrue);
      expect(result.totalStake, 120);
      expect(result.coinBalance, 67322);
      expect(result.ledgerVersion, 1460);
    });

    test('an empty board, or one holding only zeros, is refused without calling the database', () async {
      final rec = _Recorder((_, __) async => fail('the database must not be called'));
      final api = LuckyCardApiService(rpc: rec.call);
      for (final bets in <Map<LuckyCard, int>>[{}, {_jack: 0, _queen: 0}]) {
        final result = await api.placeBet(roundId: 'r', bets: bets);
        expect(result.success, isFalse);
        expect(result.error, LuckyCardError.emptyBet);
      }
      expect(rec.calls, isEmpty);
    });

    test('no answer is reported as offline', () async {
      final api = LuckyCardApiService(rpc: (_, __) async => null);
      final result = await api.placeBet(roundId: 'r', bets: {_jack: 50});
      expect(result.success, isFalse);
      expect(result.error, LuckyCardError.offline);
    });

    test('a rejected bet comes back as a failure carrying its reason', () async {
      final api = LuckyCardApiService(
        rpc: (_, __) => Future<dynamic>.error(const PostgrestException(message: 'ROUND_CLOSED', code: 'P0121')),
      );
      final result = await api.placeBet(roundId: 'r', bets: {_jack: 50});
      expect(result.success, isFalse);
      expect(result.error, LuckyCardError.roundClosed);
      expect(result.error!.isRetryable, isFalse);
    });
  });

  group('every real database error is understood', () {
    final real = (loadFixture('errors.json') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    const expected = <String, LuckyCardError>{
      'P0100': LuckyCardError.unauthenticated,
      'P0112': LuckyCardError.insufficientCoins,
      'P0113': LuckyCardError.accountBlocked,
      'P0114': LuckyCardError.notAPlayer,
      'P0120': LuckyCardError.roundClosed,
      'P0121': LuckyCardError.roundClosed,
      'P0123': LuckyCardError.belowMin,
      'P0124': LuckyCardError.exceedsMax,
      'P0125': LuckyCardError.emptyBet,
      'P0126': LuckyCardError.badBet,
    };

    test('the captured set covers all ten codes the player functions can raise', () {
      expect(real.map((e) => e['sqlstate']).toSet(), expected.keys.toSet());
    });

    for (final e in real) {
      test('${e['sqlstate']} "${e['message']}" (${e['scenario']})', () async {
        final error = PostgrestException(message: e['message'] as String, code: e['sqlstate'] as String);
        expect(LuckyCardApiService.mapError(error), expected[e['sqlstate']]);
        final api = LuckyCardApiService(rpc: (_, __) => Future<dynamic>.error(error));
        final result = await api.placeBet(roundId: 'r', bets: {_jack: 50});
        expect(result.error, expected[e['sqlstate']]);
        expect(result.success, isFalse);
      });
    }
  });

  group('mapError for failures that are not Lucky Card codes', () {
    test('a token problem is a sign-in problem, not "no internet"', () {
      expect(LuckyCardApiService.mapError(const PostgrestException(message: 'JWT expired')), LuckyCardError.unauthenticated);
      expect(LuckyCardApiService.mapError(const PostgrestException(message: 'x', code: 'PGRST303')), LuckyCardError.unauthenticated);
      expect(LuckyCardApiService.mapError(const AuthException('session gone')), LuckyCardError.unauthenticated);
    });

    test('a dropped connection is offline', () {
      expect(LuckyCardApiService.mapError(AuthRetryableFetchException()), LuckyCardError.offline);
      expect(LuckyCardApiService.mapError(const SocketException('x')), LuckyCardError.offline);
      expect(LuckyCardApiService.mapError(TimeoutException('x')), LuckyCardError.offline);
      expect(LuckyCardApiService.mapError(ClientException()), LuckyCardError.offline);
    });

    test('an unrecognised database error and an unrelated exception are "unknown"', () {
      expect(LuckyCardApiService.mapError(const PostgrestException(message: 'duplicate key', code: '23505')), LuckyCardError.unknown);
      expect(LuckyCardApiService.mapError(StateError('x')), LuckyCardError.unknown);
    });

    test('a Triple Chance code that Lucky Card never raises is not mistaken for a card error', () {
      // P0122 is Triple Chance's bad-key code; Lucky Card's own is P0126.
      expect(LuckyCardApiService.mapError(const PostgrestException(message: 'BAD_SINGLE_KEY:x', code: 'P0122')), LuckyCardError.unknown);
    });
  });

  group('getMyRoundResult', () {
    test('asks for the round and understands a settled win', () async {
      final rec = _Recorder((_, __) async => loadFixture('my_result_settled_win.json'));
      final result = await LuckyCardApiService(rpc: rec.call).getMyRoundResult('round-9');
      expect(rec.calls.single.$1, 'lucky_card_get_my_round_result');
      expect(rec.calls.single.$2, {'p_round_id': 'round-9'});
      expect(result!.isSettled, isTrue);
      expect(result.totalPayout, 300);
    });

    test('"no bet" is an answer; no answer is null', () async {
      final noBet = await LuckyCardApiService(rpc: (_, __) async => loadFixture('my_result_no_bet.json')).getMyRoundResult('r');
      expect(noBet!.placedBet, isFalse);
      expect(await LuckyCardApiService(rpc: (_, __) async => null).getMyRoundResult('r'), isNull);
      expect(await LuckyCardApiService(rpc: (_, __) => Future<dynamic>.error(const SocketException('x'))).getMyRoundResult('r'), isNull);
    });
  });

  group('getRecentRounds', () {
    test('asks for the limit (10 by default) and understands the list', () async {
      final rec = _Recorder((_, __) async => loadFixture('recent_rounds.json'));
      final api = LuckyCardApiService(rpc: rec.call);
      final list = await api.getRecentRounds();
      expect(rec.calls.single.$1, 'lucky_card_get_recent_rounds');
      expect(rec.calls.single.$2, {'p_limit': 10});
      expect(list.length, 3);
      await api.getRecentRounds(limit: 3);
      expect(rec.calls.last.$2, {'p_limit': 3});
    });

    test('an answer that is not a list, a failure, or a bad row all give an empty list', () async {
      expect(await LuckyCardApiService(rpc: (_, __) async => null).getRecentRounds(), isEmpty);
      expect(await LuckyCardApiService(rpc: (_, __) async => {'a': 1}).getRecentRounds(), isEmpty);
      expect(await LuckyCardApiService(rpc: (_, __) => Future<dynamic>.error(const SocketException('x'))).getRecentRounds(), isEmpty);
      final bad = [
        {'round_id': 'x', 'round_number': 1, 'scheduled_at': '2026-10-06T00:00:00+00:00', 'winning_rank': 'A', 'winning_suit': 'hearts', 'bonus_multiplier': 1},
      ];
      expect(await LuckyCardApiService(rpc: (_, __) async => bad).getRecentRounds(), isEmpty);
    });
  });

  group('the fake used by later steps', () {
    test('satisfies the same contract as the real service and records its calls', () async {
      final LuckyCardApi api = FakeLuckyCardApi(
        rounds: [LuckyCardRoundState.fromJson(loadFixtureMap('current_round_betting.json'))],
        betResults: const [LuckyCardPlaceBetResult.failure(LuckyCardError.roundClosed)],
      );
      expect((await api.getCurrentRound())!.isDrawn, isFalse);
      final result = await api.placeBet(roundId: 'r1', bets: {_jack: 50});
      expect(result.error, LuckyCardError.roundClosed);
      expect((api as FakeLuckyCardApi).calls, ['getCurrentRound()', 'placeBet(r1, j_hearts:50)']);
    });
  });
}
