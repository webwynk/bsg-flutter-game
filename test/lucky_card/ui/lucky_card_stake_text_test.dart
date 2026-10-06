// Tests for lib/widgets/lucky_card/lucky_card_stake_text.dart: what the numbers
// say, and how they are sized.

import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_stake_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

const TextStyle style = TextStyle(fontFamily: 'Oswald', fontWeight: FontWeight.w500, height: 1.0);

double widthAt(String text, double size) {
  final p = TextPainter(
    text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
    textDirection: TextDirection.ltr,
  )..layout();
  final w = p.width;
  p.dispose();
  return w;
}

void main() {
  setUpAll(loadLuckyCardFonts);

  group('what the numbers say (the user, 2026-10-06)', () {
    test('a card with no coins says "Play"; with coins, the amount in full', () {
      expect(luckyCardRibbonLabel(0), 'Play');
      expect(luckyCardRibbonLabel(-5), 'Play');
      expect(luckyCardRibbonLabel(5), '5');
      expect(luckyCardRibbonLabel(15), '15');
      expect(luckyCardRibbonLabel(50000), '50000', reason: 'no separators, no abbreviation on a card');
      expect(luckyCardPlayWord, 'Play');
    });

    test('a suit bar with nothing on it says nothing; otherwise the total in full', () {
      expect(luckyCardSuitLabel(0), '');
      expect(luckyCardSuitLabel(35), '35');
      expect(luckyCardSuitLabel(150000), '150000');
    });

    test('a rank disc says nothing at 0, the number below 100,000, and whole thousands with a K from 100,000', () {
      expect(luckyCardRankLabel(0), '');
      expect(luckyCardRankLabel(30), '30');
      expect(luckyCardRankLabel(99999), '99999');
      expect(luckyCardRankLabel(100000), '100K');
      expect(luckyCardRankLabel(100999), '100K', reason: 'rounded down');
      expect(luckyCardRankLabel(123500), '123K');
      expect(luckyCardRankLabel(200000), '200K');
    });
  });

  group('the fit rule', () {
    test('text that fits keeps the preferred size', () {
      final size = fitLuckyCardFontSize(text: '15', style: style, maxWidth: 80, preferred: 14);
      expect(size, 14);
    });

    test('text that is too wide shrinks until it fits', () {
      // A slot 60% as wide as the text is at 30 dp: some size between 11 and 30
      // fits, whatever the font.
      final slot = widthAt('12345', 30) * 0.6;
      final size = fitLuckyCardFontSize(text: '12345', style: style, maxWidth: slot, preferred: 30);
      expect(size, lessThan(30));
      expect(size, greaterThanOrEqualTo(kLuckyCardMinReadableDp));
      expect(widthAt('12345', size), lessThanOrEqualTo(slot + 0.5));
    });

    test('it never goes below 11 dp: at the minimum the text is allowed to be wider than its slot', () {
      final size = fitLuckyCardFontSize(text: '200000', style: style, maxWidth: 5, preferred: 30);
      expect(size, kLuckyCardMinReadableDp);
      expect(widthAt('200000', size), greaterThan(5));
    });

    test('a preferred size under 11 is raised to 11', () {
      expect(fitLuckyCardFontSize(text: '5', style: style, maxWidth: 100, preferred: 6), kLuckyCardMinReadableDp);
    });

    test('an empty text or a slot of no width does not break it', () {
      expect(fitLuckyCardFontSize(text: '', style: style, maxWidth: 40, preferred: 20), 20);
      expect(fitLuckyCardFontSize(text: '50', style: style, maxWidth: 0, preferred: 20), 20);
    });

    test('a longer text never gets a larger size than a shorter one', () {
      var previous = double.infinity;
      for (final t in ['5', '50', '500', '5000', '50000', '500000']) {
        final s = fitLuckyCardFontSize(text: t, style: style, maxWidth: 40, preferred: 24);
        expect(s, lessThanOrEqualTo(previous), reason: t);
        previous = s;
      }
    });
  });

  group('the widget', () {
    testWidgets('shows its text centred in its slot at no less than 11 dp, and nothing for an empty text', (tester) async {
      await pumpAtSize(
        tester,
        const Size(400, 200),
        const Center(
          child: SizedBox(
            width: 60,
            height: 20,
            child: LuckyCardStakeText('15', key: Key('t'), maxWidth: 60, preferredSize: 8),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text('15'));
      expect(text.style!.fontSize, greaterThanOrEqualTo(kLuckyCardMinReadableDp));
      expect(tester.getCenter(find.text('15')).dx, closeTo(200, 0.5));

      await pumpAtSize(tester, const Size(400, 200), const LuckyCardStakeText('', maxWidth: 60, preferredSize: 12));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('a number wider than its slot runs over instead of overflowing or being cut', (tester) async {
      await pumpAtSize(
        tester,
        const Size(400, 200),
        const Center(child: SizedBox(width: 20, height: 14, child: LuckyCardStakeText('200000', maxWidth: 20, preferredSize: 12))),
      );
      expect(tester.takeException(), isNull, reason: 'no overflow error');
      expect(tester.getSize(find.text('200000')).width, greaterThan(20));
    });

    testWidgets("the phone's font-size setting has no effect", (tester) async {
      Future<double> sizeAt(double scale) async {
        await pumpAtSize(
          tester,
          const Size(400, 200),
          const Center(child: SizedBox(width: 60, height: 20, child: LuckyCardStakeText('15', maxWidth: 60, preferredSize: 14))),
          textScale: scale,
        );
        return tester.getSize(find.text('15')).width;
      }

      final a = await sizeAt(0.5);
      final b = await sizeAt(1);
      final c = await sizeAt(3);
      expect(a, b);
      expect(b, c);
    });
  });
}
