import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'providers/auth_provider.dart';
import 'providers/game_provider.dart';
import 'providers/history_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/game_screen.dart';
import 'theme/app_colors.dart';
import 'utils/app_exit.dart';
import 'widgets/dialogs/action_dialog.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase official SDK (auto token refresh + native RPC + connection pooling)
  await Supabase.initialize(
    url: kSupabaseUrl,
    // ignore: deprecated_member_use
    anonKey: kSupabaseAnonKey,
  );

  // Start in portrait on app launch
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Full screen immersive
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Keep screen on
  await WakelockPlus.enable();

  runApp(const BsgApp());
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

/// Sends the player back to the login screen when the server ends their
/// session — either the account was blocked, or another device took it over
/// after this one stopped heartbeating.
///
/// F-4: without this the app logged the player out internally but left them on
/// a fully interactive game screen. Their bets simply stopped being accepted.
class _ForcedLogoutWatcher extends StatelessWidget {
  final Widget? child;
  const _ForcedLogoutWatcher({required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.forcedLogout) {
          final reason = auth.forcedLogoutReason;
          // Navigate after this frame — we are inside a build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final nav = _navigatorKey.currentState;
            if (nav == null) return;
            auth.clearForcedLogout();
            nav.pushNamedAndRemoveUntil('/login', (_) => false);
            if (reason != null) auth.setError(reason);
          });
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

/// Single-device session + "away too long" handling for backgrounding the
/// app. Two related jobs, one guard:
///
///  1. Free the single-device seat once the player has genuinely been away
///     for a while -- confirmed by grepping the whole codebase that, before
///     this existed, nothing anywhere watched for the app being backgrounded
///     at all, so closing the app (not tapping Logout) left the seat claimed
///     until the server's own 30s heartbeat-silence fallback kicked in.
///  2. If THIS device comes back after being away 20+ seconds, don't quietly
///     resume as if nothing happened -- resolve whatever bet was on the
///     board (submit it if the round's cutoff genuinely passed while frozen,
///     otherwise refund it exactly like a normal mid-round exit already
///     does), then tell the player plainly they were away and log them out.
///     Deliberately no silent "welcome back" path -- every return past the
///     threshold ends the same, honest way.
///
/// Debounced on `paused` (backgrounded) so a brief app-switch -- checking a
/// notification, answering a call -- does nothing at all. `detached`
/// (Android's stronger "the activity is being torn down" signal) releases
/// the seat immediately, no debounce, since there's no "waiting to see if
/// they come back" to do when the app is already being destroyed.
///
/// Honest about the limit: reliable on Android, best-effort on iOS, where a
/// hard swipe-to-kill gives apps no guaranteed chance to run any code at
/// all. The shortened server-side grace period (session_grace_sec 90->30)
/// is the safety net for whatever this can't catch.
class _AwaySessionGuard extends StatefulWidget {
  final Widget? child;
  const _AwaySessionGuard({required this.child});

  @override
  State<_AwaySessionGuard> createState() => _AwaySessionGuardState();
}

class _AwaySessionGuardState extends State<_AwaySessionGuard> with WidgetsBindingObserver {
  static const _awayThreshold = Duration(seconds: 20);

  Timer? _releaseTimer;
  bool _wasAwayPastThreshold = false;

  /// True from the moment the "You were away" popup is shown until its OK
  /// button is tapped. Bug fix: without this, backgrounding a second time
  /// (before ever answering the first popup) would start a whole new
  /// 20-second timer and, on returning, try to show a SECOND popup stacked
  /// on top of the first -- this flag makes the second background period a
  /// no-op instead, since there's already an unanswered popup waiting.
  bool _awayPopupShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _releaseTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return; // nothing to release or resolve

    switch (state) {
      case AppLifecycleState.paused:
        // Already showing the popup from a previous away period? Don't
        // start a whole new 20s cycle on top of an unanswered one -- there's
        // nothing new to detect until the player actually responds to what's
        // already on screen.
        if (_awayPopupShowing) return;
        _releaseTimer?.cancel();
        _releaseTimer = Timer(_awayThreshold, () => _markAwayAndRelease(auth));
        break;
      case AppLifecycleState.detached:
        _releaseTimer?.cancel();
        _markAwayAndRelease(auth);
        break;
      case AppLifecycleState.resumed:
        _releaseTimer?.cancel();
        if (_wasAwayPastThreshold) {
          _wasAwayPastThreshold = false;
          _resolveAwayReturn();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break; // transient (e.g. a system dialog) -- not a real background
    }
  }

  Future<void> _markAwayAndRelease(AuthProvider auth) async {
    _wasAwayPastThreshold = true;
    await auth.releaseSessionSlot();
  }

  /// Resolves the bet (if any), then shows the "away" popup. Resolution
  /// happens BEFORE the popup, not inside its OK button -- so the outcome is
  /// already settled by the time the player sees anything, no waiting on a
  /// network call after they tap OK.
  Future<void> _resolveAwayReturn() async {
    // Defensive: shouldn't be reachable given the paused-case guard above
    // (which stops a second timer from ever completing while this is true),
    // but checked here too so this function is safe to call from anywhere,
    // not just the one call site that currently exists.
    if (_awayPopupShowing) return;

    final auth = context.read<AuthProvider>();
    final game = context.read<GameProvider>();

    // If the round's cutoff genuinely passed while the timer was frozen in
    // the background, this submits the bet now -- the same trigger the
    // normal 5-second mark uses, not a separate path. abortSpin() below then
    // correctly sees a submitted bet and leaves it alone instead of wrongly
    // refunding one that should go through. If nothing was on the board
    // (e.g. the player was on the Lobby), both calls are harmless no-ops.
    game.catchUpMissedSubmissionIfNeeded();
    game.abortSpin(auth);

    isClosingApp.value = true;
    final navContext = _navigatorKey.currentContext;
    if (navContext == null) return;

    _awayPopupShowing = true;
    showActionDialog(
      navContext,
      icon: Icons.timer_off_rounded,
      title: 'YOU WERE AWAY',
      message: 'You were away for a while, so for your safety you have been logged out.',
      barrierDismissible: false,
      onPressed: () async {
        _awayPopupShowing = false;
        await auth.logout();
        isClosingApp.value = false;
        closeApp();
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}

class BsgApp extends StatelessWidget {
  const BsgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
      ],
      child: MaterialApp(
        title: 'Best Smart Game',
        debugShowCheckedModeBanner: false,
        // F-4 FIX: when the server ends a session, get the player off the game
        // screen. The heartbeat used to log them out internally and set an
        // error string that only the login screen renders, so a blocked or
        // displaced player kept tapping numbers on a session that no longer
        // existed, with a stale balance and no explanation.
        navigatorKey: _navigatorKey,
        builder: (context, child) => _AwaySessionGuard(
          child: _ForcedLogoutWatcher(child: child),
        ),
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.bgBase,
          colorScheme: ColorScheme.dark(
            primary: AppColors.goldBright,
            secondary: AppColors.casinoRed,
            surface: AppColors.bgSurface,
          ),
          fontFamily: 'DMSans',
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.bgPanel,
            elevation: 0,
          ),
        ),
        initialRoute: '/splash',
        routes: {
          '/splash':  (_) => const SplashScreen(),
          '/login':   (_) => const LoginScreen(),
          '/lobby':   (_) => const LobbyScreen(),
          '/game':    (_) => const GameScreen(),
        },
      ),
    );
  }
}
