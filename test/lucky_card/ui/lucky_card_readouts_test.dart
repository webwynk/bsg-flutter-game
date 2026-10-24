// Tests for the Lucky Card top bar, status words and bet-panel readouts
// (lucky_card_top_bar.dart, lucky_card_status_strip.dart, lucky_card_readouts.dart).
//
// What the player reads: the balance, the countdown, the status words, PLAY and WIN and the
// twelve latest results. Everything is checked on every
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

/// Twelve rounds: those ten, then two older ones (King of Hearts with no bonus, Queen of Hearts with 6X).
final List<LuckyCardRecentRound> twelve = [
  ...ten,
  round(0, LuckyCardRank.king, LuckyCardSuit.hearts, 1),
  round(-1, LuckyCardRank.queen, LuckyCardSuit.hearts, 6),
];

/// A picture source that remembers what was asked of it, to prove each picture is asked for at the
/// width it is drawn.
class RecordingArt extends LuckyCardArt {
  RecordingArt();

  final List<({LuckyCardArtKey key, int cacheWidth})> requests = [];

  @override
  ImageProvider image(LuckyCardArtKey key, {required int cacheWidth}) {
    requests.add((key: key, cacheWidth: cacheWidth));
    return const FileLuckyCardArt().image(key, cacheWidth: cacheWidth);
  }
}

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
  final rounds = history ?? twelve;
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
          for (var i = 0; i < 11; i++) 'result-$i': l.resultTile(i + 1),
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

    testWidgets('the countdown is a purple disc with white digits and NO ring, at every second, the last five included', (tester) async {
      // The gold ring that emptied as the window ran down (and went red for the last five seconds)
      // was removed, 2026-10-24: the disc looks the same all the time; the words beside it flash.
      Container disc() => tester.widget<Container>(find.descendant(of: find.byKey(const ValueKey('top-countdown')), matching: find.byType(Container)).first);

      for (final s in [90, 45, 6, 5, 3, 1, 0]) {
        await pumpAtSize(tester, const Size(844, 390), scene(countdown: s));
        final decoration = disc().decoration as BoxDecoration;
        expect(decoration.gradient, isA<RadialGradient>(), reason: '$s seconds: a plain disc, no sweep ring');
        expect((decoration.gradient as RadialGradient).colors, kDesignCountdownDisc, reason: '$s seconds');
        expect(decoration.boxShadow, isNull, reason: '$s seconds: no glow');
        expect(find.descendant(of: find.byKey(const ValueKey('top-countdown')), matching: find.byType(Container)), findsOneWidget, reason: '$s seconds: one layer, no ring around it');
        final t = tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('top-countdown')), matching: find.byType(Text)));
        expect(t.style!.color, kDesignCountdownText, reason: '$s seconds');
        expect(t.data, s.toString().padLeft(2, '0'));
        expect(tester.getSize(find.byKey(const ValueKey('top-countdown'))), Size.square(LuckyCardLayout.phone(const Size(844, 390)).designCountdownSize), reason: '$s seconds: the box is exactly the disc');
      }
    });

    testWidgets('the words in the header are DM Sans (extra-bold); the digits and the balance stay Oswald', (tester) async {
      for (final mode in LuckyCardStatusMode.values) {
        await pumpAtSize(tester, const Size(844, 390), scene(mode: mode));
        final words = tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('top-status')), matching: find.byType(Text)));
        expect(words.style!.fontFamily, 'DMSans', reason: '$mode');
        expect(words.style!.fontWeight, FontWeight.w800, reason: '$mode');
        expect(words.data, luckyCardStatusText(mode).toUpperCase(), reason: '$mode');
        final digits = tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('top-countdown')), matching: find.byType(Text)));
        expect(digits.style!.fontFamily, 'Oswald', reason: 'the countdown digits keep their face: $mode');
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

  group('the results (the twelve history cards, spec §17BO)', () {
    /// The file name of every picture ([Image]) drawn in [key]'s card: the suit's picture only,
    /// because the frame is its own widget ([LuckyCardHistoryFrame]).
    List<String> picturesIn(WidgetTester tester, String key) => [
          for (final image in tester.widgetList<Image>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Image))))
            ((image.image as ResizeImage).imageProvider as FileImage).file.path.split(RegExp(r'[\\/]')).last,
        ];

    /// The suit picture of [key]'s card.
    String? iconOf(WidgetTester tester, String key) {
      final icons = picturesIn(tester, key);
      return icons.isEmpty ? null : icons.single;
    }

    /// The frame of [key]'s card (null when it has none).
    LuckyCardHistoryFrame? frameOf(WidgetTester tester, String key) {
      final found = find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(LuckyCardHistoryFrame));
      return found.evaluate().isEmpty ? null : tester.widget<LuckyCardHistoryFrame>(found);
    }

    TextStyle styleOf(WidgetTester tester, String key, String text) =>
        tester.widget<Text>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text))).style!;

    testWidgets('the twelve latest rounds fill four across and three down, newest first, each with its letter and its bonus', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      expect(textsIn(tester, find.byKey(const ValueKey('result-latest'))), ['Q', '4X']);
      final row = [for (var i = 0; i < 11; i++) textsIn(tester, find.byKey(ValueKey('result-$i')))];
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
        ['K', 'N'],
        ['Q', '6X'],
      ]);
      // Four across (the same top along a row, the same left down a column), three rows.
      final tiles = [rectOf(tester, 'result-latest'), for (var i = 0; i < 11; i++) rectOf(tester, 'result-$i')];
      for (var i = 0; i < 12; i++) {
        expect(tiles[i].top, closeTo(tiles[i - i % 4].top, 0.01), reason: 'card $i is in its row');
        expect(tiles[i].left, closeTo(tiles[i % 4].left, 0.01), reason: 'card $i is in its column');
      }
      expect(tiles[4].top, greaterThan(tiles[0].bottom), reason: 'the second row is under the first');
      expect(tiles[8].top, greaterThan(tiles[4].bottom), reason: 'the third row is under the second');
      expect(find.text('LAST RESULT'), findsNothing);
      expect(find.text('Previous 9'), findsNothing);
    });

    testWidgets('each card carries the picture of its own suit and the right frame: the green one for the newest, the cream one for the rest', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      expect(iconOf(tester, 'result-latest'), 'spades-icon.webp');
      expect([for (var i = 0; i < 11; i++) iconOf(tester, 'result-$i')], [
        'hearts-icon.webp',
        'diamonds-icon.webp',
        'clubs-icon.webp',
        'spades-icon.webp',
        'hearts-icon.webp',
        'diamonds-icon.webp',
        'clubs-icon.webp',
        'spades-icon.webp',
        'diamonds-icon.webp',
        'hearts-icon.webp',
        'hearts-icon.webp',
      ]);
      expect(frameOf(tester, 'result-latest')!.latest, isTrue, reason: 'the newest card has the green frame');
      for (var i = 0; i < 11; i++) {
        expect(frameOf(tester, 'result-$i')!.latest, isFalse, reason: 'card $i has the cream frame');
      }
    });

    testWidgets('the green frame is the picture latest-history-card and the cream one history-card', (tester) async {
      final art = RecordingArt();
      await pumpAtSize(tester, const Size(844, 390), scene(art: art));
      final frames = art.requests.where((r) => !r.key.assetPath.endsWith('-icon.webp')).map((r) => r.key.assetPath.split('/').last).toSet();
      expect(frames, {'latest-history-card.webp', 'history-card.webp'});
    });

    testWidgets('a new table has fewer than twelve rounds: the missing ones are faint empty frames', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(history: ten.sublist(0, 3)));
      expect(textsIn(tester, find.byKey(const ValueKey('result-latest'))), ['Q', '4X']);
      expect(textsIn(tester, find.byKey(const ValueKey('result-0'))), ['J', 'N']);
      expect(textsIn(tester, find.byKey(const ValueKey('result-1'))), ['K', '10X']);
      for (var i = 2; i < 11; i++) {
        final slot = find.byKey(ValueKey('result-$i'));
        expect(textsIn(tester, slot), isEmpty, reason: 'slot $i is empty');
        expect(iconOf(tester, 'result-$i'), isNull, reason: 'slot $i has no suit picture');
        expect(frameOf(tester, 'result-$i')!.latest, isFalse, reason: 'slot $i is a bare cream frame');
        expect(tester.widget<Opacity>(find.descendant(of: slot, matching: find.byType(Opacity))).opacity, 0.3, reason: 'slot $i is faint');
      }
      expect(find.descendant(of: find.byKey(const ValueKey('results')), matching: find.byType(Opacity)), findsNWidgets(9));
    });

    testWidgets('the newest card has white writing with a thin dark outline and its suit on a cream patch; the older ones have red or black writing and no patch', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      final latest = styleOf(tester, 'result-latest', 'Q');
      expect(latest.color, kDesignHistoryLatestLetter);
      expect(latest.shadows!.length, 4, reason: 'a thin outline from four sides');
      expect(latest.shadows!.every((s) => s.color == kDesignHistoryLatestOutline && s.blurRadius == 0), isTrue);
      bool hasPatch(String key) => tester
          .widgetList<DecoratedBox>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(DecoratedBox)))
          .any((d) => d.decoration is BoxDecoration && (d.decoration as BoxDecoration).color == kDesignHistoryPatch);
      expect(hasPatch('result-latest'), isTrue, reason: 'the newest suit sits on the cream patch');
      // Cream cards: red hearts and diamonds, black spades and clubs (result-0 Jack of Hearts,
      // result-1 King of Diamonds, result-2 Queen of Clubs, result-3 Jack of Spades).
      expect(styleOf(tester, 'result-0', 'J').color, kDesignHistoryRed);
      expect(styleOf(tester, 'result-1', 'K').color, kDesignHistoryRed);
      expect(styleOf(tester, 'result-2', 'Q').color, kDesignHistoryBlack);
      expect(styleOf(tester, 'result-3', 'J').color, kDesignHistoryBlack);
      for (var i = 0; i < 11; i++) {
        expect(hasPatch('result-$i'), isFalse, reason: 'card $i has no patch');
        expect(styleOf(tester, 'result-$i', textsIn(tester, find.byKey(ValueKey('result-$i'))).first).shadows, isNull, reason: 'card $i has no outline');
      }
    });

    testWidgets('the bonus sits in a red bubble with white writing, "N" when there was none, never under 11 dp, the bubble wider for "10X"', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene());
      for (final e in {'result-latest': '4X', 'result-0': 'N', 'result-1': '10X', 'result-2': '2X'}.entries) {
        final text = styleOf(tester, e.key, e.value);
        expect(text.color, kDesignHistoryBubbleText, reason: e.key);
        expect(text.fontSize, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: e.key);
      }
      Rect bubble(String key, String text) {
        final box = find.ancestor(of: find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text)), matching: find.byType(DecoratedBox)).first;
        final decoration = tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
        expect((decoration.gradient as LinearGradient).colors, kDesignHistoryBubbleFill, reason: '$key $text is a red bubble');
        expect((decoration.border as Border).top.color, kDesignHistoryBubbleRing, reason: 'with the gold ring');
        return tester.getRect(box);
      }

      final two = bubble('result-2', '2X');
      final ten = bubble('result-1', '10X');
      final none = bubble('result-0', 'N');
      expect(ten.width, greaterThan(two.width), reason: 'a longer bonus widens the bubble');
      expect(none.height, closeTo(two.height, 0.01));
      expect(two.width, greaterThanOrEqualTo(two.height - 0.01), reason: 'round or a pill, never narrower than tall');
      // At the top right of its card.
      final card = rectOf(tester, 'result-2');
      expect(two.top, lessThan(card.top + card.height * 0.2));
      expect(two.right, greaterThan(card.right - card.width * 0.2));
    });

    testWidgets('the letter is at the top left, the suit at the bottom middle, the bubble at the top right, and they do not cover each other on any device', (tester) async {
      for (final d in kDeviceMatrix) {
        await pumpAtSize(tester, d.size, scene());
        expect(tester.takeException(), isNull, reason: d.name);
        for (final key in ['result-latest', for (var i = 0; i < 11; i++) 'result-$i']) {
          final card = rectOf(tester, key);
          final slot = find.byKey(ValueKey(key));
          final texts = textsIn(tester, slot);
          final letter = tester.getRect(find.descendant(of: slot, matching: find.text(texts[0])));
          final bonus = tester.getRect(find.ancestor(of: find.descendant(of: slot, matching: find.text(texts[1])), matching: find.byType(DecoratedBox)).first);
          final icon = tester.getRect(find.descendant(of: slot, matching: find.byType(Image)));
          final why = '$key on ${d.name}';
          expect(letter.left, lessThan(card.left + card.width * 0.25), reason: 'letter at the left: $why');
          expect(letter.top, lessThan(card.top + card.height * 0.25), reason: 'letter at the top: $why');
          expect(bonus.right, greaterThan(card.right - card.width * 0.25), reason: 'bubble at the right: $why');
          expect(bonus.top, lessThan(card.top + card.height * 0.25), reason: 'bubble at the top: $why');
          expect(icon.bottom, greaterThan(card.bottom - card.height * 0.2), reason: 'suit at the bottom: $why');
          expect(icon.center.dx, closeTo(card.center.dx, card.width * 0.3), reason: 'suit in the middle: $why');
          expect(letter.overlaps(bonus), isFalse, reason: 'the letter and the bubble are apart: $why');
          // The suit may tuck a few dp under the bubble on a short card, never more than a quarter of its own area.
          final inter = icon.intersect(bonus);
          final overlap = inter.width > 0 && inter.height > 0 ? inter.width * inter.height : 0.0;
          expect(overlap, lessThanOrEqualTo(icon.width * icon.height * 0.25), reason: 'the suit is mostly clear of the bubble: $why');
          // Everything stays inside the card (the frame is the whole card).
          for (final r in [letter, bonus, icon]) {
            expect(r.left, greaterThanOrEqualTo(card.left - 0.5), reason: why);
            expect(r.right, lessThanOrEqualTo(card.right + 0.5), reason: why);
            expect(r.top, greaterThanOrEqualTo(card.top - 0.5), reason: why);
            expect(r.bottom, lessThanOrEqualTo(card.bottom + 0.5), reason: why);
          }
        }
      }
    });

    testWidgets('the frames and suit pictures are decoded no wider than they are drawn, at any pixel density', (tester) async {
      for (final dpr in [1.0, 2.0, 3.0]) {
        const size = Size(844, 390);
        final art = RecordingArt();
        await pumpAtSize(tester, size, scene(art: art), devicePixelRatio: dpr);
        final l = LuckyCardLayout.of(size);
        expect(art.requests, isNotEmpty);
        for (final r in art.requests) {
          final isIcon = r.key.assetPath.endsWith('-icon.webp');
          final isFrame = r.key.assetPath.endsWith('history-card.webp');
          if (!isIcon && !isFrame) continue;
          expect(r.cacheWidth, isIcon ? l.resultIconCacheWidth(dpr) : l.historyFrameCacheWidth(dpr), reason: '${r.key.assetPath} at $dpr');
        }
        // The frame's decoded width gives exactly tileBorder dp of border at this density.
        expect(l.historyFrameCacheWidth(dpr) * 18 / 604 / dpr, closeTo(l.tileBorder, 0.02 + 0.5 / dpr), reason: 'the border at $dpr');
      }
    });

    test('the frame is drawn nine-slice: corners of 7.5% of the picture, scaled so the 18 px border comes out tileBorder dp', () {
      // The picture is 604 x 686: the middle leaves 45.3 px at every side.
      final center = LuckyCardHistoryFramePainter.centerOf(604, 686);
      expect(center.left, closeTo(45.3, 0.001));
      expect(center.top, closeTo(45.3, 0.001));
      expect(center.right, closeTo(604 - 45.3, 0.001));
      expect(center.bottom, closeTo(686 - 45.3, 0.001));
      // At 604 px wide an 18 px border drawn 1.5 dp thick is a scale of 1.5 / 18; at a decoded 50 px it is ten times bigger.
      expect(LuckyCardHistoryFramePainter.scaleFor(604, 1.5), closeTo(1.5 / 18, 1e-9));
      expect(LuckyCardHistoryFramePainter.scaleFor(50, 1.5), closeTo(1.5 / (50 * 18 / 604), 1e-9));
      // Whatever size the picture arrives at, its border is drawn the same thickness.
      for (final w in [50.0, 100.0, 302.0, 604.0]) {
        expect(w * LuckyCardHistoryFramePainter.scaleFor(w, 2.2) * (18 / 604), closeTo(2.2, 1e-9), reason: 'decoded $w px wide');
      }
    });

    testWidgets('the frame is as big as its card, and drawn once the picture has arrived', (tester) async {
      await pumpAtSize(tester, const Size(640, 360), scene());
      final l = LuckyCardLayout.of(const Size(640, 360));
      for (final key in ['result-latest', 'result-0', 'result-10']) {
        final frame = find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(LuckyCardHistoryFrame));
        expect(frame, findsOneWidget, reason: key);
        final size = tester.getSize(find.descendant(of: frame, matching: find.byType(SizedBox)).first);
        expect(size.width, closeTo(l.designTileWidth, 0.01), reason: key);
        expect(size.height, closeTo(l.designTileHeight, 0.01), reason: key);
      }
    });

    testWidgets('no rounds at all: twelve faint empty frames, no letters, no bubbles, nothing thrown', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), scene(history: const []));
      expect(tester.takeException(), isNull);
      final results = find.byKey(const ValueKey('results'));
      expect(find.descendant(of: results, matching: find.byType(LuckyCardHistoryFrame)), findsNWidgets(12), reason: 'only the frames');
      expect(find.descendant(of: results, matching: find.byType(Image)), findsNothing, reason: 'no suit pictures');
      expect(find.descendant(of: results, matching: find.byType(Opacity)), findsNWidgets(12));
      expect(textsIn(tester, results), isEmpty);
    });

    testWidgets('more than twelve rounds: only the latest twelve are shown', (tester) async {
      final many = [round(13, LuckyCardRank.king, LuckyCardSuit.clubs, 6), ...twelve];
      await pumpAtSize(tester, const Size(844, 390), scene(history: many));
      expect(textsIn(tester, find.byKey(const ValueKey('result-latest'))), ['K', '6X']);
      final results = find.byKey(const ValueKey('results'));
      expect(find.descendant(of: results, matching: find.byType(LuckyCardHistoryFrame)), findsNWidgets(12));
      expect(find.descendant(of: results, matching: find.byType(Image)), findsNWidgets(12), reason: '12 suit pictures');
    });

    testWidgets('every card holds its text at 11 dp or more on every device', (tester) async {
      for (final d in kDeviceMatrix) {
        await pumpAtSize(tester, d.size, scene());
        expect(tester.takeException(), isNull, reason: d.name);
        final l = LuckyCardLayout.of(d.size);
        expect(l.tileLetterFont, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: d.name);
        expect(l.tileBubbleFont, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: d.name);
        for (final key in ['result-latest', for (var i = 0; i < 11; i++) 'result-$i']) {
          for (final t in tester.widgetList<Text>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text)))) {
            expect(t.style!.fontSize, greaterThanOrEqualTo(kLuckyCardMinReadableDp - 0.001), reason: '"${t.data}" in $key on ${d.name}');
          }
        }
      }
    });

    testWidgets('a screen reader hears each result in words', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), scene());
      expect(find.bySemanticsLabel('Latest result: Queen of Spades, bonus 4X'), findsOneWidget);
      expect(find.bySemanticsLabel('Earlier result: Jack of Hearts, no bonus'), findsWidgets);
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
