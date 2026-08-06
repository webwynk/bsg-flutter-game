import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/auth_provider.dart';
import 'providers/game_provider.dart';
import 'providers/history_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/game_screen.dart';
import 'theme/app_colors.dart';

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

  // Clear personal game history on app startup (game close / restart)
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bsg_local_game_history');
  } catch (_) {}

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
        builder: (context, child) => _ForcedLogoutWatcher(child: child),
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
