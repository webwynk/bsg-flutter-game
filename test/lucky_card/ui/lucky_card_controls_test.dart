// Tests for the chip rail and the three buttons (lucky_card_chip_rail.dart,
// lucky_card_action_buttons.dart), given plain values. The provider-driven behaviour is
// in lucky_card_controls_binding_test.dart.
//
// What is checked on every device of the matrix: each chip and button is where the layout
// puts it, is at least 48 dp each way, holds its text at 11 dp or more with nothing
// overflowing, and the phone's font-size setting changes nothing.

import 'dart:ui' as ui;

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_action_buttons.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_chip_rail.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

/// What the screen's callbacks were told, in order.
class Log {
  final List<String> events = [];
}

/// One button of the scene: what it is, whether it can be used, and what its action answers.
class ButtonSpec {
  const ButtonSpec(this.control, {this.enabled = true, this.result = const LuckyCardBoardResult()});

  final LuckyCardControl control;
  final bool enabled;
  final LuckyCardBoardResult result;
}

const List<ButtonSpec> defaultButtons = [
  ButtonSpec(LuckyCardControl.doubleBet),
  ButtonSpec(LuckyCardControl.clear),
  ButtonSpec(LuckyCardControl.remove),
];

/// The chip rail and the three buttons in the side zone, as the binding places them.
Widget scene({
  LuckyCardArt art = const FileLuckyCardArt(),
  LuckyCardChip? activeChip = LuckyCardChip.ten,
  bool locked = false,
  List<ButtonSpec> buttons = defaultButtons,
  Log? log,
}) {
  return LuckyCardCanvas(
    side: (context, layout) {
      final side = layout.side;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(
            rect: layout.within(side, layout.chipRail),
            child: LuckyCardChipRail(
              layout: layout,
              art: art,
              activeChip: activeChip,
              isLocked: locked,
              onSelect: (chip) {
                log?.events.add('chip ${chip.amount}');
                return const LuckyCardBoardResult();
              },
            ),
          ),
          for (var i = 0; i < buttons.length; i++)
            Positioned.fromRect(
              rect: layout.within(side, layout.actionButton(i)),
              child: LuckyCardActionButton(
                key: ValueKey('button-${buttons[i].control.name}'),
                layout: layout,
                control: buttons[i].control,
                size: layout.actionButton(i).size,
                enabled: buttons[i].enabled,
                isLocked: locked,
                onTap: () {
                  log?.events.add('action ${buttons[i].control.name}');
                  return buttons[i].result;
                },
                onPressed: log == null ? null : () => log.events.add('pressed ${buttons[i].control.name}'),
                onRefused: log == null ? null : (c, issues) => log.events.add('refused ${c.name} ${(issues.map((e) => e.name).toList()..sort()).join('+')}'),
              ),
            ),
        ],
      );
    },
  );
}

Rect onScreen(LuckyCardLayout l, Rect inCanvas) => inCanvas.shift(l.canvasRect.topLeft);
Finder key(String k) => find.byKey(ValueKey(k));
Finder chipKey(LuckyCardChip c) => key('chip-${c.amount}');

double opacityOf(WidgetTester tester, Finder within) {
  final found = find.descendant(of: within, matching: find.byType(Opacity));
  return found.evaluate().isEmpty ? 1.0 : tester.widget<Opacity>(found.first).opacity;
}

Color faceTop(WidgetTester tester, String k) {
  final box = tester
      .widgetList<DecoratedBox>(find.descendant(of: key(k), matching: find.byType(DecoratedBox)))
      .map((d) => d.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((d) => d.gradient is LinearGradient && (d.gradient as LinearGradient).colors.length == 2);
  return (box.gradient as LinearGradient).colors.first;
}

void main() {
  setUpAll(loadLuckyCardFonts);

  group('the words and colours (pure)', () {
    test('the labels are the Triple Chance ones', () {
      expect([for (final c in LuckyCardControl.values) luckyCardControlLabel(c)], ['DOUBLE', 'REBET', 'CLEAR', 'REMOVE']);
    });

    test('DOUBLE is gold, REBET purple, CLEAR and REMOVE red', () {
      expect(LuckyCardButtonLook.of(LuckyCardControl.doubleBet), same(LuckyCardButtonLook.gold));
      expect(LuckyCardButtonLook.of(LuckyCardControl.rebet), same(LuckyCardButtonLook.purple));
      expect(LuckyCardButtonLook.of(LuckyCardControl.clear), same(LuckyCardButtonLook.red));
      expect(LuckyCardButtonLook.of(LuckyCardControl.remove), same(LuckyCardButtonLook.red));
      expect(LuckyCardButtonLook.gold.top, const Color(0xFFFFD700));
      expect(LuckyCardButtonLook.purple.bottom, const Color(0xFF3A0060));
      expect(LuckyCardButtonLook.red.top, const Color(0xFF8B0000));
    });

    test('every button has its own spoken words', () {
      final words = {for (final c in LuckyCardControl.values) luckyCardControlSemantics(c)};
      expect(words.length, 4);
      expect(luckyCardControlSemantics(LuckyCardControl.remove), contains('put the chip down'));
    });

    test('the chips are announced with their value, and "in hand" when held', () {
      expect(luckyCardChipSemantics(LuckyCardChip.fifty, selected: false), '50 chip');
      expect(luckyCardChipSemantics(LuckyCardChip.fifty, selected: true), '50 chip, in hand');
    });
  });

  group('every device of the matrix', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): each chip and button where the layout puts it, 48 dp, 11 dp text, no overflow', (tester) async {
        await pumpAtSize(tester, d.size, scene());
        final l = LuckyCardLayout.of(d.size);
        expect(tester.takeException(), isNull);

        for (final chip in LuckyCardChip.values) {
          final r = tester.getRect(chipKey(chip));
          final want = onScreen(l, l.chip(chip.index));
          expect(r.left, closeTo(want.left, 0.01), reason: '${chip.amount} left');
          expect(r.top, closeTo(want.top, 0.01), reason: '${chip.amount} top');
          expect(r.width, closeTo(want.width, 0.01));
          expect(r.height, closeTo(want.height, 0.01));
          expect(r.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'chip ${chip.amount}');
          expect(r.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'chip ${chip.amount}');
        }
        for (var i = 0; i < 3; i++) {
          final r = tester.getRect(key('button-${defaultButtons[i].control.name}'));
          final want = onScreen(l, l.actionButton(i));
          expect(r.left, closeTo(want.left, 0.01), reason: 'button $i left');
          expect(r.top, closeTo(want.top, 0.01), reason: 'button $i top');
          expect(r.width, closeTo(want.width, 0.01));
          expect(r.height, closeTo(want.height, 0.01));
          expect(r.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'button $i');
          expect(r.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'button $i');

          // The label is at least 11 dp and lies inside its button.
          final text = find.descendant(of: key('button-${defaultButtons[i].control.name}'), matching: find.byType(Text));
          final t = tester.widget<Text>(text);
          expect(t.style!.fontSize, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: t.data);
          final tr = tester.getRect(text);
          expect(tr.left, greaterThanOrEqualTo(r.left - 0.5), reason: '${t.data} left on ${d.name}');
          expect(tr.right, lessThanOrEqualTo(r.right + 0.5), reason: '${t.data} right on ${d.name}');
          expect(tr.top, greaterThanOrEqualTo(r.top - 0.5), reason: '${t.data} top on ${d.name}');
          expect(tr.bottom, lessThanOrEqualTo(r.bottom + 0.5), reason: '${t.data} bottom on ${d.name}');
        }
      });
    }

    testWidgets('the chips and the buttons do not overlap each other or the readouts above', (tester) async {
      for (final d in kDeviceMatrix) {
        await pumpAtSize(tester, d.size, scene());
        final rects = [
          for (final chip in LuckyCardChip.values) tester.getRect(chipKey(chip)),
          for (final b in defaultButtons) tester.getRect(key('button-${b.control.name}')),
        ];
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            expect(rects[i].overlaps(rects[j]), isFalse, reason: '$i and $j on ${d.name}');
          }
        }
      }
    });
  });

  group('the font-size setting of the phone changes nothing', () {
    testWidgets('at 3 times the text, every label keeps its size and every button its place', (tester) async {
      const size = Size(640, 360);
      await pumpAtSize(tester, size, scene());
      final before = [for (final b in defaultButtons) tester.getRect(key('button-${b.control.name}'))];
      final texts = [for (final t in tester.widgetList<Text>(find.byType(Text))) '${t.data}:${t.style!.fontSize}'];
      await pumpAtSize(tester, size, scene(), textScale: 3);
      expect(tester.takeException(), isNull);
      expect([for (final b in defaultButtons) tester.getRect(key('button-${b.control.name}'))], before);
      expect([for (final t in tester.widgetList<Text>(find.byType(Text))) '${t.data}:${t.style!.fontSize}'], texts);
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        expect(t.textScaler, TextScaler.noScaling);
      }
    });
  });

  group('the chip rail', () {
    testWidgets('five chips, 5 at the top to 500 at the bottom, each with its own picture', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      final tops = [for (final c in LuckyCardChip.values) tester.getRect(chipKey(c)).top];
      expect(tops, [...tops]..sort());
      expect(tops.toSet().length, 5);
      for (final chip in LuckyCardChip.values) {
        final image = tester.widget<Image>(find.descendant(of: chipKey(chip), matching: find.byType(Image)));
        final file = ((image.image as ResizeImage).imageProvider as FileImage).file.path.replaceAll('\\', '/');
        expect(file.endsWith(chip == LuckyCardChip.fiveHundred ? 'lucky_card/images/chip_500.webp' : 'images/chip_${chip.amount}.webp'), isTrue, reason: file);
      }
    });

    testWidgets('only the chip in hand is full size and glows; the others are smaller with no glow', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(activeChip: LuckyCardChip.fifty));
      await tester.pump(const Duration(milliseconds: 300));
      final l = LuckyCardLayout.of(const Size(844, 390));
      for (final chip in LuckyCardChip.values) {
        final face = key('chip-face-${chip.amount}');
        final size = tester.getSize(face);
        final selected = chip == LuckyCardChip.fifty;
        final share = size.width / l.chip(chip.index).width;
        expect(share, closeTo(selected ? LuckyCardChipRail.selectedShare : LuckyCardChipRail.restingShare, 0.001), reason: '${chip.amount}');
        final decoration = tester.widget<AnimatedContainer>(face).decoration as BoxDecoration;
        expect((decoration.boxShadow ?? const []).isNotEmpty, selected, reason: 'glow on ${chip.amount}');
      }
    });

    testWidgets('with nothing in hand no chip is full size', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(activeChip: null));
      await tester.pump(const Duration(milliseconds: 300));
      final l = LuckyCardLayout.of(const Size(844, 390));
      for (final chip in LuckyCardChip.values) {
        expect(tester.getSize(key('chip-face-${chip.amount}')).width / l.chip(chip.index).width, closeTo(LuckyCardChipRail.restingShare, 0.001));
      }
    });

    testWidgets('the chip in hand changes with a short animation when another is chosen', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(activeChip: LuckyCardChip.five));
      await tester.pump(const Duration(milliseconds: 300));
      final small = tester.getSize(key('chip-face-100')).width;
      await pumpAtSize(tester, const Size(844, 390), scene(activeChip: LuckyCardChip.hundred));
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.getSize(key('chip-face-100')).width;
      await tester.pump(const Duration(milliseconds: 300));
      final big = tester.getSize(key('chip-face-100')).width;
      expect(mid, greaterThan(small));
      expect(mid, lessThan(big), reason: 'it grows, it does not jump');
    });

    testWidgets('a tap anywhere in a chip\'s 48 dp area picks it up, even beside the picture', (tester) async {
      for (final d in kDeviceMatrix) {
        final log = Log();
        await pumpAtSize(tester, d.size, scene(log: log));
        final l = LuckyCardLayout.of(d.size);
        for (final chip in LuckyCardChip.values) {
          final area = onScreen(l, l.chip(chip.index));
          for (final p in [area.center, area.topLeft + const Offset(1, 1), area.bottomRight - const Offset(1, 1)]) {
            await tester.tapAt(p);
          }
        }
        await tester.pump();
        expect(log.events, [for (final c in LuckyCardChip.values) ...List.filled(3, 'chip ${c.amount}')], reason: d.name);
      }
    });

    testWidgets('tapping the chip already in hand tells the screen again (it stays in hand)', (tester) async {
      final log = Log();
      await pumpAtSize(tester, const Size(844, 390), scene(log: log, activeChip: LuckyCardChip.ten));
      await tester.tap(chipKey(LuckyCardChip.ten));
      await tester.pump();
      expect(log.events, ['chip 10']);
    });

    testWidgets('while betting is closed the chips are dimmed and ignore taps', (tester) async {
      final log = Log();
      await pumpAtSize(tester, const Size(844, 390), scene(log: log, locked: true));
      for (final chip in LuckyCardChip.values) {
        expect(opacityOf(tester, chipKey(chip)), closeTo(0.55, 1e-9), reason: '${chip.amount}');
        await tester.tap(chipKey(chip));
      }
      await tester.pump();
      expect(log.events, isEmpty);

      await pumpAtSize(tester, const Size(844, 390), scene(log: log, locked: false));
      for (final chip in LuckyCardChip.values) {
        expect(opacityOf(tester, chipKey(chip)), 1.0);
      }
    });

    testWidgets('the pictures are decoded no wider than a chip is drawn, at any density', (tester) async {
      for (final dpr in [1.0, 2.0, 3.0]) {
        const size = Size(844, 390);
        await pumpAtSize(tester, size, scene(), devicePixelRatio: dpr);
        final need = (LuckyCardLayout.of(size).chip(0).width * dpr).ceil();
        for (final chip in LuckyCardChip.values) {
          final image = tester.widget<Image>(find.descendant(of: chipKey(chip), matching: find.byType(Image)));
          final width = (image.image as ResizeImage).width!;
          expect(width, greaterThanOrEqualTo(need), reason: 'sharp at $dpr');
          expect(width, lessThanOrEqualTo(need + 1), reason: 'not larger than needed at $dpr');
        }
      }
    });

    testWidgets('a screen reader hears each chip and which one is in hand', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), scene(activeChip: LuckyCardChip.hundred));
      expect(find.bySemanticsLabel('100 chip, in hand'), findsOneWidget);
      for (final a in [5, 10, 50, 500]) {
        expect(find.bySemanticsLabel('$a chip'), findsOneWidget);
      }
      handle.dispose();
    });
  });

  group('the buttons', () {
    testWidgets('each is drawn in its own colour with its own word', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(buttons: const [
        ButtonSpec(LuckyCardControl.rebet),
        ButtonSpec(LuckyCardControl.clear),
        ButtonSpec(LuckyCardControl.remove),
      ]));
      Text label(String k) => tester.widget<Text>(find.descendant(of: key(k), matching: find.byType(Text)));
      expect(label('button-rebet').data, 'REBET');
      expect(label('button-clear').data, 'CLEAR');
      expect(label('button-remove').data, 'REMOVE');
      expect(faceTop(tester, 'button-rebet'), const Color(0xFF6A0DAD));
      expect(faceTop(tester, 'button-clear'), const Color(0xFF8B0000));
      expect(faceTop(tester, 'button-remove'), const Color(0xFF8B0000));
      expect(label('button-rebet').style!.color, const Color(0xFFFFFFFF));

      await pumpAtSize(tester, const Size(844, 390), scene());
      expect(label('button-doubleBet').data, 'DOUBLE');
      expect(faceTop(tester, 'button-doubleBet'), const Color(0xFFFFD700));
      expect(label('button-doubleBet').style!.color, const Color(0xFF350000), reason: 'dark on gold');
    });

    testWidgets('three looks of dimming: open, nothing to act on, and betting closed', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(buttons: const [
        ButtonSpec(LuckyCardControl.doubleBet),
        ButtonSpec(LuckyCardControl.clear, enabled: false),
        ButtonSpec(LuckyCardControl.remove),
      ]));
      expect(opacityOf(tester, key('button-doubleBet')), 1.0);
      expect(opacityOf(tester, key('button-clear')), closeTo(0.4, 1e-9));
      expect(opacityOf(tester, key('button-remove')), 1.0);

      await pumpAtSize(tester, const Size(844, 390), scene(locked: true, buttons: const [
        ButtonSpec(LuckyCardControl.doubleBet),
        ButtonSpec(LuckyCardControl.clear, enabled: false),
        ButtonSpec(LuckyCardControl.remove),
      ]));
      for (final k in ['button-doubleBet', 'button-clear', 'button-remove']) {
        expect(opacityOf(tester, key(k)), closeTo(0.55, 1e-9), reason: k);
      }
    });

    testWidgets('a tap anywhere in the button does its action, after the click hook', (tester) async {
      for (final d in kDeviceMatrix) {
        final log = Log();
        await pumpAtSize(tester, d.size, scene(log: log));
        final l = LuckyCardLayout.of(d.size);
        for (var i = 0; i < 3; i++) {
          final area = onScreen(l, l.actionButton(i));
          for (final p in [area.center, area.topLeft + const Offset(1, 1), area.bottomRight - const Offset(1, 1)]) {
            await tester.tapAt(p);
          }
        }
        await tester.pump();
        expect(log.events, [
          for (final c in [LuckyCardControl.doubleBet, LuckyCardControl.clear, LuckyCardControl.remove])
            for (var n = 0; n < 3; n++) ...['pressed ${c.name}', 'action ${c.name}'],
        ], reason: d.name);
      }
    });

    testWidgets('a button with nothing to act on, or a closed table, ignores taps and says nothing', (tester) async {
      final log = Log();
      await pumpAtSize(tester, const Size(844, 390), scene(log: log, buttons: const [
        ButtonSpec(LuckyCardControl.doubleBet, enabled: false),
        ButtonSpec(LuckyCardControl.clear, enabled: false),
        ButtonSpec(LuckyCardControl.remove, enabled: false),
      ]));
      for (final k in ['button-doubleBet', 'button-clear', 'button-remove']) {
        await tester.tap(key(k));
      }
      await pumpAtSize(tester, const Size(844, 390), scene(log: log, locked: true));
      for (final k in ['button-doubleBet', 'button-clear', 'button-remove']) {
        await tester.tap(key(k));
      }
      await tester.pump();
      expect(log.events, isEmpty);
    });

    testWidgets('a refused action flashes the button red and tells the screen why', (tester) async {
      final log = Log();
      const refused = LuckyCardBoardResult(issues: {LuckyCardBoardIssue.notEnoughCoins});
      await pumpAtSize(tester, const Size(844, 390), scene(log: log, buttons: const [
        ButtonSpec(LuckyCardControl.doubleBet, result: refused),
        ButtonSpec(LuckyCardControl.clear),
        ButtonSpec(LuckyCardControl.remove),
      ]));
      Finder flash() => find.descendant(of: key('button-doubleBet'), matching: find.byType(ColoredBox));
      expect(flash(), findsNothing);
      await tester.tap(key('button-doubleBet'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(flash(), findsOneWidget, reason: 'the red flash');
      expect(log.events, ['pressed doubleBet', 'action doubleBet', 'refused doubleBet notEnoughCoins']);
      await tester.pump(const Duration(milliseconds: 400));
      expect(flash(), findsNothing, reason: 'it fades away');

      // A clean tap does not flash and reports nothing.
      log.events.clear();
      await tester.tap(key('button-clear'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.descendant(of: key('button-clear'), matching: find.byType(ColoredBox)), findsNothing);
      expect(log.events, ['pressed clear', 'action clear']);
    });

    testWidgets('a partly done action (some cards changed, one at the maximum) is reported too', (tester) async {
      final log = Log();
      final partial = LuckyCardBoardResult(
        coinsSpent: 20,
        changed: const [LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts)],
        issues: const {LuckyCardBoardIssue.cardAtMaximum},
      );
      await pumpAtSize(tester, const Size(844, 390), scene(log: log, buttons: [ButtonSpec(LuckyCardControl.doubleBet, result: partial)]));
      await tester.tap(key('button-doubleBet'));
      await tester.pump();
      expect(log.events.last, 'refused doubleBet cardAtMaximum');
    });

    testWidgets('with "reduce motion" on, a refusal is reported but nothing flashes or shrinks', (tester) async {
      final log = Log();
      const refused = LuckyCardBoardResult(issues: {LuckyCardBoardIssue.nothingToDo});
      await pumpAtSize(
        tester,
        const Size(844, 390),
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: scene(log: log, buttons: const [ButtonSpec(LuckyCardControl.doubleBet, result: refused)]),
          ),
        ),
      );
      await tester.tap(key('button-doubleBet'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.descendant(of: key('button-doubleBet'), matching: find.byType(ColoredBox)), findsNothing);
      expect(log.events.last, 'refused doubleBet nothingToDo');
    });

    testWidgets('a button shrinks while the finger is down and springs back, also when the tap is cancelled', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(log: Log()));
      final l = LuckyCardLayout.of(const Size(844, 390));
      double scaleOf(String k) =>
          tester.widget<AnimatedScale>(find.descendant(of: key(k), matching: find.byType(AnimatedScale))).scale;
      final centre = onScreen(l, l.actionButton(1)).center;
      expect(scaleOf('button-clear'), 1.0);
      final finger = await tester.startGesture(centre);
      await tester.pump(const Duration(milliseconds: 20));
      expect(scaleOf('button-clear'), lessThan(1.0));
      expect(scaleOf('button-remove'), 1.0, reason: 'only the pressed button');
      await finger.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(scaleOf('button-clear'), 1.0);

      final second = await tester.startGesture(centre);
      await tester.pump(const Duration(milliseconds: 20));
      expect(scaleOf('button-clear'), lessThan(1.0));
      await second.moveBy(const Offset(0, 300));
      await second.cancel();
      await tester.pump(const Duration(milliseconds: 200));
      expect(scaleOf('button-clear'), 1.0, reason: 'cancelled');
    });

    testWidgets('a disabled button does not shrink under a finger', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(buttons: const [
        ButtonSpec(LuckyCardControl.doubleBet, enabled: false),
        ButtonSpec(LuckyCardControl.clear),
        ButtonSpec(LuckyCardControl.remove),
      ]));
      final l = LuckyCardLayout.of(const Size(844, 390));
      final finger = await tester.startGesture(onScreen(l, l.actionButton(0)).center);
      await tester.pump(const Duration(milliseconds: 20));
      final scale = tester.widget<AnimatedScale>(find.descendant(of: key('button-doubleBet'), matching: find.byType(AnimatedScale))).scale;
      expect(scale, 1.0);
      await finger.up();
    });

    testWidgets('a screen reader hears each button, and whether it can be used', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), scene(buttons: const [
        ButtonSpec(LuckyCardControl.doubleBet),
        ButtonSpec(LuckyCardControl.clear, enabled: false),
        ButtonSpec(LuckyCardControl.remove),
      ]));
      for (final c in [LuckyCardControl.doubleBet, LuckyCardControl.clear, LuckyCardControl.remove]) {
        expect(find.bySemanticsLabel(luckyCardControlSemantics(c)), findsOneWidget, reason: c.name);
      }
      final clear = tester.getSemantics(find.bySemanticsLabel(luckyCardControlSemantics(LuckyCardControl.clear)));
      expect(clear.getSemanticsData().flagsCollection.isEnabled, ui.Tristate.isFalse, reason: 'nothing to clear');
      final double = tester.getSemantics(find.bySemanticsLabel(luckyCardControlSemantics(LuckyCardControl.doubleBet)));
      expect(double.getSemanticsData().flagsCollection.isEnabled, ui.Tristate.isTrue);
      expect(double.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(double.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue, reason: 'a usable button can be activated');
      expect(clear.getSemanticsData().hasAction(ui.SemanticsAction.tap), isFalse, reason: 'a disabled one cannot');
      handle.dispose();
    });
  });
}
