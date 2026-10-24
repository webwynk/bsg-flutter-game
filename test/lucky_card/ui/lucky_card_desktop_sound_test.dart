// Tests for the sounds on the DESKTOP screen (desktop step D2, spec §17BP): the same mapping as the
// phone's (spec §17AE, lucky_card_screen_sound_test.dart), proven again on the real screen with the
// desktop arrangement on, where the wheel is built before any spin and stays on screen between rounds.
// A fake sound output writes down every sound asked for.

import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/screens/lucky_card_screen.dart';
import 'package:best_smart_game/services/lucky_card_sound.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_desktop_pieces.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lucky_card_sound_test.dart' show FakeOutput;
import '../provider_rig.dart';
import 'ui_harness.dart';

const Size desktop = Size(1920, 1080);

late PreloadedLuckyCardArt art;

Finder key(String k) => find.byKey(ValueKey(k));

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Widget lobby(LuckyCardProvider provider, FakeOutput out) => Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const ValueKey('go'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LuckyCardScreen(
                setup: LuckyCardScreenSetup(
                  provider: provider,
                  art: art,
                  setOrientation: false,
                  sound: LuckyCardSound(out),
                  desktopPlatform: true,
                ),
              ),
            ),
          ),
          child: const Text('go'),
        ),
      ),
    );

Future<void> openGame(WidgetTester tester, BetRig rig, FakeOutput out, {bool alreadyPumped = false}) async {
  if (!alreadyPumped) await pumpAtSize(tester, desktop, lobby(rig.provider, out));
  await tester.tap(key('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await rig.world.run(const Duration(seconds: 2));
  await settle(tester);
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

  group('a round on the desktop screen', () {
    testWidgets('a winner hears the lock voice, the wheel, two dings, the coins and the win, in that order', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      expect(find.byType(LuckyCardDesktopSide), findsOneWidget, reason: 'this is the desktop screen');
      rig.betTenOnEveryCard();
      await tester.pump();
      out.events.clear();

      await rig.world.runUntil(99.5);
      await settle(tester);
      final seq = out.events;
      expect(seq.first, 'noMoreBets');
      expect(count(out, 'noMoreBets'), 1);
      expect(count(out, 'wheelSpin'), 1, reason: "the wheel's own sound, once, when the spin starts");
      expect(count(out, 'ding'), 2, reason: 'one for the rank rim, one for the suit rim');
      expect(count(out, 'numberSelect'), 0, reason: 'no card flips on the desktop');
      expect(count(out, 'coin'), 1);
      expect(count(out, 'win'), 1);
      expect(seq.indexOf('noMoreBets'), lessThan(seq.indexOf('wheelSpin')));
      expect(seq.indexOf('wheelSpin'), lessThan(seq.indexOf('ding')), reason: 'the wheel starts before the first ding');
      expect(seq.indexOf('ding'), lessThan(seq.lastIndexOf('ding')));
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
      expect(count(out, 'ding'), 2);
      expect(count(out, 'coin'), 0);
      expect(count(out, 'win'), 0);
      await rig.finish();
    });

    testWidgets('the same wheel plays its sound again in the NEXT round: one spin sound and two dings each', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      out.events.clear();
      await rig.world.runUntil(99.5);
      await settle(tester);
      expect(count(out, 'wheelSpin'), 1);
      expect(count(out, 'ding'), 2);
      await rig.runIntoNextCycle(8);
      await settle(tester);
      expect(rig.provider.isLocked, isFalse, reason: 'betting is open again');
      out.events.clear();
      await rig.world.runUntil(99.5);
      await settle(tester);
      expect(count(out, 'noMoreBets'), 1);
      expect(count(out, 'wheelSpin'), 1, reason: 'a permanent wheel still plays its sound every round');
      expect(count(out, 'ding'), 2);
      await rig.finish();
    });

    testWidgets('a screen that opens while betting is closed stays silent about the lock, and the wheel still dings', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await rig.open();
      await rig.world.runUntil(87.0);
      await pumpAtSize(tester, desktop, lobby(rig.provider, out));
      await openGame(tester, rig, out, alreadyPumped: true);
      expect(count(out, 'noMoreBets'), 0);
      await rig.world.runUntil(99.5);
      await settle(tester);
      expect(count(out, 'noMoreBets'), 0);
      expect(count(out, 'ding'), greaterThanOrEqualTo(1));
      await rig.finish();
    });

    testWidgets('a screen that opens after the result was shown replays nothing', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await rig.open();
      await rig.world.runUntil(99.0);
      await pumpAtSize(tester, desktop, lobby(rig.provider, out));
      await openGame(tester, rig, out, alreadyPumped: true);
      final heard = out.events.where((e) => e != 'inGame true').toList();
      expect(heard, isEmpty, reason: 'no ding, no coins, no win for a result that was already shown');
      await rig.finish();
    });
  });

  group('the taps in the bottom bar and on the board', () {
    testWidgets('a chip and each button: the button click; a single card: the number-select sound; a suit bar: the chip click', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      final l = LuckyCardLayout.of(desktop, desktopPlatform: true);
      out.events.clear();
      await tester.tapAt(l.chip(1).center);
      await tester.pump();
      expect(out.events, ['buttonClick'], reason: 'a chip');
      out.events.clear();
      await tester.tapAt(l.cardCell(0, 0).center);
      await tester.pump();
      expect(out.events, ['numberSelect'], reason: 'a single card');
      out.events.clear();
      await tester.tapAt(l.suitHeader(1).center);
      await tester.pump();
      expect(out.events, ['chipClick'], reason: 'a suit bar');
      out.events.clear();
      await tester.tapAt(l.actionButton(0).center);
      await tester.pump();
      expect(out.events, ['buttonClick'], reason: 'DOUBLE');
      out.events.clear();
      await tester.tapAt(l.actionButton(1).center);
      await tester.pump();
      expect(out.events, ['buttonClick'], reason: 'CLEAR');
      await rig.finish();
    });

    testWidgets('a locked board and locked buttons make no sound', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, out);
      final l = LuckyCardLayout.of(desktop, desktopPlatform: true);
      await rig.world.runUntil(90.5);
      await settle(tester);
      expect(rig.provider.isLocked, isTrue);
      out.events.clear();
      await tester.tapAt(l.chip(1).center);
      await tester.tapAt(l.cardCell(0, 0).center);
      await tester.tapAt(l.suitHeader(1).center);
      await tester.tapAt(l.actionButton(0).center);
      await tester.pump();
      expect(out.events.where((e) => ['buttonClick', 'chipClick', 'numberSelect'].contains(e)), isEmpty);
      await rig.finish();
    });
  });

  group('the mute on the desktop screen', () {
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
  });
}
