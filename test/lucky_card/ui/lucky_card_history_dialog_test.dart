// Tests for the Lucky Card History dialog (lucky_card_history_text.dart,
// lucky_card_history_dialog.dart): the words (pure), then the dialog on every device of the
// matrix, driven by the real game provider on the simulated server (for "it closes by itself
// when betting closes") and a scripted database read for the lines.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:best_smart_game/models/lucky_card_history_model.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_history_provider.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/services/lucky_card_history_service.dart';
import 'package:best_smart_game/services/lucky_card_round_sync.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_history_dialog.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_history_text.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_popup_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_wallet.dart';
import '../provider_rig.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

/// The sizes the new popup design is checked and pictured at, besides the device matrix. The popup is
/// laid out by screen size alone, so the two desktop sizes need no flag.
const List<Device> kPopupSizes = [
  Device('phone 800', 800, 360),
  Device('phone 844', 844, 390),
  Device('phone 915', 915, 412),
  Device('tablet 1180', 1180, 820),
  Device('tablet 1024', 1024, 768),
  Device('desktop 1920', 1920, 1080),
  Device('desktop 1366', 1366, 768),
];

final DateTime login = DateTime.utc(2026, 10, 22, 9);

/// A row shaped like the live answer.
Map<String, dynamic> row({
  int round = 100,
  int stake = 50,
  int payout = 0,
  String rank = 'J',
  String suit = 'hearts',
  int bonus = 1,
  String at = '2026-10-22T10:00:00+00:00',
}) =>
    {
      'round_id': 'id-$round',
      'total_stake': stake,
      'total_payout': payout,
      'created_at': at,
      'lucky_card_rounds': {
        'round_number': round,
        'winning_rank': rank,
        'winning_suit': suit,
        'bonus_multiplier': bonus,
      },
    };

/// Four lines, newest first: a 5X win, a loss, a plain win, a loss in a bonus round.
List<Map<String, dynamic>> sampleRows() => [
      row(round: 17403942, stake: 100, payout: 5000, rank: 'K', suit: 'spades', bonus: 5),
      row(round: 17403941, stake: 50, payout: 0, rank: 'J', suit: 'hearts'),
      row(round: 17403940, stake: 480000, payout: 4800000, rank: 'Q', suit: 'diamonds'),
      row(round: 17403939, stake: 300, payout: 0, rank: 'Q', suit: 'clubs', bonus: 3),
    ];

/// A history over a scripted read. [answer] decides what each read returns; every read is logged.
class Script {
  Script(this.answer);

  Future<List<dynamic>> Function() answer;
  final List<DateTime?> reads = [];

  late final LuckyCardHistoryProvider history = LuckyCardHistoryProvider(
    service: LuckyCardHistoryService(query: (since, limit) {
      reads.add(since);
      return answer();
    }),
  );
}

Script rowsScript(List<Map<String, dynamic>> rows) => Script(() async => rows);

class Log {
  final List<String> events = [];
}

/// A game provider that can say whether anything is still listening to it.
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

/// A screen with one button that opens the dialog, as the real screen's History button will.
Widget host(LuckyCardProvider game, LuckyCardHistoryProvider history, {Log? log, DateTime? since}) => ColoredBox(
      color: const Color(0xFF1A0505),
      child: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            key: const ValueKey('open'),
            onPressed: () => LuckyCardHistoryDialog.show(
              context,
              provider: game,
              history: history,
              since: since ?? login,
              onOpen: () => log?.events.add('open'),
              onRow: () => log?.events.add('row'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

Finder key(String k) => find.byKey(ValueKey(k));
Finder get dialog => key('history-dialog');
Finder get detail => key('history-detail');

Future<void> open(WidgetTester tester) async {
  await tester.tap(key('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

List<Text> textsIn(WidgetTester tester, Finder within) =>
    tester.widgetList<Text>(find.descendant(of: within, matching: find.byType(Text))).toList();

List<String> wordsIn(WidgetTester tester, Finder within) => [for (final t in textsIn(tester, within)) t.data ?? ''];

double smallestText(WidgetTester tester, Finder within) {
  var smallest = double.infinity;
  for (final t in textsIn(tester, within)) {
    final size = t.style?.fontSize;
    expect(size, isNotNull, reason: '"${t.data}" sets its own size');
    if (size! < smallest) smallest = size;
  }
  return smallest;
}

void main() {
  setUpAll(() async {
    await loadLuckyCardFonts();
    await loadLuckyCardIcons();
  });

  group('the words and numbers (pure)', () {
    final win = LuckyCardHistoryEntry.fromRow(row(round: 17403942, stake: 100, payout: 5000, rank: 'K', suit: 'spades', bonus: 5));
    final loss = LuckyCardHistoryEntry.fromRow(row(round: 17403941, stake: 50, payout: 0, bonus: 3));
    final plainWin = LuckyCardHistoryEntry.fromRow(row(stake: 480000, payout: 4800000));

    test('a card is written in words, for all 12', () {
      expect(luckyCardCardWords(const LuckyCard(LuckyCardRank.queen, LuckyCardSuit.spades)), 'Queen of Spades');
      expect(luckyCardCardWords(const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts)), 'Jack of Hearts');
      expect(luckyCardCardWords(const LuckyCard(LuckyCardRank.king, LuckyCardSuit.clubs)), 'King of Clubs');
      expect(LuckyCard.all.map(luckyCardCardWords).toSet().length, 12);
    });

    test('PLAY and WIN are written as the game screen writes them', () {
      expect(luckyCardHistoryPlayText(plainWin), '480,000');
      expect(luckyCardHistoryWinText(plainWin), '+4,800,000');
      expect(luckyCardHistoryWinText(loss), '0');
      expect(luckyCardHistoryPlayText(loss), '50');
    });

    test('the detail has four facts: the round, the card in words, the bonus and the total bet', () {
      expect(luckyCardHistoryDetailLines(win), [
        ('ROUND', '17403942'),
        ('WINNING CARD', 'King of Spades'),
        ('BONUS', '5X'),
        ('TOTAL BET', '100 coins'),
      ]);
      expect(luckyCardHistoryDetailLines(loss), [
        ('ROUND', '17403941'),
        ('WINNING CARD', 'Jack of Hearts'),
        ('BONUS', '3X'),
        ('TOTAL BET', '50 coins'),
      ]);
      expect(luckyCardHistoryDetailLines(plainWin)[2], ('BONUS', 'N'));
      expect(luckyCardHistoryDetailBadge(3), 'NO. 3');
    });

    test('what a screen reader says for a line', () {
      expect(luckyCardHistoryRowSemantics(win, 1), 'Line 1, round 17403942, played 100, won 5,000. Tap for details.');
      expect(luckyCardHistoryRowSemantics(loss, 2), 'Line 2, round 17403941, played 50, no win. Tap for details.');
    });

    test('every word is plain letters: the fonts have no card-suit symbols', () {
      final all = [
        kLuckyCardHistoryTitle,
        kLuckyCardHistoryNoHeader,
        kLuckyCardHistoryRoundHeader,
        kLuckyCardHistoryResultHeader,
        kLuckyCardHistoryPlayHeader,
        kLuckyCardHistoryWinHeader,
        kLuckyCardHistoryRoundsStat,
        kLuckyCardHistoryPlayStat,
        kLuckyCardHistoryWinStat,
        kLuckyCardHistoryHint,
        kLuckyCardHistoryLoading,
        kLuckyCardHistoryEmpty,
        kLuckyCardHistoryRetry,
        kLuckyCardHistoryStale,
        kLuckyCardHistorySemanticsLabel,
        LuckyCardHistoryProvider.loadErrorText,
        for (final e in [win, loss, plainWin]) ...[
          luckyCardHistoryRowSemantics(e, 1),
          for (final l in luckyCardHistoryDetailLines(e)) ...[l.$1, l.$2],
        ],
        for (final card in LuckyCard.all) luckyCardCardWords(card),
      ];
      for (final s in all) {
        expect(s.codeUnits.every((c) => c < 128), isTrue, reason: s);
      }
    });
  });

  group('the dialog opens, reads, and shows the lines', () {
    testWidgets('it reads everything since login once on open, and shows the title and column headings', (tester) async {
      final rig = BetRig(tester);
      final script = rowsScript(sampleRows());
      final log = Log();
      await pumpAtSize(tester, phone, host(rig.provider, script.history, log: log));
      expect(dialog, findsNothing);
      await open(tester);
      expect(dialog, findsOneWidget);
      expect(log.events, ['open']);
      expect(script.reads, [login]);
      expect(wordsIn(tester, dialog), containsAll(['HISTORY', 'ROUNDS', 'TOTAL PLAY', 'TOTAL WIN', 'NO.', 'ROUND', 'RESULT', 'PLAY', 'WIN', kLuckyCardHistoryHint]));
      expect(find.text('NET'), findsNothing, reason: 'Hasan: only ROUNDS, TOTAL PLAY and TOTAL WIN');
      expect(find.text('TOTAL SESSION'), findsNothing);
      await rig.finish();
    });

    testWidgets('each line shows its number, round, card, bonus, what was staked and what was won, in order', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history));
      await open(tester);
      expect(wordsIn(tester, key('history-row-0')), ['1', '17403942', 'K', '5X', '100', '+5,000']);
      expect(wordsIn(tester, key('history-row-1')), ['2', '17403941', 'J', 'N', '50', '0']);
      expect(wordsIn(tester, key('history-row-2')), ['3', '17403940', 'Q', 'N', '480,000', '+4,800,000']);
      expect(wordsIn(tester, key('history-row-3')), ['4', '17403939', 'Q', '3X', '300', '0']);
      await rig.finish();
    });

    testWidgets('a winning line has a green strip and a losing line a red one', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history));
      await open(tester);
      BoxDecoration strip(int i) => tester.widget<Container>(key('history-strip-$i')).decoration! as BoxDecoration;
      expect(strip(0).gradient, isNotNull, reason: 'green');
      expect(strip(1).color, kLuckyCardLossRed);
      expect(strip(2).gradient, isNotNull, reason: 'green');
      expect(strip(3).color, kLuckyCardLossRed, reason: 'a loss in a bonus round is still a loss');
      await rig.finish();
    });

    testWidgets('the stat boxes add up exactly the lines under them', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history));
      await open(tester);
      expect(wordsIn(tester, key('history-stat-rounds')), ['ROUNDS', '4']);
      expect(wordsIn(tester, key('history-total-play')), ['TOTAL PLAY', '480,450']);
      expect(wordsIn(tester, key('history-total-win')), ['TOTAL WIN', '4,805,000']);
      await rig.finish();
    });

    testWidgets('a session with no win shows a plain 0 for the total won', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript([row(stake: 50, payout: 0)]).history));
      await open(tester);
      expect(wordsIn(tester, key('history-total-win')), ['TOTAL WIN', '0']);
      expect(wordsIn(tester, key('history-total-play')), ['TOTAL PLAY', '50']);
      await rig.finish();
    });

    testWidgets('it reads again every time it is opened and shows what the database now holds', (tester) async {
      final rig = BetRig(tester);
      final rows = [row(round: 2, stake: 5)];
      final script = Script(() async => rows);
      await pumpAtSize(tester, phone, host(rig.provider, script.history));
      await open(tester);
      expect(key('history-row-1'), findsNothing);
      await tester.tap(key('history-close'));
      await settle(tester);

      rows.insert(0, row(round: 3, stake: 10));
      await open(tester);
      expect(script.reads.length, 2);
      expect(wordsIn(tester, key('history-row-0')), ['1', '3', 'J', 'N', '10', '0']);
      expect(key('history-row-1'), findsOneWidget);
      await rig.finish();
    });
  });

  group('what it says when there are no lines', () {
    testWidgets('while the first read is on its way it says so, then shows the lines', (tester) async {
      final rig = BetRig(tester);
      final gate = Completer<List<dynamic>>();
      final script = Script(() => gate.future);
      await pumpAtSize(tester, phone, host(rig.provider, script.history));
      await open(tester);
      expect(key('history-loading'), findsOneWidget);
      expect(tester.widget<Text>(key('history-loading')).data, 'Loading session history...');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete(sampleRows());
      await settle(tester);
      expect(key('history-loading'), findsNothing);
      expect(key('history-row-0'), findsOneWidget);
      await rig.finish();
    });

    testWidgets('on its very first frame it already says loading, never "no rounds yet"', (tester) async {
      final rig = BetRig(tester);
      final gate = Completer<List<dynamic>>();
      final script = Script(() => gate.future);
      await pumpAtSize(tester, phone, host(rig.provider, script.history));
      await tester.tap(key('open'));
      await tester.pump();
      expect(dialog, findsOneWidget);
      expect(key('history-loading'), findsOneWidget);
      expect(key('history-empty'), findsNothing);
      gate.complete(const []);
      await settle(tester);
      expect(key('history-empty'), findsOneWidget);
      await rig.finish();
    });

    testWidgets('no rounds since login says so', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(const []).history));
      await open(tester);
      expect(tester.widget<Text>(key('history-empty')).data, 'No rounds in this session yet');
      expect(key('history-total-play'), findsNothing);
      await rig.finish();
    });

    testWidgets('a failed first read says so with a RETRY button, and RETRY reads again', (tester) async {
      final rig = BetRig(tester);
      var fail = true;
      final script = Script(() async {
        if (fail) throw StateError('offline');
        return sampleRows();
      });
      await pumpAtSize(tester, phone, host(rig.provider, script.history));
      await open(tester);
      expect(tester.widget<Text>(key('history-error')).data, 'Could not load history. Tap to retry.');
      expect(key('history-empty'), findsNothing, reason: 'an error is never shown as "no rounds yet"');
      expect(tester.getSize(key('history-retry')).height, greaterThanOrEqualTo(kLuckyCardMinTapDp));
      fail = false;
      await tester.tap(key('history-retry'));
      await settle(tester);
      expect(script.reads.length, 2);
      expect(key('history-error'), findsNothing);
      expect(key('history-row-0'), findsOneWidget);
      await rig.finish();
    });

    testWidgets('a later read that fails keeps the earlier lines, with a line over them that retries when tapped', (tester) async {
      final rig = BetRig(tester);
      var fail = false;
      final script = Script(() async {
        if (fail) throw StateError('offline');
        return sampleRows();
      });
      await pumpAtSize(tester, phone, host(rig.provider, script.history));
      await open(tester);
      expect(key('history-stale'), findsNothing);
      await tester.tap(key('history-close'));
      await settle(tester);

      fail = true;
      await open(tester);
      expect(key('history-row-0'), findsOneWidget, reason: 'the earlier list is still shown');
      expect(key('history-stale'), findsOneWidget);
      expect(tester.widget<Text>(find.descendant(of: key('history-stale'), matching: find.byType(Text))).data, kLuckyCardHistoryStale);

      fail = false;
      await tester.tap(key('history-stale'));
      await settle(tester);
      expect(key('history-stale'), findsNothing);
      expect(key('history-row-0'), findsOneWidget);
      await rig.finish();
    });
  });

  group('a line opens a popup with the details', () {
    testWidgets('a winning line: the badge, the amount, the picture and the four facts, and the click hook is told', (tester) async {
      final rig = BetRig(tester);
      final log = Log();
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history, log: log));
      await open(tester);
      expect(detail, findsNothing);
      await tester.tap(key('history-row-0'));
      await settle(tester);
      expect(detail, findsOneWidget);
      expect(log.events, ['open', 'row']);
      expect(tester.widget<Text>(key('history-detail-badge')).data, 'NO. 1');
      expect(tester.widget<Text>(key('history-detail-amount')).data, '+5,000');
      expect(key('history-detail-card-k_spades'), findsOneWidget);
      expect(find.descendant(of: key('history-detail-bonus'), matching: find.text('5X')), findsOneWidget);
      expect(tester.widget<Text>(key('history-detail-ROUND')).data, '17403942');
      expect(tester.widget<Text>(key('history-detail-WINNING CARD')).data, 'King of Spades');
      expect(tester.widget<Text>(key('history-detail-BONUS')).data, '5X');
      expect(tester.widget<Text>(key('history-detail-TOTAL BET')).data, '100 coins');
      await rig.finish();
    });

    testWidgets('a losing line says NO WIN, with its own numbers', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history));
      await open(tester);
      await tester.tap(key('history-row-3'));
      await settle(tester);
      expect(tester.widget<Text>(key('history-detail-badge')).data, 'NO. 4');
      expect(tester.widget<Text>(key('history-detail-headline')).data, 'NO WIN');
      expect(key('history-detail-amount'), findsNothing);
      expect(tester.widget<Text>(key('history-detail-WINNING CARD')).data, 'Queen of Clubs');
      expect(tester.widget<Text>(key('history-detail-BONUS')).data, '3X');
      await rig.finish();
    });

    testWidgets('the popup\'s close button, and a tap outside it, close only the popup', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history));
      await open(tester);
      await tester.tap(key('history-row-0'));
      await settle(tester);
      await tester.tap(key('history-detail-close'));
      await settle(tester);
      expect(detail, findsNothing);
      expect(dialog, findsOneWidget, reason: 'the list is still there');

      await tester.tap(key('history-row-1'));
      await settle(tester);
      expect(detail, findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await settle(tester);
      expect(detail, findsNothing);
      expect(dialog, findsOneWidget);
      await rig.finish();
    });

    testWidgets('a tap inside the popup does not close it', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history));
      await open(tester);
      await tester.tap(key('history-row-0'));
      await settle(tester);
      await tester.tap(key('history-detail-headline'));
      await settle(tester);
      expect(detail, findsOneWidget);
      await rig.finish();
    });
  });

  group('the dialog closes', () {
    testWidgets('the close button, and a tap outside, close it', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history));
      await open(tester);
      await tester.tap(key('history-close'));
      await settle(tester);
      expect(dialog, findsNothing);

      await open(tester);
      await tester.tapAt(const Offset(4, 4));
      await settle(tester);
      expect(dialog, findsNothing);

      await open(tester);
      expect(dialog, findsOneWidget, reason: 'it can be opened again');
      await rig.finish();
    });

    testWidgets('two quick activations of close close the dialog once, not the game screen behind it', (tester) async {
      final rig = BetRig(tester);
      final script = rowsScript(sampleRows());
      await pumpAtSize(
        tester,
        phone,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('lobby-go'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(body: host(rig.provider, script.history)))),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(key('lobby-go'));
      await settle(tester);
      expect(key('open'), findsOneWidget);

      final handle = tester.ensureSemantics();
      await open(tester);
      final close = find.semantics.byPredicate((n) => n.label == 'Close' && n.getSemanticsData().flagsCollection.isButton);
      tester.semantics.performAction(close, ui.SemanticsAction.tap);
      tester.semantics.performAction(close, ui.SemanticsAction.tap);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(dialog, findsNothing);
      expect(key('open'), findsOneWidget, reason: 'still in the game after two activations');
      expect(key('lobby-go'), findsNothing, reason: 'the lobby is still covered');
      handle.dispose();
      await rig.finish();
    });

    testWidgets('it stays open while betting is open, however long the player reads', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history));
      await rig.open();
      await open(tester);
      await rig.world.runUntil(60.0);
      expect(rig.provider.isLocked, isFalse);
      expect(dialog, findsOneWidget);
      await rig.world.runUntil(80.0);
      expect(dialog, findsOneWidget);
      await rig.finish();
    });
  });

  group('it closes by itself when betting closes', () {
    Future<void> runToLock(BetRig rig) async {
      var guard = 0;
      while (!rig.provider.isLocked && ++guard < 800) {
        await rig.world.run(const Duration(milliseconds: 50));
      }
      expect(rig.provider.isLocked, isTrue);
      await rig.world.run(const Duration(milliseconds: 500));
    }

    testWidgets('open at second 70, it fades away at the lock', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history));
      await rig.open();
      await rig.world.runUntil(70.0);
      await open(tester);
      expect(dialog, findsOneWidget);
      await runToLock(rig);
      expect(dialog, findsNothing);
      await rig.finish();
    });

    testWidgets('with a line\'s popup open on top, both go at the lock, with nothing left over', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history));
      await rig.open();
      await rig.world.runUntil(70.0);
      await open(tester);
      await tester.tap(key('history-row-0'));
      await settle(tester);
      expect(detail, findsOneWidget);
      await runToLock(rig);
      expect(tester.takeException(), isNull);
      expect(detail, findsNothing);
      expect(dialog, findsNothing);
      expect(key('open'), findsOneWidget, reason: 'the screen behind is still there');
      await rig.finish();
    });

    testWidgets('opened after the lock, it closes again at once and reads nothing', (tester) async {
      final rig = BetRig(tester);
      final script = rowsScript(sampleRows());
      await pumpAtSize(tester, phone, host(rig.provider, script.history));
      await rig.open();
      await rig.world.runUntil(86.0);
      expect(rig.provider.isLocked, isTrue);
      await open(tester);
      await settle(tester);
      expect(dialog, findsNothing);
      expect(script.reads, isEmpty);
      await rig.finish();
    });

    testWidgets('another dialog on top of it (the screen\'s own message) stays, only the history goes', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history));
      await rig.open();
      await rig.world.runUntil(70.0);
      await open(tester);
      showDialog<void>(
        context: tester.element(key('open')),
        builder: (_) => const AlertDialog(key: ValueKey('other-dialog'), title: Text('Connection lost')),
      );
      await settle(tester);
      expect(key('other-dialog'), findsOneWidget);
      await runToLock(rig);
      expect(tester.takeException(), isNull);
      expect(dialog, findsNothing, reason: 'the history closed at the lock');
      expect(key('other-dialog'), findsOneWidget, reason: 'the message on top was not taken away');
      await rig.finish();
    });

    testWidgets('closing by hand, then the lock, does not close anything twice or throw', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history));
      await rig.open();
      await rig.world.runUntil(70.0);
      await open(tester);
      await tester.tap(key('history-close'));
      await settle(tester);
      await rig.world.runUntil(88.0);
      expect(tester.takeException(), isNull);
      expect(key('open'), findsOneWidget);
      await rig.finish();
    });

    testWidgets('it stops listening to the game once it and its popup are closed', (tester) async {
      final rig = BetRig(tester);
      final probe = ProbeProvider(rig);
      await pumpAtSize(tester, phone, host(probe, rowsScript(sampleRows()).history));
      expect(probe.listenedTo, isFalse);
      await open(tester);
      expect(probe.listenedTo, isTrue);
      await tester.tap(key('history-row-0'));
      await settle(tester);
      await tester.tap(key('history-detail-close'));
      await settle(tester);
      await tester.tap(key('history-close'));
      await settle(tester);
      expect(probe.listenedTo, isFalse);
      probe.dispose();
      await rig.finish();
    });

    testWidgets('a read that finishes after the dialog has closed does no harm', (tester) async {
      final rig = BetRig(tester);
      final gate = Completer<List<dynamic>>();
      final script = Script(() => gate.future);
      await pumpAtSize(tester, phone, host(rig.provider, script.history));
      await open(tester);
      await tester.tap(key('history-close'));
      await settle(tester);
      gate.complete(sampleRows());
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(script.history.records.length, 4);
      await rig.finish();
    });
  });

  group('every device of the matrix', () {
    for (final d in [...kDeviceMatrix, ...kPopupSizes]) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): it fits, every tap area is 48 dp, text is 11 dp, every line is reachable', (tester) async {
        final rig = BetRig(tester);
        final many = [for (var i = 0; i < 40; i++) row(round: 17403000 + i, stake: 10 + i, payout: i.isEven ? 100 : 0, bonus: i % 5 + 1)];
        await pumpAtSize(tester, d.size, host(rig.provider, rowsScript(many).history));
        await open(tester);
        final l = LuckyCardLayout.of(d.size);

        final box = tester.getRect(dialog);
        final screen = Offset.zero & d.size;
        expect(screen.contains(box.topLeft) && screen.contains(box.bottomRight), isTrue, reason: 'inside the screen: $box');
        expect(box.center.dx, closeTo(l.canvasRect.center.dx, 0.5));
        expect(box.center.dy, closeTo(l.canvasRect.center.dy, 0.5));
        expect(box.width, closeTo(l.canvasRect.width * LuckyCardHistoryDialog.widthShare, 0.5));

        final close = tester.getRect(key('history-close'));
        expect(close.width, greaterThanOrEqualTo(kLuckyCardMinTapDp - 0.001), reason: 'close width');
        expect(close.height, greaterThanOrEqualTo(kLuckyCardMinTapDp - 0.001), reason: 'close height');
        expect(smallestText(tester, dialog), greaterThanOrEqualTo(kLuckyCardMinReadableDp));

        // Rows that are on screen are 48 dp tall at least, and inside the dialog.
        final row0 = tester.getRect(key('history-row-0'));
        // 0.001 dp of slack: a line is exactly 48 dp on the smallest phones, and the open
        // animation's scale can leave a last bit of rounding (47.99999999999999).
        expect(row0.height, greaterThanOrEqualTo(kLuckyCardMinTapDp - 0.001), reason: 'a line is a tap area');
        expect(box.contains(row0.topLeft) && box.contains(row0.bottomRight - const Offset(0.01, 0.01)), isTrue);

        // The stat boxes are always on screen, inside the dialog, and the last line can be scrolled to.
        final foot = tester.getRect(key('history-total-play'));
        expect(box.contains(foot.center), isTrue, reason: 'the stat boxes are inside the dialog');
        await tester.dragUntilVisible(key('history-row-39'), key('history-list'), const Offset(0, -200));
        await tester.pump();
        final last = tester.getRect(key('history-row-39'));
        final list = tester.getRect(key('history-list'));
        expect(last.bottom, lessThanOrEqualTo(list.bottom + 0.5), reason: 'the last line is reachable');
        expect(tester.takeException(), isNull);

        // The popup of a line fits the screen and its buttons are 48 dp.
        await tester.dragUntilVisible(key('history-row-0'), key('history-list'), const Offset(0, 200));
        await tester.pump();
        await tester.tap(key('history-row-0'));
        await settle(tester);
        final pop = tester.getRect(detail);
        expect(screen.contains(pop.topLeft) && screen.contains(pop.bottomRight), isTrue, reason: 'popup inside the screen: $pop');
        final pclose = tester.getRect(key('history-detail-close'));
        expect(pclose.width, greaterThanOrEqualTo(kLuckyCardMinTapDp - 0.001));
        expect(pclose.height, greaterThanOrEqualTo(kLuckyCardMinTapDp - 0.001));
        expect(smallestText(tester, detail), greaterThanOrEqualTo(kLuckyCardMinReadableDp));
        expect(tester.takeException(), isNull);
        await rig.finish();
      });
    }

    for (final d in [...kDeviceMatrix, ...kPopupSizes]) {
      testWidgets('${d.name}: no stat label is squeezed: each stays on one line beside its figure', (tester) async {
        final rig = BetRig(tester);
        await pumpAtSize(tester, d.size, host(rig.provider, rowsScript([row(stake: 600000, payout: 60000000)]).history));
        await open(tester);
        for (final (k, label) in const [
          ('history-stat-rounds', 'ROUNDS'),
          ('history-total-play', 'TOTAL PLAY'),
          ('history-total-win', 'TOTAL WIN'),
        ]) {
          final box = tester.getRect(key(k));
          final text = tester.getRect(find.descendant(of: key(k), matching: find.text(label)));
          expect(box.contains(text.topLeft) && box.contains(text.bottomRight - const Offset(0.01, 0.01)), isTrue, reason: label);
        }
        expect(tester.getRect(key('history-total-play')).width, closeTo(tester.getRect(key('history-total-win')).width, 0.5));
        expect(tester.takeException(), isNull);
        await rig.finish();
      });
    }

    testWidgets('the biggest numbers still fit their columns on the smallest phone', (tester) async {
      final rig = BetRig(tester);
      final script = rowsScript([row(round: 17403942, stake: 600000, payout: 60000000, bonus: 10)]);
      await pumpAtSize(tester, const Size(640, 360), host(rig.provider, script.history));
      await open(tester);
      final cell = tester.getRect(key('history-row-0'));
      for (final t in find.descendant(of: key('history-row-0'), matching: find.byType(Text)).evaluate()) {
        final r = tester.getRect(find.byWidget(t.widget));
        expect(r.left, greaterThanOrEqualTo(cell.left - 0.5), reason: (t.widget as Text).data);
        expect(r.right, lessThanOrEqualTo(cell.right + 0.5), reason: (t.widget as Text).data);
      }
      expect(wordsIn(tester, key('history-row-0')), ['1', '17403942', 'J', '10X', '600,000', '+60,000,000']);
      await rig.finish();
    });
  });

  group('the phone\'s font-size setting changes nothing', () {
    testWidgets('at 3 times the text every size and the dialog\'s box stay the same', (tester) async {
      const size = Size(640, 360);
      final rig = BetRig(tester);
      final script = rowsScript(sampleRows());
      await pumpAtSize(tester, size, host(rig.provider, script.history));
      await open(tester);
      final box = tester.getRect(dialog);
      final sizes = [for (final t in textsIn(tester, dialog)) '${t.data}:${t.style!.fontSize}'];

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpAtSize(tester, size, host(rig.provider, script.history), textScale: 3);
      await open(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(dialog), box);
      expect([for (final t in textsIn(tester, dialog)) '${t.data}:${t.style!.fontSize}'], sizes);
      for (final t in textsIn(tester, dialog)) {
        expect(t.textScaler, TextScaler.noScaling, reason: '"${t.data}"');
      }
      await rig.finish();
    });
  });

  group('a screen reader', () {
    testWidgets('hears the dialog, each line as a button with its facts, and the close button', (tester) async {
      final handle = tester.ensureSemantics();
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider, rowsScript(sampleRows()).history));
      await open(tester);
      expect(find.bySemanticsLabel('Game history'), findsWidgets);
      expect(find.bySemanticsLabel('Close'), findsWidgets);
      final line = tester.getSemantics(find.bySemanticsLabel('Line 1, round 17403942, played 100, won 5,000. Tap for details.'));
      expect(line.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(find.bySemanticsLabel('Line 2, round 17403941, played 50, no win. Tap for details.'), findsOneWidget);
      handle.dispose();
      await rig.finish();
    });
  });

  group('a picture to look at', () {
    Future<void> shoot(WidgetTester tester, Device d, String name, {int? tapRow, List<Map<String, dynamic>>? rows, bool fail = false, bool loading = false}) async {
      final rig = BetRig(tester);
      final gate = Completer<List<dynamic>>();
      final script = loading
          ? Script(() => gate.future)
          : fail
              ? Script(() async => throw StateError('offline'))
              : rowsScript(rows ?? sampleRows());
      await pumpAtSize(tester, d.size, host(rig.provider, script.history));
      await open(tester);
      if (tapRow != null) {
        await tester.tap(key('history-row-$tapRow'));
        await settle(tester);
      }
      expect(tester.takeException(), isNull);
      // The cards are real pictures: wait for them, so the picture never depends on which test ran first.
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${d.width.toInt()}x${d.height.toInt()}.png'));
      if (loading) gate.complete(const []);
      await rig.finish();
    }

    for (final d in const [Device('small phone', 640, 360), ...kPopupSizes]) {
      final size = '${d.width.toInt()}x${d.height.toInt()}';
      testWidgets('the list: $size', (tester) => shoot(tester, d, 'history_list'));
      testWidgets('a win\'s popup: $size', (tester) => shoot(tester, d, 'history_win', tapRow: 0));
      testWidgets('a loss\'s popup: $size', (tester) => shoot(tester, d, 'history_loss', tapRow: 1));
      testWidgets('no rounds yet: $size', (tester) => shoot(tester, d, 'history_empty', rows: const []));
      testWidgets('a failed read: $size', (tester) => shoot(tester, d, 'history_error', fail: true));
      testWidgets('loading: $size', (tester) => shoot(tester, d, 'history_loading', loading: true));
    }
  });
}
