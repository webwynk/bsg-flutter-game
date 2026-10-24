// Tests for how the real screen chooses the desktop arrangement (spec §17BP): by SCREEN SIZE alone, a
// screen of at least 1280 x 720 dp, like Triple Chance, on every platform (an Android emulator such as
// BlueStacks included). The real app's default setup passes `desktopPlatform: true`; a test that leaves
// it unset never gets the desktop arrangement, however big the screen.

import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/screens/lucky_card_screen.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_controls_binding.dart' show LuckyCardChipBar;
import 'package:best_smart_game/widgets/lucky_card/lucky_card_desktop_pieces.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel_binding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'ui_harness.dart';

late PreloadedLuckyCardArt art;

Finder key(String k) => find.byKey(ValueKey(k));

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The lobby opens the screen with [desktopPlatform] as given (what the real app's default setup passes
/// is true; null is what a test that says nothing gets).
Widget lobby(LuckyCardProvider provider, {bool? desktopPlatform}) => Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const ValueKey('go'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LuckyCardScreen(
                setup: LuckyCardScreenSetup(provider: provider, art: art, setOrientation: false, desktopPlatform: desktopPlatform),
              ),
            ),
          ),
          child: const Text('go'),
        ),
      ),
    );

Future<void> openGame(WidgetTester tester, BetRig rig, Size size, {bool? desktopPlatform}) async {
  await pumpAtSize(tester, size, lobby(rig.provider, desktopPlatform: desktopPlatform));
  await tester.tap(key('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await rig.world.run(const Duration(seconds: 2));
  await settle(tester);
}

enum Arrangement { desktop, tablet, phone }

Arrangement arrangementOnScreen() {
  if (find.byType(LuckyCardDesktopSide).evaluate().isNotEmpty) return Arrangement.desktop;
  if (find.byType(LuckyCardChipBar).evaluate().isNotEmpty) return Arrangement.tablet;
  return Arrangement.phone;
}

void main() {
  setUpAll(() async {
    await loadLuckyCardWheelFonts();
    await loadLuckyCardIcons();
    art = await PreloadedLuckyCardArt.load();
  });

  group('screen size decides, as the real app is set up (desktopPlatform true)', () {
    final cases = <(String, Size, Arrangement)>[
      ('exactly the smallest desktop screen', const Size(1280, 720), Arrangement.desktop),
      ('a 1920 x 1080 screen (BlueStacks on a desktop)', const Size(1920, 1080), Arrangement.desktop),
      ('one dp too narrow', const Size(1279, 720), Arrangement.tablet),
      ('one dp too short', const Size(1280, 719), Arrangement.tablet),
      ('a small laptop window', const Size(1024, 768), Arrangement.tablet),
      ('a tablet, 1180 x 820', const Size(1180, 820), Arrangement.tablet),
      ('a phone-sized window', const Size(640, 360), Arrangement.phone),
      ('a large phone', const Size(915, 412), Arrangement.phone),
    ];
    for (final (name, size, want) in cases) {
      testWidgets('$name: ${want.name}', (tester) async {
        final rig = BetRig(tester);
        await openGame(tester, rig, size, desktopPlatform: true);
        expect(arrangementOnScreen(), want);
        expect(tester.takeException(), isNull);
        await rig.finish();
      });
    }
  });

  group('desktopPlatform left unset or false: never the desktop arrangement', () {
    testWidgets('unset, 1920 x 1080: the tablet arrangement', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig, const Size(1920, 1080));
      expect(arrangementOnScreen(), Arrangement.tablet);
      await rig.finish();
    });

    testWidgets('false, 1920 x 1080: the tablet arrangement', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig, const Size(1920, 1080), desktopPlatform: false);
      expect(arrangementOnScreen(), Arrangement.tablet);
      await rig.finish();
    });
  });

  group('resizing the window', () {
    testWidgets('dragging a window from 1920 x 1080 down under 1280 x 720 and back, in the middle of a round, never breaks the screen', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig, const Size(1920, 1080), desktopPlatform: true);
      expect(arrangementOnScreen(), Arrangement.desktop);
      rig.betTenOnEveryCard();
      await tester.pump();
      await rig.world.runUntil(91.5);
      await settle(tester);
      expect(rig.provider.isLocked, isTrue);

      tester.view.physicalSize = const Size(1000, 700);
      await settle(tester);
      expect(arrangementOnScreen(), Arrangement.tablet, reason: 'too small for the desktop: the tablet arrangement');
      expect(find.byType(LuckyCardWheelBinding), findsOneWidget, reason: 'the wheel takes the board\'s place, as on a tablet');
      expect(tester.takeException(), isNull, reason: 'the shrink');

      tester.view.physicalSize = const Size(1600, 900);
      await settle(tester);
      expect(arrangementOnScreen(), Arrangement.desktop);
      expect(find.byType(LuckyCardWheelBinding), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the growth');

      await rig.world.runUntil(99.0);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'the reveal after the resizes');
      final wheel = tester.state<LuckyCardWheelState>(find.byType(LuckyCardWheel));
      expect(wheel.result, isNotNull, reason: 'the wheel that is on screen landed and shows the winner');
      expect(rig.provider.cardRevealed, isTrue);
      await rig.runIntoNextCycle(8);
      await settle(tester);
      expect(rig.provider.isLocked, isFalse);
      expect(key('suit-hearts'), findsOneWidget, reason: 'the board is there for the next round');
      await rig.finish();
    });
  });
}
