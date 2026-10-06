// Tests for lib/widgets/lucky_card/lucky_card_wheel_binding.dart: the wheel driven by
// the REAL Lucky Card provider on the simulated server and the fake clock. The
// wheel must start when the countdown reaches 00 with the server's card and bonus
// on the segments derived from the round, and ITS LANDING, five seconds later, is
// what makes the provider reveal the card and move the balance.

import 'dart:async';

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/services/lucky_card_round_sync.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel_slots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_wallet.dart';
import '../provider_rig.dart';
import '../sim_server.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

final LuckyCard winner = SimulatedLuckyCardServer.winnerOf(cycle);
final int bonus = SimulatedLuckyCardServer.bonusOf(cycle);

class Seen {
  int spinStarts = 0;
  int rankLands = 0;
  double? startedAt;
  double? rankLandedAt;
}

Widget scene(BetRig rig, Seen seen) => LuckyCardCanvas(
      grid: (context, layout) => LuckyCardWheelBinding(
        provider: rig.provider,
        layout: layout,
        onSpinStart: () {
          seen.spinStarts++;
          seen.startedAt = rig.world.cyclePosition;
        },
        onRankLanded: () {
          seen.rankLands++;
          seen.rankLandedAt = rig.world.cyclePosition;
        },
      ),
    );

/// A provider that can say whether anything is still listening to it.
class ProbeProvider extends LuckyCardProvider {
  ProbeProvider(BetRig rig)
      : super(
          api: rig.server,
          wallet: FakeWallet(1000),
          sync: LuckyCardRoundSync(api: rig.server, now: () => rig.world.deviceNow),
          now: () => rig.world.deviceNow,
        );

  bool get listenedTo => hasListeners;
}

Widget sceneOf(LuckyCardProvider provider, BetRig rig, Seen seen) => LuckyCardCanvas(
      grid: (context, layout) => LuckyCardWheelBinding(
        provider: provider,
        layout: layout,
        onSpinStart: () {
          seen.spinStarts++;
          seen.startedAt = rig.world.cyclePosition;
        },
      ),
    );

LuckyCardWheelState wheelState(WidgetTester tester) =>
    tester.state<LuckyCardWheelState>(find.byType(LuckyCardWheel));

void main() {
  setUpAll(loadLuckyCardWheelFonts);

  group("the wheel plays the server's result", () {
    testWidgets('Aisha: it starts at countdown 00, the rank rim stops at 3 s, and the suit rim stopping at 5 s is what reveals the card and moves her balance', (tester) async {
      final rig = BetRig(tester);
      final seen = Seen();
      await pumpAtSize(tester, phone, scene(rig, seen));
      await rig.open();
      rig.betTenOnEveryCard();
      final p = rig.provider;
      expect(find.byType(LuckyCardWheel), findsOneWidget);
      expect(wheelState(tester).isSpinning, isFalse);

      await rig.world.runUntil(91.4);
      expect(p.stage, LuckyCardStage.spinning);
      expect(seen.spinStarts, 1);
      expect(wheelState(tester).isSpinning, isTrue);
      final t0 = seen.startedAt!;
      expect(t0, inInclusiveRange(89.9, 91.4), reason: 'the countdown has just reached 00');

      await rig.world.runUntil(t0 + 2.7);
      expect(seen.rankLands, 0);
      await rig.world.runUntil(t0 + 3.3);
      expect(seen.rankLands, 1, reason: 'the first ding');
      expect(seen.rankLandedAt! - t0, inInclusiveRange(2.95, 3.25));
      expect(p.cardRevealed, isFalse, reason: 'only the rank rim has stopped');

      await rig.world.runUntil(t0 + 4.8);
      expect(p.cardRevealed, isFalse, reason: 'the suit rim is still turning');
      expect(p.balance, 880, reason: 'the balance does not move before the suit rim lands');
      expect(wheelState(tester).result, isNull);

      await rig.world.runUntil(t0 + 5.4);
      expect(p.cardRevealed, isTrue, reason: 'the wheel landing told the provider');
      expect(p.balance, 1280, reason: 'and the winnings arrived');
      expect(p.showCoinFx, isTrue);

      final result = wheelState(tester).result!;
      expect(result.card, winner, reason: "the wheel shows the server's card");
      expect(result.bonus, bonus);
      final stop = luckyCardWheelStopFor(winner, cycle);
      expect(wheelState(tester).restingSegments, (stop.outerIndex, stop.innerIndex), reason: 'on the segments derived from the round');

      await rig.world.runUntil(t0 + 9.6);
      expect(p.stage, LuckyCardStage.none, reason: 'the round ended at W + 4');
      expect(seen.spinStarts, 1);
      await rig.finish();
    });

    testWidgets('a player who opens the screen in the middle of the reveal (a late joiner) sees the same spin, starting at once', (tester) async {
      final rig = BetRig(tester, startInto: 98);
      final seen = Seen();
      await pumpAtSize(tester, phone, scene(rig, seen));
      await rig.open();
      await tester.pump();
      final p = rig.provider;
      expect(p.spinTarget?.isCatchUpReplay, isTrue);
      expect(seen.spinStarts, 1, reason: 'the wheel starts as soon as it is on screen');
      expect(wheelState(tester).isSpinning, isTrue);

      final t0 = rig.world.cyclePosition;
      await rig.world.run(const Duration(milliseconds: 5400));
      expect(p.cardRevealed, isTrue);
      expect(wheelState(tester).result!.card, winner);
      final stop = luckyCardWheelStopFor(winner, cycle);
      expect(wheelState(tester).restingSegments, (stop.outerIndex, stop.innerIndex), reason: 'the same segments as every other phone');
      expect(t0, greaterThan(0));
      await rig.world.run(const Duration(seconds: 6));
      await rig.finish();
    });

    testWidgets('one spin per round; the next round spins again with its own card, bonus and segments', (tester) async {
      final rig = BetRig(tester);
      final seen = Seen();
      await pumpAtSize(tester, phone, scene(rig, seen));
      await rig.open();
      await rig.world.runUntil(91.4);
      expect(seen.spinStarts, 1);
      await rig.world.run(const Duration(seconds: 8));
      expect(seen.spinStarts, 1, reason: 'the notifications of the sequence do not spin it again');

      await rig.runIntoNextCycle(91.4);
      expect(seen.spinStarts, 2);
      await rig.world.run(const Duration(milliseconds: 5400));
      final next = cycle + 1;
      final nextWinner = SimulatedLuckyCardServer.winnerOf(next);
      expect(wheelState(tester).result!.card, nextWinner);
      expect(wheelState(tester).result!.bonus, SimulatedLuckyCardServer.bonusOf(next));
      final stop = luckyCardWheelStopFor(nextWinner, next);
      expect(wheelState(tester).restingSegments, (stop.outerIndex, stop.innerIndex));
      await rig.world.run(const Duration(seconds: 6));
      await rig.finish();
    });
  });

  group('the wheel is not in charge', () {
    testWidgets('tapping the middle of the wheel does nothing, before or during the round', (tester) async {
      final rig = BetRig(tester);
      final seen = Seen();
      await pumpAtSize(tester, phone, scene(rig, seen));
      await rig.open();
      await tester.tapAt(tester.getCenter(find.byType(LuckyCardWheel)));
      await tester.pump();
      expect(seen.spinStarts, 0);
      expect(wheelState(tester).isSpinning, isFalse);
      await rig.world.runUntil(92.0);
      await tester.tapAt(tester.getCenter(find.byType(LuckyCardWheel)));
      await tester.pump();
      expect(seen.spinStarts, 1, reason: 'only the round started it');
      await rig.world.run(const Duration(seconds: 12));
      await rig.finish();
    });

    testWidgets('the wheel never spins while the provider holds no result', (tester) async {
      final rig = BetRig(tester);
      final seen = Seen();
      rig.server.resultFromSecond = 1000; // the draw never happens
      await pumpAtSize(tester, phone, scene(rig, seen));
      await rig.open();
      await rig.world.runUntil(100.0);
      expect(seen.spinStarts, 0);
      expect(wheelState(tester).isSpinning, isFalse);
      expect(wheelState(tester).result, isNull);
      await rig.finish();
    });
  });

  group('leaving', () {
    testWidgets('the player leaves mid-spin: the provider changes nothing afterwards, and nothing throws', (tester) async {
      final rig = BetRig(tester);
      final seen = Seen();
      await pumpAtSize(tester, phone, scene(rig, seen));
      await rig.open();
      rig.betTenOnEveryCard();
      await rig.world.runUntil(91.4);
      final t0 = seen.startedAt!;
      await rig.world.runUntil(t0 + 2.0);
      rig.provider.leave();
      await rig.world.runUntil(t0 + 6.0);
      expect(tester.takeException(), isNull);
      expect(rig.provider.cardRevealed, isFalse, reason: 'a wheel landing after leaving reveals nothing');
      expect(rig.provider.stage, LuckyCardStage.none);
      expect(rig.wallet.balance, 880, reason: 'no late balance');
      await rig.finish();
    });

    testWidgets('the wheel is taken off the screen: later changes in the provider leave no trace', (tester) async {
      final rig = BetRig(tester);
      final seen = Seen();
      await pumpAtSize(tester, phone, scene(rig, seen));
      await rig.open();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await rig.world.runUntil(95.0);
      expect(tester.takeException(), isNull);
      expect(seen.spinStarts, 0, reason: 'the removed wheel does not spin');
      await rig.finish();
    });

    testWidgets('a wheel put on the screen after the spin has begun starts at once, without waiting for the next notification', (tester) async {
      final rig = BetRig(tester);
      final probe = ProbeProvider(rig);
      final seen = Seen();
      await pumpAtSize(tester, phone, const SizedBox());
      unawaited(probe.attach());
      await rig.world.runUntil(91.4);
      expect(probe.stage, LuckyCardStage.spinning);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: sceneOf(probe, rig, seen))));
      await tester.pump(); // one frame, no clock time: the provider has not notified again
      expect(seen.spinStarts, 1);
      expect(wheelState(tester).isSpinning, isTrue);

      await rig.world.run(const Duration(seconds: 6));
      expect(wheelState(tester).result!.card, winner);
      probe.dispose();
      await rig.world.run(const Duration(seconds: 12));
    });

    testWidgets('the wheel stops listening to the provider when it is removed', (tester) async {
      final rig = BetRig(tester);
      final probe = ProbeProvider(rig);
      await pumpAtSize(tester, phone, sceneOf(probe, rig, Seen()));
      expect(probe.listenedTo, isTrue);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(probe.listenedTo, isFalse, reason: 'no listener left behind');
      probe.dispose();
      await rig.world.run(const Duration(seconds: 12));
    });

    testWidgets('given another provider it follows that one, and lets go of the first', (tester) async {
      final rigA = BetRig(tester);
      final rigB = BetRig(tester, startInto: 40);
      final probeA = ProbeProvider(rigA);
      final probeB = ProbeProvider(rigB);
      final seen = Seen();
      await pumpAtSize(tester, phone, sceneOf(probeA, rigA, seen));
      expect(probeA.listenedTo, isTrue);
      expect(probeB.listenedTo, isFalse);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: sceneOf(probeB, rigB, seen))));
      expect(probeA.listenedTo, isFalse, reason: 'the first provider is let go');
      expect(probeB.listenedTo, isTrue, reason: 'the second is followed');

      unawaited(probeB.attach());
      await rigB.world.runUntil(91.4);
      expect(seen.spinStarts, 1, reason: 'the new provider drives the wheel');
      expect(wheelState(tester).isSpinning, isTrue);
      await rigB.world.run(const Duration(seconds: 6));
      probeA.dispose();
      probeB.dispose();
      await rigB.world.run(const Duration(seconds: 12));
    });
  });
}
