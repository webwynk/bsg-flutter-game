// Tests for lib/services/lucky_card_sound.dart (the gate and the mute) and
// lib/services/lucky_card_sound_director.dart (the lock voice and the suit-rim ding), the
// second on the simulated server and the fake clock.

import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/services/lucky_card_round_sync.dart';
import 'package:best_smart_game/services/lucky_card_sound.dart';
import 'package:best_smart_game/services/lucky_card_sound_director.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_wallet.dart';
import 'provider_rig.dart';

/// Writes down every sound it is asked for.
class FakeOutput implements LuckyCardSoundOutput {
  final List<String> events = [];

  @override
  void buttonClick() => events.add('buttonClick');
  @override
  void chipClick() => events.add('chipClick');
  @override
  void numberSelect() => events.add('numberSelect');
  @override
  void ding() => events.add('ding');
  @override
  void notification() => events.add('notification');
  @override
  void win() => events.add('win');
  @override
  void coin() => events.add('coin');
  @override
  void noMoreBets() => events.add('noMoreBets');
  @override
  void setInGame(bool inGame) => events.add('inGame $inGame');
  @override
  void stopAll() => events.add('stopAll');
}

void main() {
  setUp(LuckyCardSound.resetMute);
  tearDown(LuckyCardSound.resetMute);

  group('the gate', () {
    test('every sound is passed on while it is not muted', () {
      final out = FakeOutput();
      LuckyCardSound(out)
        ..buttonClick()
        ..chipClick()
        ..numberSelect()
        ..ding()
        ..notification()
        ..win()
        ..coin()
        ..noMoreBets();
      expect(out.events, ['buttonClick', 'chipClick', 'numberSelect', 'ding', 'notification', 'win', 'coin', 'noMoreBets']);
    });

    test('muting stops whatever is playing and silences every sound', () {
      final out = FakeOutput();
      final sound = LuckyCardSound(out);
      expect(sound.muted, isFalse);
      sound.toggle();
      expect(sound.muted, isTrue);
      expect(out.events, ['stopAll']);
      sound
        ..buttonClick()
        ..chipClick()
        ..numberSelect()
        ..ding()
        ..notification()
        ..win()
        ..coin()
        ..noMoreBets();
      expect(out.events, ['stopAll'], reason: 'nothing else was played');
    });

    test('unmuting brings the sounds back, and does not stop anything', () {
      final out = FakeOutput();
      final sound = LuckyCardSound(out)..toggle();
      out.events.clear();
      sound.toggle();
      expect(sound.muted, isFalse);
      sound.win();
      expect(out.events, ['win']);
    });

    test('the choice is remembered by the next screen of the same run', () {
      final first = LuckyCardSound(FakeOutput())..toggle();
      final out = FakeOutput();
      final second = LuckyCardSound(out);
      expect(second.muted, isTrue);
      second.ding();
      expect(out.events, isEmpty);
      expect(first.muted, isTrue);
    });

    test('opening the game sets the in-game flag; leaving clears it and stops every sound, muted or not', () {
      final out = FakeOutput();
      final sound = LuckyCardSound(out);
      sound.enterGame();
      expect(out.events, ['inGame true']);
      out.events.clear();
      sound.leaveGame();
      expect(out.events, ['inGame false', 'stopAll']);

      out.events.clear();
      sound.toggle();
      out.events.clear();
      sound.enterGame();
      sound.leaveGame();
      expect(out.events, ['inGame true', 'inGame false', 'stopAll'], reason: 'the flag and the stop are not sounds');
    });

    test('stopAll stops at once', () {
      final out = FakeOutput();
      LuckyCardSound(out).stopAll();
      expect(out.events, ['stopAll']);
    });
  });

  group('the director', () {
    testWidgets('the lock gives the voice once, the card reveal gives the ding once, nothing else', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await rig.open();
      final director = LuckyCardSoundDirector(provider: rig.provider, sound: LuckyCardSound(out));
      rig.betTenOnEveryCard();

      await rig.world.runUntil(84.0);
      expect(out.events, isEmpty, reason: 'nothing while betting is open');
      await rig.world.runUntil(86.5);
      expect(out.events, ['noMoreBets'], reason: 'the voice, at the lock');
      await rig.world.runUntil(92.0);
      expect(out.events, ['noMoreBets'], reason: 'nothing while the wheel turns');
      await rig.world.runUntil(99.0);
      expect(out.events, ['noMoreBets', 'ding'], reason: 'the second ding, at the reveal');
      await rig.runIntoNextCycle(10);
      expect(out.events, ['noMoreBets', 'ding'], reason: 'the end of the round makes no sound');
      director.dispose();
      await rig.finish();
    });

    testWidgets('a screen that opens while betting is closed stays silent about the lock', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await rig.open();
      await rig.world.runUntil(87.0);
      expect(rig.provider.isLocked, isTrue);
      final director = LuckyCardSoundDirector(provider: rig.provider, sound: LuckyCardSound(out));
      await rig.world.runUntil(90.5);
      expect(out.events, isEmpty, reason: 'no voice for a late joiner');
      await rig.world.runUntil(99.0);
      expect(out.events, ['ding'], reason: 'but the reveal still dings');
      director.dispose();
      await rig.finish();
    });

    testWidgets('a screen that opens after the card was shown replays nothing', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await rig.open();
      await rig.world.runUntil(99.0);
      expect(rig.provider.cardRevealed, isTrue);
      final director = LuckyCardSoundDirector(provider: rig.provider, sound: LuckyCardSound(out));
      await rig.runIntoNextCycle(10);
      expect(out.events, isEmpty);
      director.dispose();
      await rig.finish();
    });

    testWidgets('muted, it makes no sound at all', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      final sound = LuckyCardSound(out)..toggle();
      out.events.clear();
      await rig.open();
      final director = LuckyCardSoundDirector(provider: rig.provider, sound: sound);
      await rig.world.runUntil(99.0);
      expect(out.events, isEmpty);
      director.dispose();
      await rig.finish();
    });

    testWidgets('after dispose it does not listen any more', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await rig.open();
      final director = LuckyCardSoundDirector(provider: rig.provider, sound: LuckyCardSound(out));
      director.dispose();
      await rig.world.runUntil(99.0);
      expect(out.events, isEmpty);
      await rig.finish();
    });

    testWidgets('each round sounds again: the lock and the reveal of the next round', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      await rig.open();
      final director = LuckyCardSoundDirector(provider: rig.provider, sound: LuckyCardSound(out));
      await rig.world.runUntil(99.0);
      await rig.runIntoNextCycle(10);
      out.events.clear();
      await rig.world.runUntil(99.0);
      expect(out.events, ['noMoreBets', 'ding']);
      director.dispose();
      await rig.finish();
    });

    testWidgets('it does not need a screen: the provider can be any provider', (tester) async {
      final rig = BetRig(tester);
      final probe = LuckyCardProvider(
        api: rig.server,
        wallet: FakeWallet(1000),
        sync: LuckyCardRoundSync(api: rig.server, now: () => rig.world.deviceNow),
        now: () => rig.world.deviceNow,
      );
      final out = FakeOutput();
      final director = LuckyCardSoundDirector(provider: probe, sound: LuckyCardSound(out));
      expect(out.events, isEmpty);
      director.dispose();
      probe.dispose();
      await rig.finish();
    });
  });
}
