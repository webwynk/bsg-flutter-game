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

  // A window that always fits the main screen at 100%, so the bar's screen
  // checks find nothing to fix. Minimums are accepted silently here (the
  // screen tests below use _ScreenFake, which records them).
  @override
  Future<void> setMinimumSize(Size size) async {}

  @override
  Future<Rect> getBounds() async => fullScreen
      ? const Rect.fromLTWH(0, 0, 1920, 1080)
      : Rect.fromLTWH(291.6, 140, kDesktopMinimumWindow.width, kDesktopMinimumWindow.height);

  @override
  double devicePixelRatio() => 1;

  @override
  Future<List<DesktopScreen>> screens() async => const [_main100];

  @override
  Future<void> setSize(Size size) async => calls.add('size');

  @override
  Future<void> setPosition(Offset position) async => calls.add('position');

  @override
  Future<void> maximize() async => calls.add('maximize');
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

  /// The primary screen with a 48-pixel taskbar at the bottom, at scale 1
  /// (setup works in the primary screen's own logical units).
  @override
  Future<DesktopScreen> primaryScreen() async {
    _record('primaryScreen');
    return DesktopScreen(
      workOrigin: Offset.zero,
      workSize: Size(screen.width, screen.height - 48),
      size: screen,
      scale: 1,
    );
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
/// and confirmed visible, so that leaving full screen does not hide it; then
/// the minimum removed (fix A), so full screen can fit any screen.
List<String> _expectedSetup(Size screen) {
  final primary = DesktopScreen(
    workOrigin: Offset.zero,
    workSize: Size(screen.width, screen.height - 48),
    size: screen,
    scale: 1,
  );
  final minimum = desktopMinimumForWorkArea(primary.workSize);
  final position = desktopCentredInWorkArea(primary, minimum);
  return [
    'primaryScreen',
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
    'minimum:${_xy(0, 0)}',
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

// ---------------------------------------------------------------------------
// Fix A (any screen size / scaling). Real numbers from Hasan's PC, measured on
// 2026-11-20 (phase 0 report): main screen 1920 x 1080 at 100%, second screen
// 1920 x 1080 at 150% placed at physical (1920, 53).
// ---------------------------------------------------------------------------

/// The main screen at 100%, taskbar at the bottom.
const _main100 = DesktopScreen(workOrigin: Offset.zero, workSize: Size(1920, 1032), size: Size(1920, 1080), scale: 1);

/// The second screen at 150%, as screen_retriever reported it on the real PC.
const _second150 = DesktopScreen(workOrigin: Offset(1280, 35), workSize: Size(1280, 672), size: Size(1280, 720), scale: 1.5);

/// The text the screen fake records for a minimum of [size].
String _min(Size size) => 'minimum:${_xy(size.width, size.height)}';

/// The minimum that means "no minimum".
final _noMin = _min(Size.zero);

/// A pretend window on pretend screens that behaves like the real one, as
/// measured in phase 0:
/// - full screen covers the screen the window is on, but Windows never makes
///   a window smaller than its minimum, so a too-big minimum makes the
///   full-screen window bigger than the screen;
/// - leaving full screen goes back to the small window's saved place
///   ([smallScreenIndex], [smallBounds]);
/// - [stuckOversized] makes that many full-screen entries come out too big
///   whatever the minimum (for the safety net tests).
/// Every action is recorded in [calls]; reads (bounds, screens) are not.
class _ScreenFake extends DesktopWindowControls {
  _ScreenFake({
    required List<DesktopScreen> screens,
    this.fullScreen = false,
    this.screenIndex = 0,
    this.smallScreenIndex = 0,
    Rect? smallBounds,
    Size? minimum,
    this.stuckOversized = 0,
  })  : screenList = screens,
        smallBounds = smallBounds ?? Rect.fromLTWH(291.6, 140, kDesktopMinimumWindow.width, kDesktopMinimumWindow.height),
        minimum = minimum ?? kDesktopMinimumWindow;

  final List<DesktopScreen> screenList;
  bool fullScreen;
  int screenIndex;
  int smallScreenIndex;
  Rect smallBounds;
  Size minimum;
  int stuckOversized;
  bool maximized = false;
  Rect _fullBounds = Rect.zero;
  final calls = <String>[];

  DesktopScreen get _screen => screenList[screenIndex];

  void _enterFullScreen() {
    final screen = _screen;
    var size = Size(
      screen.size.width > minimum.width ? screen.size.width : minimum.width,
      screen.size.height > minimum.height ? screen.size.height : minimum.height,
    );
    if (stuckOversized > 0) {
      stuckOversized--;
      size = Size(screen.size.width + 56, screen.size.height + 32);
    }
    _fullBounds = screen.workOrigin & size;
  }

  @override
  Future<bool> isFullScreen() async => fullScreen;

  @override
  Future<void> setFullScreen(bool value) async {
    calls.add('fullscreen:$value');
    fullScreen = value;
    if (value) {
      maximized = false;
      _enterFullScreen();
    } else {
      screenIndex = smallScreenIndex;
    }
  }

  @override
  Future<Rect> getBounds() async {
    if (fullScreen) return _fullBounds;
    if (maximized) return _screen.workArea;
    return smallBounds;
  }

  @override
  double devicePixelRatio() => _screen.scale;

  @override
  Future<List<DesktopScreen>> screens() async => screenList;

  @override
  Future<void> setMinimumSize(Size size) async {
    calls.add(_min(size));
    minimum = size;
  }

  @override
  Future<void> setSize(Size size) async {
    calls.add('size:${_xy(size.width, size.height)}');
    smallBounds = smallBounds.topLeft & size;
  }

  @override
  Future<void> setPosition(Offset position) async {
    calls.add('position:${_xy(position.dx, position.dy)}');
    smallBounds = position & smallBounds.size;
  }

  @override
  Future<void> maximize() async {
    calls.add('maximize');
    maximized = true;
  }

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> startDragging() async => calls.add('drag');
}

/// The title bar over the app on [fake]'s window, with the calls made while
/// it starts up cleared, so a test sees only what its own action causes.
Future<void> _frameOn(WidgetTester tester, _ScreenFake fake, {bool keepStartupCalls = false}) async {
  await _frame(tester, const Size(1920, 1080), fake);
  await tester.pump();
  await tester.pump();
  if (!keepStartupCalls) fake.calls.clear();
}

/// True when no minimum other than "none" was set while in full screen.
bool _noMinimumWhileFullScreen(List<String> calls) {
  var full = false;
  for (final call in calls) {
    if (call == 'fullscreen:true') full = true;
    if (call == 'fullscreen:false') full = false;
    if (full && call.startsWith('minimum:') && call != _noMin) return false;
  }
  return true;
}

/// A 16:9 work area check shared by the size matrix.
void _expectFitsWorkArea(Size minimum, Size work, String reason) {
  expect(minimum.width, lessThanOrEqualTo(work.width + 0.01), reason: '$reason width');
  expect(minimum.height, lessThanOrEqualTo(work.height + 0.01), reason: '$reason height');
  expect(minimum.aspectRatio, closeTo(16 / 9, 0.001), reason: '$reason 16:9');
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
      final laptop = await _frame(tester, desktopMinimumForWorkArea(const Size(1280, 672)), _FakeControls());
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
      final upToShow = expected.sublist(0, expected.indexOf('show') + 1);
      expect(window.calls, [
        ...upToShow,
        'visible:false',
        'visible:false',
        'visible:true',
        ...expected.sublist(expected.indexOf('visible:true') + 1),
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

  // Same expected values as before fix A; the opening position is now worked
  // out from the screen's real work area instead of a fixed 48-pixel taskbar.
  group('opening position', () {
    test('centred above the taskbar on the screen', () {
      expect(desktopCentredInWorkArea(_main100, const Size(1320, 752)), const Offset(300, 140));
    });

    test('never off the top or left of a small screen', () {
      const small = DesktopScreen(workOrigin: Offset.zero, workSize: Size(1000, 552), size: Size(1000, 600), scale: 1);
      expect(desktopCentredInWorkArea(small, const Size(1100, 600)), Offset.zero);
    });
  });

  group('minimum window', () {
    test('a normal screen leaves 720 high under the title bar, in 16:9', () {
      expect(kDesktopMinimumWindow.height - kDesktopTitleBarHeight, 720);
      expect(kDesktopMinimumWindow.aspectRatio, closeTo(16 / 9, 0.001));

      // Same expected values as before fix A, now from the work area (screen
      // minus a 48-pixel taskbar).
      expect(desktopMinimumForWorkArea(const Size(1920, 1032)), kDesktopMinimumWindow);
      expect(desktopMinimumForWorkArea(const Size(2560, 1392)), kDesktopMinimumWindow);
    });

    test('an unknown screen gets the normal minimum', () {
      expect(desktopMinimumForWorkArea(Size.zero), kDesktopMinimumWindow);
    });

    test('a 1920 x 1080 laptop at 150% stays 16:9 and clears the taskbar', () {
      final size = desktopMinimumForWorkArea(const Size(1280, 672));
      expect(size.height, 672);
      expect(size.aspectRatio, closeTo(16 / 9, 0.001));
    });

    test('a 1366 x 768 laptop at 125% fits too', () {
      final size = desktopMinimumForWorkArea(const Size(1092.8, 614.4 - 48));
      expect(size.width, lessThanOrEqualTo(1092.8));
      expect(size.height, lessThanOrEqualTo(614.4 - 48));
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

  // ===== Fix A: any screen size and scaling (written before the code in
  // phase 1, built in phase 2). Tests are marked "(fix A)". =====

  group('small-window minimum for a work area (fix A)', () {
    test('a big enough work area gets today\'s 1336 x 752', () {
      expect(desktopMinimumForWorkArea(const Size(1920, 1032)), kDesktopMinimumWindow);
      expect(desktopMinimumForWorkArea(const Size(2560, 1392)), kDesktopMinimumWindow);
    });

    test('the 150% screen from Hasan\'s PC gets the biggest 16:9 that fits 1280 x 672', () {
      final minimum = desktopMinimumForWorkArea(_second150.workSize);
      expect(minimum.height, closeTo(672, 0.01));
      expect(minimum.width, closeTo(672 * 16 / 9, 0.01));
    });

    test('every common screen, scaling and taskbar position gets a fitting 16:9 minimum', () {
      const resolutions = [
        Size(1366, 768),
        Size(1536, 864),
        Size(1600, 900),
        Size(1920, 1080),
        Size(2560, 1440),
        Size(3840, 2160),
      ];
      const scales = [1.0, 1.25, 1.5, 1.75, 2.0];
      const taskbar = 48.0; // logical, the Windows default at any scaling
      for (final physical in resolutions) {
        for (final scale in scales) {
          final logical = physical / scale;
          final workAreas = {
            'bottom': Size(logical.width, logical.height - taskbar),
            'top': Size(logical.width, logical.height - taskbar),
            'left': Size(logical.width - taskbar, logical.height),
            'hidden': logical,
          };
          workAreas.forEach((side, work) {
            final reason = '${physical.width.toInt()}x${physical.height.toInt()} at ${(scale * 100).toInt()}%, taskbar $side';
            final minimum = desktopMinimumForWorkArea(work);
            _expectFitsWorkArea(minimum, work, reason);
            final roomy = work.width >= kDesktopMinimumWindow.width && work.height >= kDesktopMinimumWindow.height;
            if (roomy) expect(minimum, kDesktopMinimumWindow, reason: '$reason: room for the normal minimum');
            // The physical size Windows enforces never exceeds the screen.
            expect(minimum.width * scale, lessThanOrEqualTo(physical.width + 0.01), reason: '$reason physical');
            expect(minimum.height * scale, lessThanOrEqualTo(physical.height + 0.01), reason: '$reason physical');
          });
        }
      }
    });

    test('an unknown (empty) work area gets the normal minimum', () {
      expect(desktopMinimumForWorkArea(Size.zero), kDesktopMinimumWindow);
    });
  });

  group('centring in a work area (fix A)', () {
    test('centred on the main screen above the taskbar', () {
      final position = desktopCentredInWorkArea(_main100, kDesktopMinimumWindow);
      expect(position.dx, closeTo((1920 - kDesktopMinimumWindow.width) / 2, 0.01));
      expect(position.dy, closeTo((1032 - 752) / 2, 0.01));
    });

    test('centred on the 150% screen in its own coordinates', () {
      final window = desktopMinimumForWorkArea(_second150.workSize);
      final position = desktopCentredInWorkArea(_second150, window);
      expect(position.dx, closeTo(1280 + (1280 - window.width) / 2, 0.01));
      expect(position.dy, closeTo(35, 0.01));
    });

    test('never off the top or left of the work area', () {
      final position = desktopCentredInWorkArea(_second150, const Size(2000, 1000));
      expect(position, const Offset(1280, 35));
    });
  });

  group('which screen the window is on (fix A)', () {
    test('real numbers: the window on the 150% screen', () {
      final screen = desktopScreenOfWindow(const Rect.fromLTWH(1400, 133.3, 1280, 720), 1.5, [_main100, _second150]);
      expect(screen, same(_second150));
    });

    test('real numbers: the window on the main screen', () {
      final screen = desktopScreenOfWindow(const Rect.fromLTWH(10, 10, 1280, 720), 1.0, [_second150, _main100]);
      expect(screen, same(_main100));
    });

    test('a full-screen window on the 150% screen', () {
      final screen = desktopScreenOfWindow(const Rect.fromLTWH(1280, 35, 1280, 720), 1.5, [_main100, _second150]);
      expect(screen, same(_second150));
    });

    test('two screens with the same scaling: the one holding the window\'s centre', () {
      const right = DesktopScreen(workOrigin: Offset(1920, 0), workSize: Size(1920, 1032), size: Size(1920, 1080), scale: 1);
      expect(desktopScreenOfWindow(const Rect.fromLTWH(2000, 100, 1336, 752), 1.0, [_main100, right]), same(right));
      expect(desktopScreenOfWindow(const Rect.fromLTWH(1500, 100, 1336, 752), 1.0, [_main100, right]), same(right),
          reason: 'across both, centre on the right');
      expect(desktopScreenOfWindow(const Rect.fromLTWH(100, 100, 1336, 752), 1.0, [_main100, right]), same(_main100));
    });

    test('no screen with the window\'s scaling, or nowhere near a screen: none', () {
      expect(desktopScreenOfWindow(const Rect.fromLTWH(10, 10, 1280, 720), 1.25, [_main100, _second150]), isNull);
      expect(desktopScreenOfWindow(const Rect.fromLTWH(9000, 9000, 100, 100), 1.0, [_main100, _second150]), isNull);
    });
  });

  group('does full screen fit the screen (fix A)', () {
    test('real numbers: a correct full screen on the 150% screen fits', () {
      // Physical (1920,53)-(3840,1133) / 1.5.
      expect(desktopFullScreenFits(const Rect.fromLTRB(1280, 35.33, 2560, 755.33), _second150), isTrue);
    });

    test('real numbers: the measured cut-off window (2004 x 1128) does not fit', () {
      // Physical (1920,53)-(3924,1181) / 1.5.
      expect(desktopFullScreenFits(const Rect.fromLTRB(1280, 35.33, 2616, 787.33), _second150), isFalse);
    });

    test('the main screen at 100% fits exactly', () {
      expect(desktopFullScreenFits(const Rect.fromLTWH(0, 0, 1920, 1080), _main100), isTrue);
      expect(desktopFullScreenFits(const Rect.fromLTWH(0, 0, 1921, 1080), _main100), isTrue, reason: 'rounding');
      expect(desktopFullScreenFits(const Rect.fromLTWH(0, 0, 1936, 1080), _main100), isFalse);
    });

    test('taskbar on the left: screen_retriever\'s short size still gives the right edge', () {
      // Monitor 0..1920; work area starts at 48; screen_retriever's size.width
      // is 1920 - 48 = 1872 (its known quirk), so the right edge is still 1920.
      const leftTaskbar = DesktopScreen(workOrigin: Offset(48, 0), workSize: Size(1872, 1080), size: Size(1872, 1080), scale: 1);
      expect(desktopFullScreenFits(const Rect.fromLTWH(0, 0, 1920, 1080), leftTaskbar), isTrue);
      expect(desktopFullScreenFits(const Rect.fromLTWH(0, 0, 2004, 1128), leftTaskbar), isFalse);
    });
  });

  group('title bar on any screen (fix A)', () {
    testWidgets('maximise from the small window: no minimum first, then full screen', (tester) async {
      final fake = _ScreenFake(screens: [_main100]);
      await _frameOn(tester, fake);
      await _pressMaximize(tester);
      expect(fake.calls, [_noMin, 'fullscreen:true']);
    }, variant: _windows);

    testWidgets('maximise from full screen: leaves, then the minimum for the window\'s screen', (tester) async {
      final fake = _ScreenFake(screens: [_main100], fullScreen: true, minimum: Size.zero);
      await _frameOn(tester, fake);
      await _pressMaximize(tester);
      expect(fake.calls, ['fullscreen:false', _min(kDesktopMinimumWindow)]);
    }, variant: _windows);

    testWidgets('leaving full screen onto the 150% screen sets the minimum that fits it', (tester) async {
      final fake = _ScreenFake(
        screens: [_main100, _second150],
        fullScreen: true,
        screenIndex: 1,
        smallScreenIndex: 1,
        smallBounds: const Rect.fromLTWH(1300, 35, 1200, 675),
        minimum: Size.zero,
      );
      await _frameOn(tester, fake);
      await _pressMaximize(tester);
      expect(fake.calls, ['fullscreen:false', _min(desktopMinimumForWorkArea(_second150.workSize))]);
    }, variant: _windows);

    testWidgets('an oversized small window (measured: 2004 wide on 1920) is resized and centred', (tester) async {
      final fake = _ScreenFake(
        screens: [_main100],
        fullScreen: true,
        smallBounds: const Rect.fromLTWH(291, 140, 2004, 1128),
        minimum: Size.zero,
      );
      await _frameOn(tester, fake);
      await _pressMaximize(tester);
      final centred = desktopCentredInWorkArea(_main100, kDesktopMinimumWindow);
      expect(fake.calls, [
        'fullscreen:false',
        _min(kDesktopMinimumWindow),
        'size:${_xy(kDesktopMinimumWindow.width, kDesktopMinimumWindow.height)}',
        'position:${_xy(centred.dx, centred.dy)}',
      ]);
    }, variant: _windows);

    testWidgets('a small window shrunk by a scaling change (measured 594 x 334) is resized and centred (fix A)',
        (tester) async {
      final fake = _ScreenFake(
        screens: [_main100],
        fullScreen: true,
        smallBounds: const Rect.fromLTWH(148, 216, 594, 334),
        minimum: Size.zero,
      );
      await _frameOn(tester, fake);
      await _pressMaximize(tester);
      final centred = desktopCentredInWorkArea(_main100, kDesktopMinimumWindow);
      expect(fake.calls, [
        'fullscreen:false',
        _min(kDesktopMinimumWindow),
        'size:${_xy(kDesktopMinimumWindow.width, kDesktopMinimumWindow.height)}',
        'position:${_xy(centred.dx, centred.dy)}',
      ]);
    }, variant: _windows);

    testWidgets('a small window the player dragged partly off the screen is left where it is (fix A)',
        (tester) async {
      final fake = _ScreenFake(
        screens: [_main100],
        smallBounds: Rect.fromLTWH(1500, 600, kDesktopMinimumWindow.width, kDesktopMinimumWindow.height),
      );
      await _frameOn(tester, fake);
      await _windowEvent(tester, (l) => l.onWindowMoved());
      expect(fake.calls, [_min(kDesktopMinimumWindow)], reason: 'minimum only: no resize, no move');
    }, variant: _windows);

    testWidgets('double-click does the same as the maximise button, both ways', (tester) async {
      final fake = _ScreenFake(screens: [_main100], fullScreen: true, minimum: Size.zero);
      await _frameOn(tester, fake);
      await _doubleClickBar(tester);
      await _doubleClickBar(tester);
      expect(fake.calls, ['fullscreen:false', _min(kDesktopMinimumWindow), _noMin, 'fullscreen:true']);
    }, variant: _windows);

    testWidgets('minimise from full screen, then back: fitted minimum before, no minimum after', (tester) async {
      final fake = _ScreenFake(screens: [_main100], fullScreen: true, minimum: Size.zero);
      await _frameOn(tester, fake);
      await _pressMinimize(tester);
      await _windowEvent(tester, (l) => l.onWindowRestore());
      expect(fake.calls, ['fullscreen:false', _min(kDesktopMinimumWindow), 'minimize', _noMin, 'fullscreen:true']);
    }, variant: _windows);

    testWidgets('no minimum is ever set while in full screen', (tester) async {
      final fake = _ScreenFake(screens: [_main100]);
      await _frameOn(tester, fake);
      for (var i = 0; i < 3; i++) {
        await _pressMaximize(tester);
      }
      await _pressMinimize(tester);
      await _windowEvent(tester, (l) => l.onWindowRestore());
      await _doubleClickBar(tester);
      expect(fake.calls, contains('fullscreen:true'));
      expect(_noMinimumWhileFullScreen(fake.calls), isTrue, reason: '${fake.calls}');
    }, variant: _windows);

    testWidgets('safety net: a full screen that comes out too big is redone once', (tester) async {
      final fake = _ScreenFake(screens: [_main100], stuckOversized: 1);
      await _frameOn(tester, fake);
      await _pressMaximize(tester);
      expect(fake.calls, [_noMin, 'fullscreen:true', 'fullscreen:false', _noMin, 'fullscreen:true']);
      expect(find.byIcon(Icons.filter_none), findsOneWidget);
    }, variant: _windows);

    testWidgets('safety net: still too big after the retry gives a normal maximised window', (tester) async {
      final fake = _ScreenFake(screens: [_main100], stuckOversized: 2);
      await _frameOn(tester, fake);
      await _pressMaximize(tester);
      expect(fake.calls, [
        _noMin,
        'fullscreen:true',
        'fullscreen:false',
        _noMin,
        'fullscreen:true',
        'fullscreen:false',
        _min(kDesktopMinimumWindow),
        'maximize',
      ]);
    }, variant: _windows);

    testWidgets('at start-up, a full screen that does not fit its screen is redone', (tester) async {
      // Started with today's minimum (1336 x 752) on a 150% screen: too big.
      final fake = _ScreenFake(screens: [_second150], fullScreen: true, screenIndex: 0, smallScreenIndex: 0);
      fake.setFullScreen(true); // put the pretend window in its (oversized) full-screen place
      fake.calls.clear();
      await _frameOn(tester, fake, keepStartupCalls: true);
      expect(fake.calls, ['fullscreen:false', _noMin, 'fullscreen:true']);
    }, variant: _windows);

    testWidgets('at start-up, a full screen that fits is left alone', (tester) async {
      final fake = _ScreenFake(screens: [_main100], fullScreen: true, minimum: Size.zero);
      fake.setFullScreen(true);
      fake.calls.clear();
      await _frameOn(tester, fake, keepStartupCalls: true);
      expect(fake.calls, isEmpty);
    }, variant: _windows);
  });

  group('window setup on any screen (fix A)', () {
    List<String> expectedFixA(Size screen) {
      final work = Size(screen.width, screen.height - 48);
      final minimum = desktopMinimumForWorkArea(work);
      final position = desktopCentredInWorkArea(
          DesktopScreen(workOrigin: Offset.zero, workSize: work, size: screen, scale: 1), minimum);
      return [
        'primaryScreen',
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
        'minimum:${_xy(0, 0)}',
        'fullscreen:true',
      ];
    }

    test('main screen: small window from the work area, then no minimum, then full screen', () async {
      final window = _FakeSetup(const Size(1920, 1080));
      await setUpDesktopWindow(window: window);
      expect(window.calls, expectedFixA(const Size(1920, 1080)));
    });

    test('a laptop that starts at 150% (1280 x 720 logical)', () async {
      final window = _FakeSetup(const Size(1280, 720));
      await setUpDesktopWindow(window: window);
      expect(window.calls, expectedFixA(const Size(1280, 720)));
    });

    test('a failure while removing the minimum is caught; the small window stays', () async {
      final window = _FakeSetup(const Size(1920, 1080), failOn: 'minimum:0.0');
      await setUpDesktopWindow(window: window);
      expect(window.calls, isNot(contains('fullscreen:true')));
      expect(window.calls, contains('show'));
    });
  });
}
