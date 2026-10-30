// Tests for the Lucky 16 Card wheel and reveal on the phone screen (phone phase 4): at the lock the
// board's place holds the wheel and the reveal card; the wheel spins to the server's card and bonus
// with Lucky Card's timing, the card settles on the winner, and the board comes back for the next round.
// On the real screen (lib/screens/lucky16_screen.dart) over the simulated server. Also draws the golden
// pictures -- the wheel mid-spin and stopped with the card shown -- copied to
// reference-design/lucky16/screenshots/phase4/.

import 'package:best_smart_game/providers/lucky16_provider.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_layout.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'lucky16_board_test.dart' show aceHearts, expectNear, loadArt, runToLock, tapPiece;
import 'lucky16_screen_test.dart' show key, openGame, phone, settle;
import 'ui_harness.dart';

/// Runs the simulated round on, a fifth of a second at a time, until [done] (or a long time passes).
Future<void> runUntilTrue(WidgetTester tester, BetRig rig, bool Function() done) async {
  var guard = 0;
  while (!done() && ++guard < 2000) {
    await rig.world.run(const Duration(milliseconds: 200));
  }
  expect(done(), isTrue, reason: 'the round got there');
}

/// Bets, then runs to the moment the wheel starts to turn.
Future<void> betAndRunToSpin(WidgetTester tester, BetRig rig) async {
  await tapPiece(tester, 'chip-10');
  await tapPiece(tester, 'suit-spades');
  await runUntilTrue(tester, rig, () => rig.provider.stage == Lucky16Stage.spinning);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await loadLucky16Fonts();
    await loadLucky16Icons();
  });

  testWidgets('the wheel refuses a bonus it cannot show (only N to 10X)', (tester) async {
    final wheel = GlobalKey<Lucky16WheelState>();
    await pumpAtSize(tester, phone, Center(child: Lucky16Wheel(key: wheel, size: 300)));
    expect(() => wheel.currentState!.spin(outerIndex: 0, innerIndex: 0, bonus: 11), throwsArgumentError);
    expect(() => wheel.currentState!.spin(outerIndex: 0, innerIndex: 0, bonus: 0), throwsArgumentError);
    expect(() => wheel.currentState!.spin(outerIndex: 12, innerIndex: 0, bonus: 2), throwsArgumentError);
  });

  testWidgets('at the lock the wheel and the reveal card take the board\'s place, where the layout says',
      (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    expect(find.byType(Lucky16Wheel), findsNothing, reason: 'betting is open: the board shows');
    await tapPiece(tester, aceHearts.key);
    await runToLock(tester, rig);
    expect(find.byType(Lucky16Wheel), findsOneWidget);
    expect(key(aceHearts.key), findsNothing, reason: 'the board is off the screen while the wheel shows');
    expect(key('rank-A'), findsNothing);
    final layout = Lucky16Layout.of(phone);
    expectNear(tester.getRect(find.byType(Lucky16Wheel)), layout.wheelBox, 'wheel');
    expect(key('reveal-face-back'), findsOneWidget, reason: 'the card rests face down until the spin');
    expectNear(tester.getRect(key('reveal-face-back')), layout.revealCard, 'reveal card');
    expect(layout.revealCard.left, greaterThan(layout.wheelBox.right), reason: 'the card is beside the wheel');
    await rig.finish();
  });

  testWidgets('the wheel spins to the server\'s card, the card settles on it, then the board comes back',
      (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    await betAndRunToSpin(tester, rig);
    final target = rig.provider.spinTarget!;
    final winner = target.winningCard;
    await rig.world.run(const Duration(seconds: 1));
    expect(rig.provider.cardRevealed, isFalse, reason: 'mid-spin, nothing is revealed');
    expect(key('reveal-face-${winner.key}'), findsNothing, reason: 'the card never shows the winner early');
    // The wheel itself tells the provider when its inner rim lands (5 s after it starts).
    await runUntilTrue(tester, rig, () => rig.provider.cardRevealed);
    await settle(tester);
    expect(key('reveal-face-${winner.key}'), findsOneWidget, reason: 'the card settled on ${winner.key}');
    expect(target.bonusMultiplier, inInclusiveRange(1, 10));
    // The next round opens: the board is back, with nothing on it.
    await rig.runIntoNextCycle(2.0);
    await settle(tester);
    await settle(tester);
    expect(rig.provider.isLocked, isFalse);
    expect(find.byType(Lucky16Wheel), findsNothing);
    expect(key(aceHearts.key), findsOneWidget);
    expect(rig.provider.isBoardEmpty, isTrue);
    await rig.finish();
  });

  testWidgets('a round with no bet still spins and shows the card (a spectator)', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    await runUntilTrue(tester, rig, () => rig.provider.stage == Lucky16Stage.spinning);
    await runUntilTrue(tester, rig, () => rig.provider.cardRevealed);
    await settle(tester);
    expect(key('reveal-face-${rig.provider.spinTarget!.winningCard.key}'), findsOneWidget);
    await rig.finish();
  });

  group('pictures to compare with the approved mockup (?state=spin)', () {
    for (final d in kGoldenPhones) {
      final size = '${d.width.toInt()}x${d.height.toInt()}';
      testWidgets('$size: the wheel mid-spin', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        await betAndRunToSpin(tester, rig);
        await rig.world.run(const Duration(milliseconds: 1500));
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/phase4_wheel_spinning_$size.png'));
        await rig.finish();
      });

      testWidgets('$size: the wheel stopped, the card shown', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        await betAndRunToSpin(tester, rig);
        await runUntilTrue(tester, rig, () => rig.provider.cardRevealed);
        await rig.world.run(const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/phase4_wheel_stopped_$size.png'));
        await rig.finish();
      });
    }
  });
}
