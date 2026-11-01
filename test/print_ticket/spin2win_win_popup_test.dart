// The Spin2Win win popup with a print player's tickets, drawn at the Windows board size.
import 'dart:io';

import 'package:best_smart_game/print_ticket/spin2win_tickets.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_layout.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_win_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Spin2WinTicket ticket(int no, int stake, int win) => Spin2WinTicket(
      id: 'id$no',
      code: 'SW-P17-${no.toString().padLeft(4, '0')}',
      number: no,
      roundId: 'r',
      roundNumber: 1,
      items: const {7: 100},
      totalStake: stake,
      printStatus: 'printed',
      reprintCount: 0,
      createdAt: DateTime(2026, 11, 1),
      win: win,
    );

Future<void> show(WidgetTester tester, List<Spin2WinTicket> tickets) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: const Color(0xFF07132E),
      body: Spin2WinZoom(
        zoom: Spin2WinLayout.desktop.popupZoom,
        child: Spin2WinWinOverlay(number: 7, bonusMultiplier: 2, amount: 245700, tickets: tickets),
      ),
    ),
  ));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    for (final (family, files) in [
      ('DMSans', ['Regular', 'Bold', 'ExtraBold', 'Black']),
      ('Oswald', ['Regular', 'Medium', 'SemiBold', 'Bold']),
    ]) {
      final loader = FontLoader(family);
      for (final f in files) {
        final b = File('assets/fonts/$family-$f.ttf').readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(b.buffer)));
      }
      await loader.load();
    }
  });

  testWidgets('one winning ticket shows its number, bet and win, on screen', (tester) async {
    await show(tester, [ticket(1, 3300, 1350), ticket(2, 500, 0)]);
    expect(find.text('SW-P17-0001'), findsOneWidget);
    expect(find.text('SW-P17-0002'), findsNothing, reason: 'a losing ticket is not a winner');
    expect(find.text('3,300'), findsOneWidget);
    expect(find.text('1,350'), findsOneWidget);
    expect(find.text('Round total play 3,800 - all tickets in Records'), findsOneWidget);
    final box = tester.getRect(find.byKey(const ValueKey('spin2win-win-tickets')));
    expect(box.top, greaterThanOrEqualTo(0));
    expect(box.bottom, lessThanOrEqualTo(1080));
    expect(tester.takeException(), isNull);
  });

  testWidgets('many winning tickets stay in a set height', (tester) async {
    await show(tester, [for (var i = 1; i <= 9; i++) ticket(i, 1000, 18000)]);
    expect(find.text('SW-P17-0003'), findsOneWidget);
    expect(find.text('SW-P17-0004'), findsNothing);
    expect(find.text('and 6 more tickets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a normal bet draws the popup as before', (tester) async {
    await show(tester, const []);
    expect(find.byKey(const ValueKey('spin2win-win-tickets')), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('spin2win-win-popup'))).height, 326);
  });

  testWidgets('a picture to look at', (tester) async {
    await show(tester, [ticket(1, 3300, 135000), ticket(2, 5000, 90000), ticket(3, 1000, 18000), ticket(4, 200, 3600), ticket(5, 100, 0)]);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../../docs/print_phase3/win_spin2win_tickets.png'));
  }, skip: !Platform.environment.containsKey('BSG_PICTURES'));
}
