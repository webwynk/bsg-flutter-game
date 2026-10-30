// Tests for the Lucky 16 Card tablet arrangement (tablet phase 1): the layout's numbers against the
// approved mockup (reference-design/lucky16/lucky16-tablet.html) at the tablet sizes, and the real screen
// (lib/screens/lucky16_screen.dart) at those sizes: the header, the board with the chip bar under it, and
// the bet panel with its stacked buttons. The golden pictures are copied to
// reference-design/lucky16/screenshots/tablet_phase1/.

import 'package:best_smart_game/models/lucky16_board.dart';
import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'lucky16_board_test.dart' show expectNear, loadArt, tapPiece;
import 'lucky16_screen_test.dart' show key, openGame, textIn;
import 'ui_harness.dart';

const List<Device> kTablets = [
  Device('android tablet', 1024, 600),
  Device('small tablet', 1024, 768),
  Device('ipad air', 1180, 820),
  Device('tablet', 1280, 800),
  Device('large tablet', 1366, 1024),
];

const List<Device> kGoldenTablets = [Device('small tablet', 1024, 768), Device('ipad air', 1180, 820)];

bool inside(Rect outer, Rect inner, {double slack = 0.01}) =>
    inner.left >= outer.left - slack &&
    inner.top >= outer.top - slack &&
    inner.right <= outer.right + slack &&
    inner.bottom <= outer.bottom + slack;

void main() {
  setUpAll(() async {
    await loadLucky16Fonts();
    await loadLucky16Icons();
  });

  group('who gets the tablet arrangement', () {
    test('Lucky Card\'s rule: at least 600 on the short side and 800 on the long side', () {
      for (final d in kTablets) {
        expect(Lucky16Layout.of(d.size).isTablet, isTrue, reason: '$d');
      }
      for (final d in kPhoneMatrix) {
        expect(Lucky16Layout.of(d.size).isTablet, isFalse, reason: '$d');
      }
      expect(Lucky16Layout.of(const Size(790, 600)).isTablet, isFalse, reason: 'too short a long side');
    });

    test('the canvas is the whole screen', () {
      expect(Lucky16Layout.of(const Size(1024, 768)).canvasRect, const Rect.fromLTWH(0, 0, 1024, 768));
    });
  });

  group('the sizes of the approved mockup', () {
    test('1180 x 820: card 164.5 x 111.8, bar 42.3, selector 104.2, board 791 x 518, panel 342', () {
      final l = Lucky16Layout.of(const Size(1180, 820));
      expect(l.cardSize.width, closeTo(164.5, 0.5));
      expect(l.cardSize.height, closeTo(111.8, 0.5));
      expect(l.suitHeader(0).height, closeTo(42.3, 0.5));
      expect(l.rankSelector(0).width, closeTo(104.2, 0.5));
      expect(l.designBoard.width, closeTo(791, 1));
      expect(l.designBoard.height, closeTo(518, 1));
      expect(l.side.width, closeTo(342, 0.5));
    });

    test('1024 x 768: card 142.1 x 96.6, board 683 x 448, panel 300', () {
      final l = Lucky16Layout.of(const Size(1024, 768));
      expect(l.cardSize.width, closeTo(142.1, 0.5));
      expect(l.cardSize.height, closeTo(96.6, 0.5));
      expect(l.designBoard.width, closeTo(683, 1));
      expect(l.designBoard.height, closeTo(448, 1));
      expect(l.side.width, 300);
    });
  });

  for (final d in kTablets) {
    group('$d', () {
      final l = Lucky16Layout.of(d.size);
      final canvas = Offset.zero & l.canvasSize;

      test('every zone is inside the canvas and none overlaps another', () {
        final zones = l.zones.entries.toList();
        expect(l.zones.keys, contains('chipBar'));
        for (final z in zones) {
          expect(inside(canvas, z.value), isTrue, reason: '${z.key} ${z.value}');
        }
        for (var i = 0; i < zones.length; i++) {
          for (var j = i + 1; j < zones.length; j++) {
            final overlap = zones[i].value.intersect(zones[j].value);
            expect(overlap.width <= 0.01 || overlap.height <= 0.01, isTrue, reason: '${zones[i].key} ${zones[j].key}');
          }
        }
      });

      test('the chip bar is under the board, as wide as its column; the board stays above it', () {
        expect(l.chipBar.left, closeTo(l.designBody.left, 1e-9));
        expect(l.chipBar.right, closeTo(l.side.left - l.designBodyGapX, 1e-9));
        expect(l.chipBar.bottom, closeTo(l.designBody.bottom, 1e-9));
        expect(l.designBoard.bottom, lessThanOrEqualTo(l.chipBar.top + 0.01));
      });

      test('the five chips are in the bar, side by side, and never overlap', () {
        for (var i = 0; i < Lucky16Layout.chipCount; i++) {
          expect(inside(l.chipBar, l.chip(i)), isTrue, reason: 'chip $i');
          expect(l.chip(i).height, greaterThanOrEqualTo(kLucky16MinTapDp));
          if (i > 0) expect(l.chip(i).left, closeTo(l.chip(i - 1).right, 1e-6));
        }
      });

      test('in the panel: PLAY and WIN, 12 cards under them, and three stacked buttons at the bottom', () {
        final inner = l.panelInner;
        expect(inside(inner, l.totalBetCell), isTrue);
        expect(inside(inner, l.winCell), isTrue);
        for (var i = 0; i < l.resultCount; i++) {
          expect(inside(l.resultsPanel, l.resultTile(i)), isTrue, reason: 'card $i');
        }
        expect(l.resultsPanel.bottom, lessThanOrEqualTo(l.actionButton(0).top), reason: 'the cards clear the buttons');
        expect(l.actionButton(2).bottom, closeTo(inner.bottom, 1e-6));
        for (var i = 0; i < Lucky16Layout.actionButtonCount; i++) {
          expect(l.actionButton(i).width, closeTo(inner.width, 1e-9));
          expect(l.actionButton(i).height, greaterThanOrEqualTo(kLucky16MinTapDp));
          if (i > 0) expect(l.actionButton(i).top, greaterThan(l.actionButton(i - 1).bottom));
        }
      });
    });
  }

  group('on the screen', () {
    for (final d in kTablets) {
      testWidgets('$d: everything is where the layout says, and nothing overflows', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        expect(tester.takeException(), isNull);
        final l = Lucky16Layout.of(d.size);
        expectNear(tester.getRect(key('top-bar')), l.topBar, 'header');
        expectNear(tester.getRect(key('bet-panel')), l.side, 'panel');
        expectNear(tester.getRect(key('chip-bar')), l.chipBar, 'chip bar');
        expectNear(tester.getRect(key('a_hearts')), l.cardCell(0, 0), 'card');
        expectNear(tester.getRect(key('rank-K')), l.rankSelector(3), 'selector');
        for (final chip in Lucky16Chip.values) {
          expectNear(tester.getRect(key('chip-${chip.amount}')), l.chip(chip.index), 'chip ${chip.amount}');
        }
        expectNear(tester.getRect(key('button-remove')), l.actionButton(2), 'REMOVE');
        expectNear(tester.getRect(key('result-latest')), l.resultTile(0), 'newest result');
        await rig.finish();
      });
    }

    testWidgets('the chips in the bar work: the one tapped goes in hand and the board uses it', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      await openGame(tester, rig, size: const Size(1180, 820));
      await tapPiece(tester, 'chip-100');
      expect(rig.provider.activeChip, Lucky16Chip.hundred);
      await tapPiece(tester, 'rank-A');
      for (final card in Lucky16Card.ofRank(Lucky16Rank.ace)) {
        expect(rig.provider.stakeOn(card), 100, reason: card.key);
      }
      expect(textIn(tester, 'total-bet'), '400');
      await tapPiece(tester, 'button-doubleBet');
      expect(textIn(tester, 'total-bet'), '800');
      await tapPiece(tester, 'button-clear');
      expect(rig.provider.isBoardEmpty, isTrue);
      await rig.finish();
    });
  });

  group('pictures to compare with the approved mockup', () {
    for (final d in kGoldenTablets) {
      final size = '${d.width.toInt()}x${d.height.toInt()}';
      testWidgets('$size: betting, the mockup\'s sample bets', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size);
        await tapPiece(tester, 'chip-10');
        await tapPiece(tester, 'suit-hearts');
        await tapPiece(tester, 'rank-A');
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tablet1_betting_$size.png'));
        await rig.finish();
      });
    }
  });
}
