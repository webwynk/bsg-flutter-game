// Tests for the Lucky 16 Card screen when the app goes to the background and comes back, on the real
// screen (lib/screens/lucky16_screen.dart) over the simulated server. Copied from the "app goes to the
// background" group of test/lucky_card/ui/lucky_card_screen_test.dart, with the cases of a bet still open,
// a late bet the server refuses, and no double send.

import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/screens/lucky16_screen.dart';
import 'package:best_smart_game/services/lucky16_sound.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lucky16_sound_test.dart' show FakeOutput;
import '../provider_rig.dart';
import 'lucky16_board_test.dart' show loadArt, tapPiece;
import 'lucky16_screen_test.dart' show key, openGame, settle, textIn;
import 'ui_harness.dart';

void away(WidgetTester tester) => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

Future<void> back(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

/// A round sync whose tick is slow, to stand for a phone whose timers stood still while it was away,
/// with betting still open and 10 on each heart on the board.
Future<BetRig> frozenClockWithBet(WidgetTester tester) async {
  final rig = BetRig(tester, startInto: 80, tickInterval: const Duration(seconds: 30));
  await openGame(tester, rig);
  await tester.tap(key('chip-10'));
  await tester.tap(key('suit-hearts'));
  await tester.pump();
  expect(rig.provider.total, 40);
  expect(rig.provider.countdown, greaterThan(5), reason: 'betting is still open when the phone goes away');
  return rig;
}

void main() {
  setUpAll(() async {
    await loadLucky16Fonts();
    await loadLucky16Icons();
  });

  setUp(Lucky16Sound.resetMute);
  tearDown(Lucky16Sound.resetMute);

  testWidgets('a short absence changes nothing: the screen keeps running and the lock still comes', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    away(tester);
    await rig.world.run(const Duration(seconds: 5));
    await back(tester);
    await rig.world.runUntil(86.0);
    await settle(tester);
    expect(rig.provider.isLocked, isTrue, reason: 'the round sync is still running');
    expect(find.byType(Lucky16Wheel), findsOneWidget);
    await rig.finish();
  });

  testWidgets('a bet with betting still open waits for the lock as usual, and is sent once', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    await tapPiece(tester, 'chip-10');
    await tapPiece(tester, 'suit-hearts');
    away(tester);
    await rig.world.run(const Duration(seconds: 3));
    await back(tester);
    expect(rig.provider.isLocked, isFalse);
    expect(rig.server.betLog, isEmpty, reason: 'the player can still change the bet');
    expect(rig.provider.total, 40, reason: 'the chips are still on the board');
    await rig.world.runUntil(87.0);
    expect(rig.server.betLog.length, 1);
    await rig.finish();
  });

  testWidgets('after a short absence that crossed the lock, the bet is sent at once, and only once', (tester) async {
    await loadArt(tester);
    final rig = await frozenClockWithBet(tester);
    away(tester);
    await rig.world.run(const Duration(seconds: 3));
    expect(rig.provider.countdown, lessThanOrEqualTo(5), reason: 'the lock mark went by while it was away');
    expect(rig.server.betLog, isEmpty, reason: 'and nothing sent the bet');
    await back(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(rig.server.betLog.length, 1, reason: 'the late bet went to the server on the way back');
    // A second return, and the round going on, never send it again.
    away(tester);
    await rig.world.run(const Duration(seconds: 1));
    await back(tester);
    await rig.world.run(const Duration(seconds: 2));
    expect(rig.server.betLog.length, 1, reason: 'no double send');
    await rig.finish();
  });

  testWidgets('a late bet the server refuses: ROUND CLOSED, the chips back, the player stays', (tester) async {
    await loadArt(tester);
    final rig = await frozenClockWithBet(tester);
    rig.server.failBetsNext(5, error: Lucky16Error.roundClosed);
    away(tester);
    await rig.world.run(const Duration(seconds: 3));
    await back(tester);
    await rig.world.run(const Duration(seconds: 2));
    await settle(tester);
    expect(find.text('ROUND CLOSED'), findsOneWidget);
    expect(textIn(tester, 'top-balance'), '1,000', reason: 'the chips went back on screen');
    expect(find.byType(Lucky16Screen), findsOneWidget);
    await rig.finish();
  });

  testWidgets('a return with an empty board sends nothing', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester, startInto: 80, tickInterval: const Duration(seconds: 30));
    await openGame(tester, rig);
    away(tester);
    await rig.world.run(const Duration(seconds: 3));
    await back(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(rig.server.betLog, isEmpty);
    await rig.finish();
  });

  testWidgets('after 20 seconds or more the screen stops: chips back, sounds stopped, nothing runs or answers',
      (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    final out = FakeOutput();
    await openGame(tester, rig, sound: Lucky16Sound(out));
    await tapPiece(tester, 'chip-10');
    await tapPiece(tester, 'suit-hearts');
    expect(rig.wallet.balance, 960);

    away(tester);
    await rig.world.run(const Duration(seconds: 21));
    out.events.clear();
    await back(tester);
    expect(out.events, contains('stopAll'), reason: 'every sound stops');
    expect(rig.provider.isBoardEmpty, isTrue, reason: 'the unsent chips were given back');
    expect(rig.wallet.balance, 1000);
    await rig.world.runUntil(88.0);
    expect(rig.provider.isLocked, isFalse, reason: 'the round sync is stopped: the lock never comes');
    expect(rig.server.betLog, isEmpty);

    // The screen is dimmed and nothing on it answers (the shared popup logs the player out).
    await tester.tap(key('top-exit'), warnIfMissed: false);
    await settle(tester);
    expect(key('exit-dialog'), findsNothing);
    await rig.finish();
  });

  testWidgets('a screen that has stopped itself raises no connection dialog', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    away(tester);
    await rig.world.run(const Duration(seconds: 21));
    await back(tester);
    rig.server.offline = true;
    await rig.world.run(const Duration(seconds: 15));
    await settle(tester);
    expect(find.text('CONNECTION LOST'), findsNothing);
    await rig.finish();
  });

  testWidgets('an absence that ended long ago is forgotten: a later short one does not stop the screen',
      (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    away(tester);
    await rig.world.run(const Duration(seconds: 5));
    await back(tester);
    await rig.world.run(const Duration(seconds: 25));
    away(tester);
    await rig.world.run(const Duration(seconds: 2));
    await back(tester);
    await rig.world.runUntil(86.0);
    await settle(tester);
    expect(rig.provider.isLocked, isTrue, reason: 'the screen is still running, not stopped');
    await rig.finish();
  });

  testWidgets('a second absence after the screen stopped does nothing more', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    for (var i = 0; i < 2; i++) {
      away(tester);
      await rig.world.run(const Duration(seconds: 21));
      await back(tester);
    }
    expect(tester.takeException(), isNull);
    await rig.finish();
  });
}
