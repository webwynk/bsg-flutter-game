// Spin2Win screens, Phase 6: the sounds and Spin2Win's own mute (lib/services/spin2win_sound.dart,
// lib/services/spin2win_sound_director.dart, and the screen's taps).
//
// The screen runs over the provider on the simulated server and a fake clock (provider_rig.dart);
// [FakeSoundOutput] writes down every sound asked for. The round is number 7 with the 4x bonus.

import 'dart:typed_data';

import 'package:best_smart_game/models/spin2win_board.dart';
import 'package:best_smart_game/screens/spin2win_screen.dart';
import 'package:best_smart_game/services/spin2win_sound.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_alerts.dart';
import 'fake_sound.dart';
import 'provider_rig.dart';

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
  final FakeSoundOutput out = FakeSoundOutput();

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
          chipImage: (_) => MemoryImage(_pixel),
          alerts: FakeAlerts(),
          sound: Spin2WinSound(out),
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

  /// The sounds asked for since the last call.
  List<String> take() {
    final list = List<String>.of(out.played);
    out.played.clear();
    return list;
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
    await rig.finish();
  }
}

/// Runs the round on to [until], keeping every sound in order.
Future<void> _runTo(_Screen s, double until) async {
  await s.rig.world.runUntil(until);
}

void main() {
  setUp(Spin2WinSound.resetMute);
  tearDown(Spin2WinSound.resetMute);

  testWidgets('taps: a card, a chip and a button each make their sound, a refused tap none', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40));
    await s.open();
    expect(s.out.inGame, [true], reason: 'opening sets Triple Chance\'s in-game flag');
    s.take();

    await s.tap('chip-10');
    await s.tap('card-3');
    await s.tap('odd');
    await s.tap('double');
    await s.tap('clear');
    expect(s.take(), ['chip', 'number', 'button', 'button', 'button']);

    // Nothing on the board to clear: no sound.
    await s.tap('clear');
    expect(s.take(), isEmpty);

    await s.tap('chip-10');
    await s.tap('card-3');
    await s.tap('remove');
    await s.tap('remove');
    expect(s.take(), ['chip', 'number', 'button'], reason: 'only the first REMOVE had a chip to put down');
    await s.close();
  });

  testWidgets('a winning round of 900: no more bets, spin, stop and ding, coins, win', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 80));
    await s.open();
    s.rig.provider.selectChip(Spin2WinChip.ten);
    s.rig.provider.tapNumber(7);
    s.rig.provider.tapNumber(7);
    s.rig.provider.selectChip(Spin2WinChip.five);
    s.rig.provider.tapNumber(7);
    await tester.pump();
    s.take();

    await _runTo(s, 99);
    expect(s.take(), ['noMoreBets', 'spinStart', 'spinStop', 'ding', 'coin', 'win']);
    await s.close();
  });

  testWidgets('a win of 360: no coin sound, but the win sound with the popup', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 80));
    await s.open();
    s.rig.provider.selectChip(Spin2WinChip.ten);
    s.rig.provider.tapNumber(7);
    await tester.pump();
    s.take();
    await _runTo(s, 99);
    expect(s.take(), ['noMoreBets', 'spinStart', 'spinStop', 'ding', 'win']);
    await s.close();
  });

  testWidgets('a loss or no bet: no coin and no win sound', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 80));
    await s.open();
    s.take();
    await _runTo(s, 99);
    expect(s.take(), ['noMoreBets', 'spinStart', 'spinStop', 'ding']);
    await s.close();
  });

  testWidgets('the SOUND button mutes Spin2Win: nothing plays, what plays stops, and it is remembered', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 80));
    await s.open();
    s.take();
    await s.tap('sound');
    expect(s.out.stops, 1, reason: 'muting stops what is playing');
    expect(s.take(), isEmpty, reason: 'the button\'s own click is muted too');
    expect(find.bySemanticsLabel('Sound off'), findsOneWidget);

    await s.tap('chip-10');
    await s.tap('card-3');
    await _runTo(s, 99);
    expect(s.take(), isEmpty);
    await s.close();

    // Spin2Win's mute stays for the next visit, until the app closes.
    final again = _Screen(tester, BetRig(tester, startInto: 40));
    await again.open();
    expect(find.bySemanticsLabel('Sound off'), findsOneWidget);
    await again.tap('sound');
    expect(again.take(), ['button']);
    await again.close();
  });

  testWidgets('leaving stops every sound and clears the in-game flag, muted or not', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40));
    await s.open();
    await s.tap('sound');
    final stops = s.out.stops;
    await s.close();
    expect(s.out.inGame, [true, false]);
    expect(s.out.stops, stops + 1);
  });

  testWidgets('the exit question and MY RECORDS open with the notification sound', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40));
    await s.open();
    s.take();
    await s.tap('exit');
    expect(s.take(), ['notification']);
    await tester.pump(const Duration(milliseconds: 500));
    await s.tap('exit-no');
    await tester.pump(const Duration(milliseconds: 500));
    s.take();
    await s.close();
  });
}
