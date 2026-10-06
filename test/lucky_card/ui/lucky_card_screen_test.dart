// Tests for the Lucky Card screen (lib/screens/lucky_card_screen.dart): the whole game on
// the simulated server and the fake clock, driven only through what the player can touch.
// The screen is pushed over another page (the lobby), as in the real app.

import 'dart:ui' as ui;

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/screens/lucky_card_screen.dart';
import 'package:best_smart_game/services/lucky_card_round_sync.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_background.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_reveal_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_win_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_wallet.dart';
import '../provider_rig.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

late PreloadedLuckyCardArt art;

/// A provider that can say whether anything is still listening to it.
class ProbeProvider extends LuckyCardProvider {
  ProbeProvider(BetRig rig)
      : super(
          api: rig.server,
          wallet: FakeWallet(1000),
          sync: LuckyCardRoundSync(api: rig.server, now: () => rig.world.deviceNow),
          now: () => rig.world.deviceNow,
        );

  bool get listenedTo => hasListeners;
}

/// Records which pictures were asked for.
class SpyArt extends LuckyCardArt {
  SpyArt(this._inner);

  final LuckyCardArt _inner;
  final Set<LuckyCardArtKey> asked = {};

  @override
  ImageProvider image(LuckyCardArtKey key, {required int cacheWidth}) {
    asked.add(key);
    return _inner.image(key, cacheWidth: cacheWidth);
  }
}

/// A provider that says when it has been disposed.
class DisposeProbe extends LuckyCardProvider {
  DisposeProbe(BetRig rig)
      : super(
          api: rig.server,
          wallet: rig.wallet,
          sync: LuckyCardRoundSync(api: rig.server, now: () => rig.world.deviceNow),
          now: () => rig.world.deviceNow,
        );

  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

/// The lobby: one button that opens the game screen over it.
Widget lobby(LuckyCardProvider provider) => Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const ValueKey('go'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LuckyCardScreen(setup: LuckyCardScreenSetup(provider: provider, art: art, setOrientation: false)),
            ),
          ),
          child: const Text('go'),
        ),
      ),
    );

Finder key(String k) => find.byKey(ValueKey(k));

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Opens the game screen over the lobby and lets it load and attach.
Future<void> openGame(WidgetTester tester, BetRig rig, {Size size = phone, LuckyCardProvider? provider}) async {
  await pumpAtSize(tester, size, lobby(provider ?? rig.provider));
  await tester.tap(key('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await rig.world.run(const Duration(seconds: 2));
  await settle(tester);
}

String textIn(WidgetTester tester, String k) =>
    tester.widgetList<Text>(find.descendant(of: key(k), matching: find.byType(Text))).map((t) => t.data!).last;

/// The question, the answer and the page turning back take three transitions.
Future<void> settleAll(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await settle(tester);
  }
}

bool get inGame => find.byType(LuckyCardScreen).evaluate().isNotEmpty;
bool get onBoard => key('suit-hearts').evaluate().isNotEmpty;
bool get onWheel => find.byType(LuckyCardWheelBinding).evaluate().isNotEmpty;

void main() {
  setUpAll(() async {
    await loadLuckyCardWheelFonts();
    await loadLuckyCardIcons();
    art = await PreloadedLuckyCardArt.load();
  });

  group('opening', () {
    testWidgets('a loading mark first, then the whole game: the top bar, the board, the chips, the buttons', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, lobby(rig.provider));
      await tester.tap(key('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'loading');
      expect(onBoard, isFalse);

      await rig.world.run(const Duration(seconds: 2));
      await settle(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      for (final k in ['top-balance', 'top-countdown', 'top-exit', 'top-sound', 'top-info', 'suit-hearts', 'rank-J', 'play', 'win', 'limits', 'result-latest', 'chip-5', 'chip-500', 'button-doubleBet', 'button-clear', 'button-remove']) {
        expect(key(k), findsOneWidget, reason: k);
      }
      expect(find.text('PLACE YOUR CHIPS'), findsOneWidget);
      expect(textIn(tester, 'top-balance'), '1,000');
      expect(rig.provider.countdown, inInclusiveRange(30, 50));
      await rig.finish();
    });

    testWidgets('a screen that opens while betting is closed starts with the wheel', (tester) async {
      final rig = BetRig(tester);
      await rig.open();
      await rig.world.runUntil(86.0);
      await pumpAtSize(tester, phone, lobby(rig.provider));
      await tester.tap(key('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await rig.world.run(const Duration(seconds: 1));
      await settle(tester);
      expect(onWheel, isTrue);
      expect(onBoard, isFalse);
      await rig.finish();
    });
  });

  group('the swap of the board and the wheel', () {
    testWidgets('the wheel and the card column replace the board and the rank selectors at the lock, and the board comes back with the next round', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      expect(onBoard, isTrue);
      expect(key('rank-J'), findsOneWidget);
      expect(onWheel, isFalse);
      expect(find.byType(LuckyCardRevealColumn), findsNothing);

      await rig.world.runUntil(86.0);
      await settle(tester);
      expect(rig.provider.isLocked, isTrue);
      expect(onWheel, isTrue);
      expect(find.byType(LuckyCardRevealColumn), findsOneWidget);
      expect(onBoard, isFalse);
      expect(key('rank-J'), findsNothing);
      expect(key('chip-5'), findsOneWidget, reason: 'the side column stays');
      expect(key('top-balance'), findsOneWidget, reason: 'and so does the top bar');

      await rig.world.runUntil(98.0);
      expect(onWheel, isTrue, reason: 'through the spin and the reveal');
      await rig.runIntoNextCycle(8);
      await settle(tester);
      expect(rig.provider.isLocked, isFalse);
      expect(onBoard, isTrue);
      expect(onWheel, isFalse);
      expect(key('rank-J'), findsOneWidget);
      await rig.finish();
    });

    testWidgets('with "reduce motion" on, the swap is at once', (tester) async {
      final rig = BetRig(tester);
      // The phone's own setting (a route pushed on the app's navigator does not see a
      // MediaQuery put around the lobby).
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await openGame(tester, rig);
      expect(MediaQuery.disableAnimationsOf(tester.element(key('top-exit'))), isTrue, reason: 'the screen sees the setting');
      var guard = 0;
      while (!rig.provider.isLocked && ++guard < 2000) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(rig.provider.isLocked, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(onWheel, isTrue);
      expect(onBoard, isFalse, reason: 'no cross-fade leaves the board on screen');
      await rig.finish();
    });

    testWidgets('with the setting off the board is still there for a moment while the wheel fades in', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      var guard = 0;
      while (!rig.provider.isLocked && ++guard < 2000) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(rig.provider.isLocked, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(onWheel, isTrue);
      expect(onBoard, isTrue, reason: 'the cross-fade has not finished');
      await settle(tester);
      expect(onBoard, isFalse);
      await rig.finish();
    });
  });

  group('playing through the real widgets', () {
    testWidgets('chip, suit bar, DOUBLE and CLEAR move the board, PLAY and the balance together', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await tester.tap(key('chip-10'));
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      expect(textIn(tester, 'play'), '30');
      expect(textIn(tester, 'top-balance'), '970');
      expect(rig.provider.total, 30);

      await tester.tap(key('button-doubleBet'));
      await tester.pump();
      expect(textIn(tester, 'play'), '60');
      expect(textIn(tester, 'top-balance'), '940');

      await tester.tap(key('button-clear'));
      await tester.pump();
      expect(textIn(tester, 'play'), '0');
      expect(textIn(tester, 'top-balance'), '1,000');
      await rig.finish();
    });

    testWidgets('a whole round: the bet is sent at the lock, the wheel turns, the winner is paid', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      rig.betTenOnEveryCard();
      await tester.pump();
      expect(textIn(tester, 'top-balance'), '880');
      await rig.world.runUntil(98.0);
      await settle(tester);
      expect(rig.server.betsReceived, 1);
      expect(rig.provider.cardRevealed, isTrue);
      expect(textIn(tester, 'win').startsWith('+'), isTrue, reason: 'the card is the one the simulated server drew, a win');
      await rig.finish();
    });

    testWidgets('INFO opens the dialog while betting is open, and the lock closes it by itself', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await tester.tap(key('top-info'));
      await settle(tester);
      expect(key('info-dialog'), findsOneWidget);
      await rig.world.runUntil(86.0);
      await settle(tester);
      expect(key('info-dialog'), findsNothing);
      expect(onWheel, isTrue, reason: 'the wheel is not hidden behind it');
      await rig.finish();
    });
  });

  group('leaving', () {
    testWidgets('EXIT asks, NO stays, and the question cancels itself after 5 seconds', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await tester.tap(key('top-exit'));
      await settle(tester);
      expect(key('exit-dialog'), findsOneWidget);
      await tester.tap(key('exit-no'));
      await settle(tester);
      expect(key('exit-dialog'), findsNothing);
      expect(key('top-exit'), findsOneWidget, reason: 'still in the game');
      expect(key('go'), findsNothing);

      await tester.tap(key('top-exit'));
      await settle(tester);
      expect(key('exit-dialog'), findsOneWidget);
      await rig.world.run(const Duration(seconds: 5, milliseconds: 500));
      await settle(tester);
      expect(key('exit-dialog'), findsNothing, reason: 'it cancelled itself');
      expect(key('top-exit'), findsOneWidget, reason: 'and the player stayed');
      await rig.finish();
    });

    testWidgets('the back gesture asks the same question', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(key('exit-dialog'), findsOneWidget);
      expect(key('top-exit'), findsOneWidget);
      await tester.tap(key('exit-no'));
      await settle(tester);
      expect(key('top-exit'), findsOneWidget);
      await rig.finish();
    });

    testWidgets('YES leaves to the lobby, and chips that were never sent come back', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await tester.tap(key('chip-10'));
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      expect(rig.wallet.balance, 970);

      await tester.tap(key('top-exit'));
      await settle(tester);
      await tester.tap(key('exit-yes'));
      await settleAll(tester);
      expect(inGame, isFalse, reason: 'back in the lobby');
      expect(key('go'), findsOneWidget);
      expect(key('top-exit'), findsNothing);
      expect(rig.wallet.balance, 1000, reason: 'the chips were given back');
      expect(rig.provider.isBoardEmpty, isTrue);
      await rig.world.run(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await rig.finish();
    });

    testWidgets('a bet that was already sent is left to settle when the player leaves', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      rig.betTenOnEveryCard();
      await rig.world.runUntil(86.5);
      await rig.world.run(const Duration(seconds: 1));
      expect(rig.server.betsReceived, 1);
      await tester.tap(key('top-exit'));
      await settle(tester);
      await tester.tap(key('exit-yes'));
      await settleAll(tester);
      expect(inGame, isFalse);
      expect(rig.wallet.balance, 880, reason: 'no refund for a bet the server already has');
      await rig.finish();
    });

    testWidgets('the screen lets everything go when it closes: no listener is left on the provider', (tester) async {
      final rig = BetRig(tester);
      final probe = ProbeProvider(rig);
      await openGame(tester, rig, provider: probe);
      expect(probe.listenedTo, isTrue);
      await tester.tap(key('top-exit'));
      await settle(tester);
      await tester.tap(key('exit-yes'));
      await settleAll(tester);
      expect(inGame, isFalse);
      expect(probe.listenedTo, isFalse);
      probe.dispose();
      await rig.finish();
    });
  });

  group('the app goes to the background', () {
    testWidgets('a short absence changes nothing: the screen keeps running and the lock still comes', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await rig.world.run(const Duration(seconds: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await rig.world.runUntil(86.0);
      await settle(tester);
      expect(rig.provider.isLocked, isTrue, reason: 'the round sync is still running');
      expect(onWheel, isTrue);
      await tester.tap(key('top-info'), warnIfMissed: false);
      expect(tester.takeException(), isNull);
      await rig.finish();
    });

    testWidgets('an absence that ended long ago is forgotten: a later short one does not stop the screen', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await rig.world.run(const Duration(seconds: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await rig.world.run(const Duration(seconds: 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await rig.world.run(const Duration(seconds: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await rig.world.runUntil(86.0);
      await settle(tester);
      expect(rig.provider.isLocked, isTrue, reason: 'the screen is still running, not stopped');
      await rig.finish();
    });

    testWidgets('after a short absence that crossed the lock, the bet is sent at once, not lost', (tester) async {
      // The round sync's tick is made slow, to stand for a phone whose timers stood still.
      final rig = BetRig(tester, startInto: 80, tickInterval: const Duration(seconds: 30));
      await openGame(tester, rig);
      await tester.tap(key('chip-10'));
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      expect(rig.provider.total, 30);
      expect(rig.provider.countdown, greaterThan(5), reason: 'betting is still open when the phone goes away');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await rig.world.run(const Duration(seconds: 3));
      expect(rig.provider.countdown, lessThanOrEqualTo(5), reason: 'the lock mark went by while it was away');
      expect(rig.server.betsReceived, 0, reason: 'and nothing sent the bet');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.server.betsReceived, 1, reason: 'the late bet went to the server on the way back');
      await rig.finish();
    });

    testWidgets('after 20 seconds or more the screen stops itself: chips come back, nothing runs, nothing can be tapped', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await tester.tap(key('chip-10'));
      await tester.tap(key('suit-hearts'));
      await tester.pump();
      expect(rig.wallet.balance, 970);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await rig.world.run(const Duration(seconds: 21));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(rig.provider.isBoardEmpty, isTrue, reason: 'the unsent chips were given back');
      expect(rig.wallet.balance, 1000);
      await rig.world.runUntil(88.0);
      expect(rig.provider.isLocked, isFalse, reason: 'the round sync is stopped: the lock never comes');
      expect(rig.server.betsReceived, 0);

      // The screen is dimmed and nothing on it answers (the shared popup logs the player out).
      await tester.tap(key('top-exit'), warnIfMissed: false);
      await settle(tester);
      expect(key('exit-dialog'), findsNothing);
      expect(find.byType(IgnorePointer), findsWidgets);
      await rig.finish();
    });

    testWidgets('a second absence after the screen stopped does nothing more', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await rig.world.run(const Duration(seconds: 21));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await rig.world.run(const Duration(seconds: 21));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await rig.finish();
    });

    testWidgets('going to the background while the game is still loading does not break the opening', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, lobby(rig.provider));
      await tester.tap(key('go'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await rig.world.run(const Duration(seconds: 2));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(key('top-exit'), findsOneWidget);
      await rig.finish();
    });
  });

  group('what the screen sets up and gives up', () {
    testWidgets('it forces landscape, as Triple Chance does', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') calls.add('${call.arguments}');
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final rig = BetRig(tester);
      await pumpAtSize(
        tester,
        phone,
        Builder(
          builder: (context) => TextButton(
            key: const ValueKey('go-landscape'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => LuckyCardScreen(setup: LuckyCardScreenSetup(provider: rig.provider, art: art))),
            ),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(key('go-landscape'));
      await tester.pump();
      expect(calls.length, 1);
      expect(calls.single, allOf(contains('landscapeLeft'), contains('landscapeRight')));
      expect(calls.single.contains('portrait'), isFalse);
      await rig.world.run(const Duration(seconds: 2));
      await rig.finish();
    });

    testWidgets('a test setup that switches landscape off sends no orientation request', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') calls.add('${call.arguments}');
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final rig = BetRig(tester);
      await openGame(tester, rig);
      expect(calls, isEmpty);
      await rig.finish();
    });

    testWidgets('every picture is requested while the loading mark is still showing', (tester) async {
      final rig = BetRig(tester);
      final spy = SpyArt(art);
      await pumpAtSize(
        tester,
        phone,
        Builder(
          builder: (context) => TextButton(
            key: const ValueKey('go-spy'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => LuckyCardScreen(setup: LuckyCardScreenSetup(provider: rig.provider, art: spy, setOrientation: false))),
            ),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(key('go-spy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final wanted = {
        for (final c in LuckyCard.all) LuckyCardArtKey.card(c),
        for (final s in LuckyCardSuit.values) ...[LuckyCardArtKey.suitBar(s), LuckyCardArtKey.suitIcon(s)],
        for (final r in LuckyCardRank.values) LuckyCardArtKey.rankSelector(r),
        for (final c in LuckyCardChip.values) LuckyCardArtKey.chip(c),
        LuckyCardArtKey.winPopup,
        LuckyCardArtKey.background,
      };
      expect(spy.asked.containsAll(wanted), isTrue, reason: 'missing: ${wanted.difference(spy.asked)}');
      await rig.world.run(const Duration(seconds: 2));
      await rig.finish();
    });

    testWidgets('a provider the screen made is disposed with it; one it was given is not', (tester) async {
      for (final owns in [true, false]) {
        final rig = BetRig(tester);
        final probe = DisposeProbe(rig);
        await pumpAtSize(
          tester,
          phone,
          Builder(
            builder: (context) => TextButton(
              key: const ValueKey('go-own'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LuckyCardScreen(setup: LuckyCardScreenSetup(provider: probe, art: art, setOrientation: false, ownsProvider: owns)),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        );
        await tester.tap(key('go-own'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await rig.world.run(const Duration(seconds: 2));
        await settle(tester);
        await tester.tap(key('top-exit'));
        await settle(tester);
        await tester.tap(key('exit-yes'));
        await settleAll(tester);
        expect(inGame, isFalse);
        expect(probe.disposed, owns, reason: 'owns: $owns');
        if (!owns) probe.dispose();
        await rig.finish();
      }
    });
  });

  group('small things on the screen', () {
    testWidgets('two quick activations of EXIT by a screen reader ask once, not twice', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      final handle = tester.ensureSemantics();
      final exit = find.semantics.byPredicate((n) => n.label == 'Exit the game');
      tester.semantics.performAction(exit, ui.SemanticsAction.tap);
      tester.semantics.performAction(exit, ui.SemanticsAction.tap);
      await settle(tester);
      expect(key('exit-dialog'), findsOneWidget);
      await tester.tap(key('exit-no'));
      await settle(tester);
      expect(key('exit-dialog'), findsNothing, reason: 'there was only one question to answer');
      handle.dispose();
      await rig.finish();
    });

    testWidgets('the win popup is on the screen during a win, and gone when the round ends', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      rig.betTenOnEveryCard();
      await rig.world.runUntil(99.0);
      await settle(tester);
      expect(find.byType(LuckyCardWinPopup), findsOneWidget);
      await rig.runIntoNextCycle(8);
      await settle(tester);
      expect(find.byType(LuckyCardWinPopup), findsNothing);
      await rig.finish();
    });

    testWidgets('the game stays inside the safe area of a phone with a notch', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, lobby(rig.provider));
      // The notch, as the phone itself reports it (the shared test setup puts it back).
      tester.view.padding = const FakeViewPadding(left: 44, right: 44);
      tester.view.viewPadding = const FakeViewPadding(left: 44, right: 44);
      await tester.pump();
      await tester.tap(key('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await rig.world.run(const Duration(seconds: 2));
      await settle(tester);
      final exit = tester.getRect(key('top-exit'));
      final info = tester.getRect(key('top-info'));
      expect(exit.left, greaterThanOrEqualTo(44), reason: 'clear of the notch at the left');
      expect(info.right, lessThanOrEqualTo(phone.width - 44), reason: 'and at the right');
      // The stage is the screen's own: it fills everything, the notch areas too.
      expect(tester.getRect(find.byType(LuckyCardBackground)), Offset.zero & phone);
      await rig.finish();
    });

    testWidgets('the stage is painted under the game, and nothing dark is left on top of it', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      final stack = find.ancestor(of: find.byType(LuckyCardBackground), matching: find.byType(Stack)).first;
      final children = tester.widget<Stack>(stack).children;
      expect(children.first, isA<Positioned>(), reason: 'the stage is the first, so the lowest, thing painted');
      expect(((children.first as Positioned).child as LuckyCardBackground), isNotNull);
      expect(children.length, 2);
      final placeholders = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_PlaceholderBackground');
      expect(placeholders, findsNothing, reason: 'the canvas draws no background of its own on top of the stage');
      await rig.finish();
    });

    testWidgets('the SOUND button changes its look when tapped, and back', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      await tester.tap(key('top-sound'));
      await tester.pump();
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
      await tester.tap(key('top-sound'));
      await tester.pump();
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      await rig.finish();
    });
  });

  group('every device', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): the whole screen, betting then the wheel, with no overflow', (tester) async {
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        rig.betTenOnEveryCard();
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'betting');
        await rig.world.runUntil(90.5);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'the lock');
        await rig.world.runUntil(98.0);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'the reveal');
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          final size = t.style?.fontSize;
          if (size != null) expect(size, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: '"${t.data}"');
        }
        await rig.finish();
      });
    }
  });

  group('a picture to look at', () {
    Future<void> shoot(WidgetTester tester, Device d, String name, Future<void> Function(BetRig rig) arrange) async {
      final rig = BetRig(tester);
      await openGame(tester, rig, size: d.size);
      await arrange(rig);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${d.width.toInt()}x${d.height.toInt()}.png'));
      await rig.finish();
    }

    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets('betting, a bet on the board: ${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) async {
        await shoot(tester, d, 'screen_betting', (rig) async {
          rig.provider.selectChip(LuckyCardChip.ten);
          rig.provider.tapSuit(LuckyCardSuit.hearts);
          rig.provider.tapRank(LuckyCardRank.jack);
          rig.provider.selectChip(LuckyCardChip.fifty);
          await tester.pump();
        });
      });
    }

    testWidgets('the wheel turning: small phone', (tester) async {
      await shoot(tester, const Device('small phone', 640, 360), 'screen_reveal', (rig) async {
        rig.betTenOnEveryCard();
        await rig.world.runUntil(93.5);
      });
    });

    testWidgets('the win: small phone', (tester) async {
      await shoot(tester, const Device('small phone', 640, 360), 'screen_win', (rig) async {
        rig.betTenOnEveryCard();
        await rig.world.runUntil(99.0);
      });
    });
  });
}
