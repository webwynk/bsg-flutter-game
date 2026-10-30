// Proof that the phone is untouched by the tablet and desktop login work.
//
// The reference pictures in reference-design/login/before/ were taken from the
// code as it stood BEFORE that work began (Phase 0). They must never be
// regenerated: if one of these tests fails, the phone has changed.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:best_smart_game/screens/lobby_screen.dart';
import 'package:best_smart_game/screens/login_screen.dart';
import 'package:best_smart_game/screens/splash_screen.dart';
import 'package:best_smart_game/services/api_service.dart';

import 'login_test_harness.dart';

const _phones = [Size(390, 844), Size(360, 800)];

String _before(String name, Size size) =>
    '../../reference-design/login/before/${name}_${size.width.toInt()}x${size.height.toInt()}.png';

Future<void> _openLogin(WidgetTester tester, FakeAuth auth, Size size) async {
  setScreen(tester, size);
  await tester.pumpWidget(loginApp(auth, const LoginScreen()));
  await decodeImages(tester);
  await tester.pumpAndSettle();
}

Future<void> _openPopup(WidgetTester tester, FakeAuth auth, Size size) async {
  setScreen(tester, size);
  await tester.pumpWidget(loginApp(auth, const LobbyScreen()));
  await decodeImages(tester);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.lock));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(setUpLoginTests);

  for (final size in _phones) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('$label: login, untouched', (tester) async {
      await _openLogin(tester, FakeAuth(), size);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile(_before('phone_login', size)));
    });

    testWidgets('$label: login, with the error text', (tester) async {
      await _openLogin(tester, FakeAuth(), size);
      await tester.tap(find.text('LOGIN'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong username or password'), findsOneWidget);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile(_before('phone_login_error', size)));
    });

    testWidgets('$label: login, signing in', (tester) async {
      final auth = FakeAuth()..loginGate = Completer<LoginOutcome>();
      await _openLogin(tester, auth, size);
      await tester.enterText(find.byType(TextField).at(0), 'player01');
      await tester.enterText(find.byType(TextField).at(1), 'secret1');
      await tester.tap(find.text('LOGIN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile(_before('phone_login_loading', size)));
      auth.loginGate!.complete(const LoginOutcome(success: false, error: 'stop'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('$label: splash', (tester) async {
      setScreen(tester, size);
      await tester.pumpWidget(loginApp(
        FakeAuth(),
        const SplashScreen(),
        routes: {'/login': (_) => const SizedBox.shrink()},
      ));
      await decodeImages(tester);
      await tester.pump(const Duration(milliseconds: 1000));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile(_before('phone_splash', size)));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('$label: change-password popup', (tester) async {
      await _openPopup(tester, FakeAuth(), size);
      expect(find.text('SECURITY & ACCOUNT'), findsOneWidget);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile(_before('phone_password_popup', size)));
    });

    testWidgets('$label: change-password popup, with an error', (tester) async {
      await _openPopup(tester, FakeAuth(), size);
      await tester.tap(find.text('UPDATE PASSWORD'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your current password.'), findsOneWidget);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile(_before('phone_password_popup_error', size)));
    });
  }
}
