// Tests for lib/services/lucky_card_round_sync.dart.
//
// Whole rounds are played on a fake clock against a simulated server that
// follows the real server's measured rules (see sim_server.dart), so each test
// takes a fraction of a second and nothing depends on the network.
//
// The smart-schedule and clock-move tests (2026-11-09) are ported from
// test/lucky16/lucky16_round_sync_test.dart (103-second round, draw at 89).

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/services/lucky_card_round_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sim_server.dart';

const int cycle = 17390000;

/// Everything one test needs: the fake world, the server, the sync under test,
/// and a record of what the sync told the rest of the app.
class Rig {
  Rig(
    WidgetTester tester, {
    int cycleNumber = cycle,
    double startInto = 0,
    double skew = 0,
    Duration latency = const Duration(milliseconds: 100),
    int resultFromSecond = 89,
    Duration? pollInterval,
  })  : world = SimWorld(tester, cycleNumber: cycleNumber, startInto: startInto, skewSeconds: skew) {
    server = SimulatedLuckyCardServer(
      now: () => world.serverNow,
      latency: latency,
      resultFromSecond: resultFromSecond,
    );
    sync = pollInterval == null
        ? LuckyCardRoundSync(api: server, now: () => world.deviceNow, elapsed: () => world.elapsed)
        : LuckyCardRoundSync(
            api: server,
            now: () => world.deviceNow,
            elapsed: () => world.elapsed,
            pollInterval: pollInterval,
          );
    sync.onLockMark = () {
      lockMarks.add(world.cyclePosition);
      countdownAtLock.add(sync.countdown);
    };
    sync.onResult = (r) {
      results.add(r);
      resultAt.add(world.cyclePosition);
      countdownAtResult.add(sync.countdown);
      secondsIntoAtResult.add(sync.secondsInto);
    };
    sync.onResultUnavailable = () => unavailableAt.add(world.cyclePosition);
    sync.onNewCycle = () => newCycles.add(world.cyclePosition);
  }

  final SimWorld world;
  late final SimulatedLuckyCardServer server;
  late final LuckyCardRoundSync sync;

  final List<double> lockMarks = [];
  final List<int> countdownAtLock = [];
  final List<LuckyCardRoundResult> results = [];
  final List<double> resultAt = [];
  final List<int> countdownAtResult = [];
  final List<int> secondsIntoAtResult = [];
  final List<double> unavailableAt = [];
  final List<double> newCycles = [];

  /// Opens the screen: starts the sync and lets the first answer arrive.
  Future<void> open() async {
    final attached = sync.attach();
    await world.run(const Duration(seconds: 1));
    await attached;
  }

  /// Closes the screen and lets any timer still waiting run out, so the test
  /// ends clean.
  Future<void> finish() async {
    sync.dispose();
    await world.run(const Duration(seconds: 12));
  }
}

void main() {
  group('opening the screen', () {
    testWidgets('connects, corrects its clock, and then asks every 10 seconds while betting', (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      expect(rig.sync.isConnected, isTrue);
      expect(rig.sync.connectionError, isNull);
      expect(rig.sync.currentRound!.roundNumber, cycle);
      expect((rig.sync.countdown - 79).abs(), lessThanOrEqualTo(1));

      final before = rig.server.polls;
      await rig.world.run(const Duration(seconds: 20));
      expect(rig.server.polls - before, inInclusiveRange(1, 3));
      await rig.finish();
    });

    testWidgets('a device clock that is wrong still gives the right countdown', (tester) async {
      for (final skew in [-2.4, 0.3, 2.7, 5.0, -61.0]) {
        final rig = Rig(tester, cycleNumber: cycle + 5, startInto: 20, skew: skew);
        await rig.open();
        await rig.world.run(const Duration(seconds: 5));
        final serverCountdown = 90 - rig.world.cyclePosition.floor();
        expect((rig.sync.countdown - serverCountdown).abs(), lessThanOrEqualTo(1), reason: 'skew $skew s');
        await rig.finish();
      }
    });
  });

  group('the lock mark', () {
    testWidgets('fires once per round, when the countdown reads 5', (tester) async {
      final rig = Rig(tester);
      await rig.open();
      await rig.world.run(const Duration(seconds: 205));
      expect(rig.lockMarks.length, 2, reason: 'one lock mark for each of the two rounds');
      expect(rig.countdownAtLock, [5, 5]);
      for (final p in rig.lockMarks) {
        expect(p % 103, inInclusiveRange(84.0, 86.5), reason: 'cycle position $p');
      }
      await rig.finish();
    });

    testWidgets('still fires when the clock jumps over the mark', (tester) async {
      final rig = Rig(tester, startInto: 70);
      await rig.open();
      await rig.world.runUntil(82.6);
      rig.world.skewSeconds = 2.0; // the device clock suddenly runs 2 seconds ahead
      await rig.world.run(const Duration(seconds: 8));
      expect(rig.lockMarks, isNotEmpty);
      expect(rig.countdownAtLock.every((c) => c <= 5 && c > 0), isTrue);
      await rig.finish();
    });

    testWidgets('does not fire when the screen is opened after the mark', (tester) async {
      final rig = Rig(tester, startInto: 87);
      await rig.open();
      await rig.world.run(const Duration(seconds: 4));
      expect(rig.lockMarks, isEmpty);
      await rig.finish();
    });
  });

  group('the result is held until the countdown reads 00', () {
    testWidgets('delivered once, with the right card and bonus, never before 00, for every clock alignment', (tester) async {
      var knownEarlier = 0;
      var cycleNumber = cycle + 10;
      for (final skew in [0.0, 0.25, 0.5, 0.75, 0.95]) {
        final rig = Rig(tester, cycleNumber: cycleNumber++, startInto: 80, skew: skew);
        await rig.open();
        await rig.world.run(const Duration(seconds: 25));
        final n = rig.world.cycleNumber;

        expect(rig.results.length, 1, reason: 'skew $skew');
        expect(rig.results.single.roundNumber, n);
        expect(rig.results.single.winningCard, SimulatedLuckyCardServer.winnerOf(n));
        expect(rig.results.single.bonusMultiplier, SimulatedLuckyCardServer.bonusOf(n));
        expect(rig.results.single.isCatchUpReplay, isFalse);
        expect(rig.countdownAtResult.single, 0, reason: 'the wheel may only start once the countdown reads 00 (skew $skew)');
        expect(rig.secondsIntoAtResult.single, greaterThanOrEqualTo(90));
        expect(rig.resultAt.single, inInclusiveRange(89.0, 91.6), reason: 'skew $skew');

        // Was the winner already in hand, from a poll, before it was shown?
        final deliveredServerTime = rig.world.serverNow.subtract(
          Duration(milliseconds: ((rig.world.cyclePosition - rig.resultAt.single) * 1000).round()),
        );
        if (rig.server.pollLog.any((p) => p.drawn && p.at.isBefore(deliveredServerTime))) knownEarlier++;
        await rig.finish();
      }
      expect(knownEarlier, greaterThan(0), reason: 'the test must really cover a winner that arrives before 00');
    });

    testWidgets('each round delivers exactly once, in order, across two rounds', (tester) async {
      final rig = Rig(tester);
      await rig.open();
      await rig.world.run(const Duration(seconds: 205));
      expect(rig.results.map((r) => r.roundNumber), [cycle, cycle + 1]);
      expect(rig.results.map((r) => r.winningCard).toList(), [
        SimulatedLuckyCardServer.winnerOf(cycle),
        SimulatedLuckyCardServer.winnerOf(cycle + 1),
      ]);
      expect(rig.countdownAtResult, [0, 0]);
      await rig.finish();
    });

    testWidgets('a slow draw: the result is fetched once the countdown reads 00 and delivered when it exists', (tester) async {
      final rig = Rig(tester, startInto: 80, resultFromSecond: 94);
      await rig.open();
      await rig.world.run(const Duration(seconds: 25));
      expect(rig.results.length, 1);
      expect(rig.resultAt.single, inInclusiveRange(94.0, 96.5));
      expect(rig.unavailableAt, isEmpty);
      await rig.finish();
    });

    testWidgets('a draw that never happens: gives up once after 8 attempts and delivers nothing', (tester) async {
      final rig = Rig(tester, startInto: 80, resultFromSecond: 1000);
      await rig.open();
      await rig.world.run(const Duration(seconds: 30));
      expect(rig.results, isEmpty);
      expect(rig.unavailableAt.length, 1);
      expect(rig.unavailableAt.single, inInclusiveRange(96.0, 99.8));
      await rig.finish();
    });
  });

  group('joining mid-round', () {
    testWidgets('after the countdown reached 00: the finished round is shown once, as a replay', (tester) async {
      final rig = Rig(tester, startInto: 92.3);
      await rig.open();
      await rig.world.run(const Duration(seconds: 8));
      expect(rig.results.length, 1);
      expect(rig.results.single.isCatchUpReplay, isTrue);
      expect(rig.results.single.winningCard, SimulatedLuckyCardServer.winnerOf(cycle));
      await rig.world.run(const Duration(seconds: 10));
      expect(rig.results.length, 1, reason: 'polls must not deliver it again');
      await rig.finish();
    });

    testWidgets('a replay of a round whose result is still being drawn stays marked as a replay', (tester) async {
      // A poll must not get in first and deliver it as a live round.
      final rig = Rig(tester, startInto: 91, resultFromSecond: 95);
      await rig.open();
      await rig.world.run(const Duration(seconds: 10));
      expect(rig.results.length, 1);
      expect(rig.results.single.isCatchUpReplay, isTrue);
      await rig.finish();
    });

    testWidgets('early in the round: nothing is shown until 00, and then it is a live result', (tester) async {
      final rig = Rig(tester, startInto: 50);
      await rig.open();
      await rig.world.runUntil(89.0);
      expect(rig.results, isEmpty);
      await rig.world.run(const Duration(seconds: 6));
      expect(rig.results.length, 1);
      expect(rig.results.single.isCatchUpReplay, isFalse);
      expect(rig.countdownAtResult.single, 0);
      await rig.finish();
    });

    testWidgets('one second before the draw: held until 00, not shown as a replay', (tester) async {
      final rig = Rig(tester, startInto: 88.6);
      await rig.open();
      await rig.world.run(const Duration(seconds: 6));
      expect(rig.results.length, 1);
      expect(rig.results.single.isCatchUpReplay, isFalse);
      expect(rig.countdownAtResult.single, 0);
      await rig.finish();
    });
  });

  group('a new round', () {
    testWidgets('is announced once when the cycle wraps', (tester) async {
      final rig = Rig(tester, startInto: 95);
      await rig.open();
      await rig.world.run(const Duration(seconds: 20));
      expect(rig.newCycles.length, 1);
      expect(rig.newCycles.single % 103, inInclusiveRange(0.0, 2.0));
      await rig.finish();
    });
  });

  group('the connection', () {
    testWidgets('three failed polls in a row mean "disconnected", and one good poll brings it back', (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      expect(rig.sync.isConnected, isTrue);
      rig.server.offline = true;
      await rig.world.run(const Duration(seconds: 3)); // at most one failed poll
      expect(rig.sync.isConnected, isTrue, reason: 'one or two failures are tolerated');
      // The next 10-second poll fails (by second ~21), then two more 2 s apart.
      await rig.world.run(const Duration(seconds: 13));
      expect(rig.sync.isConnected, isFalse);
      expect(rig.sync.connectionError, LuckyCardError.offline);
      rig.server.offline = false;
      await rig.world.run(const Duration(seconds: 3));
      expect(rig.sync.isConnected, isTrue);
      expect(rig.sync.connectionError, isNull);
      await rig.finish();
    });

    testWidgets('two blips in a row never reach the player', (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      rig.server.failNext(2);
      await rig.world.run(const Duration(seconds: 12));
      expect(rig.sync.isConnected, isTrue);
      await rig.finish();
    });

    testWidgets('an expired sign-in is reported as that, not as "no internet"', (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      rig.server.failNext(6, error: LuckyCardError.unauthenticated);
      await rig.world.run(const Duration(seconds: 18));
      expect(rig.sync.isConnected, isFalse);
      expect(rig.sync.connectionError, LuckyCardError.unauthenticated);
      await rig.finish();
    });

    testWidgets('offline at opening: tries three times, reports it, and recovers by itself', (tester) async {
      final rig = Rig(tester, startInto: 10);
      rig.server.offline = true;
      final attached = rig.sync.attach();
      await rig.world.run(const Duration(seconds: 2));
      await attached;
      expect(rig.server.polls, 3, reason: 'three attempts, half a second apart');
      expect(rig.sync.isConnected, isFalse);
      expect(rig.sync.connectionError, LuckyCardError.offline);
      rig.server.offline = false;
      await rig.world.run(const Duration(seconds: 4));
      expect(rig.sync.isConnected, isTrue);
      await rig.finish();
    });
  });

  group('leaving the screen', () {
    testWidgets('detach stops every timer and every event', (tester) async {
      final rig = Rig(tester, startInto: 70);
      await rig.open();
      expect(rig.sync.isWatching, isTrue);
      rig.sync.detach();
      expect(rig.sync.isWatching, isFalse);
      final polls = rig.server.polls;
      await rig.world.run(const Duration(seconds: 40));
      expect(rig.server.polls, polls);
      expect(rig.lockMarks, isEmpty);
      expect(rig.results, isEmpty);
      await rig.finish();
    });

    testWidgets('leaving while the first answer is still on its way starts nothing', (tester) async {
      final rig = Rig(tester, startInto: 70, latency: const Duration(seconds: 3));
      final attached = rig.sync.attach();
      await rig.world.run(const Duration(milliseconds: 500));
      rig.sync.detach();
      await rig.world.run(const Duration(seconds: 5));
      await attached;
      final polls = rig.server.polls;
      await rig.world.run(const Duration(seconds: 30));
      expect(rig.server.polls, polls, reason: 'an abandoned attach must not start polling');
      expect(rig.sync.isWatching, isFalse, reason: 'an abandoned attach must not leave a timer running');
      expect(rig.sync.isConnected, isFalse);
      await rig.finish();
    });

    testWidgets('coming straight back starts fresh and works', (tester) async {
      final rig = Rig(tester, startInto: 70);
      await rig.open();
      rig.sync.detach();
      await rig.open();
      await rig.world.run(const Duration(seconds: 30));
      expect(rig.results.length, 1);
      expect(rig.results.single.isCatchUpReplay, isFalse);
      await rig.finish();
    });

    testWidgets('a result fetch still waiting when the screen is left delivers nothing', (tester) async {
      final rig = Rig(tester, startInto: 80, resultFromSecond: 1000);
      await rig.open();
      await rig.world.runUntil(92.0);
      rig.sync.detach();
      await rig.world.run(const Duration(seconds: 20));
      expect(rig.results, isEmpty);
      expect(rig.unavailableAt, isEmpty, reason: 'a left screen must not report a missing result');
      await rig.finish();
    });
  });

  group('the round a bet is sent to', () {
    testWidgets('the round already known is used while the server will still take bets', (tester) async {
      final rig = Rig(tester, startInto: 40);
      await rig.open();
      final before = rig.server.polls;
      final round = await rig.sync.roundForBet();
      expect(round, isNotNull);
      expect(round!.roundNumber, cycle);
      expect(rig.server.polls, before, reason: 'no extra request');
      await rig.finish();
    });

    testWidgets('a fresh one is fetched when the known round no longer takes bets', (tester) async {
      final rig = Rig(tester, startInto: 40);
      await rig.open();
      await rig.world.runUntil(89.5);
      // The poll may already have refreshed it; either way a drawn round must not be returned as open.
      final before = rig.server.polls;
      final future = rig.sync.roundForBet();
      await rig.world.run(const Duration(milliseconds: 500));
      final round = await future;
      expect(round, isNotNull);
      expect(round!.acceptsBets, isFalse);
      expect(rig.server.polls, greaterThan(before));
      await rig.finish();
    });

    testWidgets('no answer gives null, with the reason', (tester) async {
      final rig = Rig(tester, startInto: 40);
      await rig.open();
      await rig.world.runUntil(89.5);
      rig.server.offline = true;
      final future = rig.sync.roundForBet();
      await rig.world.run(const Duration(milliseconds: 500));
      expect(await future, isNull);
      expect(rig.sync.lastRoundError, LuckyCardError.offline);
      await rig.finish();
    });
  });

  group('how often the server is asked (2026-11-09 load reduction)', () {
    /// Plays three whole 103-second rounds from second 0.5 and returns the
    /// requests per round, checking every round still delivered once, at 00, as
    /// a live result.
    Future<double> requestsPerRound(WidgetTester tester, {Duration? pollInterval, required int cycleNumber}) async {
      final rig = Rig(tester, cycleNumber: cycleNumber, startInto: 0.5, pollInterval: pollInterval);
      await rig.open();
      final before = rig.server.polls;
      await rig.world.run(const Duration(seconds: 309));
      final perRound = (rig.server.polls - before) / 3;
      expect(rig.results.map((r) => r.roundNumber), [cycleNumber, cycleNumber + 1, cycleNumber + 2]);
      expect(rig.countdownAtResult, [0, 0, 0]);
      expect(rig.results.every((r) => !r.isCatchUpReplay), isTrue);
      expect(rig.lockMarks.length, 3);
      expect(rig.unavailableAt, isEmpty);
      await rig.finish();
      return perRound;
    }

    testWidgets('a healthy 103-second round takes about 11 requests instead of about 52', (tester) async {
      final now = await requestsPerRound(tester, cycleNumber: cycle + 40);
      final before = await requestsPerRound(tester, cycleNumber: cycle + 50, pollInterval: const Duration(seconds: 2));
      debugPrint('Lucky Card get_current_round requests per round: before (2 s rhythm) $before, now $now');
      expect(before, inInclusiveRange(50.0, 53.0), reason: 'the old 2-second rhythm, for comparison');
      expect(now, inInclusiveRange(10.0, 14.0));
    });

    testWidgets('a new round is asked for at once, so its id is fresh before the player bets', (tester) async {
      final rig = Rig(tester, startInto: 98);
      await rig.open();
      await rig.world.run(const Duration(milliseconds: 5700)); // to about second 1.7 of the next round
      expect(rig.world.cyclePosition, lessThan(2.5));
      expect(rig.sync.currentRound!.roundNumber, cycle + 1);
      await rig.finish();
    });

    testWidgets('once a poll fails it asks every 2 seconds, and goes back to 10 when it recovers', (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      await rig.world.runUntil(22.0); // the 10-second poll at ~20 has happened
      rig.server.offline = true;
      await rig.world.runUntil(31.0); // the poll at ~30 fails
      final failing = rig.server.polls;
      await rig.world.run(const Duration(seconds: 6));
      expect(rig.server.polls - failing, inInclusiveRange(2, 4), reason: 'every 2 seconds while failing');
      rig.server.offline = false;
      await rig.world.run(const Duration(seconds: 3));
      expect(rig.sync.isConnected, isTrue);
      final healthy = rig.server.polls;
      await rig.world.run(const Duration(seconds: 8));
      expect(rig.server.polls - healthy, lessThanOrEqualTo(1), reason: 'back to every 10 seconds');
      await rig.finish();
    });

    testWidgets('the draw at second 89: the request at the draw second sees the card, it is held, and shown at 00',
        (tester) async {
      final rig = Rig(tester, startInto: 60);
      await rig.open();
      await rig.world.runUntil(95.0);
      double pos(DateTime t) => (t.millisecondsSinceEpoch / 1000 + 0.5) % 103;
      final firstDrawn = rig.server.pollLog.firstWhere((p) => p.drawn);
      expect(pos(firstDrawn.at), inInclusiveRange(88.5, 90.0), reason: 'asked from the draw second (89), from the reply');
      expect(rig.results.length, 1);
      expect(rig.results.single.isCatchUpReplay, isFalse);
      expect(rig.countdownAtResult, [0], reason: 'held until the countdown reads 00');
      expect(rig.resultAt.single, inInclusiveRange(89.5, 91.6));
      final nearDraw = rig.server.pollLog.where((p) => pos(p.at) >= 85.0 && pos(p.at) < 95.0).length;
      expect(nearDraw, lessThanOrEqualTo(2), reason: 'no 00 fetch is needed: the card is already in hand');
      await rig.finish();
    });
  });

  group("the device's clock is moved (2026-11-09 stopwatch schedule)", () {
    /// The countdown the server itself would show right now.
    int serverCountdown(Rig rig) {
      final c = 90 - rig.world.cyclePosition.floor();
      return c < 0 ? 0 : c;
    }

    /// Checks the round played out normally after a clock move: one lock mark at
    /// countdown 5, one live result at 00, nothing given up.
    void expectNormalRoundEnd(Rig rig) {
      expect(rig.lockMarks.length, 1, reason: 'the lock fires once');
      expect(rig.countdownAtLock, [5]);
      expect(rig.lockMarks.single, inInclusiveRange(84.5, 86.0), reason: 'lock at the real countdown 5');
      expect(rig.results.length, 1, reason: 'the result is delivered once');
      expect(rig.results.single.roundNumber, cycle);
      expect(rig.results.single.isCatchUpReplay, isFalse);
      expect(rig.countdownAtResult, [0]);
      expect(rig.unavailableAt, isEmpty);
    }

    testWidgets('moved back 30 seconds while betting: asked at once, countdown right again, lock and result as normal',
        (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      await rig.world.runUntil(40.0);
      final before = rig.server.polls;
      rig.world.skewSeconds = -30;
      await rig.world.run(const Duration(milliseconds: 1500));
      expect(rig.server.polls, greaterThan(before), reason: 'the move is noticed within 1.5 s, not paused');
      await rig.world.run(const Duration(milliseconds: 500));
      expect((rig.sync.countdown - serverCountdown(rig)).abs(), lessThanOrEqualTo(1));
      await rig.world.runUntil(95.0);
      expectNormalRoundEnd(rig);
      await rig.finish();
    });

    testWidgets('moved forward 30 seconds while betting: asked at once, no early lock', (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      await rig.world.runUntil(40.0);
      final before = rig.server.polls;
      rig.world.skewSeconds = 30;
      await rig.world.run(const Duration(milliseconds: 1500));
      expect(rig.server.polls, greaterThan(before), reason: 'the move is noticed within 1.5 s');
      await rig.world.run(const Duration(milliseconds: 500));
      expect((rig.sync.countdown - serverCountdown(rig)).abs(), lessThanOrEqualTo(1));
      await rig.world.runUntil(95.0);
      expectNormalRoundEnd(rig);
      await rig.finish();
    });

    testWidgets('moved back 30 seconds while the result is awaited: still delivered once, live', (tester) async {
      final rig = Rig(tester, startInto: 80, resultFromSecond: 95);
      await rig.open();
      await rig.world.runUntil(92.0);
      expect(rig.results, isEmpty, reason: 'the draw is slow: nothing yet at second 92');
      rig.world.skewSeconds = -30;
      await rig.world.runUntil(99.0);
      expect(rig.results.length, 1);
      expect(rig.results.single.roundNumber, cycle);
      expect(rig.results.single.isCatchUpReplay, isFalse);
      expect(rig.resultAt.single, inInclusiveRange(95.0, 97.0), reason: 'as soon as the draw exists');
      expect(rig.countdownAtResult, [0]);
      expect(rig.unavailableAt, isEmpty);
      await rig.finish();
    });

    testWidgets('a small move (0.8 s, like a network time correction) adds no request', (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      final before = rig.server.polls;
      rig.world.skewSeconds = 0.8;
      await rig.world.run(const Duration(seconds: 20));
      expect(rig.server.polls - before, inInclusiveRange(1, 3), reason: 'still the 10-second rhythm');
      await rig.finish();
    });

    testWidgets('the phone slept 8 seconds (stopwatch stood still): asked at the next check after waking',
        (tester) async {
      final rig = Rig(tester, startInto: 20);
      await rig.open();
      await rig.world.runUntil(30.0);
      final before = rig.server.polls;
      rig.world.sleepPhone(const Duration(seconds: 8));
      await rig.world.run(const Duration(milliseconds: 600));
      expect(rig.server.polls, greaterThan(before), reason: 'the wake-up is noticed at the next 0.5 s check');
      expect((rig.sync.countdown - serverCountdown(rig)).abs(), lessThanOrEqualTo(1));
      final afterWake = rig.server.polls;
      await rig.world.run(const Duration(seconds: 9));
      expect(rig.server.polls - afterWake, lessThanOrEqualTo(1), reason: 'back to the 10-second rhythm');
      expect(rig.lockMarks, isEmpty);
      await rig.finish();
    });

    testWidgets('one move back does not cause a request storm: still about 11 requests per round', (tester) async {
      const n = cycle + 60;
      final rig = Rig(tester, cycleNumber: n, startInto: 0.5);
      await rig.open();
      final before = rig.server.polls;
      await rig.world.run(const Duration(seconds: 40));
      rig.world.skewSeconds = -30;
      await rig.world.run(const Duration(seconds: 269));
      final perRound = (rig.server.polls - before) / 3;
      debugPrint('Lucky Card requests per round with one 30 s clock move back: $perRound');
      expect(perRound, inInclusiveRange(10.0, 14.0));
      expect(rig.results.map((r) => r.roundNumber), [n, n + 1, n + 2]);
      expect(rig.countdownAtResult, [0, 0, 0]);
      expect(rig.unavailableAt, isEmpty);
      await rig.finish();
    });

    for (final dropAfter in [0.0, 2.0, 4.0, 6.0, 8.0, 9.5]) {
      testWidgets('network lost ${dropAfter}s after a request: "disconnected" within 4-14.5 s, recovers within 2.5 s',
          (tester) async {
        final rig = Rig(tester, startInto: 10);
        await rig.open();
        await rig.world.runUntil(15.0);
        final n = rig.server.polls;
        var guard = 0;
        while (rig.server.polls == n && ++guard < 400) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await rig.world.run(const Duration(milliseconds: 150)); // its answer is in
        final dropAt = rig.server.pollLog.last.at.add(Duration(milliseconds: 150 + (dropAfter * 1000).round()));
        while (rig.world.serverNow.isBefore(dropAt)) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(rig.sync.isConnected, isTrue);
        rig.server.offline = true;
        final droppedAt = rig.world.serverNow;
        guard = 0;
        while (rig.sync.isConnected && ++guard < 400) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final lag = rig.world.serverNow.difference(droppedAt).inMilliseconds / 1000;
        expect(rig.sync.isConnected, isFalse);
        expect(lag, inInclusiveRange(4.0, 14.5), reason: 'popup delay after the drop');
        rig.server.offline = false;
        final backAt = rig.world.serverNow;
        guard = 0;
        while (!rig.sync.isConnected && ++guard < 200) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(rig.sync.isConnected, isTrue);
        expect(rig.world.serverNow.difference(backAt).inMilliseconds / 1000, lessThanOrEqualTo(2.5));
        await rig.finish();
      });
    }

    testWidgets('network lost right after a clock move: the 2-second failing rhythm holds, one popup',
        (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      await rig.world.runUntil(40.0);
      var popups = 0;
      var wasConnected = rig.sync.isConnected;
      rig.sync.addListener(() {
        if (wasConnected && !rig.sync.isConnected) popups++;
        wasConnected = rig.sync.isConnected;
      });
      final movedAt = rig.world.serverNow;
      final before = rig.server.polls;
      rig.world.skewSeconds = -30;
      rig.server.offline = true;
      await rig.world.run(const Duration(seconds: 12));
      expect(rig.sync.isConnected, isFalse);
      expect(popups, 1);
      final times = rig.server.pollLog.skip(before).map((p) => p.at).toList();
      expect(times.first.difference(movedAt).inMilliseconds, lessThanOrEqualTo(600),
          reason: 'the move is noticed at once');
      for (var i = 1; i < times.length; i++) {
        final gap = times[i].difference(times[i - 1]).inMilliseconds / 1000;
        expect(gap, inInclusiveRange(1.5, 2.5), reason: 'request ${i + 1} after the move');
      }
      await rig.finish();
    });

    testWidgets('the default stopwatch (no elapsed passed) builds, attaches and detaches', (tester) async {
      final world = SimWorld(tester, cycleNumber: cycle, startInto: 10);
      final server = SimulatedLuckyCardServer(now: () => world.serverNow, latency: const Duration(milliseconds: 100));
      final sync = LuckyCardRoundSync(api: server, now: () => world.deviceNow);
      final attached = sync.attach();
      await world.run(const Duration(seconds: 1));
      await attached;
      expect(sync.isConnected, isTrue);
      expect(sync.isWatching, isTrue);
      sync.detach();
      expect(sync.isWatching, isFalse);
      sync.dispose();
      await world.run(const Duration(seconds: 12));
    });
  });
}
