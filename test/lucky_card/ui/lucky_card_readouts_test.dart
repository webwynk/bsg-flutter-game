// Tests for the Lucky Card top bar, status words and bet-panel readouts
// (lucky_card_top_bar.dart, lucky_card_status_strip.dart, lucky_card_readouts.dart).
//
// What the player reads: the balance, the countdown, the status words, PLAY and WIN and the
// ten latest results. Everything is checked on every
// device of the matrix: where it sits, that each button has a tap area of at least
// 48 dp, that no text is smaller than 11 dp, that nothing overflows, and that the
// phone's font-size setting changes nothing. The pieces here are given plain values;
// the provider-driven behaviour is in lucky_card_readouts_binding_test.dart.

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_palette.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_panel.dart' show luckyCardGrouped;
import 'package:best_smart_game/widgets/lucky_card/lucky_card_readouts.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_readouts_binding.dart' show luckyCardHeaderStatus;
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

/// The screen as the Step 7a pieces build it: the top bar (which now carries the status
/// words itself, the reference design having no separate strip for them), and PLAY, WIN
/// and the results in the bet panel.
Widget scene({
  LuckyCardArt art = const FileLuckyCardArt(),
  int balance = 12345,
  int countdown = 47,
  bool soundOn = true,
  bool infoEnabled = true,
  LuckyCardStatusMode mode = LuckyCardStatusMode.placeChips,
  int total = 150,
  int win = 0,
  List<LuckyCardRecentRound>? history,
  Taps? taps,
}) {
  final rounds = history ?? ten;
  // Matches what LuckyCardTopBarBinding actually feeds the header from a mode, so a test
  // here that picks a mode sees the same words, colour and flashing the real screen would.
  return LuckyCardCanvas(
    topBar: (context, layout) {
      final status = luckyCardHeaderStatus(mode: mode);
      return LuckyCardTopBar(
        layout: layout, art: const FileLuckyCardArt(),
        balance: balance,
        countdown: countdown,
        soundOn: soundOn,
        infoEnabled: infoEnabled,
        statusWidget: LuckyCardStatusLine(
          key: const ValueKey('top-status'),
          text: status.text,
          size: layout.designStatusFont,
          color: status.color,
          flashing: status.isFlashing,
        ),
        onExit: taps == null ? null : () => taps.exit++,
        onToggleSound: taps == null ? null : () => taps.sound++,
        onInfo: taps == null ? null : () => taps.info++,
      );
    },
    side: (context, layout) {
      Rect inSide(Rect r) => layout.within(layout.side, r);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(
            rect: inSide(layout.totalBetCell),
            child: LuckyCardTotalCell(
              key: const ValueKey('total-bet'),
              layout: layout,
              label: 'Play',
              value: luckyCardGrouped(total),
              fill: kDesignTotalBetFill,
              labelColor: kDesignTotalBetLabel,
              under: kDesignTotalBetUnder,
            ),
          ),
          Positioned.fromRect(
            rect: inSide(layout.winCell),
            child: LuckyCardTotalCell(
              key: const ValueKey('win'),
              layout: layout,
              label: 'Win',
              value: luckyCardWinText(win),
              fill: kDesignWinFill,
              labelColor: kDesignWinLabel,
              under: kDesignWinUnder,
            ),
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

        // Each side-column piece is exactly where the layout says (the header's own row
        // layout is its own thing now, proven by lucky_card_top_bar_history_test.dart).
        Map<String, Rect> expected = {
          'total-bet': l.totalBetCell,
          'win': l.winCell,
          'results': l.resultsPanel,
          'result-latest': l.resultTile(0),
          for (var i = 0; i < 9; i++) 'result-$i': l.resultTile(i + 1),
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
        for (final k in ['top-balance', 'top-countdown', 'total-bet', 'win', 'results']) k: rectOf(tester, k),
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
      // The coin beside the figure is the BSG coin picture (the user's decision of 2026-10-23), not a
      // drawn "$", so the balance pill reads only the figure.
      await pumpAtSize(tester, const Size(844, 390), scene(balance: 1234567, countdown: 7));
      expect(textsIn(tester, find.byKey(const ValueKey('top-balance'))), ['1,234,567']);
      final coin = tester.widget<Image>(find.byKey(const ValueKey('top-coin')));
      final coinFile = ((coin.image as ResizeImage).imageProvider as FileImage).file.path.split(RegExp(r'[\\/]')).last;
      expect(coinFile, 'bsg_coin.webp');
      expect(tester.getSize(find.byKey(const ValueKey('top-coin'))).width, closeTo(LuckyCardLayout.of(const Size(844, 390)).designCoinSize, 0.01));
      expect(textsIn(tester, find.byKey(const ValueKey('top-countdown'))), ['07']);

      await pumpAtSize(tester, const Size(844, 390), scene(balance: 0, countdown: 90));
      expect(textsIn(tester, find.byKey(const ValueKey('top-balance'))), ['0']);
      expect(textsIn(tester, find.byKey(const ValueKey('top-countdown'))), ['90']);
    });

    testWidgets('the countdown ring is gold, and red for the last five seconds only; the digits stay white, as the design draws them', (tester) async {
      // The design's countdown turns urgent in its RING, not its digits (a purple disc with
      // white digits throughout): the old gold/red text is gone with the strip that used it.
      Color ringColorAt(int seconds) {
        final container = tester.widget<Container>(find.descendant(of: find.byKey(const ValueKey('top-countdown')), matching: find.byType(Container)).first);
        return ((container.decoration as BoxDecoration).gradient as SweepGradient).colors.first;
      }

      Color textColorAt(int seconds) {
        final t = tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('top-countdown')), matching: find.byType(Text)));
        return t.style!.color!;
      }

      for (final s in [90, 6, 0]) {
        await pumpAtSize(tester, const Size(844, 390), scene(countdown: s));
        expect(ringColorAt(s), kDesignRing, reason: '$s seconds');
        expect(textColorAt(s), kDesignCountdownText, reason: '$s seconds');
      }
      for (final s in [5, 3, 1]) {
        await pumpAtSize(tester, const Size(844, 390), scene(countdown: s));
        expect(ringColorAt(s), kDesignAlertText, reason: '$s seconds');
        expect(textColorAt(s), kDesignCountdownText, reason: '$s seconds, digits unchanged');
      }
    });

    testWidgets('each button answers a tap anywhere in its 48 dp area, even where the round button is not drawn', (tester) async {
      for (final d in kDeviceMatrix) {
        final taps = Taps();
        await pumpAtSize(tester, d.size, scene(taps: taps));
        final areas = {
          'top-exit': () => taps.exit,
          'top-sound': () => taps.sound,
          'top-info': () => taps.info,
        };
        for (final e in areas.entries) {
          final hit = tester.getRect(find.byKey(ValueKey(e.key)));
          // The middle, and a point 1 dp inside each corner of the area.
          for (final p in [hit.center, hit.topLeft + const Offset(1, 1), hit.bottomRight - const Offset(1, 1), hit.topRight + const Offset(-1, 1), hit.bottomLeft + const Offset(1, -1)]) {
            final before = e.value();
            await tester.tapAt(p);
            await tester.pump();
            expect(e.value(), before + 1, reason: '${e.key} at $p on ${d.name}');
          }
        }
        expect([taps.exit, taps.sound, taps.info], [5, 5, 5], reason: d.name);

        // Just outside an area, nothing happens.
        final exit = tester.getRect(find.byKey(const ValueKey('top-exit')));
        await tester.tapAt(exit.centerRight + const Offset(1.5, 0));
        await tester.pump();
        expect([taps.exit, taps.sound, taps.info], [5, 5, 5], reason: 'a tap beside the exit button, ${d.name}');
      }
    });

    testWidgets('Info is dimmed and ignores taps while it is disabled; Exit and Sound still work', (tester) async {
      final taps = Taps();
      await pumpAtSize(tester, const Size(844, 390), scene(taps: taps, infoEnabled: false));
      await tester.tap(find.byKey(const ValueKey('top-info')), warnIfMissed: false);
      await tester.tap(find.byKey(const ValueKey('top-exit')));
      await tester.tap(find.byKey(const ValueKey('top-sound')));
      await tester.pump();
      expect([taps.exit, taps.sound, taps.info], [1, 1, 0]);

      final info = find.descendant(of: find.byKey(const ValueKey('top-info')), matching: find.byType(Opacity));
      expect(tester.widget<Opacity>(info.first).opacity, closeTo(0.4, 1e-9), reason: 'dimmed');
      final exit = find.descendant(of: find.byKey(const ValueKey('top-exit')), matching: find.byType(Opacity));
      expect(exit, findsNothing, reason: 'an enabled button is not dimmed');
    });

    testWidgets('a button with no callback is dimmed and harmless', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      await tester.tap(find.byKey(const ValueKey('top-exit')), warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.descendant(of: find.byKey(const ValueKey('top-exit')), matching: find.byType(Opacity)), findsOneWidget);
    });

    // The design pushes a pressed button down 2 dp (`button:active { transform:
    // translateY(2px) }`), not the old shrink: the Y offset of its AnimatedContainer's own
    // transform is what moves, not an AnimatedScale (removed with the rest of the old look).
    testWidgets('a pressed button eases down a little while the finger is down and springs back', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(taps: Taps()));
      double offsetOf(String k) {
        final container = tester.widget<AnimatedContainer>(find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(AnimatedContainer)));
        return container.transform!.getTranslation().y;
      }

      expect(offsetOf('top-exit'), 0.0);
      final finger = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('top-exit'))));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 100));
      expect(offsetOf('top-exit'), greaterThan(0.0), reason: 'pressed');
      expect(offsetOf('top-sound'), 0.0, reason: 'only the pressed button moves');
      await finger.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(offsetOf('top-exit'), 0.0, reason: 'released');
    });

    testWidgets('a pressed button springs back when the finger slides away and the tap is cancelled', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(taps: Taps()));
      double offsetOf() {
        final container = tester.widget<AnimatedContainer>(find.descendant(of: find.byKey(const ValueKey('top-exit')), matching: find.byType(AnimatedContainer)));
        return container.transform!.getTranslation().y;
      }

      final finger = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('top-exit'))));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 100));
      expect(offsetOf(), greaterThan(0.0));
      await finger.moveBy(const Offset(0, 300));
      await finger.cancel();
      await tester.pump(const Duration(milliseconds: 100));
      expect(offsetOf(), 0.0);
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

  group('the status words (now in the header -- lucky_card_top_bar.dart\'s LuckyCardStatusLine, key top-status; the reference design has no separate strip)', () {
    testWidgets('says what each mode says', (tester) async {
      const size = Size(844, 390);
      for (final mode in LuckyCardStatusMode.values) {
        await pumpAtSize(tester, size, scene(mode: mode));
        expect(find.text(luckyCardStatusText(mode)), findsOneWidget, reason: '$mode');
        expect(find.descendant(of: find.byKey(const ValueKey('top-status')), matching: find.text(luckyCardStatusText(mode))), findsOneWidget, reason: '$mode');
      }
    });

    testWidgets('the words are cream while betting is open and red once it is closed', (tester) async {
      Color color() => tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('top-status')), matching: find.byType(Text))).style!.color!;
      await pumpAtSize(tester, const Size(844, 390), scene(mode: LuckyCardStatusMode.placeChips));
      expect(color(), kDesignStatusText);
      await pumpAtSize(tester, const Size(844, 390), scene(mode: LuckyCardStatusMode.noMoreFlashing));
      expect(color(), kDesignAlertText);
      await pumpAtSize(tester, const Size(844, 390), scene(mode: LuckyCardStatusMode.noMoreSteady));
      expect(color(), kDesignAlertText);
    });

    double opacity(WidgetTester tester) => tester
        .widget<Opacity>(find.descendant(of: find.byKey(const ValueKey('top-status')), matching: find.byType(Opacity)).last)
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
      await pumpAtSize(tester, const Size(844, 390), scene(total: 12500, win: 0));
      expect(textsIn(tester, find.byKey(const ValueKey('total-bet'))), ['PLAY', '12,500']);
      expect(textsIn(tester, find.byKey(const ValueKey('win'))), ['WIN', '0']);
    });

    testWidgets('a screen reader hears each amount with its name', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), scene(total: 150, win: 1500));
      expect(find.bySemanticsLabel('Play: 150'), findsOneWidget);
      expect(find.bySemanticsLabel('Win: +1,500'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a win shows +amount; the figures are white on the blue and green cells, as in the design', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(total: 120, win: 1500));
      expect(textsIn(tester, find.byKey(const ValueKey('win'))), ['WIN', '+1,500']);
      Text text(String key, String value) => tester.widget<Text>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(value)));
      expect(text('win', '+1,500').style!.color, const Color(0xFFFFFFFF));
      expect(text('total-bet', '120').style!.color, const Color(0xFFFFFFFF));
      expect(text('total-bet', 'PLAY').style!.color, kDesignTotalBetLabel);
      expect(text('win', 'WIN').style!.color, kDesignWinLabel);
      expect(text('total-bet', '120').style!.fontFamily, 'Oswald');
    });

    testWidgets('the biggest numbers fit their cell on the smallest phone', (tester) async {
      await pumpAtSize(tester, const Size(640, 360), scene(total: 1000000, win: 9999999));
      expect(tester.takeException(), isNull);
      for (final key in ['total-bet', 'win']) {
        final cell = rectOf(tester, key);
        for (final t in find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text)).evaluate()) {
          final r = tester.getRect(find.byWidget(t.widget));
          expect(r.left, greaterThanOrEqualTo(cell.left - 0.5), reason: '$key "${(t.widget as Text).data}" left');
          expect(r.right, lessThanOrEqualTo(cell.right + 0.5), reason: '$key "${(t.widget as Text).data}" right');
        }
      }
    });

    testWidgets('no limits are drawn on the board any more (they stay in the Info dialog)', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      expect(find.text('MIN'), findsNothing);
      expect(find.text('MAX'), findsNothing);
    });
  });

  group('the results', () {
    testWidgets('the ten latest rounds fill two rows of five, newest first, each with its bonus under the letter and suit', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      expect(textsIn(tester, find.byKey(const ValueKey('result-latest'))), ['Q', '4X']);
      final row = [for (var i = 0; i < 9; i++) textsIn(tester, find.byKey(ValueKey('result-$i')))];
      expect(row, [
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
      expect(find.text('LAST RESULT'), findsNothing, reason: 'no caption line any more');
      expect(find.text('Previous 9'), findsNothing);
    });

    testWidgets('each result carries the picture of its own suit', (tester) async {
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

    testWidgets('a new table has fewer than ten rounds: the missing ones are empty slots', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(history: ten.sublist(0, 3)));
      expect(textsIn(tester, find.byKey(const ValueKey('result-latest'))), ['Q', '4X']);
      expect(textsIn(tester, find.byKey(const ValueKey('result-0'))), ['J', 'N']);
      expect(textsIn(tester, find.byKey(const ValueKey('result-1'))), ['K', '10X']);
      for (var i = 2; i < 9; i++) {
        expect(textsIn(tester, find.byKey(ValueKey('result-$i'))), isEmpty, reason: 'slot $i is empty');
        expect(find.descendant(of: find.byKey(ValueKey('result-$i')), matching: find.byType(Image)), findsNothing);
      }
      expect(find.descendant(of: find.byKey(const ValueKey('results')), matching: find.byType(Image)), findsNWidgets(3));
    });

    testWidgets('an empty slot is a faint blank box, the newest card green and the older ones white', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(history: ten.sublist(0, 3)));
      BoxDecoration decoration(String k) =>
          tester.widget<DecoratedBox>(find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(DecoratedBox)).first).decoration as BoxDecoration;
      expect(decoration('result-latest').gradient!.colors, kDesignTileFill, reason: 'the newest is green');
      expect(decoration('result-0').gradient!.colors, kDesignOldTileFill, reason: 'older ones are white');
      expect(decoration('result-0').gradient!.colors.every((c) => c == const Color(0xFFFFFFFF)), isTrue);
      expect(decoration('result-1').gradient!.colors, kDesignOldTileFill);
      for (var i = 2; i < 9; i++) {
        expect(decoration('result-$i').gradient, isNull, reason: 'slot $i');
        expect(decoration('result-$i').color, const Color(0x1FFFFFFF), reason: 'slot $i');
      }
    });

    testWidgets('the suit pictures are decoded no wider than the largest one drawn, at any pixel density', (tester) async {
      for (final dpr in [1.0, 2.0, 3.0]) {
        const size = Size(844, 390);
        await pumpAtSize(tester, size, scene(), devicePixelRatio: dpr);
        final need = (LuckyCardLayout.designTileIcon * dpr).ceil();
        for (final k in ['result-latest', for (var i = 0; i < 9; i++) 'result-$i']) {
          final image = tester.widget<Image>(find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(Image)));
          final width = (image.image as ResizeImage).width!;
          expect(width, greaterThanOrEqualTo(need), reason: 'sharp enough: $k at $dpr');
          expect(width, lessThanOrEqualTo(need + 1), reason: 'not larger than needed: $k at $dpr');
        }
      }
    });

    testWidgets('no rounds at all: ten empty slots, nothing drawn, nothing thrown', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(history: const []));
      expect(tester.takeException(), isNull);
      expect(find.descendant(of: find.byKey(const ValueKey('results')), matching: find.byType(Image)), findsNothing);
      expect(textsIn(tester, find.byKey(const ValueKey('results'))), isEmpty);
    });

    testWidgets('more than ten rounds: only the latest ten are shown', (tester) async {
      final many = [round(11, LuckyCardRank.king, LuckyCardSuit.clubs, 6), ...ten];
      await pumpAtSize(tester, const Size(844, 390), scene(history: many));
      expect(textsIn(tester, find.byKey(const ValueKey('result-latest'))), ['K', '6X']);
      expect(find.descendant(of: find.byKey(const ValueKey('results')), matching: find.byType(Image)), findsNWidgets(10));
    });

    testWidgets('the newest card has dark writing (a real bonus amber, none a muted purple); the older ones light writing', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      Color color(String key, String text) =>
          tester.widget<Text>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text))).style!.color!;
      expect(color('result-latest', 'Q'), kDesignTileLetter);
      expect(color('result-latest', '4X'), kDesignTileBonus, reason: 'a bonus on the white card');
      expect(color('result-0', 'J'), kDesignOldTileLetter);
      expect(color('result-1', 'K'), kDesignOldTileLetter);
      expect(color('result-1', '10X'), kDesignOldTileBonus, reason: 'a bonus on a dark card');
      expect(color('result-0', 'N'), kDesignOldTileNoBonus, reason: 'no bonus on a dark card');
    });

    testWidgets('every result holds its content on every device, the bonus at 11 dp or more', (tester) async {
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
              if (e.widget is Text) {
                expect((e.widget as Text).style!.fontSize, greaterThanOrEqualTo(kLuckyCardMinReadableDp - 0.001), reason: '$what in $key');
              }
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
        (art) => scene(art: art, win: 1500, total: 0, countdown: 3, balance: 98765432, mode: LuckyCardStatusMode.noMoreSteady, infoEnabled: false, soundOn: false, history: ten.sublist(0, 2)),
      );
    });
  });
}
