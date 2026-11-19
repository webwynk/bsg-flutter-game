import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// True only in the Windows app, never on a phone, a tablet or the web.
bool get isWindowsApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// Whether a [state] change counts as the player leaving the app for the
/// away-too-long logout. On Windows it never does: a minimised app keeps
/// running, with its timers, frames and connection alive (measured on the real
/// app), so the player stays logged in. Closing ends the session instead.
bool countsAsAway(AppLifecycleState state) => state == AppLifecycleState.paused && !isWindowsApp;

/// The window size every game's desktop layout is designed to fit.
const Size kDesktopDesignSize = Size(1280, 720);

/// Height of the app's own gold title bar.
const double kDesktopTitleBarHeight = 32;

/// The smallest 16:9 window that leaves the app at least 720 high under the
/// title bar.
const Size kDesktopMinimumWindow = Size(
  (720 + kDesktopTitleBarHeight) * 16 / 9,
  720 + kDesktopTitleBarHeight,
);

/// One screen as screen_retriever reports it on Windows, in that screen's own
/// logical units (physical pixels divided by [scale]).
///
/// [workOrigin] and [workSize] are the work area (the screen minus the
/// taskbar). They share a coordinate frame with window_manager's getBounds for
/// a window on this screen, because both divide by this screen's [scale]
/// (checked on a real two-screen PC, 2026-11-20). [size] is the screen size as
/// screen_retriever 0.2.2 reports it, which is short by the taskbar when the
/// taskbar is on the left or top; so [size] is never used on its own, only
/// through [right] and [bottom], which are exact either way.
class DesktopScreen {
  final Offset workOrigin;
  final Size workSize;
  final Size size;
  final double scale;

  const DesktopScreen({required this.workOrigin, required this.workSize, required this.size, required this.scale});

  /// The screen from a screen_retriever [display]; missing values fall back to
  /// the whole screen at scale 1.
  factory DesktopScreen.fromDisplay(Display display) => DesktopScreen(
        workOrigin: display.visiblePosition ?? Offset.zero,
        workSize: display.visibleSize ?? display.size,
        size: display.size,
        scale: (display.scaleFactor ?? 1).toDouble(),
      );

  /// The work area as a rectangle.
  Rect get workArea => workOrigin & workSize;

  /// The screen's right edge. Exact whatever side the taskbar is on, because
  /// screen_retriever computes size.width as monitor right minus work-area
  /// left (screen_retriever_windows_plugin.cpp:130-132).
  double get right => workOrigin.dx + size.width;

  /// The screen's bottom edge, exact for the same reason (:133-135).
  double get bottom => workOrigin.dy + size.height;
}

/// The smallest small-window size allowed in a [workArea] (the screen minus
/// the taskbar, logical): [kDesktopMinimumWindow], or the biggest 16:9 size
/// that fits the work area on a smaller or scaled screen. An unknown (empty)
/// work area gets [kDesktopMinimumWindow]. Windows applies the minimum in
/// physical pixels (minimum x the screen's scale), so a minimum that fits the
/// logical work area also fits the real screen.
Size desktopMinimumForWorkArea(Size workArea) {
  if (workArea.isEmpty) return kDesktopMinimumWindow;
  final scale = math.min(
    1.0,
    math.min(workArea.width / kDesktopMinimumWindow.width, workArea.height / kDesktopMinimumWindow.height),
  );
  return kDesktopMinimumWindow * scale;
}

/// Where a [window] sits to be centred in [screen]'s work area, in that
/// screen's coordinates; never off the work area's top or left.
Offset desktopCentredInWorkArea(DesktopScreen screen, Size window) => Offset(
      screen.workOrigin.dx + math.max(0, (screen.workSize.width - window.width) / 2),
      screen.workOrigin.dy + math.max(0, (screen.workSize.height - window.height) / 2),
    );

/// The screen a window with logical [bounds] (window_manager getBounds) at
/// [devicePixelRatio] is on: among the screens with that scale (only those
/// share the window's coordinate frame), the one whose work area holds the
/// window's centre, else the one it overlaps most. Null when none matches.
DesktopScreen? desktopScreenOfWindow(Rect bounds, double devicePixelRatio, List<DesktopScreen> screens) {
  final sameScale = screens.where((screen) => (screen.scale - devicePixelRatio).abs() < 0.01).toList();
  for (final screen in sameScale) {
    if (screen.workArea.contains(bounds.center)) return screen;
  }
  DesktopScreen? best;
  var bestArea = 0.0;
  for (final screen in sameScale) {
    final overlap = screen.workArea.intersect(bounds);
    if (overlap.width <= 0 || overlap.height <= 0) continue;
    final area = overlap.width * overlap.height;
    if (area > bestArea) {
      best = screen;
      bestArea = area;
    }
  }
  return best;
}

/// How far (logical pixels) a window edge may pass the screen's edge and
/// still count as fitting: screen_retriever rounds each value to a whole
/// logical pixel, which can put a correct full screen up to about 1 off.
const double _kEdgeRounding = 2;

/// Whether a full-screen window with logical [bounds] fits [screen]: its right
/// and bottom edges are not past the screen's. A window that Windows kept at a
/// too-big minimum grows to the right and down from the screen's top-left
/// corner, which is exactly what this catches.
bool desktopFullScreenFits(Rect bounds, DesktopScreen screen) =>
    bounds.right <= screen.right + _kEdgeRounding && bounds.bottom <= screen.bottom + _kEdgeRounding;

/// The window calls [setUpDesktopWindow] makes. The default passes each one
/// straight to the real window (window_manager) and screen (screen_retriever);
/// tests pass their own to record the calls and their order.
class DesktopWindowSetup {
  const DesktopWindowSetup();

  /// The primary screen with its work area and scale.
  Future<DesktopScreen> primaryScreen() async => DesktopScreen.fromDisplay(await screenRetriever.getPrimaryDisplay());

  Future<void> ensureInitialized() => windowManager.ensureInitialized();

  Future<void> setTitle(String title) => windowManager.setTitle(title);

  /// Hides the native title bar and its buttons (DesktopTitleBar replaces them).
  Future<void> hideTitleBar() => windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);

  Future<void> setPreventClose(bool prevent) => windowManager.setPreventClose(prevent);

  Future<void> setSize(Size size) => windowManager.setSize(size);

  Future<void> setMinimumSize(Size size) => windowManager.setMinimumSize(size);

  Future<void> setAspectRatio(double ratio) => windowManager.setAspectRatio(ratio);

  Future<void> setPosition(Offset position) => windowManager.setPosition(position);

  /// Shows the window and brings it to the front. window_manager does the
  /// showing asynchronously, so check [isVisible] afterwards.
  Future<void> show() => windowManager.show();

  /// Whether the window is visible on screen.
  Future<bool> isVisible() => windowManager.isVisible();

  /// Turns window_manager's full screen on (the whole monitor, taskbar
  /// included) or off. Setup only turns it on.
  Future<void> setFullScreen(bool fullScreen) => windowManager.setFullScreen(fullScreen);
}

/// Sets up the Windows app's window before the first frame, through [window]
/// (the real window unless a test passes its own): the title BSG, the native
/// title bar hidden (DesktopTitleBar replaces it), the minimum size for the
/// primary screen's work area, that size as the opening size, 16:9 resizing,
/// centred in that work area, then shown, then the minimum removed, and then
/// full screen on that screen. A failure here is only logged, so a window
/// problem can never stop the game from opening (if full screen fails or the
/// window never shows, the centred small window stays).
Future<void> setUpDesktopWindow({DesktopWindowSetup window = const DesktopWindowSetup()}) async {
  try {
    // The window always opens on the primary screen. Flutter's own display
    // info is not usable on Windows (its docs say size and pixel ratio are
    // invalid on desktops), so screen_retriever gives the screen.
    final screen = await window.primaryScreen();
    final minimum = desktopMinimumForWorkArea(screen.workSize);
    await window.ensureInitialized();
    await window.setTitle('BSG');
    await window.hideTitleBar();
    // DesktopCloseGuard decides what happens when the window is asked to close.
    await window.setPreventClose(true);
    await window.setSize(minimum);
    await window.setMinimumSize(minimum);
    await window.setAspectRatio(16 / 9);
    // Not windowManager.center(): that follows the mouse, and on two screens
    // with different scaling it left the window across both.
    await window.setPosition(desktopCentredInWorkArea(screen, minimum));
    // window_manager saves the window's style when full screen begins and
    // puts it back when full screen ends. The runner only shows the window
    // after Flutter's first frame, so without this the saved style is
    // "hidden" and the first exit from full screen (maximise, double-click,
    // minimise) made the window invisible. Show it first and wait until it
    // really is visible.
    await window.show();
    if (!await _becameVisible(window)) {
      debugPrint('Desktop window did not become visible; staying out of full screen.');
      return;
    }
    // No minimum in full screen: Windows enforces the minimum (x the screen's
    // scale) even on window_manager's full-screen resize, so a minimum bigger
    // than the screen left the full screen too big and cut off (measured:
    // 2004 x 1128 on a 1920 x 1080 screen at 150%). The title bar sets the
    // small window's minimum again whenever it leaves full screen.
    await window.setMinimumSize(Size.zero);
    // Last: leaving full screen returns to the window as it was when full
    // screen began, so it must already be the centred minimum-size window.
    await window.setFullScreen(true);
  } catch (e) {
    debugPrint('Desktop window setup failed: $e');
  }
}

/// Waits up to about one second (20 checks, 50 ms apart) for [window] to be
/// visible. True as soon as it is.
Future<bool> _becameVisible(DesktopWindowSetup window) async {
  for (var i = 0; i < 20; i++) {
    if (await window.isVisible()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return false;
}
