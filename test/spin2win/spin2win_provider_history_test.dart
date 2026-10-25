// Tests for lib/providers/spin2win_provider.dart, part 3: the last-10 history
// strip, a round that never resolves, late joiners, and leaving at every stage
// of the sequence.
//
// The simulated round `cycle` is won by number 7 with a 4X bonus; a bet of 10
// on that number pays 360. Times are seconds into the round.

import 'package:best_smart_game/models/spin2win_board.dart';
import 'package:best_smart_game/providers/spin2win_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_rig.dart';
import 'sim_server.dart';

final int winner = SimulatedSpin2WinServer.winnerOf(cycle);
final int bonus = SimulatedSpin2WinServer.bonusOf(cycle);

List<int> numbersOf(Spin2WinProvider p) => p.history.map((r) => r.roundNumber).toList();

void main() {
  group('the history strip', () {
    testWidgets('opened mid-round: the last 10 drawn rounds, newest first, the current round not among them', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      await rig.world.run(const Duration(seconds: 1));
      final p = rig.provider;
      expect(numbersOf(p), [for (var n = cycle - 1; n > cycle - 11; n--) n]);
      expect(p.history.first.winningNumber, SimulatedSpin2WinServer.winnerOf(cycle - 1));
      expect(p.history.first.bonusMultiplier, SimulatedSpin2WinServer.bonusOf(cycle - 1));
      await rig.finish();
    });

    testWidgets('the new round enters the strip when the wheel stops, not a moment before, and the oldest drops out', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      final p = rig.provider;
      await rig.world.runUntil(93.4);
      expect(p.history.first.roundNumber, cycle - 1, reason: 'the winner is drawn at 90 but must not show yet');
      expect(p.history.any((r) => r.roundNumber == cycle), isFalse);

      await landWheelAt(rig, 93.5);
      expect(p.history.first.roundNumber, cycle);
      expect(p.history.first.winningNumber, winner);
      expect(p.history.first.bonusMultiplier, bonus);
      expect(p.history.length, 10);
      expect(numbersOf(p), [for (var n = cycle; n > cycle - 10; n--) n]);
      await rig.finish();
    });

    testWidgets('a player who opens the screen after the draw but before the reveal is not shown the winner early', (tester) async {
      final rig = BetRig(tester, startInto: 91);
      await rig.open();
      await rig.world.run(const Duration(seconds: 1));
      final p = rig.provider;
      expect(rig.server.recentCalls, isNotEmpty);
      expect(p.stage, Spin2WinStage.spinning);
      expect(p.history.any((r) => r.roundNumber == cycle), isFalse, reason: 'the server already lists it');
      expect(p.history.first.roundNumber, cycle - 1);
      expect(numbersOf(p), [for (var n = cycle - 1; n > cycle - 11; n--) n], reason: 'one more is asked for, so the strip is full without the hidden round');
      await rig.finish();
    });

    testWidgets('and gets it, once, when the wheel lands', (tester) async {
      final rig = BetRig(tester, startInto: 91);
      await rig.open();
      await rig.world.run(const Duration(seconds: 1));
      final p = rig.provider;
      await landWheelAt(rig, rig.world.cyclePosition + 0.1);
      expect(numbersOf(p).where((n) => n == cycle).length, 1);
      expect(p.history.first.roundNumber, cycle);
      expect(p.history.length, 10);
      await rig.finish();
    });

    testWidgets('a history answer that arrives after the reveal does not duplicate or wipe the round', (tester) async {
      final rig = BetRig(tester, startInto: 95, latency: const Duration(seconds: 2));
      final attached = rig.provider.attach();
      await rig.world.run(const Duration(milliseconds: 2200));
      await attached;
      final p = rig.provider;
      expect(p.stage, Spin2WinStage.spinning);
      p.wheelLanded(); // the reveal comes before the history answer
      await rig.world.run(const Duration(milliseconds: 200));
      expect(numbersOf(p), [cycle], reason: 'only the revealed round so far');

      await rig.world.run(const Duration(seconds: 3));
      expect(numbersOf(p), [for (var n = cycle; n > cycle - 10; n--) n]);
      await rig.finish();
    });

    testWidgets('a failed history load after a reveal keeps what is there', (tester) async {
      final rig = BetRig(tester, startInto: 95, latency: const Duration(seconds: 2));
      final attached = rig.provider.attach();
      await rig.world.run(const Duration(milliseconds: 2200));
      await attached;
      final p = rig.provider;
      p.wheelLanded();
      await rig.world.run(const Duration(milliseconds: 200));
      rig.server.recentOffline = true;
      await rig.world.run(const Duration(seconds: 3));
      expect(numbersOf(p), [cycle], reason: 'an empty answer must not wipe the strip');
      await rig.finish();
    });

    testWidgets('two rounds in a row: newest first, no duplicates, never more than 10', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      final p = rig.provider;
      await landWheelAt(rig, 93.5);
      await rig.runIntoNextCycle(94.0);
      await landWheelAt(rig, 93.5);
      expect(numbersOf(p), [for (var n = cycle + 1; n > cycle - 9; n--) n]);
      expect(p.history.first.bonusMultiplier, SimulatedSpin2WinServer.bonusOf(cycle + 1));
      await rig.finish();
    });

    testWidgets('leaving empties the strip; opening again loads it afresh', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      await rig.world.run(const Duration(seconds: 1));
      expect(rig.provider.history, isNotEmpty);
      rig.provider.leave();
      expect(rig.provider.history, isEmpty);
      await rig.finish();
    });

    testWidgets('an offline start leaves the strip empty and nothing breaks', (tester) async {
      final rig = BetRig(tester);
      rig.server.recentOffline = true;
      await rig.open();
      await rig.world.run(const Duration(seconds: 2));
      expect(rig.provider.history, isEmpty);
      expect(rig.problems, isEmpty);
      await rig.finish();
    });
  });

  group('a round that never resolves', () {
    testWidgets('a bettor: told, the board dropped with NO refund, the saved Rebet bet kept', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      // Round one plays normally, so there is a bet to remember for Rebet.
      rig.betTenOnEveryNumber();
      final p = rig.provider;
      final w = await landWheelAt(rig, 93.5);
      await rig.world.runUntil(w + 6.2);
      expect(p.canRebet, isTrue);
      final balanceAfterRound = p.balance;

      // Round two: the draw never happens.
      rig.server.resultFromSecond = 1000;
      await rig.runIntoNextCycle(10.0);
      p.selectChip(Spin2WinChip.fifty);
      p.tapNumber(0);
      expect(p.balance, balanceAfterRound - 50);
      await rig.world.runUntil(99.6);

      expect(rig.problems.length, 1);
      expect(rig.problems.single.kind, Spin2WinProblemKind.roundUnresolved);
      expect(rig.problems.single.reason, isNull);
      expect(p.isBoardEmpty, isTrue);
      expect(p.balance, balanceAfterRound - 50, reason: 'the stake really was taken: no refund is claimed');
      expect(rig.server.serverBalance, balanceAfterRound - 50);
      expect(p.isBetSubmitted, isFalse);
      expect(p.betStatus, Spin2WinBetStatus.idle);
      expect(p.submittedRoundId, isNull);
      expect(p.canRebet, isTrue, reason: 'the saved bet belongs to the earlier, completed round');
      expect(p.stage, Spin2WinStage.none);
      expect(p.isLocked, isTrue, reason: 'the countdown is at 00');

      await rig.runIntoNextCycle(2.0);
      expect(p.isLocked, isFalse);
      expect(rig.problems.length, 1, reason: 'told once');
      await rig.finish();
    });

    testWidgets('a spectator is told too (as in Triple Chance)', (tester) async {
      final rig = BetRig(tester);
      rig.server.resultFromSecond = 1000;
      await rig.open();
      await rig.world.runUntil(99.6);
      expect(rig.problems.length, 1);
      expect(rig.problems.single.kind, Spin2WinProblemKind.roundUnresolved);
      expect(rig.provider.stage, Spin2WinStage.none);
      expect(rig.provider.balance, 1000);
      await rig.finish();
    });

    testWidgets('not told while the result is merely slow', (tester) async {
      final rig = BetRig(tester);
      rig.server.resultFromSecond = 93; // drawn late, but within the 8 asks
      await rig.open();
      await rig.world.runUntil(97.0);
      expect(rig.problems, isEmpty);
      expect(rig.provider.stage, isNot(Spin2WinStage.none));
      await rig.finish();
    });

    testWidgets('leaving before the sync gives up tells no one', (tester) async {
      final rig = BetRig(tester);
      rig.server.resultFromSecond = 1000;
      await rig.open();
      await rig.world.runUntil(92.0);
      rig.provider.leave();
      await rig.world.run(const Duration(seconds: 15));
      expect(rig.problems, isEmpty);
      await rig.finish();
    });
  });

  group('a late joiner gets the whole reveal, as in Triple Chance', () {
    for (final joinAt in [91.0, 94.0, 97.0]) {
      testWidgets('joining at second ${joinAt.toInt()}', (tester) async {
        final rig = BetRig(tester, startInto: joinAt);
        await rig.open();
        final p = rig.provider;
        expect(p.stage, Spin2WinStage.spinning);
        expect(p.spinTarget?.winningNumber, winner);
        expect(p.spinTarget?.bonusMultiplier, bonus);
        expect(p.spinTarget?.isCatchUpReplay, isTrue);
        expect(p.numberRevealed, isFalse);
        expect(p.isLocked, isTrue);
        expect(p.history.any((r) => r.roundNumber == cycle), isFalse);

        p.wheelLanded();
        await rig.world.run(const Duration(milliseconds: 100));
        expect(p.numberRevealed, isTrue);
        expect(p.history.first.roundNumber, cycle);
        expect(p.balance, 1000);
        expect(p.showCoinFx, isFalse);
        expect(p.popup, isNull);

        await rig.world.run(const Duration(milliseconds: 5600));
        expect(p.stage, Spin2WinStage.revealing, reason: 'the reveal lasts until W+6');
        await rig.world.run(const Duration(milliseconds: 600));
        expect(p.stage, Spin2WinStage.none);
        expect(p.canRebet, isFalse, reason: 'a replay is not offered for Rebet');
        expect(rig.server.betsReceived, 0);
        expect(rig.server.resultCalls, isEmpty);
        expect(rig.wallet.synced, isEmpty);
        expect(rig.problems, isEmpty);
        await rig.finish();
      });
    }
  });

  group('leaving at every stage of the sequence', () {
    Future<BetRig> winnerAtLanding(WidgetTester tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryNumber();
      await landWheelAt(rig, 93.5);
      return rig;
    }

    void expectNothingLeft(BetRig rig) {
      final p = rig.provider;
      expect(p.stage, Spin2WinStage.none);
      expect(p.isSequenceRunning, isFalse);
      expect(p.spinTarget, isNull);
      expect(p.numberRevealed, isFalse);
      expect(p.showCoinFx, isFalse);
      expect(p.popup, isNull);
      expect(p.lastOutcome, isNull);
      expect(rig.wallet.spinningGetter, isNull);
      expect(rig.wallet.uncommittedGetter, isNull);
    }

    testWidgets('during the coin effect', (tester) async {
      final rig = await winnerAtLanding(tester);
      expect(rig.provider.showCoinFx, isTrue);
      final synced = rig.wallet.synced.length;
      rig.provider.leave();
      expectNothingLeft(rig);
      await rig.world.run(const Duration(seconds: 12));
      expectNothingLeft(rig);
      expect(rig.wallet.synced.length, synced, reason: 'nothing more reaches the wallet');
      expect(rig.provider.balance, 1260, reason: 'the reveal had already happened');
      expect(rig.problems, isEmpty);
      await rig.finish();
    });

    testWidgets('during the popup', (tester) async {
      final rig = await winnerAtLanding(tester);
      await rig.world.run(const Duration(milliseconds: 1800));
      expect(rig.provider.popup, isNotNull);
      rig.provider.leave();
      expectNothingLeft(rig);
      await rig.world.run(const Duration(seconds: 12));
      expectNothingLeft(rig);
      expect(rig.provider.canRebet, isFalse, reason: 'the round was left, not completed');
      expect(rig.problems, isEmpty);
      await rig.finish();
    });

    testWidgets('after the round has ended, and twice', (tester) async {
      final rig = await winnerAtLanding(tester);
      await rig.world.run(const Duration(milliseconds: 6300));
      expect(rig.provider.stage, Spin2WinStage.none);
      rig.provider.leave();
      rig.provider.leave();
      expectNothingLeft(rig);
      expect(rig.provider.balance, 1260);
      await rig.finish();
    });

    testWidgets('while waiting for a slow confirmation', (tester) async {
      final rig = BetRig(tester);
      rig.server.settleFromSecond = 200;
      await rig.open();
      rig.betTenOnEveryNumber();
      await landWheelAt(rig, 93.5);
      expect(rig.provider.numberRevealed, isFalse);
      rig.provider.leave();
      await rig.world.run(const Duration(seconds: 12));
      expectNothingLeft(rig);
      expect(rig.provider.balanceSyncFailed, isFalse);
      expect(rig.wallet.synced.length, 1, reason: 'only the bet confirmation');
      await rig.finish();
    });
  });
}
