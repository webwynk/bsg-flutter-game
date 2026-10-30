// Tests for the Lucky 16 Card bet panel (phone phase 3): PLAY and WIN, the twelve latest results, the
// five chips and DOUBLE / REBET, CLEAR and REMOVE, on the real screen (lib/screens/lucky16_screen.dart)
// over the simulated server, driven through taps. Also draws the whole screen's golden pictures --
// betting with the mockup's sample bets, and betting closed -- copied to
// reference-design/lucky16/screenshots/phase3/.

import 'package:best_smart_game/models/lucky16_board.dart';
import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'lucky16_board_test.dart' show aceHearts, expectNear, loadArt, runToLock, tapPiece;
import 'lucky16_screen_test.dart' show key, openGame, phone, settle, textIn;
import 'ui_harness.dart';

/// How see-through the widget with key [k] is drawn (1 when it has no fade of its own).
double opacityOf(WidgetTester tester, String k) {
  final fades = find.descendant(of: key(k), matching: find.byType(Opacity));
  if (fades.evaluate().isEmpty) return 1;
  return tester.widget<Opacity>(fades.first).opacity;
}

void main() {
  setUpAll(() async {
    await loadLucky16Fonts();
    await loadLucky16Icons();
  });

  testWidgets('PLAY is the stake on the board, WIN the last round\'s pay (0 so far)', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    expect(textIn(tester, 'total-bet'), '0');
    expect(textIn(tester, 'win'), '0');
    await tapPiece(tester, 'suit-hearts');
    expect(textIn(tester, 'total-bet'), '20', reason: 'the 5 chip on the 4 hearts');
    await rig.finish();
  });

  testWidgets('the twelve latest results, newest first, as the provider has them (aces included)', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    final history = rig.provider.history;
    expect(history.length, 12);
    final layout = Lucky16Layout.of(phone);
    for (var i = 0; i < 12; i++) {
      final k = i == 0 ? 'result-latest' : 'result-${i - 1}';
      expectNear(tester.getRect(key(k)), layout.resultTile(i), k);
      final texts =
          tester.widgetList<Text>(find.descendant(of: key(k), matching: find.byType(Text))).map((t) => t.data);
      expect(texts.first, history[i].winningCard.rank.dbValue, reason: k);
      expect(texts.last, lucky16BonusLabel(history[i].bonusMultiplier), reason: k);
    }
    expect(history.any((r) => r.winningCard.rank == Lucky16Rank.ace), isTrue, reason: 'the sample has an ace');
    await rig.finish();
  });

  testWidgets('the five chips: the one tapped goes in hand, is drawn bigger, and the board uses it', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    final layout = Lucky16Layout.of(phone);
    for (final chip in Lucky16Chip.values) {
      expectNear(tester.getRect(key('chip-${chip.amount}')), layout.chip(chip.index), 'chip ${chip.amount}');
    }
    await tapPiece(tester, 'chip-100');
    expect(rig.provider.activeChip, Lucky16Chip.hundred);
    expect(tester.getSize(key('chip-face-100')).width, greaterThan(tester.getSize(key('chip-face-5')).width));
    await tapPiece(tester, aceHearts.key);
    expect(rig.provider.stakeOn(aceHearts), 100);
    expect(textIn(tester, 'total-bet'), '100');
    await rig.finish();
  });

  testWidgets('with nothing on the board DOUBLE, CLEAR and REMOVE are dimmed and do nothing', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    for (final k in ['button-doubleBet', 'button-clear', 'button-remove']) {
      expect(opacityOf(tester, k), 0.4, reason: k);
      await tapPiece(tester, k);
    }
    expect(rig.provider.activeChip, Lucky16Chip.five, reason: 'REMOVE did not put the chip down');
    await rig.finish();
  });

  testWidgets('DOUBLE doubles every stake, CLEAR gives every chip back', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    await tapPiece(tester, 'chip-10');
    await tapPiece(tester, 'rank-A');
    expect(rig.provider.total, 40);
    expect(opacityOf(tester, 'button-doubleBet'), 1);
    await tapPiece(tester, 'button-doubleBet');
    for (final card in Lucky16Card.ofRank(Lucky16Rank.ace)) {
      expect(rig.provider.stakeOn(card), 20, reason: card.key);
    }
    expect(textIn(tester, 'total-bet'), '80');
    expect(textIn(tester, 'top-balance'), '920');
    await tapPiece(tester, 'button-clear');
    expect(rig.provider.isBoardEmpty, isTrue);
    expect(textIn(tester, 'top-balance'), '1,000');
    await rig.finish();
  });

  testWidgets('REMOVE puts the chip down; a tap on a card then takes chips back from it', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    await tapPiece(tester, 'chip-10');
    await tapPiece(tester, aceHearts.key);
    await tapPiece(tester, aceHearts.key);
    await tapPiece(tester, 'button-remove');
    expect(rig.provider.activeChip, isNull);
    expect(tester.getSize(key('chip-face-10')).width, tester.getSize(key('chip-face-5')).width,
        reason: 'no chip is drawn in hand');
    await tapPiece(tester, aceHearts.key);
    expect(rig.provider.stakeOn(aceHearts), lessThan(20));
    await rig.finish();
  });

  testWidgets('when betting closes the chips and the buttons dim and ignore taps', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    await tapPiece(tester, aceHearts.key);
    await runToLock(tester, rig);
    for (final k in ['chip-5', 'chip-500', 'button-doubleBet', 'button-clear', 'button-remove']) {
      expect(opacityOf(tester, k), 0.55, reason: k);
    }
    await tapPiece(tester, 'chip-500');
    await tapPiece(tester, 'button-clear');
    expect(rig.provider.activeChip, Lucky16Chip.five);
    expect(rig.provider.stakeOn(aceHearts), 5);
    await rig.finish();
  });

  testWidgets('after a round with a bet, REBET takes DOUBLE\'s place and puts the bet back; WIN shows the pay',
      (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    await tapPiece(tester, 'chip-10');
    await tapPiece(tester, 'suit-clubs');
    final w = await landWheelAt(rig, 95.0);
    await rig.world.runUntil(w + 4.5);
    await settle(tester);
    final paid = rig.provider.lastOutcome?.payout ?? 0;
    expect(textIn(tester, 'win'), paid > 0 ? '+$paid' : '0');
    await rig.runIntoNextCycle(2.0);
    await settle(tester);
    expect(rig.provider.isLocked, isFalse);
    expect(key('button-rebet'), findsOneWidget);
    expect(key('button-doubleBet'), findsNothing);
    await tapPiece(tester, 'button-rebet');
    for (final card in Lucky16Card.ofSuit(Lucky16Suit.clubs)) {
      expect(rig.provider.stakeOn(card), 10, reason: card.key);
    }
    expect(key('button-doubleBet'), findsOneWidget);
    await rig.finish();
  });

  group('pictures to compare with the approved mockup', () {
    for (final d in kGoldenPhones) {
      final size = '${d.width.toInt()}x${d.height.toInt()}';
      testWidgets('$size: betting, the mockup\'s sample bets (10 on the Hearts bar, then on the A selector)',
          (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        await tapPiece(tester, 'chip-10');
        await tapPiece(tester, 'suit-hearts');
        await tapPiece(tester, 'rank-A');
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/phase3_panel_betting_$size.png'));
        await rig.finish();
      });

      testWidgets('$size: betting closed, the same bets', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        await tapPiece(tester, 'chip-10');
        await tapPiece(tester, 'suit-hearts');
        await tapPiece(tester, 'rank-A');
        await runToLock(tester, rig);
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/phase3_panel_closed_$size.png'));
        await rig.finish();
      });
    }
  });
}
