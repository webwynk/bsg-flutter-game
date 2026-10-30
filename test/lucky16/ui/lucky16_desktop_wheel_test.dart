// Tests for the Lucky 16 Card spin and win effects at desktop size (desktop phase 2), on the real screen
// (lib/screens/lucky16_screen.dart) over the simulated server. The wheel is always on screen; at the lock
// the board stays, dimmed, with its stakes; the hub shows the card and bonus and goes back to the gift box
// for the next round. Golden pictures are copied to reference-design/lucky16/screenshots/desktop_phase2/.
// As on the phone, the coin picture is only made with --update-goldens, because Triple Chance's coin
// fountain throws its coins at random.

import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/providers/lucky16_provider.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_reveal_binding.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_wheel.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_win_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'lucky16_board_test.dart' show expectNear, loadArt, tapPiece;
import 'lucky16_desktop_test.dart' show desktopOf, kDesktops, kGoldenDesktops;
import 'lucky16_screen_test.dart' show key, openGame, settle, textIn;
import 'lucky16_tablet_wheel_test.dart' show opacityOf;
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

void main() {
  setUpAll(() async {
    await loadLucky16Fonts();
    await loadLucky16Icons();
  });

  for (final d in kDesktops) {
    test('$d: the wheel fits its column, and the popup the screen', () {
      final l = desktopOf(d.size);
      expect(l.wheelBox.top, greaterThanOrEqualTo(l.topBar.bottom), reason: 'the pointer clears the header');
      expect(l.wheelBox.bottom, lessThanOrEqualTo(l.totalBetCell.top));
      expect(l.winPopup.width, lessThanOrEqualTo(l.canvasSize.width * 0.92 + 0.01));
    });
  }

  testWidgets('1920x1080: the same wheel all the time; at the lock the board stays, dimmed, with its stakes',
      (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    const size = Size(1920, 1080);
    await openGame(tester, rig, size: size, desktopPlatform: true);
    final wheel = tester.state(find.byType(Lucky16Wheel));
    await betAndRunToSpin(tester, rig, aceHearts);
    await settle(tester);
    expect(tester.state(find.byType(Lucky16Wheel)), same(wheel), reason: 'it is never rebuilt or swapped');
    expectNear(tester.getRect(find.byType(Lucky16Wheel)), desktopOf(size).wheelBox, 'wheel');
    expect(textIn(tester, aceHearts.key), '10', reason: 'the stake is still shown');
    for (final k in [aceHearts.key, 'suit-spades', 'rank-Q', 'chip-5', 'button-clear']) {
      expect(opacityOf(tester, k), 0.55, reason: '$k is dimmed');
    }
    final before = rig.provider.total;
    await tester.tap(key('suit-spades'));
    await tester.pump();
    expect(rig.provider.total, before, reason: 'a dimmed board takes no chips');
    expect(find.byType(Lucky16RevealColumn), findsNothing, reason: 'no reveal card on the desktop: the hub shows it');
    await rig.finish();
  });

  testWidgets('1920x1080: a win: the server\'s 560, the coins, the popup, and the board opens again', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig, size: const Size(1920, 1080), desktopPlatform: true);
    await betAndRunToSpin(tester, rig, aceClubs);
    await runUntilTrue(tester, rig, () => rig.provider.cardRevealed);
    await settle(tester);
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
    expect(rig.provider.isLocked, isFalse);
    expect(find.byType(Lucky16Wheel), findsOneWidget, reason: 'the wheel stays');
    expect(opacityOf(tester, aceClubs.key), 1, reason: 'the board is lit again');
    await tapPiece(tester, 'chip-10');
    await tapPiece(tester, aceClubs.key);
    expect(rig.provider.stakeOn(aceClubs), 10, reason: 'betting works again');
    expect(tester.takeException(), isNull);
    await rig.finish();
  });

  group('pictures to compare with the approved mockup', () {
    for (final d in kGoldenDesktops) {
      final size = '${d.width.toInt()}x${d.height.toInt()}';
      Future<void> game(WidgetTester tester, BetRig rig) => openGame(tester, rig, size: d.size, desktopPlatform: true);

      testWidgets('$size: the wheel mid-spin, the board dimmed', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await game(tester, rig);
        await betAndRunToSpin(tester, rig, aceClubs);
        await rig.world.run(const Duration(milliseconds: 1500));
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/desktop2_spinning_$size.png'));
        await rig.finish();
      });

      testWidgets('$size: stopped, the bonus in the hub', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await game(tester, rig);
        await betAndRunToSpin(tester, rig, aceHearts);
        await runUntilTrue(tester, rig, () => rig.provider.cardRevealed);
        await rig.world.run(const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/desktop2_stopped_$size.png'));
        await rig.finish();
      });

      testWidgets('$size: the coins (made only with --update-goldens)', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await game(tester, rig);
        await betAndRunToSpin(tester, rig, aceClubs);
        await runUntilTrue(tester, rig, () => rig.provider.cardRevealed);
        await rig.world.run(const Duration(milliseconds: 700));
        await tester.pump();
        expect(key('coin-fountain'), findsOneWidget);
        if (autoUpdateGoldenFiles) {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/desktop2_coins_$size.png'));
        }
        await rig.finish();
      });

      testWidgets('$size: the win popup', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await game(tester, rig);
        await betAndRunToSpin(tester, rig, aceClubs);
        await runUntilTrue(tester, rig, () => rig.provider.cardRevealed);
        await rig.world.run(const Duration(milliseconds: 2000));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(Lucky16WinPopup), findsOneWidget);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/desktop2_popup_$size.png'));
        await rig.finish();
      });
    }
  });
}
