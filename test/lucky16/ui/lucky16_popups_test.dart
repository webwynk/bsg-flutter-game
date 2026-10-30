// Tests for the Lucky 16 Card popups (phone phase 6), the new design Hasan approved with Lucky Card's
// behaviour: Info (RULES and PAYOUTS), Exit, History and the round detail. On the real screen
// (lib/screens/lucky16_screen.dart) over the simulated server, opened from the header's buttons. The
// golden pictures are copied to reference-design/lucky16/screenshots/phase6/.

import 'package:best_smart_game/models/lucky16_board.dart';
import 'package:best_smart_game/providers/lucky16_history_provider.dart';
import 'package:best_smart_game/screens/lucky16_screen.dart';
import 'package:best_smart_game/services/lucky16_history_service.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_exit_dialog.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_history_text.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_info_text.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'lucky16_board_test.dart' show loadArt, tapPiece;
import 'lucky16_screen_test.dart' show key, openGame, phone, settle;
import 'ui_harness.dart';

/// One row as the database gives it.
Map<String, dynamic> row(int number, String rank, String suit, int bonus, int stake, int payout) => {
      'round_id': 'round-$number',
      'total_stake': stake,
      'total_payout': payout,
      'created_at': '2026-10-28T18:05:04.680622+00:00',
      'lucky16_rounds': {
        'round_number': number,
        'winning_rank': rank,
        'winning_suit': suit,
        'bonus_multiplier': bonus,
      },
    };

/// A session of five rounds, newest first: two wins and three losses, one with each kind of bonus.
final List<Map<String, dynamic>> sampleRows = [
  row(17403945, 'A', 'spades', 4, 200, 560),
  row(17403944, 'Q', 'hearts', 1, 100, 0),
  row(17403943, 'K', 'diamonds', 10, 50, 0),
  row(17403942, 'J', 'clubs', 2, 300, 280),
  row(17403941, 'A', 'hearts', 1, 40, 0),
];

/// A history provider over a scripted read: [rows], or a failure while [fail] says so.
class Script {
  Script(this.rows);

  List<Map<String, dynamic>> rows;
  bool fail = false;
  int reads = 0;
  DateTime? since;

  late final Lucky16HistoryProvider provider = Lucky16HistoryProvider(
    service: Lucky16HistoryService(
      query: (since, limit) async {
        reads++;
        this.since = since;
        if (fail) throw StateError('no connection');
        return rows;
      },
    ),
  );
}

Future<void> open(WidgetTester tester, BetRig rig, String button) async {
  await tester.tap(key(button));
  await settle(tester);
}

/// The whole of the text under [k].
List<String> textsIn(WidgetTester tester, String k) =>
    tester.widgetList<Text>(find.descendant(of: key(k), matching: find.byType(Text))).map((t) => t.data ?? '').toList();

String textOf(WidgetTester tester, String k) => tester.widget<Text>(key(k)).data ?? '';

/// Runs the round on until betting closes.
Future<void> runToLock(WidgetTester tester, BetRig rig) async {
  var guard = 0;
  while (!rig.provider.isLocked && ++guard < 2000) {
    await rig.world.run(const Duration(milliseconds: 500));
  }
  await settle(tester);
}

void main() {
  setUpAll(() async {
    await loadLucky16Fonts();
    await loadLucky16Icons();
  });

  group('the Info popup', () {
    testWidgets('INFO opens it, 80% x 92% of the canvas, on RULES, with the numbers from the game', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await open(tester, rig, 'top-info');
      final layout = Lucky16Layout.of(phone);
      final size = tester.getSize(key('info-dialog'));
      expect(size.width, closeTo(layout.canvasSize.width * 0.8, 0.01));
      expect(size.height, closeTo(layout.canvasSize.height * 0.92, 0.01));
      expect(find.text(kLucky16InfoTitle), findsWidgets);
      expect(textOf(tester, 'rule-0'), 'Choose 5, 10, 50, 100 or 500, then tap a card to put the chip on it.');
      expect(textOf(tester, 'rule-2'), contains('from 5 to 10,000 on each card'));
      expect(textOf(tester, 'rule-3'), contains('reaches 5'));
      expect(textOf(tester, 'rule-5'), contains('14 times'));
      expect(tester.takeException(), isNull);
      await rig.finish();
    });

    testWidgets('PAYOUTS: the formula, the example and 10 x 14 x the bonus for N to 10X', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await open(tester, rig, 'top-info');
      await tapPiece(tester, 'info-tab-payouts');
      const wins = ['140', '280', '420', '560', '700', '840', '980', '1,120', '1,260', '1,400'];
      const bonuses = ['N', '2X', '3X', '4X', '5X', '6X', '7X', '8X', '9X', '10X'];
      for (var i = 0; i < 10; i++) {
        expect(textsIn(tester, 'payout-${bonuses[i]}'), [bonuses[i], wins[i]]);
      }
      expect(textOf(tester, 'payout-example'), contains('you get 140. With a 4X bonus you get 560.'));
      expect(textOf(tester, 'payout-limits'),
          'The smallest stake on a card, 5, wins 70. The largest, 10,000, wins 140,000 before the bonus, and the bonus multiplies it.');
      expect(textsIn(tester, 'payout-formula').where((t) => t != 'x'), ['STAKE', '14', 'BONUS']);
      expect(kLucky16MaxStake, 10000);
      expect(tester.takeException(), isNull);
      await rig.finish();
    });

    testWidgets('the tabs and the close button answer over 48 dp; a tap outside closes it', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await open(tester, rig, 'top-info');
      for (final k in ['info-tab-rules', 'info-tab-payouts', 'info-close']) {
        expect(tester.getSize(key(k)).height, greaterThanOrEqualTo(kLucky16MinTapDp), reason: k);
      }
      await tapPiece(tester, 'info-close');
      expect(key('info-dialog'), findsNothing);
      await open(tester, rig, 'top-info');
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);
      expect(key('info-dialog'), findsNothing);
      await rig.finish();
    });

    testWidgets('it closes by itself when betting closes', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await open(tester, rig, 'top-info');
      expect(key('info-dialog'), findsOneWidget);
      await runToLock(tester, rig);
      expect(key('info-dialog'), findsNothing);
      await rig.finish();
    });
  });

  group('the Exit popup', () {
    testWidgets('EXIT asks; NO stays; YES leaves the screen', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await open(tester, rig, 'top-exit');
      expect(key('exit-dialog'), findsOneWidget);
      expect(find.text(kLucky16ExitTitle), findsWidgets);
      expect(textOf(tester, 'exit-message'), 'Do you want to exit?');
      await tapPiece(tester, 'exit-no');
      expect(key('exit-dialog'), findsNothing);
      expect(find.byType(Lucky16Screen), findsOneWidget);
      await open(tester, rig, 'top-exit');
      await tester.tap(key('exit-yes'));
      for (var i = 0; i < 4; i++) {
        await settle(tester);
      }
      expect(find.byType(Lucky16Screen), findsNothing);
      expect(tester.takeException(), isNull);
      await rig.finish();
    });

    testWidgets('the back gesture asks too, and a second back answers "stay"', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      await openGame(tester, rig);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      await navigator.maybePop();
      await settle(tester);
      expect(key('exit-dialog'), findsOneWidget);
      await navigator.maybePop();
      await settle(tester);
      expect(key('exit-dialog'), findsNothing);
      expect(find.byType(Lucky16Screen), findsOneWidget);
      await rig.finish();
    });

    testWidgets('a tap outside does nothing; the bar drains and after 5 s it answers "stay"', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      await openGame(tester, rig);
      await tester.tap(key('top-exit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(textOf(tester, 'exit-countdown'), 'STAYING IN 5S');
      final full = tester.getSize(key('exit-bar')).width;
      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(seconds: 2));
      expect(key('exit-dialog'), findsOneWidget, reason: 'a tap outside does not dismiss it');
      expect(textOf(tester, 'exit-countdown'), 'STAYING IN 3S');
      final left = tester.getSize(find.descendant(of: key('exit-bar'), matching: find.byType(DecoratedBox)).last).width;
      expect(left, lessThan(full * 0.65));
      await tester.pump(const Duration(milliseconds: 3000));
      await settle(tester);
      expect(key('exit-dialog'), findsNothing);
      expect(find.byType(Lucky16Screen), findsOneWidget);
      await rig.finish();
    });
  });

  group('the History popup', () {
    testWidgets('HISTORY reads the session and shows the stats and the rounds, newest first', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final script = Script(sampleRows);
      await openGame(tester, rig, history: script.provider);
      await open(tester, rig, 'top-history');
      expect(script.reads, 1);
      expect(script.since, DateTime.utc(2026, 10, 28), reason: 'since the login');
      final layout = Lucky16Layout.of(phone);
      expect(tester.getSize(key('history-dialog')).width, closeTo(layout.canvasSize.width * 0.8, 0.01));
      expect(textsIn(tester, 'history-stat-rounds'), ['ROUNDS', '5']);
      expect(textsIn(tester, 'history-total-play'), ['TOTAL PLAY', '690']);
      expect(textsIn(tester, 'history-total-win'), ['TOTAL WIN', '840']);
      expect(key('history-net'), findsNothing, reason: 'Hasan: only ROUNDS, TOTAL PLAY and TOTAL WIN');
      expect(find.text('NET'), findsNothing);
      final first = textsIn(tester, 'history-row-0');
      expect(first, containsAllInOrder(['1', '17403945', 'A', '4X', '200', '+560']));
      final second = textsIn(tester, 'history-row-1');
      expect(second, containsAllInOrder(['2', '17403944', 'Q', 'N', '100', '0']));
      expect(find.text(kLucky16HistoryHint), findsOneWidget);
      expect(tester.takeException(), isNull);
      await rig.finish();
    });

    testWidgets('it reads again every time it opens', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final script = Script(sampleRows);
      await openGame(tester, rig, history: script.provider);
      await open(tester, rig, 'top-history');
      await tapPiece(tester, 'history-close');
      await open(tester, rig, 'top-history');
      expect(script.reads, 2);
      await rig.finish();
    });

    testWidgets('no rounds says so', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final script = Script([]);
      await openGame(tester, rig, history: script.provider);
      await open(tester, rig, 'top-history');
      expect(textOf(tester, 'history-empty'), kLucky16HistoryEmpty);
      await rig.finish();
    });

    testWidgets('a failed read offers RETRY, which reads again', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final script = Script(sampleRows)..fail = true;
      await openGame(tester, rig, history: script.provider);
      await open(tester, rig, 'top-history');
      expect(textOf(tester, 'history-error'), Lucky16HistoryProvider.loadErrorText);
      expect(tester.getSize(key('history-retry')).height, greaterThanOrEqualTo(kLucky16MinTapDp));
      script.fail = false;
      await tapPiece(tester, 'history-retry');
      expect(key('history-row-0'), findsOneWidget);
      await rig.finish();
    });

    testWidgets('a failed later read keeps the list and offers a line that retries', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final script = Script(sampleRows);
      await openGame(tester, rig, history: script.provider);
      await open(tester, rig, 'top-history');
      await tapPiece(tester, 'history-close');
      script.fail = true;
      await open(tester, rig, 'top-history');
      expect(key('history-stale'), findsOneWidget);
      expect(key('history-row-0'), findsOneWidget);
      script.fail = false;
      await tapPiece(tester, 'history-stale');
      expect(key('history-stale'), findsNothing);
      await rig.finish();
    });

    testWidgets('a round opens its detail: a win, then a loss, with the four facts', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final script = Script(sampleRows);
      await openGame(tester, rig, history: script.provider);
      await open(tester, rig, 'top-history');
      await tapPiece(tester, 'history-row-0');
      final layout = Lucky16Layout.of(phone);
      expect(tester.getSize(key('history-detail')).width, closeTo(layout.canvasSize.width * 0.56, 0.01));
      expect(textOf(tester, 'history-detail-badge'), 'NO. 1');
      expect(textOf(tester, 'history-detail-amount'), '+560');
      expect(key('history-detail-card-a_spades'), findsOneWidget);
      expect(textOf(tester, 'history-detail-ROUND'), '17403945');
      expect(textOf(tester, 'history-detail-WINNING CARD'), 'Ace of Spades');
      expect(textOf(tester, 'history-detail-BONUS'), '4X');
      expect(textOf(tester, 'history-detail-TOTAL BET'), '200 coins');
      await tapPiece(tester, 'history-detail-close');
      expect(key('history-detail'), findsNothing);
      expect(key('history-dialog'), findsOneWidget, reason: 'the list is still there');
      await tapPiece(tester, 'history-row-1');
      expect(textOf(tester, 'history-detail-headline'), 'NO WIN');
      expect(textOf(tester, 'history-detail-BONUS'), 'N');
      await rig.finish();
    });

    testWidgets('when betting closes the detail and the list both close', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final script = Script(sampleRows);
      await openGame(tester, rig, history: script.provider);
      await open(tester, rig, 'top-history');
      await tapPiece(tester, 'history-row-0');
      await runToLock(tester, rig);
      expect(key('history-detail'), findsNothing);
      expect(key('history-dialog'), findsNothing);
      expect(tester.takeException(), isNull);
      await rig.finish();
    });
  });

  group('pictures to compare with the approved design', () {
    for (final d in kGoldenPhones) {
      final size = '${d.width.toInt()}x${d.height.toInt()}';
      Future<void> shoot(WidgetTester tester, String name, List<Map<String, dynamic>> rows,
          Future<void> Function(BetRig rig) arrange) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        final script = Script(rows);
        await openGame(tester, rig, size: d.size, history: script.provider);
        await arrange(rig);
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/phase6_${name}_$size.png'));
        await rig.finish();
      }

      testWidgets('$size: Info, RULES',
          (tester) => shoot(tester, 'info_rules', sampleRows, (rig) => open(tester, rig, 'top-info')));

      testWidgets(
          '$size: Info, PAYOUTS',
          (tester) => shoot(tester, 'info_payouts', sampleRows, (rig) async {
                await open(tester, rig, 'top-info');
                await tapPiece(tester, 'info-tab-payouts');
              }));

      testWidgets('$size: Exit', (tester) => shoot(tester, 'exit', sampleRows, (rig) => open(tester, rig, 'top-exit')));

      testWidgets('$size: History, wins and losses',
          (tester) => shoot(tester, 'history_list', sampleRows, (rig) => open(tester, rig, 'top-history')));

      testWidgets('$size: History, no rounds',
          (tester) => shoot(tester, 'history_empty', const [], (rig) => open(tester, rig, 'top-history')));

      testWidgets(
          '$size: a winning round\'s detail',
          (tester) => shoot(tester, 'detail_win', sampleRows, (rig) async {
                await open(tester, rig, 'top-history');
                await tapPiece(tester, 'history-row-0');
              }));

      testWidgets(
          '$size: a losing round\'s detail',
          (tester) => shoot(tester, 'detail_loss', sampleRows, (rig) async {
                await open(tester, rig, 'top-history');
                await tapPiece(tester, 'history-row-1');
              }));
    }
  });
}
