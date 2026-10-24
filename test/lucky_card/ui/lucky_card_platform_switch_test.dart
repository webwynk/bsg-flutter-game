// Tests for the platform switch (desktop step D3, spec §17BP, the user's decision 1): the desktop
// arrangement is chosen by PLATFORM (Windows, macOS, Linux, web) AND a screen of at least 1280 x 720 dp;
// Android and iOS keep the phone and tablet arrangements however big the screen. The screen is built
// the way the real app builds it: `desktopPlatform` left unset, so it asks the platform. (A test's
// `kIsWeb` is always false, so the web branch is the one line that cannot be exercised here.)

import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/screens/lucky_card_screen.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_controls_binding.dart' show LuckyCardChipBar;
import 'package:best_smart_game/widgets/lucky_card/lucky_card_desktop_pieces.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_platform.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_region_swap.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel_binding.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'lucky_card_layout_desktop_test.dart' show kDesktopReferenceSizes;
import 'ui_harness.dart';

late PreloadedLuckyCardArt art;

Finder key(String k) => find.byKey(ValueKey(k));

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The lobby opens the screen exactly as the real app does: no say about the platform.
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

/// Runs [body] with the app pretending to run on [platform], and always puts the real one back.
Future<void> onPlatform(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
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

  group('which platforms count as a desktop', () {
    test('Windows, macOS and Linux: yes', () {
      for (final p in [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux]) {
        debugDefaultTargetPlatformOverride = p;
        try {
          expect(luckyCardRunsOnDesktop(), isTrue, reason: '$p');
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }
    });

    test('Android, iOS and Fuchsia: no', () {
      for (final p in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.fuchsia]) {
        debugDefaultTargetPlatformOverride = p;
        try {
          expect(luckyCardRunsOnDesktop(), isFalse, reason: '$p');
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }
    });

    test('the test platform itself (Android) is not a desktop, so every older test sees the phone and tablet screens', () {
      expect(luckyCardRunsOnDesktop(), isFalse);
    });
  });

  group('the real screen, platform left unset, at the seven desktop sizes', () {
    for (final platform in [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux]) {
      for (final d in kDesktopReferenceSizes) {
        testWidgets('${platform.name} ${d.name} (${d.width.toInt()} x ${d.height.toInt()}): the desktop arrangement; a chip, a card and DOUBLE work', (tester) async {
          await onPlatform(platform, () async {
            final rig = BetRig(tester);
            await openGame(tester, rig, d.size);
            final l = LuckyCardLayout.of(d.size, desktopPlatform: true);
            expect(arrangementOnScreen(), Arrangement.desktop);
            expect(find.byType(LuckyCardRegionSwap), findsNothing);
            expect(find.byType(LuckyCardWheelBinding), findsOneWidget, reason: 'the wheel is always there');
            expect(tester.takeException(), isNull);
            await tester.tapAt(l.chip(1).center);
            await tester.pump();
            await tester.tapAt(l.cardCell(0, 0).center);
            await tester.pump();
            expect(rig.provider.total, 10);
            await tester.tapAt(l.actionButton(0).center);
            await tester.pump();
            expect(rig.provider.total, 20, reason: 'DOUBLE in the bottom bar');
            await rig.finish();
          });
        });
      }
    }
  });

  group('platform and size together', () {
    final cases = <(String, TargetPlatform, Size, Arrangement)>[
      ('Windows, exactly the smallest desktop screen', TargetPlatform.windows, const Size(1280, 720), Arrangement.desktop),
      ('Windows, one dp too narrow', TargetPlatform.windows, const Size(1279, 720), Arrangement.tablet),
      ('Windows, one dp too short', TargetPlatform.windows, const Size(1280, 719), Arrangement.tablet),
      ('Windows, a small laptop window', TargetPlatform.windows, const Size(1024, 768), Arrangement.tablet),
      ('Windows, a phone-sized window', TargetPlatform.windows, const Size(640, 360), Arrangement.phone),
      ('Android tablet, 1280 x 800 (same shape as a laptop)', TargetPlatform.android, const Size(1280, 800), Arrangement.tablet),
      ('Android with a huge 1920 x 1080 screen', TargetPlatform.android, const Size(1920, 1080), Arrangement.tablet),
      ('iPad, 1366 x 1024', TargetPlatform.iOS, const Size(1366, 1024), Arrangement.tablet),
      ('iPhone', TargetPlatform.iOS, const Size(844, 390), Arrangement.phone),
      ('Android phone', TargetPlatform.android, const Size(915, 412), Arrangement.phone),
    ];
    for (final (name, platform, size, want) in cases) {
      testWidgets('$name: ${want.name}', (tester) async {
        await onPlatform(platform, () async {
          final rig = BetRig(tester);
          await openGame(tester, rig, size);
          expect(arrangementOnScreen(), want);
          expect(tester.takeException(), isNull);
          await rig.finish();
        });
      });
    }

    testWidgets('an explicit setting beats the platform: Windows told "not a desktop" gets the tablet screen', (tester) async {
      await onPlatform(TargetPlatform.windows, () async {
        final rig = BetRig(tester);
        await openGame(tester, rig, const Size(1920, 1080), desktopPlatform: false);
        expect(arrangementOnScreen(), Arrangement.tablet);
        await rig.finish();
      });
    });

    testWidgets('an explicit setting beats the platform: Android told "desktop" gets the desktop screen', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        final rig = BetRig(tester);
        await openGame(tester, rig, const Size(1920, 1080), desktopPlatform: true);
        expect(arrangementOnScreen(), Arrangement.desktop);
        await rig.finish();
      });
    });
  });

  group('resizing the window of a desktop program', () {
    testWidgets('dragging a window from 1920 x 1080 down under 1280 x 720 and back, in the middle of a round, never breaks the screen', (tester) async {
      await onPlatform(TargetPlatform.windows, () async {
        final rig = BetRig(tester);
        await openGame(tester, rig, const Size(1920, 1080));
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
  });
}
