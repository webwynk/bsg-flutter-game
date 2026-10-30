// Tests for the HISTORY button on the real Lucky Card screen (lib/screens/lucky_card_screen.dart):
// the whole game on the simulated server and the fake clock, with a scripted database read for
// the player's rounds and a fake sound output. The older screen tests are left as they were.

import 'package:best_smart_game/providers/auth_provider.dart';
import 'package:best_smart_game/providers/lucky_card_history_provider.dart';
import 'package:best_smart_game/screens/lucky_card_screen.dart';
import 'package:best_smart_game/services/lucky_card_history_service.dart';
import 'package:best_smart_game/services/lucky_card_sound.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel_binding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lucky_card_sound_test.dart' show FakeOutput;
import '../provider_rig.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

final DateTime login = DateTime.utc(2026, 10, 22, 9);

late PreloadedLuckyCardArt art;

Finder key(String k) => find.byKey(ValueKey(k));

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The question, the answer and the page turning back take three transitions.
Future<void> settleAll(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await settle(tester);
  }
}

/// A row shaped like the live answer.
Map<String, dynamic> row({int round = 100, int stake = 50, int payout = 0, String rank = 'J', String suit = 'hearts', int bonus = 1}) => {
      'round_id': 'id-$round',
      'total_stake': stake,
      'total_payout': payout,
      'created_at': '2026-10-22T10:00:00+00:00',
      'lucky_card_rounds': {'round_number': round, 'winning_rank': rank, 'winning_suit': suit, 'bonus_multiplier': bonus},
    };

List<Map<String, dynamic>> sampleRows() => [
      row(round: 17403942, stake: 100, payout: 5000, rank: 'K', suit: 'spades', bonus: 5),
      row(round: 17403941, stake: 50, payout: 0),
    ];

/// A history over a scripted read; every read is logged with the login time it was asked for.
class Script {
  Script(this.rows);

  final List<Map<String, dynamic>> rows;
  final List<DateTime?> reads = [];

  late final LuckyCardHistoryProvider history = LuckyCardHistoryProvider(
    service: LuckyCardHistoryService(query: (since, limit) async {
      reads.add(since);
      return rows;
    }),
  );
}

/// A history that says when it has been disposed.
class DisposeProbeHistory extends LuckyCardHistoryProvider {
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

/// The lobby: one button that opens the game screen over it, as in the real app.
Widget lobby(LuckyCardScreenSetup Function() setup) => Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const ValueKey('go'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LuckyCardScreen(setup: setup()))),
          child: const Text('go'),
        ),
      ),
    );

/// A stand-in for the shared AuthProvider (the real one cannot be built without Supabase) that
/// only knows when this login started.
class LoginAuth extends Fake implements AuthProvider {
  DateTime? start;

  @override
  DateTime? get sessionStartAt => start;
}

LuckyCardScreenSetup setupFor(
  BetRig rig,
  FakeOutput out, {
  LuckyCardHistoryProvider? history,
  bool ownsHistory = false,
  DateTime? Function()? sessionStart,
  AuthProvider? auth,
}) =>
    LuckyCardScreenSetup(
      provider: rig.provider,
      art: art,
      setOrientation: false,
      sound: LuckyCardSound(out),
      history: history,
      ownsHistory: ownsHistory,
      sessionStart: sessionStart,
      auth: auth,
    );

Future<void> openGame(WidgetTester tester, BetRig rig, LuckyCardScreenSetup Function() setup, {bool pumped = false, Size size = phone}) async {
  if (!pumped) await pumpAtSize(tester, size, lobby(setup));
  await tester.tap(key('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await rig.world.run(const Duration(seconds: 2));
  await settle(tester);
}

bool dimmed(String k) => find.descendant(of: key(k), matching: find.byType(Opacity)).evaluate().isNotEmpty;

List<String> wordsIn(WidgetTester tester, Finder within) => [
      for (final t in tester.widgetList<Text>(find.descendant(of: within, matching: find.byType(Text)))) t.data ?? '',
    ];

bool get onWheel => find.byType(LuckyCardWheelBinding).evaluate().isNotEmpty;

void main() {
  setUpAll(() async {
    await loadLuckyCardWheelFonts();
    await loadLuckyCardIcons();
    art = await PreloadedLuckyCardArt.load();
  });

  setUp(LuckyCardSound.resetMute);
  tearDown(LuckyCardSound.resetMute);

  group('the HISTORY button opens the list', () {
    testWidgets('it is on the screen and usable while betting is open', (tester) async {
      final rig = BetRig(tester);
      final script = Script(sampleRows());
      await openGame(tester, rig, () => setupFor(rig, FakeOutput(), history: script.history, sessionStart: () => login));
      expect(key('top-history'), findsOneWidget);
      expect(dimmed('top-history'), isFalse);
      expect(script.reads, isEmpty, reason: 'nothing is read until the button is tapped');
      await rig.finish();
    });

    testWidgets('a tap opens the dialog, reads everything since the login time, lists the rounds, and makes the notification sound', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      final script = Script(sampleRows());
      await openGame(tester, rig, () => setupFor(rig, out, history: script.history, sessionStart: () => login));
      out.events.clear();
      await tester.tap(key('top-history'));
      await settle(tester);
      expect(key('history-dialog'), findsOneWidget);
      expect(script.reads, [login]);
      expect(wordsIn(tester, key('history-row-0')), ['1', '17403942', 'K', '5X', '100', '+5,000']);
      expect(wordsIn(tester, key('history-row-1')), ['2', '17403941', 'J', 'N', '50', '0']);
      expect(wordsIn(tester, key('history-total-play')), ['TOTAL PLAY', '150']);
      expect(wordsIn(tester, key('history-total-win')), ['TOTAL WIN', '5,000']);
      expect(out.events, ['notification']);
      await rig.finish();
    });

    testWidgets('a tap on a line opens its popup with the notification sound, as Triple Chance\'s detail popup does', (tester) async {
      final rig = BetRig(tester);
      final out = FakeOutput();
      final script = Script(sampleRows());
      await openGame(tester, rig, () => setupFor(rig, out, history: script.history, sessionStart: () => login));
      await tester.tap(key('top-history'));
      await settle(tester);
      out.events.clear();
      await tester.tap(key('history-row-0'));
      await settle(tester);
      expect(key('history-detail'), findsOneWidget);
      expect(tester.widget<Text>(key('history-detail-WINNING CARD')).data, 'King of Spades');
      expect(out.events, ['notification']);
      await rig.finish();
    });

    testWidgets('a player who has not played any round gets the dialog saying so', (tester) async {
      final rig = BetRig(tester);
      final script = Script(const []);
      await openGame(tester, rig, () => setupFor(rig, FakeOutput(), history: script.history, sessionStart: () => login));
      await tester.tap(key('top-history'));
      await settle(tester);
      expect(key('history-dialog'), findsOneWidget);
      expect(tester.widget<Text>(key('history-empty')).data, 'No rounds in this session yet');
      await rig.finish();
    });

    testWidgets('with no login time nothing is read, and the dialog says no rounds', (tester) async {
      final rig = BetRig(tester);
      final script = Script(sampleRows());
      await openGame(tester, rig, () => setupFor(rig, FakeOutput(), history: script.history));
      await tester.tap(key('top-history'));
      await settle(tester);
      expect(script.reads, isEmpty);
      expect(key('history-empty'), findsOneWidget);
      await rig.finish();
    });

    testWidgets('the login time is read when the button is tapped, each time', (tester) async {
      final rig = BetRig(tester);
      final script = Script(sampleRows());
      var current = login;
      await openGame(tester, rig, () => setupFor(rig, FakeOutput(), history: script.history, sessionStart: () => current));
      await tester.tap(key('top-history'));
      await settle(tester);
      await tester.tap(key('history-close'));
      await settle(tester);
      current = DateTime.utc(2026, 10, 22, 11);
      await tester.tap(key('top-history'));
      await settle(tester);
      expect(script.reads, [login, DateTime.utc(2026, 10, 22, 11)]);
      await rig.finish();
    });
  });

  group('"since logging in" is the shared AuthProvider\'s login time', () {
    testWidgets('read from sessionStartAt at each tap: a new login moves it, and no login reads nothing', (tester) async {
      final rig = BetRig(tester);
      final script = Script(sampleRows());
      final auth = LoginAuth()..start = login;
      await openGame(tester, rig, () => setupFor(rig, FakeOutput(), history: script.history, auth: auth));

      await tester.tap(key('top-history'));
      await settle(tester);
      expect(script.reads, [login]);
      expect(key('history-row-0'), findsOneWidget);
      await tester.tap(key('history-close'));
      await settle(tester);

      final later = DateTime.utc(2026, 10, 22, 12);
      auth.start = later;
      await tester.tap(key('top-history'));
      await settle(tester);
      expect(script.reads, [login, later], reason: 'a new login starts a new list');
      await tester.tap(key('history-close'));
      await settle(tester);

      auth.start = null;
      await tester.tap(key('top-history'));
      await settle(tester);
      expect(script.reads, [login, later], reason: 'with no login nothing is read');
      expect(key('history-empty'), findsOneWidget);
      await rig.finish();
    });

    testWidgets('a time said directly wins over the AuthProvider\'s', (tester) async {
      final rig = BetRig(tester);
      final script = Script(sampleRows());
      final auth = LoginAuth()..start = DateTime.utc(2026, 1, 1);
      await openGame(tester, rig, () => setupFor(rig, FakeOutput(), history: script.history, auth: auth, sessionStart: () => login));
      await tester.tap(key('top-history'));
      await settle(tester);
      expect(script.reads, [login]);
      await rig.finish();
    });
  });

  group('betting closing', () {
    testWidgets('the lock closes the dialog and its popup by itself, and the wheel is not hidden', (tester) async {
      final rig = BetRig(tester);
      final script = Script(sampleRows());
      await openGame(tester, rig, () => setupFor(rig, FakeOutput(), history: script.history, sessionStart: () => login));
      await tester.tap(key('top-history'));
      await settle(tester);
      await tester.tap(key('history-row-0'));
      await settle(tester);
      expect(key('history-detail'), findsOneWidget);
      await rig.world.runUntil(86.0);
      await settle(tester);
      expect(key('history-detail'), findsNothing);
      expect(key('history-dialog'), findsNothing);
      expect(onWheel, isTrue, reason: 'the wheel is not hidden behind it');
      await rig.finish();
    });

    testWidgets('from the lock the button is dimmed and a tap does nothing; it works again in the next round', (tester) async {
      final rig = BetRig(tester);
      final script = Script(sampleRows());
      await openGame(tester, rig, () => setupFor(rig, FakeOutput(), history: script.history, sessionStart: () => login));
      await rig.world.runUntil(86.0);
      await settle(tester);
      expect(dimmed('top-history'), isTrue);
      await tester.tap(key('top-history'), warnIfMissed: false);
      await settle(tester);
      expect(key('history-dialog'), findsNothing);
      expect(script.reads, isEmpty);

      await rig.runIntoNextCycle(8);
      await settle(tester);
      expect(dimmed('top-history'), isFalse);
      await tester.tap(key('top-history'));
      await settle(tester);
      expect(key('history-dialog'), findsOneWidget);
      await rig.finish();
    });
  });

  group('leaving with EXIT and coming back', () {
    testWidgets('the list is read again from the database and is the same; EXIT did not lose it', (tester) async {
      final rig = BetRig(tester);
      final script = Script(sampleRows());
      LuckyCardScreenSetup setup() => setupFor(rig, FakeOutput(), history: script.history, sessionStart: () => login);
      await openGame(tester, rig, setup);
      await tester.tap(key('top-history'));
      await settle(tester);
      expect(wordsIn(tester, key('history-row-0')), ['1', '17403942', 'K', '5X', '100', '+5,000']);
      await tester.tap(key('history-close'));
      await settle(tester);

      await tester.tap(key('top-exit'));
      await settle(tester);
      await tester.tap(key('exit-yes'));
      await settleAll(tester);
      expect(find.byType(LuckyCardScreen), findsNothing);

      await openGame(tester, rig, setup, pumped: true);
      await tester.tap(key('top-history'));
      await settle(tester);
      expect(script.reads, [login, login], reason: 'asked the database again');
      expect(wordsIn(tester, key('history-row-0')), ['1', '17403942', 'K', '5X', '100', '+5,000']);
      expect(wordsIn(tester, key('history-row-1')), ['2', '17403941', 'J', 'N', '50', '0']);
      await rig.finish();
    });

    testWidgets('a history the screen made is disposed with it; one it was given is not unless told to', (tester) async {
      for (final owns in [true, false]) {
        final rig = BetRig(tester);
        final probe = DisposeProbeHistory();
        await pumpAtSize(tester, phone, lobby(() => setupFor(rig, FakeOutput(), history: probe, ownsHistory: owns)));
        await tester.tap(key('go'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await rig.world.run(const Duration(seconds: 2));
        await settle(tester);
        await tester.tap(key('top-exit'));
        await settle(tester);
        await tester.tap(key('exit-yes'));
        await settleAll(tester);
        expect(find.byType(LuckyCardScreen), findsNothing);
        expect(probe.disposed, owns, reason: 'owns: $owns');
        if (!owns) probe.dispose();
        await rig.finish();
      }
    });

    testWidgets('given no history, the screen makes its own and the button works', (tester) async {
      final rig = BetRig(tester);
      // No history and no login time: the screen makes its own provider and, with no login, reads nothing.
      await openGame(tester, rig, () => LuckyCardScreenSetup(provider: rig.provider, art: art, setOrientation: false, sound: LuckyCardSound(FakeOutput())));
      await tester.tap(key('top-history'));
      await settle(tester);
      expect(key('history-dialog'), findsOneWidget);
      expect(key('history-empty'), findsOneWidget);
      await tester.tap(key('history-close'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await rig.finish();
    });
  });

  group('a picture to look at', () {
    Future<void> shoot(WidgetTester tester, Size size, String name, {bool popup = false}) async {
      final rig = BetRig(tester);
      final script = Script([
        row(round: 17403942, stake: 100, payout: 5000, rank: 'K', suit: 'spades', bonus: 5),
        row(round: 17403941, stake: 50, payout: 0),
        row(round: 17403940, stake: 480000, payout: 4800000, rank: 'Q', suit: 'diamonds'),
      ]);
      await openGame(tester, rig, () => setupFor(rig, FakeOutput(), history: script.history, sessionStart: () => login), size: size);
      await tester.tap(key('top-history'));
      await settle(tester);
      if (popup) {
        await tester.tap(key('history-row-0'));
        await settle(tester);
      }
      expect(tester.takeException(), isNull);
      // The popup's cards are real pictures: wait for them, so the picture never depends on which test ran first.
      await tester.runAsync(() async {
        for (final popup in ['history-dialog', 'history-detail']) {
          for (final e in find.descendant(of: key(popup), matching: find.byType(Image)).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
        }
      });
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${size.width.toInt()}x${size.height.toInt()}.png'));
      await rig.finish();
    }

    testWidgets('the History dialog open over the game: small phone 640x360', (tester) => shoot(tester, const Size(640, 360), 'screen_history'));
    testWidgets('a line\'s popup over the game: large phone 915x412', (tester) => shoot(tester, const Size(915, 412), 'screen_history_popup', popup: true));
  });

  group('a failed read', () {
    testWidgets('says so with RETRY on the real screen, and RETRY reads again', (tester) async {
      final rig = BetRig(tester);
      var fail = true;
      final reads = <DateTime?>[];
      final history = LuckyCardHistoryProvider(
        service: LuckyCardHistoryService(query: (since, limit) async {
          reads.add(since);
          if (fail) throw StateError('offline');
          return sampleRows();
        }),
      );
      await openGame(tester, rig, () => setupFor(rig, FakeOutput(), history: history, sessionStart: () => login));
      await tester.tap(key('top-history'));
      await settle(tester);
      expect(key('history-error'), findsOneWidget);
      fail = false;
      await tester.tap(key('history-retry'));
      await settle(tester);
      expect(reads.length, 2);
      expect(key('history-row-0'), findsOneWidget);
      await rig.finish();
    });
  });
}
