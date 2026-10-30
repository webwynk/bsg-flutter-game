// The lobby top bar's side padding: 35 on a phone held sideways, 16 on a
// tablet or desktop and on a phone turned upright for the password popup.
import 'package:best_smart_game/screens/lobby_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'login_test_harness.dart';

/// A long name and a big balance, the widest the bar normally gets.
class _WideAuth extends FakeAuth {
  _WideAuth() : super(name: 'player123456');

  @override
  int get coinBalance => 12345678;
}

Future<void> _open(WidgetTester tester, Size size) async {
  setScreen(tester, size);
  await tester.pumpWidget(loginApp(_WideAuth(), const LobbyScreen()));
  await decodeImages(tester);
  await tester.pumpAndSettle();
}

/// How far the logo sits from the left edge and the lock from the right.
(double, double) _gaps(WidgetTester tester, Size size) {
  final logo = find.byWidgetPredicate(
      (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.contains('icon_bsg_1024'));
  return (tester.getRect(logo).left, size.width - tester.getRect(find.byIcon(Icons.lock).first).right);
}

void main() {
  setUpAll(setUpLoginTests);

  for (final size in const [
    Size(568, 320),
    Size(640, 360),
    Size(740, 360),
    Size(780, 360),
    Size(844, 390),
    Size(915, 412),
    Size(932, 430),
  ]) {
    testWidgets('phone $size: 35 on each side, and everything still fits', (tester) async {
      await _open(tester, size);
      expect(tester.takeException(), isNull);
      final (left, right) = _gaps(tester, size);
      expect(left, closeTo(35, 0.5));
      // The lock icon fills its box, which has a 1.2 border.
      expect(right, closeTo(35 + 1.2, 0.5));
      // The middle text needs 500 of room, which is 570 wide with this padding.
      expect(find.textContaining('AMUSEMENT'), size.width >= 570 ? findsOneWidget : findsNothing);
    });
  }

  testWidgets('phone turned upright: stays at 16', (tester) async {
    const size = Size(390, 844);
    await _open(tester, size);
    final (left, _) = _gaps(tester, size);
    expect(left, closeTo(16, 0.5));
  });

  testWidgets('tablet: stays at 16', (tester) async {
    const size = Size(1180, 820);
    await _open(tester, size);
    final (left, right) = _gaps(tester, size);
    expect(left, closeTo(16, 0.5));
    expect(right, closeTo(16 + 1.2, 0.5));
  });

  testWidgets('desktop: stays at 16', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const size = Size(1280, 720);
    await _open(tester, size);
    final (left, _) = _gaps(tester, size);
    debugDefaultTargetPlatformOverride = null;
    expect(left, closeTo(16, 0.5));
  });

  for (final size in const [Size(844, 390), Size(640, 360)]) {
    testWidgets('picture of the phone lobby at $size', (tester) async {
      await _open(tester, size);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
            '../../reference-design/lobby_topbar/after_phone_${size.width.toInt()}x${size.height.toInt()}.png'),
      );
    });
  }
}
