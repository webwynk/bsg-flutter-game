// The final checks of Lucky Card's redesigned popups together, on the real game screen with the
// simulated server, at every phone, tablet and desktop size: Info (both tabs), History, the round
// detail and Exit, then the messages and the win popup, which did not change. Nothing overflows, every
// tap area is 48 dp, all text is drawn at 11 dp or more, and a screen reader hears each thing once.

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/services/lucky_card_sound.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_win_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lucky_card_sound_test.dart' show FakeOutput;
import '../provider_rig.dart';
import 'lucky_card_screen_history_test.dart' show Script, art, key, openGame, sampleRows, settle, setupFor;
import 'ui_harness.dart';

const List<Device> kAllSizes = [
  Device('phone', 800, 360),
  Device('phone', 844, 390),
  Device('phone', 915, 412),
  Device('tablet', 1180, 820),
  Device('tablet', 1024, 768),
  Device('tablet', 1024, 600),
  Device('tablet', 1366, 1024),
  Device('desktop', 1920, 1080),
  Device('desktop', 1366, 768),
  Device('desktop', 1280, 720),
  Device('desktop', 2560, 1440),
];

final DateTime login = DateTime.utc(2026, 10, 22, 9);

/// The popup is on screen, nothing threw, and every text is drawn at 11 dp or more, a text that a
/// FittedBox shrinks included. [taps] are the popup's tap areas.
void checkPopup(WidgetTester tester, Size screen, String popup, List<String> taps) {
  expect(tester.takeException(), isNull, reason: popup);
  final box = tester.getRect(key(popup));
  final area = Offset.zero & screen;
  expect(area.contains(box.topLeft) && area.contains(box.bottomRight - const Offset(0.01, 0.01)), isTrue, reason: '$popup $box');
  for (final k in taps) {
    final r = tester.getRect(key(k));
    expect(r.width, greaterThanOrEqualTo(kLuckyCardMinTapDp - 0.001), reason: '$k width');
    expect(r.height, greaterThanOrEqualTo(kLuckyCardMinTapDp - 0.001), reason: '$k height');
  }
  for (final e in find.descendant(of: key(popup), matching: find.byType(Text)).evaluate()) {
    final text = e.widget as Text;
    final render = e.renderObject! as RenderBox;
    final drawn = MatrixUtils.transformRect(render.getTransformTo(null), Offset.zero & render.size);
    final shown = text.style!.fontSize! * drawn.height / render.size.height;
    expect(shown, greaterThanOrEqualTo(kLuckyCardMinReadableDp - 0.01), reason: '"${text.data}" in $popup');
  }
}

void main() {
  setUpAll(() async {
    await loadLuckyCardWheelFonts();
    await loadLuckyCardIcons();
    art = await PreloadedLuckyCardArt.load();
  });

  setUp(LuckyCardSound.resetMute);
  tearDown(LuckyCardSound.resetMute);

  for (final d in kAllSizes) {
    final name = '${d.name} ${d.width.toInt()}x${d.height.toInt()}';

    testWidgets('$name: Info, History, the round detail and Exit on the real screen', (tester) async {
      final handle = tester.ensureSemantics();
      final rig = BetRig(tester);
      final script = Script(sampleRows());
      await openGame(tester, rig, () => setupFor(rig, FakeOutput(), history: script.history, sessionStart: () => login), size: d.size);

      await tester.tap(key('top-info'));
      await settle(tester);
      checkPopup(tester, d.size, 'info-dialog', ['info-tab-rules', 'info-tab-payouts', 'info-close']);
      expect(find.bySemanticsLabel('RULES'), findsOneWidget);
      expect(find.bySemanticsLabel('PAYOUTS'), findsOneWidget);
      expect(find.bySemanticsLabel('HOW TO PLAY'), findsOneWidget);
      await tester.tap(key('info-tab-payouts'));
      await settle(tester);
      checkPopup(tester, d.size, 'info-dialog', ['info-tab-rules', 'info-tab-payouts', 'info-close']);
      await tester.tap(key('info-close'));
      await settle(tester);

      await tester.tap(key('top-history'));
      await settle(tester);
      checkPopup(tester, d.size, 'history-dialog', ['history-row-0', 'history-row-1', 'history-close']);
      expect(find.bySemanticsLabel('HISTORY'), findsOneWidget);
      await tester.tap(key('history-row-0'));
      await settle(tester);
      checkPopup(tester, d.size, 'history-detail', ['history-detail-close']);
      await tester.tap(key('history-detail-close'));
      await settle(tester);
      await tester.tap(key('history-close'));
      await settle(tester);

      await tester.tap(key('top-exit'));
      await settle(tester);
      checkPopup(tester, d.size, 'exit-dialog', ['exit-no', 'exit-yes']);
      expect(find.bySemanticsLabel('EXIT GAME'), findsOneWidget);
      expect(find.bySemanticsLabel('NO'), findsOneWidget);
      await tester.tap(key('exit-no'));
      await settle(tester);
      expect(key('exit-dialog'), findsNothing);
      expect(key('top-exit'), findsOneWidget, reason: 'still in the game');
      handle.dispose();
      await rig.finish();
    });

    testWidgets('$name: the messages still fit: the refusal, the limit snackbar and a dialog', (tester) async {
      final rig = BetRig(tester, startBalance: 200000);
      await openGame(tester, rig, () => setupFor(rig, FakeOutput()), size: d.size);
      const jack = LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts);
      rig.provider.selectChip(LuckyCardChip.fiveHundred);
      for (var i = 0; i < 100; i++) {
        rig.provider.tapCard(jack);
      }
      await tester.pump();
      await tester.tap(key('chip-500'));
      await tester.tap(key('j_hearts'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('CARD PLAY LIMIT REACHED'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));

      rig.server.failBetsNext(5, error: LuckyCardError.roundClosed);
      await rig.world.runUntil(88.0);
      await settle(tester);
      expect(find.text('ROUND CLOSED'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await rig.finish();
    });

    testWidgets('$name: the win popup, which did not change, still fits', (tester) async {
      const queen = LuckyCard(LuckyCardRank.queen, LuckyCardSuit.spades);
      const outcome = LuckyCardOutcome(roundId: 'round-1', winningCard: queen, bonusMultiplier: 10, stake: 50000, payout: 5000000);
      await pumpAtSize(
        tester,
        d.size,
        LuckyCardCanvas(
          overlay: (context, layout) => LuckyCardWinPopup(outcome: outcome, layout: layout, art: const FileLuckyCardArt()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      final area = Offset.zero & d.size;
      for (final k in ['win-title', 'win-amount-box', 'win-card-q_spades', 'win-bonus']) {
        final r = tester.getRect(key(k));
        expect(area.contains(r.topLeft) && area.contains(r.bottomRight - const Offset(0.01, 0.01)), isTrue, reason: k);
      }
    });
  }
}
