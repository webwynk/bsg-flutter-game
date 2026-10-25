// Spin2Win screens, Phase 2: the betting panel working on the screen (lib/screens/spin2win_screen.dart,
// lib/widgets/spin2win/spin2win_frame_binding.dart).
//
// The whole screen runs over the provider on the simulated server and a fake clock (provider_rig.dart):
// every test taps the drawn cards, chips and buttons and checks what the panel then shows and what
// the wallet holds.

import 'dart:typed_data';

import 'package:best_smart_game/models/spin2win_board.dart';
import 'package:best_smart_game/providers/spin2win_provider.dart';
import 'package:best_smart_game/screens/spin2win_screen.dart';
import 'package:best_smart_game/services/spin2win_sound.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_alerts.dart';
import 'fake_sound.dart';
import 'provider_rig.dart';

/// A 1 x 1 transparent PNG, standing in for the chip pictures.
final Uint8List _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class _Screen {
  _Screen(this.tester, this.rig);

  final WidgetTester tester;
  final BetRig rig;
  final List<Set<Spin2WinBoardIssue>> refusals = [];

  Spin2WinProvider get p => rig.provider;

  Future<void> open() async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Spin2WinScreen(
        setup: Spin2WinScreenSetup(
          provider: rig.provider,
          setOrientation: false,
          precacheChips: false,
          alerts: FakeAlerts(),
          sound: Spin2WinSound(FakeSoundOutput()),
          chipImage: (_) => MemoryImage(_pixel),
          onRefused: refusals.add,
          onProblem: (_) {},
        ),
      ),
    ));
    await rig.world.run(const Duration(seconds: 1));
    await tester.pump();
  }

  Future<void> tap(String key) async {
    await tester.tap(find.byKey(ValueKey('spin2win-$key')), warnIfMissed: false);
    await tester.pump();
  }

  /// The text of every [Text] under the widget with this key, joined.
  String text(String key) => tester
      .widgetList<Text>(find.descendant(of: find.byKey(ValueKey('spin2win-$key')), matching: find.byType(Text), matchRoot: true))
      .map((t) => t.data ?? '')
      .toSet()
      .join(' ');

  String stake(int n) => text('stake-$n');

  /// How strongly the button with this key is drawn (1 = normal, less = dimmed).
  double opacityOf(String key) {
    final fade = find.ancestor(of: find.byKey(ValueKey('spin2win-$key')), matching: find.byType(AnimatedOpacity));
    return tester.widget<AnimatedOpacity>(fade.first).opacity;
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
    await rig.finish();
  }
}

void main() {
  testWidgets('the screen opens on the provider: balance, PLAY 0, countdown, empty cards', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40));
    await s.open();
    expect(s.text('balance'), '1,000');
    expect(s.text('play'), '0');
    expect(s.text('countdown'), '${s.p.countdown}'.padLeft(2, '0'));
    expect(int.parse(s.text('countdown')), inInclusiveRange(48, 50));
    for (var n = 0; n <= 9; n++) {
      expect(s.stake(n), '0');
    }
    await s.close();
  });

  testWidgets('a chip, then a card: the coins go on the card, off the balance, onto PLAY', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40));
    await s.open();
    await s.tap('chip-10');
    expect(s.p.activeChip, Spin2WinChip.ten);
    await s.tap('card-3');
    await s.tap('card-3');
    await s.tap('chip-500');
    await s.tap('card-0');
    expect(s.stake(3), '20');
    expect(s.stake(0), '500');
    expect(s.text('balance'), '480');
    expect(s.text('play'), '520');
    expect(s.refusals, isEmpty);
    await s.close();
  });

  testWidgets('ODD puts the chip on 1 3 5 7 9, EVEN on 0 2 4 6 8 (0 is even), pressing again adds', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40));
    await s.open();
    await s.tap('chip-5');
    await s.tap('odd');
    expect([for (var n = 0; n <= 9; n++) s.stake(n)], ['0', '5', '0', '5', '0', '5', '0', '5', '0', '5']);
    await s.tap('odd');
    await s.tap('chip-10');
    await s.tap('even');
    expect([for (var n = 0; n <= 9; n++) s.stake(n)], ['10', '10', '10', '10', '10', '10', '10', '10', '10', '10']);
    expect(s.text('play'), '100');
    expect(s.text('balance'), '900');
    await s.close();
  });

  testWidgets('DOUBLE doubles every stake; it is dimmed while the board is empty', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40));
    await s.open();
    expect(s.opacityOf('double'), lessThan(1));
    await s.tap('double');
    expect(s.text('play'), '0');
    await s.tap('chip-50');
    await s.tap('card-7');
    await s.tap('card-2');
    expect(s.opacityOf('double'), 1);
    await s.tap('double');
    expect(s.stake(7), '100');
    expect(s.stake(2), '100');
    expect(s.text('balance'), '800');
    await s.close();
  });

  testWidgets('REMOVE puts the chip down: the next taps on a card take its newest chip back', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40));
    await s.open();
    await s.tap('chip-10');
    await s.tap('card-4');
    await s.tap('chip-100');
    await s.tap('card-4');
    expect(s.stake(4), '110');
    await s.tap('remove');
    expect(s.p.activeChip, isNull);
    await s.tap('card-4');
    expect(s.stake(4), '10');
    await s.tap('card-4');
    expect(s.stake(4), '0');
    expect(s.text('balance'), '1,000');
    // With no chip in hand ODD takes chips back too.
    await s.tap('chip-5');
    await s.tap('odd');
    await s.tap('remove');
    await s.tap('odd');
    expect(s.text('play'), '0');
    await s.close();
  });

  testWidgets('CLEAR gives every chip back', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40));
    await s.open();
    await s.tap('chip-100');
    await s.tap('even');
    expect(s.text('balance'), '500');
    await s.tap('clear');
    expect(s.text('balance'), '1,000');
    expect(s.text('play'), '0');
    expect(s.opacityOf('clear'), lessThan(1));
    await s.close();
  });

  testWidgets('a number at 10,000 is skipped by EVEN, and the refusal is reported', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40, startBalance: 50000));
    await s.open();
    await s.tap('chip-500');
    for (var i = 0; i < 20; i++) {
      await s.tap('card-0');
    }
    expect(s.stake(0), '10,000');
    s.refusals.clear();
    await s.tap('even');
    expect(s.stake(0), '10,000');
    expect(s.stake(2), '500');
    expect(s.refusals.single, contains(Spin2WinBoardIssue.numberAtMaximum));
    await s.close();
  });

  testWidgets('not enough coins: nothing is placed and the refusal is reported', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40, startBalance: 100));
    await s.open();
    await s.tap('chip-500');
    await s.tap('card-1');
    expect(s.stake(1), '0');
    expect(s.text('balance'), '100');
    expect(s.refusals.single, contains(Spin2WinBoardIssue.notEnoughCoins));
    await s.close();
  });

  testWidgets('at 05 the board locks: dimmed, taps ignored, and the bet is sent', (tester) async {
    final rig = BetRig(tester, startInto: 80);
    final s = _Screen(tester, rig);
    await s.open();
    await s.tap('chip-10');
    await s.tap('card-5');
    await rig.world.runUntil(85.5);
    await tester.pump();
    expect(s.p.isLocked, isTrue);
    expect(s.text('countdown'), anyOf('05', '04'));
    expect(s.opacityOf('card-5'), lessThan(1));
    expect(s.opacityOf('chip-10'), lessThan(1));
    expect(s.opacityOf('odd'), lessThan(1));
    await s.tap('card-5');
    await s.tap('odd');
    await s.tap('clear');
    expect(s.stake(5), '10');
    expect(s.stake(1), '0');
    await rig.world.run(const Duration(seconds: 1));
    expect(rig.server.betsReceived, 1);
    await s.close();
  });

  testWidgets('after a round DOUBLE becomes REBET, which puts the last bet back', (tester) async {
    final rig = BetRig(tester, startInto: 80);
    final s = _Screen(tester, rig);
    await s.open();
    await s.tap('chip-10');
    await s.tap('card-5');
    await s.tap('card-6');
    expect(find.byKey(const ValueKey('spin2win-double')), findsOneWidget);
    // Through the draw, the wheel's landing and into the next round's betting.
    await landWheelAt(rig, 94.2);
    await rig.runIntoNextCycle(3);
    await tester.pump();
    expect(s.p.isLocked, isFalse);
    expect(find.byKey(const ValueKey('spin2win-rebet')), findsOneWidget);
    expect(find.byKey(const ValueKey('spin2win-double')), findsNothing);
    expect(s.opacityOf('rebet'), 1);
    final before = s.p.balance;
    await s.tap('rebet');
    expect(s.stake(5), '10');
    expect(s.stake(6), '10');
    expect(s.p.balance, before - 20);
    expect(find.byKey(const ValueKey('spin2win-double')), findsOneWidget);
    await s.close();
  });

  testWidgets('the history strip and the dome show the results the provider has', (tester) async {
    final rig = BetRig(tester, startInto: 80);
    final s = _Screen(tester, rig);
    await s.open();
    await landWheelAt(rig, 94.2);
    await rig.runIntoNextCycle(3);
    await tester.pump();
    final first = s.p.history.first;
    expect(s.text('history-0'), contains('${first.winningNumber}'));
    expect(s.text('dome-number'), '${first.winningNumber}');
    await s.close();
  });

  testWidgets('closing the screen gives back chips that were never sent', (tester) async {
    final rig = BetRig(tester, startInto: 40);
    final s = _Screen(tester, rig);
    await s.open();
    await s.tap('chip-100');
    await s.tap('card-8');
    expect(rig.wallet.balance, 900);
    await tester.pumpWidget(const SizedBox());
    expect(rig.wallet.balance, 1000);
    await rig.finish();
  });
}
