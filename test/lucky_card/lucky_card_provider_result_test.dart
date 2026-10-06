// Tests for lib/providers/lucky_card_provider.dart, part 2a (App Step 3b-2a): the
// result sequence of a normal round. Whole rounds are played on a fake clock
// against the simulated server and a fake wallet.
//
// The simulated round `cycle` is won by card 11 with a 4X bonus. A bet of 10 on
// that card pays 400 in the simulated server.
//
// Times are written as seconds into the round (the countdown reads 00 at 90).
// W is the moment the test tells the provider the suit rim has landed.

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_rig.dart';
import 'sim_server.dart';

final LuckyCard winner = SimulatedLuckyCardServer.winnerOf(cycle);
final int bonus = SimulatedLuckyCardServer.bonusOf(cycle);

void main() {
  group('a round the player won', () {
    testWidgets('Aisha: 120 staked, the card and bonus go to the wheel, the confirmation is asked for during the spin, nothing moves until the suit rim lands', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryCard();
      await rig.world.runUntil(91.2);

      final p = rig.provider;
      expect(p.stage, LuckyCardStage.spinning);
      expect(p.isSequenceRunning, isTrue);
      expect(p.spinTarget?.winningCard, winner);
      expect(p.spinTarget?.bonusMultiplier, bonus);
      expect(p.cardRevealed, isFalse, reason: 'the hub shows the card only after both rims land');
      expect(p.isLocked, isTrue);
      expect(rig.wallet.spinningGetter!(), isTrue, reason: 'the heartbeat must not apply a balance mid-reveal');
      expect(p.balance, 880);

      expect(rig.server.resultCalls, isNotEmpty, reason: 'asked for while the wheel turns');
      final firstAsk = positionOf(rig.server.resultCalls.first.at);
      expect(firstAsk, inInclusiveRange(89.9, 91.3));
      expect(rig.server.resultCalls.every((c) => c.roundId == 'round-$cycle'), isTrue, reason: 'the round the bet went to');

      await rig.world.runUntil(94.9);
      expect(rig.server.serverBalance, 880 + 400, reason: 'the server has already paid');
      expect(p.balance, 880, reason: 'but the screen has not moved: the suit rim has not landed');
      expect(rig.wallet.synced.length, 1, reason: 'only the bet confirmation so far');
      expect(p.cardRevealed, isFalse);
      await rig.finish();
    });

    testWidgets('at the suit rim: balance, card and coins together; popup 1.5 s later; the round ends 4.0 s after', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryCard();
      final p = rig.provider;
      final w = await landWheelAt(rig, 95.0);

      expect(p.balance, 1280);
      expect(rig.wallet.synced.last.balance, 1280);
      expect(p.cardRevealed, isTrue);
      expect(p.stage, LuckyCardStage.revealing);
      expect(p.showCoinFx, isTrue);
      expect(p.popup, isNull);
      expect(p.lastOutcome?.payout, 400);
      expect(p.lastOutcome?.stake, 120);
      expect(p.lastOutcome?.won, isTrue);
      expect(p.balanceSyncFailed, isFalse);

      await rig.world.runUntil(w + 1.3);
      expect(p.popup, isNull);
      expect(p.showCoinFx, isTrue);
      await rig.world.runUntil(w + 1.7);
      expect(p.popup, isNotNull);
      expect(p.popup!.payout, 400);
      expect(p.popup!.winningCard, winner);
      expect(p.popup!.bonusMultiplier, bonus);
      expect(p.showCoinFx, isFalse, reason: 'the coins stop as the popup opens');
      await rig.world.runUntil(w + 3.8);
      expect(p.popup, isNotNull);

      await rig.world.runUntil(w + 4.2);
      expect(p.popup, isNull);
      expect(p.stage, LuckyCardStage.none);
      expect(p.isSequenceRunning, isFalse);
      expect(rig.wallet.spinningGetter!(), isFalse);
      expect(p.spinTarget, isNull);
      expect(p.isBoardEmpty, isTrue);
      expect(p.isBetSubmitted, isFalse);
      expect(p.betStatus, LuckyCardBetStatus.idle);
      expect(p.canRebet, isTrue);
      expect(p.isLocked, isTrue, reason: 'the countdown is at 00 until the next round');
      expect(rig.problems, isEmpty);

      await rig.runIntoNextCycle(2.0);
      expect(p.isLocked, isFalse);
      expect(p.phase, LuckyCardPhase.betting);
      expect(p.rebet().coinsSpent, 120);
      expect(p.balance, 1280 - 120);
      expect(p.lastOutcome, isNull, reason: 'the badge goes when the next bet starts');
      await rig.finish();
    });
  });

  group('a round the player lost, and a spectator', () {
    testWidgets('a loser: the balance is confirmed at the landing, no coins, no popup, same end', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.provider.selectChip(LuckyCardChip.ten);
      rig.provider.tapCard(LuckyCard.all.first); // not the winner
      final p = rig.provider;
      final w = await landWheelAt(rig, 95.0);

      expect(p.cardRevealed, isTrue);
      expect(p.balance, 990);
      expect(rig.wallet.synced.last.balance, 990);
      expect(p.showCoinFx, isFalse);
      expect(p.lastOutcome?.payout, 0);
      expect(p.lastOutcome?.won, isFalse);
      await rig.world.runUntil(w + 1.7);
      expect(p.popup, isNull);
      await rig.world.runUntil(w + 3.8);
      expect(p.popup, isNull);
      expect(p.stage, LuckyCardStage.revealing);
      await rig.world.runUntil(w + 4.2);
      expect(p.stage, LuckyCardStage.none);
      expect(p.isBoardEmpty, isTrue);
      expect(p.canRebet, isTrue);
      await rig.finish();
    });

    testWidgets('a spectator sees the wheel and the card, asks the server nothing, and ends together with everyone', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      final p = rig.provider;
      await rig.world.runUntil(91.2);
      expect(p.stage, LuckyCardStage.spinning);
      expect(p.spinTarget?.winningCard, winner);
      final w = await landWheelAt(rig, 95.0);

      expect(p.cardRevealed, isTrue);
      expect(p.balance, 1000);
      expect(rig.server.resultCalls, isEmpty);
      expect(p.showCoinFx, isFalse);
      expect(p.lastOutcome?.stake, 0);
      expect(p.lastOutcome?.won, isFalse);
      await rig.world.runUntil(w + 4.2);
      expect(p.stage, LuckyCardStage.none);
      expect(p.canRebet, isFalse, reason: 'nothing to remember');
      expect(rig.wallet.synced, isEmpty);
      await rig.finish();
    });
  });

  group('when the confirmation is slow', () {
    testWidgets('an answer after the landing is awaited; the balance moves when it arrives; the round still ends at W+4', (tester) async {
      final rig = BetRig(tester);
      rig.server.settleFromSecond = 96;
      await rig.open();
      rig.betTenOnEveryCard();
      final p = rig.provider;
      final w = await landWheelAt(rig, 95.0);

      await rig.world.runUntil(w + 0.3);
      expect(p.balance, 880, reason: 'not settled yet: nothing is guessed');
      expect(p.cardRevealed, isFalse);
      expect(p.stage, LuckyCardStage.spinning);

      // Each retry waits its gap after the previous answer, so the six asks end
      // about 6.3 s after the spin began (a little after W+1.5).
      await rig.world.runUntil(w + 2.2);
      expect(p.cardRevealed, isTrue);
      expect(p.balance, 1280);
      expect(p.balanceSyncFailed, isFalse);
      expect(rig.server.resultCalls.length, inInclusiveRange(4, 6));
      expect(p.popup, isNotNull, reason: 'a late winner still gets the popup');
      expect(p.showCoinFx, isFalse);
      await rig.world.runUntil(w + 4.2);
      expect(p.stage, LuckyCardStage.none);
      await rig.finish();
    });

    testWidgets('a reveal so late that both deadlines are past still shows the popup for at least 1.2 s, and no coin effect', (tester) async {
      final rig = BetRig(tester);
      rig.server.resultLatency = const Duration(milliseconds: 4500);
      await rig.open();
      rig.betTenOnEveryCard();
      final p = rig.provider;
      final w = await landWheelAt(rig, 91.3); // the wheel lands early; the answer comes ~4.5 s after the spin began

      double? openedAt;
      double? closedAt;
      double? endedAt;
      while (rig.world.cyclePosition < w + 9 && endedAt == null) {
        await rig.world.run(const Duration(milliseconds: 100));
        final now = rig.world.cyclePosition;
        if (p.popup != null) openedAt ??= now;
        if (openedAt != null && p.popup == null) closedAt ??= now;
        if (p.stage == LuckyCardStage.none) endedAt = now;
        if (p.cardRevealed) expect(p.showCoinFx, isFalse, reason: 'no room for the coins before the popup');
      }
      expect(openedAt, isNotNull, reason: 'the winner must see the popup');
      expect(closedAt! - openedAt!, greaterThanOrEqualTo(1.1), reason: 'at least 1.2 s on screen (100 ms sampling)');
      expect(openedAt, greaterThan(w + 3.0), reason: 'it really was a late reveal');
      expect(p.balance, 1280);
      await rig.finish();
    });

    testWidgets('a reveal that leaves less than half a second before the popup gets no coin effect', (tester) async {
      final rig = BetRig(tester);
      rig.server.resultLatency = const Duration(seconds: 6);
      await rig.open();
      rig.betTenOnEveryCard();
      final p = rig.provider;
      await rig.world.runUntil(91.6);
      final spinStart = positionOf(rig.server.resultCalls.first.at);
      // The only answer comes 6 s after the spin began; the wheel lands 1.25 s
      // before it, so the reveal is 1.25 s after W and the popup 0.25 s later.
      await landWheelAt(rig, spinStart + 4.75);
      expect(p.cardRevealed, isFalse, reason: 'still waiting for the answer');

      var sawReveal = false;
      for (var i = 0; i < 40 && p.popup == null; i++) {
        await rig.world.run(const Duration(milliseconds: 50));
        if (p.cardRevealed) sawReveal = true;
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
      rig.betTenOnEveryCard();
      final p = rig.provider;
      final w = await landWheelAt(rig, 95.0);

      await rig.world.runUntil(w + 2.2);
      expect(p.cardRevealed, isTrue);
      expect(p.balanceSyncFailed, isTrue);
      expect(p.balance, 880, reason: 'no balance is invented; the heartbeat catches up');
      expect(rig.wallet.synced.length, 1, reason: 'only the bet confirmation');
      expect(rig.server.resultCalls.length, 6, reason: 'the whole budget, no more');
      expect(p.lastOutcome?.payout, 0);
      await rig.world.runUntil(w + 3.0);
      expect(p.popup, isNull);
      await rig.world.runUntil(w + 4.2);
      expect(p.stage, LuckyCardStage.none);
      expect(p.isBoardEmpty, isTrue);
      expect(p.canRebet, isTrue, reason: 'the stake really was taken: the round happened');
      await rig.finish();
    });

    testWidgets('the answers are retried through failures (offline blips) and the bet is then confirmed', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryCard();
      rig.server.resultsOffline = true;
      await rig.world.runUntil(92.0);
      rig.server.resultsOffline = false;
      final w = await landWheelAt(rig, 95.0);
      await rig.world.run(const Duration(milliseconds: 600));
      expect(rig.provider.balance, 1280);
      expect(rig.provider.balanceSyncFailed, isFalse);
      await rig.world.runUntil(w + 4.2);
      expect(rig.provider.stage, LuckyCardStage.none);
      await rig.finish();
    });
  });

  group('the wheel signal', () {
    testWidgets('a wheel that never reports is waited for 7 s, then the sequence carries on', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryCard();
      final p = rig.provider;
      await rig.world.runUntil(96.5);
      expect(p.cardRevealed, isFalse);
      expect(p.stage, LuckyCardStage.spinning);
      await rig.world.runUntil(98.4);
      expect(p.cardRevealed, isTrue, reason: 'about 7 s after the spin began (90 to 91)');
      expect(p.balance, 1280);
      await rig.world.runUntil(103 - 0.5);
      expect(p.stage, LuckyCardStage.none, reason: 'ended before the next round');
      await rig.finish();
    });

    testWidgets('a landing with no sequence running, or a second landing, is ignored', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      final p = rig.provider;
      p.wheelLanded();
      p.wheelLanded();
      expect(p.stage, LuckyCardStage.none);
      final w = await landWheelAt(rig, 95.0);
      p.wheelLanded();
      p.wheelLanded();
      await rig.world.run(const Duration(milliseconds: 100));
      expect(p.stage, LuckyCardStage.revealing);
      await rig.world.runUntil(w + 4.2);
      expect(p.stage, LuckyCardStage.none);
      p.wheelLanded();
      expect(p.stage, LuckyCardStage.none);
      await rig.finish();
    });

    testWidgets('a second result handed over while one is running is ignored', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      final p = rig.provider;
      await rig.world.runUntil(91.2);
      final target = p.spinTarget!;
      rig.sync.onResult!(LuckyCardRoundResult(
        roundId: 'round-other',
        roundNumber: 1,
        winningCard: LuckyCard.all.first,
        bonusMultiplier: 9,
        scheduledAt: DateTime.utc(2026),
        isCatchUpReplay: false,
      ));
      expect(p.spinTarget, same(target));
      await rig.finish();
    });
  });

  group('the board while a sequence runs', () {
    testWidgets('a late joiner: the board stays locked across the next round\'s start, unlocks when the sequence ends, no Rebet for a replay', (tester) async {
      final rig = BetRig(tester, startInto: 100);
      await rig.open();
      final p = rig.provider;
      expect(p.stage, LuckyCardStage.spinning, reason: 'the finished round is replayed from now');
      expect(p.spinTarget?.isCatchUpReplay, isTrue);

      await rig.runIntoNextCycle(1.0);
      expect(p.isSequenceRunning, isTrue);
      expect(p.isLocked, isTrue, reason: 'a new round has begun but the sequence still owns the board');
      final r = p.tapCard(LuckyCard.all.first);
      expect(r.changedAnything, isFalse);

      await rig.world.runUntil(3.0);
      final w = await landWheelAt(rig, 3.0);
      await rig.world.runUntil(w + 4.2);
      expect(p.stage, LuckyCardStage.none);
      expect(p.isLocked, isFalse, reason: 'betting is open again');
      expect(p.phase, LuckyCardPhase.betting);
      expect(p.canRebet, isFalse);
      await rig.finish();
    });
  });

  group('leaving', () {
    testWidgets('leaving while the wheel turns: nothing is applied afterwards, the hooks are gone', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryCard();
      await rig.world.runUntil(91.2);
      expect(rig.provider.stage, LuckyCardStage.spinning);
      rig.provider.leave();
      expect(rig.wallet.spinningGetter, isNull);
      expect(rig.provider.stage, LuckyCardStage.none);
      expect(rig.provider.spinTarget, isNull);

      rig.provider.wheelLanded();
      await rig.world.run(const Duration(seconds: 15));
      expect(rig.wallet.synced.length, 1, reason: 'only the bet confirmation; no late answer was applied');
      expect(rig.provider.balance, 880);
      expect(rig.provider.popup, isNull);
      expect(rig.provider.cardRevealed, isFalse);
      expect(rig.problems, isEmpty);
      await rig.finish();
    });
  });
}
