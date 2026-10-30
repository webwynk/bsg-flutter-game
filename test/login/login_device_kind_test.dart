// The phone / tablet / desktop check behind the login screens, and the screen
// direction each kind gets. A phone must always get portrait, as it always has.
import 'package:best_smart_game/screens/login_screen.dart';
import 'package:best_smart_game/screens/splash_screen.dart';
import 'package:best_smart_game/utils/device_type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'login_test_harness.dart';

const _portrait = [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];
const _landscape = [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];
const _portraitNames = ['DeviceOrientation.portraitUp', 'DeviceOrientation.portraitDown'];
const _landscapeNames = ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'];

LoginDeviceKind _kind(TargetPlatform platform, Size size, {bool web = false}) =>
    classifyLoginDevice(isWeb: web, platform: platform, logicalSize: size);

void main() {
  setUpAll(setUpLoginTests);

  group('which kind of device', () {
    test('Android and iOS under 600 are phones, in either direction', () {
      for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
        for (final s in const [Size(390, 844), Size(844, 390), Size(360, 800), Size(932, 430), Size(599, 1000)]) {
          expect(_kind(p, s), LoginDeviceKind.phone, reason: '$p $s');
        }
      }
    });

    test('Android and iOS at 600 and over are tablets, in either direction', () {
      for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
        for (final s in const [Size(600, 960), Size(960, 600), Size(1024, 768), Size(820, 1180), Size(1366, 1024)]) {
          expect(_kind(p, s), LoginDeviceKind.tablet, reason: '$p $s');
        }
      }
    });

    test('Windows, macOS and Linux are desktop at any window size', () {
      for (final p in [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux]) {
        for (final s in const [Size(500, 400), Size(1280, 720), Size(2560, 1440), Size.zero]) {
          expect(_kind(p, s), LoginDeviceKind.desktop, reason: '$p $s');
        }
      }
    });

    test('web goes by size only, whatever system the browser runs on', () {
      expect(_kind(TargetPlatform.windows, const Size(1920, 1080), web: true), LoginDeviceKind.tablet);
      expect(_kind(TargetPlatform.windows, const Size(500, 800), web: true), LoginDeviceKind.phone);
      expect(_kind(TargetPlatform.android, const Size(390, 844), web: true), LoginDeviceKind.phone);
    });

    test('a size not known yet counts as a phone on Android and iOS', () {
      expect(_kind(TargetPlatform.android, Size.zero), LoginDeviceKind.phone);
      expect(_kind(TargetPlatform.iOS, Size.zero), LoginDeviceKind.phone);
    });

    testWidgets('it reads the real screen, allowing for pixel density', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      expect(loginDeviceKind(), LoginDeviceKind.phone);
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      expect(loginDeviceKind(), LoginDeviceKind.tablet);
    });
  });

  test('a phone gets portrait, a tablet and a desktop get landscape', () {
    expect(loginOrientations(LoginDeviceKind.phone), _portrait);
    expect(loginOrientations(LoginDeviceKind.tablet), _landscape);
    expect(loginOrientations(LoginDeviceKind.desktop), _landscape);
  });

  group('what the screens ask the system for', () {
    late List<MethodCall> log;

    setUp(() {
      log = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        log.add(call);
        return null;
      });
    });

    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    List<String> lastSent() => (log
            .lastWhere((c) => c.method == 'SystemChrome.setPreferredOrientations')
            .arguments as List)
        .cast<String>();

    Future<void> open(WidgetTester tester, Size size, Widget screen) async {
      setScreen(tester, size);
      await tester.pumpWidget(loginApp(FakeAuth(), screen, routes: {'/login': (_) => const SizedBox.shrink()}));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }

    testWidgets('login: phone portrait', (tester) async {
      await open(tester, const Size(390, 844), const LoginScreen());
      expect(lastSent(), _portraitNames);
    });

    testWidgets('login: tablet landscape', (tester) async {
      await open(tester, const Size(1180, 820), const LoginScreen());
      expect(lastSent(), _landscapeNames);
    });

    testWidgets('splash: phone portrait', (tester) async {
      await open(tester, const Size(390, 844), const SplashScreen());
      expect(lastSent(), _portraitNames);
    });

    testWidgets('splash: tablet landscape', (tester) async {
      await open(tester, const Size(1180, 820), const SplashScreen());
      expect(lastSent(), _landscapeNames);
    });

    testWidgets('login: desktop landscape', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await open(tester, const Size(1280, 720), const LoginScreen());
      final sent = lastSent();
      debugDefaultTargetPlatformOverride = null;
      expect(sent, _landscapeNames);
    });
  });
}
