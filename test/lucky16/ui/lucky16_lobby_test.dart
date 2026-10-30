// Tests for the Lucky 16 Card lobby entry (phone phase 8): lib/screens/lobby_screen.dart shows the Lucky
// 16 Card poster in slot 4, where the first "coming soon" card was, and opens the Lucky 16 Card screen
// from it, while the other games open as before. The pictures come from the real asset bundle, which
// also proves the new line of pubspec.yaml. Copied from test/lucky_card/ui/lucky_card_lobby_test.dart.

import 'package:best_smart_game/providers/auth_provider.dart';
import 'package:best_smart_game/screens/lobby_screen.dart';
import 'package:best_smart_game/screens/lucky16_screen.dart';
import 'package:best_smart_game/screens/lucky_card_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// What the lobby reads from the logged-in user.
class StandInAuth extends ChangeNotifier implements AuthProvider {
  @override
  String get username => 'aisha';

  @override
  int get coinBalance => 1000;

  @override
  bool get isLoggedIn => true;

  // What the Lucky Card screen's wallet calls on the user.
  @override
  void updateBalance(int newBalance) {}

  @override
  void syncAuthoritativeBalance(int newBalance, int version) {}

  @override
  void setUncommittedStakeGetter(int? Function()? getter) {}

  @override
  void setIsSpinningGetter(bool Function()? getter) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const Size phone = Size(915, 412);

Future<void> openLobby(WidgetTester tester) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: StandInAuth(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const LobbyScreen(),
        routes: {
          '/game': (_) => const Scaffold(body: Center(child: Text('TRIPLE CHANCE SCREEN', key: ValueKey('tc-screen')))),
        },
      ),
    ),
  );
  // The cards slide in one after another (80 ms apart, 400 ms each).
  await tester.pump(const Duration(seconds: 2));
}

/// The cards of the lobby, left to right and top to bottom, as the names of their pictures.
List<String> posters(WidgetTester tester) {
  final cards = find.descendant(of: find.byType(GridView), matching: find.byType(Image));
  return [
    for (final e in cards.evaluate()) ((e.widget as Image).image as AssetImage).assetName,
  ];
}

Finder cardAt(int index) =>
    find.descendant(of: find.byType(GridView), matching: find.byType(GestureDetector)).at(index);

void main() {
  testWidgets('slot 4 is the Lucky 16 Card poster, then six "coming soon" cards', (tester) async {
    await openLobby(tester);
    final shown = posters(tester);
    expect(shown.length, 10);
    expect(shown[3], 'assets/lucky16card/images/lucky-16-game-card.webp');
    expect(shown.sublist(4), everyElement('assets/images/card_coming_soon.webp'));
    expect(shown.sublist(4).length, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the poster loads from the real bundle and keeps the card shape', (tester) async {
    await openLobby(tester);
    final poster = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/lucky16card/images/lucky-16-game-card.webp',
    );
    expect(poster, findsOneWidget);
    final size = tester.getSize(poster);
    expect(size.width / size.height, closeTo(474 / 680, 0.02));
    expect(tester.takeException(), isNull, reason: 'a missing asset would be an error here');
  });

  testWidgets('a tap on it opens the Lucky 16 Card screen, and no other game', (tester) async {
    await openLobby(tester);
    await tester.tap(cardAt(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(Lucky16Screen), findsOneWidget);
    expect(find.byType(LuckyCardScreen), findsNothing);
    expect(find.byKey(const ValueKey('tc-screen')), findsNothing);
  });

  testWidgets('a "coming soon" card still opens nothing', (tester) async {
    await openLobby(tester);
    await tester.tap(cardAt(4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(Lucky16Screen), findsNothing);
    expect(find.byKey(const ValueKey('tc-screen')), findsNothing);
    // The lobby's "coming soon" notice closes itself after 5 seconds.
    await tester.pump(const Duration(seconds: 6));
  });
}
