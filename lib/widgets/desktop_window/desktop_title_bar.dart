import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../utils/desktop_window.dart';

/// What the title bar's buttons do to the window. The default drives the real
/// window; tests pass their own.
class DesktopWindowControls {
  const DesktopWindowControls();

  Future<void> minimize() => windowManager.minimize();

  Future<bool> isMaximized() => windowManager.isMaximized();

  Future<void> toggleMaximize() async {
    if (await isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  Future<void> close() => windowManager.close();
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

/// The app's own title bar: the BSG icon and name, a drag area to move the
/// window (double-click maximises), and gold minimise, maximise and close
/// buttons. Close turns red under the mouse, as on any Windows app.
class DesktopTitleBar extends StatefulWidget {
  final DesktopWindowControls controls;

  const DesktopTitleBar({super.key, this.controls = const DesktopWindowControls()});

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _readMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _readMaximized() async {
    final maximized = await widget.controls.isMaximized();
    if (mounted) setState(() => _maximized = maximized);
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

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
            child: DragToMoveArea(
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
            onTap: widget.controls.minimize,
          ),
          _WindowButton(
            key: const ValueKey('window-maximize'),
            icon: _maximized ? Icons.filter_none : Icons.crop_square,
            iconSize: _maximized ? 13 : 15,
            onTap: () async {
              await widget.controls.toggleMaximize();
              await _readMaximized();
            },
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
