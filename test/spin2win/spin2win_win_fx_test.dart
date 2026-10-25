// Spin2Win screens, Phase 4: what a win looks like (the coin burst, the win popup, the WIN box and
// coin box bump, the newest history tile popping in), on the whole screen over the simulated server.
//
// The round is number 7 with the 4x bonus, so a stake on 7 pays 36 times over: 25 pays exactly 900
// (coins burst), 10 pays 360 (no coins, the popup at the same moment).

import 'dart:typed_data';

import 'package:best_smart_game/models/spin2win_board.dart';
import 'package:best_smart_game/screens/spin2win_screen.dart';
import 'package:best_smart_game/services/spin2win_sound.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_bump.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_coin_burst.dart';
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

String _text(WidgetTester tester, String key) => tester
    .widgetList<Text>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text), matchRoot: true))
    .map((t) => t.data ?? '')
    .toSet()
    .join(' ');

final Finder _burst = find.byKey(const ValueKey('spin2win-coin-burst'));
final Finder _popup = find.byKey(const ValueKey('spin2win-win-popup'));

/// Opens the screen 80 s into the round and puts [chips] on [number].
Future<BetRig> _open(WidgetTester tester, {required int number, required List<Spin2WinChip> chips}) async {
  final rig = BetRig(tester, startInto: 80);
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
        onProblem: (_) {},
      ),
    ),
  ));
  await rig.world.run(const Duration(seconds: 1));
  await tester.pump();
  for (final chip in chips) {
    rig.provider.selectChip(chip);
    rig.provider.tapNumber(number);
  }
  await tester.pump();
  return rig;
}

/// Runs until the wheel has stopped and the result is shown. Returns that moment's round position.
Future<double> _untilRevealed(BetRig rig) async {
  await rig.world.runUntil(91);
  var guard = 0;
  while (!rig.provider.numberRevealed && ++guard < 200) {
    await rig.world.run(const Duration(milliseconds: 50));
  }
  expect(rig.provider.numberRevealed, isTrue);
  return rig.world.cyclePosition;
}

Future<void> _close(WidgetTester tester, BetRig rig) async {
  await tester.pumpWidget(const SizedBox());
  await rig.finish();
}

void main() {
  test('the coins burst for a win of 900 or more, never below', () {
    expect(kSpin2WinCoinBurstMinWin, 900);
    expect(spin2WinShowsCoinBurst(0), isFalse);
    expect(spin2WinShowsCoinBurst(899), isFalse);
    expect(spin2WinShowsCoinBurst(900), isTrue);
    expect(spin2WinShowsCoinBurst(36000), isTrue);
  });

  testWidgets('a win of exactly 900: coins, then the popup for 2.5 s with 7 x 4x = +900', (tester) async {
    final rig = await _open(tester, number: 7, chips: [Spin2WinChip.ten, Spin2WinChip.ten, Spin2WinChip.five]);
    expect(rig.provider.stakeOn(7), 25);
    final w = await _untilRevealed(rig);

    expect(rig.provider.lastOutcome!.payout, 900);
    expect(_burst, findsOneWidget);
    expect(_popup, findsNothing);
    expect(_text(tester, 'spin2win-win'), '900');
    // The coins come out of the middle of the wheel.
    final hub = tester.getCenter(find.byKey(const ValueKey('spin2win-dome')));
    expect((hub - kSpin2WinHubCentre).distance, lessThan(6), reason: 'hub at $hub');

    // 1.5 s after the stop the coins make way for the popup.
    await rig.world.runUntil(w + 1.7);
    expect(_burst, findsNothing);
    expect(_popup, findsOneWidget);
    expect(_text(tester, 'spin2win-win-number'), '7');
    expect(_text(tester, 'spin2win-win-bonus'), '4x');
    expect(_text(tester, 'spin2win-win-amount'), '+900');

    await rig.world.runUntil(w + 3.8);
    expect(_popup, findsOneWidget);
    await rig.world.runUntil(w + 4.4);
    expect(_popup, findsNothing);
    expect(_text(tester, 'spin2win-win'), '900', reason: 'the WIN box keeps the payout');
    await _close(tester, rig);
  });

  testWidgets('a win of 360: no coins, but the popup waits the same 1.5 s', (tester) async {
    final rig = await _open(tester, number: 7, chips: [Spin2WinChip.ten]);
    final w = await _untilRevealed(rig);
    expect(rig.provider.lastOutcome!.payout, 360);
    expect(rig.provider.showCoinFx, isTrue, reason: 'the coin time is still kept');

    for (var t = w; t < w + 1.3; t += 0.1) {
      await rig.world.runUntil(t);
      expect(_burst, findsNothing, reason: 'at ${t - w}');
      expect(_popup, findsNothing, reason: 'at ${t - w}');
    }
    await rig.world.runUntil(w + 1.7);
    expect(_popup, findsOneWidget);
    expect(_text(tester, 'spin2win-win-amount'), '+360');
    await rig.world.runUntil(w + 4.4);
    expect(_popup, findsNothing);
    await _close(tester, rig);
  });

  testWidgets('a loss: no coins, no popup, no bump', (tester) async {
    final rig = await _open(tester, number: 3, chips: [Spin2WinChip.hundred]);
    final w = await _untilRevealed(rig);
    for (var t = w; t < w + 5; t += 0.25) {
      await rig.world.runUntil(t);
      expect(_burst, findsNothing);
      expect(_popup, findsNothing);
      expect(find.byType(ColorFiltered), findsNothing);
    }
    expect(_text(tester, 'spin2win-win'), '0');
    await _close(tester, rig);
  });

  testWidgets('a win bumps the coin box and the WIN figure; the new history tile pops in', (tester) async {
    final rig = await _open(tester, number: 7, chips: [Spin2WinChip.ten]);
    // Opening the screen plays neither.
    expect(find.byType(ColorFiltered), findsNothing);
    final pop = find.ancestor(of: find.byKey(const ValueKey('spin2win-history-0')), matching: find.byType(Transform));
    expect(pop, findsNothing);

    await rig.world.runUntil(91);
    while (!rig.provider.numberRevealed) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 150));
    expect(_text(tester, 'spin2win-history-0'), '7 4x');
    expect(pop, findsOneWidget, reason: 'the newest tile is growing in');
    final bumped = find.ancestor(of: find.byKey(const ValueKey('spin2win-balance')), matching: find.byType(ColorFiltered));
    expect(bumped, findsOneWidget);
    expect(
      find.ancestor(of: find.byKey(const ValueKey('spin2win-win')), matching: find.byType(ColorFiltered)),
      findsOneWidget,
    );

    await tester.pump(Spin2WinBump.duration);
    expect(pop, findsNothing);
    expect(bumped, findsNothing);
    await _close(tester, rig);
  });
}
