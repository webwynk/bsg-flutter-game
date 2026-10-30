// Tests for the Lucky 16 Card screen's frame and header (lib/screens/lucky16_screen.dart, phone
// phase 1), on the simulated server and the fake clock, with the real pictures and fonts. The screen
// is pushed over another page (a stand-in lobby), as in the real app.
//
// The board is tested in lucky16_board_test.dart, which also draws the whole screen's golden pictures
// (phase 1's frame-only pictures stay in reference-design/lucky16/screenshots/phase1/ as a record).

import 'package:best_smart_game/providers/lucky16_history_provider.dart';
import 'package:best_smart_game/providers/lucky16_provider.dart';
import 'package:best_smart_game/screens/lucky16_screen.dart';
import 'package:best_smart_game/services/lucky16_sound.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_layout.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_palette.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

late PreloadedLucky16Art art;

/// Plays nothing.
class SilentOutput implements Lucky16SoundOutput {
  @override
  void buttonClick() {}
  @override
  void chipClick() {}
  @override
  void numberSelect() {}
  @override
  void ding() {}
  @override
  void wheelSpin() {}
  @override
  void notification() {}
  @override
  void win() {}
  @override
  void coin() {}
  @override
  void noMoreBets() {}
  @override
  void setInGame(bool inGame) {}
  @override
  void stopAll() {}
}

Finder key(String k) => find.byKey(ValueKey(k));

/// The lobby stand-in: one button that opens the game screen over it.
Widget lobby(
  Lucky16Provider provider, {
  Lucky16HistoryProvider? history,
  Lucky16Sound? sound,
  Future<void> Function()? endSession,
  bool? desktopPlatform,
}) =>
    Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const ValueKey('go'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Lucky16Screen(
                setup: Lucky16ScreenSetup(
                  provider: provider,
                  art: art,
                  setOrientation: false,
                  history: history,
                  sessionStart: () => DateTime.utc(2026, 10, 28),
                  // A silent stand-in unless a test hands in its own: no real audio in a test.
                  sound: sound ?? Lucky16Sound(SilentOutput()),
                  endSession: endSession,
                  desktopPlatform: desktopPlatform,
                ),
              ),
            ),
          ),
          child: const Text('go'),
        ),
      ),
    );

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Opens the game screen over the lobby and lets it load and attach.
Future<void> openGame(
  WidgetTester tester,
  BetRig rig, {
  Size size = phone,
  double textScale = 1,
  Lucky16HistoryProvider? history,
  Lucky16Sound? sound,
  Future<void> Function()? endSession,
  bool? desktopPlatform,
}) async {
  await pumpAtSize(
    tester,
    size,
    lobby(rig.provider, history: history, sound: sound, endSession: endSession, desktopPlatform: desktopPlatform),
    textScale: textScale,
  );
  await tester.tap(key('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await rig.world.run(const Duration(seconds: 2));
  await settle(tester);
}

/// The last piece of text inside the widget with key [k].
String textIn(WidgetTester tester, String k) =>
    tester.widgetList<Text>(find.descendant(of: key(k), matching: find.byType(Text))).map((t) => t.data!).last;

/// The tap area of a header ball.
Size hitOf(WidgetTester tester, String k) =>
    tester.getSize(find.descendant(of: key(k), matching: find.byType(GestureDetector)).first);

void main() {
  setUpAll(() async {
    await loadLucky16Fonts();
    await loadLucky16Icons();
  });

  Future<void> loadArt(WidgetTester tester) async => art = (await tester.runAsync(PreloadedLucky16Art.load))!;

  testWidgets('it opens with the header live: balance, countdown and PLACE YOUR CHIPS', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    expect(tester.takeException(), isNull);
    expect(find.byType(Lucky16Screen), findsOneWidget);
    expect(key('top-bar'), findsOneWidget);
    expect(textIn(tester, 'top-balance'), '1,000');
    expect(textIn(tester, 'top-countdown'), lucky16CountdownText(rig.provider.countdown));
    expect(rig.provider.isLocked, isFalse);
    expect(textIn(tester, 'top-status'), 'PLACE YOUR CHIPS');
    await rig.finish();
  });

  testWidgets('the header and the bet panel are exactly the size of their zones', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    final layout = Lucky16Layout.of(phone);
    expect(tester.getRect(key('bet-panel')), layout.side);
    expect(tester.getRect(key('top-bar')), layout.topBar);
    await rig.finish();
  });

  testWidgets('the four balls are lit and answer over at least 48 dp; SOUND does nothing yet', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    for (final k in ['top-exit', 'top-history', 'top-sound', 'top-info']) {
      final hit = hitOf(tester, k);
      expect(hit.width, greaterThanOrEqualTo(kLucky16MinTapDp), reason: k);
      expect(hit.height, greaterThanOrEqualTo(kLucky16MinTapDp), reason: k);
      expect(find.descendant(of: key(k), matching: find.byType(Opacity)), findsNothing, reason: '$k is drawn lit');
    }
    await tester.tap(key('top-sound'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(Lucky16Screen), findsOneWidget);
    await rig.finish();
  });

  testWidgets('when betting closes the words turn red NO MORE PLAY, and HISTORY and INFO dim', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    var guard = 0;
    while (!rig.provider.isLocked && ++guard < 2000) {
      await rig.world.run(const Duration(milliseconds: 500));
    }
    await settle(tester);
    expect(rig.provider.isLocked, isTrue);
    expect(textIn(tester, 'top-status'), 'NO MORE PLAY');
    final words = tester.widget<Text>(find.descendant(of: key('top-status'), matching: find.byType(Text)));
    expect(words.style!.color, kLucky16AlertText);
    for (final k in ['top-history', 'top-info']) {
      expect(find.descendant(of: key(k), matching: find.byType(Opacity)), findsOneWidget, reason: '$k is dimmed');
    }
    for (final k in ['top-exit', 'top-sound']) {
      expect(find.descendant(of: key(k), matching: find.byType(Opacity)), findsNothing, reason: '$k stays lit');
    }
    await rig.finish();
  });

  testWidgets('the phone\'s large-font setting changes nothing', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig, textScale: 2);
    expect(tester.takeException(), isNull);
    final layout = Lucky16Layout.of(phone);
    expect(tester.getRect(key('top-bar')), layout.topBar);
    expect(tester.getRect(key('bet-panel')), layout.side);
    await rig.finish();
  });
}
