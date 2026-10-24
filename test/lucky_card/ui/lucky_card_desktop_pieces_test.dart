// Tests for the desktop pieces (desktop step D2, spec §17BP): the permanent wheel in its column with
// PLAY and WIN under it, the row of ten history cards, the bar of chips and buttons, and the board that
// stays on screen, dimmed, while betting is closed. Driven by the REAL Lucky Card provider on the
// simulated server, first piece by piece in a scene, then through the REAL screen with
// `desktopPlatform` set. The phone and tablet screens must not change: the older tests prove most of
// that, the last group here proves the rest.

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/screens/lucky_card_screen.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_action_buttons.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_board_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_controls_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_desktop_pieces.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_readouts.dart' show LuckyCardResultsPanel, LuckyCardResultTile;
import 'package:best_smart_game/widgets/lucky_card/lucky_card_readouts_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_region_swap.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_reveal_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_win_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import '../sim_server.dart';
import 'lucky_card_layout_desktop_test.dart' show kDesktopReferenceSizes;
import 'ui_harness.dart';

late PreloadedLuckyCardArt art;

Finder key(String k) => find.byKey(ValueKey(k));
Finder chip(LuckyCardChip c) => key('chip-${c.amount}');
Finder button(LuckyCardControl c) => key('button-${c.name}');

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

LuckyCardWheelState wheelState(WidgetTester tester) => tester.state<LuckyCardWheelState>(find.byType(LuckyCardWheel));

/// The desktop screen as the real one builds it, minus the sounds and the pop-ups: the header, the
/// board and rank selectors (never swapped), the wheel's column, the results row and the bottom bar,
/// laid out by [LuckyCardLayout.desktop].
Widget desktopScene(BetRig rig, {LuckyCardArt? artOverride, bool permanent = true}) {
  final a = artOverride ?? art;
  return LuckyCardBoardBinding(
    provider: rig.provider,
    art: a,
    builder: (context, zones) => LuckyCardCanvas(
      layoutOf: LuckyCardLayout.desktop,
      topBar: (context, layout) => LuckyCardTopBarBinding(provider: rig.provider, layout: layout, art: a, soundOn: true),
      grid: zones.grid,
      rankColumn: zones.rankColumn,
      side: (context, layout) => LuckyCardDesktopSide(provider: rig.provider, layout: layout, art: a),
      resultsBar: (context, layout) => LuckyCardResultsBarBinding(provider: rig.provider, layout: layout, art: a),
      actionBar: (context, layout) => LuckyCardActionBar(provider: rig.provider, layout: layout, art: a),
    ),
  );
}

/// The lobby, one button that opens the game screen over it as the real app does, with the desktop
/// platform on or off.
Widget lobby(LuckyCardProvider provider, {required bool desktopPlatform}) => Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const ValueKey('go'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LuckyCardScreen(
                setup: LuckyCardScreenSetup(provider: provider, art: art, setOrientation: false, desktopPlatform: desktopPlatform),
              ),
            ),
          ),
          child: const Text('go'),
        ),
      ),
    );

Future<void> openGame(WidgetTester tester, BetRig rig, Size size, {bool desktopPlatform = true}) async {
  await pumpAtSize(tester, size, lobby(rig.provider, desktopPlatform: desktopPlatform));
  await tester.tap(key('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await rig.world.run(const Duration(seconds: 2));
  await settle(tester);
}

bool get onBoard => key('suit-hearts').evaluate().isNotEmpty;
bool get onWheel => find.byType(LuckyCardWheelBinding).evaluate().isNotEmpty;

/// The opacity the piece with this key is drawn at: its tap target wraps its content in an Opacity of
/// 0.55 only while betting is closed, so 1 means no such wrapper.
double pieceOpacity(WidgetTester tester, String pieceKey) {
  final wrappers = tester.widgetList<Opacity>(find.descendant(of: key(pieceKey), matching: find.byType(Opacity)));
  return wrappers.isEmpty ? 1.0 : wrappers.first.opacity;
}

void main() {
  setUpAll(() async {
    await loadLuckyCardWheelFonts();
    await loadLuckyCardIcons();
    art = await PreloadedLuckyCardArt.load();
  });

  group('every piece is where the desktop layout says', () {
    for (final d in kDesktopReferenceSizes) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()})', (tester) async {
        final rig = BetRig(tester);
        await pumpAtSize(tester, d.size, desktopScene(rig));
        await rig.open();
        final l = LuckyCardLayout.desktop(d.size);
        expect(tester.takeException(), isNull, reason: 'no overflow or error');

        void at(Finder f, Rect want, String what) {
          final got = tester.getRect(f);
          expect(got.left, closeTo(want.left, 0.01), reason: '$what left');
          expect(got.top, closeTo(want.top, 0.01), reason: '$what top');
          expect(got.width, closeTo(want.width, 0.01), reason: '$what width');
          expect(got.height, closeTo(want.height, 0.01), reason: '$what height');
        }

        at(find.byType(LuckyCardDesktopSide), l.side, "the wheel's column");
        at(find.byType(LuckyCardActionBar), l.actionBar, 'the bottom bar');
        at(find.byType(LuckyCardResultsPanel), l.resultsBar, 'the results row');
        at(find.byType(LuckyCardWheel), l.wheelBox, 'the wheel');
        at(key('total-bet'), l.totalBetCell, 'PLAY');
        at(key('win'), l.winCell, 'WIN');
        for (var i = 0; i < LuckyCardLayout.chipCount; i++) {
          at(chip(LuckyCardChip.values[i]), l.chip(i), 'chip $i');
        }
        const controls = [LuckyCardControl.doubleBet, LuckyCardControl.clear, LuckyCardControl.remove];
        for (var i = 0; i < 3; i++) {
          at(button(controls[i]), l.actionButton(i), 'button $i');
        }
        at(key('suit-hearts'), l.suitHeader(0), 'the hearts bar');
        at(key('rank-J'), l.rankSelector(0), 'the Jack selector');
        // The ten history cards, in one row, newest at the left.
        at(key('result-latest'), l.resultTile(0), 'the newest card');
        for (var i = 1; i < l.resultCount; i++) {
          at(key('result-${i - 1}'), l.resultTile(i), 'card $i');
        }
        expect(key('result-${l.resultCount - 1}'), findsNothing, reason: 'only ${l.resultCount} cards are drawn');
        expect(find.byType(LuckyCardResultTile), findsNWidgets(l.resultCount));
        await rig.finish();
      });
    }

    testWidgets('PLAY and WIN are in the wheel\'s column, the results and the buttons are not', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, const Size(1920, 1080), desktopScene(rig));
      await rig.open();
      expect(find.descendant(of: find.byType(LuckyCardDesktopSide), matching: key('total-bet')), findsOneWidget);
      expect(find.descendant(of: find.byType(LuckyCardDesktopSide), matching: key('win')), findsOneWidget);
      expect(find.descendant(of: find.byType(LuckyCardDesktopSide), matching: find.byType(LuckyCardResultsPanel)), findsNothing);
      expect(find.descendant(of: find.byType(LuckyCardDesktopSide), matching: find.byType(LuckyCardActionButton)), findsNothing);
      for (final c in LuckyCardChip.values) {
        expect(find.descendant(of: find.byType(LuckyCardActionBar), matching: chip(c)), findsOneWidget, reason: '${c.amount} in the bar');
      }
      expect(find.descendant(of: find.byType(LuckyCardActionBar), matching: find.byType(LuckyCardActionButton)), findsNWidgets(3));
      await rig.finish();
    });
  });

  group('the chips and buttons in the bottom bar work by finger and mouse', () {
    testWidgets('a tap anywhere in a chip\'s slot picks it up; a card takes it; DOUBLE, CLEAR and REMOVE act', (tester) async {
      final rig = BetRig(tester);
      const size = Size(1920, 1080);
      await pumpAtSize(tester, size, desktopScene(rig));
      await rig.open();
      final l = LuckyCardLayout.desktop(size);
      final p = rig.provider;
      for (var i = 0; i < LuckyCardLayout.chipCount; i++) {
        final slot = l.chip(i);
        for (final x in [slot.left + 2, slot.center.dx, slot.right - 2]) {
          p.deselectChip();
          await tester.pump();
          await tester.tapAt(Offset(x, slot.center.dy));
          await settle(tester);
          expect(p.activeChip, LuckyCardChip.values[i], reason: 'tap at $x on chip $i');
        }
      }
      await tester.tapAt(l.chip(1).center);
      await tester.pump();
      await tester.tapAt(l.cardCell(0, 0).center);
      await tester.pump();
      expect(p.total, 10);
      await tester.tapAt(l.actionButton(0).center);
      await tester.pump();
      expect(p.total, 20, reason: 'DOUBLE');
      await tester.tapAt(l.actionButton(2).center);
      await tester.pump();
      expect(p.activeChip, isNull, reason: 'REMOVE puts the chip in hand down');
      await tester.tapAt(l.actionButton(1).center);
      await tester.pump();
      expect(p.total, 0, reason: 'CLEAR');
      await rig.finish();
    });

    testWidgets('the sounds hooks are told: a chip, a button', (tester) async {
      final rig = BetRig(tester);
      final events = <String>[];
      const size = Size(1280, 720);
      await pumpAtSize(
        tester,
        size,
        LuckyCardCanvas(
          layoutOf: LuckyCardLayout.desktop,
          actionBar: (context, layout) => LuckyCardActionBar(
            provider: rig.provider,
            layout: layout,
            art: art,
            onChipSelected: (c) => events.add('chip ${c.amount}'),
            onButtonPressed: (c) => events.add('pressed ${c.name}'),
          ),
        ),
      );
      await rig.open();
      final l = LuckyCardLayout.desktop(size);
      await tester.tapAt(l.chip(3).center);
      await tester.pump();
      rig.provider.tapCard(LuckyCard.all.first);
      await tester.pump();
      await tester.tapAt(l.actionButton(1).center);
      await tester.pump();
      expect(events, ['chip 100', 'pressed clear']);
      await rig.finish();
    });
  });

  group('the wheel is always on screen and its hub goes back to the gift box', () {
    testWidgets('the wheel binding with permanent clears the hub when betting opens; without it, it leaves the hub alone', (tester) async {
      for (final permanent in [true, false]) {
        final rig = BetRig(tester);
        await pumpAtSize(
          tester,
          const Size(1920, 1080),
          LuckyCardCanvas(
            layoutOf: LuckyCardLayout.desktop,
            side: (context, layout) => LuckyCardWheelBinding(provider: rig.provider, layout: layout, zone: layout.side, permanent: permanent),
          ),
        );
        await rig.open();
        rig.betTenOnEveryCard();
        await rig.world.runUntil(99.0);
        await tester.pump();
        expect(wheelState(tester).result?.card, SimulatedLuckyCardServer.winnerOf(cycle), reason: 'the hub shows the winner (permanent: $permanent)');
        final state = wheelState(tester);
        await rig.runIntoNextCycle(8);
        await tester.pump();
        expect(rig.provider.isLocked, isFalse, reason: 'betting is open again');
        expect(identical(wheelState(tester), state), isTrue, reason: 'the same wheel, not a new one');
        if (permanent) {
          expect(state.result, isNull, reason: 'the hub is the gift box again');
        } else {
          expect(state.result, isNotNull, reason: 'a wheel that is not permanent keeps its hub');
        }
        await rig.finish();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('clearResult does nothing while a spin is running and nothing when there is no result', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(
        tester,
        const Size(1920, 1080),
        LuckyCardCanvas(
          layoutOf: LuckyCardLayout.desktop,
          side: (context, layout) => LuckyCardWheelBinding(provider: rig.provider, layout: layout, zone: layout.side, permanent: true),
        ),
      );
      await rig.open();
      wheelState(tester).clearResult();
      expect(wheelState(tester).result, isNull);
      rig.betTenOnEveryCard();
      await rig.world.runUntil(92.0);
      await tester.pump();
      expect(wheelState(tester).isSpinning, isTrue);
      wheelState(tester).clearResult();
      expect(wheelState(tester).isSpinning, isTrue, reason: 'the spin goes on');
      await rig.world.runUntil(99.0);
      await tester.pump();
      expect(wheelState(tester).result, isNotNull, reason: 'and still lands');
      await rig.finish();
    });
  });

  group('the real screen on the seven reference desktop sizes', () {
    for (final d in kDesktopReferenceSizes) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): the wheel stays, the board dims and locks, no card flips, the hub shows the winner, then the board comes back', (tester) async {
        final rig = BetRig(tester);
        await openGame(tester, rig, d.size);
        final l = LuckyCardLayout.of(d.size, desktopPlatform: true);
        final p = rig.provider;
        expect(l.isDesktop, isTrue);
        expect(find.byType(LuckyCardDesktopSide), findsOneWidget);
        expect(find.byType(LuckyCardActionBar), findsOneWidget);
        expect(find.byType(LuckyCardChipBar), findsNothing, reason: 'no tablet chip bar');
        expect(find.byType(LuckyCardRegionSwap), findsNothing, reason: 'nothing is swapped on the desktop');
        expect(onBoard, isTrue);
        expect(onWheel, isTrue, reason: 'the wheel is there while betting is open');
        expect(wheelState(tester).result, isNull);
        expect(tester.takeException(), isNull);
        expect(pieceOpacity(tester, 'suit-hearts'), 1.0);

        // A finger: a chip, a card, DOUBLE, CLEAR.
        await tester.tapAt(l.chip(1).center);
        await tester.pump();
        await tester.tapAt(l.cardCell(0, 0).center);
        await tester.pump();
        expect(p.total, 10);
        await tester.tapAt(l.actionButton(0).center);
        await tester.pump();
        expect(p.total, 20, reason: 'DOUBLE');
        await tester.tapAt(l.actionButton(1).center);
        await tester.pump();
        expect(p.total, 0, reason: 'CLEAR');

        // The lock.
        final before = wheelState(tester);
        rig.betTenOnEveryCard();
        await tester.pump();
        await rig.world.runUntil(90.5);
        await settle(tester);
        expect(p.isLocked, isTrue);
        expect(onBoard, isTrue, reason: 'the board stays');
        expect(key('rank-J'), findsOneWidget, reason: 'the rank selectors stay (no card column)');
        expect(find.byType(LuckyCardRevealColumn), findsNothing, reason: 'no flipping card on the desktop');
        expect(onWheel, isTrue);
        expect(identical(wheelState(tester), before), isTrue, reason: 'the very same wheel, not a new one');
        expect(pieceOpacity(tester, 'suit-hearts'), closeTo(0.55, 0.001), reason: 'the board is dimmed');
        final totalLocked = p.total;
        await tester.tapAt(l.cardCell(1, 1).center);
        await tester.tapAt(l.suitHeader(2).center);
        await tester.tapAt(l.rankSelector(0).center);
        await tester.tapAt(l.chip(2).center);
        await tester.pump();
        expect(p.total, totalLocked, reason: 'a locked board takes no taps');
        expect(tester.takeException(), isNull, reason: 'the lock');

        // The spin and the win.
        await rig.world.runUntil(93.5);
        await tester.pump();
        expect(wheelState(tester).isSpinning, isTrue, reason: 'the wheel turns in its column');
        await rig.world.runUntil(99.0);
        await settle(tester);
        expect(wheelState(tester).result?.card, SimulatedLuckyCardServer.winnerOf(cycle), reason: 'the hub shows the winner');
        expect(find.byType(LuckyCardWinPopup), findsOneWidget, reason: 'the win popup');
        expect(tester.takeException(), isNull, reason: 'the reveal');
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          final size = t.style?.fontSize;
          if (size != null) expect(size, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: '"${t.data}"');
        }

        // Betting opens again.
        await rig.runIntoNextCycle(8);
        await settle(tester);
        expect(find.byType(LuckyCardWinPopup), findsNothing);
        expect(p.isLocked, isFalse);
        expect(identical(wheelState(tester), before), isTrue, reason: 'still the same wheel');
        expect(wheelState(tester).result, isNull, reason: 'the hub is the gift box again');
        expect(pieceOpacity(tester, 'suit-hearts'), 1.0, reason: 'the board is bright again');
        await tester.tapAt(l.chip(1).center);
        await tester.pump();
        await tester.tapAt(l.cardCell(0, 0).center);
        await tester.pump();
        expect(p.total, 10, reason: 'and takes bets');
        await rig.finish();
      });
    }
  });

  group('the phone and the tablet screens do not change', () {
    testWidgets('a desktop platform with a phone-sized screen gets the phone arrangement: no wheel while betting', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig, const Size(844, 390));
      expect(find.byType(LuckyCardDesktopSide), findsNothing);
      expect(find.byType(LuckyCardActionBar), findsNothing);
      expect(find.byType(LuckyCardRegionSwap), findsNWidgets(2));
      expect(onBoard, isTrue);
      expect(onWheel, isFalse);
      await rig.finish();
    });

    testWidgets('a desktop platform with a screen under 1280 x 720 gets the tablet arrangement', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig, const Size(1024, 768));
      expect(find.byType(LuckyCardDesktopSide), findsNothing);
      expect(find.byType(LuckyCardChipBar), findsOneWidget);
      expect(onWheel, isFalse);
      await rig.finish();
    });

    testWidgets('not a desktop platform with a 1920 x 1080 screen (the real app today): the tablet arrangement', (tester) async {
      final rig = BetRig(tester);
      await openGame(tester, rig, const Size(1920, 1080), desktopPlatform: false);
      expect(find.byType(LuckyCardDesktopSide), findsNothing);
      expect(find.byType(LuckyCardActionBar), findsNothing);
      expect(find.byType(LuckyCardChipBar), findsOneWidget);
      expect(find.byType(LuckyCardRegionSwap), findsNWidgets(2));
      expect(onWheel, isFalse);
      await rig.finish();
    });

    testWidgets('the desktop-only zones are not built on a phone or a tablet even when offered', (tester) async {
      final rig = BetRig(tester);
      for (final layoutOf in [LuckyCardLayout.phone, LuckyCardLayout.tablet]) {
        await pumpAtSize(
          tester,
          const Size(1280, 800),
          LuckyCardCanvas(
            layoutOf: layoutOf,
            resultsBar: (context, layout) => const SizedBox(key: ValueKey('offered-results')),
            actionBar: (context, layout) => const SizedBox(key: ValueKey('offered-actions')),
          ),
        );
        expect(key('offered-results'), findsNothing);
        expect(key('offered-actions'), findsNothing);
      }
      await rig.finish();
    });
  });

  group('a picture to look at', () {
    Future<void> shoot(WidgetTester tester, Device d, String name, Future<void> Function(BetRig rig) arrange) async {
      final rig = BetRig(tester);
      await openGame(tester, rig, d.size);
      await arrange(rig);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${d.width.toInt()}x${d.height.toInt()}.png'));
      await rig.finish();
    }

    for (final d in const [Device('smallest', 1280, 720), Device('laptop', 1440, 900), Device('full hd', 1920, 1080)]) {
      testWidgets('betting, a bet on the board: ${d.name}', (tester) async {
        await shoot(tester, d, 'desktop_screen_betting', (rig) async {
          rig.provider.selectChip(LuckyCardChip.ten);
          rig.provider.tapSuit(LuckyCardSuit.hearts);
          rig.provider.tapRank(LuckyCardRank.jack);
          rig.provider.selectChip(LuckyCardChip.fifty);
          await tester.pump();
        });
      });
    }

    testWidgets('the wheel turning, the board dimmed: full hd', (tester) async {
      await shoot(tester, const Device('full hd', 1920, 1080), 'desktop_screen_spin', (rig) async {
        rig.betTenOnEveryCard();
        await rig.world.runUntil(93.5);
      });
    });

    testWidgets('the win: smallest', (tester) async {
      await shoot(tester, const Device('smallest', 1280, 720), 'desktop_screen_win', (rig) async {
        rig.betTenOnEveryCard();
        await rig.world.runUntil(99.0);
      });
    });
  });
}
