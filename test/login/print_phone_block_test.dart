// A print player opening a game away from the Windows app gets the message and
// no game. Everyone else is unaffected.
import 'package:best_smart_game/screens/lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'login_test_harness.dart';

const _message = 'USE THE DESKTOP APP';

Future<void> _openLobby(WidgetTester tester, Future<bool> Function() check) async {
  setScreen(tester, const Size(844, 390));
  await tester.pumpWidget(loginApp(
    FakeAuth(),
    LobbyScreen(desktopCheck: check, connectionCheck: () async => true),
  ));
  await decodeImages(tester);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// The first poster in the grid, Triple Chance.
Finder get _firstGame => find.byType(GridView).first;

void main() {
  setUpAll(setUpLoginTests);

  testWidgets('a print player gets the message and stays in the lobby', (tester) async {
    await _openLobby(tester, () async => true);
    await tester.tapAt(tester.getTopLeft(_firstGame) + const Offset(60, 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(_message), findsOneWidget);
    expect(find.text('Your account plays with printed tickets. Please open BSG on your Windows computer.'), findsOneWidget);
    expect(find.byType(LobbyScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text(_message), findsNothing);
  });

  testWidgets('the lobby looks the same for a print player until a game is tapped', (tester) async {
    await _openLobby(tester, () async => true);
    expect(find.text(_message), findsNothing);
  });

  testWidgets('a normal player gets no message', (tester) async {
    await _openLobby(tester, () async => false);
    await tester.tapAt(tester.getTopLeft(_firstGame) + const Offset(60, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(_message), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed check lets the player through; the server still decides', (tester) async {
    await _openLobby(tester, () async => false);
    expect(find.text(_message), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
