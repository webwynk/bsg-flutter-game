import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../../utils/desktop_window.dart';

/// What happens when the Windows window is asked to close, by the gold X,
/// Alt+F4 or the taskbar. It sends the same back signal as a phone's back
/// button, so nothing about a game's own exit rules changes:
///
///  * Login or lobby, nothing on top: the session ends and the app closes.
///  * In a game: the game's own Exit popup shows. NO keeps playing. YES lets
///    the game leave as usual, then the session ends and the app closes.
///  * Another popup on top that can be closed: only that popup closes.
///  * A popup that must be answered: nothing happens.
///  * The NO INTERNET popup, which nobody can answer: the app closes.
///
/// A game's own EXIT button is not affected: this only acts while a close was
/// asked for. As a NavigatorObserver it sees the Exit popup and the game close.
class DesktopCloseController extends NavigatorObserver {
  final NavigatorState? Function() findNavigator;

  /// Ends the session; may do nothing when nobody is logged in.
  final Future<void> Function() endSession;

  /// True while a popup that cannot be answered is up, like NO INTERNET.
  /// Closing does not wait for it. Only that popup, so a game's popups keep
  /// their rules.
  final bool Function() closeOverPopup;

  /// Hides the window, so closing feels instant while the session ends.
  final Future<void> Function() hideWindow;

  /// Ends the app for good.
  final Future<void> Function() destroyWindow;

  DesktopCloseController({
    required this.findNavigator,
    required this.endSession,
    required this.closeOverPopup,
    required this.hideWindow,
    required this.destroyWindow,
  });

  /// The longest the app waits for the server when ending the session.
  static const sessionTimeout = Duration(seconds: 5);

  /// How long after a popup closes the game may still leave. The games leave
  /// straight after their popup answers YES, so past this the answer was NO.
  static const _answerWindow = Duration(milliseconds: 300);

  /// Lets a game's own clean-up run before the window goes.
  static const _settleAfterGame = Duration(milliseconds: 300);

  bool _closeAsked = false;
  bool _closing = false;
  Timer? _answerTimer;

  /// Handles one request to close the window.
  Future<void> requestClose() async {
    if (_closing || _closeAsked) return;
    final navigator = findNavigator();
    if (navigator == null || !navigator.canPop() || closeOverPopup()) {
      await _finish();
      return;
    }
    _closeAsked = true;
    await navigator.maybePop();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_closeAsked) return;
    if (route is PopupRoute) {
      _answerTimer?.cancel();
      _answerTimer = Timer(_answerWindow, () => _closeAsked = false);
      return;
    }
    if (previousRoute?.isFirst ?? false) {
      _answerTimer?.cancel();
      _closeAsked = false;
      _closing = true;
      final left = route is TransitionRoute ? route.completed : Future<void>.value();
      left.then((_) async {
        await Future<void>.delayed(_settleAfterGame);
        await _finish();
      });
    }
  }

  /// A forced logout clears every screen and popup at once, so no answer to a
  /// pending close will ever come.
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _answerTimer?.cancel();
    _closeAsked = false;
  }

  /// Ends the session and closes. A slow or failed logout still closes: the
  /// server frees the seat itself once the heartbeat stops.
  Future<void> _finish() async {
    _closing = true;
    try {
      await hideWindow();
      await endSession().timeout(sessionTimeout);
    } catch (e) {
      debugPrint('Ending the session on close failed: $e');
    }
    await destroyWindow();
  }
}

/// Passes every request to close to [controller]: the window's own close
/// signal, which the gold X and the taskbar send, and the Alt+F4 keys.
/// Only in the Windows app; anywhere else it returns [child] as it is.
class DesktopCloseGuard extends StatefulWidget {
  final DesktopCloseController controller;
  final Widget child;

  const DesktopCloseGuard({super.key, required this.controller, required this.child});

  @override
  State<DesktopCloseGuard> createState() => _DesktopCloseGuardState();
}

class _DesktopCloseGuardState extends State<DesktopCloseGuard> with WindowListener {
  bool _altF4Held = false;

  @override
  void initState() {
    super.initState();
    if (isWindowsApp) {
      windowManager.addListener(this);
      HardwareKeyboard.instance.addHandler(_onKey);
    }
  }

  @override
  void dispose() {
    if (isWindowsApp) {
      windowManager.removeListener(this);
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
    super.dispose();
  }

  @override
  void onWindowClose() => widget.controller.requestClose();

  /// Takes Alt+F4 before Windows sees it, because left to Windows it closed the
  /// app without the game's Exit popup. Holding the keys counts as one press.
  bool _onKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.f4) return false;
    if (event is KeyDownEvent && HardwareKeyboard.instance.isAltPressed) {
      _altF4Held = true;
      widget.controller.requestClose();
      return true;
    }
    final wasHeld = _altF4Held;
    if (event is KeyUpEvent) _altF4Held = false;
    return wasHeld;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
