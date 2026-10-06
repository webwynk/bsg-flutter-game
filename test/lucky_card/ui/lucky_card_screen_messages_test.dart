// Tests for the messages of the Lucky Card screen (App Step 8c): the refusal lines in the status
// strip, the dialogs for a rejected bet, a round that never resolved, a lost connection and a
// blocked account, and the warning for a balance that could not be confirmed. The whole game on
// the simulated server and the fake clock, with the server made to fail in each way, driven only
// by taps. The shared dialog is Triple Chance's own (`showActionDialog`), called as it is.

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/screens/lucky_card_screen.dart';
import 'package:best_smart_game/services/lucky_card_round_sync.dart';
import 'package:best_smart_game/services/lucky_card_sound.dart';
import 'package:best_smart_game/utils/app_exit.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_status_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lucky_card_sound_test.dart' show FakeOutput;
import '../provider_rig.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

late PreloadedLuckyCardArt art;

class Session {
  int ended = 0;
}

/// A round sync that can say whether anything is still listening to it.
class ProbeSync extends LuckyCardRoundSync {
  ProbeSync(BetRig rig) : super(api: rig.server, now: () => rig.world.deviceNow);

  bool get listened => hasListeners;
}

Finder key(String k) => find.byKey(ValueKey(k));

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Widget lobby(LuckyCardProvider provider, Session session) => Builder(
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
                  sound: LuckyCardSound(FakeOutput()),
                  endSession: () async => session.ended++,
                ),
              ),
            ),
          ),
          child: const Text('go'),
        ),
      ),
    );

Future<Session> openGame(WidgetTester tester, BetRig rig, {Size size = phone}) async {
  final session = Session();
  await pumpAtSize(tester, size, lobby(rig.provider, session));
  await tester.tap(key('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await rig.world.run(const Duration(seconds: 2));
  await settle(tester);
  return session;
}

String stripText(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byType(LuckyCardStatusStrip), matching: find.byType(Text))).data!;

Color stripColor(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byType(LuckyCardStatusStrip), matching: find.byType(Text))).style!.color!;

String balanceText(WidgetTester tester) =>
    tester.widgetList<Text>(find.descendant(of: key('top-balance'), matching: find.byType(Text))).map((t) => t.data!).last;

/// The dialog of Triple Chance's shared helper, found by its title.
Finder dialogTitled(String title) => find.text(title);

void main() {
  setUpAll(() async {
    await loadLuckyCardWheelFonts();
    await loadLuckyCardIcons();
    art = await PreloadedLuckyCardArt.load();
  });

  setUp(() {
    LuckyCardSound.resetMute();
    isClosingApp.value = false;
  });
  tearDown(() {
    LuckyCardSound.resetMute();
    isClosingApp.value = false;
  });

  group('the refusal lines in the status strip', () {
    testWidgets('not enough coins for a chip: the line, in amber, then the words come back after 2 seconds', (tester) async {
      final rig = BetRig(tester, startBalance: 3);
      await openGame(tester, rig);
      expect(stripText(tester), 'PLACE YOUR CHIPS');
      await tester.tap(key('chip-5'));
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      expect(stripText(tester), 'NOT ENOUGH COINS');
      expect(stripColor(tester), LuckyCardStatusStrip.noticeColor);
      expect(balanceText(tester), '3', reason: 'nothing was taken');

      await tester.pump(const Duration(milliseconds: 1800));
      expect(stripText(tester), 'NOT ENOUGH COINS');
      await tester.pump(const Duration(milliseconds: 400));
      expect(stripText(tester), 'PLACE YOUR CHIPS');
      expect(stripColor(tester), kCream);
      await rig.finish();
    });

    testWidgets('a second refusal restarts the time', (tester) async {
      final rig = BetRig(tester, startBalance: 3);
      await openGame(tester, rig);
      await tester.tap(key('chip-5'));
      await tester.tap(key('suit-hearts'));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.tap(key('suit-spades'));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(stripText(tester), 'NOT ENOUGH COINS', reason: 'the second tap gave it a fresh 2 seconds');
      await tester.pump(const Duration(milliseconds: 700));
      expect(stripText(tester), 'PLACE YOUR CHIPS');
      await rig.finish();
    });

    testWidgets('a card at the limit says so, with the real number', (tester) async {
      final rig = BetRig(tester, startBalance: 200000);
      await openGame(tester, rig);
      final p = rig.provider;
      p.selectChip(LuckyCardChip.fiveHundred);
      for (var i = 0; i < 100; i++) {
        p.tapCard(const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts));
      }
      await tester.pump();
      expect(p.stakeOn(const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts)), 50000);
      await tester.tap(key('chip-500'));
      await tester.tap(key('j_hearts'));
      await tester.pump();
      expect(stripText(tester), 'CARD AT 50,000 LIMIT');
      await rig.finish();
    });

    testWidgets('taking back from a card with nothing on it says so', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await tester.tap(key('chip-10'));
      await tester.tap(key('j_hearts'));
      await tester.pump();
      await tester.tap(key('button-remove'));
      await tester.pump();
      await tester.tap(key('k_clubs'));
      await tester.pump();
      expect(stripText(tester), 'NOTHING TO TAKE BACK');
      await rig.finish();
    });

    testWidgets('a button that cannot finish says why: DOUBLE with too few coins', (tester) async {
      final rig = BetRig(tester, startBalance: 25);
      await openGame(tester, rig);
      await tester.tap(key('chip-10'));
      await tester.tap(key('j_hearts'));
      await tester.tap(key('k_clubs'));
      await tester.pump();
      expect(stripText(tester), 'PLACE YOUR CHIPS', reason: 'both bets were fine');
      await tester.tap(key('button-doubleBet'));
      await tester.pump();
      expect(stripText(tester), 'NOT ENOUGH COINS');
      await rig.finish();
    });

    testWidgets('a tap that works says nothing, and a closed table shows no refusal line', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await tester.tap(key('chip-10'));
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      expect(stripText(tester), 'PLACE YOUR CHIPS');
      await rig.world.runUntil(86.5);
      await tester.pump();
      await tester.tap(key('button-doubleBet'), warnIfMissed: false);
      await tester.pump();
      expect(stripText(tester), 'NO MORE PLAY');
      await rig.finish();
    });
  });

  group('a bet the server refused', () {
    Future<void> toTheDialog(WidgetTester tester, BetRig rig) async {
      await tester.tap(key('chip-10'));
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      await rig.world.runUntil(88.0);
      await settle(tester);
    }

    testWidgets('ROUND CLOSED: the dialog, the chips back, the player stays, and it closes by itself after 5 seconds', (tester) async {
      final rig = BetRig(tester);
      final session = await openGame(tester, rig);
      rig.server.failBetsNext(5, error: LuckyCardError.roundClosed);
      await toTheDialog(tester, rig);
      expect(dialogTitled('ROUND CLOSED'), findsOneWidget);
      expect(find.textContaining('Your coins have been returned'), findsOneWidget);
      expect(balanceText(tester), '1,000', reason: 'the chips went back on screen');
      expect(key('top-exit'), findsOneWidget, reason: 'the player is still in the game');
      await rig.world.run(const Duration(seconds: 5, milliseconds: 600));
      await settle(tester);
      expect(dialogTitled('ROUND CLOSED'), findsNothing, reason: 'it closed by itself');
      expect(session.ended, 0);
      await rig.finish();
    });

    for (final e in {
      LuckyCardError.insufficientCoins: 'INSUFFICIENT COINS',
      LuckyCardError.notAPlayer: 'ACCOUNT NOT ELIGIBLE',
      LuckyCardError.belowMin: 'BET NOT PLACED',
    }.entries) {
      testWidgets('${e.key.name} has its own words: ${e.value}', (tester) async {
        final rig = BetRig(tester);
        await openGame(tester, rig);
        rig.server.failBetsNext(5, error: e.key);
        await toTheDialog(tester, rig);
        expect(dialogTitled(e.value), findsOneWidget);
        await rig.finish();
      });
    }

    testWidgets('the dialog may be skipped by a tap outside', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      rig.server.failBetsNext(5, error: LuckyCardError.roundClosed);
      await toTheDialog(tester, rig);
      expect(dialogTitled('ROUND CLOSED'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await settle(tester);
      expect(dialogTitled('ROUND CLOSED'), findsNothing);
      await rig.finish();
    });
  });

  group('a round that never resolved', () {
    testWidgets('SERVER ERROR: no refund is claimed, the board is dropped, the dialog closes by itself', (tester) async {
      final rig = BetRig(tester);
      final session = await openGame(tester, rig);
      rig.server.resultFromSecond = 1000;
      rig.betTenOnEveryCard();
      await tester.pump();
      expect(balanceText(tester), '880');
      await rig.world.runUntil(99.5);
      await settle(tester);
      expect(dialogTitled('SERVER ERROR'), findsOneWidget);
      expect(find.textContaining('Your balance will update automatically'), findsOneWidget);
      expect(find.textContaining('returned'), findsNothing, reason: 'the stake was really taken');
      expect(balanceText(tester), '880', reason: 'no refund');
      expect(rig.provider.isBoardEmpty, isTrue);
      await rig.world.run(const Duration(seconds: 5, milliseconds: 600));
      await settle(tester);
      expect(dialogTitled('SERVER ERROR'), findsNothing);
      expect(session.ended, 0);
      await rig.finish();
    });
  });

  group('a lost connection', () {
    testWidgets('a bet that cannot be sent: CONNECTION LOST, it cannot be skipped, and OK ends the session once', (tester) async {
      final rig = BetRig(tester);
      final session = await openGame(tester, rig);
      await tester.tap(key('chip-10'));
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      rig.server.betsOffline = true;
      await rig.world.runUntil(90.0);
      await rig.world.run(const Duration(seconds: 6));
      await settle(tester);
      expect(dialogTitled('CONNECTION LOST'), findsOneWidget);
      expect(find.textContaining('you will be logged out'), findsOneWidget);
      expect(balanceText(tester), '1,000', reason: 'the chips went back first');

      await tester.tapAt(const Offset(4, 4));
      await settle(tester);
      expect(dialogTitled('CONNECTION LOST'), findsOneWidget, reason: 'a tap outside does not close it');
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(dialogTitled('CONNECTION LOST'), findsOneWidget, reason: 'nor does the back gesture');
      await rig.world.run(const Duration(seconds: 10));
      expect(dialogTitled('CONNECTION LOST'), findsOneWidget, reason: 'nor does time');
      expect(session.ended, 0);

      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(session.ended, 1);
      await rig.finish();
    });

    testWidgets('the server going silent: after about 6 seconds, ONE dialog however long it lasts; OK gives the unsent chips back and ends the session', (tester) async {
      final rig = BetRig(tester);
      final session = await openGame(tester, rig);
      await tester.tap(key('chip-10'));
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      expect(balanceText(tester), '970');

      rig.server.offline = true;
      await rig.world.run(const Duration(seconds: 4));
      await settle(tester);
      expect(dialogTitled('CONNECTION LOST'), findsNothing, reason: 'a short break is forgiven');
      await rig.world.run(const Duration(seconds: 8));
      await settle(tester);
      expect(dialogTitled('CONNECTION LOST'), findsOneWidget);
      await rig.world.run(const Duration(seconds: 12));
      await settle(tester);
      expect(dialogTitled('CONNECTION LOST'), findsOneWidget, reason: 'still one');

      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(session.ended, 1);
      expect(rig.wallet.balance, 1000, reason: 'the chips that were never sent came back');
      expect(rig.provider.isBoardEmpty, isTrue);
      await rig.finish();
    });

    testWidgets('a connection that comes back within the 6 seconds shows nothing', (tester) async {
      final rig = BetRig(tester);
      final session = await openGame(tester, rig);
      rig.server.offline = true;
      await rig.world.run(const Duration(seconds: 3));
      rig.server.offline = false;
      await rig.world.run(const Duration(seconds: 10));
      await settle(tester);
      expect(dialogTitled('CONNECTION LOST'), findsNothing);
      expect(session.ended, 0);
      await rig.finish();
    });

    testWidgets('a second outage after the connection came back does not stack a second dialog', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      rig.server.offline = true;
      await rig.world.run(const Duration(seconds: 9));
      await settle(tester);
      expect(dialogTitled('CONNECTION LOST'), findsOneWidget);
      rig.server.offline = false;
      await rig.world.run(const Duration(seconds: 6));
      rig.server.offline = true;
      await rig.world.run(const Duration(seconds: 9));
      await settle(tester);
      expect(dialogTitled('CONNECTION LOST'), findsOneWidget, reason: 'still the one dialog');
      await rig.finish();
    });

    testWidgets('a blocked account: ACCOUNT BLOCKED', (tester) async {
      final rig = BetRig(tester);
      final session = await openGame(tester, rig);
      rig.server.failNext(1000, error: LuckyCardError.accountBlocked);
      await rig.world.run(const Duration(seconds: 12));
      await settle(tester);
      expect(dialogTitled('ACCOUNT BLOCKED'), findsOneWidget);
      expect(dialogTitled('CONNECTION LOST'), findsNothing);
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(session.ended, 1);
      await rig.finish();
    });

    testWidgets('while the away-too-long flow is closing the app, no second popup is made', (tester) async {
      final rig = BetRig(tester);
      final session = await openGame(tester, rig);
      isClosingApp.value = true;
      rig.server.offline = true;
      await rig.world.run(const Duration(seconds: 12));
      await settle(tester);
      expect(dialogTitled('CONNECTION LOST'), findsNothing);
      expect(session.ended, 0);
      await rig.finish();
    });

    testWidgets('after the screen has stopped itself (a long absence), no dialog is made', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await rig.world.run(const Duration(seconds: 21));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      rig.server.offline = true;
      await rig.world.run(const Duration(seconds: 12));
      await settle(tester);
      expect(dialogTitled('CONNECTION LOST'), findsNothing);
      await rig.finish();
    });

    testWidgets('a connection already down when the screen opens is noticed', (tester) async {
      final rig = BetRig(tester);
      rig.server.offline = true;
      final session = Session();
      await pumpAtSize(tester, phone, lobby(rig.provider, session));
      await tester.tap(key('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await rig.world.run(const Duration(seconds: 6));
      await settle(tester);
      expect(dialogTitled('CONNECTION LOST'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(session.ended, 1);
      await rig.finish();
    });
  });

  group('a balance that could not be confirmed', () {
    testWidgets('an amber line for 6 seconds, even while the table is closed, then the words', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      rig.server.resultsOffline = true;
      rig.betTenOnEveryCard();
      await tester.pump();
      var guard = 0;
      while (!rig.provider.cardRevealed && ++guard < 3000) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(rig.provider.cardRevealed, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(rig.provider.balanceSyncFailed, isTrue);
      expect(stripText(tester), kLuckyCardBalanceLineForTest);
      expect(stripColor(tester), LuckyCardStatusStrip.noticeColor);
      await tester.pump(const Duration(seconds: 5));
      expect(stripText(tester), kLuckyCardBalanceLineForTest, reason: 'still there at 5 seconds');
      await tester.pump(const Duration(seconds: 2));
      expect(stripText(tester), isNot(kLuckyCardBalanceLineForTest));
      await rig.finish();
    });
  });

  group('a picture to look at', () {
    const small = Size(640, 360);

    Future<void> shoot(WidgetTester tester, String name) async {
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_640x360.png'));
    }

    testWidgets('a refusal line in the status strip', (tester) async {
      final rig = BetRig(tester, startBalance: 3);
      await openGame(tester, rig, size: small);
      await tester.tap(key('chip-5'));
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await shoot(tester, 'message_refusal');
      await rig.finish();
    });

    testWidgets('a rejected bet', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig, size: small);
      rig.server.failBetsNext(5, error: LuckyCardError.roundClosed);
      await tester.tap(key('chip-10'));
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      await rig.world.runUntil(88.0);
      await settle(tester);
      await shoot(tester, 'message_bet_rejected');
      await rig.finish();
    });

    testWidgets('a lost connection', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig, size: small);
      rig.server.offline = true;
      await rig.world.run(const Duration(seconds: 9));
      await settle(tester);
      await shoot(tester, 'message_connection_lost');
      await rig.finish();
    });

    testWidgets('a balance that could not be confirmed', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig, size: small);
      rig.server.resultsOffline = true;
      rig.betTenOnEveryCard();
      await tester.pump();
      var guard = 0;
      while (!rig.provider.cardRevealed && ++guard < 3000) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 700));
      await shoot(tester, 'message_balance');
      await rig.finish();
    });
  });

  group('leaving', () {
    testWidgets('the screen stops watching the round sync when it closes', (tester) async {
      final rig = BetRig(tester);
      final sync = ProbeSync(rig);
      final probe = LuckyCardProvider(
        api: rig.server,
        wallet: rig.wallet,
        sync: sync,
        now: () => rig.world.deviceNow,
      );
      final session = Session();
      await pumpAtSize(tester, phone, lobby(probe, session));
      await tester.tap(key('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await rig.world.run(const Duration(seconds: 2));
      await settle(tester);
      expect(sync.listened, isTrue, reason: 'the screen and the provider listen while it is open');
      await tester.tap(key('top-exit'));
      await settle(tester);
      await tester.tap(key('exit-yes'));
      for (var i = 0; i < 3; i++) {
        await settle(tester);
      }
      expect(sync.listened, isFalse, reason: 'nobody is left listening');
      probe.dispose();
      await rig.finish();
    });

    testWidgets('the screen stops listening for problems when it closes', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      expect(rig.provider.onProblem, isNotNull);
      await tester.tap(key('top-exit'));
      await settle(tester);
      await tester.tap(key('exit-yes'));
      for (var i = 0; i < 3; i++) {
        await settle(tester);
      }
      expect(rig.provider.onProblem, isNull);
      await rig.finish();
    });
  });
}

const Color kCream = Color(0xFFF5E6C4);
const String kLuckyCardBalanceLineForTest = 'BALANCE NOT CONFIRMED - IT WILL UPDATE NEXT ROUND';
