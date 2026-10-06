// Tests for lib/widgets/lucky_card/lucky_card_reveal_card.dart: the big card of the
// reveal. Resting it shows a card back; during the spin it flips through the
// planned faces; it turns to the winner only when told to; it fits every device.

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_reveal_card.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_reveal_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

const LuckyCard queenSpades = LuckyCard(LuckyCardRank.queen, LuckyCardSuit.spades);
const int round = 17390003;

class Flips {
  int count = 0;
}

Widget column(Flips flips, {LuckyCardArt art = const FileLuckyCardArt(), String? label}) => LuckyCardCanvas(
      rankColumn: (context, layout) => LuckyCardRevealCard(
        key: const ValueKey('card'),
        layout: layout,
        art: art,
        onFlip: () => flips.count++,
        semanticsLabel: label,
      ),
    );

LuckyCardRevealCardState stateOf(WidgetTester tester) =>
    tester.state<LuckyCardRevealCardState>(find.byType(LuckyCardRevealCard));

Future<void> ms(WidgetTester tester, int millis) => tester.pump(Duration(milliseconds: millis));

void main() {
  setUpAll(loadLuckyCardWheelFonts);

  group('resting', () {
    testWidgets('shows the back of a card, is not settled, and flips nothing', (tester) async {
      final flips = Flips();
      await pumpAtSize(tester, const Size(844, 390), column(flips));
      final s = stateOf(tester);
      expect(find.byKey(const ValueKey('reveal-face-back')), findsOneWidget);
      expect(s.shownCard, isNull);
      expect(s.isSettled, isFalse);
      expect(s.isShuffling, isFalse);
      expect(s.popScale, 1.0);
      await ms(tester, 2000);
      expect(flips.count, 0);
    });
  });

  group('the shuffle follows the plan', () {
    testWidgets('at every moment the face on show is the one the plan says, and a flip is announced for every step', (tester) async {
      final flips = Flips();
      await pumpAtSize(tester, const Size(844, 390), column(flips));
      final s = stateOf(tester);
      final plan = luckyCardRevealPlan(winner: queenSpades, roundNumber: round);

      s.spin(winner: queenSpades, roundNumber: round);
      await tester.pump(); // the animation starts counting at this frame
      expect(s.isShuffling, isTrue);

      var elapsed = 0;
      for (final step in [150, 400, 400, 500, 750, 1000, 800, 700]) {
        await ms(tester, step);
        elapsed += step;
        final want = luckyCardRevealFrameAt(plan, Duration(milliseconds: elapsed));
        expect(s.shownCard, want.visible, reason: 'at $elapsed ms');
        final due = plan.steps.where((p) => p.at <= Duration(milliseconds: elapsed)).length;
        expect(flips.count, due, reason: 'flips announced by $elapsed ms');
      }
      expect(flips.count, 11);
      await ms(tester, 2000);
    });

    testWidgets('the card never shows the winner on its own: after the shuffle it holds the last random face until it is told to settle', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), column(Flips()));
      final s = stateOf(tester);
      s.spin(winner: queenSpades, roundNumber: round);
      await tester.pump();
      await ms(tester, 5200);
      final plan = luckyCardRevealPlan(winner: queenSpades, roundNumber: round);
      expect(s.shownCard, plan.steps.last.face);
      expect(s.shownCard, isNot(queenSpades));
      expect(s.isSettled, isFalse);
      await ms(tester, 6000); // far past the landing: still waiting for the word
      expect(s.shownCard, isNot(queenSpades));
      expect(s.isShuffling, isFalse);
    });

    testWidgets('the faces are real pictures of the 12 cards, one at a time', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), column(Flips()));
      final s = stateOf(tester);
      s.spin(winner: queenSpades, roundNumber: round);
      await tester.pump();
      await ms(tester, 2400);
      final shown = s.shownCard!;
      expect(find.byKey(ValueKey('reveal-face-${shown.key}')), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await ms(tester, 4000);
    });
  });

  group('settling on the winner', () {
    testWidgets('turns over to the winner, then pops, and is settled; asking twice does nothing more', (tester) async {
      final flips = Flips();
      await pumpAtSize(tester, const Size(844, 390), column(flips));
      final s = stateOf(tester);
      s.spin(winner: queenSpades, roundNumber: round);
      await tester.pump();
      await ms(tester, 5000);
      final before = flips.count;
      final lastRandom = s.shownCard;

      s.settle(queenSpades);
      await tester.pump(); // the turn starts counting
      expect(s.isSettled, isTrue);
      expect(flips.count, before + 1, reason: 'one more flip, the turn to the winner');
      await ms(tester, 100);
      expect(s.shownCard, lastRandom, reason: 'the old face until the card is edge-on');
      await ms(tester, 100);
      expect(s.shownCard, queenSpades, reason: 'then the winner');

      // The turn finishes, then the card pops: watch the whole animation.
      var peak = 1.0;
      for (var i = 0; i < 30; i++) {
        await ms(tester, 50);
        peak = peak > s.popScale ? peak : s.popScale;
      }
      expect(peak, greaterThan(1.05), reason: 'the pop');
      expect(peak, lessThanOrEqualTo(1.0801), reason: 'a small pop');
      expect(s.popScale, closeTo(1.0, 0.001), reason: 'back to size');
      expect(s.shownCard, queenSpades);

      s.settle(queenSpades);
      await ms(tester, 500);
      expect(flips.count, before + 1);
    });

    testWidgets('showing the winner at once (a screen that opens late) has no turn and no pop', (tester) async {
      final flips = Flips();
      await pumpAtSize(tester, const Size(844, 390), column(flips));
      final s = stateOf(tester);
      s.showWinner(queenSpades);
      await tester.pump();
      expect(s.shownCard, queenSpades);
      expect(s.isSettled, isTrue);
      expect(s.popScale, 1.0);
      await ms(tester, 800);
      expect(s.popScale, 1.0, reason: 'no pop afterwards');
      expect(flips.count, 0);
    });

    testWidgets('the next round starts over: back to flipping, no longer settled', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), column(Flips()));
      final s = stateOf(tester);
      s.spin(winner: queenSpades, roundNumber: round);
      await tester.pump();
      await ms(tester, 5000);
      s.settle(queenSpades);
      await ms(tester, 1000);
      expect(s.isSettled, isTrue);

      const next = LuckyCard(LuckyCardRank.king, LuckyCardSuit.hearts);
      s.spin(winner: next, roundNumber: round + 1);
      await tester.pump();
      expect(s.isSettled, isFalse);
      expect(s.isShuffling, isTrue);
      expect(s.popScale, 1.0);
      await ms(tester, 5200);
      expect(s.shownCard, luckyCardRevealPlan(winner: next, roundNumber: round + 1).steps.last.face);
      s.settle(next);
      await tester.pump(); // the turn starts counting at this frame
      await ms(tester, 1000);
      expect(s.shownCard, next);
    });
  });

  group('leaving and accessibility', () {
    testWidgets('removed mid-shuffle or mid-turn, nothing throws and nothing is left running', (tester) async {
      final flips = Flips();
      await pumpAtSize(tester, const Size(844, 390), column(flips));
      stateOf(tester).spin(winner: queenSpades, roundNumber: round);
      await tester.pump();
      await ms(tester, 1500);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await ms(tester, 7000);
      expect(tester.takeException(), isNull);

      await pumpAtSize(tester, const Size(844, 390), column(flips));
      stateOf(tester).settle(queenSpades);
      await tester.pump();
      await ms(tester, 150);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await ms(tester, 2000);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a screen reader hears nothing until the winner is known, then the winning card', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), column(Flips()));
      expect(find.bySemanticsLabel(RegExp('Winning card')), findsNothing);
      await pumpAtSize(tester, const Size(844, 390), column(Flips(), label: 'Winning card: Queen of Spades, 4X'));
      expect(find.bySemanticsLabel('Winning card: Queen of Spades, 4X'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the phone font-size setting makes no difference', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), column(Flips()), textScale: 3);
      stateOf(tester).spin(winner: queenSpades, roundNumber: round);
      await tester.pump();
      await ms(tester, 3000);
      expect(tester.takeException(), isNull);
      await ms(tester, 3000);
    });
  });

  group('it fits every device of the matrix', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): the card is where the layout puts it, back, mid-shuffle and settled, with no overflow', (tester) async {
        await pumpAtSize(tester, d.size, column(Flips()));
        final layout = LuckyCardLayout.of(d.size);
        final want = layout.revealCard.shift(layout.canvasRect.topLeft);
        Rect box() => tester.getRect(find.byKey(const ValueKey('reveal-face-back')).evaluate().isNotEmpty
            ? find.byKey(const ValueKey('reveal-face-back'))
            : find.byType(Image));
        expect(box().width, closeTo(want.width, 0.01));
        expect(box().center.dx, closeTo(want.center.dx, 0.01));
        expect(box().center.dy, closeTo(want.center.dy, 0.01));
        expect(want.width, greaterThanOrEqualTo(layout.rankColumn.width * 0.9));

        final s = stateOf(tester);
        s.spin(winner: queenSpades, roundNumber: round);
        await tester.pump();
        await ms(tester, 2500);
        expect(tester.takeException(), isNull, reason: 'mid-shuffle');
        expect(box().width, closeTo(want.width, 0.01));
        await ms(tester, 3000);
        s.settle(queenSpades);
        await tester.pump();
        await ms(tester, 1000);
        expect(tester.takeException(), isNull, reason: 'settled');
        expect(box().center.dx, closeTo(want.center.dx, 0.01));
      });
    }
  });

  group('pictures to look at, with the real artwork', () {
    Widget scene(LuckyCardArt art) => LuckyCardCanvas(
          rankColumn: (context, layout) => LuckyCardRevealCard(key: const ValueKey('card'), layout: layout, art: art),
        );

    Future<void> shot(WidgetTester tester, String name) =>
        expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

    testWidgets('the card back, 915x412', (tester) async {
      final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
      await pumpAtSize(tester, const Size(915, 412), scene(art));
      await tester.pump();
      await shot(tester, 'reveal_back_915x412');
    });

    testWidgets('two seconds into the shuffle, 915x412', (tester) async {
      final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
      await pumpAtSize(tester, const Size(915, 412), scene(art));
      stateOf(tester).spin(winner: queenSpades, roundNumber: round);
      await tester.pump();
      await ms(tester, 2100);
      await shot(tester, 'reveal_shuffling_915x412');
      await ms(tester, 4000);
    });

    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets('settled on Q♠, ${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) async {
        final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
        await pumpAtSize(tester, d.size, scene(art));
        final s = stateOf(tester);
        s.spin(winner: queenSpades, roundNumber: round);
        await tester.pump();
        await ms(tester, 5000);
        s.settle(queenSpades);
        await tester.pump();
        await ms(tester, 1200);
        await shot(tester, 'reveal_settled_${d.width.toInt()}x${d.height.toInt()}');
      });
    }
  });
}
