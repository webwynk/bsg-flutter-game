// Tests for the Lucky 16 Card desktop arrangement (desktop phase 1): the layout's numbers against the
// approved mockup (reference-design/lucky16/lucky16-desktop.html) at the desktop sizes, and the real screen
// (lib/screens/lucky16_screen.dart) at those sizes: the header, the wheel's column with PLAY and WIN, the
// board, the row of ten results and the bottom bar. The golden pictures are copied to
// reference-design/lucky16/screenshots/desktop_phase1/.

import 'package:best_smart_game/models/lucky16_board.dart';
import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_layout.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'lucky16_board_test.dart' show expectNear, loadArt, tapPiece;
import 'lucky16_screen_test.dart' show key, openGame, textIn;
import 'lucky16_tablet_test.dart' show inside, kTablets;
import 'ui_harness.dart';

const List<Device> kDesktops = [
  Device('small laptop', 1280, 720),
  Device('laptop', 1366, 768),
  Device('large laptop', 1440, 900),
  Device('hd plus', 1600, 900),
  Device('full hd', 1920, 1080),
  Device('quad hd', 2560, 1440),
];

const List<Device> kGoldenDesktops = [Device('full hd', 1920, 1080), Device('laptop', 1366, 768)];

Lucky16Layout desktopOf(Size size) => Lucky16Layout.of(size, desktopPlatform: true);

void main() {
  setUpAll(() async {
    await loadLucky16Fonts();
    await loadLucky16Icons();
  });

  group('who gets the desktop arrangement', () {
    test('at least 1280 x 720 when told so; never without the flag', () {
      for (final d in kDesktops) {
        expect(desktopOf(d.size).isDesktop, isTrue, reason: '$d');
        expect(Lucky16Layout.of(d.size).isDesktop, isFalse, reason: '$d, no flag');
      }
      expect(desktopOf(const Size(1279, 800)).isDesktop, isFalse);
      expect(desktopOf(const Size(1366, 719)).isDesktop, isFalse);
      for (final d in kPhoneMatrix) {
        expect(desktopOf(d.size).isDesktop, isFalse, reason: '$d is a phone');
      }
    });

    test('the tablets without the flag stay tablets', () {
      for (final d in kTablets) {
        expect(Lucky16Layout.of(d.size).isTablet, isTrue);
      }
    });
  });

  group('the sizes of the approved mockup', () {
    test('1920 x 1080: card 233.8 x 159, bar 60.2, selector 148.1, board 1124 x 737, wheel 717', () {
      final l = desktopOf(const Size(1920, 1080));
      expect(l.cardSize.width, closeTo(233.8, 0.5));
      expect(l.cardSize.height, closeTo(159, 0.5));
      expect(l.suitHeader(0).height, closeTo(60.2, 0.5));
      expect(l.rankSelector(0).width, closeTo(148.1, 0.5));
      expect(l.designBoard.width, closeTo(1124, 1));
      expect(l.designBoard.height, closeTo(737, 1));
      expect(l.wheelDiameter, closeTo(717, 1));
    });

    test('1366 x 768: card 162.2 x 110.3, board 779 x 511, wheel 531', () {
      final l = desktopOf(const Size(1366, 768));
      expect(l.cardSize.width, closeTo(162.2, 0.5));
      expect(l.cardSize.height, closeTo(110.3, 0.5));
      expect(l.designBoard.width, closeTo(779, 1));
      expect(l.designBoard.height, closeTo(511, 1));
      expect(l.wheelDiameter, closeTo(531, 1));
    });
  });

  for (final d in kDesktops) {
    group('$d', () {
      final l = desktopOf(d.size);
      final canvas = Offset.zero & l.canvasSize;

      test('every zone is inside the canvas and none overlaps another', () {
        final zones = l.zones.entries.toList();
        expect(l.zones.keys, containsAll(['resultsBar', 'actionBar']));
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

      test('the wheel column is at the left: the wheel over PLAY and WIN, which end level with the bottom bar', () {
        expect(l.side.left, closeTo(l.designBody.left, 1e-9));
        expect(l.wheelBox.top, greaterThanOrEqualTo(l.topBar.bottom));
        expect(inside(l.side, l.wheelBox), isTrue);
        expect(l.totalBetCell.top, greaterThanOrEqualTo(l.wheelBox.bottom));
        expect(l.winCell.bottom, closeTo(l.actionBar.bottom, 1e-6));
        expect(l.winCell.right, closeTo(l.wheelBox.right, 1e-6), reason: 'PLAY and WIN are as wide as the wheel');
      });

      test('the board is flush with the right column, the ten results and the bar under it', () {
        expect(l.designBoard.left, closeTo(l.rightColumn.left, 1e-6));
        expect(l.designBoard.bottom, lessThanOrEqualTo(l.resultsBar.top));
        expect(l.resultsBar.bottom, lessThanOrEqualTo(l.actionBar.top));
        expect(l.resultCount, 10);
        for (var i = 0; i < l.resultCount; i++) {
          expect(inside(l.resultsBar, l.resultTile(i)), isTrue, reason: 'card $i');
        }
      });

      test('the bottom bar: five chips at the left, then three buttons in a row, none touching', () {
        for (var i = 0; i < Lucky16Layout.chipCount; i++) {
          expect(inside(l.actionBar, l.chip(i)), isTrue, reason: 'chip $i');
        }
        expect(l.actionButton(0).left, greaterThan(l.chip(4).right - 1));
        for (var i = 0; i < Lucky16Layout.actionButtonCount; i++) {
          expect(inside(l.actionBar, l.actionButton(i)), isTrue, reason: 'button $i');
          expect(l.actionButton(i).height, greaterThanOrEqualTo(kLucky16MinTapDp));
          if (i > 0) expect(l.actionButton(i).left, greaterThan(l.actionButton(i - 1).right));
        }
      });
    });
  }

  group('on the screen', () {
    for (final d in kDesktops) {
      testWidgets('$d: everything is where the layout says, and nothing overflows', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size, desktopPlatform: true);
        expect(tester.takeException(), isNull);
        final l = desktopOf(d.size);
        expectNear(tester.getRect(key('top-bar')), l.topBar, 'header');
        expectNear(tester.getRect(find.byType(Lucky16Wheel)), l.wheelBox, 'wheel');
        expectNear(tester.getRect(key('total-bet')), l.totalBetCell, 'PLAY');
        expectNear(tester.getRect(key('win')), l.winCell, 'WIN');
        expectNear(tester.getRect(key('action-bar')), l.actionBar, 'bottom bar');
        expectNear(tester.getRect(key('a_hearts')), l.cardCell(0, 0), 'card');
        expectNear(tester.getRect(key('rank-K')), l.rankSelector(3), 'selector');
        for (final chip in Lucky16Chip.values) {
          expectNear(tester.getRect(key('chip-${chip.amount}')), l.chip(chip.index), 'chip ${chip.amount}');
        }
        expectNear(tester.getRect(key('button-remove')), l.actionButton(2), 'REMOVE');
        expectNear(tester.getRect(key('result-latest')), l.resultTile(0), 'newest result');
        expectNear(tester.getRect(key('result-8')), l.resultTile(9), 'tenth result');
        expect(key('result-9'), findsNothing, reason: 'ten results, not twelve');
        await rig.finish();
      });
    }

    testWidgets('betting works: the chips, the board, the buttons', (tester) async {
      await loadArt(tester);
      final rig = BetRig(tester);
      await openGame(tester, rig, size: const Size(1920, 1080), desktopPlatform: true);
      await tapPiece(tester, 'chip-100');
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
    for (final d in kGoldenDesktops) {
      final size = '${d.width.toInt()}x${d.height.toInt()}';
      testWidgets('$size: betting, the mockup\'s sample bets', (tester) async {
        await loadArt(tester);
        final rig = BetRig(tester);
        await openGame(tester, rig, size: d.size, desktopPlatform: true);
        await tapPiece(tester, 'chip-10');
        await tapPiece(tester, 'suit-hearts');
        await tapPiece(tester, 'rank-A');
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/desktop1_betting_$size.png'));
        await rig.finish();
      });
    }
  });
}
