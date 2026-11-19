import 'dart:async';

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import '../../utils/desktop_window.dart';

/// What the title bar does to the window. Each method passes straight to the
/// real window (window_manager); tests pass their own. The decisions (when to
/// leave or return to full screen) live in the title bar, not here.
class DesktopWindowControls {
  const DesktopWindowControls();

  /// Minimises the window. window_manager ignores this while in full screen,
  /// so the title bar leaves full screen first.
  Future<void> minimize() => windowManager.minimize();

  /// Asks the window to close. DesktopCloseGuard decides what happens.
  Future<void> close() => windowManager.close();

  /// Whether window_manager has the window in full screen (its own flag; it
  /// stays true if Windows minimises a full-screen window by itself).
  Future<bool> isFullScreen() => windowManager.isFullScreen();

  /// Turns window_manager's full screen on (covers the whole monitor,
  /// taskbar included) or off (back to the window it had before).
  Future<void> setFullScreen(bool fullScreen) => windowManager.setFullScreen(fullScreen);

  /// Starts moving the window with the mouse, as when dragging a native title
  /// bar.
  Future<void> startDragging() => windowManager.startDragging();

  /// Sets the smallest size the window can be dragged to; Size.zero means none.
  Future<void> setMinimumSize(Size size) => windowManager.setMinimumSize(size);

  /// The window's position and size, logical (physical / devicePixelRatio).
  Future<Rect> getBounds() => windowManager.getBounds();

  /// The window's current device pixel ratio (its screen's scale).
  double devicePixelRatio() => WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

  /// Every screen, with its work area and scale.
  Future<List<DesktopScreen>> screens() async =>
      (await screenRetriever.getAllDisplays()).map(DesktopScreen.fromDisplay).toList();

  /// Resizes the window (never used while in full screen).
  Future<void> setSize(Size size) => windowManager.setSize(size);

  /// Moves the window (never used while in full screen).
  Future<void> setPosition(Offset position) => windowManager.setPosition(position);

  /// A normal Windows maximised window: the last-resort fallback when full
  /// screen cannot fit the screen.
  Future<void> maximize() => windowManager.maximize();
}

/// Puts the gold title bar above the app in the Windows app and gives the app
/// the space under it, reporting that smaller size as its screen size. It sits
/// above every screen and popup, so the window can always be moved or closed.
/// Anywhere else it returns [child] as it is.
class DesktopWindowFrame extends StatelessWidget {
  final Widget child;
  final DesktopWindowControls controls;

  const DesktopWindowFrame({super.key, required this.child, this.controls = const DesktopWindowControls()});

  @override
  Widget build(BuildContext context) {
    if (!isWindowsApp) return child;
    final media = MediaQuery.of(context);
    final height = (media.size.height - kDesktopTitleBarHeight).clamp(0.0, double.infinity);
    return Column(
      children: [
        DesktopTitleBar(controls: controls),
        Expanded(
          child: MediaQuery(
            data: media.copyWith(size: Size(media.size.width, height)),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// The app's own title bar: the BSG icon and name, a drag area, and gold
/// minimise, maximise and close buttons. Close turns red under the mouse, as on
/// any Windows app. Every window action goes through [controls].
///
/// Full screen (the app opens in it): the maximise button and a double-click
/// on the bar switch between full screen and the small window; the icon shows
/// which. Minimise leaves full screen first and the window returns to full
/// screen when brought back. Dragging moves only the small window.
///
/// Any screen size and scaling: full screen never has a minimum size, and the
/// small window's minimum is the one that fits the screen it is on. After
/// every full-screen entry, at start-up, and when Windows reports a change
/// (scaling or size change, window dragged, window focused), the bar checks
/// the window still fits its screen and fixes it if not.
class DesktopTitleBar extends StatefulWidget {
  final DesktopWindowControls controls;

  const DesktopTitleBar({super.key, this.controls = const DesktopWindowControls()});

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> with WindowListener, WidgetsBindingObserver {
  /// Whether the window is in full screen, as this bar last set or read it.
  /// Tracked here because window_manager's enter/leave full-screen events do
  /// not fire for this window (checked in its 0.5.2 source).
  bool _fullScreen = false;

  /// Set when minimise took the window out of full screen, so that bringing
  /// it back returns to full screen. Cleared once used.
  bool _returnToFullScreen = false;

  /// True while the bar is changing or checking the window. Checks asked for
  /// meanwhile (for example by the events its own changes cause) are skipped,
  /// so they cannot loop.
  bool _busy = false;

  /// The bar's window changes run one after another in this chain, so a
  /// button press or a restore asked for while another change runs is done
  /// next, never at the same time and never dropped.
  Future<void> _queue = Future<void>.value();

  /// Waits for a burst of size/scaling changes to end before checking once.
  Timer? _metricsCheck;

  DesktopWindowControls get _controls => widget.controls;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    _startUp();
  }

  @override
  void dispose() {
    _metricsCheck?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  /// Reads whether the app opened in full screen, then checks the window fits
  /// its screen (it may not, for example on a screen whose minimum was wrong).
  Future<void> _startUp() async {
    await _readFullScreen();
    await _checkScreen();
  }

  Future<void> _readFullScreen() async {
    final fullScreen = await _controls.isFullScreen();
    if (mounted) setState(() => _fullScreen = fullScreen);
  }

  /// Turns full screen on or off and shows the matching icon.
  Future<void> _setFullScreen(bool fullScreen) async {
    await _controls.setFullScreen(fullScreen);
    if (mounted) setState(() => _fullScreen = fullScreen);
  }

  /// Runs [action] after any change already running or waiting. A failure is
  /// only logged, so a window problem never breaks the bar.
  Future<void> _exclusive(Future<void> Function() action) {
    final next = _queue.then((_) async {
      _busy = true;
      try {
        await action();
      } catch (e) {
        debugPrint('Desktop window change failed: $e');
      } finally {
        _busy = false;
      }
    });
    _queue = next;
    return next;
  }

  /// The maximise button and a double-click on the drag area.
  Future<void> _toggleFullScreen() => _exclusive(() async {
        if (await _controls.isFullScreen()) {
          await _leaveFullScreen();
        } else {
          await _enterFullScreen();
        }
      });

  /// Full screen with no minimum size (Windows would otherwise keep the window
  /// at least the minimum x the screen's scale, bigger than a small or scaled
  /// screen), then the safety net.
  Future<void> _enterFullScreen() async {
    await _controls.setMinimumSize(Size.zero);
    await _setFullScreen(true);
    await _makeFullScreenFit();
  }

  /// Back to the small window, then its minimum and place fitted to the
  /// screen it is on.
  Future<void> _leaveFullScreen() async {
    await _setFullScreen(false);
    await _fitSmallWindow();
  }

  /// Safety net: if the full-screen window is bigger than its screen, redo
  /// full screen once with no minimum. window_manager's "leave" goes back to
  /// where full screen started, so a window moved to another screen comes
  /// back to its first screen (Hasan's choice D1-b). If it still does not fit,
  /// the last resort is a normal maximised window, which Windows always fits
  /// to the screen (choice Q2).
  Future<void> _makeFullScreenFit() async {
    if (await _fullScreenFits()) return;
    await _controls.setFullScreen(false);
    await _controls.setMinimumSize(Size.zero);
    await _controls.setFullScreen(true);
    if (await _fullScreenFits()) return;
    debugPrint('Full screen does not fit this screen; using a maximised window instead.');
    await _setFullScreen(false);
    await _fitSmallWindow();
    await _controls.maximize();
  }

  /// Whether the full-screen window fits the screen it is on. An unknown
  /// screen (no match, for example while minimised) counts as fitting, so the
  /// bar never acts on numbers it cannot place.
  Future<bool> _fullScreenFits() async {
    final bounds = await _controls.getBounds();
    final screen = desktopScreenOfWindow(bounds, _controls.devicePixelRatio(), await _controls.screens());
    return screen == null || desktopFullScreenFits(bounds, screen);
  }

  /// How much (logical pixels) bigger than the work area the small window may
  /// be and still count as fitting: Windows' invisible 8-pixel resize borders
  /// on each side (and a maximised window's) must not trigger a resize.
  static const double _kBorderSlack = 16;

  /// Sets the small window's minimum to the one that fits the screen it is
  /// on. If the window is bigger than that screen's work area (for example it
  /// came back too big from another screen: measured 2004 wide on a 1920
  /// screen) or smaller than that minimum (Windows' own scaling resize can
  /// shrink it when it crosses screens with different scaling: measured
  /// 594 x 334, which is 1336 x 752 x (96/144) twice), it is resized to that
  /// minimum and centred. Windows does not grow a window to a new minimum by
  /// itself, and the player cannot drag it below the minimum, so a too-small
  /// window only comes from such a resize. A window that is only partly off
  /// the screen because the player dragged it there is left where it is.
  /// Never called in full screen.
  Future<void> _fitSmallWindow() async {
    final bounds = await _controls.getBounds();
    final screen = desktopScreenOfWindow(bounds, _controls.devicePixelRatio(), await _controls.screens());
    if (screen == null) return;
    final minimum = desktopMinimumForWorkArea(screen.workSize);
    await _controls.setMinimumSize(minimum);
    final tooBig = bounds.width > screen.workSize.width + _kBorderSlack ||
        bounds.height > screen.workSize.height + _kBorderSlack;
    final tooSmall = bounds.width < minimum.width - _kBorderSlack || bounds.height < minimum.height - _kBorderSlack;
    if (!tooBig && !tooSmall) return;
    await _controls.setSize(minimum);
    await _controls.setPosition(desktopCentredInWorkArea(screen, minimum));
  }

  /// Checks the window still fits its screen: in full screen the safety net,
  /// otherwise the small window's minimum and place. Skipped while another
  /// change runs (that change ends with its own fit).
  Future<void> _checkScreen() {
    if (_busy) return Future<void>.value();
    return _exclusive(() async {
      if (await _controls.isFullScreen()) {
        await _makeFullScreenFit();
      } else {
        await _fitSmallWindow();
      }
    });
  }

  /// Minimises. window_manager refuses to minimise a full-screen window, so a
  /// full-screen window leaves full screen first and is marked to return to it.
  Future<void> _minimize() => _exclusive(() async {
        if (await _controls.isFullScreen()) {
          await _leaveFullScreen();
          _returnToFullScreen = true;
        }
        await _controls.minimize();
      });

  /// The window came back from being minimised: back to full screen if
  /// minimise took it out of full screen. A restore the bar did not cause
  /// (Win+D, a taskbar click) changes nothing.
  @override
  void onWindowRestore() {
    if (!_returnToFullScreen) return;
    _returnToFullScreen = false;
    _exclusive(_enterFullScreen);
  }

  /// The small window was dragged (window_manager reports only mouse drags).
  @override
  void onWindowMoved() => _checkScreen();

  /// The window was activated; a cheap moment to make sure it still fits.
  @override
  void onWindowFocus() => _checkScreen();

  /// The window's size or scaling changed (for example the scaling setting,
  /// or a move to a screen with other scaling). Checked once the changes
  /// settle.
  @override
  void didChangeMetrics() {
    _metricsCheck?.cancel();
    _metricsCheck = Timer(const Duration(milliseconds: 300), _checkScreen);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kDesktopTitleBarHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A0A02), Color(0xFF1E0400)],
        ),
        border: Border(bottom: BorderSide(color: Color(0xFFD4AF37))),
      ),
      child: Row(
        children: [
          Expanded(
            // Our own drag area (not window_manager's DragToMoveArea, which
            // called the real window directly), so it goes through controls.
            // A full-screen window must not be dragged: it would move off the
            // monitor while window_manager still counts it as full screen.
            child: GestureDetector(
              key: const ValueKey('window-drag-area'),
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) {
                if (!_fullScreen) widget.controls.startDragging();
              },
              onDoubleTap: _toggleFullScreen,
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Image.asset('assets/images/bsg-app-icon.webp', width: 20, height: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'BSG',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.5,
                      color: Color(0xFFFFD700),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _WindowButton(
            key: const ValueKey('window-minimize'),
            icon: Icons.remove,
            onTap: _minimize,
          ),
          _WindowButton(
            key: const ValueKey('window-maximize'),
            icon: _fullScreen ? Icons.filter_none : Icons.crop_square,
            iconSize: _fullScreen ? 13 : 15,
            onTap: _toggleFullScreen,
          ),
          _WindowButton(
            key: const ValueKey('window-close'),
            icon: Icons.close,
            hoverColor: const Color(0xFFC42B1C),
            onTap: widget.controls.close,
          ),
        ],
      ),
    );
  }
}

/// One title bar button, 46 wide as on standard Windows windows.
class _WindowButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final Color hoverColor;
  final VoidCallback onTap;

  const _WindowButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconSize = 16,
    this.hoverColor = const Color(0x33FFD700),
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: kDesktopTitleBarHeight,
          color: _hovered ? widget.hoverColor : Colors.transparent,
          child: Icon(widget.icon, size: widget.iconSize, color: const Color(0xFFFFD700)),
        ),
      ),
    );
  }
}
