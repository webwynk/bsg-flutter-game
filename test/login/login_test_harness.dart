// Shared set-up for the login tests: real fonts and icons, the same theme the
// app runs with, a stand-in AuthProvider that never reaches a server, and a
// helper that decodes every picture on screen so a screenshot shows them.
import 'dart:async';
import 'dart:io';

// Reached through audioplayers, which the app depends on.
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
// Reached through supabase_flutter, which the app depends on; the tests only
// need its in-memory stand-in so the Supabase client can start.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:best_smart_game/providers/auth_provider.dart';
import 'package:best_smart_game/providers/game_provider.dart';
import 'package:best_smart_game/providers/history_provider.dart';
import 'package:best_smart_game/services/api_service.dart';
import 'package:best_smart_game/theme/app_colors.dart';

/// Starts the Supabase client against a throwaway address (the providers need
/// it to exist; nothing here talks to a real server) and silences audio,
/// because no plugin runs inside a test.
Future<void> setUpLoginTests() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  AudioplayersPlatformInterface.instance = _SilentAudio();
  GlobalAudioplayersPlatformInterface.instance = _SilentGlobalAudio();
  await Supabase.initialize(
    url: 'http://localhost:54321',
    // ignore: deprecated_member_use
    anonKey: 'test-key-not-real',
  );
  GoogleFonts.config.allowRuntimeFetching = false;
  await _loadFonts();
}

/// Accepts every audio call and does nothing.
class _SilentAudio implements AudioplayersPlatformInterface {
  @override
  Stream<AudioEvent> getEventStream(String playerId) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _SilentGlobalAudio implements GlobalAudioplayersPlatformInterface {
  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await loader.load();
  }

  await load('DMSans', [
    'DMSans-Regular.ttf',
    'DMSans-Medium.ttf',
    'DMSans-SemiBold.ttf',
    'DMSans-Bold.ttf',
    'DMSans-ExtraBold.ttf',
    'DMSans-Black.ttf',
  ]);
  await load('Oswald', ['Oswald-Regular.ttf', 'Oswald-Medium.ttf', 'Oswald-SemiBold.ttf', 'Oswald-Bold.ttf']);
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (root != null && icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

/// AuthProvider with a scripted server. Every other behaviour (error text,
/// clearError, setError) is the real provider's.
class FakeAuth extends AuthProvider {
  FakeAuth({this.name = 'player01'});

  final String name;
  Completer<LoginOutcome>? loginGate;
  LoginOutcome loginResult = const LoginOutcome(success: true);
  bool passwordResult = true;
  String? passwordError;
  bool loadingNow = false;
  final List<(String, String)> loginCalls = [];
  final List<(String, String)> passwordCalls = [];

  @override
  String get username => name;

  @override
  bool get isLoading => loadingNow;

  @override
  Future<LoginOutcome> login(String username, String password) async {
    loginCalls.add((username, password));
    clearError();
    loadingNow = true;
    notifyListeners();
    final outcome = loginGate == null ? loginResult : await loginGate!.future;
    loadingNow = false;
    if (!outcome.success && outcome.error != null) {
      setError(outcome.error!);
    } else {
      notifyListeners();
    }
    return outcome;
  }

  @override
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    passwordCalls.add((currentPassword, newPassword));
    clearError();
    if (!passwordResult && passwordError != null) setError(passwordError!);
    return passwordResult;
  }
}

/// The app's real theme and providers around [home].
Widget loginApp(FakeAuth auth, Widget home, {Map<String, WidgetBuilder>? routes}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.bgBase,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.goldBright,
            secondary: AppColors.casinoRed,
            surface: AppColors.bgSurface,
          ),
          fontFamily: 'DMSans',
        ),
        home: home,
        routes: routes ?? const {},
      ),
    );

/// Sets the test screen to [size] at one device pixel per dp.
void setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Decodes every picture currently in the tree, plus the lobby header (it is
/// a box decoration, not an Image widget), then rebuilds. Decoding does not
/// finish inside a widget test's frame clock, so it runs on the real one.
Future<void> decodeImages(WidgetTester tester) async {
  final images = find.byType(Image).evaluate().toList();
  await tester.runAsync(() async {
    for (final element in images) {
      await precacheImage((element.widget as Image).image, element);
    }
    await precacheImage(const AssetImage('assets/images/game_lobby_hader.webp'), images.first);
  });
  await tester.pump();
}
