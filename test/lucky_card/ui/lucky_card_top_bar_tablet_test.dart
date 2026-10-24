// Tests for the header on the tablet arrangement (tablet step T3, spec §17BN): the same flat bar as
// the phone, with the sizes of LuckyCardLayout.tablet. Checked at the six sizes of the reference
// design's tablet files, with the hardest balance and the longest words the header ever shows.

import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_palette.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lucky_card_layout_tablet_test.dart' show kTabletReferenceSizes;
import 'ui_harness.dart';

class Taps {
  int exit = 0, sound = 0, info = 0, history = 0;
}

Widget header({
  LuckyCardArt art = const FileLuckyCardArt(),
  int balance = 12345,
  int countdown = 47,
  bool soundOn = true,
  bool infoEnabled = true,
  String words = 'Place your chips',
  Color wordsColor = kDesignStatusText,
  Taps? taps,
  EdgeInsets bleed = EdgeInsets.zero,
}) =>
    LuckyCardCanvas(
      layoutOf: LuckyCardLayout.tablet,
      topBar: (context, layout) => LuckyCardTopBar(
        layout: layout,
        art: art,
        balance: balance,
        countdown: countdown,
        soundOn: soundOn,
        infoEnabled: infoEnabled,
        bleed: bleed,
        statusWidget: LuckyCardStatusLine(key: const ValueKey('top-status'), text: words, size: layout.designStatusFont, color: wordsColor, flashing: false),
        onExit: taps == null ? null : () => taps.exit++,
        onToggleSound: taps == null ? null : () => taps.sound++,
        onInfo: taps == null ? null : () => taps.info++,
        onHistory: taps == null ? null : () => taps.history++,
      ),
    );

Rect rectOf(WidgetTester tester, String key) => tester.getRect(find.byKey(ValueKey(key)));

/// The size of the tap area of a header ball.
Size hitOf(WidgetTester tester, String key) =>
    tester.getSize(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(GestureDetector)).first);

void main() {
  setUpAll(() async {
    await loadLuckyCardFonts();
    await loadLuckyCardIcons();
  });

  group('the header at the six reference tablet sizes', () {
    for (final d in kTabletReferenceSizes) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): the flat bar, every piece in its place, 48 dp tap areas, 11 dp text, no overflow', (tester) async {
        await pumpAtSize(tester, d.size, header(taps: Taps()));
        expect(tester.takeException(), isNull, reason: 'no overflow or error');
        final l = LuckyCardLayout.tablet(d.size);

        // The bar: flat, full width, flush with the top, the height the layout gives.
        final back = rectOf(tester, 'top-bar-back');
        expect(back.left, 0, reason: 'flush left');
        expect(back.top, 0, reason: 'flush top');
        expect(back.width, closeTo(d.width, 0.01), reason: 'full width');
        expect(back.height, closeTo(l.designHeaderHeight, 0.01));
        final row = rectOf(tester, 'top-bar');
        expect(row, l.designHeaderBar);

        // The balls are drawn at the layout's size inside tap areas of at least 48 dp, centred in the bar.
        for (final k in ['top-exit', 'top-history', 'top-sound', 'top-info']) {
          final hit = hitOf(tester, k);
          expect(hit.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: '$k width');
          expect(hit.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: '$k height');
          expect(hit.width, closeTo(l.designBallHit, 0.01), reason: k);
          final r = rectOf(tester, k);
          expect(r.center.dy, closeTo(row.center.dy, 0.6), reason: '$k centred in the bar');
          expect(r.top, greaterThanOrEqualTo(row.top - 0.5), reason: '$k inside the bar');
          expect(r.bottom, lessThanOrEqualTo(row.bottom + 0.5), reason: '$k inside the bar');
        }
        // The ball itself is drawn at designBallSize (the AnimatedContainer inside the tap area).
        final ball = tester.getSize(find.descendant(of: find.byKey(const ValueKey('top-exit')), matching: find.byType(AnimatedContainer)));
        expect(ball.width, closeTo(l.designBallSize, 0.01));

        // The pill, the coin and the countdown disc are the layout's sizes and sit inside the bar.
        expect(rectOf(tester, 'top-balance').height, closeTo(l.designPillHeight, 0.01));
        final coin = tester.getSize(find.byKey(const ValueKey('top-coin')));
        expect(coin.width, closeTo(l.designCoinSize, 0.01));
        expect(coin.height, closeTo(l.designCoinSize, 0.01));
        final disc = rectOf(tester, 'top-countdown').size;
        expect(disc.width, closeTo(l.designCountdownSize, 0.01));
        expect(disc.height, closeTo(l.designCountdownSize, 0.01));
        for (final k in ['top-balance', 'top-countdown', 'top-status']) {
          final r = rectOf(tester, k);
          expect(r.top, greaterThanOrEqualTo(row.top - 0.5), reason: '$k inside the bar');
          expect(r.bottom, lessThanOrEqualTo(row.bottom + 0.5), reason: '$k inside the bar');
        }

        // Left to right: exit, balance, countdown, words, history, sound, info; none on another; the
        // content kept 30 dp in from each edge, as on the phone.
        final order = ['top-exit', 'top-balance', 'top-countdown', 'top-status', 'top-history', 'top-sound', 'top-info'].map((k) => rectOf(tester, k)).toList();
        for (var i = 1; i < order.length; i++) {
          expect(order[i].left, greaterThanOrEqualTo(order[i - 1].right - 0.01), reason: 'piece $i is right of piece ${i - 1}');
        }
        expect(order.first.left, closeTo(30, 0.01), reason: '30 dp in from the left');
        expect(d.width - order.last.right, closeTo(30, 0.6), reason: '30 dp in from the right');

        // The disc and the words are in the middle of what is left, as a group.
        final group = Rect.fromLTRB(rectOf(tester, 'top-countdown').left, row.top, rectOf(tester, 'top-status').right, row.bottom);
        final free = Rect.fromLTRB(order[1].right, row.top, order[4].left, row.bottom);
        expect(group.center.dx, closeTo(free.center.dx, 2), reason: 'disc and words centred between the balance and the buttons');

        // No text under 11 dp; the countdown's digits fit inside the disc.
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          expect(t.style!.fontSize, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: '"${t.data}"');
          expect(t.textScaler, TextScaler.noScaling);
        }
        final digits = tester.getRect(find.descendant(of: find.byKey(const ValueKey('top-countdown')), matching: find.byType(Text)));
        expect(digits.width, lessThan(l.designCountdownSize * 0.82), reason: 'the digits fit the disc');
        expect(digits.height, lessThan(l.designCountdownSize * 0.82));
      });

      testWidgets('${d.name}: the hardest content: a balance of 98,765,432 and the longest warning, still no overflow and nothing on top of anything', (tester) async {
        await pumpAtSize(tester, d.size, header(balance: 98765432, countdown: 5, words: 'Card at 50,000 limit', wordsColor: kDesignAlertText, taps: Taps()));
        expect(tester.takeException(), isNull);
        final order = ['top-exit', 'top-balance', 'top-countdown', 'top-status', 'top-history', 'top-sound', 'top-info'].map((k) => rectOf(tester, k)).toList();
        for (var i = 1; i < order.length; i++) {
          expect(order[i].left, greaterThanOrEqualTo(order[i - 1].right - 0.01), reason: 'piece $i clear of piece ${i - 1}');
        }
        final balance = rectOf(tester, 'top-balance');
        final figure = tester.getRect(find.descendant(of: find.byKey(const ValueKey('top-balance')), matching: find.text('98,765,432')));
        expect(figure.right, lessThanOrEqualTo(balance.right + 0.5), reason: 'the whole balance is inside its pill');
        expect(find.text('CARD AT 50,000 LIMIT'), findsOneWidget);
      });
    }
  });

  group('the balls work', () {
    testWidgets('a tap anywhere in a ball\'s tap area works, EXIT and SOUND always, RULES and HISTORY only while betting is open', (tester) async {
      const size = Size(1280, 800);
      final taps = Taps();
      await pumpAtSize(tester, size, header(taps: taps));
      for (final k in ['top-exit', 'top-sound', 'top-info', 'top-history']) {
        final r = rectOf(tester, k);
        await tester.tapAt(r.topLeft + const Offset(2, 2));
        await tester.tapAt(r.bottomRight - const Offset(2, 2));
        await tester.pump();
      }
      expect([taps.exit, taps.sound, taps.info, taps.history], [2, 2, 2, 2]);

      final closed = Taps();
      await pumpAtSize(tester, size, header(taps: closed, infoEnabled: false));
      for (final k in ['top-exit', 'top-sound', 'top-info', 'top-history']) {
        await tester.tap(find.byKey(ValueKey(k)));
        await tester.pump();
      }
      expect([closed.exit, closed.sound, closed.info, closed.history], [1, 1, 0, 0], reason: 'RULES and HISTORY are dimmed and ignore taps');
    });

    testWidgets('the bar bleeds up and to the sides under a status bar or a camera cut-out, content staying inside', (tester) async {
      const size = Size(1180, 820);
      await pumpAtSize(tester, size, header(bleed: const EdgeInsets.only(left: 20, top: 24, right: 20)));
      final back = rectOf(tester, 'top-bar-back');
      expect(back.left, -20);
      expect(back.top, -24);
      expect(back.right, closeTo(size.width + 20, 0.01));
      expect(rectOf(tester, 'top-bar').top, 0, reason: 'the row itself did not move');
    });
  });

  group('a picture to look at, with the real artwork', () {
    for (final d in const [Device('android tablet', 1024, 600), Device('ipad air', 1180, 820), Device('ipad pro 12.9', 1366, 1024)]) {
      testWidgets('${d.name} ${d.width.toInt()}x${d.height.toInt()}: the header, betting open', (tester) async {
        final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
        await pumpAtSize(tester, d.size, header(art: art, balance: 129695, taps: Taps()));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tablet_header_${d.width.toInt()}x${d.height.toInt()}.png'));
      });
    }

    testWidgets('ipad air 1180x820: the header, betting closed, the hardest content', (tester) async {
      const d = Device('ipad air', 1180, 820);
      final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
      await pumpAtSize(tester, d.size, header(art: art, balance: 98765432, countdown: 3, infoEnabled: false, soundOn: false, words: 'No more play', wordsColor: kDesignAlertText, taps: Taps()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tablet_header_closed_1180x820.png'));
    });
  });
}
