// Spin2Win screens, Phase 1: the phone screen's frame (lib/widgets/spin2win/).
//
// Checks that the frame draws every piece of the reference design with the sample numbers, fits
// every phone shape without overflowing, and that its small text helpers write numbers the way the
// design does.

import 'dart:io';

import 'package:best_smart_game/models/spin2win_board.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_bet_panel.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_frame.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_history_strip.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_palette.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Size screen, {Spin2WinFrameData data = Spin2WinFrameData.sample, EdgeInsets padding = EdgeInsets.zero}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(left: padding.left, top: padding.top, right: padding.right, bottom: padding.bottom);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Spin2WinViewport(child: Spin2WinFrame(data: data)))));
}

/// The text of every [Text] under [finder], joined.
String _textUnder(WidgetTester tester, Finder finder) => tester
    .widgetList<Text>(find.descendant(of: finder, matching: find.byType(Text), matchRoot: true))
    .map((t) => t.data ?? '')
    .toSet()
    .join(' ');

void main() {
  group('the frame shows every piece of the design', () {
    testWidgets('the top bar: balance, PLAY, WIN and the three buttons', (tester) async {
      await _pump(tester, const Size(844, 390));
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-balance'))), '1,250');
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-play'))), '0');
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-win'))), '0');
      expect(find.text('PLAY:'), findsOneWidget);
      expect(find.text('WIN:'), findsOneWidget);
      expect(find.byKey(const ValueKey('spin2win-exit')), findsOneWidget);
      expect(find.byKey(const ValueKey('spin2win-records')), findsOneWidget);
      expect(find.byKey(const ValueKey('spin2win-sound')), findsOneWidget);
    });

    testWidgets('ten number cards, 0 to 9, each with the coins on it', (tester) async {
      await _pump(tester, const Size(844, 390));
      for (var n = 0; n <= 9; n++) {
        expect(find.byKey(ValueKey('spin2win-card-$n')), findsOneWidget, reason: 'card $n');
        expect(_textUnder(tester, find.byKey(ValueKey('spin2win-stake-$n'))), '0');
      }
      // 0 to 4 on the top row, 5 to 9 under them, in order.
      double x(int n) => tester.getTopLeft(find.byKey(ValueKey('spin2win-card-$n'))).dx;
      double y(int n) => tester.getTopLeft(find.byKey(ValueKey('spin2win-card-$n'))).dy;
      for (var n = 1; n <= 4; n++) {
        expect(x(n), greaterThan(x(n - 1)));
        expect(y(n), y(0));
        expect(x(n + 5), moreOrLessEquals(x(n)));
        expect(y(n + 5), greaterThan(y(n)));
      }
    });

    testWidgets('the five chips, the 5 chip raised as the one in hand', (tester) async {
      await _pump(tester, const Size(844, 390));
      final tops = {
        for (final c in Spin2WinChip.values)
          c: tester
              .getTopLeft(find.descendant(of: find.byKey(ValueKey('spin2win-chip-${c.amount}')), matching: find.byType(Image)))
              .dy,
      };
      expect(tops.length, 5);
      expect(tops[Spin2WinChip.five], lessThan(tops[Spin2WinChip.ten]!));
      expect(tops[Spin2WinChip.ten], tops[Spin2WinChip.fiveHundred]);
    });

    testWidgets('ODD, EVEN, DOUBLE, REMOVE, CLEAR and the timer at 90', (tester) async {
      await _pump(tester, const Size(844, 390));
      for (final key in ['odd', 'even', 'double', 'remove', 'clear', 'timer']) {
        expect(find.byKey(ValueKey('spin2win-$key')), findsOneWidget, reason: key);
      }
      expect(find.byKey(const ValueKey('spin2win-rebet')), findsNothing);
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-countdown'))), '90');
    });

    testWidgets('the history strip holds the ten results, newest first', (tester) async {
      await _pump(tester, const Size(844, 390));
      expect(find.text('HISTORY'), findsOneWidget);
      for (var i = 0; i < 10; i++) {
        expect(find.byKey(ValueKey('spin2win-history-$i')), findsOneWidget);
      }
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-history-0'))), '1 N');
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-history-1'))), '8 3x');
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-history-4'))), '7 4x');
      double x(int i) => tester.getTopLeft(find.byKey(ValueKey('spin2win-history-$i'))).dx;
      for (var i = 1; i < 10; i++) {
        expect(x(i), greaterThan(x(i - 1)));
      }
    });

    testWidgets('the wheel: its face, the dome with the last result and its bonus', (tester) async {
      await _pump(tester, const Size(844, 390));
      expect(find.byKey(const ValueKey('spin2win-wheel-face')), findsOneWidget);
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-dome-number'))), '1');
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-dome'))), contains('N'));
    });
  });

  group('the frame shows the values it is given', () {
    const busy = Spin2WinFrameData(
      balance: 1234567,
      play: 10500,
      win: 360,
      muted: true,
      stakes: {0: 10000, 3: 5, 9: 750},
      selectedChip: Spin2WinChip.fiveHundred,
      countdown: 5,
      rebetMode: true,
      wheelAngle: 123,
      dome: Spin2WinDomeShuffling(3),
      history: [
        Spin2WinHistoryTile(number: 0, bonusMultiplier: 2),
        Spin2WinHistoryTile(number: 3, bonusMultiplier: 1),
      ],
    );

    testWidgets('numbers, stakes, countdown, REBET, the shuffling dome, a short history', (tester) async {
      await _pump(tester, const Size(844, 390), data: busy);
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-balance'))), '1,234,567');
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-play'))), '10,500');
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-win'))), '360');
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-stake-0'))), '10,000');
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-stake-3'))), '5');
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-stake-9'))), '750');
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-stake-1'))), '0');
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-countdown'))), '05');
      expect(find.byKey(const ValueKey('spin2win-rebet')), findsOneWidget);
      expect(find.byKey(const ValueKey('spin2win-double')), findsNothing);
      expect(find.byKey(const ValueKey('spin2win-dome-number')), findsNothing);
      expect(_textUnder(tester, find.byKey(const ValueKey('spin2win-dome-bonus'))), '3x');
      expect(find.text('BONUS'), findsOneWidget);
      expect(find.byKey(const ValueKey('spin2win-history-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('spin2win-history-2')), findsNothing);
      expect(find.bySemanticsLabel('Sound off'), findsOneWidget);
    });
  });

  group('the frame fits every phone shape', () {
    const shapes = {
      'design phone 844 x 390': Size(844, 390),
      'small 16:9 phone 640 x 360': Size(640, 360),
      '18:9 phone 720 x 360': Size(720, 360),
      '19.5:9 phone 780 x 360': Size(780, 360),
      '20:9 phone 915 x 412': Size(915, 412),
      '21:9 phone 960 x 412': Size(960, 412),
      'very long 1100 x 400': Size(1100, 400),
      'tablet 1024 x 768': Size(1024, 768),
    };
    for (final entry in shapes.entries) {
      testWidgets('${entry.key}: no overflow, everything on screen', (tester) async {
        await _pump(tester, entry.value);
        expect(tester.takeException(), isNull);
        final screen = Offset.zero & entry.value;
        for (final key in ['spin2win-exit', 'spin2win-sound', 'spin2win-card-0', 'spin2win-card-9', 'spin2win-timer', 'spin2win-history-9']) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(screen.contains(rect.topLeft) && screen.contains(rect.bottomRight - const Offset(0.01, 0.01)), isTrue,
              reason: '$key at $rect is off a ${entry.value} screen');
        }
      });
    }

    testWidgets('a side camera cut-out: no blank strip, the buttons stay clear of it', (tester) async {
      // Hasan's phone test, 2026-10-25: the side inset left a blank strip down the left. The board
      // now runs edge to edge (as Lucky Card does); the cut-out falls in the board's own margin.
      await _pump(tester, const Size(844, 390), padding: const EdgeInsets.only(left: 32, right: 32, top: 0));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(const ValueKey('spin2win-timer'))).right, greaterThan(844 - 32));
      expect(tester.getRect(find.byKey(const ValueKey('spin2win-exit'))).left, greaterThanOrEqualTo(32));
      expect(tester.getRect(find.byKey(const ValueKey('spin2win-sound'))).right, lessThanOrEqualTo(844 - 32));
    });

    testWidgets('a top or bottom inset still keeps the board inside it', (tester) async {
      await _pump(tester, const Size(844, 390), padding: const EdgeInsets.only(top: 24));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(const ValueKey('spin2win-exit'))).top, greaterThanOrEqualTo(24));
    });

    testWidgets('a phone set to a large font changes nothing', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, const Size(844, 390));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const ValueKey('spin2win-timer'))).width, moreOrLessEquals(92));
    });

    test('the design is laid out 390 dp tall and 760 to 940 dp wide', () {
      expect(Spin2WinViewport.designSizeFor(const Size(844, 390)), const Size(844, 390));
      expect(Spin2WinViewport.designSizeFor(const Size(915, 412)).width, closeTo(866.1, 0.1));
      expect(Spin2WinViewport.designSizeFor(const Size(640, 360)), const Size(760, 390));
      expect(Spin2WinViewport.designSizeFor(const Size(1100, 400)), const Size(940, 390));
    });
  });

  group('helpers', () {
    test('amounts are written with thousands commas', () {
      expect(spin2WinAmountText(0), '0');
      expect(spin2WinAmountText(999), '999');
      expect(spin2WinAmountText(1250), '1,250');
      expect(spin2WinAmountText(10000), '10,000');
      expect(spin2WinAmountText(1234567), '1,234,567');
      expect(spin2WinAmountText(-4500), '-4,500');
    });

    test('the countdown is always two digits', () {
      expect(spin2WinCountdownText(90), '90');
      expect(spin2WinCountdownText(5), '05');
      expect(spin2WinCountdownText(0), '00');
      expect(spin2WinCountdownText(-3), '00');
    });

    test('bonus text and colours: N, 2x, 3x, 4x', () {
      expect([1, 2, 3, 4].map(spin2WinBonusText), ['N', '2x', '3x', '4x']);
      expect(spin2WinBonusShades(1).light, const Color(0xFFC7D3EE));
      expect(spin2WinBonusShades(4).dark, const Color(0xFF0A4FC4));
    });

    test('every number has its colour; 1 and 6, 4 and 8 share theirs', () {
      expect(kSpin2WinShades.length, 10);
      expect(spin2WinShades(1), same(spin2WinShades(6)));
      expect(spin2WinShades(4), same(spin2WinShades(8)));
      expect(spin2WinShades(0).mid, const Color(0xFF00B8E6));
    });

    test('the wheel turns the chosen number under the pointer', () {
      expect(kSpin2WinWheelOrder, [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
      expect(spin2WinAngleFor(1), 0);
      expect(spin2WinAngleFor(2), -36);
      expect(spin2WinAngleFor(0), -324);
    });

    test('chips: 5 to 100 are Triple Chance pictures, 500 is Lucky Card\'s, and all exist', () {
      expect(spin2WinChipAsset(Spin2WinChip.five), 'assets/images/chip_5.webp');
      expect(spin2WinChipAsset(Spin2WinChip.hundred), 'assets/images/chip_100.webp');
      expect(spin2WinChipAsset(Spin2WinChip.fiveHundred), 'assets/lucky_card/images/chip_500.webp');
      for (final chip in Spin2WinChip.values) {
        expect(File(spin2WinChipAsset(chip)).existsSync(), isTrue, reason: spin2WinChipAsset(chip));
      }
    });

    test('the sample history is the design\'s ten tiles', () {
      final tiles = Spin2WinFrameData.sample.history;
      expect(tiles.length, Spin2WinHistoryStrip.slots);
      expect(tiles.map((t) => '${t.number}${spin2WinBonusText(t.bonusMultiplier)}').join(' '),
          '1N 83x 2N 5N 74x 8N 62x 5N 4N 93x');
    });
  });
}
