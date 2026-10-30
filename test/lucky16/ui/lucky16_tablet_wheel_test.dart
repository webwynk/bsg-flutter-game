// Tests for the Lucky 16 Card wheel, reveal and win effects at tablet size (tablet phase 2), on the real
// screen (lib/screens/lucky16_screen.dart) over the simulated server. The wheel and the reveal card take
// the board's place, the chip bar and the bet panel stay, dimmed. Golden pictures are copied to
// reference-design/lucky16/screenshots/tablet_phase2/. As on the phone, the coin picture is only made
// with --update-goldens, because Triple Chance's coin fountain throws its coins at random.

import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/providers/lucky16_provider.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_layout.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_wheel.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_win_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'lucky16_board_test.dart' show expectNear, loadArt, tapPiece;
import 'lucky16_screen_test.dart' show key, openGame, settle, textIn;
import 'lucky16_tablet_test.dart' show kGoldenTablets, kTablets;
import 'lucky16_wheel_test.dart' show runUntilTrue;
import 'lucky16_win_test.dart' show aceClubs, aceHearts;
import 'ui_harness.dart';

/// Bets a 10 chip on [card], then runs to the moment the wheel starts to turn.
Future<void> betAndRunToSpin(WidgetTester tester, BetRig rig, Lucky16Card card) async {
  await tapPiece(tester, 'chip-10');
  await tapPiece(tester, card.key);
  await runUntilTrue(tester, rig, () => rig.provider.stage == Lucky16Stage.spinning);
  await tester.pump();
}

/// The first fade inside the widget with key [k], 1 when it has none.
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

  for (final d in kTablets) {
    test('$d: the wheel and the card fit the board\'s place, side by side, above the chip bar', () {
      final l = Lucky16Layout.of(d.size);
      expect(l.isTablet, isTrue);
      expect(l.wheelBox.left, greaterThanOrEqualTo(l.designBoard.left));
      expect(l.wheelBox.top, greaterThanOrEqualTo(l.topBar.bottom), reason: 'the pointer clears the header');
      expect(l.wheelBox.bottom, lessThanOrEqualTo(l.chipBar.top), reason: 'the wheel clears the chip bar');
      expect(l.revealCard.left, greaterThan(l.wheelBox.right));
      expect(l.revealCard.right, lessThanOrEqualTo(l.designBoard.right + 0.01));
      expect(l.revealCard.width / l.revealCard.height, closeTo(700 / 476, 1e-6));
      expect(l.winPopup.width, lessThanOrEqualTo(l.canvasSize.width * 0.92 + 0.01));
    });
  }

  testWidgets('1180x820: at the lock the wheel and the card replace the board; chips and buttons stay, dimmed',
      (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    const size = Size(1180, 820);
    await openGame(tester, rig, size: size);
    await betAndRunToSpin(tester, rig, aceHearts);
    await settle(tester);
    final l = Lucky16Layout.of(size);
    expectNear(tester.getRect(find.byType(Lucky16Wheel)), l.wheelBox, 'wheel');
    expect(key(aceHearts.key), findsNothing, reason: 'the board is off the screen');
    expect(key('chip-bar'), findsOneWidget, reason: 'the chip bar stays');
    expectNear(tester.getRect(key('chip-bar')), l.chipBar, 'chip bar');
    for (final k in ['chip-5', 'chip-500', 'button-doubleBet', 'button-clear', 'button-remove']) {
      expect(opacityOf(tester, k), 0.55, reason: '$k is dimmed');
    }
    expect(tester.takeException(), isNull);
    await rig.finish();
  });

  testWidgets('1180x820: a win: the lit card, the coins, the popup with the server\'s 560, then the board is back',
      (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig, size: const Size(1180, 820));
    await betAndRunToSpin(tester, rig, aceClubs);
    await runUntilTrue(tester, rig, () => rig.provider.cardRevealed);
    await settle(tester);
    expect(key('reveal-face-${aceClubs.key}'), findsOneWidget);
    expect(key('reveal-winner-glow'), findsOneWidget);
    expect(key('coin-fountain'), findsOneWidget);
    expect(textIn(tester, 'win'), '+560');
    expect(textIn(tester, 'top-balance'), '1,550');
    await rig.world.run(const Duration(milliseconds: 1300));
    await tester.pump();
    expect(find.byType(Lucky16WinPopup), findsOneWidget);
    expect(key('coin-fountain'), findsNothing);
    expect(tester.widget<Text>(key('win-amount')).data, '560');
    await rig.world.run(const Duration(milliseconds: 2600));
    await settle(tester);
    expect(find.byType(Lucky16WinPopup), findsNothing);
    await rig.runIntoNextCycle(2.0);
    await settle(tester);
    await settle(tester);
    expect(find.byType(Lucky16Wheel), findsNothing);
    expect(key(aceClubs.key), findsOneWidget, reason: 'the board is back for the next round');
    expect(tester.takeException(), isNull);
    await rig.finish();
  });

  group('pictures to compare with the approved mockup', () {
    for (final d in kGoldenTablets) {
      final size = '${d.width.toInt()}x${d.height.toInt()}';
      testWidgets('$size: the wheel mid-spin', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        await betAndRunToSpin(tester, rig, aceClubs);
        await rig.world.run(const Duration(milliseconds: 1500));
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tablet2_spinning_$size.png'));
        await rig.finish();
      });

      testWidgets('$size: the coins, the winning card lit (made only with --update-goldens)', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        await betAndRunToSpin(tester, rig, aceClubs);
        await runUntilTrue(tester, rig, () => rig.provider.cardRevealed);
        await rig.world.run(const Duration(milliseconds: 700));
        await tester.pump();
        expect(key('coin-fountain'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (autoUpdateGoldenFiles) {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tablet2_coins_$size.png'));
        }
        await rig.finish();
      });

      testWidgets('$size: the win popup', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        await betAndRunToSpin(tester, rig, aceClubs);
        await runUntilTrue(tester, rig, () => rig.provider.cardRevealed);
        await rig.world.run(const Duration(milliseconds: 2000));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(Lucky16WinPopup), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tablet2_popup_$size.png'));
        await rig.finish();
      });

      testWidgets('$size: a loss, the wheel stopped and the card shown', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        await betAndRunToSpin(tester, rig, aceHearts);
        await runUntilTrue(tester, rig, () => rig.provider.cardRevealed);
        await rig.world.run(const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tablet2_stopped_$size.png'));
        await rig.finish();
      });
    }
  });
}
