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

/// Sets up the Windows app's window before the first frame: the title BSG, the
/// native title bar hidden (DesktopTitleBar replaces it), the minimum size for
/// this screen, that size as the opening size, centred, and 16:9 resizing. A
/// failure here is only logged, so a window problem can never stop the game
/// from opening.
Future<void> setUpDesktopWindow() async {
  try {
    // The window always opens on the primary screen. Flutter's own display
    // list can name a different monitor when there are two.
    final screen = (await screenRetriever.getPrimaryDisplay()).size;
    final minimum = desktopMinimumWindow(screen);
    await windowManager.ensureInitialized();
    await windowManager.setTitle('BSG');
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
    // DesktopCloseGuard decides what happens when the window is asked to close.
    await windowManager.setPreventClose(true);
    await windowManager.setSize(minimum);
    await windowManager.setMinimumSize(minimum);
    await windowManager.setAspectRatio(16 / 9);
    // Not windowManager.center(): that follows the mouse, and on two screens
    // with different scaling it left the window across both.
    await windowManager.setPosition(desktopOpeningPosition(screen, minimum));
  } catch (e) {
    debugPrint('Desktop window setup failed: $e');
  }
}
