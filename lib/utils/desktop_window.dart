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

/// Height left for the Windows taskbar when choosing the minimum window size.
const double kTaskbarAllowance = 48;

/// The smallest 16:9 window that leaves the app at least 720 high under the
/// title bar.
const Size kDesktopMinimumWindow = Size(
  (720 + kDesktopTitleBarHeight) * 16 / 9,
  720 + kDesktopTitleBarHeight,
);

/// The smallest window allowed on a screen of [display] logical size:
/// [kDesktopMinimumWindow], or the biggest 16:9 size that fits above the
/// taskbar on a smaller or heavily scaled laptop screen. An unknown (empty)
/// screen gets [kDesktopMinimumWindow].
Size desktopMinimumWindow(Size display) {
  if (display.isEmpty) return kDesktopMinimumWindow;
  final usableHeight = display.height - kTaskbarAllowance;
  final scale = [
    1.0,
    display.width / kDesktopMinimumWindow.width,
    usableHeight / kDesktopMinimumWindow.height,
  ].reduce((a, b) => a < b ? a : b);
  return kDesktopMinimumWindow * scale;
}

/// Where a [window] sits to be centred on [screen], never off its top or left.
Offset desktopOpeningPosition(Size screen, Size window) => Offset(
      ((screen.width - window.width) / 2).clamp(0, double.infinity),
      ((screen.height - kTaskbarAllowance - window.height) / 2).clamp(0, double.infinity),
    );

/// The window calls [setUpDesktopWindow] makes. The default passes each one
/// straight to the real window (window_manager) and screen (screen_retriever);
/// tests pass their own to record the calls and their order.
class DesktopWindowSetup {
  const DesktopWindowSetup();

  /// The primary screen's logical size.
  Future<Size> primaryScreenSize() async => (await screenRetriever.getPrimaryDisplay()).size;

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
/// title bar hidden (DesktopTitleBar replaces it), the minimum size for this
/// screen, that size as the opening size, 16:9 resizing, centred on the
/// primary screen, then shown, and then full screen on that screen. A failure
/// here is only logged, so a window problem can never stop the game from
/// opening (if full screen fails or the window never shows, the centred small
/// window stays).
Future<void> setUpDesktopWindow({DesktopWindowSetup window = const DesktopWindowSetup()}) async {
  try {
    // The window always opens on the primary screen. Flutter's own display
    // list can name a different monitor when there are two.
    final screen = await window.primaryScreenSize();
    final minimum = desktopMinimumWindow(screen);
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
    await window.setPosition(desktopOpeningPosition(screen, minimum));
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
