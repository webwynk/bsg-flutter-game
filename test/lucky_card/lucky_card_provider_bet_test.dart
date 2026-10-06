// Tests for lib/providers/lucky_card_provider.dart, part 1 (App Step 3b-1): the
// board as the player uses it, the lock at countdown 5, and sending the bet.
//
// Whole rounds are played on a fake clock against the simulated server and a
// fake wallet, so each test takes a fraction of a second.

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_rig.dart';

void main() {
  group('the board moves the coins in the wallet', () {
    testWidgets('placing, removing, doubling and clearing change the balance by exactly what the board says', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      final p = rig.provider;

      p.selectChip(LuckyCardChip.ten);
      final r1 = p.tapSuit(LuckyCardSuit.hearts);
      expect(r1.coinsSpent, 30);
      expect(rig.wallet.balance, 970);
      expect(p.total, 30);
      expect(p.suitTotal(LuckyCardSuit.hearts), 30);

      p.selectChip(LuckyCardChip.five);
      p.tapRank(LuckyCardRank.jack);
      expect(rig.wallet.balance, 950);
      expect(p.stakeOn(LuckyCard.fromKey('j_hearts')), 15);
      expect(p.rankTotal(LuckyCardRank.jack), 30);

      p.removeLast();
      expect(rig.wallet.balance, 955);

      final dbl = p.doubleBet();
      expect(dbl.coinsSpent, p.total ~/ 2);
      expect(rig.wallet.balance + p.total, 1000);

      p.clearBoard();
      expect(rig.wallet.balance, 1000);
      expect(p.isBoardEmpty, isTrue);
      await rig.finish();
    });

    testWidgets('a refused action moves no coins and says why', (tester) async {
      final rig = BetRig(tester, startBalance: 100);
      await rig.open();
      rig.provider.selectChip(LuckyCardChip.fiveHundred);
      final r = rig.provider.tapCard(LuckyCard.all.first);
      expect(r.issues, {LuckyCardBoardIssue.notEnoughCoins});
      expect(rig.wallet.balance, 100);
      expect(rig.wallet.localSets, isEmpty);
      await rig.finish();
    });

    testWidgets('with no chip held, tapping a card takes the latest chip back', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      final jh = LuckyCard.fromKey('j_hearts');
      rig.provider.selectChip(LuckyCardChip.fifty);
      rig.provider.tapCard(jh);
      rig.provider.deselectChip();
      expect(rig.provider.activeChip, isNull);
      final r = rig.provider.tapCard(jh);
      expect(r.coinsSpent, -50);
      expect(rig.wallet.balance, 1000);
      await rig.finish();
    });

    testWidgets('chips cannot be placed once the board is locked', (tester) async {
      final rig = BetRig(tester, startInto: 84);
      await rig.open();
      await rig.world.run(const Duration(seconds: 3));
      expect(rig.provider.isLocked, isTrue);
      expect(rig.provider.phase, LuckyCardPhase.locked);
      final r = rig.provider.tapCard(LuckyCard.all.first);
      expect(r.issues, {LuckyCardBoardIssue.locked});
      expect(rig.wallet.balance, 1000);
      await rig.finish();
    });
  });

  group('the wallet hooks', () {
    testWidgets('unsent chips are reported, then not once the bet is on its way, and removed on leaving', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      expect(rig.wallet.uncommittedGetter, isNotNull);
      expect(rig.wallet.uncommittedGetter!(), 0);
      rig.betTenOnEveryCard();
      expect(rig.wallet.uncommittedGetter!(), 120, reason: 'chips on the board have not reached the database');
      await rig.world.runUntil(88.5);
      expect(rig.provider.isBetSubmitted, isTrue);
      expect(rig.wallet.uncommittedGetter!(), 0, reason: 'the bet has been sent: do not subtract it twice');
      rig.provider.leave();
      expect(rig.wallet.uncommittedGetter, isNull);
      expect(rig.wallet.spinningGetter, isNull);
      await rig.finish();
    });
  });

  group('a whole round', () {
    testWidgets('Aisha: 120 staked, locked and sent once at countdown 5, balance confirmed by the server', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryCard();
      expect(rig.wallet.balance, 880);

      await rig.world.runUntil(88.5);
      expect(rig.server.betsReceived, 1, reason: 'exactly one bet');
      final sent = rig.server.betLog.single;
      expect(sent.roundId, 'round-$cycle');
      expect(sent.bets.length, 12);
      expect(sent.bets.values.every((v) => v == 10), isTrue);
      final arrivedAt = (sent.arrived.millisecondsSinceEpoch / 1000 + 0.5) % 103;
      expect(arrivedAt, inInclusiveRange(84.0, 86.6), reason: 'sent when the countdown reached 5');

      expect(rig.provider.betStatus, LuckyCardBetStatus.submitted);
      expect(rig.provider.submittedRoundId, 'round-$cycle');
      expect(rig.provider.isLocked, isTrue);
      expect(rig.provider.phase, LuckyCardPhase.locked);
      expect(rig.wallet.synced.single.balance, 880);
      expect(rig.wallet.balance, 880);
      expect(rig.server.serverBalance, 880);
      expect(rig.server.stakedOn('round-$cycle'), 120);
      expect(rig.problems, isEmpty);
      await rig.finish();
    });

    testWidgets('a spectator sends nothing, is locked at the mark and can bet again in the next round', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      await rig.world.runUntil(88.5);
      expect(rig.server.betsReceived, 0);
      expect(rig.provider.isLocked, isTrue);
      await rig.runIntoNextCycle(2.0);
      expect(rig.provider.isLocked, isFalse);
      expect(rig.provider.phase, LuckyCardPhase.betting);
      rig.provider.selectChip(LuckyCardChip.five);
      expect(rig.provider.tapCard(LuckyCard.all.first).isClean, isTrue);
      await rig.finish();
    });

    testWidgets('a sent bet of a round that never resolves stays locked into the next round until the round is ended, then Rebet is offered', (tester) async {
      final rig = BetRig(tester);
      rig.server.resultFromSecond = 1000; // the draw never happens: no result sequence ever runs
      await rig.open();
      // The sync's give-up report (3b-2b) would drop the board at about second 98.
      // Silenced here so the lock itself is proven on its own: a sent bet keeps the
      // board locked into the next round until the round is ended.
      rig.sync.onResultUnavailable = null;
      rig.betTenOnEveryCard();
      await rig.runIntoNextCycle(2.0);
      expect(rig.provider.isLocked, isTrue, reason: 'the result sequence (3b-2) has not ended the round');
      expect(rig.provider.isBetSubmitted, isTrue);

      rig.provider.endRound(saveForRebet: true);
      expect(rig.provider.isBoardEmpty, isTrue);
      expect(rig.provider.isBetSubmitted, isFalse);
      expect(rig.provider.betStatus, LuckyCardBetStatus.idle);
      expect(rig.provider.isLocked, isFalse, reason: 'the countdown allows betting again');
      expect(rig.provider.canRebet, isTrue);
      expect(rig.provider.canAffordRebet, isTrue);
      final r = rig.provider.rebet();
      expect(r.coinsSpent, 120);
      expect(rig.wallet.balance, 760);
      await rig.finish();
    });
  });

  group('the bet is sent at most once', () {
    testWidgets('a catch-up after the bet was sent does not send it again', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryCard();
      await rig.world.runUntil(87.0);
      expect(rig.server.betsReceived, 1);
      rig.provider.catchUpMissedSubmissionIfNeeded();
      await rig.world.run(const Duration(seconds: 2));
      expect(rig.server.betsReceived, 1);
      await rig.finish();
    });

    testWidgets('coming back after the timer was frozen through the lock mark sends the bet now', (tester) async {
      // Ticks never run (an hour apart), so the lock mark is never seen: the
      // situation of a phone that was asleep through second 85.
      final rig = BetRig(tester, tickInterval: const Duration(hours: 1));
      await rig.open();
      rig.betTenOnEveryCard();
      await rig.world.runUntil(86.0);
      expect(rig.server.betsReceived, 0, reason: 'the mark was missed');
      rig.provider.catchUpMissedSubmissionIfNeeded();
      await rig.world.run(const Duration(seconds: 1));
      expect(rig.server.betsReceived, 1);
      expect(rig.provider.betStatus, LuckyCardBetStatus.submitted);
      rig.provider.catchUpMissedSubmissionIfNeeded();
      await rig.world.run(const Duration(seconds: 1));
      expect(rig.server.betsReceived, 1);
      await rig.finish();
    });

    testWidgets('a catch-up while betting is still open does nothing', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryCard();
      rig.provider.catchUpMissedSubmissionIfNeeded();
      await rig.world.run(const Duration(seconds: 2));
      expect(rig.server.betsReceived, 0);
      expect(rig.provider.isLocked, isFalse);
      await rig.finish();
    });

    testWidgets('a board left over from a round that never resolved is dropped, not sent again, and not refunded', (tester) async {
      final rig = BetRig(tester);
      rig.server.resultFromSecond = 1000; // the draw never happens: nothing cleans the board up
      await rig.open();
      // Silenced so the second lock at the next lock mark is proven on its own,
      // independently of the give-up report that would already have dropped the board.
      rig.sync.onResultUnavailable = null;
      rig.betTenOnEveryCard();
      await rig.world.runUntil(88.5);
      expect(rig.server.betsReceived, 1);
      // The round ends, but nothing cleans the board up (the round never resolved).
      await rig.runIntoNextCycle(87.0);
      expect(rig.server.betsReceived, 1, reason: 'the old board must not be sent for the new round');
      expect(rig.provider.isBoardEmpty, isTrue);
      expect(rig.wallet.balance, 880, reason: 'no refund: that stake was really taken');
      expect(rig.problems, isEmpty);
      await rig.finish();
    });
  });

  group('when the server refuses the bet', () {
    Future<void> placeAndWaitForTheMark(BetRig rig) async {
      await rig.open();
      rig.betTenOnEveryCard();
      expect(rig.wallet.balance, 880);
      await rig.world.runUntil(95.0);
    }

    void expectChipsReturned(BetRig rig) {
      expect(rig.wallet.balance, 1000, reason: 'the chips are returned on screen');
      expect(rig.provider.isBoardEmpty, isTrue);
      expect(rig.provider.betStatus, LuckyCardBetStatus.failed);
      expect(rig.provider.isBetSubmitted, isFalse);
      expect(rig.provider.canRebet, isFalse);
    }

    testWidgets('too late (it reaches the server after the cutoff): returned, "round closed", not retried', (tester) async {
      final rig = BetRig(tester);
      rig.server.uplink = const Duration(milliseconds: 3500);
      await placeAndWaitForTheMark(rig);
      expect(rig.server.betsReceived, 1, reason: 'a final answer is not retried');
      expect(rig.problems.length, 1);
      expect(rig.problems.single.kind, LuckyCardProblemKind.betRejected);
      expect(rig.problems.single.reason, LuckyCardError.roundClosed);
      expectChipsReturned(rig);
      expect(rig.server.serverBalance, 1000, reason: 'nothing was charged');
      await rig.finish();
    });

    testWidgets('not enough coins on the server: returned, "insufficient coins"', (tester) async {
      final rig = BetRig(tester);
      rig.server.serverBalance = 50;
      await placeAndWaitForTheMark(rig);
      expect(rig.server.betsReceived, 1);
      expect(rig.problems.single.kind, LuckyCardProblemKind.betRejected);
      expect(rig.problems.single.reason, LuckyCardError.insufficientCoins);
      expectChipsReturned(rig);
      await rig.finish();
    });

    testWidgets('a staff account: returned, "not a player", not retried', (tester) async {
      final rig = BetRig(tester);
      rig.server.failBetsNext(5, error: LuckyCardError.notAPlayer);
      await placeAndWaitForTheMark(rig);
      expect(rig.server.betsReceived, 0, reason: 'the simulated failure stops it before the account');
      expect(rig.problems.single.kind, LuckyCardProblemKind.betRejected);
      expect(rig.problems.single.reason, LuckyCardError.notAPlayer);
      expectChipsReturned(rig);
      await rig.finish();
    });

    testWidgets('a blocked account: returned, a connection problem, not retried', (tester) async {
      final rig = BetRig(tester);
      rig.server.failBetsNext(5, error: LuckyCardError.accountBlocked);
      await placeAndWaitForTheMark(rig);
      expect(rig.problems.single.kind, LuckyCardProblemKind.connectionProblem);
      expect(rig.problems.single.reason, LuckyCardError.accountBlocked);
      expectChipsReturned(rig);
      await rig.finish();
    });

    testWidgets('a passing glitch is retried and the bet goes through, with no problem shown', (tester) async {
      final rig = BetRig(tester);
      rig.server.failBetsNext(2);
      await placeAndWaitForTheMark(rig);
      expect(rig.server.betsReceived, 1);
      expect(rig.provider.betStatus, LuckyCardBetStatus.submitted);
      expect(rig.problems, isEmpty);
      expect(rig.wallet.balance, 880);
      await rig.finish();
    });

    testWidgets('offline three times: returned, a connection problem', (tester) async {
      final rig = BetRig(tester);
      rig.server.betsOffline = true;
      await placeAndWaitForTheMark(rig);
      expect(rig.problems.single.kind, LuckyCardProblemKind.connectionProblem);
      expect(rig.problems.single.reason, LuckyCardError.offline);
      expectChipsReturned(rig);
      await rig.finish();
    });

    testWidgets('a sign-in that stays broken: returned, a connection problem', (tester) async {
      final rig = BetRig(tester);
      rig.server.failBetsNext(3, error: LuckyCardError.unauthenticated);
      await placeAndWaitForTheMark(rig);
      expect(rig.problems.single.kind, LuckyCardProblemKind.connectionProblem);
      expect(rig.problems.single.reason, LuckyCardError.unauthenticated);
      expectChipsReturned(rig);
      await rig.finish();
    });

    testWidgets('an unknown fault that stays: returned, a rejected bet (the player stays in the game)', (tester) async {
      final rig = BetRig(tester);
      rig.server.failBetsNext(3, error: LuckyCardError.unknown);
      await placeAndWaitForTheMark(rig);
      expect(rig.problems.single.kind, LuckyCardProblemKind.betRejected);
      expect(rig.problems.single.reason, LuckyCardError.unknown);
      expectChipsReturned(rig);
      await rig.finish();
    });

    testWidgets('no round could be read at the mark: returned, a connection problem, nothing sent', (tester) async {
      final rig = BetRig(tester);
      rig.server.offline = true; // the screen opens while offline: no round is ever known
      final attached = rig.provider.attach();
      await rig.world.run(const Duration(seconds: 2));
      await attached;
      rig.betTenOnEveryCard();
      await rig.world.runUntil(95.0);
      expect(rig.server.betsReceived, 0);
      expect(rig.problems.single.kind, LuckyCardProblemKind.connectionProblem);
      expect(rig.problems.single.reason, LuckyCardError.offline);
      expectChipsReturned(rig);
      await rig.finish();
    });

    testWidgets('a rejected bet forgets the saved Rebet bet, and chips can be placed again afterwards', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryCard();
      await rig.world.runUntil(95.0);
      rig.provider.endRound(saveForRebet: true);
      expect(rig.provider.canRebet, isTrue);
      await rig.runIntoNextCycle(3.0);
      rig.server.uplink = const Duration(milliseconds: 3500);
      rig.provider.selectChip(LuckyCardChip.ten);
      rig.provider.tapCard(LuckyCard.all.first);
      await rig.world.runUntil(95.0);
      expect(rig.problems.length, 1);
      expect(rig.provider.canRebet, isFalse, reason: 'a refused bet clears the saved bet, as in Triple Chance');
      rig.server.uplink = Duration.zero;
      await rig.runIntoNextCycle(3.0);
      rig.provider.selectChip(LuckyCardChip.five);
      expect(rig.provider.tapCard(LuckyCard.all.first).isClean, isTrue);
      expect(rig.provider.betStatus, LuckyCardBetStatus.idle);
      await rig.finish();
    });
  });

  group('leaving the screen', () {
    testWidgets('chips never sent are returned on screen, and everything stops', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryCard();
      expect(rig.wallet.balance, 880);
      rig.provider.leave();
      expect(rig.wallet.balance, 1000);
      expect(rig.provider.isBoardEmpty, isTrue);
      expect(rig.sync.isWatching, isFalse);
      final polls = rig.server.polls;
      await rig.world.run(const Duration(seconds: 60));
      expect(rig.server.polls, polls);
      expect(rig.server.betsReceived, 0);
      await rig.finish();
    });

    testWidgets('a bet already sent is left to settle: no refund, the board is cleared', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryCard();
      await rig.world.runUntil(88.5);
      rig.provider.leave();
      expect(rig.wallet.balance, 880);
      expect(rig.provider.isBoardEmpty, isTrue);
      await rig.finish();
    });

    testWidgets('leaving while the bet is on its way changes nothing afterwards and shows no problem', (tester) async {
      final rig = BetRig(tester);
      rig.server.uplink = const Duration(seconds: 2);
      await rig.open();
      rig.betTenOnEveryCard();
      await rig.world.runUntil(86.5);
      expect(rig.provider.betStatus, LuckyCardBetStatus.submitting);
      rig.provider.leave();
      final balance = rig.wallet.balance;
      await rig.world.run(const Duration(seconds: 15));
      expect(rig.problems, isEmpty);
      expect(rig.wallet.balance, balance);
      expect(rig.wallet.synced, isEmpty, reason: 'a stale answer must not touch the wallet at all');
      expect(rig.server.betsReceived, 1, reason: 'the bet was on its way and nothing resends it');
      await rig.finish();
    });

    testWidgets('leaving twice is harmless', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      rig.betTenOnEveryCard();
      rig.provider.leave();
      rig.provider.leave();
      expect(rig.wallet.balance, 1000);
      await rig.finish();
    });
  });
}
