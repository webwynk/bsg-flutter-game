// The Windows app's window rules: the minimum size for each screen, and the
// scale-down that keeps desktop layouts on small laptops. Phones and tablets
// must pass straight through DesktopFitBox.
import 'package:best_smart_game/utils/desktop_window.dart';
import 'package:best_smart_game/utils/device_type.dart';
import 'package:best_smart_game/widgets/desktop_window/desktop_fit_box.dart';
import 'package:best_smart_game/widgets/desktop_window/desktop_title_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shows the screen size the app sees, under the fit box, in a window of [size].
Future<Size> _seenSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  late Size seen;
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => DesktopFitBox(child: child!),
    home: Builder(builder: (context) {
      seen = MediaQuery.of(context).size;
      return const SizedBox.shrink();
    }),
  ));
  return seen;
}

/// Records which window button was pressed.
class _FakeControls extends DesktopWindowControls {
  final calls = <String>[];
  bool maximized = false;

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<void> toggleMaximize() async {
    calls.add('maximize');
    maximized = !maximized;
  }

  @override
  Future<void> close() async => calls.add('close');
}

/// The app under the title bar in a window of [size].
Future<Size> _frame(WidgetTester tester, Size size, DesktopWindowControls controls) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  late Size seen;
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => DesktopWindowFrame(
      controls: controls,
      child: DesktopFitBox(child: child!),
    ),
    home: Builder(builder: (context) {
      seen = MediaQuery.of(context).size;
      return const SizedBox.shrink();
    }),
  ));
  await tester.pump();
  return seen;
}

void main() {
  group('title bar', () {
    testWidgets('Windows: the bar is on top and the app gets the space under it', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final seen = await _frame(tester, const Size(1920, 1080), _FakeControls());
      final bar = tester.getRect(find.byType(DesktopTitleBar));
      debugDefaultTargetPlatformOverride = null;
      expect(bar.top, 0);
      expect(bar.height, kDesktopTitleBarHeight);
      expect(seen, const Size(1920, 1048));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Windows: at the smallest window the games still get a desktop screen', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final normal = await _frame(tester, kDesktopMinimumWindow, _FakeControls());
      final laptop = await _frame(tester, desktopMinimumWindow(const Size(1280, 720)), _FakeControls());
      debugDefaultTargetPlatformOverride = null;
      expect(isDesktopScreen(normal), isTrue, reason: '$normal');
      expect(isDesktopScreen(laptop), isTrue, reason: '$laptop');
    });

    testWidgets('the three buttons reach the window', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final controls = _FakeControls();
      await _frame(tester, const Size(1920, 1080), controls);
      await tester.tap(find.byKey(const ValueKey('window-minimize')));
      await tester.tap(find.byKey(const ValueKey('window-maximize')));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.filter_none), findsOneWidget, reason: 'the icon shows restore');
      await tester.tap(find.byKey(const ValueKey('window-close')));
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
      expect(controls.calls, ['minimize', 'maximize', 'close']);
    });

    testWidgets('a phone and a tablet get no bar', (tester) async {
      expect(await _frame(tester, const Size(844, 390), _FakeControls()), const Size(844, 390));
      expect(find.byType(DesktopTitleBar), findsNothing);
      expect(await _frame(tester, const Size(1180, 820), _FakeControls()), const Size(1180, 820));
      expect(find.byType(DesktopTitleBar), findsNothing);
    });
  });

  group('minimising', () {
    test('a phone or tablet going to the background counts as away', () {
      expect(countsAsAway(AppLifecycleState.paused), isTrue);
    });

    test('nothing else counts as away', () {
      expect(countsAsAway(AppLifecycleState.hidden), isFalse);
      expect(countsAsAway(AppLifecycleState.inactive), isFalse);
      expect(countsAsAway(AppLifecycleState.resumed), isFalse);
    });

    test('on Windows nothing counts as away', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final away = AppLifecycleState.values.any(countsAsAway);
      debugDefaultTargetPlatformOverride = null;
      expect(away, isFalse);
    });
  });

  group('opening position', () {
    test('centred above the taskbar on the screen', () {
      expect(desktopOpeningPosition(const Size(1920, 1080), const Size(1320, 752)), const Offset(300, 140));
    });

    test('never off the top or left of a small screen', () {
      expect(desktopOpeningPosition(const Size(1000, 600), const Size(1100, 600)), Offset.zero);
    });
  });

  group('minimum window', () {
    test('a normal screen leaves 720 high under the title bar, in 16:9', () {
      expect(kDesktopMinimumWindow.height - kDesktopTitleBarHeight, 720);
      expect(kDesktopMinimumWindow.aspectRatio, closeTo(16 / 9, 0.001));

      expect(desktopMinimumWindow(const Size(1920, 1080)), kDesktopMinimumWindow);
      expect(desktopMinimumWindow(const Size(2560, 1440)), kDesktopMinimumWindow);
    });

    test('an unknown screen gets the normal minimum', () {
      expect(desktopMinimumWindow(Size.zero), kDesktopMinimumWindow);
    });

    test('a 1920 x 1080 laptop at 150% stays 16:9 and clears the taskbar', () {
      final size = desktopMinimumWindow(const Size(1280, 720));
      expect(size.height, 672);
      expect(size.aspectRatio, closeTo(16 / 9, 0.001));
    });

    test('a 1366 x 768 laptop at 125% fits too', () {
      final size = desktopMinimumWindow(const Size(1092.8, 614.4));
      expect(size.width, lessThanOrEqualTo(1092.8));
      expect(size.height, lessThanOrEqualTo(614.4 - kTaskbarAllowance));
      expect(size.aspectRatio, closeTo(16 / 9, 0.001));
    });
  });

  group('scale-down', () {
    testWidgets('Windows, small window: the app still sees a desktop screen', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final seen = await _seenSize(tester, const Size(1093, 614));
      debugDefaultTargetPlatformOverride = null;
      expect(isDesktopScreen(seen), isTrue, reason: '$seen');
    });

    testWidgets('Windows, window just short of 720 high: still desktop', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final seen = await _seenSize(tester, const Size(1280, 681));
      debugDefaultTargetPlatformOverride = null;
      expect(isDesktopScreen(seen), isTrue, reason: '$seen');
    });

    testWidgets('Windows, big enough window: nothing changes', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final seen = await _seenSize(tester, const Size(1920, 1080));
      debugDefaultTargetPlatformOverride = null;
      expect(seen, const Size(1920, 1080));
    });

    testWidgets('a phone passes straight through', (tester) async {
      expect(await _seenSize(tester, const Size(390, 844)), const Size(390, 844));
      expect(await _seenSize(tester, const Size(844, 390)), const Size(844, 390));
    });

    testWidgets('a tablet passes straight through', (tester) async {
      expect(await _seenSize(tester, const Size(1024, 768)), const Size(1024, 768));
    });

    testWidgets('a tap still lands on the right button when scaled', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = const Size(1093, 614);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      var tapped = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => DesktopFitBox(child: child!),
        home: Align(
          alignment: Alignment.bottomRight,
          child: TextButton(onPressed: () => tapped++, child: const Text('GO')),
        ),
      ));
      await tester.tap(find.text('GO'));
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
      expect(tapped, 1);
    });
  });
}
