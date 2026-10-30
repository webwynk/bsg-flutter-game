// The change-password popup on all three devices. The same list of cases runs
// on the phone popup and the wide popup, because both use ChangePasswordForm:
// every message, the server call, the auto-close and "cannot be dismissed".
// Pictures of the wide popup are saved to reference-design/login/after/.
import 'package:best_smart_game/screens/lobby_screen.dart';
import 'package:best_smart_game/widgets/login/security_wide_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'login_test_harness.dart';

const _wide = ValueKey('security-wide-dialog');

/// A device to run the cases on.
class _Device {
  final String name;
  final Size size;
  final bool windows;
  final bool wide;
  const _Device(this.name, this.size, {this.windows = false, this.wide = true});
}

const _devices = [
  _Device('phone', Size(390, 844), wide: false),
  _Device('tablet', Size(1180, 820)),
  _Device('desktop', Size(1920, 1080), windows: true),
];

Future<void> _open(WidgetTester tester, _Device d, FakeAuth auth) async {
  if (d.windows) debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  setScreen(tester, d.size);
  await tester.pumpWidget(loginApp(auth, const LobbyScreen()));
  await decodeImages(tester);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.lock));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, String current, String fresh, String confirm) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), current);
  await tester.enterText(fields.at(1), fresh);
  await tester.enterText(fields.at(2), confirm);
}

Future<void> _update(WidgetTester tester) async {
  await tester.tap(find.text('UPDATE PASSWORD'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void _done() => debugDefaultTargetPlatformOverride = null;

void main() {
  setUpAll(setUpLoginTests);

  for (final d in _devices) {
    group(d.name, () {
      const cases = [
        ('', '', '', 'Please enter your current password.'),
        ('oldpass', '', '', 'Please enter a new password.'),
        ('oldpass', 'abc', 'abc', 'New password must be at least 6 characters.'),
        ('oldpass', 'newpass1', 'newpass2', 'New password and confirmation do not match.'),
        ('samepass', 'samepass', 'samepass', 'New password must be different from current password.'),
      ];

      for (final (current, fresh, confirm, message) in cases) {
        testWidgets('check: $message', (tester) async {
          final auth = FakeAuth();
          await _open(tester, d, auth);
          await _fill(tester, current, fresh, confirm);
          await _update(tester);
          expect(find.text(message), findsOneWidget);
          expect(auth.passwordCalls, isEmpty);
          expect(tester.takeException(), isNull);
          _done();
        });
      }

      testWidgets('success: calls the server with trimmed text, shows the message, closes itself', (tester) async {
        final auth = FakeAuth();
        await _open(tester, d, auth);
        await _fill(tester, ' oldpass ', ' newpass1 ', 'newpass1');
        await _update(tester);
        expect(auth.passwordCalls, [('oldpass', 'newpass1')]);
        expect(find.text('Password updated successfully!'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1000));
        expect(find.text('SECURITY & ACCOUNT'), findsOneWidget, reason: 'still open at 1.1s');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.text('SECURITY & ACCOUNT'), findsNothing);
        _done();
      });

      testWidgets('the server refuses: its text is shown', (tester) async {
        final auth = FakeAuth()
          ..passwordResult = false
          ..passwordError = 'Current password is wrong.';
        await _open(tester, d, auth);
        await _fill(tester, 'oldpass', 'newpass1', 'newpass1');
        await _update(tester);
        expect(find.text('Current password is wrong.'), findsOneWidget);
        _done();
      });

      testWidgets('the server refuses with no text: the fallback is shown', (tester) async {
        final auth = FakeAuth()..passwordResult = false;
        await _open(tester, d, auth);
        await _fill(tester, 'oldpass', 'newpass1', 'newpass1');
        await _update(tester);
        expect(find.text('Failed to update password.'), findsOneWidget);
        _done();
      });

      testWidgets('tapping outside or pressing back does not close it; the X does', (tester) async {
        await _open(tester, d, FakeAuth());
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.text('SECURITY & ACCOUNT'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('SECURITY & ACCOUNT'), findsOneWidget);
        await tester.tap(d.wide ? find.byKey(const ValueKey('security-close')) : find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('SECURITY & ACCOUNT'), findsNothing);
        _done();
      });

      testWidgets('the eye shows and hides each field; logout is on offer', (tester) async {
        await _open(tester, d, FakeAuth());
        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(3));
        for (var i = 0; i < 3; i++) {
          expect(tester.widget<TextField>(fields.at(i)).obscureText, isTrue);
        }
        await tester.tap(find.byIcon(Icons.visibility_off_outlined).first);
        await tester.pump();
        expect(tester.widget<TextField>(fields.at(0)).obscureText, isFalse);
        expect(find.text('LOGOUT ACCOUNT'), findsOneWidget);
        _done();
      });

      testWidgets('it is the right popup for the device', (tester) async {
        await _open(tester, d, FakeAuth());
        expect(find.byKey(_wide), d.wide ? findsOneWidget : findsNothing);
        expect(find.text('CHANGE PASSWORD'), d.wide ? findsOneWidget : findsNothing);
        if (d.wide) {
          final expected = d.windows ? 780 * 1.4 : 780.0;
          expect(tester.getSize(find.byKey(_wide)).width, closeTo(expected, 0.5));
          for (final t in const [
            'At least 6 characters',
            'Different from the current one',
            'Both new entries must match',
            'CURRENT PASSWORD',
            'NEW PASSWORD (MIN 6 CHARS)',
            'CONFIRM NEW PASSWORD',
            '@player01',
          ]) {
            expect(find.text(t), findsOneWidget, reason: t);
          }
        }
        _done();
      });
    });
  }

  group('wide popup fit', () {
    test('a window narrower than the popup shrinks it', () {
      expect(SecurityWideDialog.scaleFor(1180, desktop: false), 1.0);
      expect(SecurityWideDialog.scaleFor(1920, desktop: true), 1.4);
      expect(SecurityWideDialog.scaleFor(800, desktop: true), closeTo(752 / 780, 0.001));
    });

    testWidgets('960 x 600 tablet with the keyboard up: nothing overflows and the field stays visible', (tester) async {
      await _open(tester, const _Device('small', Size(960, 600)), FakeAuth());
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(TextField).at(2));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(TextField).at(2)).bottom, lessThanOrEqualTo(600 - 280));
    });
  });

  group('pictures', () {
    Future<void> shoot(WidgetTester tester, _Device d, bool error) async {
      await _open(tester, d, FakeAuth());
      if (error) {
        await tester.tap(find.text('UPDATE PASSWORD'));
        await tester.pumpAndSettle();
      }
      final kind = d.windows ? 'desktop' : 'tablet';
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
            '../../reference-design/login/after/${kind}_password_popup${error ? '_error' : ''}_${d.size.width.toInt()}x${d.size.height.toInt()}.png'),
      );
      _done();
    }

    for (final d in const [
      _Device('tablet', Size(1024, 768)),
      _Device('tablet', Size(1180, 820)),
      _Device('desktop', Size(1920, 1080), windows: true),
    ]) {
      testWidgets('${d.name} ${d.size}', (tester) => shoot(tester, d, false));
      testWidgets('${d.name} ${d.size} with an error', (tester) => shoot(tester, d, true));
    }
  });
}
