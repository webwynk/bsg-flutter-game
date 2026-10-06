// Tests for the lobby entry (App Step 9, spec §17AI): lib/screens/lobby_screen.dart shows the Lucky
// Card poster in its second slot and opens the Lucky Card screen from it, while Triple Chance
// still opens its named route '/game' exactly as before and a "coming soon" card still does not
// open anything.
//
// The lobby needs a logged-in user only for a name and a balance, so a stand-in is used (the real
// AuthProvider needs a Supabase connection). The pictures come from the real asset bundle, which
// also proves the new line of pubspec.yaml.

import 'package:best_smart_game/providers/auth_provider.dart';
import 'package:best_smart_game/screens/lobby_screen.dart';
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
    for (final e in cards.evaluate())
      ((e.widget as Image).image as AssetImage).assetName,
  ];
}

Finder cardAt(int index) => find.descendant(of: find.byType(GridView), matching: find.byType(GestureDetector)).at(index);

void main() {
  testWidgets('the lobby shows Triple Chance, then Lucky Card, then eight "coming soon" cards', (tester) async {
    await openLobby(tester);
    final shown = posters(tester);
    expect(shown.length, 10);
    expect(shown[0], 'assets/images/card_triple_chance.webp');
    expect(shown[1], 'assets/lucky_card/images/lucky-card-game-card.webp');
    expect(shown.sublist(2), everyElement('assets/images/card_coming_soon.webp'));
    expect(shown.sublist(2).length, 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Lucky Card poster loads from the app\'s own bundle and keeps the card shape', (tester) async {
    await openLobby(tester);
    final poster = find.byWidgetPredicate(
      (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/lucky_card/images/lucky-card-game-card.webp',
    );
    expect(poster, findsOneWidget);
    final size = tester.getSize(poster);
    expect(size.width / size.height, closeTo(474 / 680, 0.02), reason: 'the poster is 474 x 680 and the grid cell is 0.70');
    expect(tester.takeException(), isNull, reason: 'a missing asset would be an error here');
  });

  testWidgets('a tap on Triple Chance opens its named route, exactly as before', (tester) async {
    await openLobby(tester);
    await tester.tap(cardAt(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('tc-screen')), findsOneWidget);
    expect(find.byType(LuckyCardScreen), findsNothing);
  });

  testWidgets('a tap on Lucky Card opens the Lucky Card screen, and not Triple Chance\'s', (tester) async {
    await openLobby(tester);
    await tester.tap(cardAt(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(LuckyCardScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('tc-screen')), findsNothing);
  });

  testWidgets('a "coming soon" card opens neither game', (tester) async {
    await openLobby(tester);
    await tester.tap(cardAt(2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(LuckyCardScreen), findsNothing);
    expect(find.byKey(const ValueKey('tc-screen')), findsNothing);
    // The lobby's "coming soon" notice closes itself after 5 seconds.
    await tester.pump(const Duration(seconds: 6));
  });
}
