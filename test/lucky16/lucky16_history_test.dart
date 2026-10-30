// Unit tests for the Lucky 16 Card history: the row model, the database read service and
// the provider (lib/models/lucky16_history_model.dart,
// lib/services/lucky16_history_service.dart, lib/providers/lucky16_history_provider.dart).
//
// Copied from test/lucky_card/lucky_card_history_test.dart and changed for 16 cards,
// the A rank and 14x. The rows (test/lucky16/fixtures/history_rows.json) are ADAPTED
// from Lucky Card's live capture of 2026-10-22 (see fixtures/README.md): a 5X win of
// 10,000 on every one of the 16 cards (160,000 staked, 10,000 x 14 x 5 = 700,000 paid)
// and a no-bonus loss on an A hearts round.
// The real Supabase query line itself (the one thing handed in as a fake here) is
// the same shape as Triple Chance's history query and is proven in the manual test.

import 'dart:async';

import 'package:best_smart_game/models/lucky16_history_model.dart';
import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/providers/lucky16_history_provider.dart';
import 'package:best_smart_game/services/lucky16_api_contract.dart';
import 'package:best_smart_game/services/lucky16_history_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

Map<String, dynamic> _fixtureRow(int i) =>
    Map<String, dynamic>.from((loadFixture('history_rows.json') as List)[i] as Map);

/// A row with chosen numbers, shaped like the live answer.
Map<String, dynamic> _row({
  int round = 100,
  int stake = 50,
  int payout = 0,
  String rank = 'J',
  String suit = 'hearts',
  int bonus = 1,
  String at = '2026-10-22T10:00:00+00:00',
}) =>
    {
      'round_id': 'id-$round',
      'total_stake': stake,
      'total_payout': payout,
      'created_at': at,
      'lucky16_rounds': {
        'round_number': round,
        'winning_rank': rank,
        'winning_suit': suit,
        'bonus_multiplier': bonus,
      },
    };

/// A provider over a scripted query; every call is recorded as "since|limit".
({Lucky16HistoryProvider provider, List<String> calls}) _provider(
  Future<List<dynamic>> Function(DateTime? since, int limit) answer,
) {
  final calls = <String>[];
  final service = Lucky16HistoryService(query: (since, limit) {
    calls.add('${since?.toUtc().toIso8601String()}|$limit');
    return answer(since, limit);
  });
  return (provider: Lucky16HistoryProvider(service: service), calls: calls);
}

final DateTime _since = DateTime.utc(2026, 10, 22, 9);

void main() {
  group('the names used to read the history', () {
    test('match the live database', () {
      expect(Lucky16Table.bets, 'lucky16_bets');
      expect(Lucky16Table.rounds, 'lucky16_rounds');
      expect(Lucky16Field.createdAt, 'created_at');
      expect(
        kLucky16HistorySelect,
        'round_id, total_stake, total_payout, created_at, '
        'lucky16_rounds!inner ( round_number, winning_rank, winning_suit, bonus_multiplier )',
      );
    });
  });

  group('one history line, from the adapted rows', () {
    test('a win: the round number, winning card, bonus, stake and payout', () {
      final e = Lucky16HistoryEntry.fromRow(_fixtureRow(0));
      expect(e.roundId, '2609dff7-972e-47ac-bb33-33f41b62ce84');
      expect(e.roundNumber, 17403940);
      expect(e.winningCard, const Lucky16Card(Lucky16Rank.queen, Lucky16Suit.spades));
      expect(e.bonusMultiplier, 5);
      expect(e.stake, 160000);
      expect(e.payout, 700000);
      expect(e.won, isTrue);
      expect(e.placedAt.toUtc(), DateTime.utc(2026, 10, 21, 18, 5, 4, 680, 622));
    });

    test('a loss: payout 0 is not a win, and bonus 1 is the N round', () {
      final e = Lucky16HistoryEntry.fromRow(_fixtureRow(1));
      expect(e.roundNumber, 17400328);
      expect(e.winningCard, const Lucky16Card(Lucky16Rank.ace, Lucky16Suit.hearts));
      expect(e.stake, 300);
      expect(e.payout, 0);
      expect(e.won, isFalse);
      expect(lucky16BonusLabel(e.bonusMultiplier), 'N');
    });

    test('anything paid, even 1 coin, is a win; nothing paid is not', () {
      expect(Lucky16HistoryEntry.fromRow(_row(payout: 1)).won, isTrue);
      expect(Lucky16HistoryEntry.fromRow(_row(payout: 0)).won, isFalse);
    });

    test('a number that arrives as a decimal (7.0) still reads as a whole number', () {
      final row = _row();
      row['total_stake'] = 50.0;
      expect(Lucky16HistoryEntry.fromRow(row).stake, 50);
    });

    test('a row without its round, or with the round in the wrong shape, is refused', () {
      final none = _row()..remove('lucky16_rounds');
      expect(() => Lucky16HistoryEntry.fromRow(none), throwsFormatException);
      final nullRound = _row()..['lucky16_rounds'] = null;
      expect(() => Lucky16HistoryEntry.fromRow(nullRound), throwsFormatException);
      final listRound = _row()..['lucky16_rounds'] = [<String, dynamic>{}];
      expect(() => Lucky16HistoryEntry.fromRow(listRound), throwsFormatException);
    });

    test('a changed card word, or a round with no result, is refused, never guessed', () {
      expect(() => Lucky16HistoryEntry.fromRow(_row(suit: 'stars')), throwsFormatException);
      expect(() => Lucky16HistoryEntry.fromRow(_row(rank: 'X')), throwsFormatException);
      // The Ace is a real Lucky 16 Card rank, not a changed word.
      expect(Lucky16HistoryEntry.fromRow(_row(rank: 'A')).winningCard.rank, Lucky16Rank.ace);
      final undrawn = _row();
      undrawn['lucky16_rounds'] = <String, dynamic>{
        'round_number': 100,
        'winning_rank': null,
        'winning_suit': null,
        'bonus_multiplier': 1,
      };
      expect(() => Lucky16HistoryEntry.fromRow(undrawn), throwsA(isA<TypeError>()));
    });
  });

  group('the read service', () {
    test('with no login time nothing is read and the list is empty', () async {
      var asked = 0;
      final service = Lucky16HistoryService(query: (_, __) async {
        asked++;
        return [_row()];
      });
      expect(await service.loadSession(since: null), isEmpty);
      expect(asked, 0);
    });

    test('asks for everything since login, with the safety ceiling', () async {
      DateTime? gotSince;
      int? gotLimit;
      final service = Lucky16HistoryService(query: (since, limit) async {
        gotSince = since;
        gotLimit = limit;
        return const [];
      });
      await service.loadSession(since: _since);
      expect(gotSince, _since);
      expect(gotLimit, 10000);
      expect(Lucky16HistoryService.maxRows, 10000);
    });

    test('keeps the order the database sent (newest first)', () async {
      final service = Lucky16HistoryService(
        query: (_, __) async => [_row(round: 30), _row(round: 20), _row(round: 10)],
      );
      final list = await service.loadSession(since: _since);
      expect(list.map((e) => e.roundNumber), [30, 20, 10]);
    });

    test('one row that cannot be understood fails the whole read, not just that row', () async {
      final service = Lucky16HistoryService(
        query: (_, __) async => [_row(round: 2), _row(round: 1, suit: 'stars')],
      );
      await expectLater(service.loadSession(since: _since), throwsFormatException);
    });

    test('a failed read is thrown, not turned into an empty list', () async {
      final service = Lucky16HistoryService(query: (_, __) async => throw StateError('offline'));
      await expectLater(service.loadSession(since: _since), throwsStateError);
    });
  });

  group('the provider', () {
    test('starts empty, not loading, with no error', () {
      final p = _provider((_, __) async => const []).provider;
      expect(p.records, isEmpty);
      expect(p.totalStake, 0);
      expect(p.totalPayout, 0);
      expect(p.isLoading, isFalse);
      expect(p.error, isNull);
    });

    test('loads the rows, and the footer totals are the sum of exactly those rows', () async {
      final p = _provider((_, __) async => [
            _row(round: 3, stake: 100, payout: 2500, bonus: 5),
            _row(round: 2, stake: 50, payout: 0),
            _row(round: 1, stake: 5, payout: 0),
          ]).provider;
      await p.loadSession(since: _since);
      expect(p.records.map((r) => r.roundNumber), [3, 2, 1]);
      expect(p.totalStake, 155);
      expect(p.totalPayout, 2500);
      expect(p.error, isNull);
      expect(p.isLoading, isFalse);
    });

    test('the real fixture rows give the right totals', () async {
      final p = _provider((_, __) async => [_fixtureRow(0), _fixtureRow(1)]).provider;
      await p.loadSession(since: _since);
      expect(p.totalStake, 160300);
      expect(p.totalPayout, 700000);
    });

    test('passes the login time through, and reads again on every open', () async {
      final r = _provider((_, __) async => [_row()]);
      await r.provider.loadSession(since: _since);
      await r.provider.loadSession(since: _since);
      expect(r.calls, ['2026-10-22T09:00:00.000Z|10000', '2026-10-22T09:00:00.000Z|10000']);
    });

    test('a read replaces the list with what the database now holds', () async {
      var round = 1;
      final p = _provider((_, __) async => [for (var i = round; i >= 1; i--) _row(round: i)]).provider;
      await p.loadSession(since: _since);
      expect(p.records.length, 1);
      round = 3;
      await p.loadSession(since: _since);
      expect(p.records.length, 3);
    });

    test('tells its listeners that loading started and that it ended', () async {
      final p = _provider((_, __) async => [_row()]).provider;
      final seen = <bool>[];
      p.addListener(() => seen.add(p.isLoading));
      await p.loadSession(since: _since);
      expect(seen, [true, false]);
    });

    test('with no login time the list is empty, with no error and no database read', () async {
      final r = _provider((_, __) async => [_row()]);
      await r.provider.loadSession(since: null);
      expect(r.provider.records, isEmpty);
      expect(r.provider.error, isNull);
      expect(r.calls, isEmpty);
    });

    test('a failed read sets the retry text and keeps what was shown before', () async {
      var fail = false;
      final p = _provider((_, __) async {
        if (fail) throw StateError('offline');
        return [_row(round: 7, stake: 40, payout: 400)];
      }).provider;
      await p.loadSession(since: _since);
      fail = true;
      await p.loadSession(since: _since);
      expect(p.error, 'Could not load history. Tap to retry.');
      expect(p.isLoading, isFalse);
      expect(p.records.single.roundNumber, 7);
      expect(p.totalStake, 40);
      expect(p.totalPayout, 400);
    });

    test('a failed first read leaves an honest error, not an empty "no rounds yet"', () async {
      final p = _provider((_, __) async => throw StateError('offline')).provider;
      await p.loadSession(since: _since);
      expect(p.error, Lucky16HistoryProvider.loadErrorText);
      expect(p.records, isEmpty);
    });

    test('a retry after a failure works and clears the error', () async {
      var fail = true;
      final p = _provider((_, __) async {
        if (fail) throw StateError('offline');
        return [_row()];
      }).provider;
      await p.loadSession(since: _since);
      expect(p.error, isNotNull);
      fail = false;
      await p.loadSession(since: _since);
      expect(p.error, isNull);
      expect(p.records.length, 1);
    });

    test('a second open while a read is still running does not start another', () async {
      final gate = Completer<List<dynamic>>();
      final r = _provider((_, __) => gate.future);
      final first = r.provider.loadSession(since: _since);
      expect(r.provider.isLoading, isTrue);
      await r.provider.loadSession(since: _since);
      expect(r.calls.length, 1);
      gate.complete([_row()]);
      await first;
      expect(r.provider.records.length, 1);
      expect(r.provider.isLoading, isFalse);
    });

    test('the list it hands out cannot be changed from outside', () async {
      final p = _provider((_, __) async => [_row()]).provider;
      await p.loadSession(since: _since);
      expect(() => p.records.add(p.records.first), throwsUnsupportedError);
    });

    test('closing the screen while the read is on its way is safe', () async {
      final gate = Completer<List<dynamic>>();
      final r = _provider((_, __) => gate.future);
      var notified = 0;
      r.provider.addListener(() => notified++);
      final pending = r.provider.loadSession(since: _since);
      final before = notified;
      r.provider.dispose();
      gate.complete([_row()]);
      await pending;
      expect(notified, before);
    });

    test('a disposed provider ignores a new open', () async {
      final r = _provider((_, __) async => [_row()]);
      r.provider.dispose();
      await r.provider.loadSession(since: _since);
      expect(r.calls, isEmpty);
    });
  });
}
