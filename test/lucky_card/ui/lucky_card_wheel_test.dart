// Tests for lib/widgets/lucky_card/lucky_card_wheel.dart: the wheel ported from the
// user's design. The outer rim stops at 3 s and the inner at 5 s, both on exactly
// the segments the server's card needs; nothing is invented; the hub is not a
// button; it fits every device of the matrix; and screenshots of idle, mid-spin and
// landed with the real fonts.

import 'dart:async';

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel_slots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

const LuckyCard queenSpades = LuckyCard(LuckyCardRank.queen, LuckyCardSuit.spades);

Finder get wheelFinder => find.byType(LuckyCardWheel);
LuckyCardWheelState stateOf(WidgetTester tester) => tester.state<LuckyCardWheelState>(wheelFinder);

class Calls {
  int spinStarts = 0;
  int outerLands = 0;
  final List<LuckyCardWheelOutcome> innerLands = [];
}

Widget wheel(Calls calls, {double size = 300, bool innerClockwise = false}) => Center(
      child: LuckyCardWheel(
        size: size,
        innerClockwise: innerClockwise,
        onSpinStart: () => calls.spinStarts++,
        onOuterLand: () => calls.outerLands++,
        onInnerLand: calls.innerLands.add,
      ),
    );

Future<void> ms(WidgetTester tester, int millis) => tester.pump(Duration(milliseconds: millis));

void main() {
  setUpAll(loadLuckyCardWheelFonts);

  group('the timing (spec §6): the rank rim stops at 3 s, the suit rim at 5 s', () {
    testWidgets('spin start at 0, the first ding at 3 s, both landed at 5 s, in that order, once each', (tester) async {
      final calls = Calls();
      await pumpAtSize(tester, const Size(600, 500), wheel(calls));
      final s = stateOf(tester);
      expect(s.isSpinning, isFalse);
      expect(s.result, isNull);

      unawaited(s.spin(outerIndex: 2, innerIndex: 5, bonus: 4));
      await tester.pump(); // the animation starts counting at this frame
      expect(calls.spinStarts, 1);
      expect(s.isSpinning, isTrue);
      expect(s.result, isNull, reason: 'the card is not shown while the rims turn');

      await ms(tester, 2900);
      expect(calls.outerLands, 0);
      await ms(tester, 200); // 3.1 s
      expect(calls.outerLands, 1, reason: 'the rank rim has stopped');
      expect(calls.innerLands, isEmpty);
      expect(s.isSpinning, isTrue);
      expect(s.result, isNull, reason: 'the card shows only when BOTH rims have stopped');

      await ms(tester, 1800); // 4.9 s
      expect(calls.innerLands, isEmpty);
      await ms(tester, 200); // 5.1 s
      expect(calls.innerLands.length, 1);
      expect(calls.outerLands, 1);
      expect(s.isSpinning, isFalse);
      expect(s.result, calls.innerLands.single);
      await ms(tester, 2000); // lights settle
    });

    testWidgets('the rims turn in opposite directions: the outer clockwise, the inner counter-clockwise', (tester) async {
      await pumpAtSize(tester, const Size(600, 500), wheel(Calls()));
      final s = stateOf(tester);
      unawaited(s.spin(outerIndex: 1, innerIndex: 1, bonus: 1));
      await tester.pump();
      await ms(tester, 500);
      final (outerA, innerA) = s.currentAngles;
      await ms(tester, 500);
      final (outerB, innerB) = s.currentAngles;
      expect(outerB, greaterThan(outerA), reason: 'outer rim clockwise');
      expect(innerB, lessThan(innerA), reason: 'inner rim counter-clockwise');
      await ms(tester, 6000);
    });

    testWidgets('a custom duration is honoured', (tester) async {
      final calls = Calls();
      await pumpAtSize(
        tester,
        const Size(600, 500),
        Center(
          child: LuckyCardWheel(
            size: 300,
            outerSpinDuration: const Duration(seconds: 1),
            innerSpinDuration: const Duration(seconds: 2),
            onOuterLand: () => calls.outerLands++,
            onInnerLand: calls.innerLands.add,
          ),
        ),
      );
      unawaited(stateOf(tester).spin(outerIndex: 0, innerIndex: 0, bonus: 1));
      await tester.pump();
      await ms(tester, 1100);
      expect(calls.outerLands, 1);
      expect(calls.innerLands, isEmpty);
      await ms(tester, 1000);
      expect(calls.innerLands.length, 1);
      await ms(tester, 2000);
    });
  });

  group('the wheel stops on exactly the segments it was given', () {
    testWidgets('every one of the 12 outer segments, with a different inner one each time', (tester) async {
      final calls = Calls();
      await pumpAtSize(tester, const Size(600, 500), wheel(calls));
      final s = stateOf(tester);
      for (var o = 0; o < 12; o++) {
        final i = (o * 5 + 3) % 12;
        unawaited(s.spin(outerIndex: o, innerIndex: i, bonus: 1 + o % 10));
        await tester.pump();
        await ms(tester, 5200);
        expect(s.restingSegments, (o, i), reason: 'asked for outer $o, inner $i');
        expect(s.result!.card, luckyCardAtWheelStop(o, i), reason: 'outer $o, inner $i');
        expect(s.result!.bonus, 1 + o % 10);
        await ms(tester, 2000);
      }
      expect(calls.innerLands.length, 12);
    });

    testWidgets('every one of the 12 inner segments', (tester) async {
      await pumpAtSize(tester, const Size(600, 500), wheel(Calls()));
      final s = stateOf(tester);
      for (var i = 0; i < 12; i++) {
        unawaited(s.spin(outerIndex: (i * 7) % 12, innerIndex: i, bonus: 2));
        await tester.pump();
        await ms(tester, 5200);
        expect(s.restingSegments, ((i * 7) % 12, i), reason: 'inner $i');
        await ms(tester, 2000);
      }
    });

    testWidgets('a spin from a wheel already turned (consecutive rounds) still ends on the right segments', (tester) async {
      await pumpAtSize(tester, const Size(600, 500), wheel(Calls(), innerClockwise: true));
      final s = stateOf(tester);
      for (final (o, i) in [(3, 9), (3, 9), (0, 0), (11, 11), (5, 2)]) {
        unawaited(s.spin(outerIndex: o, innerIndex: i, bonus: 1));
        await tester.pump();
        await ms(tester, 5200);
        expect(s.restingSegments, (o, i));
        await ms(tester, 2000);
      }
    });

    testWidgets('spinTo gives the card for the round: Q♠ in a round, and the same segments for the same round on any wheel', (tester) async {
      await pumpAtSize(tester, const Size(600, 500), wheel(Calls()));
      final s = stateOf(tester);
      unawaited(s.spinTo(card: queenSpades, roundNumber: 17390003, bonus: 4));
      await tester.pump();
      await ms(tester, 5200);
      final stop = luckyCardWheelStopFor(queenSpades, 17390003);
      expect(s.restingSegments, (stop.outerIndex, stop.innerIndex));
      expect(s.result!.card, queenSpades);
      expect(s.result!.bonus, 4);
      await ms(tester, 2000);
    });
  });

  group('nothing is invented', () {
    testWidgets('a second spin while one is running is ignored and calls nothing twice', (tester) async {
      final calls = Calls();
      await pumpAtSize(tester, const Size(600, 500), wheel(calls));
      final s = stateOf(tester);
      unawaited(s.spin(outerIndex: 4, innerIndex: 6, bonus: 3));
      await tester.pump();
      await ms(tester, 1000);
      var answered = false;
      Object? answer = 'no answer yet';
      unawaited(s.spin(outerIndex: 9, innerIndex: 1, bonus: 7).then((v) {
        answered = true;
        answer = v;
      }));
      await tester.pump();
      expect(answered, isTrue, reason: 'refused at once, not after running a second spin');
      expect(answer, isNull);
      await ms(tester, 5000);
      expect(calls.spinStarts, 1);
      expect(calls.outerLands, 1);
      expect(calls.innerLands.length, 1);
      expect(s.restingSegments, (4, 6), reason: 'the first spin, not the ignored one');
      expect(s.result!.bonus, 3);
      await ms(tester, 2000);
    });

    testWidgets('a value out of range is refused, even while idle, and changes nothing', (tester) async {
      final calls = Calls();
      await pumpAtSize(tester, const Size(600, 500), wheel(calls));
      final s = stateOf(tester);
      for (final args in [(-1, 0, 1), (12, 0, 1), (0, -1, 1), (0, 12, 1), (0, 0, 0), (0, 0, 11), (0, 0, -3)]) {
        expect(
          () {
            s.spin(outerIndex: args.$1, innerIndex: args.$2, bonus: args.$3);
          },
          throwsArgumentError,
          reason: '$args',
        );
      }
      expect(s.isSpinning, isFalse);
      expect(s.result, isNull);
      expect(calls.spinStarts, 0);
    });

    testWidgets('a bad value is refused even while a spin is running, and does not disturb it', (tester) async {
      final calls = Calls();
      await pumpAtSize(tester, const Size(600, 500), wheel(calls));
      final s = stateOf(tester);
      unawaited(s.spin(outerIndex: 1, innerIndex: 1, bonus: 2));
      await tester.pump();
      expect(() { s.spin(outerIndex: 99, innerIndex: 1, bonus: 2); }, throwsArgumentError);
      expect(() { s.spin(outerIndex: 1, innerIndex: 1, bonus: 11); }, throwsArgumentError);
      await ms(tester, 5200);
      expect(calls.innerLands.length, 1);
      await ms(tester, 2000);
    });

    testWidgets('the hub is not a button: tapping the middle of the wheel does nothing', (tester) async {
      final calls = Calls();
      await pumpAtSize(tester, const Size(600, 500), wheel(calls));
      expect(find.descendant(of: wheelFinder, matching: find.byType(GestureDetector)), findsNothing);
      expect(find.descendant(of: wheelFinder, matching: find.byType(InkWell)), findsNothing);
      await tester.tapAt(tester.getCenter(wheelFinder));
      await tester.tapAt(tester.getCenter(wheelFinder) + const Offset(0, 30));
      await ms(tester, 100);
      expect(stateOf(tester).isSpinning, isFalse);
      expect(calls.spinStarts, 0);
      expect(stateOf(tester).result, isNull);
    });
  });

  group('the bonus text (the user: "2X")', () {
    test('N for no bonus, then 2X to 10X', () {
      expect(luckyCardWheelBonusLabel(1), 'N');
      expect(luckyCardWheelBonusLabel(0), 'N');
      expect(luckyCardWheelBonusLabel(2), '2X');
      expect(luckyCardWheelBonusLabel(3), '3X');
      expect(luckyCardWheelBonusLabel(10), '10X');
    });

    test('the outcome knows whether there is a bonus', () {
      expect(const LuckyCardWheelOutcome(queenSpades, 1).hasBonus, isFalse);
      expect(const LuckyCardWheelOutcome(queenSpades, 2).hasBonus, isTrue);
      expect(const LuckyCardWheelOutcome(queenSpades, 4).toString(), 'Q♠ bonus 4X');
      expect(const LuckyCardWheelOutcome(queenSpades, 1).toString(), 'Q♠');
      expect(const LuckyCardWheelOutcome(queenSpades, 4).rank, 'Q');
      expect(const LuckyCardWheelOutcome(queenSpades, 4).suit, LuckyCardSuit.spades);
    });
  });

  group('leaving', () {
    testWidgets('removing the wheel mid-spin calls nothing back and leaves nothing running', (tester) async {
      final calls = Calls();
      await pumpAtSize(tester, const Size(600, 500), wheel(calls));
      unawaited(stateOf(tester).spin(outerIndex: 3, innerIndex: 3, bonus: 5));
      await tester.pump();
      await ms(tester, 1000);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await ms(tester, 7000);
      expect(tester.takeException(), isNull);
      expect(calls.outerLands, 0);
      expect(calls.innerLands, isEmpty);
    });

    testWidgets('removing the wheel the moment it lands leaves no timer pending', (tester) async {
      final calls = Calls();
      await pumpAtSize(tester, const Size(600, 500), wheel(calls));
      unawaited(stateOf(tester).spin(outerIndex: 3, innerIndex: 3, bonus: 5));
      await tester.pump();
      await ms(tester, 5100);
      expect(calls.innerLands.length, 1);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(tester.takeException(), isNull);
      // The test ends here: a timer left running by the wheel would fail it.
    });
  });

  group('it fits every device of the matrix', () {
    Widget inCanvas({bool spin = false}) => LuckyCardCanvas(
          grid: (context, l) => Stack(
            children: [
              Positioned.fromRect(
                rect: l.wheelBox.shift(-l.grid.topLeft),
                child: LuckyCardWheel(size: l.wheelDiameter),
              ),
            ],
          ),
        );

    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): in the grid zone, pointer included, idle and mid-spin, with no overflow', (tester) async {
        await pumpAtSize(tester, d.size, inCanvas());
        expect(tester.takeException(), isNull);
        final layout = LuckyCardLayout.of(d.size);
        final box = tester.getRect(wheelFinder);
        final want = layout.wheelBox.shift(layout.canvasRect.topLeft);
        expect(box.left, closeTo(want.left, 0.01));
        expect(box.top, closeTo(want.top, 0.01));
        expect(box.width, closeTo(layout.wheelDiameter, 0.01));
        expect(box.height, closeTo(layout.wheelDiameter * 1.06, 0.01));
        final grid = layout.grid.shift(layout.canvasRect.topLeft);
        expect(box.left, greaterThanOrEqualTo(grid.left - 0.01));
        expect(box.right, lessThanOrEqualTo(grid.right + 0.01));
        expect(box.top, greaterThanOrEqualTo(grid.top - 0.01));
        expect(box.bottom, lessThanOrEqualTo(grid.bottom + 0.01));

        unawaited(stateOf(tester).spin(outerIndex: 5, innerIndex: 8, bonus: 10));
        await tester.pump();
        await ms(tester, 2500);
        expect(tester.takeException(), isNull, reason: 'mid-spin');
        await ms(tester, 3000);
        expect(tester.takeException(), isNull, reason: 'landed');
        await ms(tester, 2000);
      });
    }

    testWidgets("the phone's font-size setting makes no difference to the wheel", (tester) async {
      await pumpAtSize(tester, const Size(844, 390), inCanvas(), textScale: 3);
      unawaited(stateOf(tester).spin(outerIndex: 2, innerIndex: 2, bonus: 10));
      await tester.pump();
      await ms(tester, 5500);
      expect(tester.takeException(), isNull);
      await ms(tester, 2000);
    });
  });

  group('pictures to look at, with the real fonts', () {
    Widget scene(Size screen) => LuckyCardCanvas(
          grid: (context, l) => Stack(
            children: [
              Positioned.fromRect(
                rect: l.wheelBox.shift(-l.grid.topLeft),
                child: LuckyCardWheel(key: const ValueKey('wheel'), size: l.wheelDiameter),
              ),
            ],
          ),
        );

    Future<void> shot(WidgetTester tester, String name) =>
        expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets('Q♠ with a 4X bonus, landed: ${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) async {
        await pumpAtSize(tester, d.size, scene(d.size));
        unawaited(stateOf(tester).spinTo(card: queenSpades, roundNumber: 17390003, bonus: 4));
        await tester.pump();
        await ms(tester, 5100); // both rims have stopped
        await ms(tester, 1300); // the result has popped in; the lights still blink
        expect(tester.takeException(), isNull);
        await shot(tester, 'wheel_landed_${d.width.toInt()}x${d.height.toInt()}');
        await ms(tester, 2500);
      });
    }

    testWidgets('idle: the mystery gift, 915x412', (tester) async {
      await pumpAtSize(tester, const Size(915, 412), scene(const Size(915, 412)));
      await tester.pump();
      await shot(tester, 'wheel_idle_915x412');
    });

    testWidgets('three and a half seconds into the spin: the rank rim has stopped, the bonus is growing out of the smoke, 915x412', (tester) async {
      await pumpAtSize(tester, const Size(915, 412), scene(const Size(915, 412)));
      unawaited(stateOf(tester).spinTo(card: queenSpades, roundNumber: 17390003, bonus: 4));
      await tester.pump();
      await ms(tester, 3500);
      expect(stateOf(tester).isSpinning, isTrue);
      await shot(tester, 'wheel_spinning_915x412');
      await ms(tester, 6000);
    });
  });
}
