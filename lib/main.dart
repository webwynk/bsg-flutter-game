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
import 'screens/profile_screen.dart';
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
          '/profile': (_) => const ProfileScreen(),
        },
      ),
    );
  }
}
