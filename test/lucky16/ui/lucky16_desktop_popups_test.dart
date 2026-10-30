// Tests for the Lucky 16 Card popups at desktop size (desktop phase 3), on the real screen
// (lib/screens/lucky16_screen.dart) over the simulated server: Info 80% x 92% of the canvas, History the
// same, Exit 46% wide, the round detail 56% wide, nothing overflowing, the tap areas kept. Golden pictures
// are copied to reference-design/lucky16/screenshots/desktop_phase3/.

import 'package:best_smart_game/widgets/lucky16/lucky16_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'lucky16_board_test.dart' show loadArt, tapPiece;
import 'lucky16_popups_test.dart' show Script, open, sampleRows, textOf, textsIn;
import 'lucky16_screen_test.dart' show key, openGame, settle;
import 'lucky16_desktop_test.dart' show kDesktops, kGoldenDesktops;
import 'ui_harness.dart';

void main() {
  setUpAll(() async {
    await loadLucky16Fonts();
    await loadLucky16Icons();
  });

  for (final d in kDesktops) {
    testWidgets('$d: every popup has its share of the screen, opens clean and closes', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final script = Script(sampleRows);
      await openGame(tester, rig, size: d.size, desktopPlatform: true, history: script.provider);
      final canvas = Lucky16Layout.of(d.size).canvasSize;

      await open(tester, rig, 'top-info');
      var size = tester.getSize(key('info-dialog'));
      expect(size.width, closeTo(canvas.width * 0.8, 0.01));
      expect(size.height, closeTo(canvas.height * 0.92, 0.01));
      for (final k in ['info-tab-rules', 'info-tab-payouts', 'info-close']) {
        expect(tester.getSize(key(k)).height, greaterThanOrEqualTo(kLucky16MinTapDp), reason: k);
      }
      expect(tester.takeException(), isNull, reason: 'RULES');
      await tapPiece(tester, 'info-tab-payouts');
      expect(textsIn(tester, 'payout-10X'), ['10X', '1,400']);
      expect(tester.takeException(), isNull, reason: 'PAYOUTS');
      await tapPiece(tester, 'info-close');
      expect(key('info-dialog'), findsNothing);

      await open(tester, rig, 'top-exit');
      expect(tester.getSize(key('exit-dialog')).width, closeTo(canvas.width * 0.46, 0.01));
      expect(tester.getRect(key('exit-gem')).top, greaterThanOrEqualTo(0), reason: 'the gem is on the screen');
      expect(tester.getRect(key('exit-dialog')).bottom, lessThanOrEqualTo(canvas.height));
      expect(tester.getSize(key('exit-no')).height, greaterThanOrEqualTo(kLucky16MinTapDp));
      expect(tester.takeException(), isNull, reason: 'Exit');
      await tapPiece(tester, 'exit-no');
      expect(key('exit-dialog'), findsNothing);

      await open(tester, rig, 'top-history');
      size = tester.getSize(key('history-dialog'));
      expect(size.width, closeTo(canvas.width * 0.8, 0.01));
      expect(size.height, closeTo(canvas.height * 0.92, 0.01));
      expect(tester.getSize(key('history-row-0')).height, greaterThanOrEqualTo(kLucky16MinTapDp));
      expect(tester.takeException(), isNull, reason: 'History');

      await tapPiece(tester, 'history-row-0');
      final detail = tester.getRect(key('history-detail'));
      expect(detail.width, closeTo(canvas.width * 0.56, 0.01));
      expect(detail.height, lessThanOrEqualTo(canvas.height * 0.92 + 0.01));
      expect(textOf(tester, 'history-detail-amount'), '+560');
      expect(tester.takeException(), isNull, reason: 'the round detail');
      await tapPiece(tester, 'history-detail-close');
      await tapPiece(tester, 'history-close');
      expect(key('history-dialog'), findsNothing);
      await rig.finish();
    });
  }

  testWidgets('1920x1080: the popups close by themselves when betting closes, as on the phone', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    final script = Script(sampleRows);
    await openGame(tester, rig, size: const Size(1920, 1080), desktopPlatform: true, history: script.provider);
    await open(tester, rig, 'top-history');
    await tapPiece(tester, 'history-row-0');
    var guard = 0;
    while (!rig.provider.isLocked && ++guard < 2000) {
      await rig.world.run(const Duration(milliseconds: 500));
    }
    await settle(tester);
    expect(key('history-detail'), findsNothing);
    expect(key('history-dialog'), findsNothing);
    await rig.finish();
  });

  group('pictures to compare with the approved design', () {
    for (final d in kGoldenDesktops) {
      final size = '${d.width.toInt()}x${d.height.toInt()}';
      Future<void> shoot(WidgetTester tester, String name, List<Map<String, dynamic>> rows,
          Future<void> Function(BetRig rig) arrange) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        final script = Script(rows);
        await openGame(tester, rig, size: d.size, desktopPlatform: true, history: script.provider);
        await arrange(rig);
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/desktop3_${name}_$size.png'));
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
