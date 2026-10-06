// Tests for lib/widgets/lucky_card/lucky_card_reveal_binding.dart: the whole reveal
// (the wheel, the big flipping card, the coins and the win popup) driven by the REAL
// Lucky Card provider on the simulated server and the fake clock. Aisha wins, a
// loser and a spectator watch, a late joiner arrives, and rounds follow each other.

import 'dart:async';

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/services/lucky_card_round_sync.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_reveal_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_reveal_card.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_reveal_plan.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_win_popup.dart';
import 'package:best_smart_game/widgets/overlays/coin_fountain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_wallet.dart';
import '../provider_rig.dart';
import '../sim_server.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

final LuckyCard winner = SimulatedLuckyCardServer.winnerOf(cycle);
final int bonus = SimulatedLuckyCardServer.bonusOf(cycle);

class Hooks {
  int spinStarts = 0;
  int flips = 0;
  int revealed = 0;
  int coins = 0;
  int popups = 0;
  double? startedAt;
}

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

Widget scene(
  BetRig rig,
  Hooks h, {
  LuckyCardProvider? provider,
  LuckyCardArt art = const FileLuckyCardArt(),
  bool wheel = true,
  bool column = true,
  bool overlay = true,
}) {
  final p = provider ?? rig.provider;
  return LuckyCardCanvas(
    grid: wheel
        ? (context, layout) => LuckyCardWheelBinding(
              provider: p,
              layout: layout,
              onSpinStart: () {
                h.spinStarts++;
                h.startedAt = rig.world.cyclePosition;
              },
            )
        : null,
    rankColumn: column
        ? (context, layout) => LuckyCardRevealColumn(
              provider: p,
              layout: layout,
              art: art,
              onFlip: () => h.flips++,
              onCardRevealed: () => h.revealed++,
            )
        : null,
    overlay: overlay
        ? (context, layout) => LuckyCardRevealOverlay(
              provider: p,
              layout: layout,
              art: art,
              onCoinsStart: () => h.coins++,
              onPopupOpen: () => h.popups++,
            )
        : null,
  );
}

LuckyCardRevealCardState cardState(WidgetTester tester) =>
    tester.state<LuckyCardRevealCardState>(find.byType(LuckyCardRevealCard));

Finder get coinsFinder => find.byType(CoinFountain);
Finder get popupFinder => find.byType(LuckyCardWinPopup);

void main() {
  setUpAll(loadLuckyCardWheelFonts);

  group('Aisha wins', () {
    testWidgets('the shuffle, the settling at the landing, the coins from the wheel centre, then the popup, then the end', (tester) async {
      final rig = BetRig(tester);
      final h = Hooks();
      await pumpAtSize(tester, phone, scene(rig, h));
      await rig.open();
      rig.betTenOnEveryCard();
      final p = rig.provider;

      await rig.world.runUntil(91.4);
      final t0 = h.startedAt!;
      expect(h.spinStarts, 1);
      expect(cardState(tester).isShuffling, isTrue, reason: 'the big card starts with the wheel');

      await rig.world.runUntil(t0 + 1.0);
      expect(cardState(tester).shownCard, isNotNull, reason: 'a face is showing');
      expect(h.flips, greaterThanOrEqualTo(3));

      await rig.world.runUntil(t0 + 4.8);
      expect(cardState(tester).isSettled, isFalse, reason: 'the suit rim has not landed');
      expect(cardState(tester).shownCard, isNot(winner), reason: 'the winner is not shown early');
      expect(h.revealed, 0);
      expect(h.coins, 0);
      expect(coinsFinder, findsNothing);
      expect(popupFinder, findsNothing);
      expect(p.cardRevealed, isFalse);

      await rig.world.runUntil(t0 + 5.8);
      expect(p.cardRevealed, isTrue);
      expect(cardState(tester).isSettled, isTrue);
      expect(cardState(tester).shownCard, winner, reason: 'the column settles on the winner');
      expect(h.revealed, 1);

      // The coins burst from the wheel's centre.
      expect(coinsFinder, findsOneWidget);
      expect(h.coins, 1);
      final layout = LuckyCardLayout.of(phone);
      final centre = layout.wheelCenter + layout.canvasRect.topLeft;
      final origin = tester.widget<CoinFountain>(coinsFinder).originFraction;
      expect(origin.dx, closeTo(centre.dx / phone.width, 1e-6));
      expect(origin.dy, closeTo(centre.dy / phone.height, 1e-6));
      final fountain = tester.widget<CoinFountain>(coinsFinder);
      expect(fountain.coinsPerSecond, 60, reason: 'as in Triple Chance');
      expect(fountain.autoPlay, isTrue);
      expect(fountain.duration, const Duration(milliseconds: 1500), reason: 'the 1.5 s of spec section 6, the widget default');
      expect(popupFinder, findsNothing, reason: 'the popup waits for the coins');

      await rig.world.runUntil(t0 + 6.9);
      expect(coinsFinder, findsNothing, reason: 'the coins are over');
      expect(popupFinder, findsOneWidget);
      expect(h.popups, 1);
      expect(tester.widget<Text>(find.byKey(const ValueKey('win-amount'))).data, '400');
      expect(tester.widget<Text>(find.byKey(const ValueKey('win-bonus'))).data, '${bonus}X');
      expect(find.byKey(ValueKey('win-card-${winner.key}')), findsOneWidget);

      await rig.world.runUntil(t0 + 8.5);
      expect(popupFinder, findsOneWidget, reason: 'still showing');

      await rig.world.runUntil(t0 + 9.6);
      expect(popupFinder, findsNothing, reason: 'closed at W + 4');
      expect(p.stage, LuckyCardStage.none);
      expect(cardState(tester).shownCard, winner, reason: 'the column keeps the winner');
      expect(h.coins, 1);
      expect(h.popups, 1);
      expect(h.revealed, 1);
      expect(h.flips, 12, reason: '11 random faces and the final turn to the winner, each announced once');
      await rig.finish();
    });

    testWidgets('on a tablet, where the canvas is smaller than the screen, the coins still burst from the wheel centre', (tester) async {
      const tablet = Size(1024, 768);
      final rig = BetRig(tester);
      final h = Hooks();
      await pumpAtSize(tester, tablet, scene(rig, h));
      await rig.open();
      rig.betTenOnEveryCard();
      await rig.world.runUntil(91.4);
      await rig.world.runUntil(h.startedAt! + 5.8);
      expect(coinsFinder, findsOneWidget);
      final layout = LuckyCardLayout.of(tablet);
      expect(layout.canvasRect.top, greaterThan(0), reason: 'the canvas is offset on this screen');
      final centre = layout.wheelCenter + layout.canvasRect.topLeft;
      final origin = tester.widget<CoinFountain>(coinsFinder).originFraction;
      expect(origin.dx, closeTo(centre.dx / tablet.width, 1e-6));
      expect(origin.dy, closeTo(centre.dy / tablet.height, 1e-6));
      await rig.world.run(const Duration(seconds: 8));
      await rig.finish();
    });
  });

  group('a loser and a spectator watch', () {
    Future<void> watch(WidgetTester tester, {required bool bet}) async {
      final rig = BetRig(tester);
      final h = Hooks();
      await pumpAtSize(tester, phone, scene(rig, h));
      await rig.open();
      if (bet) {
        rig.provider.selectChip(LuckyCardChip.ten);
        rig.provider.tapCard(LuckyCard.all.first); // not the winner
      }
      await rig.world.runUntil(91.4);
      final t0 = h.startedAt!;
      var sawCoins = false;
      var sawPopup = false;
      while (rig.world.cyclePosition < t0 + 10.0) {
        await rig.world.run(const Duration(milliseconds: 100));
        sawCoins = sawCoins || coinsFinder.evaluate().isNotEmpty;
        sawPopup = sawPopup || popupFinder.evaluate().isNotEmpty;
      }
      expect(sawCoins, isFalse, reason: 'no coins for ${bet ? 'a loser' : 'a spectator'}');
      expect(sawPopup, isFalse, reason: 'no popup');
      expect(h.coins, 0);
      expect(h.popups, 0);
      expect(h.revealed, 1, reason: 'but the card is revealed to everyone');
      expect(cardState(tester).shownCard, winner);
      await rig.finish();
    }

    testWidgets('a loser sees the wheel and the winning card but no coins and no popup', (tester) => watch(tester, bet: true));
    testWidgets('a spectator the same', (tester) => watch(tester, bet: false));
  });

  group('a screen that opens at other moments', () {
    testWidgets('a late joiner: the big card shuffles at once and settles with the wheel', (tester) async {
      final rig = BetRig(tester, startInto: 98);
      final h = Hooks();
      await pumpAtSize(tester, phone, scene(rig, h));
      await rig.open();
      await tester.pump();
      expect(cardState(tester).isShuffling, isTrue);
      expect(h.spinStarts, 1);
      await rig.world.run(const Duration(milliseconds: 5800));
      expect(rig.provider.cardRevealed, isTrue);
      expect(cardState(tester).isSettled, isTrue);
      expect(cardState(tester).shownCard, winner);
      expect(h.revealed, 1);
      await rig.world.run(const Duration(seconds: 6));
      await rig.finish();
    });

    testWidgets('a screen that opens after the reveal shows the winner at once, with no shuffle', (tester) async {
      final rig = BetRig(tester);
      final h = Hooks();
      await pumpAtSize(tester, phone, const SizedBox()); // nothing on screen yet
      await rig.open();
      await rig.world.runUntil(98.8); // no wheel is mounted, so the provider reveals at its 7 s ceiling
      expect(rig.provider.cardRevealed, isTrue);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: scene(rig, h, wheel: false, overlay: false))));
      await tester.pump();
      expect(cardState(tester).isSettled, isTrue);
      expect(cardState(tester).shownCard, winner);
      expect(h.flips, 0, reason: 'no shuffle');
      expect(h.revealed, 1);
      expect(cardState(tester).popScale, 1.0);
      await rig.world.run(const Duration(seconds: 6));
      await rig.finish();
    });

    testWidgets('a column put on the screen after the shuffle began joins it at once', (tester) async {
      final rig = BetRig(tester);
      final h = Hooks();
      await pumpAtSize(tester, phone, const SizedBox());
      await rig.open();
      await rig.world.runUntil(92.0);
      expect(rig.provider.stage, LuckyCardStage.spinning);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: scene(rig, h, wheel: false, overlay: false))));
      await tester.pump(); // one frame, no clock time: no new notification
      expect(cardState(tester).isShuffling, isTrue);
      await rig.world.run(const Duration(seconds: 8));
      await rig.finish();
    });
  });

  group('round after round', () {
    testWidgets('the next round shuffles again with its own order and settles on its own winner', (tester) async {
      final rig = BetRig(tester);
      final h = Hooks();
      await pumpAtSize(tester, phone, scene(rig, h));
      await rig.open();
      await rig.world.runUntil(91.4);
      await rig.world.run(const Duration(seconds: 7));
      expect(h.revealed, 1);
      expect(cardState(tester).shownCard, winner);

      await rig.runIntoNextCycle(92.0);
      expect(cardState(tester).isSettled, isFalse, reason: 'starts over');
      expect(cardState(tester).isShuffling, isTrue);
      await rig.world.run(const Duration(seconds: 6));
      final next = cycle + 1;
      final nextWinner = SimulatedLuckyCardServer.winnerOf(next);
      expect(cardState(tester).shownCard, nextWinner);
      expect(h.revealed, 2);
      expect(
        luckyCardRevealPlan(winner: nextWinner, roundNumber: next).steps.map((s) => s.face).toList(),
        isNot(luckyCardRevealPlan(winner: winner, roundNumber: cycle).steps.map((s) => s.face).toList()),
      );
      await rig.world.run(const Duration(seconds: 6));
      await rig.finish();
    });
  });

  group('leaving', () {
    testWidgets('the player leaves mid-shuffle: the card never settles, no coins, no popup, nothing throws', (tester) async {
      final rig = BetRig(tester);
      final h = Hooks();
      await pumpAtSize(tester, phone, scene(rig, h));
      await rig.open();
      rig.betTenOnEveryCard();
      await rig.world.runUntil(91.4);
      final t0 = h.startedAt!;
      await rig.world.runUntil(t0 + 2.0);
      rig.provider.leave();
      await rig.world.runUntil(t0 + 9.0);
      expect(tester.takeException(), isNull);
      expect(cardState(tester).isSettled, isFalse);
      expect(h.revealed, 0);
      expect(h.coins, 0);
      expect(h.popups, 0);
      expect(coinsFinder, findsNothing);
      expect(popupFinder, findsNothing);
      await rig.finish();
    });

    testWidgets('both bindings stop listening to the provider when they are removed', (tester) async {
      final rig = BetRig(tester);
      final probe = ProbeProvider(rig);
      await pumpAtSize(tester, phone, scene(rig, Hooks(), provider: probe, wheel: false));
      expect(probe.listenedTo, isTrue);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(probe.listenedTo, isFalse, reason: 'no listener left behind');
      probe.dispose();
      await rig.world.run(const Duration(seconds: 12));
    });

    testWidgets('given another provider they follow that one and let go of the first', (tester) async {
      final rigA = BetRig(tester);
      final rigB = BetRig(tester, startInto: 40);
      final probeA = ProbeProvider(rigA);
      final probeB = ProbeProvider(rigB);
      final h = Hooks();
      await pumpAtSize(tester, phone, scene(rigA, h, provider: probeA, wheel: false));
      expect(probeA.listenedTo, isTrue);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: scene(rigB, h, provider: probeB, wheel: false))));
      expect(probeA.listenedTo, isFalse);
      expect(probeB.listenedTo, isTrue);

      unawaited(probeB.attach());
      await rigB.world.runUntil(92.0);
      expect(cardState(tester).isShuffling, isTrue, reason: 'the new provider drives the card');
      await rigB.world.run(const Duration(seconds: 9));
      probeA.dispose();
      probeB.dispose();
      await rigB.world.run(const Duration(seconds: 12));
    });
  });

  group('pictures to look at, with the real artwork and fonts', () {
    Future<void> shot(WidgetTester tester, String name) =>
        expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

    testWidgets('Aisha wins: the wheel landed, the winner alone in the column, the popup open (915x412)', (tester) async {
      const size = Size(915, 412);
      final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
      final rig = BetRig(tester);
      final h = Hooks();
      await pumpAtSize(tester, size, scene(rig, h, art: art));
      await rig.open();
      rig.betTenOnEveryCard();
      await rig.world.runUntil(91.4);
      await rig.world.runUntil(h.startedAt! + 7.2);
      expect(popupFinder, findsOneWidget);
      await shot(tester, 'reveal_scene_win_915x412');
      await rig.world.run(const Duration(seconds: 6));
      await rig.finish();
    });

    testWidgets('a loser watches: the wheel landed and the winner alone in the column, no popup (915x412)', (tester) async {
      const size = Size(915, 412);
      final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
      final rig = BetRig(tester);
      final h = Hooks();
      await pumpAtSize(tester, size, scene(rig, h, art: art));
      await rig.open();
      await rig.world.runUntil(91.4);
      await rig.world.runUntil(h.startedAt! + 7.2);
      expect(popupFinder, findsNothing);
      await shot(tester, 'reveal_scene_watch_915x412');
      await rig.world.run(const Duration(seconds: 6));
      await rig.finish();
    });
  });
}
