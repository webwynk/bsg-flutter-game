// The lost-reply "bet not placed" problem (docs/loadtest/BET_NOT_PLACED_PLAN_2026-11-09.md).
//
// On a weak network the bet sent at countdown 5 reaches the server and is ACCEPTED, but its reply
// is lost; the app retries a second apart, and the try that arrives at second 88 or later is
// refused with "round closed". Phase 2 (2026-11-09) recorded what the app did then: it believed
// that last answer, gave the stake back on screen, said the bet was rejected, never asked for the
// result and showed no win. Phase 3 (the fix, option A): after such a failure the app asks the
// server once whether the round holds the bet, and these tests check the three answers.

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_rig.dart';

/// A weak network: every call takes 0.3 s up and 0.3 s back, so the 3rd try of a bet sent at
/// countdown 5 reaches the server at about second 89.
BetRig weakNetworkRig(WidgetTester tester) {
  final rig = BetRig(tester, latency: const Duration(milliseconds: 300));
  rig.server.uplink = const Duration(milliseconds: 300);
  return rig;
}

double positionOf(DateTime t) => (t.millisecondsSinceEpoch / 1000 + 0.5) % 103;

void main() {
  testWidgets('the first send is accepted but its reply is lost, the late retry gets "round closed": '
      'the app asks the server, finds the bet, and keeps it as placed (before the fix: refunded and "rejected")',
      (tester) async {
    final rig = weakNetworkRig(tester);
    await rig.open();
    rig.betTenOnEveryCard();
    expect(rig.wallet.balance, 880);
    rig.server.loseBetRepliesNext(2); // the 1st and 2nd tries reach the server; both replies are lost

    await rig.world.runUntil(89.9);
    debugPrint('Lucky Card bet tries reached the server at: '
        '${rig.server.betLog.map((b) => positionOf(b.arrived).toStringAsFixed(2)).toList()}');
    expect(rig.server.stakedOn('round-$cycle'), 120);
    expect(positionOf(rig.server.betLog.last.arrived), greaterThanOrEqualTo(88.0),
        reason: 'the last try is the late one');

    expect(rig.problems, isEmpty, reason: 'no false "bet rejected"');
    expect(rig.wallet.balance, 880, reason: 'the stake is not shown as returned, and no win shows early');
    expect(rig.provider.betStatus, LuckyCardBetStatus.submitted);
    expect(rig.provider.isBoardEmpty, isFalse);
    expect(rig.server.resultCalls.where((c) => c.roundId == 'round-$cycle').length, 1,
        reason: 'one question to the server');
    await rig.finish();
  });

  testWidgets('after that, the result is asked for and the WIN is shown (before the fix: no win)', (tester) async {
    final rig = weakNetworkRig(tester);
    await rig.open();
    rig.betTenOnEveryCard(); // covers every card, so this bet always wins
    rig.server.loseBetRepliesNext(2);
    await rig.world.runUntil(89.9);
    expect(rig.problems, isEmpty);

    await landWheelAt(rig, 95);
    await rig.world.run(const Duration(seconds: 6));
    debugPrint('Lucky Card after the lost reply: win shown ${rig.provider.lastOutcome?.payout}, '
        'wallet ${rig.wallet.balance}, server ${rig.server.serverBalance}');
    expect(rig.provider.lastOutcome?.payout ?? 0, greaterThan(0), reason: 'the win is shown');
    expect(rig.wallet.balance, rig.server.serverBalance, reason: 'the balance matches the server');
    await rig.finish();
  });

  testWidgets('when no try reached the server, the late "round closed" is still a real refusal', (tester) async {
    final rig = weakNetworkRig(tester);
    await rig.open();
    rig.betTenOnEveryCard();
    rig.server.failBetsNext(2); // the 1st and 2nd tries never reach the account
    await rig.world.runUntil(89.9);
    expect(rig.server.stakedOn('round-$cycle'), 0);
    expect(rig.problems.single.reason, LuckyCardError.roundClosed);
    expect(rig.wallet.balance, 1000, reason: 'nothing was taken, so the stake comes back');
    expect(rig.provider.isBoardEmpty, isTrue);
    await rig.finish();
  });

  testWidgets('when the question itself fails: no refund and no message; the result check at the end shows the truth',
      (tester) async {
    final rig = weakNetworkRig(tester);
    await rig.open();
    rig.betTenOnEveryCard();
    rig.server.loseBetRepliesNext(2);
    rig.server.resultsOffline = true;
    await rig.world.runUntil(89.9);
    expect(rig.problems, isEmpty);
    expect(rig.wallet.balance, 880);
    expect(rig.provider.betStatus, LuckyCardBetStatus.submitted);

    rig.server.resultsOffline = false;
    await landWheelAt(rig, 95);
    await rig.world.run(const Duration(seconds: 6));
    expect(rig.provider.lastOutcome?.payout ?? 0, greaterThan(0));
    expect(rig.wallet.balance, rig.server.serverBalance);
    await rig.finish();
  });

  testWidgets('one lost reply and an in-time retry: fine, with no extra question', (tester) async {
    final rig = BetRig(tester);
    await rig.open();
    rig.betTenOnEveryCard();
    rig.server.loseBetRepliesNext(1);
    await rig.world.runUntil(88.5);
    expect(rig.problems, isEmpty);
    expect(rig.server.stakedOn('round-$cycle'), 120);
    expect(rig.server.serverBalance, 880, reason: 'the retry of the same board charges nothing more');
    expect(rig.wallet.balance, 880);
    expect(rig.server.resultCalls, isEmpty, reason: 'the retry succeeded, so nothing needed asking');
    await rig.finish();
  });
}
