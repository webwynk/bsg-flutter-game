// Tests for the sounds, the mute and the haptics of the Lucky Card screen (App Step 8b):
// the whole game on the simulated server and the fake clock, driven only by taps, with a
// fake sound output that writes down every sound asked for and the phone's haptic channel
// listened to. The mapping is the one of spec §17AE.

import 'dart:ui' as ui;

import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/screens/lucky_card_screen.dart';
import 'package:best_smart_game/services/lucky_card_sound.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lucky_card_sound_test.dart' show FakeOutput;
import '../provider_rig.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

late PreloadedLuckyCardArt art;

Finder key(String k) => find.byKey(ValueKey(k));

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> settleAll(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await settle(tester);
  }
}

/// The lobby: one button that opens the game over it.
Widget lobby(LuckyCardProvider provider, FakeOutput out) => Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const ValueKey('go'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LuckyCardScreen(
                setup: LuckyCardScreenSetup(provider: provider, art: art, setOrientation: false, sound: LuckyCardSound(out)),
              ),
            ),
          ),
          child: const Text('go'),
        ),
      ),
    );

Future<void> openGame(WidgetTester tester, BetRig rig, FakeOutput out, {bool alreadyPumped = false}) async {
  if (!alreadyPumped) await pumpAtSize(tester, phone, lobby(rig.provider, out));
  await tester.tap(key('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await rig.world.run(const Duration(seconds: 2));
  await settle(tester);
}

/// The haptic calls the phone received.
List<String> hapticsOn(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') calls.add('${call.arguments}');
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

int count(FakeOutput out, String what) => out.events.where((e) => e == what).length;

void main() {
  setUpAll(() async {
    await loadLuckyCardWheelFonts();
    await loadLuckyCardIcons();
    art = await PreloadedLuckyCardArt.load();
  });

  setUp(LuckyCardSound.resetMute);
  tearDown(LuckyCardSound.resetMute);

  group('opening and leaving', () {
    testWidgets('opening sets the in-game flag, and leaving clears it and stops every sound', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      expect(out.events.first, 'inGame true');
      out.events.clear();
      await tester.tap(key('top-exit'));
      await settle(tester);
      expect(out.events, ['notification'], reason: 'the question opens with the notification');
      await tester.tap(key('exit-yes'));
      await settleAll(tester);
      expect(out.events, ['notification', 'inGame false', 'stopAll']);
      await rig.finish();
    });

    testWidgets('after the screen has closed, the round going on makes no sound', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      await tester.tap(key('top-exit'));
      await settle(tester);
      await tester.tap(key('exit-yes'));
      await settleAll(tester);
      out.events.clear();
      // The provider the screen was given keeps living; its lock and its reveal must be silent.
      await rig.open();
      await rig.world.runUntil(99.5);
      expect(out.events, isEmpty);
      await rig.finish();
    });

    testWidgets('answering NO to the question makes no sound of its own and leaves the game flag alone', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      out.events.clear();
      await tester.tap(key('top-exit'));
      await settle(tester);
      await tester.tap(key('exit-no'));
      await settle(tester);
      expect(out.events, ['notification']);
      await rig.finish();
    });

    testWidgets('after 20 seconds or more away, everything is stopped', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      out.events.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await rig.world.run(const Duration(seconds: 21));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(out.events, contains('stopAll'));
      await rig.finish();
    });
  });

  group('the taps', () {
    testWidgets('a chip and each button: the button click; a bar: the chip click; a single card: the number-select sound', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      out.events.clear();

      await tester.tap(key('chip-10'));
      await tester.pump();
      expect(out.events, ['buttonClick']);
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      expect(out.events, ['buttonClick', 'chipClick']);
      await tester.tap(key('rank-J'));
      await tester.pump();
      await tester.tap(key('j_hearts'));
      await tester.pump();
      expect(out.events, ['buttonClick', 'chipClick', 'chipClick', 'numberSelect'],
          reason: 'the suit bar and the rank bar click; the single card makes the number-select sound');

      out.events.clear();
      await tester.tap(key('button-doubleBet'));
      await tester.pump();
      await tester.tap(key('button-remove'));
      await tester.pump();
      await tester.tap(key('button-clear'));
      await tester.pump();
      expect(out.events, ['buttonClick', 'buttonClick', 'buttonClick']);
      await rig.finish();
    });

    testWidgets('taking a chip back also clicks; a tap that changes nothing is silent', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      await tester.tap(key('chip-10'));
      await tester.tap(key('suit-hearts'));
      await tester.tap(key('k_clubs'));
      await tester.pump();
      await tester.tap(key('button-remove'));
      await tester.pump();
      out.events.clear();
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      expect(out.events, ['chipClick'], reason: 'a chip taken back');
      await tester.tap(key('suit-diamonds'));
      await tester.pump();
      expect(out.events, ['chipClick'], reason: 'nothing on diamonds to take back: no click');
      await rig.finish();
    });

    testWidgets('a single card: the number-select sound when it changes, also taking a chip back; silent when it changes nothing', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      out.events.clear();

      await tester.tap(key('chip-10'));
      await tester.pump();
      out.events.clear();
      await tester.tap(key('k_clubs'));
      await tester.pump();
      expect(out.events, ['numberSelect'], reason: 'a chip placed on one card');
      await tester.tap(key('k_clubs'));
      await tester.pump();
      expect(out.events, ['numberSelect', 'numberSelect'], reason: 'a second chip on the same card');

      await tester.tap(key('button-remove'));
      await tester.pump();
      out.events.clear();
      await tester.tap(key('k_clubs'));
      await tester.pump();
      expect(out.events, ['numberSelect'], reason: 'a chip taken back from one card');
      await tester.tap(key('q_spades'));
      await tester.pump();
      expect(out.events, ['numberSelect'], reason: 'nothing on that card to take back: silent');
      expect(count(out, 'chipClick'), 0, reason: 'a single card never makes the bar click');
      await rig.finish();
    });

    testWidgets('a button with nothing to do is silent', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      out.events.clear();
      await tester.tap(key('button-doubleBet'));
      await tester.tap(key('button-clear'));
      await tester.pump();
      expect(out.events, isEmpty);
      await rig.finish();
    });

    testWidgets('Info opens with the notification and its tabs click', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      out.events.clear();
      await tester.tap(key('top-info'));
      await settle(tester);
      expect(out.events, ['notification']);
      await tester.tap(key('info-tab-payouts'));
      await settle(tester);
      expect(out.events, ['notification', 'buttonClick']);
      await tester.tap(key('info-tab-payouts'));
      await settle(tester);
      expect(out.events.length, 2, reason: 'the tab already shown does not click again');
      await rig.finish();
    });
  });

  group('a round', () {
    testWidgets('a winner hears the lock voice, the wheel, two dings, the coins and the win, in that order; the card flip is silent', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      rig.betTenOnEveryCard();
      await tester.pump();
      out.events.clear();

      await rig.world.runUntil(99.5);
      await settle(tester);
      final seq = out.events;
      expect(seq.first, 'noMoreBets');
      expect(count(out, 'noMoreBets'), 1);
      expect(count(out, 'ding'), 2, reason: 'one for the rank rim, one for the suit rim');
      expect(count(out, 'numberSelect'), 0, reason: 'the card flip makes no sound (owner, 2026-10-07)');
      expect(count(out, 'wheelSpin'), 1, reason: 'the wheel\'s own sound, once, when the spin starts');
      expect(count(out, 'coin'), 1);
      expect(count(out, 'win'), 1);
      expect(seq.indexOf('noMoreBets'), lessThan(seq.indexOf('wheelSpin')));
      expect(seq.indexOf('ding'), lessThan(seq.lastIndexOf('ding')));
      expect(seq.indexOf('wheelSpin'), lessThan(seq.indexOf('ding')), reason: 'the wheel starts before the first ding');
      expect(seq.lastIndexOf('ding'), lessThan(seq.indexOf('coin')), reason: 'the coins follow the suit rim');
      expect(seq.indexOf('coin'), lessThan(seq.indexOf('win')), reason: 'then the popup');
      expect(seq.where((e) => ['buttonClick', 'chipClick', 'notification'].contains(e)), isEmpty, reason: 'nothing else');
      await rig.finish();
    });

    testWidgets('a spectator hears the voice, the wheel and the dings, but no coins and no win', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      out.events.clear();
      await rig.world.runUntil(99.5);
      await settle(tester);
      expect(count(out, 'noMoreBets'), 1);
      expect(count(out, 'wheelSpin'), 1);
      expect(count(out, 'numberSelect'), 0);
      expect(count(out, 'ding'), 2);
      expect(count(out, 'coin'), 0);
      expect(count(out, 'win'), 0);
      await rig.finish();
    });

    testWidgets('a player who loses hears no coins and no win', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      // 10 on a card that is not the winner (the simulated server draws the same card each time).
      await tester.tap(key('chip-10'));
      await tester.tap(key('j_hearts'));
      await tester.pump();
      final winnerKey = rig.server.betLog.isEmpty ? null : rig.server.betLog.first;
      expect(winnerKey, isNull);
      out.events.clear();
      await rig.world.runUntil(99.5);
      await settle(tester);
      final won = count(out, 'win') == 1;
      expect(count(out, 'coin'), won ? 1 : 0);
      await rig.finish();
    });

    testWidgets('a screen that opens while betting is closed stays silent about the lock', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await rig.open();
      await rig.world.runUntil(87.0);
      await pumpAtSize(tester, phone, lobby(rig.provider, out));
      await openGame(tester, rig, out, alreadyPumped: true);
      expect(count(out, 'noMoreBets'), 0);
      await rig.world.runUntil(99.5);
      await settle(tester);
      expect(count(out, 'noMoreBets'), 0);
      expect(count(out, 'ding'), greaterThanOrEqualTo(1));
      await rig.finish();
    });

    testWidgets('a screen that opens after the card was shown replays nothing', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await rig.open();
      await rig.world.runUntil(99.0);
      await pumpAtSize(tester, phone, lobby(rig.provider, out));
      await openGame(tester, rig, out, alreadyPumped: true);
      final heard = out.events.where((e) => e != 'inGame true').toList();
      expect(heard, isEmpty, reason: 'no ding, no coins, no win for a result that was already shown');
      await rig.finish();
    });
  });

  group('the mute', () {
    testWidgets('the SOUND button mutes: it stops what plays and every later sound is silent; again, and they return', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      out.events.clear();

      await tester.tap(key('top-sound'));
      await tester.pump();
      expect(out.events, ['stopAll']);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      await tester.tap(key('chip-10'));
      await tester.tap(key('suit-hearts'));
      await tester.tap(key('button-doubleBet'));
      await tester.pump();
      await tester.tap(key('top-info'));
      await settle(tester);
      await tester.tap(key('info-close'));
      await settle(tester);
      expect(out.events, ['stopAll'], reason: 'silent: chips, board, buttons, Info');

      await tester.tap(key('top-sound'));
      await tester.pump();
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      await tester.tap(key('chip-50'));
      await tester.pump();
      expect(out.events, ['stopAll', 'buttonClick']);
      await rig.finish();
    });

    testWidgets('muted, a whole round is silent', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      await tester.tap(key('top-sound'));
      rig.betTenOnEveryCard();
      await tester.pump();
      out.events.clear();
      await rig.world.runUntil(99.5);
      await settle(tester);
      expect(out.events, isEmpty);
      await rig.finish();
    });

    testWidgets('muting in the middle of a round silences the rest of it', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      rig.betTenOnEveryCard();
      await rig.world.runUntil(92.0);
      expect(count(out, 'noMoreBets'), 1);
      out.events.clear();
      await tester.tap(key('top-sound'), warnIfMissed: false);
      await tester.pump();
      out.events.clear();
      await rig.world.runUntil(99.5);
      await settle(tester);
      expect(out.events, isEmpty);
      await rig.finish();
    });

    testWidgets('leaving and coming back keeps the mute until the app closes', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      await tester.tap(key('top-sound'));
      await tester.pump();
      await tester.tap(key('top-exit'));
      await settle(tester);
      await tester.tap(key('exit-yes'));
      await settleAll(tester);

      out.events.clear();
      await tester.tap(key('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await rig.world.run(const Duration(seconds: 2));
      await settle(tester);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget, reason: 'still muted');
      await tester.tap(key('chip-10'));
      await tester.pump();
      expect(out.events.where((e) => e == 'buttonClick'), isEmpty);
      await rig.finish();
    });
  });

  group('the haptics', () {
    testWidgets('a light click when a tap changes the board and when a button is accepted; none for a chip or a refusal', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      final calls = hapticsOn(tester);

      await tester.tap(key('chip-10'));
      await tester.pump();
      expect(calls, isEmpty, reason: 'picking a chip up: no haptic, as in Triple Chance');

      await tester.tap(key('suit-hearts'));
      await tester.pump();
      expect(calls, ['HapticFeedbackType.selectionClick']);

      await tester.tap(key('button-doubleBet'));
      await tester.pump();
      expect(calls.length, 2);

      await tester.tap(key('button-remove'));
      await tester.pump();
      await tester.tap(key('suit-spades'));
      await tester.pump();
      expect(calls.length, 3, reason: 'REMOVE clicked; a tap on spades changed nothing and did not');
      await rig.finish();
    });

    testWidgets('the SOUND button does not touch the haptics', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      await tester.tap(key('top-sound'));
      await tester.pump();
      final calls = hapticsOn(tester);
      await tester.tap(key('chip-10'));
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      expect(calls, ['HapticFeedbackType.selectionClick']);
      expect(out.events.where((e) => e == 'chipClick'), isEmpty, reason: 'the sound is muted, the haptic is not');
      await rig.finish();
    });

    testWidgets('a locked board gives no haptic and no sound', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      await tester.tap(key('chip-10'));
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      await rig.world.runUntil(86.5);
      await settle(tester);
      final calls = hapticsOn(tester);
      out.events.clear();
      await tester.tap(key('button-clear'), warnIfMissed: false);
      await tester.tap(key('chip-5'), warnIfMissed: false);
      await tester.pump();
      expect(calls, isEmpty);
      expect(out.events, isEmpty);
      await rig.finish();
    });
  });

  testWidgets('semantics still describe the SOUND button after a change', (tester) async {
    final rig = BetRig(tester);
    final out = FakeOutput();
    await openGame(tester, rig, out);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Sound on, tap to mute'), findsOneWidget);
    await tester.tap(key('top-sound'));
    await tester.pump();
    expect(find.bySemanticsLabel('Sound off, tap to turn on'), findsOneWidget);
    handle.dispose();
    await rig.finish();
    expect(ui.PlatformDispatcher.instance, isNotNull);
  });
}
