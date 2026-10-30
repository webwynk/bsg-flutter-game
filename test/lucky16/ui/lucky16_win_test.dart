// Tests for the Lucky 16 Card win effects on the phone screen (phone phase 5), on the real screen
// (lib/screens/lucky16_screen.dart) over the simulated server, which pays exactly as the live
// lucky16_settle_round does: only the winning card pays, 14 times its stake times the bonus. The
// simulated round 17390003 draws the Ace of Clubs at 4X, so 10 on the Ace of Clubs pays 560.
//
//   * a win: the card lights up gold; the balance and WIN take the server's payout; the coins burst at
//     the reveal and stop when the popup opens 1.5 s later; the popup shows +560 with the card and 4X
//     until the round ends 4 s after the reveal; the round joins the results.
//   * a loss (or no bet): the card still lights up, but no coins and no popup, WIN stays 0.
//
// Golden pictures (copied to reference-design/lucky16/screenshots/phase5/): the winning card lit with the
// coins bursting, and the win popup. Triple Chance's coin fountain throws its coins at random, so the
// coin picture is only made when the goldens are refreshed (`--update-goldens`), never compared; the
// popup picture is compared every run.

import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_win_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'lucky16_board_test.dart' show loadArt, tapPiece;
import 'lucky16_screen_test.dart' show key, openGame, settle, textIn;
import 'lucky16_wheel_test.dart' show runUntilTrue;
import 'ui_harness.dart';

const Lucky16Card aceClubs = Lucky16Card(Lucky16Rank.ace, Lucky16Suit.clubs);
const Lucky16Card aceHearts = Lucky16Card(Lucky16Rank.ace, Lucky16Suit.hearts);

/// Bets a 10 chip on [card], then runs to the moment the card is revealed (both rims have landed).
Future<void> betAndRunToReveal(WidgetTester tester, BetRig rig, Lucky16Card card) async {
  await tapPiece(tester, 'chip-10');
  await tapPiece(tester, card.key);
  await runUntilTrue(tester, rig, () => rig.provider.cardRevealed);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await loadLucky16Fonts();
    await loadLucky16Icons();
  });

  testWidgets('a win: the card lights up, the balance and WIN take the server\'s 560, the coins then the popup',
      (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    await betAndRunToReveal(tester, rig, aceClubs);
    expect(rig.provider.spinTarget!.winningCard, aceClubs);
    expect(rig.provider.spinTarget!.bonusMultiplier, 4);
    await settle(tester);

    // The reveal: the server's payout, never worked out on the phone.
    expect(rig.provider.lastOutcome!.payout, 560, reason: '10 x 14 x 4, from the server');
    expect(textIn(tester, 'win'), '+560');
    expect(textIn(tester, 'top-balance'), '1,550', reason: '1,000 - 10 + 560');
    expect(key('reveal-winner-glow'), findsOneWidget, reason: 'the winning card lights up');
    expect(key('coin-fountain'), findsOneWidget, reason: 'the coins burst at the reveal');
    expect(find.byType(Lucky16WinPopup), findsNothing, reason: 'the popup waits 1.5 s');

    // 1.5 s after the reveal: the popup opens and the coins stop.
    await rig.world.run(const Duration(milliseconds: 1300));
    await tester.pump();
    expect(find.byType(Lucky16WinPopup), findsOneWidget);
    expect(key('coin-fountain'), findsNothing);
    expect(tester.widget<Text>(key('win-amount')).data, '560');
    expect(tester.widget<Text>(key('win-bonus')).data, '4X');
    expect(key('win-card-${aceClubs.key}'), findsOneWidget);

    // 4 s after the reveal the round ends and the popup goes.
    await rig.world.run(const Duration(milliseconds: 2600));
    await settle(tester);
    expect(find.byType(Lucky16WinPopup), findsNothing);
    expect(textIn(tester, 'win'), '+560', reason: 'WIN keeps the last pay until the next bet');

    // The next round: the round is the newest result, and the board is back.
    await rig.runIntoNextCycle(2.0);
    await settle(tester);
    final latest = tester.widgetList<Text>(find.descendant(of: key('result-latest'), matching: find.byType(Text)));
    expect(latest.first.data, 'A');
    expect(latest.last.data, '4X');
    expect(key(aceClubs.key), findsOneWidget);
    await rig.finish();
  });

  testWidgets('a loss: the card still lights up, but no coins and no popup; WIN stays 0', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    await betAndRunToReveal(tester, rig, aceHearts);
    await settle(tester);
    expect(rig.provider.lastOutcome!.payout, 0);
    expect(key('reveal-winner-glow'), findsOneWidget);
    expect(key('coin-fountain'), findsNothing);
    expect(textIn(tester, 'win'), '0');
    expect(textIn(tester, 'top-balance'), '990');
    for (var i = 0; i < 25; i++) {
      await rig.world.run(const Duration(milliseconds: 200));
      expect(find.byType(Lucky16WinPopup), findsNothing, reason: 'a loss never shows the popup');
      expect(key('coin-fountain'), findsNothing);
    }
    await rig.finish();
  });

  testWidgets('no bet at all: the spin and the lit card, nothing else', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    await runUntilTrue(tester, rig, () => rig.provider.cardRevealed);
    await settle(tester);
    expect(key('reveal-winner-glow'), findsOneWidget);
    await rig.world.run(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byType(Lucky16WinPopup), findsNothing);
    expect(key('coin-fountain'), findsNothing);
    await rig.finish();
  });

  group('pictures to look at', () {
    for (final d in kGoldenPhones) {
      final size = '${d.width.toInt()}x${d.height.toInt()}';
      testWidgets('$size: the winning card lit, the coins bursting (made only with --update-goldens)', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        await betAndRunToReveal(tester, rig, aceClubs);
        await rig.world.run(const Duration(milliseconds: 700));
        await tester.pump();
        expect(key('coin-fountain'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (autoUpdateGoldenFiles) {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/phase5_win_coins_$size.png'));
        }
        await rig.finish();
      });

      testWidgets('$size: the win popup, +560 with the Ace of Clubs and 4X', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        await betAndRunToReveal(tester, rig, aceClubs);
        await rig.world.run(const Duration(milliseconds: 2000));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(Lucky16WinPopup), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/phase5_win_popup_$size.png'));
        await rig.finish();
      });
    }
  });
}
