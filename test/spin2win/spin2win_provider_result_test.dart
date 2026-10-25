// Tests for lib/providers/spin2win_provider.dart, part 2: the result sequence
// of a normal round. Whole rounds are played on a fake clock against the
// simulated server and a fake wallet.
//
// The simulated round `cycle` is won by number 7 with a 4X bonus. A bet of 10
// on that number pays 10 x 9 x 4 = 360.
//
// Times are written as seconds into the round (the countdown reads 00 at 90
// and the wheel turns for 4 s). W is the moment the test tells the provider
// the wheel has stopped. The user's timeline: coins W to W+1.5, popup W+1.5 to
// W+4.0, round over at W+6.0; a loser just waits until W+6.0.

import 'package:best_smart_game/models/spin2win_board.dart';
import 'package:best_smart_game/models/spin2win_models.dart';
import 'package:best_smart_game/providers/spin2win_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_rig.dart';
import 'sim_server.dart';

final int winner = SimulatedSpin2WinServer.winnerOf(cycle);
final int bonus = SimulatedSpin2WinServer.bonusOf(cycle);

void main() {
  group('a round the player won', () {
    testWidgets('Aisha: 100 staked, the number and bonus go to the wheel, the confirmation is asked for during the spin, nothing moves until the wheel stops', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryNumber();
      await rig.world.runUntil(91.2);

      final p = rig.provider;
      expect(p.stage, Spin2WinStage.spinning);
      expect(p.isSequenceRunning, isTrue);
      expect(p.spinTarget?.winningNumber, winner);
      expect(p.spinTarget?.bonusMultiplier, bonus);
      expect(p.numberRevealed, isFalse, reason: 'the number shows only once the wheel stops');
      expect(p.isLocked, isTrue);
      expect(rig.wallet.spinningGetter!(), isTrue, reason: 'the heartbeat must not apply a balance mid-reveal');
      expect(p.balance, 900);

      expect(rig.server.resultCalls, isNotEmpty, reason: 'asked for while the wheel turns');
      final firstAsk = positionOf(rig.server.resultCalls.first.at);
      expect(firstAsk, inInclusiveRange(89.9, 91.3));
      expect(rig.server.resultCalls.every((c) => c.roundId == 'round-$cycle'), isTrue, reason: 'the round the bet went to');

      await rig.world.runUntil(93.4);
      expect(rig.server.serverBalance, 900 + 360, reason: 'the server has already paid');
      expect(p.balance, 900, reason: 'but the screen has not moved: the wheel has not stopped');
      expect(rig.wallet.synced.length, 1, reason: 'only the bet confirmation so far');
      expect(p.numberRevealed, isFalse);
      await rig.finish();
    });

    testWidgets('when the wheel stops: balance, number and coins together; popup 1.5 s later for 2.5 s; the round ends 6.0 s after', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryNumber();
      final p = rig.provider;
      final w = await landWheelAt(rig, 93.5);

      expect(p.balance, 1260);
      expect(rig.wallet.synced.last.balance, 1260);
      expect(p.numberRevealed, isTrue);
      expect(p.stage, Spin2WinStage.revealing);
      expect(p.showCoinFx, isTrue);
      expect(p.popup, isNull);
      expect(p.lastOutcome?.payout, 360);
      expect(p.lastOutcome?.stake, 100);
      expect(p.lastOutcome?.won, isTrue);
      expect(p.balanceSyncFailed, isFalse);

      await rig.world.runUntil(w + 1.3);
      expect(p.popup, isNull);
      expect(p.showCoinFx, isTrue);
      await rig.world.runUntil(w + 1.7);
      expect(p.popup, isNotNull);
      expect(p.popup!.payout, 360);
      expect(p.popup!.winningNumber, winner);
      expect(p.popup!.bonusMultiplier, bonus);
      expect(p.showCoinFx, isFalse, reason: 'the coins stop as the popup opens');
      await rig.world.runUntil(w + 3.8);
      expect(p.popup, isNotNull);

      await rig.world.runUntil(w + 4.2);
      expect(p.popup, isNull, reason: 'the popup is on screen for 2.5 s');
      expect(p.stage, Spin2WinStage.revealing, reason: 'then the 2 s pause');
      expect(p.isSequenceRunning, isTrue);
      await rig.world.runUntil(w + 5.8);
      expect(p.stage, Spin2WinStage.revealing);

      await rig.world.runUntil(w + 6.2);
      expect(p.popup, isNull);
      expect(p.stage, Spin2WinStage.none);
      expect(p.isSequenceRunning, isFalse);
      expect(rig.wallet.spinningGetter!(), isFalse);
      expect(p.spinTarget, isNull);
      expect(p.isBoardEmpty, isTrue);
      expect(p.isBetSubmitted, isFalse);
      expect(p.betStatus, Spin2WinBetStatus.idle);
      expect(p.canRebet, isTrue);
      expect(p.isLocked, isTrue, reason: 'the countdown is at 00 until the next round');
      expect(rig.problems, isEmpty);

      await rig.runIntoNextCycle(2.0);
      expect(p.isLocked, isFalse);
      expect(p.phase, Spin2WinPhase.betting);
      expect(p.rebet().coinsSpent, 100);
      expect(p.balance, 1260 - 100);
      expect(p.lastOutcome, isNull, reason: 'the badge goes when the next bet starts');
      await rig.finish();
    });
  });

  group('a round the player lost, and a spectator', () {
    testWidgets('a loser: the balance is confirmed when the wheel stops, no coins, no popup, a 6 s wait', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.provider.selectChip(Spin2WinChip.ten);
      rig.provider.tapNumber(0); // not the winner
      final p = rig.provider;
      final w = await landWheelAt(rig, 93.5);

      expect(p.numberRevealed, isTrue);
      expect(p.balance, 990);
      expect(rig.wallet.synced.last.balance, 990);
      expect(p.showCoinFx, isFalse);
      expect(p.lastOutcome?.payout, 0);
      expect(p.lastOutcome?.won, isFalse);
      await rig.world.runUntil(w + 1.7);
      expect(p.popup, isNull);
      await rig.world.runUntil(w + 5.8);
      expect(p.popup, isNull);
      expect(p.stage, Spin2WinStage.revealing);
      await rig.world.runUntil(w + 6.2);
      expect(p.stage, Spin2WinStage.none);
      expect(p.isBoardEmpty, isTrue);
      expect(p.canRebet, isTrue);
      await rig.finish();
    });

    testWidgets('a spectator sees the wheel and the number, asks the server nothing, and ends together with everyone', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      final p = rig.provider;
      await rig.world.runUntil(91.2);
      expect(p.stage, Spin2WinStage.spinning);
      expect(p.spinTarget?.winningNumber, winner);
      final w = await landWheelAt(rig, 93.5);

      expect(p.numberRevealed, isTrue);
      expect(p.balance, 1000);
      expect(rig.server.resultCalls, isEmpty);
      expect(p.showCoinFx, isFalse);
      expect(p.lastOutcome?.stake, 0);
      expect(p.lastOutcome?.won, isFalse);
      await rig.world.runUntil(w + 6.2);
      expect(p.stage, Spin2WinStage.none);
      expect(p.canRebet, isFalse, reason: 'nothing to remember');
      expect(rig.wallet.synced, isEmpty);
      await rig.finish();
    });
  });

  group('when the confirmation is slow', () {
    testWidgets('an answer after the wheel stops is awaited; the balance moves when it arrives; the round still ends at W+6', (tester) async {
      final rig = BetRig(tester);
      rig.server.settleFromSecond = 95;
      await rig.open();
      rig.betTenOnEveryNumber();
      final p = rig.provider;
      final w = await landWheelAt(rig, 93.5);

      await rig.world.runUntil(w + 0.3);
      expect(p.balance, 900, reason: 'not settled yet: nothing is guessed');
      expect(p.numberRevealed, isFalse);
      expect(p.stage, Spin2WinStage.spinning);

      // Each retry waits its gap after the previous answer, so the sixth ask is
      // about 6.2 s after the spin began (about W+3.4).
      await rig.world.runUntil(w + 3.8);
      expect(p.numberRevealed, isTrue);
      expect(p.balance, 1260);
      expect(p.balanceSyncFailed, isFalse);
      expect(rig.server.resultCalls.length, inInclusiveRange(4, 6));
      expect(p.popup, isNotNull, reason: 'a late winner still gets the popup');
      expect(p.showCoinFx, isFalse);
      await rig.world.runUntil(w + 6.2);
      expect(p.stage, Spin2WinStage.none);
      await rig.finish();
    });

    testWidgets('a reveal so late that both deadlines are past still shows the popup for at least 1.2 s, and no coin effect', (tester) async {
      final rig = BetRig(tester);
      rig.server.resultLatency = const Duration(milliseconds: 4500);
      await rig.open();
      rig.betTenOnEveryNumber();
      final p = rig.provider;
      final w = await landWheelAt(rig, 91.3); // the wheel stops early; the answer comes ~4.5 s after the spin began

      double? openedAt;
      double? closedAt;
      double? endedAt;
      while (rig.world.cyclePosition < w + 8.5 && endedAt == null) {
        await rig.world.run(const Duration(milliseconds: 100));
        final now = rig.world.cyclePosition;
        if (p.popup != null) openedAt ??= now;
        if (openedAt != null && p.popup == null) closedAt ??= now;
        if (p.stage == Spin2WinStage.none) endedAt = now;
        if (p.numberRevealed) expect(p.showCoinFx, isFalse, reason: 'no room for the coins before the popup');
      }
      expect(openedAt, isNotNull, reason: 'the winner must see the popup');
      expect(closedAt! - openedAt!, greaterThanOrEqualTo(1.1), reason: 'at least 1.2 s on screen (100 ms sampling)');
      expect(openedAt, greaterThan(w + 3.0), reason: 'it really was a late reveal');
      expect(p.balance, 1260);
      await rig.finish();
    });

    testWidgets('a reveal that leaves less than half a second before the popup gets no coin effect', (tester) async {
      final rig = BetRig(tester);
      rig.server.resultLatency = const Duration(seconds: 6);
      await rig.open();
      rig.betTenOnEveryNumber();
      final p = rig.provider;
      await rig.world.runUntil(91.6);
      final spinStart = positionOf(rig.server.resultCalls.first.at);
      // The only answer comes 6 s after the spin began; the wheel stops 1.25 s
      // before it, so the reveal is 1.25 s after W and the popup 0.25 s later.
      await landWheelAt(rig, spinStart + 4.75);
      expect(p.numberRevealed, isFalse, reason: 'still waiting for the answer');

      var sawReveal = false;
      for (var i = 0; i < 40 && p.popup == null; i++) {
        await rig.world.run(const Duration(milliseconds: 50));
        if (p.numberRevealed) sawReveal = true;
        if (p.popup == null) {
          expect(p.showCoinFx, isFalse, reason: 'less than 0.5 s before the popup: no coin effect');
        }
      }
      expect(sawReveal, isTrue);
      expect(p.popup, isNotNull);
      await rig.finish();
    });

    testWidgets('a bet that never settles in the budget: nothing guessed, the failure is flagged, the round still ends', (tester) async {
      final rig = BetRig(tester);
      rig.server.settleFromSecond = 200;
      await rig.open();
      rig.betTenOnEveryNumber();
      final p = rig.provider;
      final w = await landWheelAt(rig, 93.5);

      await rig.world.runUntil(w + 3.8);
      expect(p.numberRevealed, isTrue);
      expect(p.balanceSyncFailed, isTrue);
      expect(p.balance, 900, reason: 'no balance is invented; the heartbeat catches up');
      expect(rig.wallet.synced.length, 1, reason: 'only the bet confirmation');
      expect(rig.server.resultCalls.length, 6, reason: 'the whole budget, no more');
      expect(p.lastOutcome?.payout, 0);
      await rig.world.runUntil(w + 4.0);
      expect(p.popup, isNull);
      await rig.world.runUntil(w + 6.2);
      expect(p.stage, Spin2WinStage.none);
      expect(p.isBoardEmpty, isTrue);
      expect(p.canRebet, isTrue, reason: 'the stake really was taken: the round happened');
      await rig.finish();
    });

    testWidgets('the answers are retried through failures (offline blips) and the bet is then confirmed', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryNumber();
      rig.server.resultsOffline = true;
      await rig.world.runUntil(92.0);
      rig.server.resultsOffline = false;
      final w = await landWheelAt(rig, 93.5);
      await rig.world.run(const Duration(milliseconds: 1000));
      expect(rig.provider.balance, 1260);
      expect(rig.provider.balanceSyncFailed, isFalse);
      await rig.world.runUntil(w + 6.2);
      expect(rig.provider.stage, Spin2WinStage.none);
      await rig.finish();
    });
  });

  group('the wheel signal', () {
    testWidgets('a wheel that never reports is waited for 6 s, then the sequence carries on', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryNumber();
      final p = rig.provider;
      await rig.world.runUntil(95.5);
      expect(p.numberRevealed, isFalse);
      expect(p.stage, Spin2WinStage.spinning);
      await rig.world.runUntil(97.4);
      expect(p.numberRevealed, isTrue, reason: 'about 6 s after the spin began (90 to 91)');
      expect(p.balance, 1260);
      // Six seconds after a late reveal is a little into the next round; the
      // board is released then, as for a late confirmation.
      await rig.runIntoNextCycle(3.6);
      expect(p.stage, Spin2WinStage.none);
      expect(p.isLocked, isFalse);
      await rig.finish();
    });

    testWidgets('a landing with no sequence running, or a second landing, is ignored', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      final p = rig.provider;
      p.wheelLanded();
      p.wheelLanded();
      expect(p.stage, Spin2WinStage.none);
      final w = await landWheelAt(rig, 93.5);
      p.wheelLanded();
      p.wheelLanded();
      await rig.world.run(const Duration(milliseconds: 100));
      expect(p.stage, Spin2WinStage.revealing);
      await rig.world.runUntil(w + 6.2);
      expect(p.stage, Spin2WinStage.none);
      p.wheelLanded();
      expect(p.stage, Spin2WinStage.none);
      await rig.finish();
    });

    testWidgets('a second result handed over while one is running is ignored', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      final p = rig.provider;
      await rig.world.runUntil(91.2);
      final target = p.spinTarget!;
      rig.sync.onResult!(Spin2WinRoundResult(
        roundId: 'round-other',
        roundNumber: 1,
        winningNumber: 0,
        bonusMultiplier: 3,
        scheduledAt: DateTime.utc(2026),
        isCatchUpReplay: false,
      ));
      expect(p.spinTarget, same(target));
      await rig.finish();
    });
  });

  group('the board while a sequence runs', () {
    testWidgets('a late joiner: the board stays locked across the next round\'s start, unlocks when the sequence ends, no Rebet for a replay', (tester) async {
      final rig = BetRig(tester, startInto: 97);
      await rig.open();
      final p = rig.provider;
      expect(p.stage, Spin2WinStage.spinning, reason: 'the finished round is replayed from now');
      expect(p.spinTarget?.isCatchUpReplay, isTrue);

      await rig.runIntoNextCycle(1.0);
      expect(p.isSequenceRunning, isTrue);
      expect(p.isLocked, isTrue, reason: 'a new round has begun but the sequence still owns the board');
      final r = p.tapNumber(0);
      expect(r.changedAnything, isFalse);

      final w = await landWheelAt(rig, 2.0);
      await rig.world.runUntil(w + 6.2);
      expect(p.stage, Spin2WinStage.none);
      expect(p.isLocked, isFalse, reason: 'betting is open again');
      expect(p.phase, Spin2WinPhase.betting);
      expect(p.canRebet, isFalse);
      await rig.finish();
    });
  });

  group('leaving', () {
    testWidgets('leaving while the wheel turns: nothing is applied afterwards, the hooks are gone', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryNumber();
      await rig.world.runUntil(91.2);
      expect(rig.provider.stage, Spin2WinStage.spinning);
      rig.provider.leave();
      expect(rig.wallet.spinningGetter, isNull);
      expect(rig.provider.stage, Spin2WinStage.none);
      expect(rig.provider.spinTarget, isNull);

      rig.provider.wheelLanded();
      await rig.world.run(const Duration(seconds: 15));
      expect(rig.wallet.synced.length, 1, reason: 'only the bet confirmation; no late answer was applied');
      expect(rig.provider.balance, 900);
      expect(rig.provider.popup, isNull);
      expect(rig.provider.numberRevealed, isFalse);
      expect(rig.problems, isEmpty);
      await rig.finish();
    });
  });
}
