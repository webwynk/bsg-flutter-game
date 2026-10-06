// Tests for the Lucky Card top bar, status strip and side-column readouts
// (lucky_card_top_bar.dart, lucky_card_status_strip.dart, lucky_card_readouts.dart).
//
// What the player reads: the balance, the countdown, the words under the board,
// PLAY and WIN, the limits and the ten latest results. Everything is checked on every
// device of the matrix: where it sits, that each button has a tap area of at least
// 48 dp, that no text is smaller than 11 dp, that nothing overflows, and that the
// phone's font-size setting changes nothing. The pieces here are given plain values;
// the provider-driven behaviour is in lucky_card_readouts_binding_test.dart.

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_panel.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_readouts.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_status_strip.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

LuckyCardRecentRound round(int n, LuckyCardRank rank, LuckyCardSuit suit, int bonus) => LuckyCardRecentRound(
      roundId: 'r$n',
      roundNumber: n,
      winningCard: LuckyCard(rank, suit),
      bonusMultiplier: bonus,
      scheduledAt: DateTime.utc(2026, 10, 6, 12, 0, n),
    );

/// Ten rounds, newest first: the latest is the Queen of Spades with a 4X bonus.
final List<LuckyCardRecentRound> ten = [
  round(10, LuckyCardRank.queen, LuckyCardSuit.spades, 4),
  round(9, LuckyCardRank.jack, LuckyCardSuit.hearts, 1),
  round(8, LuckyCardRank.king, LuckyCardSuit.diamonds, 10),
  round(7, LuckyCardRank.queen, LuckyCardSuit.clubs, 2),
  round(6, LuckyCardRank.jack, LuckyCardSuit.spades, 1),
  round(5, LuckyCardRank.king, LuckyCardSuit.hearts, 3),
  round(4, LuckyCardRank.queen, LuckyCardSuit.diamonds, 1),
  round(3, LuckyCardRank.jack, LuckyCardSuit.clubs, 7),
  round(2, LuckyCardRank.king, LuckyCardSuit.spades, 1),
  round(1, LuckyCardRank.jack, LuckyCardSuit.diamonds, 5),
];

class Taps {
  int exit = 0, sound = 0, info = 0;
}

/// The screen as the Step 7a pieces build it: the top bar, the status strip, and
/// PLAY, WIN, the limits and the results in the side column.
Widget scene({
  LuckyCardArt art = const FileLuckyCardArt(),
  int balance = 12345,
  int countdown = 47,
  bool soundOn = true,
  bool infoEnabled = true,
  LuckyCardStatusMode mode = LuckyCardStatusMode.placeChips,
  int play = 150,
  int win = 0,
  List<LuckyCardRecentRound>? history,
  Taps? taps,
}) {
  final rounds = history ?? ten;
  return LuckyCardCanvas(
    topBar: (context, layout) => LuckyCardTopBar(
      layout: layout,
      balance: balance,
      countdown: countdown,
      soundOn: soundOn,
      infoEnabled: infoEnabled,
      onExit: taps == null ? null : () => taps.exit++,
      onToggleSound: taps == null ? null : () => taps.sound++,
      onInfo: taps == null ? null : () => taps.info++,
    ),
    status: (context, layout) => LuckyCardStatusStrip(layout: layout, mode: mode),
    side: (context, layout) {
      Rect inSide(Rect r) => layout.within(layout.side, r);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(
            rect: inSide(layout.playCell),
            child: LuckyCardAmountCell(key: const ValueKey('play'), layout: layout, label: 'PLAY', value: luckyCardGrouped(play)),
          ),
          Positioned.fromRect(
            rect: inSide(layout.winCell),
            child: LuckyCardAmountCell(
              key: const ValueKey('win'),
              layout: layout,
              label: 'WIN',
              value: luckyCardWinText(win),
              valueColor: win > 0 ? kLuckyCardWin : kLuckyCardCream,
              highlighted: win > 0,
            ),
          ),
          Positioned.fromRect(
            rect: inSide(layout.limitsPanel),
            child: LuckyCardLimitsPanel(key: const ValueKey('limits'), layout: layout),
          ),
          Positioned.fromRect(
            rect: inSide(layout.resultsPanel),
            child: LuckyCardResultsPanel(key: const ValueKey('results'), layout: layout, art: art, history: rounds),
          ),
        ],
      );
    },
  );
}

/// Where a piece the layout places should be on the screen.
Rect onScreen(LuckyCardLayout l, Rect inCanvas) => inCanvas.shift(l.canvasRect.topLeft);

Rect rectOf(WidgetTester tester, String key) => tester.getRect(find.byKey(ValueKey(key)));

/// The smallest text size on the screen.
double smallestText(WidgetTester tester, [Finder? within]) {
  final texts = within == null ? find.byType(Text) : find.descendant(of: within, matching: find.byType(Text));
  var smallest = double.infinity;
  for (final t in tester.widgetList<Text>(texts)) {
    final size = t.style?.fontSize;
    expect(size, isNotNull, reason: 'every Lucky Card text sets its own size: "${t.data}"');
    if (size! < smallest) smallest = size;
  }
  return smallest;
}

List<String> textsIn(WidgetTester tester, Finder within) => [
      for (final t in tester.widgetList<Text>(find.descendant(of: within, matching: find.byType(Text)))) t.data!,
    ];

void main() {
  setUpAll(() async {
    await loadLuckyCardFonts();
    await loadLuckyCardIcons();
  });

  group('the words and numbers (pure)', () {
    test('the countdown is two digits, and red from 5 to 1 only', () {
      expect(luckyCardCountdownText(90), '90');
      expect(luckyCardCountdownText(7), '07');
      expect(luckyCardCountdownText(0), '00');
      expect(luckyCardCountdownText(-3), '00');
      expect(luckyCardCountdownText(250), '99');
      expect([for (var s = 0; s <= 8; s++) luckyCardCountdownUrgent(s)], [false, true, true, true, true, true, false, false, false]);
    });

    test('numbers are grouped by thousands', () {
      expect(luckyCardGrouped(0), '0');
      expect(luckyCardGrouped(999), '999');
      expect(luckyCardGrouped(1000), '1,000');
      expect(luckyCardGrouped(50000), '50,000');
      expect(luckyCardGrouped(500000), '500,000');
      expect(luckyCardGrouped(1234567), '1,234,567');
      expect(luckyCardGrouped(-1234), '-1,234');
    });

    test('WIN reads +amount for a win and 0 for anything else', () {
      expect(luckyCardWinText(1500), '+1,500');
      expect(luckyCardWinText(0), '0');
      expect(luckyCardWinText(-5), '0');
    });

    test('the status words', () {
      expect(luckyCardStatusText(LuckyCardStatusMode.placeChips), 'PLACE YOUR CHIPS');
      expect(luckyCardStatusText(LuckyCardStatusMode.noMoreFlashing), 'NO MORE PLAY');
      expect(luckyCardStatusText(LuckyCardStatusMode.noMoreSteady), 'NO MORE PLAY');
    });

    test('the limits are the spec numbers: the stake pays ten times, before the bonus', () {
      expect(LuckyCardLimits.minIn, 5);
      expect(LuckyCardLimits.minOut, 50);
      expect(LuckyCardLimits.maxIn, 50000);
      expect(LuckyCardLimits.maxOut, 500000);
      expect(LuckyCardLimits.minOut, LuckyCardLimits.minIn * 10);
      expect(LuckyCardLimits.maxOut, LuckyCardLimits.maxIn * 10);
    });

    test('a result is read out with its rank, suit and bonus', () {
      expect(luckyCardResultSemantics(ten[0]), 'Queen of Spades, bonus 4X');
      expect(luckyCardResultSemantics(ten[1]), 'Jack of Hearts, no bonus');
      expect(luckyCardResultRank(ten[2].winningCard), 'K');
    });
  });

  group('every device of the matrix', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): everything where the layout puts it, with 48 dp buttons, 11 dp text and no overflow', (tester) async {
        await pumpAtSize(tester, d.size, scene(taps: Taps()));
        final l = LuckyCardLayout.of(d.size);
        expect(tester.takeException(), isNull, reason: 'no overflow or error');

        // Each piece is exactly where the layout says.
        Map<String, Rect> expected = {
          'top-exit': l.exitHit,
          'top-sound': l.soundHit,
          'top-info': l.infoHit,
          'top-balance': l.balanceBox,
          'top-countdown': l.countdownBox,
          'play': l.playCell,
          'win': l.winCell,
          'limits': l.limitsPanel,
          'results': l.resultsPanel,
          'result-latest': l.resultCurrent,
          for (var i = 0; i < 9; i++) 'result-$i': l.resultTile(i),
        };
        for (final e in expected.entries) {
          final got = rectOf(tester, e.key);
          final want = onScreen(l, e.value);
          expect(got.left, closeTo(want.left, 0.01), reason: '${e.key} left');
          expect(got.top, closeTo(want.top, 0.01), reason: '${e.key} top');
          expect(got.width, closeTo(want.width, 0.01), reason: '${e.key} width');
          expect(got.height, closeTo(want.height, 0.01), reason: '${e.key} height');
        }

        // The three buttons' tap areas are at least 48 dp each way.
        for (final key in ['top-exit', 'top-sound', 'top-info']) {
          final hit = tester.getSize(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(GestureDetector)).first);
          expect(hit.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: '$key width');
          expect(hit.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: '$key height');
        }

        // No text under 11 dp, and no icon under 14 dp.
        expect(smallestText(tester), greaterThanOrEqualTo(kLuckyCardMinReadableDp));
        for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
          expect(icon.size, greaterThanOrEqualTo(14));
        }
      });
    }
  });

  group('the font-size setting of the phone changes nothing', () {
    testWidgets('at 3 times the text, every text keeps its size and every box its place', (tester) async {
      const size = Size(640, 360);
      await pumpAtSize(tester, size, scene());
      final before = {
        for (final k in ['top-balance', 'top-countdown', 'play', 'win', 'limits', 'results']) k: rectOf(tester, k),
      };
      final textsBefore = [for (final t in tester.widgetList<Text>(find.byType(Text))) '${t.data}:${t.style!.fontSize}'];

      await pumpAtSize(tester, size, scene(), textScale: 3);
      expect(tester.takeException(), isNull);
      for (final e in before.entries) {
        expect(rectOf(tester, e.key), e.value, reason: e.key);
      }
      expect([for (final t in tester.widgetList<Text>(find.byType(Text))) '${t.data}:${t.style!.fontSize}'], textsBefore);
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        expect(t.textScaler, TextScaler.noScaling, reason: '"${t.data}" ignores the phone setting');
      }
    });
  });

  group('the top bar', () {
    testWidgets('shows the balance with thousands separators and the countdown in two digits', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(balance: 1234567, countdown: 7));
      expect(textsIn(tester, find.byKey(const ValueKey('top-balance'))), ['1,234,567']);
      expect(textsIn(tester, find.byKey(const ValueKey('top-countdown'))), ['07']);

      await pumpAtSize(tester, const Size(844, 390), scene(balance: 0, countdown: 90));
      expect(textsIn(tester, find.byKey(const ValueKey('top-balance'))), ['0']);
      expect(textsIn(tester, find.byKey(const ValueKey('top-countdown'))), ['90']);
    });

    testWidgets('the countdown is gold, and red for the last five seconds only', (tester) async {
      Color colorAt(int seconds) {
        final t = tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('top-countdown')), matching: find.byType(Text)));
        return t.style!.color!;
      }

      for (final s in [90, 6, 0]) {
        await pumpAtSize(tester, const Size(844, 390), scene(countdown: s));
        expect(colorAt(s), kLuckyCardGoldBright, reason: '$s seconds');
      }
      for (final s in [5, 3, 1]) {
        await pumpAtSize(tester, const Size(844, 390), scene(countdown: s));
        expect(colorAt(s), kLuckyCardAlert, reason: '$s seconds');
      }
    });

    testWidgets('each button answers a tap anywhere in its 48 dp area, even where the round button is not drawn', (tester) async {
      for (final d in kDeviceMatrix) {
        final taps = Taps();
        await pumpAtSize(tester, d.size, scene(taps: taps));
        final l = LuckyCardLayout.of(d.size);
        final areas = {
          'exit': (l.exitHit, () => taps.exit),
          'sound': (l.soundHit, () => taps.sound),
          'info': (l.infoHit, () => taps.info),
        };
        for (final e in areas.entries) {
          final hit = onScreen(l, e.value.$1);
          // The middle, and a point 1 dp inside each corner of the area.
          for (final p in [hit.center, hit.topLeft + const Offset(1, 1), hit.bottomRight - const Offset(1, 1), hit.topRight + const Offset(-1, 1), hit.bottomLeft + const Offset(1, -1)]) {
            final before = e.value.$2();
            await tester.tapAt(p);
            await tester.pump();
            expect(e.value.$2(), before + 1, reason: '${e.key} at $p on ${d.name}');
          }
        }
        expect([taps.exit, taps.sound, taps.info], [5, 5, 5], reason: d.name);

        // Just outside an area, nothing happens.
        final exit = onScreen(l, l.exitHit);
        await tester.tapAt(exit.centerRight + const Offset(1.5, 0));
        await tester.pump();
        expect([taps.exit, taps.sound, taps.info], [5, 5, 5], reason: 'a tap beside the exit button, ${d.name}');
      }
    });

    testWidgets('Info is dimmed and ignores taps while it is disabled; Exit and Sound still work', (tester) async {
      final taps = Taps();
      await pumpAtSize(tester, const Size(844, 390), scene(taps: taps, infoEnabled: false));
      final l = LuckyCardLayout.of(const Size(844, 390));
      await tester.tapAt(onScreen(l, l.infoHit).center);
      await tester.tapAt(onScreen(l, l.exitHit).center);
      await tester.tapAt(onScreen(l, l.soundHit).center);
      await tester.pump();
      expect([taps.exit, taps.sound, taps.info], [1, 1, 0]);

      final info = find.descendant(of: find.byKey(const ValueKey('top-info')), matching: find.byType(Opacity));
      expect(tester.widget<Opacity>(info.first).opacity, closeTo(0.4, 1e-9), reason: 'dimmed');
      final exit = find.descendant(of: find.byKey(const ValueKey('top-exit')), matching: find.byType(Opacity));
      expect(exit, findsNothing, reason: 'an enabled button is not dimmed');
    });

    testWidgets('a button with no callback is dimmed and harmless', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      final l = LuckyCardLayout.of(const Size(844, 390));
      await tester.tapAt(onScreen(l, l.exitHit).center);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.descendant(of: find.byKey(const ValueKey('top-exit')), matching: find.byType(Opacity)), findsOneWidget);
    });

    testWidgets('a pressed button shrinks a little while the finger is down and springs back', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(taps: Taps()));
      final l = LuckyCardLayout.of(const Size(844, 390));
      double scaleOf(String k) => tester
          .widget<AnimatedScale>(find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(AnimatedScale)))
          .scale;
      expect(scaleOf('top-exit'), 1.0);
      final finger = await tester.startGesture(onScreen(l, l.exitHit).center);
      await tester.pump(const Duration(milliseconds: 20));
      expect(scaleOf('top-exit'), lessThan(1.0), reason: 'pressed');
      expect(scaleOf('top-sound'), 1.0, reason: 'only the pressed button moves');
      await finger.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(scaleOf('top-exit'), 1.0, reason: 'released');
    });

    testWidgets('a pressed button springs back when the finger slides away and the tap is cancelled', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(taps: Taps()));
      final l = LuckyCardLayout.of(const Size(844, 390));
      double scaleOf() => tester
          .widget<AnimatedScale>(find.descendant(of: find.byKey(const ValueKey('top-exit')), matching: find.byType(AnimatedScale)))
          .scale;
      final finger = await tester.startGesture(onScreen(l, l.exitHit).center);
      await tester.pump(const Duration(milliseconds: 20));
      expect(scaleOf(), lessThan(1.0));
      await finger.moveBy(const Offset(0, 300));
      await finger.cancel();
      await tester.pump(const Duration(milliseconds: 200));
      expect(scaleOf(), 1.0);
    });

    testWidgets('the sound button shows its state, and says it', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(soundOn: true));
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
      await pumpAtSize(tester, const Size(844, 390), scene(soundOn: false));
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    });

    testWidgets('a screen reader hears each button, the balance and the countdown', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), scene(taps: Taps(), balance: 2500, countdown: 12, soundOn: true));
      expect(find.bySemanticsLabel('Exit the game'), findsOneWidget);
      expect(find.bySemanticsLabel('Sound on, tap to mute'), findsOneWidget);
      expect(find.bySemanticsLabel('How to play'), findsOneWidget);
      expect(find.bySemanticsLabel('Balance: 2,500 coins'), findsOneWidget);
      expect(find.bySemanticsLabel('Time left: 12 seconds'), findsOneWidget);
      handle.dispose();
    });
  });

  group('the status strip', () {
    testWidgets('says what each mode says, in the strip under the board', (tester) async {
      const size = Size(844, 390);
      final l = LuckyCardLayout.of(size);
      for (final mode in LuckyCardStatusMode.values) {
        await pumpAtSize(tester, size, scene(mode: mode));
        expect(find.text(luckyCardStatusText(mode)), findsOneWidget, reason: '$mode');
        expect(tester.getRect(find.byType(LuckyCardStatusStrip)), onScreen(l, l.status), reason: '$mode');
      }
    });

    testWidgets('the words are cream while betting is open and red once it is closed', (tester) async {
      Color color() => tester.widget<Text>(find.descendant(of: find.byType(LuckyCardStatusStrip), matching: find.byType(Text))).style!.color!;
      await pumpAtSize(tester, const Size(844, 390), scene(mode: LuckyCardStatusMode.placeChips));
      expect(color(), kLuckyCardCream);
      await pumpAtSize(tester, const Size(844, 390), scene(mode: LuckyCardStatusMode.noMoreFlashing));
      expect(color(), kLuckyCardAlert);
      await pumpAtSize(tester, const Size(844, 390), scene(mode: LuckyCardStatusMode.noMoreSteady));
      expect(color(), kLuckyCardAlert);
    });

    double opacity(WidgetTester tester) => tester
        .widget<Opacity>(find.descendant(of: find.byType(LuckyCardStatusStrip), matching: find.byType(Opacity)).last)
        .opacity;

    testWidgets('the flashing mode fades the words down and back; the other two never move', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(mode: LuckyCardStatusMode.noMoreFlashing));
      final seen = <double>{};
      for (var i = 0; i < 14; i++) {
        seen.add(double.parse(opacity(tester).toStringAsFixed(2)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(seen.reduce((a, b) => a < b ? a : b), lessThan(0.45), reason: 'it goes dim');
      expect(seen.reduce((a, b) => a > b ? a : b), greaterThan(0.95), reason: 'and comes back bright');

      for (final mode in [LuckyCardStatusMode.placeChips, LuckyCardStatusMode.noMoreSteady]) {
        await pumpAtSize(tester, const Size(844, 390), scene(mode: mode));
        for (var i = 0; i < 10; i++) {
          expect(opacity(tester), 1.0, reason: '$mode');
          await tester.pump(const Duration(milliseconds: 150));
        }
      }
    });

    testWidgets('when the flash ends the words go bright at once and nothing keeps animating', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(mode: LuckyCardStatusMode.noMoreFlashing));
      await tester.pump(const Duration(milliseconds: 350));
      expect(opacity(tester), lessThan(0.8), reason: 'mid-flash');

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: scene(mode: LuckyCardStatusMode.noMoreSteady))));
      await tester.pump();
      expect(opacity(tester), 1.0);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'the repeating animation is stopped');
    });

    testWidgets('with "reduce motion" on, the words do not flash', (tester) async {
      await pumpAtSize(
        tester,
        const Size(844, 390),
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: scene(mode: LuckyCardStatusMode.noMoreFlashing),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        expect(opacity(tester), 1.0);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('NO MORE PLAY'), findsOneWidget, reason: 'the words still change');
    });

    testWidgets('a screen reader hears the words, and is told when they change', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), scene(mode: LuckyCardStatusMode.placeChips));
      expect(find.bySemanticsLabel('PLACE YOUR CHIPS'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('PLACE YOUR CHIPS'));
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue, reason: 'a change is announced');
      handle.dispose();
    });
  });

  group('PLAY and WIN', () {
    testWidgets('PLAY shows the stake, WIN shows 0 until a win', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(play: 12500, win: 0));
      expect(textsIn(tester, find.byKey(const ValueKey('play'))), ['PLAY', '12,500']);
      expect(textsIn(tester, find.byKey(const ValueKey('win'))), ['WIN', '0']);
    });

    testWidgets('a screen reader hears each amount with its name', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), scene(play: 150, win: 1500));
      expect(find.bySemanticsLabel('PLAY: 150'), findsOneWidget);
      expect(find.bySemanticsLabel('WIN: +1,500'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a win shows +amount, in green, on a highlighted cell', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(play: 120, win: 1500));
      expect(textsIn(tester, find.byKey(const ValueKey('win'))), ['WIN', '+1,500']);
      final value = tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('win')), matching: find.text('+1,500')));
      expect(value.style!.color, kLuckyCardWin);
    });

    testWidgets('the biggest numbers fit their cell on the smallest phone', (tester) async {
      await pumpAtSize(tester, const Size(640, 360), scene(play: 1000000, win: 9999999));
      expect(tester.takeException(), isNull);
      for (final key in ['play', 'win']) {
        final cell = rectOf(tester, key);
        for (final t in find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text)).evaluate()) {
          final r = tester.getRect(find.byWidget(t.widget));
          expect(r.left, greaterThanOrEqualTo(cell.left - 0.5), reason: '$key "${(t.widget as Text).data}" left');
          expect(r.right, lessThanOrEqualTo(cell.right + 0.5), reason: '$key "${(t.widget as Text).data}" right');
        }
      }
    });
  });

  group('the limits', () {
    testWidgets('MIN and MAX with their IN and OUT numbers', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      expect(textsIn(tester, find.byKey(const ValueKey('limits'))), ['MIN', 'IN 5', 'OUT 50', 'MAX', 'IN 50,000', 'OUT 500,000']);
    });

    testWidgets('a screen reader hears the limits as one sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), scene());
      expect(
        find.bySemanticsLabel('Limits. Minimum: stake 5, pays up to 50. Maximum: stake 50,000, pays up to 500,000.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('on every device each limit text lies inside the panel', (tester) async {
      for (final d in kDeviceMatrix) {
        await pumpAtSize(tester, d.size, scene());
        final panel = rectOf(tester, 'limits');
        for (final t in find.descendant(of: find.byKey(const ValueKey('limits')), matching: find.byType(Text)).evaluate()) {
          final r = tester.getRect(find.byWidget(t.widget));
          expect(r.left, greaterThanOrEqualTo(panel.left), reason: '${(t.widget as Text).data} on ${d.name}');
          expect(r.right, lessThanOrEqualTo(panel.right), reason: '${(t.widget as Text).data} on ${d.name}');
          expect(r.top, greaterThanOrEqualTo(panel.top), reason: '${(t.widget as Text).data} on ${d.name}');
          expect(r.bottom, lessThanOrEqualTo(panel.bottom), reason: '${(t.widget as Text).data} on ${d.name}');
        }
      }
    });
  });

  group('the results', () {
    testWidgets('the latest result is large on top, the nine before it fill the grid in order', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      expect(textsIn(tester, find.byKey(const ValueKey('result-latest'))), ['Q', '4X']);
      final grid = [for (var i = 0; i < 9; i++) textsIn(tester, find.byKey(ValueKey('result-$i')))];
      expect(grid, [
        ['J', 'N'],
        ['K', '10X'],
        ['Q', '2X'],
        ['J', 'N'],
        ['K', '3X'],
        ['Q', 'N'],
        ['J', '7X'],
        ['K', 'N'],
        ['J', '5X'],
      ]);
    });

    testWidgets('each result carries the icon of its own suit', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      String? iconOf(String key) {
        final image = tester.widget<Image>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Image)));
        final provider = image.image as ResizeImage;
        return (provider.imageProvider as FileImage).file.path.split(RegExp(r'[\\/]')).last;
      }

      expect(iconOf('result-latest'), 'spades-icon.webp');
      expect([for (var i = 0; i < 9; i++) iconOf('result-$i')], [
        'hearts-icon.webp',
        'diamonds-icon.webp',
        'clubs-icon.webp',
        'spades-icon.webp',
        'hearts-icon.webp',
        'diamonds-icon.webp',
        'clubs-icon.webp',
        'spades-icon.webp',
        'diamonds-icon.webp',
      ]);
    });

    testWidgets('a new table has fewer than ten rounds: the missing ones are empty tiles', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(history: ten.sublist(0, 3)));
      expect(textsIn(tester, find.byKey(const ValueKey('result-latest'))), ['Q', '4X']);
      expect(textsIn(tester, find.byKey(const ValueKey('result-0'))), ['J', 'N']);
      expect(textsIn(tester, find.byKey(const ValueKey('result-1'))), ['K', '10X']);
      for (var i = 2; i < 9; i++) {
        expect(textsIn(tester, find.byKey(ValueKey('result-$i'))), isEmpty, reason: 'tile $i is empty');
        expect(find.descendant(of: find.byKey(ValueKey('result-$i')), matching: find.byType(Image)), findsNothing);
      }
      expect(find.descendant(of: find.byKey(const ValueKey('results')), matching: find.byType(Image)), findsNWidgets(3));
    });

    testWidgets('an empty tile is dimmed, a filled one is not', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(history: ten.sublist(0, 3)));
      Finder dim(String k) => find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(Opacity));
      expect(dim('result-latest'), findsNothing);
      expect(dim('result-0'), findsNothing);
      expect(dim('result-1'), findsNothing);
      for (var i = 2; i < 9; i++) {
        expect(dim('result-$i'), findsOneWidget, reason: 'tile $i');
      }
    });

    testWidgets('the suit icons are decoded no wider than the largest one drawn, at any pixel density', (tester) async {
      for (final dpr in [1.0, 2.0, 3.0]) {
        const size = Size(844, 390);
        await pumpAtSize(tester, size, scene(), devicePixelRatio: dpr);
        final l = LuckyCardLayout.of(size);
        final need = (l.resultCurrentIcon * dpr).ceil();
        for (final k in ['result-latest', for (var i = 0; i < 9; i++) 'result-$i']) {
          final image = tester.widget<Image>(find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(Image)));
          final width = (image.image as ResizeImage).width!;
          expect(width, greaterThanOrEqualTo(need), reason: 'sharp enough: $k at $dpr');
          expect(width, lessThanOrEqualTo(need + 1), reason: 'not larger than needed: $k at $dpr');
        }
      }
    });

    testWidgets('no rounds at all: ten empty tiles, nothing drawn, nothing thrown', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(history: const []));
      expect(tester.takeException(), isNull);
      expect(find.descendant(of: find.byKey(const ValueKey('results')), matching: find.byType(Image)), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('results')), matching: find.byType(Text)), findsNothing);
    });

    testWidgets('more than ten rounds: only the latest ten are shown', (tester) async {
      final many = [round(11, LuckyCardRank.king, LuckyCardSuit.clubs, 6), ...ten];
      await pumpAtSize(tester, const Size(844, 390), scene(history: many));
      expect(textsIn(tester, find.byKey(const ValueKey('result-latest'))), ['K', '6X']);
      expect(find.descendant(of: find.byKey(const ValueKey('results')), matching: find.byType(Image)), findsNWidgets(10));
    });

    testWidgets('the rank is red for hearts and diamonds, cream for spades and clubs; a real bonus is bright', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      Color color(String key, String text) =>
          tester.widget<Text>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text))).style!.color!;
      expect(color('result-latest', 'Q'), kLuckyCardCream, reason: 'spades');
      expect(color('result-0', 'J'), const Color(0xFFFF6B5E), reason: 'hearts');
      expect(color('result-1', 'K'), const Color(0xFFFF6B5E), reason: 'diamonds');
      expect(color('result-2', 'Q'), kLuckyCardCream, reason: 'clubs');
      expect(color('result-latest', '4X'), kLuckyCardGoldBright, reason: 'a bonus');
      expect(color('result-0', 'N'), kLuckyCardGold, reason: 'no bonus');
    });

    testWidgets('every result tile holds its content on every device', (tester) async {
      for (final d in kDeviceMatrix) {
        await pumpAtSize(tester, d.size, scene());
        expect(tester.takeException(), isNull, reason: d.name);
        for (final key in ['result-latest', for (var i = 0; i < 9; i++) 'result-$i']) {
          final tile = rectOf(tester, key);
          for (final child in [find.byType(Image), find.byType(Text)]) {
            for (final e in find.descendant(of: find.byKey(ValueKey(key)), matching: child).evaluate()) {
              final r = tester.getRect(find.byWidget(e.widget));
              final what = e.widget is Text ? '"${(e.widget as Text).data}"' : 'the icon';
              expect(r.left, greaterThanOrEqualTo(tile.left - 0.5), reason: '$what in $key on ${d.name}');
              expect(r.right, lessThanOrEqualTo(tile.right + 0.5), reason: '$what in $key on ${d.name}');
              expect(r.top, greaterThanOrEqualTo(tile.top - 0.5), reason: '$what in $key on ${d.name}');
              expect(r.bottom, lessThanOrEqualTo(tile.bottom + 0.5), reason: '$what in $key on ${d.name}');
            }
          }
        }
      }
    });

    testWidgets('a screen reader hears each result in words', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), scene());
      expect(find.bySemanticsLabel('Latest result: Queen of Spades, bonus 4X'), findsOneWidget);
      expect(find.bySemanticsLabel('Earlier result: Jack of Hearts, no bonus'), findsOneWidget);
      expect(find.bySemanticsLabel('Earlier result: King of Diamonds, bonus 10X'), findsOneWidget);
      handle.dispose();
    });
  });

  group('a picture to look at, with the real artwork', () {
    Future<void> shoot(WidgetTester tester, Device d, String name, Widget Function(LuckyCardArt art) build) async {
      final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
      await pumpAtSize(tester, d.size, build(art));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${d.width.toInt()}x${d.height.toInt()}.png'));
    }

    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets('betting open, a stake on the board: ${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) async {
        await shoot(tester, d, 'readouts', (art) => scene(art: art, taps: Taps()));
      });
    }

    testWidgets('after a win, the last five seconds, an empty history: small phone', (tester) async {
      const d = Device('small phone', 640, 360);
      await shoot(
        tester,
        d,
        'readouts_win_empty',
        (art) => scene(art: art, win: 1500, play: 0, countdown: 3, balance: 98765432, mode: LuckyCardStatusMode.noMoreSteady, infoEnabled: false, soundOn: false, history: ten.sublist(0, 2)),
      );
    });
  });
}
