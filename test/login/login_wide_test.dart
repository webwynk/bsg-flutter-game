// The horizontal login for tablets and desktops: the Indian clock, the layout
// at every size, the keyboard, and proof that the same login logic runs as on
// the phone. Pictures are saved to reference-design/login/after/.
import 'dart:async';

import 'package:best_smart_game/screens/login_screen.dart';
import 'package:best_smart_game/services/api_service.dart';
import 'package:best_smart_game/widgets/login/login_form_card.dart';
import 'package:best_smart_game/widgets/login/login_ist_clock.dart';
import 'package:best_smart_game/widgets/login/login_wide_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'login_test_harness.dart';

const _tablets = [Size(1024, 768), Size(1180, 820), Size(1366, 1024)];
const _desktops = [Size(1280, 720), Size(1920, 1080), Size(2560, 1440)];

const _plaque = ValueKey('login-clock-plaque');

/// Opens the login at [size].
Future<void> _open(WidgetTester tester, Size size, FakeAuth auth) async {
  setScreen(tester, size);
  await tester.pumpWidget(loginApp(auth, const LoginScreen(), routes: {
    '/lobby': (_) => const Scaffold(body: Text('LOBBY')),
  }));
  await decodeImages(tester);
  await tester.pumpAndSettle();
}

/// Tries the login with the given text in the two fields.
Future<void> _login(WidgetTester tester, String user, String pass) async {
  await tester.enterText(find.byType(TextField).at(0), user);
  await tester.enterText(find.byType(TextField).at(1), pass);
  await tester.tap(find.text('LOGIN'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(setUpLoginTests);

  group('the clock always shows India time', () {
    test('a fixed UTC moment reads as IST, not device time', () {
      // 02:13:45 UTC on Friday 30 October 2026 is 07:43:45 in India.
      final t = IstClockText.of(DateTime.utc(2026, 10, 30, 2, 13, 45));
      expect('${t.hours}:${t.minutes}:${t.seconds} ${t.amPm}', '07:43:45 AM');
      expect(t.date, 'Friday, 30 October 2026');
    });

    test('the same instant given in another zone reads the same', () {
      final utc = DateTime.utc(2026, 10, 30, 2, 13, 45);
      expect(IstClockText.of(utc.toLocal()).minutes, IstClockText.of(utc).minutes);
      expect(IstClockText.of(utc.toLocal()).hours, IstClockText.of(utc).hours);
    });

    test('the half hour carries over into the next day and month', () {
      final t = IstClockText.of(DateTime.utc(2026, 10, 31, 18, 45, 0));
      expect('${t.hours}:${t.minutes} ${t.amPm}', '12:15 AM');
      expect(t.date, 'Sunday, 1 November 2026');
    });

    test('midnight and noon read 12, never 00', () {
      expect(IstClockText.of(DateTime.utc(2026, 1, 1, 18, 30)).hours, '12');
      expect(IstClockText.of(DateTime.utc(2026, 1, 1, 18, 30)).amPm, 'AM');
      expect(IstClockText.of(DateTime.utc(2026, 1, 1, 6, 30)).hours, '12');
      expect(IstClockText.of(DateTime.utc(2026, 1, 1, 6, 30)).amPm, 'PM');
    });

    test('one in the afternoon reads 01 PM', () {
      final t = IstClockText.of(DateTime.utc(2026, 1, 1, 7, 30));
      expect('${t.hours} ${t.amPm}', '01 PM');
    });

    testWidgets('the numbers move on, and the timer stops with the screen', (tester) async {
      var now = DateTime.utc(2026, 10, 30, 2, 13, 45);
      setScreen(tester, const Size(1180, 820));
      await tester.pumpWidget(MaterialApp(home: LoginIstClock(clock: () => now)));
      expect(find.text('45'), findsNWidgets(2));
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('46'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
      // A timer left running would fail this test as it ends.
    });
  });

  group('layout', () {
    test('the design scales with the screen; a 1920 x 1080 desktop is about 1.3 times', () {
      expect(LoginWideLayout.scaleFor(const Size(1180, 820)), 1.0);
      expect(LoginWideLayout.scaleFor(const Size(1920, 1080)), closeTo(1.317, 0.001));
    });

    for (final (sizes, desktop) in [(_tablets, false), (_desktops, true)]) {
      for (final size in sizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()}';
        testWidgets('$label: everything fits, left and right of the middle', (tester) async {
          if (desktop) debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          await _open(tester, size, FakeAuth());
          expect(tester.takeException(), isNull);
          final scale = LoginWideLayout.scaleFor(size);
          final plaque = tester.getRect(find.byKey(_plaque));
          final card = tester.getRect(find.byType(LoginFormCard));
          final divider = tester.getRect(find.byKey(const ValueKey('login-divider')));
          expect(divider.center.dx, closeTo(size.width / 2, 1));
          expect(plaque.right, lessThan(divider.left));
          expect(plaque.left, greaterThan(0));
          expect(plaque.center.dy, closeTo(size.height / 2, 1));
          expect(card.left, greaterThan(divider.right));
          expect(card.right, lessThan(size.width));
          expect(card.width, closeTo(380 * scale, 0.5));
          final banner = tester.getRect(find.byWidgetPredicate(
              (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.contains('warning_18')));
          expect(banner.width, closeTo(340 * scale, 0.5));
          expect(banner.top - card.bottom, closeTo(26 * scale, 1));
          expect(banner.bottom, lessThan(size.height));
          debugDefaultTargetPlatformOverride = null;
        });
      }
    }
  });

  group('on-screen keyboard on a tablet', () {
    testWidgets('the card moves above the keyboard; the design does not shrink', (tester) async {
      await _open(tester, const Size(1180, 820), FakeAuth());
      final plaqueBefore = tester.getRect(find.byKey(_plaque));
      await tester.tap(find.byType(TextField).at(1));
      tester.view.viewInsets = const FakeViewPadding(bottom: 360);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(_plaque)), plaqueBefore);
      const keyboardTop = 820 - 360;
      expect(tester.getRect(find.text('LOGIN')).bottom, lessThanOrEqualTo(keyboardTop));
      expect(tester.getRect(find.byType(TextField).at(1)).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(find.byType(TextField).at(1)).bottom, lessThanOrEqualTo(keyboardTop));
    });

    testWidgets('Enter on the password field still logs in', (tester) async {
      final auth = FakeAuth();
      await _open(tester, const Size(1180, 820), auth);
      await tester.enterText(find.byType(TextField).at(0), 'player01');
      await tester.enterText(find.byType(TextField).at(1), 'secret1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(auth.loginCalls, [('player01', 'secret1')]);
      expect(find.text('LOBBY'), findsOneWidget);
    });
  });

  group('same login behaviour as the phone', () {
    const size = Size(1180, 820);

    testWidgets('empty fields never reach the server', (tester) async {
      final auth = FakeAuth();
      await _open(tester, size, auth);
      await tester.tap(find.text('LOGIN'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Wrong username or password'), findsOneWidget);
      expect(auth.loginCalls, isEmpty);
    });

    testWidgets('spaces are trimmed and a good login opens the lobby', (tester) async {
      final auth = FakeAuth();
      await _open(tester, size, auth);
      await _login(tester, '  player01 ', ' secret1 ');
      expect(auth.loginCalls, [('player01', 'secret1')]);
      expect(find.text('LOBBY'), findsOneWidget);
    });

    testWidgets('a wrong password shows the server text', (tester) async {
      final auth = FakeAuth()
        ..loginResult = const LoginOutcome(success: false, error: 'Wrong password. 3 attempts left.');
      await _open(tester, size, auth);
      await _login(tester, 'player01', 'nope');
      expect(find.text('Wrong password. 3 attempts left.'), findsOneWidget);
    });

    testWidgets('a blocked account gets the blocked popup', (tester) async {
      final auth = FakeAuth()
        ..loginResult = const LoginOutcome(success: false, accountBlocked: true, error: 'You are blocked.');
      await _open(tester, size, auth);
      await _login(tester, 'player01', 'nope');
      expect(find.text('ACCOUNT BLOCKED'), findsOneWidget);
      expect(find.text('You are blocked.'), findsWidgets);
    });

    testWidgets('another device, with a wait', (tester) async {
      final auth = FakeAuth()
        ..loginResult = const LoginOutcome(success: false, sessionHeldElsewhere: true, secondsUntilFree: 25);
      await _open(tester, size, auth);
      await _login(tester, 'player01', 'secret1');
      expect(find.text('Already playing on another device. Try again in 25s.'), findsOneWidget);
    });

    testWidgets('another device, no wait', (tester) async {
      final auth = FakeAuth()..loginResult = const LoginOutcome(success: false, sessionHeldElsewhere: true);
      await _open(tester, size, auth);
      await _login(tester, 'player01', 'secret1');
      expect(find.text('This account is already playing on another device.'), findsOneWidget);
    });

    testWidgets('the bar shows while signing in and the button comes back', (tester) async {
      final auth = FakeAuth()..loginGate = Completer<LoginOutcome>();
      await _open(tester, size, auth);
      await tester.enterText(find.byType(TextField).at(0), 'player01');
      await tester.enterText(find.byType(TextField).at(1), 'secret1');
      await tester.tap(find.text('LOGIN'));
      await tester.pump();
      expect(find.text('SIGNING IN...'), findsOneWidget);
      expect(find.text('LOGIN'), findsNothing);
      auth.loginGate!.complete(const LoginOutcome(success: false, error: 'Nope'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);
    });

    testWidgets('the eye shows and hides the password', (tester) async {
      await _open(tester, size, FakeAuth());
      bool obscured() => tester.widget<TextField>(find.byType(TextField).at(1)).obscureText;
      expect(obscured(), isTrue);
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();
      expect(obscured(), isFalse);
    });
  });

  group('pictures', () {
    Future<void> shoot(WidgetTester tester, Size size, bool desktop) async {
      if (desktop) debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      setScreen(tester, size);
      await tester.pumpWidget(loginApp(FakeAuth(), const _FixedLogin()));
      await decodeImages(tester);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
            '../../reference-design/login/after/${desktop ? 'desktop' : 'tablet'}_login_${size.width.toInt()}x${size.height.toInt()}.png'),
      );
      debugDefaultTargetPlatformOverride = null;
    }

    for (final size in _tablets) {
      testWidgets('tablet $size', (tester) => shoot(tester, size, false));
    }
    for (final size in _desktops) {
      testWidgets('desktop $size', (tester) => shoot(tester, size, true));
    }
  });
}

/// The login background and wide layout with the clock held at the approved
/// design's moment, so a picture never changes from run to run.
class _FixedLogin extends StatefulWidget {
  const _FixedLogin();
  @override
  State<_FixedLogin> createState() => _FixedLoginState();
}

class _FixedLoginState extends State<_FixedLogin> {
  final _user = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/bg_lobby.webp', fit: BoxFit.cover),
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(colors: [Colors.transparent, Color(0x88000000)]),
            ),
          ),
          LoginWideLayout(
            clock: () => DateTime.utc(2026, 10, 30, 2, 13, 45),
            form: LoginFormCard(usernameController: _user, passwordController: _pass, onLogin: () {}),
          ),
        ],
      ),
    );
  }
}
