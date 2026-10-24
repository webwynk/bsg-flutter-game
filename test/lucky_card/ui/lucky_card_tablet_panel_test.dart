// Tests for the tablet arrangement of the bet panel and the chip bar (tablet step T2, spec §17BN):
// the five chips in their own bar under the board, the three buttons stacked in the panel, PLAY and
// WIN and the results where LuckyCardLayout.tablet says, all driven by the REAL Lucky Card provider
// on the simulated server. The phone arrangement must not change: it is proven by the older tests.

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_action_buttons.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_bet_panel.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_board_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_controls_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_readouts.dart' show LuckyCardResultsPanel;
import 'package:best_smart_game/widgets/lucky_card/lucky_card_readouts_binding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'lucky_card_layout_tablet_test.dart' show kTabletReferenceSizes;
import 'ui_harness.dart';

class Hooks {
  final List<String> events = [];
}

/// The tablet screen as the real one builds it, minus the sounds: the top bar, the board, the
/// bet panel and the chip bar, laid out by [LuckyCardLayout.tablet].
Widget tabletScene(rig, {Hooks? hooks, LuckyCardArt art = const FileLuckyCardArt(), bool tablet = true}) => LuckyCardBoardBinding(
      provider: rig.provider,
      art: art,
      builder: (context, zones) => LuckyCardCanvas(
        layoutOf: tablet ? LuckyCardLayout.tablet : LuckyCardLayout.phone,
        topBar: (context, layout) => LuckyCardTopBarBinding(provider: rig.provider, layout: layout, art: art, soundOn: true),
        grid: zones.grid,
        rankColumn: zones.rankColumn,
        side: (context, layout) => LuckyCardSideColumn(
          provider: rig.provider,
          layout: layout,
          art: art,
          onChipSelected: hooks == null ? null : (chip) => hooks.events.add('chip ${chip.amount}'),
          onButtonPressed: hooks == null ? null : (c) => hooks.events.add('pressed ${c.name}'),
        ),
        chipBar: (context, layout) => LuckyCardChipBar(
          provider: rig.provider,
          layout: layout,
          art: art,
          onChipSelected: hooks == null ? null : (chip) => hooks.events.add('chip ${chip.amount}'),
        ),
      ),
    );

Finder key(String k) => find.byKey(ValueKey(k));
Finder chip(LuckyCardChip c) => key('chip-${c.amount}');
Finder button(LuckyCardControl c) => key('button-${c.name}');

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async {
    await loadLuckyCardFonts();
    await loadLuckyCardIcons();
  });

  group('every piece is where the tablet layout says', () {
    for (final d in kTabletReferenceSizes) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()})', (tester) async {
        final rig = BetRig(tester);
        await pumpAtSize(tester, d.size, tabletScene(rig));
        await rig.open();
        final l = LuckyCardLayout.tablet(d.size);
        expect(tester.takeException(), isNull, reason: 'no overflow or error');

        void at(Finder f, Rect want, String what) {
          final got = tester.getRect(f);
          expect(got.left, closeTo(want.left, 0.01), reason: '$what left');
          expect(got.top, closeTo(want.top, 0.01), reason: '$what top');
          expect(got.width, closeTo(want.width, 0.01), reason: '$what width');
          expect(got.height, closeTo(want.height, 0.01), reason: '$what height');
        }

        at(find.byType(LuckyCardSideColumn), l.side, 'the bet panel');
        at(find.byType(LuckyCardChipBar), l.chipBar, 'the chip bar');
        at(key('total-bet'), l.totalBetCell, 'PLAY');
        at(key('win'), l.winCell, 'WIN');
        at(find.byType(LuckyCardResultsPanel), l.resultsPanel, 'the results');
        for (var i = 0; i < LuckyCardLayout.chipCount; i++) {
          at(chip(LuckyCardChip.values[i]), l.chip(i), 'chip $i');
        }
        const controls = [LuckyCardControl.doubleBet, LuckyCardControl.clear, LuckyCardControl.remove];
        for (var i = 0; i < 3; i++) {
          at(button(controls[i]), l.actionButton(i), 'button $i');
        }
        await rig.finish();
      });
    }
  });

  group('the chips are in the bar under the board, not in the panel', () {
    testWidgets('all five are inside the chip bar and none inside the panel', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, const Size(1280, 800), tabletScene(rig));
      await rig.open();
      for (final c in LuckyCardChip.values) {
        expect(find.descendant(of: find.byType(LuckyCardChipBar), matching: chip(c)), findsOneWidget, reason: '${c.amount} in the bar');
        expect(find.descendant(of: find.byType(LuckyCardSideColumn), matching: chip(c)), findsNothing, reason: '${c.amount} not in the panel');
      }
      final l = LuckyCardLayout.tablet(const Size(1280, 800));
      expect(l.chipBar.bottom, lessThanOrEqualTo(l.designBody.bottom + 0.01));
      expect(l.chipBar.top, greaterThan(l.designBoard.bottom), reason: 'under the board');
      expect(l.chipBar.right, lessThan(l.side.left), reason: 'left of the panel');
      await rig.finish();
    });

    testWidgets('a phone arrangement is unchanged: its chips are in the panel and the bar is not built', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, const Size(1280, 800), tabletScene(rig, tablet: false));
      await rig.open();
      expect(find.byType(LuckyCardChipBar), findsNothing, reason: 'no chip bar on a phone arrangement, even if one is offered');
      for (final c in LuckyCardChip.values) {
        expect(find.descendant(of: find.byType(LuckyCardSideColumn), matching: chip(c)), findsOneWidget, reason: '${c.amount} in the panel');
      }
      await rig.finish();
    });

    testWidgets('a tap anywhere in a chip\'s slot picks it up, and the chip in hand is 6% bigger and lifted, the others full size', (tester) async {
      final rig = BetRig(tester);
      final hooks = Hooks();
      const size = Size(1366, 1024);
      await pumpAtSize(tester, size, tabletScene(rig, hooks: hooks));
      await rig.open();
      final l = LuckyCardLayout.tablet(size);
      final p = rig.provider;
      expect(l.designChipSize, 80);
      for (var i = 0; i < LuckyCardLayout.chipCount; i++) {
        final c = LuckyCardChip.values[i];
        final slot = l.chip(i);
        // The slot's left and right edges (inside it) and its centre all pick the chip up.
        for (final x in [slot.left + 2, slot.center.dx, slot.right - 2]) {
          p.deselectChip();
          await tester.pump();
          await tester.tapAt(Offset(x, slot.center.dy));
          await settle(tester);
          expect(p.activeChip, c, reason: 'tap at $x on chip ${c.amount}');
        }
        // In hand 6% bigger, everyone else full size.
        for (final other in LuckyCardChip.values) {
          final share = tester.getSize(key('chip-face-${other.amount}')).width / l.designChipSize;
          expect(share, closeTo(other == c ? 1.06 : 1.0, 0.001), reason: 'chip ${other.amount} while ${c.amount} is in hand');
        }
        final face = tester.getRect(key('chip-face-${c.amount}'));
        final lift = tester.widget<AnimatedContainer>(key('chip-face-${c.amount}')).transform!.getTranslation().y;
        expect(lift, lessThan(0), reason: 'the chip in hand is lifted');
        expect(tester.widget<AnimatedContainer>(key('chip-face-${LuckyCardChip.values[(i + 1) % 5].amount}')).transform!.getTranslation().y, 0, reason: 'the others are not');
        expect(face.left, greaterThanOrEqualTo(slot.left), reason: 'inside its slot');
        expect(face.right, lessThanOrEqualTo(slot.right), reason: 'inside its slot');
      }
      expect(hooks.events.where((e) => e.startsWith('chip')).length, greaterThanOrEqualTo(15), reason: 'a click for each pick-up');
      await rig.finish();
    });

    testWidgets('a closed table dims the chips in the bar and ignores taps; they work again in the next round', (tester) async {
      final rig = BetRig(tester);
      final hooks = Hooks();
      await pumpAtSize(tester, const Size(1024, 600), tabletScene(rig, hooks: hooks));
      await rig.open();
      rig.provider.selectChip(LuckyCardChip.ten);
      await rig.world.runUntil(86.0);
      expect(rig.provider.isLocked, isTrue);
      for (final c in LuckyCardChip.values) {
        final dim = find.descendant(of: chip(c), matching: find.byType(Opacity));
        expect(dim, findsWidgets, reason: 'chip ${c.amount} dimmed');
        await tester.tap(chip(c));
      }
      await tester.pump();
      expect(rig.provider.activeChip, LuckyCardChip.ten, reason: 'nothing was picked up while closed');
      expect(hooks.events, isEmpty);
      await rig.runIntoNextCycle(8);
      await tester.tap(chip(LuckyCardChip.hundred));
      await tester.pump();
      expect(rig.provider.activeChip, LuckyCardChip.hundred);
      await rig.finish();
    });
  });

  group('the three buttons are stacked in the panel', () {
    testWidgets('each is the panel\'s full width, one above the other, at least 48 dp tall, and with a bet each one works', (tester) async {
      final rig = BetRig(tester);
      final hooks = Hooks();
      const size = Size(1180, 820);
      await pumpAtSize(tester, size, tabletScene(rig, hooks: hooks));
      await rig.open();
      final l = LuckyCardLayout.tablet(size);
      final p = rig.provider;

      final double doubleTop = tester.getTopLeft(button(LuckyCardControl.doubleBet)).dy;
      final double clearTop = tester.getTopLeft(button(LuckyCardControl.clear)).dy;
      final double removeTop = tester.getTopLeft(button(LuckyCardControl.remove)).dy;
      expect(doubleTop, lessThan(clearTop));
      expect(clearTop, lessThan(removeTop));
      for (final c in [LuckyCardControl.doubleBet, LuckyCardControl.clear, LuckyCardControl.remove]) {
        final s = tester.getSize(button(c));
        expect(s.width, closeTo(l.panelInner.width, 0.01), reason: c.name);
        expect(s.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: c.name);
      }

      p.selectChip(LuckyCardChip.ten);
      p.tapCard(const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts));
      await settle(tester);
      expect(p.total, 10);
      await tester.tap(button(LuckyCardControl.doubleBet));
      await settle(tester);
      expect(p.total, 20, reason: 'DOUBLE doubles');
      await tester.tap(button(LuckyCardControl.remove));
      await settle(tester);
      expect(p.activeChip, isNull, reason: 'REMOVE puts the chip down');
      await tester.tap(button(LuckyCardControl.clear));
      await settle(tester);
      expect(p.total, 0, reason: 'CLEAR gives the chips back');
      expect(hooks.events.where((e) => e.startsWith('pressed')).toList(), ['pressed doubleBet', 'pressed remove', 'pressed clear']);
      await rig.finish();
    });

    testWidgets('REBET takes DOUBLE\'s place at the top after a round', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, const Size(1280, 800), tabletScene(rig));
      await rig.open();
      rig.betTenOnEveryCard();
      await rig.world.runUntil(98.0);
      await rig.runIntoNextCycle(8);
      await settle(tester);
      final l = LuckyCardLayout.tablet(const Size(1280, 800));
      final rebet = find.byWidgetPredicate((w) => w is LuckyCardActionButton && w.control == LuckyCardControl.rebet);
      expect(rebet, findsOneWidget);
      final rect = tester.getRect(rebet);
      expect(rect.top, closeTo(l.actionButton(0).top, 0.01));
      expect(rect.width, closeTo(l.panelInner.width, 0.01));
      await rig.finish();
    });
  });

  group('the corners and the cells follow the tablet', () {
    testWidgets('the panel and the chip bar have a 22 dp corner on a tablet, the panel 18 dp on a phone', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, const Size(1280, 800), tabletScene(rig));
      await rig.open();
      final radii = {for (final f in tester.widgetList<LuckyCardBetPanelFrame>(find.byType(LuckyCardBetPanelFrame))) f.radius};
      expect(radii, {22.0});
      await pumpAtSize(tester, const Size(844, 390), tabletScene(rig, tablet: false));
      await rig.open();
      expect({for (final f in tester.widgetList<LuckyCardBetPanelFrame>(find.byType(LuckyCardBetPanelFrame))) f.radius}, {18.0});
      await rig.finish();
    });

    testWidgets('the buttons have a 16 dp corner and the PLAY / WIN cells a 14 dp corner with 14 dp at the sides on a tablet; 14, 12 and 10 dp on a phone', (tester) async {
      final rig = BetRig(tester);
      Future<(double, double, double, EdgeInsets)> look(Size size, bool tablet) async {
        await pumpAtSize(tester, size, tabletScene(rig, tablet: tablet));
        await rig.open();
        double radiusOf(Finder f) {
          final box = tester.widget<DecoratedBox>(find.descendant(of: f, matching: find.byType(DecoratedBox)).first);
          return ((box.decoration as BoxDecoration).borderRadius as BorderRadius).topLeft.x;
        }

        final pad = tester.widget<Padding>(find.descendant(of: key('total-bet'), matching: find.byType(Padding)).first).padding as EdgeInsets;
        return (radiusOf(button(LuckyCardControl.doubleBet)), radiusOf(key('total-bet')), radiusOf(find.byType(LuckyCardBetPanelFrame).first), pad);
      }

      final t = await look(const Size(1280, 800), true);
      final l = LuckyCardLayout.tablet(const Size(1280, 800));
      expect(t.$1, 16);
      expect(t.$2, 14);
      expect(t.$3, 22);
      expect(t.$4, EdgeInsets.symmetric(horizontal: 14, vertical: l.totalPadY));
      final p = await look(const Size(844, 390), false);
      expect(p.$1, 14);
      expect(p.$2, 12);
      expect(p.$3, 18);
      expect(p.$4, const EdgeInsets.symmetric(horizontal: 10, vertical: 5));
      await rig.finish();
    });

    test('the layout hands out the tablet\'s cell, button and chip sizes and the phone\'s own', () {
      final t = LuckyCardLayout.tablet(const Size(1366, 1024));
      expect(t.panelRadius, 22);
      expect(t.totalPadX, 14);
      expect(t.totalCellRadius, 14);
      expect(t.buttonRadius, 16);
      expect(t.chipHandScale, 1.06);
      expect(t.chipRestScale, 1.0);
      final p = LuckyCardLayout.of(const Size(844, 390));
      expect(p.panelRadius, 18);
      expect(p.totalPadX, 10);
      expect(p.totalPadY, 5);
      expect(p.totalCellRadius, 12);
      expect(p.buttonRadius, 14);
      expect(p.chipHandScale, 1.0);
      expect(p.chipRestScale, closeTo(0.74 / 0.94, 1e-9));
    });
  });

  group('a picture to look at, with the real artwork (the tablet screen as it will be)', () {
    for (final d in const [Device('android tablet', 1024, 600), Device('ipad air', 1180, 820), Device('ipad pro 12.9', 1366, 1024)]) {
      testWidgets('betting open, the 50 chip in hand, a bet on the board: ${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) async {
        final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
        final rig = BetRig(tester);
        await pumpAtSize(tester, d.size, tabletScene(rig, art: art));
        await rig.open();
        rig.provider.selectChip(LuckyCardChip.ten);
        rig.provider.tapSuit(LuckyCardSuit.hearts);
        rig.provider.selectChip(LuckyCardChip.fifty);
        await settle(tester);
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tablet_panel_${d.width.toInt()}x${d.height.toInt()}.png'));
        await rig.finish();
      });
    }
  });
}
