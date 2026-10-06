// Tests for lib/widgets/lucky_card/lucky_card_win_popup.dart: the amount, the winning
// card and its bonus, in the frame of Triple Chance's popup, on every device of the
// matrix; blocking everything behind it; and the screenshots.

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_win_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

const LuckyCard queenSpades = LuckyCard(LuckyCardRank.queen, LuckyCardSuit.spades);

LuckyCardOutcome outcome({int payout = 400, int bonus = 4, LuckyCard card = queenSpades, int stake = 120}) =>
    LuckyCardOutcome(
      roundId: 'round-1',
      winningCard: card,
      bonusMultiplier: bonus,
      stake: stake,
      payout: payout,
    );

Widget popup(LuckyCardOutcome o, {LuckyCardArt art = const FileLuckyCardArt()}) => LuckyCardCanvas(
      overlay: (context, layout) => LuckyCardWinPopup(outcome: o, layout: layout, art: art),
    );

Future<void> ms(WidgetTester tester, int millis) => tester.pump(Duration(milliseconds: millis));

Rect rectOf(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

void main() {
  setUpAll(loadLuckyCardWheelFonts);

  group('what it says', () {
    testWidgets('the amount, the winning card and its bonus, with the title', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), popup(outcome()));
      await ms(tester, 500);
      expect(find.byKey(const ValueKey('win-title')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('win-amount'))).data, '400');
      expect(tester.widget<Text>(find.byKey(const ValueKey('win-bonus'))).data, '4X');
      expect(find.byKey(const ValueKey('win-card-q_spades')), findsOneWidget);
    });

    testWidgets('with no bonus only the card is shown, centred, and no "N" is written', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), popup(outcome(bonus: 1, payout: 100)));
      await ms(tester, 500);
      expect(find.byKey(const ValueKey('win-bonus')), findsNothing);
      expect(find.text('N'), findsNothing);
      final popupBox = rectOf(tester, const ValueKey('win-amount-box'));
      final card = rectOf(tester, const ValueKey('win-card-q_spades'));
      expect(card.center.dx, closeTo(popupBox.center.dx, 1.0), reason: 'alone, the card is centred');
    });

    testWidgets('with a bonus the card and the bonus are centred together, the bonus to the right', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), popup(outcome()));
      await ms(tester, 500);
      final box = rectOf(tester, const ValueKey('win-amount-box'));
      final card = rectOf(tester, const ValueKey('win-card-q_spades'));
      final bonus = rectOf(tester, const ValueKey('win-bonus'));
      expect(bonus.left, greaterThan(card.right));
      expect((card.left + bonus.right) / 2, closeTo(box.center.dx, 1.5), reason: 'the pair is centred');
    });

    testWidgets('every card and every bonus from 2X to 10X shows what it is', (tester) async {
      for (final bonus in [2, 5, 10]) {
        final card = LuckyCard.all[bonus];
        await pumpAtSize(tester, const Size(844, 390), popup(outcome(bonus: bonus, card: card)));
        await ms(tester, 500);
        expect(tester.widget<Text>(find.byKey(const ValueKey('win-bonus'))).data, '${bonus}X');
        expect(find.byKey(ValueKey('win-card-${card.key}')), findsOneWidget);
      }
    });
  });

  group('it fits every device of the matrix', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): inside the canvas, the pieces in order and apart, text at least 11 dp, the largest amount fits', (tester) async {
        // The largest possible payout: 50,000 on a card, 10 times, with a 10X bonus.
        await pumpAtSize(tester, d.size, popup(outcome(payout: 5000000, bonus: 10)));
        await ms(tester, 500);
        expect(tester.takeException(), isNull);
        final layout = LuckyCardLayout.of(d.size);
        final frame = layout.winPopup.shift(layout.canvasRect.topLeft);

        final title = rectOf(tester, const ValueKey('win-title'));
        final box = rectOf(tester, const ValueKey('win-amount-box'));
        final amount = rectOf(tester, const ValueKey('win-amount'));
        final card = rectOf(tester, const ValueKey('win-card-q_spades'));
        final bonus = rectOf(tester, const ValueKey('win-bonus'));

        for (final r in [title, box, card, bonus]) {
          expect(r.left, greaterThanOrEqualTo(frame.left - 0.5));
          expect(r.right, lessThanOrEqualTo(frame.right + 0.5));
          expect(r.top, greaterThanOrEqualTo(frame.top - 0.5));
          expect(r.bottom, lessThanOrEqualTo(frame.bottom + 0.5));
        }
        expect(title.bottom, lessThanOrEqualTo(box.top + 0.5), reason: 'title above the amount');
        expect(box.bottom, lessThanOrEqualTo(card.top + 0.5), reason: 'amount above the card');
        expect(amount.width, lessThanOrEqualTo(box.width), reason: '5,000,000 fits its box');
        expect(amount.height, lessThanOrEqualTo(box.height));

        for (final key in const [ValueKey('win-amount'), ValueKey('win-bonus')]) {
          expect(tester.widget<Text>(find.byKey(key)).style!.fontSize, greaterThanOrEqualTo(kLuckyCardMinReadableDp - 0.001), reason: '$key');
        }
        expect(frame.width, lessThanOrEqualTo(layout.canvasRect.width * 0.92 + 0.5));
      });
    }
  });

  group('behaviour', () {
    testWidgets('it enters: faint and small at first, then full size after 400 ms', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), popup(outcome()));
      final opacityAtStart = tester.widget<Opacity>(find.descendant(of: find.byType(LuckyCardWinPopup), matching: find.byType(Opacity))).opacity;
      expect(opacityAtStart, lessThan(0.2));
      await ms(tester, 100);
      final opacityMid = tester.widget<Opacity>(find.descendant(of: find.byType(LuckyCardWinPopup), matching: find.byType(Opacity))).opacity;
      expect(opacityMid, inExclusiveRange(0.2, 0.9), reason: 'part-way through the fade');
      final midWidth = rectOf(tester, const ValueKey('win-title')).width;
      await ms(tester, 350);
      final opacityAtEnd = tester.widget<Opacity>(find.descendant(of: find.byType(LuckyCardWinPopup), matching: find.byType(Opacity))).opacity;
      expect(opacityAtEnd, 1.0);
      final layout = LuckyCardLayout.of(const Size(844, 390));
      final fullWidth = rectOf(tester, const ValueKey('win-title')).width;
      expect(fullWidth, closeTo(layout.winPopup.width * 0.68, 1.0), reason: 'full size');
      expect(midWidth, lessThan(fullWidth * 0.95), reason: 'smaller part-way through');
      expect(midWidth, greaterThan(fullWidth * 0.5), reason: 'it never goes below half size');
    });

    testWidgets('it blocks everything behind it: a tap on the zones underneath never reaches them', (tester) async {
      var taps = 0;
      // Two zones that count taps, with and without the popup over them.
      Widget scene({required bool withPopup}) => LuckyCardCanvas(
            grid: (context, l) => GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++),
            side: (context, l) => GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++),
            overlay: withPopup ? (context, l) => LuckyCardWinPopup(outcome: outcome(), layout: l, art: const FileLuckyCardArt()) : null,
          );
      final layout = LuckyCardLayout.of(const Size(844, 390));
      final origin = layout.canvasRect.topLeft;
      final inGrid = layout.grid.center + origin;
      final inSide = layout.side.center + origin;

      // Control: with no popup the zones do get the taps.
      await pumpAtSize(tester, const Size(844, 390), scene(withPopup: false));
      await tester.tapAt(inGrid);
      await tester.tapAt(inSide);
      expect(taps, 2, reason: 'the zones are tappable when nothing covers them');

      // With the popup over them, they get nothing.
      taps = 0;
      await pumpAtSize(tester, const Size(844, 390), scene(withPopup: true));
      await ms(tester, 500);
      await tester.tapAt(inGrid);
      await tester.tapAt(inSide);
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('win-amount-box'))));
      expect(taps, 0, reason: 'the popup blocks everything behind it');
    });


    testWidgets('on a tablet the dimmed backdrop covers the whole screen, not just the smaller canvas', (tester) async {
      await pumpAtSize(tester, const Size(1024, 768), popup(outcome()));
      await ms(tester, 500);
      expect(LuckyCardLayout.of(const Size(1024, 768)).canvasRect.top, greaterThan(0), reason: 'the canvas is smaller than the screen here');
      expect(tester.getRect(find.byType(BackdropFilter)), const Rect.fromLTWH(0, 0, 1024, 768));
    });


    testWidgets('it has no button to dismiss it', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), popup(outcome()));
      await ms(tester, 500);
      expect(find.byType(GestureDetector), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('a screen reader hears the win at once, with the card and the bonus', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), popup(outcome()));
      expect(find.bySemanticsLabel('You won 400 coins. Winning card Queen of Spades, 4X'), findsOneWidget);
      await pumpAtSize(tester, const Size(844, 390), popup(outcome(bonus: 1)));
      expect(find.bySemanticsLabel('You won 400 coins. Winning card Queen of Spades'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the phone font-size setting changes nothing', (tester) async {
      Future<double> amountWidth(double scale) async {
        await pumpAtSize(tester, const Size(844, 390), popup(outcome()), textScale: scale);
        await ms(tester, 500);
        return tester.getSize(find.byKey(const ValueKey('win-amount'))).width;
      }

      final a = await amountWidth(0.5);
      final b = await amountWidth(1);
      final c = await amountWidth(3);
      expect(a, b);
      expect(b, c);
    });

    testWidgets('taken off the screen in the middle of its entrance, nothing is left running', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), popup(outcome()));
      await ms(tester, 150);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await ms(tester, 1000);
      expect(tester.takeException(), isNull);
    });
  });

  group('pictures to look at, with the real artwork and fonts', () {
    Future<void> shot(WidgetTester tester, String name) =>
        expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets('Q♠ with 4X and 400 won, ${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) async {
        final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
        await pumpAtSize(tester, d.size, popup(outcome(), art: art));
        await ms(tester, 600);
        await shot(tester, 'win_popup_${d.width.toInt()}x${d.height.toInt()}');
      });
    }

    testWidgets('no bonus, 915x412', (tester) async {
      final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
      await pumpAtSize(
        tester,
        const Size(915, 412),
        popup(outcome(bonus: 1, payout: 100, card: const LuckyCard(LuckyCardRank.king, LuckyCardSuit.hearts)), art: art),
      );
      await ms(tester, 600);
      await shot(tester, 'win_popup_nobonus_915x412');
    });
  });
}
