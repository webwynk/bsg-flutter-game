// Final tablet checks for Lucky 16 Card (tablet phase 3), on the real screen over the simulated server:
// no popup text under 11 dp, the history's loading and error states, the messages and banners, the muted
// SOUND ball and the dimmed screen after a long absence. Golden pictures are copied to
// reference-design/lucky16/screenshots/tablet_phase3/.

import 'dart:async';

import 'package:best_smart_game/providers/lucky16_history_provider.dart';
import 'package:best_smart_game/services/lucky16_history_service.dart';
import 'package:best_smart_game/services/lucky16_sound.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_history_text.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'lucky16_board_test.dart' show loadArt, tapPiece;
import 'lucky16_popups_test.dart' show Script, open, sampleRows;
import 'lucky16_screen_test.dart' show key, openGame, settle, textIn;
import 'lucky16_tablet_test.dart' show kGoldenTablets, kTablets;
import 'lucky16_win_test.dart' show aceHearts;
import 'ui_harness.dart';

/// Every text on screen is at least 11 dp, unless a FittedBox above it has shrunk it, which is measured
/// from what is actually drawn.
void expectReadable(WidgetTester tester, String where) {
  for (final e in find.byType(Text).evaluate()) {
    final t = e.widget as Text;
    final size = t.style?.fontSize;
    if (size == null) continue;
    final box = e.renderObject as RenderBox?;
    final drawn = box == null || !box.hasSize || box.size.height == 0
        ? size
        : size * tester.getSize(find.byElementPredicate((x) => x == e)).height / box.size.height;
    expect(drawn, greaterThanOrEqualTo(kLucky16MinReadableDp - 0.01), reason: '$where: "${t.data}"');
  }
  // A shrunken figure in a stat box is still readable: the FittedBox never goes under the floor.
  for (final e in find.byType(FittedBox).evaluate()) {
    final child = find.descendant(of: find.byElementPredicate((x) => x == e), matching: find.byType(Text));
    if (child.evaluate().isEmpty) continue;
    final text = tester.widget<Text>(child.first);
    final natural = (child.evaluate().first.renderObject as RenderBox).size.height;
    final shown = (e.renderObject as RenderBox).size.height;
    final scale = natural == 0 ? 1.0 : (shown / natural).clamp(0.0, 1.0);
    expect(text.style!.fontSize! * scale, greaterThanOrEqualTo(kLucky16MinReadableDp - 0.01),
        reason: '$where: fitted "${text.data}"');
  }
}

void main() {
  setUpAll(() async {
    await loadLucky16Fonts();
    await loadLucky16Icons();
    await warmUpSharedSounds();
  });

  setUp(Lucky16Sound.resetMute);
  tearDown(Lucky16Sound.resetMute);

  for (final d in kTablets) {
    testWidgets('$d: no text under 11 dp in the game or in any popup', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      final script = Script(sampleRows);
      await openGame(tester, rig, size: d.size, history: script.provider);
      expectReadable(tester, 'the game');
      await open(tester, rig, 'top-info');
      expectReadable(tester, 'RULES');
      await tapPiece(tester, 'info-tab-payouts');
      expectReadable(tester, 'PAYOUTS');
      await tapPiece(tester, 'info-close');
      await open(tester, rig, 'top-exit');
      expectReadable(tester, 'Exit');
      await tapPiece(tester, 'exit-no');
      await open(tester, rig, 'top-history');
      expectReadable(tester, 'History');
      await tapPiece(tester, 'history-row-0');
      expectReadable(tester, 'the round detail');
      expect(tester.takeException(), isNull);
      await rig.finish();
    });

    testWidgets('$d: the tab pills are whole inside their row, and the tabs answer over 48 dp', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      await openGame(tester, rig, size: d.size);
      await open(tester, rig, 'top-info');
      final area = tester.getRect(key('info-tab-rules'));
      expect(area.height, greaterThanOrEqualTo(kLucky16MinTapDp));
      final label = tester.getRect(find.text('RULES'));
      expect(label.top, greaterThanOrEqualTo(area.top), reason: 'the word is not cut');
      expect(label.bottom, lessThanOrEqualTo(area.bottom));
      await rig.finish();
    });
  }

  group('pictures of the other states', () {
    for (final d in kGoldenTablets) {
      final size = '${d.width.toInt()}x${d.height.toInt()}';
      String name(String n) => 'goldens/tablet3_${n}_$size.png';

      testWidgets('$size: History, loading', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        final never = Completer<List<dynamic>>();
        final history = Lucky16HistoryProvider(service: Lucky16HistoryService(query: (since, limit) => never.future));
        await openGame(tester, rig, size: d.size, history: history);
        await open(tester, rig, 'top-history');
        expect(textIn(tester, 'history-dialog'), isNotEmpty);
        expect(find.text(kLucky16HistoryLoading), findsOneWidget);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(name('history_loading')));
        await rig.finish();
      });

      testWidgets('$size: History, the read failed', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        final script = Script(sampleRows)..fail = true;
        await openGame(tester, rig, size: d.size, history: script.provider);
        await open(tester, rig, 'top-history');
        expect(key('history-retry'), findsOneWidget);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(name('history_error')));
        await rig.finish();
      });

      testWidgets('$size: the 10,000 banner', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester, startBalance: 50000);
        await openGame(tester, rig, size: d.size);
        await tapPiece(tester, 'chip-500');
        for (var i = 0; i < 21; i++) {
          await tapPiece(tester, aceHearts.key);
        }
        expect(key('limit-snackbar'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(name('limit_banner')));
        await rig.finish();
      });

      testWidgets('$size: too few coins', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester, startBalance: 5);
        await openGame(tester, rig, size: d.size);
        await tapPiece(tester, 'chip-10');
        await tester.tap(key(aceHearts.key));
        await tester.pump();
        expect(tester.widget<Text>(find.descendant(of: key('top-status'), matching: find.byType(Text))).data,
            'NOT ENOUGH COINS');
        await settle(tester);
        expect(find.text('INSUFFICIENT COINS'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(name('insufficient_coins')));
        await rig.finish();
      });

      testWidgets('$size: connection lost', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size, endSession: () async {});
        rig.server.offline = true;
        await rig.world.run(const Duration(seconds: 12));
        await settle(tester);
        expect(find.text('CONNECTION LOST'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(name('connection_lost')));
        await rig.finish();
      });

      testWidgets('$size: the SOUND ball muted', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        await tapPiece(tester, 'top-sound');
        expect(find.descendant(of: key('top-sound'), matching: find.byIcon(Icons.volume_off_rounded)), findsOneWidget);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(name('muted')));
        await rig.finish();
      });

      testWidgets('$size: dimmed after more than 20 seconds away', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await rig.world.run(const Duration(seconds: 21));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await settle(tester);
        await tester.tap(key('top-exit'), warnIfMissed: false);
        await settle(tester);
        expect(key('exit-dialog'), findsNothing, reason: 'nothing answers');
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(name('away_dimmed')));
        await rig.finish();
      });
    }
  });
}
