// The Windows app's window rules: the minimum size for each screen, and the
// scale-down that keeps desktop layouts on small laptops. Phones and tablets
// must pass straight through DesktopFitBox.
import 'package:best_smart_game/utils/desktop_window.dart';
import 'package:best_smart_game/utils/device_type.dart';
import 'package:best_smart_game/widgets/desktop_window/desktop_fit_box.dart';
import 'package:best_smart_game/widgets/desktop_window/desktop_title_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

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

/// Records every window action, in order, and keeps a pretend full-screen
/// state.
class _FakeControls extends DesktopWindowControls {
  _FakeControls({this.fullScreen = false});

  final calls = <String>[];
  bool fullScreen;

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<bool> isFullScreen() async => fullScreen;

  @override
  Future<void> setFullScreen(bool value) async {
    calls.add('fullscreen:$value');
    fullScreen = value;
  }

  @override
  Future<void> startDragging() async => calls.add('drag');
}

/// Text for a size or position in the recorded setup calls.
String _xy(double x, double y) => '${x.toStringAsFixed(1)}x${y.toStringAsFixed(1)}';

/// Records every call setUpDesktopWindow makes, in order. [failOn] makes the
/// call whose name starts with it throw, like a real window error.
class _FakeSetup extends DesktopWindowSetup {
  _FakeSetup(this.screen, {this.failOn, this.visibleAfterChecks = 1});

  final Size screen;
  final String? failOn;

  /// How many visibility checks answer "not visible yet" before "visible";
  /// a large number means the window never shows.
  final int visibleAfterChecks;
  int _visibilityChecks = 0;
  final calls = <String>[];

  void _record(String call) {
    calls.add(call);
    if (failOn != null && call.startsWith(failOn!)) throw Exception('fake window failure');
  }

  @override
  Future<Size> primaryScreenSize() async {
    _record('screen');
    return screen;
  }

  @override
  Future<void> ensureInitialized() async => _record('init');

  @override
  Future<void> setTitle(String title) async => _record('title:$title');

  @override
  Future<void> hideTitleBar() async => _record('hideTitleBar');

  @override
  Future<void> setPreventClose(bool prevent) async => _record('preventClose:$prevent');

  @override
  Future<void> setSize(Size size) async => _record('size:${_xy(size.width, size.height)}');

  @override
  Future<void> setMinimumSize(Size size) async => _record('minimum:${_xy(size.width, size.height)}');

  @override
  Future<void> setAspectRatio(double ratio) async => _record('aspect:${ratio.toStringAsFixed(4)}');

  @override
  Future<void> setPosition(Offset position) async => _record('position:${_xy(position.dx, position.dy)}');

  @override
  Future<void> show() async => _record('show');

  @override
  Future<bool> isVisible() async {
    _visibilityChecks++;
    final visible = _visibilityChecks >= visibleAfterChecks;
    _record('visible:$visible');
    return visible;
  }

  @override
  Future<void> setFullScreen(bool fullScreen) async => _record('fullscreen:$fullScreen');
}

/// The calls setUpDesktopWindow should make on [screen], up to and including
/// going full screen: everything for the small window first, so that leaving
/// full screen returns to the centred minimum window; then the window shown
/// and confirmed visible, so that leaving full screen does not hide it.
List<String> _expectedSetup(Size screen) {
  final minimum = desktopMinimumWindow(screen);
  final position = desktopOpeningPosition(screen, minimum);
  return [
    'screen',
    'init',
    'title:BSG',
    'hideTitleBar',
    'preventClose:true',
    'size:${_xy(minimum.width, minimum.height)}',
    'minimum:${_xy(minimum.width, minimum.height)}',
    'aspect:${(16 / 9).toStringAsFixed(4)}',
    'position:${_xy(position.dx, position.dy)}',
    'show',
    'visible:true',
    'fullscreen:true',
  ];
}

/// Sends a window event (such as restore after a minimise) to the title bar,
/// as window_manager would.
Future<void> _windowEvent(WidgetTester tester, void Function(WindowListener listener) event) async {
  event(tester.state(find.byType(DesktopTitleBar)) as WindowListener);
  await tester.pump();
  await tester.pump();
}

/// Two quick clicks on the title bar's drag area.
Future<void> _doubleClickBar(WidgetTester tester) async {
  final area = find.byKey(const ValueKey('window-drag-area'));
  await tester.tap(area);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(area);
  // Let the double-click detector's waiting time run out, so the next click
  // starts fresh and no timer is left at the end of the test.
  await tester.pump(kDoubleTapTimeout);
  await tester.pump();
}

/// Presses the gold maximise button and lets the bar update.
Future<void> _pressMaximize(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('window-maximize')));
  await tester.pump();
  await tester.pump();
}

/// Presses the gold minimise button and lets the bar update.
Future<void> _pressMinimize(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('window-minimize')));
  await tester.pump();
  await tester.pump();
}

/// Only the Windows app has the title bar.
final _windows = TargetPlatformVariant.only(TargetPlatform.windows);

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
      // Option A: from the small window, maximise means full screen.
      expect(controls.calls, ['minimize', 'fullscreen:true', 'close']);
    });

    testWidgets('a phone and a tablet get no bar', (tester) async {
      expect(await _frame(tester, const Size(844, 390), _FakeControls()), const Size(844, 390));
      expect(find.byType(DesktopTitleBar), findsNothing);
      expect(await _frame(tester, const Size(1180, 820), _FakeControls()), const Size(1180, 820));
      expect(find.byType(DesktopTitleBar), findsNothing);
    });
  });

  // Option A (plan 2026-11-19). Written before the code in phase 1; the ones
  // marked "phase 2" cover the behaviour built in phase 2.
  group('full screen title bar (option A)', () {
    testWidgets('opening in full screen shows the restore icon (phase 2)', (tester) async {
      final controls = _FakeControls(fullScreen: true);
      await _frame(tester, const Size(1920, 1080), controls);
      expect(find.byIcon(Icons.filter_none), findsOneWidget);
      expect(controls.calls, isEmpty);
    }, variant: _windows);

    testWidgets('maximise toggles full screen off and on, the icon follows, nothing else is called (phase 2)',
        (tester) async {
      final controls = _FakeControls(fullScreen: true);
      await _frame(tester, const Size(1920, 1080), controls);
      await _pressMaximize(tester);
      expect(find.byIcon(Icons.crop_square), findsOneWidget, reason: 'small window shows maximise');
      await _pressMaximize(tester);
      expect(find.byIcon(Icons.filter_none), findsOneWidget, reason: 'full screen shows restore');
      // No size, minimum, 16:9 or resizable call: the small window keeps the
      // 1336 x 752 minimum and 16:9 lock set at start-up.
      expect(controls.calls, ['fullscreen:false', 'fullscreen:true']);
    }, variant: _windows);

    testWidgets('minimise in full screen leaves full screen first, then minimises (phase 2)', (tester) async {
      final controls = _FakeControls(fullScreen: true);
      await _frame(tester, const Size(1920, 1080), controls);
      await _pressMinimize(tester);
      expect(controls.calls, ['fullscreen:false', 'minimize']);
    }, variant: _windows);

    testWidgets('coming back after a full-screen minimise returns to full screen, once (phase 2)', (tester) async {
      final controls = _FakeControls(fullScreen: true);
      await _frame(tester, const Size(1920, 1080), controls);
      await _pressMinimize(tester);
      await _windowEvent(tester, (l) => l.onWindowRestore());
      expect(controls.calls, ['fullscreen:false', 'minimize', 'fullscreen:true']);
      expect(find.byIcon(Icons.filter_none), findsOneWidget);
      await _windowEvent(tester, (l) => l.onWindowRestore());
      expect(controls.calls, ['fullscreen:false', 'minimize', 'fullscreen:true'], reason: 'a later restore does nothing');
    }, variant: _windows);

    testWidgets('minimise in the small window just minimises, and coming back stays small', (tester) async {
      final controls = _FakeControls();
      await _frame(tester, const Size(1336, 752), controls);
      await _pressMinimize(tester);
      await _windowEvent(tester, (l) => l.onWindowRestore());
      expect(controls.calls, ['minimize']);
    }, variant: _windows);

    testWidgets('a restore the bar did not cause (Win+D, taskbar) changes nothing', (tester) async {
      final controls = _FakeControls(fullScreen: true);
      await _frame(tester, const Size(1920, 1080), controls);
      await _windowEvent(tester, (l) => l.onWindowRestore());
      expect(controls.calls, isEmpty);
    }, variant: _windows);

    testWidgets('double-click on the bar toggles full screen off and on (phase 2)', (tester) async {
      final controls = _FakeControls(fullScreen: true);
      await _frame(tester, const Size(1920, 1080), controls);
      await _doubleClickBar(tester);
      await _doubleClickBar(tester);
      expect(controls.calls, ['fullscreen:false', 'fullscreen:true']);
    }, variant: _windows);

    testWidgets('dragging the bar moves the small window', (tester) async {
      final controls = _FakeControls();
      await _frame(tester, const Size(1336, 752), controls);
      await tester.drag(find.byKey(const ValueKey('window-drag-area')), const Offset(80, 0));
      // Let the double-click detector's waiting time run out.
      await tester.pump(kDoubleTapTimeout);
      expect(controls.calls, ['drag']);
    }, variant: _windows);

    testWidgets('dragging the bar does nothing in full screen (phase 2)', (tester) async {
      final controls = _FakeControls(fullScreen: true);
      await _frame(tester, const Size(1920, 1080), controls);
      await tester.drag(find.byKey(const ValueKey('window-drag-area')), const Offset(80, 0));
      // Let the double-click detector's waiting time run out.
      await tester.pump(kDoubleTapTimeout);
      expect(controls.calls, isEmpty);
    }, variant: _windows);

    testWidgets('close in full screen only asks to close, as today', (tester) async {
      final controls = _FakeControls(fullScreen: true);
      await _frame(tester, const Size(1920, 1080), controls);
      await tester.tap(find.byKey(const ValueKey('window-close')));
      await tester.pump();
      expect(controls.calls, ['close']);
    }, variant: _windows);
  });

  group('window setup (option A)', () {
    test('opens full screen, after the minimum size, 16:9 and centring are set (phase 2)', () async {
      final window = _FakeSetup(const Size(1920, 1080));
      await setUpDesktopWindow(window: window);
      expect(window.calls, _expectedSetup(const Size(1920, 1080)));
    });

    test('a small or scaled laptop screen gets its own minimum, then full screen (phase 2)', () async {
      final window = _FakeSetup(const Size(1280, 720));
      await setUpDesktopWindow(window: window);
      expect(window.calls, _expectedSetup(const Size(1280, 720)));
    });

    test('a window error before full screen is caught and full screen is not tried', () async {
      final window = _FakeSetup(const Size(1920, 1080), failOn: 'size:');
      await setUpDesktopWindow(window: window);
      expect(window.calls, _expectedSetup(const Size(1920, 1080)).sublist(0, 6));
      expect(window.calls, isNot(contains('fullscreen:true')));
    });

    test('full screen waits until the window is really visible (phase 4 fix)', () async {
      final window = _FakeSetup(const Size(1920, 1080), visibleAfterChecks: 3);
      await setUpDesktopWindow(window: window);
      final expected = _expectedSetup(const Size(1920, 1080));
      expect(window.calls, [
        ...expected.sublist(0, expected.length - 2),
        'visible:false',
        'visible:false',
        'visible:true',
        'fullscreen:true',
      ]);
    });

    test('a window that never shows stays out of full screen (phase 4 fix)', () async {
      final window = _FakeSetup(const Size(1920, 1080), visibleAfterChecks: 1000);
      await setUpDesktopWindow(window: window);
      expect(window.calls, isNot(contains('fullscreen:true')));
      expect(window.calls.where((c) => c == 'visible:false').length, 20, reason: 'about one second of checks');
    });

    test('a full-screen error is caught and leaves the centred small window set up (phase 2)', () async {
      final window = _FakeSetup(const Size(1920, 1080), failOn: 'fullscreen:');
      await setUpDesktopWindow(window: window);
      expect(window.calls, _expectedSetup(const Size(1920, 1080)));
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
