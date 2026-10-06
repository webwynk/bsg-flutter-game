// Tests for lucky_card_controls_binding.dart: the chip rail, DOUBLE / REBET, CLEAR and
// REMOVE, and the whole side column, driven by the REAL Lucky Card provider on the
// simulated server and the fake clock. What the player taps, sees and pays must agree:
// the screen, the provider's board and the wallet.

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/services/lucky_card_round_sync.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_action_buttons.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_chip_rail.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_controls_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_readouts_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_tap_target.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel_binding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_wallet.dart';
import '../provider_rig.dart';
import '../sim_server.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

final LuckyCard winner = SimulatedLuckyCardServer.winnerOf(cycle);
final int bonus = SimulatedLuckyCardServer.bonusOf(cycle);
const LuckyCard hearts = LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts);

class Hooks {
  final List<String> events = [];
}

/// A provider that can say whether anything is still listening to it.
class ProbeProvider extends LuckyCardProvider {
  ProbeProvider(BetRig rig, {int balance = 1000})
      : super(
          api: rig.server,
          wallet: FakeWallet(balance),
          sync: LuckyCardRoundSync(api: rig.server, now: () => rig.world.deviceNow),
          now: () => rig.world.deviceNow,
        );

  bool get listenedTo => hasListeners;
}

Widget scene(
  LuckyCardProvider provider, {
  Hooks? hooks,
  LuckyCardArt art = const FileLuckyCardArt(),
  bool withTopBar = false,
}) =>
    LuckyCardCanvas(
      grid: (context, layout) => LuckyCardWheelBinding(provider: provider, layout: layout),
      topBar: withTopBar ? (context, layout) => LuckyCardTopBarBinding(provider: provider, layout: layout, soundOn: true) : null,
      status: withTopBar ? (context, layout) => LuckyCardStatusBinding(provider: provider, layout: layout) : null,
      side: (context, layout) => LuckyCardSideColumn(
        provider: provider,
        layout: layout,
        art: art,
        onChipSelected: hooks == null ? null : (chip) => hooks.events.add('chip ${chip.amount}'),
        onButtonPressed: hooks == null ? null : (c) => hooks.events.add('pressed ${c.name}'),
        onButtonRefused: hooks == null ? null : (c, issues) => hooks.events.add('refused ${c.name} ${(issues.map((e) => e.name).toList()..sort()).join('+')}'),
      ),
    );

Finder key(String k) => find.byKey(ValueKey(k));
Finder chip(LuckyCardChip c) => key('chip-${c.amount}');
Finder button(LuckyCardControl c) => key('button-${c.name}');

double faceShare(WidgetTester tester, LuckyCardChip c, Size screen) =>
    tester.getSize(key('chip-face-${c.amount}')).width / LuckyCardLayout.of(screen).chip(c.index).width;

bool isInHand(WidgetTester tester, LuckyCardChip c, Size screen) =>
    (faceShare(tester, c, screen) - LuckyCardChipRail.selectedShare).abs() < 0.01;

double opacityOf(WidgetTester tester, Finder within) {
  final found = find.descendant(of: within, matching: find.byType(Opacity));
  return found.evaluate().isEmpty ? 1.0 : tester.widget<Opacity>(found.first).opacity;
}

String labelOf(WidgetTester tester, Finder b) => tester.widget<Text>(find.descendant(of: b, matching: find.byType(Text))).data!;

/// Taps the first of the two "double or rebet" buttons that is on the screen.
Finder get slotZero => find.byWidgetPredicate((w) => w is LuckyCardActionButton && (w.control == LuckyCardControl.doubleBet || w.control == LuckyCardControl.rebet));

/// Lets the 150 ms chip animation run to its end (an animation starts counting one frame
/// after it is asked for, so one long pump is not enough).
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async {
    await loadLuckyCardWheelFonts();
    await loadLuckyCardIcons();
  });

  group('the chips', () {
    testWidgets('a tap picks a chip up, the chip in hand grows and glows, and the provider holds it', (tester) async {
      final rig = BetRig(tester);
      final hooks = Hooks();
      await pumpAtSize(tester, phone, scene(rig.provider, hooks: hooks));
      await rig.open();
      final p = rig.provider;
      await settle(tester);
      for (final c in LuckyCardChip.values) {
        expect(isInHand(tester, c, phone), p.activeChip == c, reason: '${c.amount} at the start');
      }

      for (final c in [LuckyCardChip.fifty, LuckyCardChip.fiveHundred, LuckyCardChip.five]) {
        await tester.tap(chip(c));
        await settle(tester);
        expect(p.activeChip, c);
        for (final other in LuckyCardChip.values) {
          expect(isInHand(tester, other, phone), other == c, reason: '${other.amount} after choosing ${c.amount}');
        }
      }
      expect(hooks.events, ['chip 50', 'chip 500', 'chip 5']);
      await rig.finish();
    });

    testWidgets('the chosen chip is what the next tap on the board places', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider));
      await rig.open();
      final p = rig.provider;
      await tester.tap(chip(LuckyCardChip.fifty));
      await tester.pump();
      p.tapCard(hearts);
      await tester.pump();
      expect(p.stakeOn(hearts), 50);
      expect(rig.wallet.balance, 950);
      await tester.tap(chip(LuckyCardChip.hundred));
      p.tapCard(hearts);
      await tester.pump();
      expect(p.stakeOn(hearts), 150);
      expect(rig.wallet.balance, 850);
      await rig.finish();
    });

    testWidgets('when betting closes the chips are dimmed and ignore taps; they work again next round', (tester) async {
      final rig = BetRig(tester);
      final hooks = Hooks();
      await pumpAtSize(tester, phone, scene(rig.provider, hooks: hooks));
      await rig.open();
      final p = rig.provider;
      await tester.tap(chip(LuckyCardChip.ten));
      await tester.pump();
      expect(opacityOf(tester, chip(LuckyCardChip.five)), 1.0);

      await rig.world.runUntil(86.0);
      expect(p.isLocked, isTrue);
      hooks.events.clear();
      for (final c in LuckyCardChip.values) {
        expect(opacityOf(tester, chip(c)), closeTo(0.55, 1e-9), reason: '${c.amount}');
        await tester.tap(chip(c));
      }
      await tester.pump();
      expect(p.activeChip, LuckyCardChip.ten, reason: 'no chip was picked up');
      expect(hooks.events, isEmpty, reason: 'no click for a refused tap');

      await rig.runIntoNextCycle(8);
      expect(p.isLocked, isFalse);
      for (final c in LuckyCardChip.values) {
        expect(opacityOf(tester, chip(c)), 1.0, reason: '${c.amount} open again');
      }
      await tester.tap(chip(LuckyCardChip.hundred));
      await tester.pump();
      expect(p.activeChip, LuckyCardChip.hundred);
      await rig.finish();
    });
  });

  group('DOUBLE, CLEAR and REMOVE', () {
    testWidgets('with an empty board all three are dimmed and do nothing', (tester) async {
      final rig = BetRig(tester);
      final hooks = Hooks();
      await pumpAtSize(tester, phone, scene(rig.provider, hooks: hooks));
      await rig.open();
      expect(labelOf(tester, slotZero), 'DOUBLE');
      for (final c in [LuckyCardControl.doubleBet, LuckyCardControl.clear, LuckyCardControl.remove]) {
        expect(opacityOf(tester, button(c)), closeTo(0.4, 1e-9), reason: c.name);
        await tester.tap(button(c));
      }
      await tester.pump();
      expect(hooks.events, isEmpty);
      expect(rig.provider.total, 0);
      await rig.finish();
    });

    testWidgets('the first chip lights all three; DOUBLE doubles every stake and takes the coins', (tester) async {
      final rig = BetRig(tester);
      final hooks = Hooks();
      await pumpAtSize(tester, phone, scene(rig.provider, hooks: hooks));
      await rig.open();
      final p = rig.provider;
      p.selectChip(LuckyCardChip.ten);
      p.tapSuit(LuckyCardSuit.hearts);
      p.tapCard(winner);
      await tester.pump();
      for (final c in [LuckyCardControl.doubleBet, LuckyCardControl.clear, LuckyCardControl.remove]) {
        expect(opacityOf(tester, button(c)), 1.0, reason: c.name);
      }
      final before = p.total;
      final balance = rig.wallet.balance;
      await tester.tap(button(LuckyCardControl.doubleBet));
      await tester.pump();
      expect(p.total, before * 2);
      expect(rig.wallet.balance, balance - before, reason: 'doubling costs what was already staked');
      expect(hooks.events, ['pressed doubleBet']);
      await rig.finish();
    });

    testWidgets('DOUBLE without enough coins changes nothing, flashes and reports notEnoughCoins', (tester) async {
      final rig = BetRig(tester, startBalance: 25);
      final hooks = Hooks();
      await pumpAtSize(tester, phone, scene(rig.provider, hooks: hooks));
      await rig.open();
      final p = rig.provider;
      p.selectChip(LuckyCardChip.ten);
      p.tapCard(winner);
      p.tapCard(hearts);
      await tester.pump();
      expect(rig.wallet.balance, 5);
      await tester.tap(button(LuckyCardControl.doubleBet));
      await tester.pump(const Duration(milliseconds: 20));
      expect(p.total, 20, reason: 'nothing doubled');
      expect(rig.wallet.balance, 5);
      expect(hooks.events, ['pressed doubleBet', 'refused doubleBet notEnoughCoins']);
      expect(find.descendant(of: button(LuckyCardControl.doubleBet), matching: find.byType(ColoredBox)), findsOneWidget);
      await rig.finish();
    });

    testWidgets('DOUBLE with a card at the maximum doubles the rest and reports cardAtMaximum', (tester) async {
      final rig = BetRig(tester, startBalance: 200000);
      final hooks = Hooks();
      await pumpAtSize(tester, phone, scene(rig.provider, hooks: hooks));
      await rig.open();
      final p = rig.provider;
      // 500 chip x 100 on one card = 50,000 (the maximum), plus 10 on another.
      p.selectChip(LuckyCardChip.fiveHundred);
      for (var i = 0; i < 100; i++) {
        p.tapCard(winner);
      }
      expect(p.stakeOn(winner), 50000);
      p.selectChip(LuckyCardChip.ten);
      p.tapCard(hearts);
      await tester.pump();
      await tester.tap(button(LuckyCardControl.doubleBet));
      await tester.pump();
      expect(p.stakeOn(winner), 50000, reason: 'already at the maximum');
      expect(p.stakeOn(hearts), 20, reason: 'the rest are doubled');
      expect(hooks.events, ['pressed doubleBet', 'refused doubleBet cardAtMaximum']);
      await rig.finish();
    });

    testWidgets('CLEAR gives every chip back, empties the board and dims the buttons again', (tester) async {
      final rig = BetRig(tester);
      final hooks = Hooks();
      await pumpAtSize(tester, phone, scene(rig.provider, hooks: hooks));
      await rig.open();
      final p = rig.provider;
      rig.betTenOnEveryCard();
      await tester.pump();
      expect(rig.wallet.balance, 880);
      await tester.tap(button(LuckyCardControl.clear));
      await tester.pump();
      expect(p.total, 0);
      expect(p.isBoardEmpty, isTrue);
      expect(rig.wallet.balance, 1000);
      expect(opacityOf(tester, button(LuckyCardControl.clear)), closeTo(0.4, 1e-9));
      expect(hooks.events, ['pressed clear']);
      await rig.finish();
    });

    testWidgets('REMOVE puts the chip down; taps on the board then take chips back; a chip picks the hand up again', (tester) async {
      final rig = BetRig(tester);
      final hooks = Hooks();
      await pumpAtSize(tester, phone, scene(rig.provider, hooks: hooks));
      await rig.open();
      final p = rig.provider;
      await settle(tester);
      p.selectChip(LuckyCardChip.ten);
      p.tapSuit(LuckyCardSuit.hearts);
      await settle(tester);
      expect(p.total, 30);
      expect(isInHand(tester, LuckyCardChip.ten, phone), isTrue);

      await tester.tap(button(LuckyCardControl.remove));
      await settle(tester);
      expect(p.activeChip, isNull, reason: 'the chip is put down');
      expect(p.total, 30, reason: 'nothing leaves the board');
      expect(rig.wallet.balance, 970);
      for (final c in LuckyCardChip.values) {
        expect(isInHand(tester, c, phone), isFalse, reason: 'no chip is in hand');
      }
      expect(hooks.events, ['pressed remove']);

      // Now a tap on a card takes a chip back, and the coins go back to the balance.
      final r = p.tapCard(hearts);
      await tester.pump();
      expect(r.coinsSpent, -10);
      expect(p.total, 20);
      expect(rig.wallet.balance, 980);

      // REMOVE stays usable while there is a bet (as in Triple Chance), and picking a chip up ends remove mode.
      expect(opacityOf(tester, button(LuckyCardControl.remove)), 1.0);
      await tester.tap(chip(LuckyCardChip.fifty));
      await settle(tester);
      expect(p.activeChip, LuckyCardChip.fifty);
      expect(isInHand(tester, LuckyCardChip.fifty, phone), isTrue);
      await rig.finish();
    });

    testWidgets('the board refuses to take chips back while one is in hand, and REMOVE is how to put it down', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider));
      await rig.open();
      final p = rig.provider;
      p.selectChip(LuckyCardChip.ten);
      p.tapCard(hearts);
      final r = p.tapCard(hearts);
      expect(p.stakeOn(hearts), 20, reason: 'a tap with a chip in hand adds one more');
      expect(r.isClean, isTrue);
      await tester.pump();
      await tester.tap(button(LuckyCardControl.remove));
      await tester.pump();
      p.tapCard(hearts);
      expect(p.stakeOn(hearts), 10);
      await rig.finish();
    });

    testWidgets('all three buttons are dimmed and ignore taps once betting is closed', (tester) async {
      final rig = BetRig(tester);
      final hooks = Hooks();
      await pumpAtSize(tester, phone, scene(rig.provider, hooks: hooks));
      await rig.open();
      final p = rig.provider;
      rig.betTenOnEveryCard();
      await rig.world.runUntil(86.0);
      expect(p.isLocked, isTrue);
      hooks.events.clear();
      for (final c in [LuckyCardControl.doubleBet, LuckyCardControl.clear, LuckyCardControl.remove]) {
        expect(opacityOf(tester, button(c)), closeTo(0.55, 1e-9), reason: c.name);
        await tester.tap(button(c));
      }
      await tester.pump();
      expect(hooks.events, isEmpty);
      expect(p.total, 120, reason: 'the bet is untouched');
      await rig.finish();
    });
  });

  group('REBET', () {
    /// Plays a whole round with a bet, then waits for the next round to open.
    Future<void> playARoundAndWait(WidgetTester tester, BetRig rig) async {
      rig.betTenOnEveryCard();
      await rig.world.runUntil(98.0);
      await rig.runIntoNextCycle(8);
    }

    testWidgets('after a round the empty board offers REBET in purple; it repeats the bet and DOUBLE comes back', (tester) async {
      final rig = BetRig(tester);
      final hooks = Hooks();
      await pumpAtSize(tester, phone, scene(rig.provider, hooks: hooks));
      await rig.open();
      final p = rig.provider;
      expect(labelOf(tester, slotZero), 'DOUBLE', reason: 'no earlier bet');
      await playARoundAndWait(tester, rig);
      expect(p.isBoardEmpty, isTrue);
      expect(p.canRebet, isTrue);
      expect(labelOf(tester, slotZero), 'REBET');
      expect(opacityOf(tester, button(LuckyCardControl.rebet)), 1.0, reason: 'affordable');
      expect(slotZero.evaluate().length, 1, reason: 'one button in the slot');

      final balance = rig.wallet.balance;
      hooks.events.clear();
      await tester.tap(button(LuckyCardControl.rebet));
      await tester.pump();
      expect(p.total, 120);
      expect(rig.wallet.balance, balance - 120);
      expect(hooks.events, ['pressed rebet']);
      expect(labelOf(tester, slotZero), 'DOUBLE', reason: 'REBET gives its place back to DOUBLE');
      await rig.finish();
    });

    testWidgets('an unaffordable REBET keeps its name, is dimmed, and does nothing', (tester) async {
      final rig = BetRig(tester);
      final hooks = Hooks();
      await pumpAtSize(tester, phone, scene(rig.provider, hooks: hooks));
      await rig.open();
      final p = rig.provider;
      await playARoundAndWait(tester, rig);
      rig.wallet.setLocalBalance(50);
      p.selectChip(LuckyCardChip.five); // any change makes the screen notice the new balance
      p.deselectChip();
      await tester.pump();
      expect(labelOf(tester, slotZero), 'REBET', reason: 'the name never changes for lack of coins');
      expect(opacityOf(tester, button(LuckyCardControl.rebet)), closeTo(0.4, 1e-9));
      hooks.events.clear();
      await tester.tap(button(LuckyCardControl.rebet));
      await tester.pump();
      expect(p.total, 0);
      expect(hooks.events, isEmpty);
      await rig.finish();
    });

    testWidgets('a bet placed by hand turns REBET back into DOUBLE', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider));
      await rig.open();
      final p = rig.provider;
      await playARoundAndWait(tester, rig);
      expect(labelOf(tester, slotZero), 'REBET');
      p.selectChip(LuckyCardChip.five);
      p.tapCard(hearts);
      await tester.pump();
      expect(labelOf(tester, slotZero), 'DOUBLE');
      await rig.finish();
    });

    testWidgets('CLEAR after a REBET lets REBET appear again', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider));
      await rig.open();
      await playARoundAndWait(tester, rig);
      await tester.tap(button(LuckyCardControl.rebet));
      await tester.pump();
      expect(labelOf(tester, slotZero), 'DOUBLE');
      await tester.tap(button(LuckyCardControl.clear));
      await tester.pump();
      expect(labelOf(tester, slotZero), 'REBET');
      await rig.finish();
    });
  });

  group('the whole side column', () {
    testWidgets('holds the readouts, the chips and the buttons together', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider));
      await rig.open();
      for (final k in ['play', 'win', 'limits', 'result-latest', 'result-8']) {
        expect(key(k), findsOneWidget, reason: k);
      }
      expect(find.byType(LuckyCardChipRail), findsOneWidget);
      expect(find.byType(LuckyCardActionButton), findsNWidgets(3));
      expect(find.byType(LuckyCardTapTarget), findsNWidgets(5));
      await rig.finish();
    });

    testWidgets('PLAY follows the chips the player places with the rail and the board', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider));
      await rig.open();
      await tester.tap(chip(LuckyCardChip.fifty));
      await tester.pump();
      rig.provider.tapCard(hearts);
      await tester.pump();
      expect(tester.widget<Text>(find.descendant(of: key('play'), matching: find.text('50'))).data, '50');
      await tester.tap(button(LuckyCardControl.doubleBet));
      await tester.pump();
      expect(find.descendant(of: key('play'), matching: find.text('100')), findsOneWidget);
      await rig.finish();
    });

    testWidgets('the chips and the suit icons are put in the image cache before the screen is shown', (tester) async {
      await pumpAtSize(tester, phone, const SizedBox.shrink());
      final cache = PaintingBinding.instance.imageCache..clear();
      expect(cache.currentSize, 0);
      final layout = LuckyCardLayout.of(phone);
      late BuildContext context;
      await pumpAtSize(tester, phone, Builder(builder: (c) {
        context = c;
        return const SizedBox.shrink();
      }));
      await tester.runAsync(() => precacheLuckyCardChips(context, layout, const FileLuckyCardArt()));
      expect(cache.currentSize, 5, reason: 'the five chips');
      cache.clear();
      await tester.runAsync(() => precacheLuckyCardSideColumn(context, layout, const FileLuckyCardArt()));
      expect(cache.currentSize, 9, reason: 'the five chips and the four suit icons');
      cache.clear();
    });
  });

  group('the binding places every piece where the layout says', () {
    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets(d.name, (tester) async {
        final rig = BetRig(tester);
        await pumpAtSize(tester, d.size, scene(rig.provider));
        await rig.open();
        final l = LuckyCardLayout.of(d.size);
        final expected = {
          for (final c in LuckyCardChip.values) 'chip-${c.amount}': l.chip(c.index),
          'button-doubleBet': l.actionButton(0),
          'button-clear': l.actionButton(1),
          'button-remove': l.actionButton(2),
        };
        for (final e in expected.entries) {
          final got = tester.getRect(key(e.key));
          final want = e.value.shift(l.canvasRect.topLeft);
          expect(got.left, closeTo(want.left, 0.01), reason: '${e.key} left');
          expect(got.top, closeTo(want.top, 0.01), reason: '${e.key} top');
          expect(got.width, closeTo(want.width, 0.01), reason: '${e.key} width');
          expect(got.height, closeTo(want.height, 0.01), reason: '${e.key} height');
        }
        await rig.finish();
      });
    }
  });

  group('it redraws only what changed', () {
    testWidgets('a tick of the countdown redraws neither the chips nor the buttons; a chip redraws both', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider));
      await rig.open();
      final rail = tester.widget(find.byType(LuckyCardChipRail));
      final button0 = tester.widget(slotZero);
      await rig.world.run(const Duration(seconds: 3));
      expect(identical(tester.widget(find.byType(LuckyCardChipRail)), rail), isTrue, reason: 'the chips did not');
      expect(identical(tester.widget(slotZero), button0), isTrue, reason: 'the buttons did not');

      rig.provider.selectChip(LuckyCardChip.fifty);
      rig.provider.tapCard(hearts);
      await tester.pump();
      expect(identical(tester.widget(find.byType(LuckyCardChipRail)), rail), isFalse, reason: 'a chip in hand changed the rail');
      expect(identical(tester.widget(slotZero), button0), isFalse, reason: 'a first bet changed the buttons');
      await rig.finish();
    });

    testWidgets('a bet placed on a board that already has bets does not redraw the buttons', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider));
      await rig.open();
      rig.provider.selectChip(LuckyCardChip.ten);
      rig.provider.tapCard(hearts);
      await tester.pump();
      final button0 = tester.widget(slotZero);
      final clear = tester.widget(button(LuckyCardControl.clear));
      rig.provider.tapCard(winner);
      await tester.pump();
      expect(identical(tester.widget(slotZero), button0), isTrue);
      expect(identical(tester.widget(button(LuckyCardControl.clear)), clear), isTrue);
      await rig.finish();
    });
  });

  group('the snapshots that decide a redraw', () {
    test('the chip rail changes with the chip in hand or the lock, and only then', () {
      const base = LuckyCardChipRailSnapshot(activeChip: LuckyCardChip.ten, isLocked: false);
      expect(base, const LuckyCardChipRailSnapshot(activeChip: LuckyCardChip.ten, isLocked: false));
      expect(base == const LuckyCardChipRailSnapshot(activeChip: LuckyCardChip.fifty, isLocked: false), isFalse);
      expect(base == const LuckyCardChipRailSnapshot(activeChip: null, isLocked: false), isFalse);
      expect(base == const LuckyCardChipRailSnapshot(activeChip: LuckyCardChip.ten, isLocked: true), isFalse);
    });

    test('the buttons change with the lock, a bet, REBET and its price, and only then', () {
      const base = LuckyCardButtonsSnapshot(isLocked: false, hasBets: true, showRebet: false, canAffordRebet: false);
      expect(base, const LuckyCardButtonsSnapshot(isLocked: false, hasBets: true, showRebet: false, canAffordRebet: false));
      expect(base == const LuckyCardButtonsSnapshot(isLocked: true, hasBets: true, showRebet: false, canAffordRebet: false), isFalse);
      expect(base == const LuckyCardButtonsSnapshot(isLocked: false, hasBets: false, showRebet: false, canAffordRebet: false), isFalse);
      expect(base == const LuckyCardButtonsSnapshot(isLocked: false, hasBets: true, showRebet: true, canAffordRebet: false), isFalse);
      expect(base == const LuckyCardButtonsSnapshot(isLocked: false, hasBets: true, showRebet: false, canAffordRebet: true), isFalse);
    });
  });

  group('listeners', () {
    testWidgets('everything stops listening when the screen goes away', (tester) async {
      final rig = BetRig(tester);
      final probe = ProbeProvider(rig);
      await pumpAtSize(tester, phone, scene(probe));
      expect(probe.listenedTo, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(probe.listenedTo, isFalse);
      probe.dispose();
      await rig.finish();
    });

    testWidgets('given another provider, the chips and buttons follow the new one and let go of the old', (tester) async {
      final rig = BetRig(tester);
      final a = ProbeProvider(rig);
      final b = ProbeProvider(rig);
      b.selectChip(LuckyCardChip.hundred);
      b.tapCard(hearts);

      await pumpAtSize(tester, phone, scene(a));
      await settle(tester);
      expect(opacityOf(tester, button(LuckyCardControl.clear)), closeTo(0.4, 1e-9), reason: 'a has no bet');
      expect(isInHand(tester, LuckyCardChip.hundred, phone), isFalse);

      await pumpAtSize(tester, phone, scene(b));
      await settle(tester);
      expect(opacityOf(tester, button(LuckyCardControl.clear)), 1.0, reason: 'b has a bet');
      expect(isInHand(tester, LuckyCardChip.hundred, phone), isTrue);
      expect(a.listenedTo, isFalse);
      expect(b.listenedTo, isTrue);

      // The buttons act on the new provider.
      await tester.tap(button(LuckyCardControl.clear));
      await tester.pump();
      expect(b.total, 0);
      a.dispose();
      b.dispose();
      await rig.finish();
    });
  });

  group('every device', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name}: a whole round with the side column builds with no overflow, 11 dp text and 48 dp taps', (tester) async {
        final rig = BetRig(tester);
        await pumpAtSize(tester, d.size, scene(rig.provider));
        await rig.open();
        rig.betTenOnEveryCard();
        await tester.pump();
        await rig.world.runUntil(98.0);
        expect(tester.takeException(), isNull);
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          expect(t.style!.fontSize, greaterThanOrEqualTo(11), reason: '"${t.data}"');
        }
        for (final c in LuckyCardChip.values) {
          final r = tester.getRect(chip(c));
          expect(r.width, greaterThanOrEqualTo(48));
          expect(r.height, greaterThanOrEqualTo(48));
        }
        for (final c in [LuckyCardControl.clear, LuckyCardControl.remove]) {
          final r = tester.getRect(button(c));
          expect(r.width, greaterThanOrEqualTo(48));
          expect(r.height, greaterThanOrEqualTo(48));
        }
        await rig.finish();
      });
    }
  });

  group('a picture to look at, with the real artwork', () {
    Future<void> shoot(WidgetTester tester, Device d, String name, Future<void> Function(BetRig rig) arrange) async {
      final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
      final rig = BetRig(tester);
      await pumpAtSize(tester, d.size, scene(rig.provider, art: art, withTopBar: true));
      await rig.open();
      await arrange(rig);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${d.width.toInt()}x${d.height.toInt()}.png'));
      await rig.finish();
    }

    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets('betting open, the 50 chip in hand, a bet on the board: ${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) async {
        await shoot(tester, d, 'side_column', (rig) async {
          rig.provider.selectChip(LuckyCardChip.ten);
          rig.provider.tapSuit(LuckyCardSuit.hearts);
          rig.provider.selectChip(LuckyCardChip.fifty);
        });
      });
    }

    testWidgets('betting closed: small phone', (tester) async {
      await shoot(tester, const Device('small phone', 640, 360), 'side_column_closed', (rig) async {
        rig.betTenOnEveryCard();
        await rig.world.runUntil(86.0);
      });
    });

    testWidgets('REBET offered after a round: small phone', (tester) async {
      await shoot(tester, const Device('small phone', 640, 360), 'side_column_rebet', (rig) async {
        rig.betTenOnEveryCard();
        await rig.world.runUntil(98.0);
        await rig.runIntoNextCycle(8);
      });
    });
  });
}
