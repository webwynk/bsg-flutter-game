// Tests for Triple Chance's round sync (lib/services/round_sync_service.dart) and the countdown
// it feeds (GameProvider), on a fake clock against a simulated server that follows the live
// rules (sim_tc_server.dart). Plan: docs/loadtest/SMART_CHECK_TRIPLE_CHANCE_PLAN_2026-11-08.md.
//
// Step 1 (2026-11-09) wrote them to record the behaviour BEFORE the smart round check: 52.3
// requests per round on the old 2-second poll, "disconnected" 5.2 s after a drop, and bug B-4
// (a result fetch that kept asking and delivering after the screen was left). Step 2 changed
// only those three on purpose: the request counts, the disconnect timing and B-4. Everything
// else (countdown, lock and bet at 5, result at 00, replay, round id for the bet) is checked
// unchanged. The "the device's clock is moved" group is ported from the other three games.
//
// The screen's two hooks are reproduced as game_screen.dart wires them: the "NO MORE PLAY"
// mark sends the bet through RoundSyncService.submitBets, and the countdown reaching 00 asks
// for the result through fetchAndDeliverResult unless the result is already in hand. The
// result itself is recorded instead of animated (ProbeGame.onGlobalResult), so no wheel,
// sound or get_my_round_result runs.

import 'dart:async';

// Reached through audioplayers, which the app depends on.
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:best_smart_game/models/spin_result_model.dart';
import 'package:best_smart_game/providers/auth_provider.dart';
import 'package:best_smart_game/providers/game_provider.dart';
import 'package:best_smart_game/services/api_contract.dart';
import 'package:best_smart_game/services/round_sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
// Reached through supabase_flutter: GameProvider's constructor asks the (absent) server for
// play limits, so the client must exist. Nothing here reaches a real server.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sim_tc_server.dart';

const int cycle = 17419200;

class _SilentAudio implements AudioplayersPlatformInterface {
  @override
  Stream<AudioEvent> getEventStream(String playerId) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _SilentGlobalAudio implements GlobalAudioplayersPlatformInterface {
  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// The real GameProvider (countdown, lock mark, bet status), with the result recorded
/// instead of animated.
class ProbeGame extends GameProvider {
  ProbeGame(this.world);

  final SimWorld world;
  final List<SpinResult> results = [];
  final List<double> resultAt = [];
  final List<int> countdownAtResult = [];
  final List<bool> resultFromZeroFetch = [];
  bool inZeroFetch = false;
  int catchUpReplays = 0;

  @override
  Future<void> loadGlobalHistory() async {}

  @override
  void markPendingCatchUpReplay() {
    catchUpReplays++;
    super.markPendingCatchUpReplay();
  }

  @override
  Future<void> onGlobalResult(SpinResult serverResult, AuthProvider auth) async {
    results.add(serverResult);
    resultAt.add(world.cyclePosition);
    countdownAtResult.add(countdown);
    resultFromZeroFetch.add(inZeroFetch);
  }

  bool hasResultFor(int roundNumber) => results.any((r) => r.id == 'round-$roundNumber');
}

/// Everything one test needs, wired the way game_screen.dart wires it.
class Rig {
  Rig(
    WidgetTester tester, {
    int cycleNumber = cycle,
    double startInto = 0,
    double skew = 0,
    int resultFromSecond = 90,
    this.bets = true,
  }) : world = SimWorld(tester, cycleNumber: cycleNumber, startInto: startInto, skewSeconds: skew) {
    server = SimulatedTcServer(now: () => world.serverNow, resultFromSecond: resultFromSecond);
    sync.configureForTest(api: server, now: () => world.deviceNow, elapsed: () => world.elapsed);
    game = ProbeGame(world);
    auth = AuthProvider();
    game.setAutoSpinCallback(_onZero, noBetsCallback: _onNoMorePlay);
  }

  final SimWorld world;
  late final SimulatedTcServer server;
  final RoundSyncService sync = RoundSyncService();
  late final ProbeGame game;
  late final AuthProvider auth;

  /// Whether the player bets each round (10 on single 7 and 10 on double 47).
  final bool bets;

  final List<double> lockAt = [];
  final List<int> countdownAtLock = [];
  final List<int> requestsBeforeBet = [];
  final List<int> requestsAfterBet = [];
  final List<bool> betAccepted = [];
  final List<double> zeroAt = [];
  final List<bool?> zeroFetchDelivered = [];

  /// The "NO MORE PLAY" mark, as game_screen.dart's _handleEarlyBetSubmission sends the bet.
  Future<void> _onNoMorePlay() async {
    lockAt.add(world.cyclePosition);
    countdownAtLock.add(game.countdown);
    if (!bets) return;
    requestsBeforeBet.add(server.polls);
    final accepted = await sync.submitBets(
      singleBets: {'7': 10},
      doubleBets: {'47': 10},
      tripleBets: const {},
      auth: auth,
      game: game,
    );
    requestsAfterBet.add(server.polls);
    betAccepted.add(accepted);
  }

  /// The countdown reached 00, as game_screen.dart's _handleSpin asks for the result (it
  /// returns early when the result is already showing).
  Future<void> _onZero() async {
    zeroAt.add(world.cyclePosition);
    final number = sync.syncedNowSecs ~/ 103;
    if (game.hasResultFor(number)) {
      zeroFetchDelivered.add(null); // already in hand from a poll: no fetch
      return;
    }
    game.inZeroFetch = true;
    final delivered = await sync.fetchAndDeliverResult(game, auth);
    game.inZeroFetch = false;
    zeroFetchDelivered.add(delivered);
  }

  Future<void> open() async {
    final attached = sync.attach(game, auth);
    await world.run(const Duration(seconds: 1));
    await attached;
  }

  /// Leaves the screen and lets every timer still waiting run out.
  Future<void> finish() async {
    sync.detach();
    game.dispose();
    await world.run(const Duration(seconds: 12));
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AudioplayersPlatformInterface.instance = _SilentAudio();
    GlobalAudioplayersPlatformInterface.instance = _SilentGlobalAudio();
    await Supabase.initialize(
      url: 'http://localhost:54321',
      // ignore: deprecated_member_use
      anonKey: 'test-key-not-real',
    );
  });

  group('opening the screen', () {
    testWidgets('connects, and the countdown follows the server', (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      expect(rig.sync.isConnected, isTrue);
      expect(rig.sync.currentRound!.roundNumber, cycle);
      expect((rig.game.countdown - 79).abs(), lessThanOrEqualTo(1));
      await rig.world.run(const Duration(seconds: 5));
      final serverCountdown = 90 - rig.world.cyclePosition.floor();
      expect((rig.game.countdown - serverCountdown).abs(), lessThanOrEqualTo(1));
      await rig.finish();
    });

    testWidgets('a device clock that is wrong still gives the right countdown', (tester) async {
      for (final skew in [-2.4, 0.3, 2.7, -61.0]) {
        final rig = Rig(tester, cycleNumber: cycle + 5, startInto: 20, skew: skew);
        await rig.open();
        await rig.world.run(const Duration(seconds: 5));
        final serverCountdown = 90 - rig.world.cyclePosition.floor();
        expect((rig.game.countdown - serverCountdown).abs(), lessThanOrEqualTo(1), reason: 'skew $skew s');
        await rig.finish();
      }
    });
  });

  group('how often the server is asked (smart check, 2026-11-09)', () {
    testWidgets('every 10 seconds while betting (was every 2 seconds)', (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      final before = rig.server.polls;
      await rig.world.run(const Duration(seconds: 20));
      expect(rig.server.polls - before, inInclusiveRange(1, 3));
      await rig.finish();
    });

    testWidgets('a whole 103-second round takes about 12 requests (was 52.3)', (tester) async {
      const n = cycle + 40;
      final rig = Rig(tester, cycleNumber: n, startInto: 0.5);
      await rig.open();
      final before = rig.server.polls;
      await rig.world.run(const Duration(seconds: 309));
      final perRound = (rig.server.polls - before) / 3;
      debugPrint('Triple Chance get_current_round requests per round AFTER: $perRound (before: 52.3)');
      expect(perRound, inInclusiveRange(10.0, 14.0));
      expect(rig.game.results.map((r) => r.id), ['round-$n', 'round-${n + 1}', 'round-${n + 2}']);
      expect(rig.lockAt.length, 3);
      expect(rig.betAccepted, [true, true, true]);
      await rig.finish();
    });

    testWidgets('a new round is asked for at once, so its id is fresh before the player bets', (tester) async {
      final rig = Rig(tester, startInto: 98);
      await rig.open();
      await rig.world.run(const Duration(milliseconds: 5700)); // to about second 1.7 of the next round
      expect(rig.world.cyclePosition, lessThan(2.5));
      expect(rig.sync.currentRound!.roundNumber, cycle + 1);
      await rig.finish();
    });

    testWidgets('from second 90: every 2 seconds until the result is in hand, then quiet', (tester) async {
      final rig = Rig(tester, startInto: 80, resultFromSecond: 95);
      await rig.open();
      await rig.world.runUntil(102.0);
      double pos(DateTime t) => SimulatedTcServer.positionOf(t);
      expect(rig.game.results.length, 1);
      final deliveredAt = rig.game.resultAt.single;
      expect(deliveredAt, inInclusiveRange(95.0, 97.2));
      final afterDelivery = rig.server.pollLog.where((p) => pos(p.at) > deliveredAt + 0.3 && pos(p.at) < 102.0).length;
      expect(afterDelivery, lessThanOrEqualTo(1), reason: 'quiet once the result is in hand');
      await rig.finish();
    });

    testWidgets('once a request fails it asks every 2 seconds, and back to 10 when it recovers', (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      await rig.world.runUntil(22.0);
      rig.server.offline = true;
      await rig.world.runUntil(31.0);
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
  });

  group('the lock and the bet at 5', () {
    testWidgets('"NO MORE PLAY" once per round at countdown 5; the bet reaches the server before 88, '
        'for this round, with no extra request', (tester) async {
      final rig = Rig(tester, startInto: 40);
      await rig.open();
      await rig.world.runUntil(89.0);
      expect(rig.lockAt.length, 1);
      expect(rig.countdownAtLock, [5]);
      expect(rig.lockAt.single, inInclusiveRange(84.5, 86.0));
      expect(rig.betAccepted, [true]);
      final bet = rig.server.betLog.single;
      expect(bet.roundId, 'round-$cycle');
      expect(SimulatedTcServer.positionOf(bet.arrived), lessThan(88.0));
      expect(rig.requestsAfterBet.single - rig.requestsBeforeBet.single, 0,
          reason: 'the bet reuses the round already read');
      await rig.finish();
    });

    testWidgets('Print uses the round already known while betting is open, with no request', (tester) async {
      final rig = Rig(tester, startInto: 40);
      await rig.open();
      await rig.world.runUntil(83.2);
      final before = rig.server.polls;
      final round = rig.sync.roundForPrint();
      expect(round, isNotNull);
      expect(round!.roundId, 'round-$cycle');
      expect(rig.server.polls, before);
      // The phone's synced clock can read up to a second behind the server's
      // rounded clock (the known 0.5 s rounding), so check past second 91.
      await rig.world.runUntil(91.5);
      expect(rig.sync.roundForPrint(), isNull, reason: 'betting closed at the draw second');
      await rig.finish();
    });

    testWidgets("an earlier round's id is never used for the bet or Print", (tester) async {
      final rig = Rig(tester, startInto: 95, bets: false);
      await rig.open();
      rig.server.offline = true; // the new round can not be read
      await rig.world.runUntil(103.0); // wraps into the next round
      await rig.world.run(const Duration(seconds: 3));
      expect(rig.sync.currentRound!.roundNumber, cycle, reason: 'only the old round is known');
      expect(rig.sync.roundForPrint(), isNull);
      await rig.finish();
    });
  });

  group('the result', () {
    testWidgets('shown once per round, at the draw (second 90-91.6), across two rounds', (tester) async {
      final rig = Rig(tester);
      await rig.open();
      await rig.world.run(const Duration(seconds: 205));
      expect(rig.game.results.map((r) => r.id), ['round-$cycle', 'round-${cycle + 1}']);
      final d = SimulatedTcServer.digitsOf(cycle);
      expect([rig.game.results.first.red, rig.game.results.first.green, rig.game.results.first.black],
          [d.red, d.green, d.black]);
      for (final at in rig.game.resultAt) {
        expect(at, inInclusiveRange(90.0, 91.6));
      }
      debugPrint('Result delivered by the 00 fetch: ${rig.game.resultFromZeroFetch} '
          '(false = by the schedule), countdown at result: ${rig.game.countdownAtResult}');
      expect(rig.game.countdownAtResult, [0, 0]);
      await rig.finish();
    });

    testWidgets('shown at 00 with the device clock behind the server (no hold; the 00 fetch asks first)',
        (tester) async {
      final countdowns = <int>[];
      var n = cycle + 10;
      for (final skew in [0.0, -0.3, -0.6, -0.9]) {
        final rig = Rig(tester, cycleNumber: n++, startInto: 80, skew: skew);
        await rig.open();
        await rig.world.runUntil(95.0);
        expect(rig.game.results.length, 1, reason: 'skew $skew');
        expect(rig.game.resultAt.single, inInclusiveRange(90.0, 92.0), reason: 'skew $skew');
        countdowns.add(rig.game.countdownAtResult.single);
        await rig.finish();
      }
      debugPrint('Countdown on screen when the result arrived, device clock 0 / -0.3 / -0.6 / -0.9 s: '
          '$countdowns (1 = shown before the screen read 00)');
      expect(countdowns, [0, 0, 0, 0], reason: 'never before the screen reads 00 (as measured before the change)');
    });

    testWidgets('a slow draw: shown as soon as the digits exist', (tester) async {
      final rig = Rig(tester, startInto: 80, resultFromSecond: 95);
      await rig.open();
      await rig.world.runUntil(100.0);
      expect(rig.game.results.length, 1);
      expect(rig.game.resultAt.single, inInclusiveRange(95.0, 97.2));
      await rig.finish();
    });

    testWidgets('a draw that never happens: the 00 fetch gives up after 8 tries', (tester) async {
      final rig = Rig(tester, startInto: 80, resultFromSecond: 1000);
      await rig.open();
      await rig.world.runUntil(101.0);
      expect(rig.game.results, isEmpty);
      expect(rig.zeroFetchDelivered, [false]);
      await rig.finish();
    });
  });

  group('joining late', () {
    testWidgets('at countdown 00 the finished round is replayed once', (tester) async {
      final rig = Rig(tester, startInto: 93);
      await rig.open();
      await rig.world.run(const Duration(seconds: 5));
      expect(rig.game.catchUpReplays, 1);
      expect(rig.game.results.length, 1);
      expect(rig.game.results.single.id, 'round-$cycle');
      await rig.finish();
    });
  });

  group('the connection', () {
    testWidgets('three failed requests in a row mean "disconnected" (4-14.5 s after the drop, was ~5 s), '
        'one good request brings it back', (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      rig.server.offline = true;
      final droppedAt = rig.world.serverNow;
      var guard = 0;
      while (rig.sync.isConnected && ++guard < 400) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final lag = rig.world.serverNow.difference(droppedAt).inMilliseconds / 1000;
      debugPrint('AFTER "disconnected" after the drop: $lag s (before: 5.2 s)');
      expect(rig.sync.isConnected, isFalse);
      expect(rig.sync.connectionError, BetError.offline);
      expect(lag, inInclusiveRange(4.0, 14.5));
      rig.server.offline = false;
      await rig.world.run(const Duration(seconds: 3));
      expect(rig.sync.isConnected, isTrue);
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
  });

  group('leaving the screen', () {
    testWidgets('detach stops the schedule', (tester) async {
      final rig = Rig(tester, startInto: 30);
      await rig.open();
      rig.sync.detach();
      final polls = rig.server.polls;
      await rig.world.run(const Duration(seconds: 20));
      expect(rig.server.polls, polls);
      await rig.finish();
    });

    testWidgets('B-4 fixed: a 00 fetch still running when the screen is left stops asking '
        'and hands nothing over (before: 5 more requests and the result delivered)', (tester) async {
      final rig = Rig(tester, startInto: 80, resultFromSecond: 95);
      await rig.open();
      await rig.world.runUntil(91.5); // the 00 fetch is now retrying (the draw is slow)
      expect(rig.game.results, isEmpty);
      rig.sync.detach();
      final pollsAtLeave = rig.server.polls;
      await rig.world.run(const Duration(seconds: 8));
      final after = rig.server.polls - pollsAtLeave;
      debugPrint('AFTER (B-4) requests after leaving: $after; result handed over after leaving: '
          '${rig.game.results.length}');
      expect(after, 0, reason: 'the fetch stops when the screen is left');
      expect(rig.game.results, isEmpty, reason: 'nothing reaches the game after leaving');
      expect(rig.zeroFetchDelivered, [false]);
      await rig.finish();
    });

    testWidgets('B-4 fixed: coming straight back after leaving mid-fetch works normally', (tester) async {
      final rig = Rig(tester, startInto: 80, resultFromSecond: 95);
      await rig.open();
      await rig.world.runUntil(91.5);
      rig.sync.detach();
      await rig.open();
      await rig.world.runUntil(100.0);
      expect(rig.game.results.length, 1, reason: 'the reopened screen gets the result');
      expect(rig.sync.isConnected, isTrue);
      await rig.world.runUntil(102.5);
      final before = rig.server.polls;
      await rig.world.run(const Duration(seconds: 4)); // into the next round
      expect(rig.server.polls, greaterThan(before), reason: 'the schedule runs again');
      await rig.finish();
    });
  });

  group("the device's clock is moved (stopwatch schedule, ported from the other games)", () {
    int serverCountdown(Rig rig) {
      final c = 90 - rig.world.cyclePosition.floor();
      return c < 0 ? 0 : c;
    }

    void expectNormalRoundEnd(Rig rig) {
      expect(rig.lockAt.length, 1, reason: 'the lock fires once');
      expect(rig.countdownAtLock, [5]);
      expect(rig.lockAt.single, inInclusiveRange(84.5, 86.0));
      expect(rig.betAccepted, [true]);
      expect(rig.game.results.length, 1, reason: 'the result is shown once');
      expect(rig.game.results.single.id, 'round-$cycle');
      expect(rig.game.countdownAtResult, [0]);
    }

    testWidgets('moved back 30 seconds while betting: asked at once, countdown right again, lock and result as normal',
        (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      await rig.world.runUntil(40.0);
      final before = rig.server.polls;
      rig.world.skewSeconds = -30;
      await rig.world.run(const Duration(milliseconds: 1500));
      expect(rig.server.polls, greaterThan(before), reason: 'noticed within 1.5 s');
      await rig.world.run(const Duration(milliseconds: 1000));
      expect((rig.game.countdown - serverCountdown(rig)).abs(), lessThanOrEqualTo(1));
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
      expect(rig.server.polls, greaterThan(before), reason: 'noticed within 1.5 s');
      await rig.world.run(const Duration(milliseconds: 1000));
      expect((rig.game.countdown - serverCountdown(rig)).abs(), lessThanOrEqualTo(1));
      await rig.world.runUntil(95.0);
      expectNormalRoundEnd(rig);
      await rig.finish();
    });

    testWidgets('a small move (0.8 s, like a network time correction) adds no request', (tester) async {
      final rig = Rig(tester, startInto: 10);
      await rig.open();
      final before = rig.server.polls;
      rig.world.skewSeconds = 0.8;
      await rig.world.run(const Duration(seconds: 20));
      expect(rig.server.polls - before, inInclusiveRange(1, 3));
      await rig.finish();
    });

    testWidgets('the phone slept 8 seconds: asked at the next check after waking', (tester) async {
      final rig = Rig(tester, startInto: 20);
      await rig.open();
      await rig.world.runUntil(30.0);
      final before = rig.server.polls;
      rig.world.sleepPhone(const Duration(seconds: 8));
      await rig.world.run(const Duration(milliseconds: 600));
      expect(rig.server.polls, greaterThan(before));
      await rig.world.run(const Duration(milliseconds: 1000));
      expect((rig.game.countdown - serverCountdown(rig)).abs(), lessThanOrEqualTo(1));
      final afterWake = rig.server.polls;
      await rig.world.run(const Duration(seconds: 8));
      expect(rig.server.polls - afterWake, lessThanOrEqualTo(1), reason: 'back to the 10-second rhythm');
      await rig.finish();
    });

    testWidgets('one move back does not cause a request storm', (tester) async {
      const n = cycle + 60;
      final rig = Rig(tester, cycleNumber: n, startInto: 0.5);
      await rig.open();
      final before = rig.server.polls;
      await rig.world.run(const Duration(seconds: 40));
      rig.world.skewSeconds = -30;
      await rig.world.run(const Duration(seconds: 269));
      final perRound = (rig.server.polls - before) / 3;
      debugPrint('Triple Chance requests per round with one 30 s clock move back: $perRound');
      expect(perRound, inInclusiveRange(10.0, 14.5));
      expect(rig.game.results.map((r) => r.id), ['round-$n', 'round-${n + 1}', 'round-${n + 2}']);
      await rig.finish();
    });

    for (final dropAfter in [0.0, 2.0, 4.0, 6.0, 8.0, 9.5]) {
      testWidgets('network lost ${dropAfter}s after a request: "disconnected" within 4-14.5 s, recovers within 2.5 s',
          (tester) async {
        final rig = Rig(tester, startInto: 10, bets: false);
        await rig.open();
        await rig.world.runUntil(15.0);
        final n = rig.server.polls;
        var guard = 0;
        while (rig.server.polls == n && ++guard < 400) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await rig.world.run(const Duration(milliseconds: 150));
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
        expect(lag, inInclusiveRange(4.0, 14.5));
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

    testWidgets('network lost right after a clock move: the 2-second failing rhythm holds', (tester) async {
      final rig = Rig(tester, startInto: 10, bets: false);
      await rig.open();
      await rig.world.runUntil(40.0);
      final movedAt = rig.world.serverNow;
      final before = rig.server.polls;
      rig.world.skewSeconds = -30;
      rig.server.offline = true;
      await rig.world.run(const Duration(seconds: 12));
      expect(rig.sync.isConnected, isFalse);
      final times = rig.server.pollLog.skip(before).map((p) => p.at).toList();
      expect(times.first.difference(movedAt).inMilliseconds, lessThanOrEqualTo(600));
      for (var i = 1; i < times.length; i++) {
        final gap = times[i].difference(times[i - 1]).inMilliseconds / 1000;
        expect(gap, inInclusiveRange(1.5, 2.5), reason: 'request ${i + 1} after the move');
      }
      await rig.finish();
    });
  });
}
