import 'package:flutter/material.dart';
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
class DesktopTitleBar extends StatefulWidget {
  final DesktopWindowControls controls;

  const DesktopTitleBar({super.key, this.controls = const DesktopWindowControls()});

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> with WindowListener {
  /// Whether the window is in full screen, as this bar last set or read it.
  /// Tracked here because window_manager's enter/leave full-screen events do
  /// not fire for this window (checked in its 0.5.2 source).
  bool _fullScreen = false;

  /// Set when minimise took the window out of full screen, so that bringing
  /// it back returns to full screen. Cleared once used.
  bool _returnToFullScreen = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _readFullScreen();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _readFullScreen() async {
    final fullScreen = await widget.controls.isFullScreen();
    if (mounted) setState(() => _fullScreen = fullScreen);
  }

  /// Turns full screen on or off and shows the matching icon. Used by the
  /// maximise button and a double-click on the drag area.
  Future<void> _setFullScreen(bool fullScreen) async {
    await widget.controls.setFullScreen(fullScreen);
    if (mounted) setState(() => _fullScreen = fullScreen);
  }

  Future<void> _toggleFullScreen() async => _setFullScreen(!await widget.controls.isFullScreen());

  /// Minimises. window_manager refuses to minimise a full-screen window, so a
  /// full-screen window leaves full screen first and is marked to return to it.
  Future<void> _minimize() async {
    if (await widget.controls.isFullScreen()) {
      await _setFullScreen(false);
      _returnToFullScreen = true;
    }
    await widget.controls.minimize();
  }

  /// The window came back from being minimised: back to full screen if
  /// minimise took it out of full screen. A restore the bar did not cause
  /// (Win+D, a taskbar click) changes nothing.
  @override
  void onWindowRestore() {
    if (!_returnToFullScreen) return;
    _returnToFullScreen = false;
    _setFullScreen(true);
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
