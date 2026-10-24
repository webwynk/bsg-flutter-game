// Tests for the HISTORY button of the Lucky Card header (the reference design header built
// in lucky_card_top_bar.dart, lucky_card_layout.dart's `design*` getters, and
// lucky_card_readouts_binding.dart).
//
// The header is a row, in order: EXIT, the balance, the countdown and the status words, then
// HISTORY, SOUND, INFO. The row is laid out by the widget, not by fixed rects in the layout
// class (2026-10-23's redesign), so this file finds pieces by their keys and reads their
// rendered rects, rather than by a `layout.historyHit`-style getter.
//
// The button is always drawn; like INFO it works only while betting is open and nothing is
// playing. The older top-bar tests (lucky_card_readouts_test.dart,
// lucky_card_readouts_binding_test.dart, lucky_card_layout_test.dart) are left as they were:
// they do not mention this button.

import 'dart:ui' as ui;

import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_palette.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_readouts_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

class Taps {
  int exit = 0, sound = 0, info = 0, history = 0;
}

/// Just the top bar, as the real screen puts it on the canvas.
Widget bar({Taps? taps, bool infoEnabled = true, bool withHistoryCallback = true}) => LuckyCardCanvas(
      topBar: (context, layout) => LuckyCardTopBar(
        layout: layout, art: const FileLuckyCardArt(),
        balance: 12345,
        countdown: 47,
        soundOn: true,
        infoEnabled: infoEnabled,
        statusWidget: LuckyCardStatusLine(
          key: const ValueKey('top-status'),
          text: 'Place your chips',
          size: layout.designStatusFont,
          color: kDesignStatusText,
          flashing: false,
        ),
        onExit: taps == null ? null : () => taps.exit++,
        onToggleSound: taps == null ? null : () => taps.sound++,
        onInfo: taps == null ? null : () => taps.info++,
        onHistory: taps == null || !withHistoryCallback ? null : () => taps.history++,
      ),
    );

/// The top bar driven by the real game provider.
Widget boundBar(LuckyCardProvider provider, Taps taps) => LuckyCardCanvas(
      topBar: (context, layout) => LuckyCardTopBarBinding(
        provider: provider,
        layout: layout, art: const FileLuckyCardArt(),
        soundOn: true,
        onExit: () => taps.exit++,
        onToggleSound: () => taps.sound++,
        onInfo: () => taps.info++,
        onHistory: () => taps.history++,
      ),
    );

Finder key(String k) => find.byKey(ValueKey(k));

bool dimmed(WidgetTester tester, String k) => find.descendant(of: key(k), matching: find.byType(Opacity)).evaluate().isNotEmpty;

void main() {
  setUpAll(() async {
    await loadLuckyCardFonts();
    await loadLuckyCardIcons();
  });

  group('the rendered order and shape of the header', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): EXIT, balance, countdown, HISTORY, SOUND, INFO, left to right, none overlapping, HISTORY at least 48 dp', (tester) async {
        await pumpAtSize(tester, d.size, bar(taps: Taps()));
        expect(tester.takeException(), isNull);

        final exit = tester.getRect(key('top-exit'));
        final balance = tester.getRect(key('top-balance'));
        final countdown = tester.getRect(key('top-countdown'));
        final history = tester.getRect(key('top-history'));
        final sound = tester.getRect(key('top-sound'));
        final info = tester.getRect(key('top-info'));
        final order = [exit, balance, countdown, history, sound, info];
        for (var i = 0; i < order.length - 1; i++) {
          expect(order[i].right, lessThanOrEqualTo(order[i + 1].left + 0.5), reason: '$i before ${i + 1} on ${d.name}');
        }

        expect(history.width, greaterThanOrEqualTo(kLuckyCardMinTapDp - 0.01), reason: 'width on ${d.name}');
        expect(history.height, greaterThanOrEqualTo(kLuckyCardMinTapDp - 0.01), reason: 'height on ${d.name}');
        expect(history.width, closeTo(sound.width, 0.5), reason: 'the same size as the other round buttons: ${d.name}');
        expect(history.width, closeTo(info.width, 0.5), reason: d.name);
        expect(history.width, closeTo(exit.width, 0.5), reason: d.name);

        // The same gap on both sides of SOUND.
        expect(sound.left - history.right, closeTo(info.left - sound.right, 0.5), reason: 'equal gaps: ${d.name}');
      });
    }
  });

  group('the button is always drawn', () {
    testWidgets('even with no callback, and it is the history icon, said as "Game history"', (tester) async {
      await pumpAtSize(tester, phone, bar());
      expect(key('top-history'), findsOneWidget);
      expect(find.descendant(of: key('top-history'), matching: find.byIcon(Icons.history_rounded)), findsOneWidget);
      expect(dimmed(tester, 'top-history'), isTrue, reason: 'with nothing to call it is dimmed, like any button that cannot be used');
    });

    testWidgets('and a screen reader hears a button called "Game history", enabled when it can be used', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, phone, bar(taps: Taps()));
      final node = tester.getSemantics(find.bySemanticsLabel('Game history'));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().flagsCollection.isEnabled, ui.Tristate.isTrue);
      await pumpAtSize(tester, phone, bar(taps: Taps(), infoEnabled: false));
      final off = tester.getSemantics(find.bySemanticsLabel('Game history'));
      expect(off.getSemanticsData().flagsCollection.isEnabled, ui.Tristate.isFalse, reason: 'told that it cannot be used now');
      handle.dispose();
    });
  });

  group('every device of the matrix', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): a tap anywhere in its area answers, and only it does', (tester) async {
        final taps = Taps();
        await pumpAtSize(tester, d.size, bar(taps: taps));
        expect(tester.takeException(), isNull);

        final hit = tester.getRect(key('top-history'));
        for (final p in [hit.center, hit.topLeft + const Offset(1, 1), hit.bottomRight - const Offset(1, 1), hit.topRight + const Offset(-1, 1), hit.bottomLeft + const Offset(1, -1)]) {
          final before = taps.history;
          await tester.tapAt(p);
          await tester.pump();
          expect(taps.history, before + 1, reason: 'at $p on ${d.name}');
        }
        expect([taps.exit, taps.sound, taps.info, taps.history], [0, 0, 0, 5], reason: 'only HISTORY answered');

        // And the other three still answer only themselves.
        for (final name in ['top-exit', 'top-sound', 'top-info']) {
          await tester.tap(key(name));
          await tester.pump();
          expect(taps.history, 5, reason: 'a tap on $name did not reach HISTORY on ${d.name}');
        }
        expect([taps.exit, taps.sound, taps.info], [1, 1, 1]);
      });
    }
  });

  group('when it can be used', () {
    testWidgets('dimmed and deaf while INFO is disabled; EXIT, SOUND and INFO\'s own rule unchanged', (tester) async {
      final taps = Taps();
      await pumpAtSize(tester, phone, bar(taps: taps, infoEnabled: false));
      await tester.tap(key('top-history'), warnIfMissed: false);
      await tester.tap(key('top-info'), warnIfMissed: false);
      await tester.tap(key('top-exit'));
      await tester.tap(key('top-sound'));
      await tester.pump();
      expect([taps.exit, taps.sound, taps.info, taps.history], [1, 1, 0, 0]);
      expect(tester.widget<Opacity>(find.descendant(of: key('top-history'), matching: find.byType(Opacity)).first).opacity, closeTo(0.4, 1e-9));
    });

    testWidgets('bright and answering while betting is open', (tester) async {
      final taps = Taps();
      await pumpAtSize(tester, phone, bar(taps: taps));
      expect(dimmed(tester, 'top-history'), isFalse);
      await tester.tap(key('top-history'));
      await tester.pump();
      expect(taps.history, 1);
    });

    testWidgets('a callback missing: harmless and dimmed', (tester) async {
      final taps = Taps();
      await pumpAtSize(tester, phone, bar(taps: taps, withHistoryCallback: false));
      await tester.tap(key('top-history'), warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(taps.history, 0);
      expect(dimmed(tester, 'top-history'), isTrue);
    });

    testWidgets('a pressed button eases down a little while the finger is down and springs back; only it moves', (tester) async {
      await pumpAtSize(tester, phone, bar(taps: Taps()));
      double offsetOf(String k) {
        final container = tester.widget<AnimatedContainer>(find.descendant(of: key(k), matching: find.byType(AnimatedContainer)));
        final m = container.transform!;
        return m.getTranslation().y;
      }

      expect(offsetOf('top-history'), 0.0);
      final finger = await tester.startGesture(tester.getCenter(key('top-history')));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 100));
      expect(offsetOf('top-history'), greaterThan(0.0));
      expect(offsetOf('top-sound'), 0.0);
      expect(offsetOf('top-info'), 0.0);
      await finger.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(offsetOf('top-history'), 0.0);
    });
  });

  group('driven by the real game provider', () {
    testWidgets('it works while betting is open, is dimmed and deaf from the lock, and works again in the next round, exactly as INFO does', (tester) async {
      final rig = BetRig(tester);
      final taps = Taps();
      await pumpAtSize(tester, phone, boundBar(rig.provider, taps));
      await rig.open();

      expect(dimmed(tester, 'top-history'), isFalse);
      await tester.tap(key('top-history'));
      await tester.tap(key('top-info'));
      await tester.pump();
      expect([taps.history, taps.info], [1, 1]);

      await rig.world.runUntil(86.0);
      expect(rig.provider.isLocked, isTrue);
      expect(dimmed(tester, 'top-history'), isTrue);
      expect(dimmed(tester, 'top-info'), isTrue, reason: 'the same rule as INFO');
      await tester.tap(key('top-history'), warnIfMissed: false);
      await tester.tap(key('top-exit'));
      await tester.pump();
      expect([taps.history, taps.info, taps.exit], [1, 1, 1], reason: 'ignored at the lock; EXIT still works');

      await rig.runIntoNextCycle(8);
      expect(dimmed(tester, 'top-history'), isFalse);
      await tester.tap(key('top-history'));
      await tester.pump();
      expect(taps.history, 2, reason: 'works again in the next round');
      await rig.finish();
    });
  });

  group('a picture to look at', () {
    Future<void> shoot(WidgetTester tester, Size size, String name, Widget scene) async {
      await pumpAtSize(tester, size, scene);
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${size.width.toInt()}x${size.height.toInt()}.png'));
    }

    for (final size in const [Size(640, 360), Size(915, 412), Size(1024, 768)]) {
      testWidgets('the whole top bar, all four buttons usable: ${size.width.toInt()}x${size.height.toInt()}', (tester) => shoot(tester, size, 'top_bar_history', bar(taps: Taps())));
    }
    testWidgets('the whole top bar while betting is closed: 640x360', (tester) => shoot(tester, const Size(640, 360), 'top_bar_history_closed', bar(taps: Taps(), infoEnabled: false)));
  });
}
