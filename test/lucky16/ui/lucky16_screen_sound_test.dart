// Tests for the Lucky 16 Card screen's sounds, mute and messages (phone phase 7), on the real screen
// (lib/screens/lucky16_screen.dart) over the simulated server, with a stand-in that writes down every
// sound asked for. The mute is Lucky 16 Card's own: muting it changes no other game's. Golden pictures of
// the SOUND ball muted are copied to reference-design/lucky16/screenshots/phase7/.

import 'package:best_smart_game/models/lucky16_board.dart';
import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/services/lucky16_sound.dart';
import 'package:best_smart_game/services/lucky_card_sound.dart';
import 'package:best_smart_game/services/spin2win_sound.dart';
import 'package:best_smart_game/utils/app_exit.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lucky16_sound_test.dart' show FakeOutput;
import '../provider_rig.dart';
import 'lucky16_board_test.dart' show loadArt, tapPiece;
import 'lucky16_screen_test.dart' show key, openGame, settle, textIn;
import 'lucky16_win_test.dart' show aceClubs, aceHearts;
import 'ui_harness.dart';

Finder get _words => find.descendant(of: key('top-status'), matching: find.byType(Text));

String statusText(WidgetTester tester) => tester.widget<Text>(_words).data!;

Color statusColor(WidgetTester tester) => tester.widget<Text>(_words).style!.color!;

/// Runs the round on, a fifth of a second at a time, until [done].
Future<void> runUntil(BetRig rig, bool Function() done) async {
  var guard = 0;
  while (!done() && ++guard < 2000) {
    await rig.world.run(const Duration(milliseconds: 200));
  }
  expect(done(), isTrue, reason: 'the round got there');
}

/// Bets on a card, then runs on until the bet has been sent and answered (past the lock).
Future<void> betAndRunPastLock(WidgetTester tester, BetRig rig) async {
  await tester.tap(key(aceHearts.key));
  await tester.pump();
  await runUntil(rig, () => rig.provider.isLocked);
  await rig.world.run(const Duration(seconds: 2));
  await settle(tester);
}

void main() {
  setUpAll(() async {
    await loadLucky16Fonts();
    await loadLucky16Icons();
    await warmUpSharedSounds();
  });

  setUp(() {
    Lucky16Sound.resetMute();
    isClosingApp.value = false;
  });
  tearDown(() {
    Lucky16Sound.resetMute();
    isClosingApp.value = false;
  });

  group('the mute', () {
    test('muting Lucky 16 Card changes no other game\'s mute, and theirs change nothing here', () {
      LuckyCardSound.resetMute();
      Spin2WinSound.resetMute();
      final lucky16 = Lucky16Sound(FakeOutput());
      lucky16.toggle();
      expect(lucky16.muted, isTrue);
      expect(LuckyCardSound().muted, isFalse);
      expect(Spin2WinSound().muted, isFalse);
      lucky16.toggle();
      LuckyCardSound.resetMute();
      final other = LuckyCardSound(_NoLuckyCardOutput());
      other.toggle();
      expect(other.muted, isTrue);
      expect(lucky16.muted, isFalse);
      LuckyCardSound.resetMute();
    });

    testWidgets('the SOUND ball mutes and unmutes, shows it, and muted means silent', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, sound: Lucky16Sound(out));
      expect(find.descendant(of: key('top-sound'), matching: find.byIcon(Icons.volume_up_rounded)), findsOneWidget);
      await tapPiece(tester, 'top-sound');
      expect(find.descendant(of: key('top-sound'), matching: find.byIcon(Icons.volume_off_rounded)), findsOneWidget);
      expect(out.events, contains('stopAll'), reason: 'muting stops what is playing');
      out.events.clear();
      await tapPiece(tester, aceHearts.key);
      await tapPiece(tester, 'chip-10');
      expect(out.events, isEmpty);
      await tapPiece(tester, 'top-sound');
      await tapPiece(tester, aceHearts.key);
      expect(out.events, ['numberSelect']);
      await rig.finish();
    });
  });

  group('the sounds', () {
    testWidgets('opening and leaving set the in-game flag; leaving stops every sound', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, sound: Lucky16Sound(out));
      expect(out.events, contains('inGame true'));
      await tapPiece(tester, 'top-exit');
      await tester.tap(key('exit-yes'));
      for (var i = 0; i < 4; i++) {
        await settle(tester);
      }
      expect(out.events, containsAllInOrder(['inGame false', 'stopAll']));
      await rig.finish();
    });

    testWidgets('a card, a bar, a selector, a chip, a button and a popup each make their sound', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, sound: Lucky16Sound(out));
      out.events.clear();
      await tapPiece(tester, 'chip-10');
      expect(out.events, ['buttonClick']);
      out.events.clear();
      await tapPiece(tester, aceHearts.key);
      expect(out.events, ['numberSelect']);
      out.events.clear();
      await tapPiece(tester, 'suit-spades');
      await tapPiece(tester, 'rank-K');
      expect(out.events, ['chipClick', 'chipClick']);
      out.events.clear();
      await tapPiece(tester, 'button-doubleBet');
      expect(out.events, ['buttonClick']);
      out.events.clear();
      await tapPiece(tester, 'top-info');
      expect(out.events, ['notification']);
      await tapPiece(tester, 'info-tab-payouts');
      expect(out.events, ['notification', 'buttonClick']);
      await tapPiece(tester, 'info-close');
      out.events.clear();
      await tapPiece(tester, 'top-exit');
      expect(out.events, ['notification']);
      await tapPiece(tester, 'exit-no');
      await rig.finish();
    });

    testWidgets('a winning round: no more bets, the spin, ding, ding, the coins, then the win', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, sound: Lucky16Sound(out));
      await tapPiece(tester, 'chip-10');
      await tapPiece(tester, aceClubs.key);
      out.events.clear();
      await runUntil(rig, () => rig.provider.popup != null);
      await tester.pump();
      expect(out.events, ['noMoreBets', 'wheelSpin', 'ding', 'ding', 'coin', 'win']);
      await rig.finish();
    });

    testWidgets('a losing round: the same, without the coins and the win', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final out = FakeOutput();
      await openGame(tester, rig, sound: Lucky16Sound(out));
      await tapPiece(tester, aceHearts.key);
      out.events.clear();
      await runUntil(rig, () => rig.provider.cardRevealed);
      await rig.world.run(const Duration(seconds: 3));
      expect(out.events, ['noMoreBets', 'wheelSpin', 'ding', 'ding']);
      await rig.finish();
    });
  });

  group('the messages', () {
    testWidgets('too few coins for a chip: the shared dialog, and the amber line in the header', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester, startBalance: 5);
      await openGame(tester, rig);
      await tapPiece(tester, 'chip-10');
      await tester.tap(key(aceHearts.key));
      await tester.pump();
      expect(statusText(tester), 'NOT ENOUGH COINS');
      expect(statusColor(tester), kLucky16NoticeText);
      expect(rig.provider.stakeOn(aceHearts), 0);
      await settle(tester);
      expect(find.text('INSUFFICIENT COINS'), findsOneWidget, reason: 'showInsufficientCoinsDialog');
      await rig.finish();
    });

    testWidgets('a card at 10,000: the limit banner says so, and the header keeps its words', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester, startBalance: 50000);
      await openGame(tester, rig);
      await tapPiece(tester, 'chip-500');
      for (var i = 0; i < 20; i++) {
        await tapPiece(tester, aceHearts.key);
      }
      await tapPiece(tester, aceHearts.key);
      expect(key('limit-snackbar'), findsOneWidget);
      expect(find.text('CARD PLAY LIMIT REACHED'), findsOneWidget);
      expect(find.text('Max ${10000 ~/ 1000},000 / card'), findsOneWidget);
      expect(kLucky16MaxStake, 10000);
      expect(statusText(tester), 'PLACE YOUR CHIPS');
      await rig.finish();
    });

    testWidgets('taking back from an empty card says so, and the line goes after 2 seconds', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await tapPiece(tester, 'rank-K');
      await tapPiece(tester, 'button-remove');
      await tester.tap(key(aceHearts.key));
      await tester.pump();
      expect(statusText(tester), 'NOTHING TO TAKE BACK');
      await rig.world.run(const Duration(milliseconds: 2200));
      await tester.pump();
      expect(statusText(tester), 'PLACE YOUR CHIPS');
      await rig.finish();
    });

    for (final e in {
      Lucky16Error.roundClosed: 'ROUND CLOSED',
      Lucky16Error.notAPlayer: 'ACCOUNT NOT ELIGIBLE',
      Lucky16Error.belowMin: 'BET NOT PLACED',
    }.entries) {
      testWidgets('a bet the server refuses (${e.key.name}): ${e.value}, the chips back, it closes by itself',
          (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        var ended = 0;
        await openGame(tester, rig, endSession: () async => ended++);
        rig.server.failBetsNext(5, error: e.key);
        await betAndRunPastLock(tester, rig);
        expect(find.text(e.value), findsOneWidget);
        expect(textIn(tester, 'top-balance'), '1,000');
        await rig.world.run(const Duration(seconds: 5, milliseconds: 600));
        await settle(tester);
        expect(find.text(e.value), findsNothing);
        expect(ended, 0);
        await rig.finish();
      });
    }

    testWidgets('the server going silent: one CONNECTION LOST; OK gives the chips back and ends the session',
        (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      var ended = 0;
      await openGame(tester, rig, endSession: () async => ended++);
      await tapPiece(tester, 'chip-10');
      await tapPiece(tester, 'suit-hearts');
      expect(textIn(tester, 'top-balance'), '960');
      rig.server.offline = true;
      await rig.world.run(const Duration(seconds: 4));
      await settle(tester);
      expect(find.text('CONNECTION LOST'), findsNothing, reason: 'a short break is forgiven');
      await rig.world.run(const Duration(seconds: 8));
      await settle(tester);
      expect(find.text('CONNECTION LOST'), findsOneWidget);
      await rig.world.run(const Duration(seconds: 12));
      await settle(tester);
      expect(find.text('CONNECTION LOST'), findsOneWidget, reason: 'still one');
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(ended, 1);
      expect(rig.wallet.balance, 1000);
      expect(rig.provider.isBoardEmpty, isTrue);
      await rig.finish();
    });

    testWidgets('while the app is already closing, no second popup is made', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      await openGame(tester, rig);
      isClosingApp.value = true;
      rig.server.offline = true;
      await rig.world.run(const Duration(seconds: 12));
      await settle(tester);
      expect(find.text('CONNECTION LOST'), findsNothing);
      await rig.finish();
    });
  });

  group('pictures: the SOUND ball muted', () {
    for (final d in kGoldenPhones) {
      final size = '${d.width.toInt()}x${d.height.toInt()}';
      testWidgets('$size: muted', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        await tapPiece(tester, 'top-sound');
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/phase7_muted_$size.png'));
        await rig.finish();
      });
    }
  });
}

/// Plays nothing, for the Lucky Card side of the independence test.
class _NoLuckyCardOutput implements LuckyCardSoundOutput {
  @override
  void buttonClick() {}
  @override
  void chipClick() {}
  @override
  void numberSelect() {}
  @override
  void ding() {}
  @override
  void wheelSpin() {}
  @override
  void notification() {}
  @override
  void win() {}
  @override
  void coin() {}
  @override
  void noMoreBets() {}
  @override
  void setInGame(bool inGame) {}
  @override
  void stopAll() {}
}
