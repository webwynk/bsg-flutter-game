// Tests for lib/widgets/lucky_card/lucky_card_layout.dart: the geometry alone, at
// every device of the matrix and across a sweep of shapes between them.

import 'dart:math' as math;
import 'dart:ui';

import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

const double eps = 0.001;

bool overlaps(Rect a, Rect b) {
  final i = a.intersect(b);
  return i.width > eps && i.height > eps;
}

bool containsRect(Rect outer, Rect inner) =>
    inner.left >= outer.left - eps &&
    inner.top >= outer.top - eps &&
    inner.right <= outer.right + eps &&
    inner.bottom <= outer.bottom + eps;

/// Every rule that must hold at any size.
void expectSound(Size screen, {bool tapTargets = true}) {
  final l = LuckyCardLayout.of(screen);
  final why = '$screen';
  final canvas = Offset.zero & l.canvasSize;

  // The canvas sits inside the screen, centred, within the band, at scale h/1000.
  expect(containsRect(Offset.zero & l.screen, l.canvasRect), isTrue, reason: why);
  expect(l.canvasRect.center.dx, closeTo(l.screen.width / 2, eps), reason: why);
  expect(l.canvasRect.center.dy, closeTo(l.screen.height / 2, eps), reason: why);
  final ratio = l.canvasRect.width / l.canvasRect.height;
  expect(ratio, inInclusiveRange(LuckyCardLayout.minRatio - eps, LuckyCardLayout.maxRatio + eps), reason: why);
  expect(l.scale, closeTo(l.canvasRect.height / 1000, 1e-9), reason: why);
  final screenRatio = screen.width / screen.height;
  if (screenRatio >= LuckyCardLayout.minRatio && screenRatio <= LuckyCardLayout.maxRatio) {
    expect(l.usedShare, closeTo(1.0, 1e-9), reason: 'a screen in the band is filled completely: $why');
  }

  // The zones are inside the canvas and never overlap each other.
  final zones = l.zones;
  for (final e in zones.entries) {
    expect(containsRect(canvas, e.value), isTrue, reason: '${e.key} outside the canvas: $why');
    expect(e.value.width > 0 && e.value.height > 0, isTrue, reason: '${e.key} is empty: $why');
  }
  final names = zones.keys.toList();
  for (var i = 0; i < names.length; i++) {
    for (var j = i + 1; j < names.length; j++) {
      expect(overlaps(zones[names[i]]!, zones[names[j]]!), isFalse,
          reason: '${names[i]} overlaps ${names[j]}: $why');
    }
  }

  // The body (the reference design): everything under the header, inside its padding (1% of
  // the width, 6 to 10 dp), with the bet panel at its right. Every zone sits inside it.
  final body = l.designBody;
  expect(body.left, greaterThanOrEqualTo(6 - eps), reason: 'padding at least 6 dp: $why');
  expect(body.left, lessThanOrEqualTo(10 + eps), reason: 'padding at most 10 dp: $why');
  expect(l.canvasSize.width - body.right, closeTo(body.left, eps), reason: 'the same padding on both sides: $why');
  expect(l.canvasSize.height - body.bottom, closeTo(body.left, eps), reason: 'and under the body: $why');
  expect(body.top - l.designHeaderBar.bottom, closeTo(LuckyCardLayout.designBodyGapY, eps), reason: '6 dp under the header: $why');
  for (final name in ['grid', 'rankColumn', 'side']) {
    expect(containsRect(body, zones[name]!), isTrue, reason: '$name inside the body: $why');
  }

  // The bet panel: 38% of the width, between 244 and 360 dp, the full height of the body.
  expect(l.side.width, closeTo((l.canvasSize.width * 0.38).clamp(244.0, 360.0), eps), reason: why);
  expect(l.side.right, closeTo(body.right, eps), reason: why);
  expect(l.side.top, closeTo(body.top, eps), reason: why);
  expect(l.side.bottom, closeTo(body.bottom, eps), reason: why);

  // The board: the largest box of shape 1.48 : 1 that fits what is left of the body, centred in
  // it, with the design's gap between it and the panel.
  final section = l.designSection;
  final board = l.designBoard;
  expect(section.right, closeTo(l.side.left - l.designBodyGapX, eps), reason: 'the gap to the panel: $why');
  expect(containsRect(section, board), isTrue, reason: 'the board inside its section: $why');
  expect(board.center.dx, closeTo(section.center.dx, eps), reason: 'centred across: $why');
  expect(board.center.dy, closeTo(section.center.dy, eps), reason: 'centred up and down: $why');
  expect(board.width >= section.width - eps || board.height >= section.height - eps, isTrue, reason: 'as large as the section allows: $why');
  expect(containsRect(board, l.grid), isTrue, reason: why);
  expect(containsRect(board, l.rankColumn), isTrue, reason: why);
  expect(l.grid.top, closeTo(board.top, eps), reason: why);
  expect(l.grid.bottom, closeTo(board.bottom, eps), reason: 'the board reaches the bottom of its box: $why');

  // The 16 grid cells sit inside the grid, never overlap, and are one gap (1% of the board's
  // width) apart, across and down; the rank column is one gap from the grid.
  final gap = l.designBoardGap;
  expect(gap, closeTo(board.width * 0.01, eps), reason: why);
  for (var c = 0; c < LuckyCardLayout.gridColumns; c++) {
    for (var r = 0; r < LuckyCardLayout.gridRows; r++) {
      final cell = l.gridCell(c, r);
      expect(containsRect(l.grid, cell), isTrue, reason: 'cell $c,$r outside the grid: $why');
      for (var c2 = 0; c2 < LuckyCardLayout.gridColumns; c2++) {
        for (var r2 = 0; r2 < LuckyCardLayout.gridRows; r2++) {
          if (c2 * 10 + r2 > c * 10 + r) {
            expect(overlaps(cell, l.gridCell(c2, r2)), isFalse, reason: 'cells overlap: $why');
          }
        }
      }
      if (c < LuckyCardLayout.gridColumns - 1) {
        expect(l.gridCell(c + 1, r).left - cell.right, closeTo(gap, eps), reason: 'gap across: $why');
      }
      if (r < LuckyCardLayout.gridRows - 1) {
        expect(l.gridCell(c, r + 1).top - cell.bottom, closeTo(gap, eps), reason: 'gap down: $why');
      }
    }
  }
  expect(l.rankColumn.left - l.grid.right, closeTo(gap, eps), reason: why);

  // The design's proportions: four cards of 458 parts then the badge of 481 across; the bar row
  // of 157 parts over three card rows of 464 down.
  expect(l.rankSelector(0).width / l.cardCell(0, 0).width, closeTo(481 / 458, 1e-9), reason: why);
  expect(l.cardCell(0, 0).height / l.suitHeader(0).height, closeTo(464 / 157, 1e-9), reason: why);
  for (var c = 1; c < 4; c++) {
    expect(l.cardCell(c, 0).width, closeTo(l.cardCell(0, 0).width, eps), reason: why);
  }

  // The rank badges are level with their rows of cards; every picture fills its cell (the
  // design's own object-fit: fill).
  for (var r = 0; r < 3; r++) {
    final sel = l.rankSelector(r);
    expect(containsRect(l.rankColumn, sel), isTrue, reason: why);
    for (var c = 0; c < 4; c++) {
      final cell = l.cardCell(c, r);
      expect(sel.top, closeTo(cell.top, eps), reason: 'badge level with its row: $why');
      expect(sel.height, closeTo(cell.height, eps), reason: why);
    }
  }
  for (var c = 0; c < 4; c++) {
    expect(l.suitHeader(c).top, closeTo(l.grid.top, eps), reason: why);
  }
  expect(l.cardSize, l.cardCell(0, 0).size, reason: why);

  // The text on the board is sized from the board's width, as the design does (CSS cqw).
  expect(l.designCardFont, closeTo(board.width * 0.034, eps), reason: why);
  expect(l.designBarFont, closeTo(board.width * 0.021, eps), reason: why);
  expect(l.designBadgeFont, closeTo(board.width * 0.024, eps), reason: why);

  // A picture is stretched to its cell, so the cell must have the picture's shape. The design's
  // cells match the new pictures (card 549 x 556, bar 821 x 281, badge 878 x 846) to within 4%,
  // the most that the board's gap, taken from its width, can bend them when it is limited by its
  // height. Checked where the supported devices are.
  if (tapTargets) {
    expect(l.cardCell(0, 0).width / l.cardCell(0, 0).height, closeTo(549 / 556, 0.04 * 549 / 556), reason: 'card shape: $why');
    expect(l.suitHeader(0).width / l.suitHeader(0).height, closeTo(821 / 281, 0.04 * 821 / 281), reason: 'bar shape: $why');
    expect(l.rankSelector(0).width / l.rankSelector(0).height, closeTo(878 / 846, 0.04 * 878 / 846), reason: 'badge shape: $why');
  }
  for (final dpr in [1.0, 2.0, 3.0]) {
    expect(l.cardCacheWidth(dpr), LuckyCardLayout.cacheWidth(l.cardSize.width, dpr), reason: why);
    expect(l.barCacheWidth(dpr), LuckyCardLayout.cacheWidth(l.suitHeader(0).width, dpr), reason: why);
    expect(l.selectorCacheWidth(dpr), LuckyCardLayout.cacheWidth(l.rankSelector(0).width, dpr), reason: why);
  }

  // The wheel replaces the grid at the lock: its box, pointer included, sits inside
  // the grid zone, centred, and touches the zone on its limiting side.
  final wheel = l.wheelBox;
  expect(containsRect(l.grid, wheel), isTrue, reason: 'wheel inside the grid zone: $why');
  expect(wheel.center.dx, closeTo(l.grid.center.dx, eps), reason: why);
  expect(wheel.center.dy, closeTo(l.grid.center.dy, eps), reason: why);
  expect(wheel.width, closeTo(l.wheelDiameter, eps), reason: why);
  expect(wheel.height, closeTo(l.wheelDiameter * LuckyCardLayout.wheelHeightFactor, eps), reason: why);
  expect(wheel.width >= l.grid.width - eps || wheel.height >= l.grid.height - eps, isTrue, reason: 'the wheel is as large as the zone allows: $why');
  expect(wheel.width, greaterThanOrEqualTo(math.min(l.grid.width, l.grid.height / 1.06) - eps), reason: why);

  // The reveal: the big card sits in the rank column, the coins burst from the
  // wheel's centre, the popup is centred in the canvas.
  final card = l.revealCard;
  expect(containsRect(l.rankColumn, card), isTrue, reason: 'reveal card inside the rank column: $why');
  expect(card.width, closeTo(card.height, eps), reason: why);
  expect(card.center.dx, closeTo(l.rankColumn.center.dx, eps), reason: why);
  expect(card.center.dy, closeTo(l.rankColumn.center.dy, eps), reason: why);
  expect(card.width, greaterThanOrEqualTo(l.rankColumn.width * 0.9), reason: 'the big card nearly fills the column: $why');
  expect(containsRect(l.wheelBox, Rect.fromCenter(center: l.wheelCenter, width: 1, height: 1)), isTrue, reason: 'wheel centre inside the wheel: $why');
  expect(l.wheelCenter.dx, closeTo(l.wheelBox.center.dx, eps), reason: why);
  expect(l.wheelCenter.dy, closeTo(l.wheelBox.bottom - l.wheelDiameter / 2, eps), reason: 'the wheel disc sits below the pointer: $why');
  final popup = l.winPopup;
  expect(containsRect(canvas, popup), isTrue, reason: 'popup inside the canvas: $why');
  expect(popup.center.dx, closeTo(canvas.center.dx, eps), reason: why);
  expect(popup.center.dy, closeTo(canvas.center.dy, eps), reason: why);
  expect(popup.width / popup.height, closeTo(LuckyCardLayout.winPopupAspect, 1e-6), reason: 'popup keeps the shape of its frame: $why');
  expect(popup.width, lessThanOrEqualTo(l.canvasSize.width * 0.92 + eps), reason: why);
  for (final dpr in [1.0, 2.0, 3.0]) {
    expect(l.revealCacheWidth(dpr), LuckyCardLayout.cacheWidth(card.width, dpr), reason: why);
    expect(l.winPopupCacheWidth(dpr), LuckyCardLayout.cacheWidth(popup.width, dpr), reason: why);
  }

  // The header bar (the reference design, App Step H1): flush with the top and both sides
  // of the canvas, never taller than the zone that holds it. What goes inside the bar --
  // the balance, the countdown, the round buttons -- is laid out by the widget as a row, not
  // by this class, so only the bar itself and the sizes it hands out are geometry the layout
  // class owns; lucky_card_top_bar_history_test.dart proves the row that is built from them.
  final headerBar = l.designHeaderBar;
  expect(headerBar.left, closeTo(0, eps), reason: 'flush with the left edge: $why');
  expect(headerBar.top, closeTo(0, eps), reason: 'flush with the top edge: $why');
  expect(headerBar.width, closeTo(l.canvasSize.width, eps), reason: 'the full width: $why');
  expect(headerBar.height, lessThanOrEqualTo(l.topBar.height + eps), reason: 'fits the zone that holds it: $why');
  expect(l.designBallHit, greaterThanOrEqualTo(kLuckyCardMinTapDp - eps), reason: 'a round button answers at least 48 dp: $why');
  expect(l.designBallSize, lessThanOrEqualTo(l.designBallHit + eps), reason: 'drawn no bigger than its own tap area: $why');
  expect(l.designCoinSize, lessThan(l.designPillHeight), reason: 'the coin fits inside its pill: $why');
  // Only guaranteed within the supported device matrix: an off-matrix, severely letterboxed
  // ratio can shrink the header's own zone below the countdown's 40 dp floor, exactly as the
  // strict 48 dp tap-target checks below are also only guaranteed there.
  if (tapTargets) {
    expect(l.designCountdownSize, lessThanOrEqualTo(headerBar.height + eps), reason: 'the countdown fits the bar: $why');
  }
  for (final size in [l.designHeaderHeight, l.designBallSize, l.designPillHeight, l.designCoinSize, l.designCountdownSize, l.designHeaderGap, l.designBalanceFont, l.designCountdownFont, l.designStatusFont]) {
    expect(size, greaterThan(0), reason: why);
  }

  // The bet panel (the design's aside): a border and padding round four rows, from the top TOTAL BET |
  // WIN, the results, the chips and (at the bottom) the three buttons, a gap apart in that order.
  final inner = l.panelInner;
  final panelEdge = LuckyCardLayout.designPanelBorder + l.designPanelPad;
  expect(inner.left, closeTo(l.side.left + panelEdge, eps), reason: why);
  expect(inner.right, closeTo(l.side.right - panelEdge, eps), reason: why);
  expect(inner.top, closeTo(l.side.top + panelEdge, eps), reason: why);
  expect(inner.bottom, closeTo(l.side.bottom - panelEdge, eps), reason: why);
  expect(l.designPanelPad, inInclusiveRange(7, 10), reason: why);
  expect(l.designPanelGap, inInclusiveRange(6, 10), reason: why);

  // Side by side, level, equal, 7 dp apart, filling the width.
  expect(l.totalBetCell.top, closeTo(inner.top, eps), reason: why);
  expect(l.winCell.top, closeTo(l.totalBetCell.top, eps), reason: why);
  expect(l.winCell.width, closeTo(l.totalBetCell.width, eps), reason: why);
  expect(l.winCell.left - l.totalBetCell.right, closeTo(LuckyCardLayout.designCellGap, eps), reason: why);
  expect(l.totalBetCell.left, closeTo(inner.left, eps), reason: why);
  expect(l.winCell.right, closeTo(inner.right, eps), reason: why);
  expect(l.totalBetCell.height, closeTo(l.designTotalHeight, eps), reason: why);
  expect(l.designTotalLabelFont, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: why);

  // The results box: the twelve latest rounds as cards, four across and three down, 3 dp apart, inside
  // a 5 dp padding (spec §17BO). It takes what the panel has left above the chips, but a card is never
  // taller than its picture's own shape.
  final results = l.resultsPanel;
  expect(results.left, closeTo(inner.left, eps), reason: why);
  expect(results.width, closeTo(inner.width, eps), reason: why);
  expect(results.top - l.totalBetCell.bottom, closeTo(l.designPanelGap, eps), reason: why);
  expect(results.height, closeTo(10 + 3 * l.designTileHeight + 2 * 3, eps), reason: why);
  expect(LuckyCardLayout.designResultTiles, 12);
  expect(l.designTileWidth, closeTo((inner.width - 10 - 3 * 3) / 4, eps), reason: why);
  expect(l.designTileHeight, lessThanOrEqualTo(l.designTileWidth * LuckyCardLayout.historyCardAspect + eps), reason: 'never taller than the picture: $why');
  for (var i = 0; i < LuckyCardLayout.designResultTiles; i++) {
    final tile = l.resultTile(i);
    expect(containsRect(results, tile), isTrue, reason: 'result card $i inside the box: $why');
    expect(tile.height, closeTo(l.designTileHeight, eps), reason: why);
    expect(tile.width, closeTo(l.resultTile(0).width, eps), reason: why);
    for (var j = i + 1; j < LuckyCardLayout.designResultTiles; j++) {
      expect(overlaps(tile, l.resultTile(j)), isFalse, reason: 'cards $i and $j overlap: $why');
    }
    if (i % 4 > 0) expect(tile.left - l.resultTile(i - 1).right, closeTo(3, eps), reason: 'cards 3 dp apart across: $why');
    if (i >= 4) expect(tile.top - l.resultTile(i - 4).bottom, closeTo(3, eps), reason: 'rows 3 dp apart: $why');
    if (i >= 4) expect(tile.left, closeTo(l.resultTile(i - 4).left, eps), reason: 'columns line up: $why');
  }
  expect(l.resultTile(0).left, closeTo(results.left + 5, eps), reason: why);
  expect(l.resultTile(0).top, closeTo(results.top + 5, eps), reason: why);
  expect(l.resultTile(3).right, closeTo(results.right - 5, eps), reason: why);
  expect(l.resultTile(11).bottom, closeTo(results.bottom - 5, eps), reason: why);
  // What is drawn on a card is worked out from its size, and no text is under 11 dp.
  expect(l.tileLetterFont, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: why);
  expect(l.tileBubbleFont, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: why);
  expect(l.tileBubbleHeight, inInclusiveRange(18, 30), reason: why);
  expect(l.tileBorder, greaterThanOrEqualTo(1.5), reason: why);
  expect(l.tileIconSize, greaterThanOrEqualTo(12), reason: why);

  // The chips: one row under the results; the design's size between 34 and 52 dp.
  expect(l.chipRail.top - results.bottom, closeTo(l.designPanelGap, eps), reason: why);
  expect(l.chipRail.left, closeTo(inner.left, eps), reason: why);
  expect(l.chipRail.width, closeTo(inner.width, eps), reason: why);
  expect(l.designChipSize, inInclusiveRange(34, 52), reason: why);
  expect(l.designChipSize, lessThanOrEqualTo(math.max(34, l.canvasSize.width * 0.056) + eps), reason: 'no wider than 5.6% of the width, or the 34 dp floor: $why');
  for (var i = 0; i < LuckyCardLayout.chipCount; i++) {
    final chip = l.chip(i);
    expect(containsRect(l.chipRail, chip), isTrue, reason: 'chip $i inside the row: $why');
    expect(chip.height, closeTo(kLuckyCardMinTapDp, eps), reason: why);
    expect(chip.top, closeTo(l.chip(0).top, eps), reason: 'one row: $why');
    expect(chip.width, closeTo(l.chip(0).width, eps), reason: why);
    expect(chip.width, greaterThanOrEqualTo(l.designChipSize - eps), reason: 'a chip is drawn inside its own tap area: $why');
    if (i > 0) expect(chip.left, closeTo(l.chip(i - 1).right, eps), reason: 'tap areas touch but never overlap: $why');
  }

  // The buttons: along the bottom of the panel, equal, 7 dp apart, filling the width.
  for (var i = 0; i < LuckyCardLayout.actionButtonCount; i++) {
    final b = l.actionButton(i);
    expect(b.bottom, closeTo(inner.bottom, eps), reason: why);
    expect(b.height, greaterThanOrEqualTo(kLuckyCardMinTapDp - eps), reason: 'button $i: $why');
    expect(b.width, closeTo(l.actionButton(0).width, eps), reason: why);
    if (i > 0) expect(b.left - l.actionButton(i - 1).right, closeTo(LuckyCardLayout.designCellGap, eps), reason: why);
  }
  expect(l.actionButton(0).left, closeTo(inner.left, eps), reason: why);
  expect(l.actionButton(2).right, closeTo(inner.right, eps), reason: why);

  // On the devices that are supported the four rows fit one above the other inside the panel.
  if (tapTargets) {
    for (final r in [l.totalBetCell, l.winCell, results, l.chipRail, for (var i = 0; i < 3; i++) l.actionButton(i)]) {
      expect(containsRect(inner, r), isTrue, reason: 'inside the panel: $why');
    }
    expect(l.chipRail.bottom, lessThanOrEqualTo(l.actionButton(0).top + eps), reason: 'chips above the buttons: $why');
  }

  if (tapTargets) {
    for (var c = 0; c < 4; c++) {
      expect(l.suitHeader(c).width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'suit header width: $why');
      // The one written exception to the 48 dp rule (the user's decision, 2026-10-23): the design's suit
      // bars are 25 to 35 dp tall on a phone and are kept as drawn. They are at least 48 dp across.
      expect(l.suitHeader(c).height, greaterThan(0), reason: 'suit header height: $why');
      for (var r = 0; r < 3; r++) {
        expect(l.cardCell(c, r).width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'card width: $why');
        expect(l.cardCell(c, r).height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'card height: $why');
      }
    }
    for (var r = 0; r < 3; r++) {
      expect(l.rankSelector(r).width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
      expect(l.rankSelector(r).height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
    }
    expect(l.cardSize.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'card picture width: $why');
    expect(l.cardSize.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'card picture height: $why');
    // Already asserted above as designBallHit >= 48 dp; each header button is square, so the
    // one figure covers both width and height.
    // The chips are 48 dp tall and a fifth of the row wide. The row is 222.7 dp on the smallest
    // phone (and 42.8 dp at the very least, with the largest padding), so a chip is about 43 dp wide there:
    // the written exception of 2026-10-23. From a panel of
    // 270 dp up (every phone but the smallest few) a chip is a full 48 dp.
    for (var i = 0; i < LuckyCardLayout.chipCount; i++) {
      expect(l.chip(i).width, greaterThanOrEqualTo(42.8), reason: 'chip $i: $why');
      if (l.side.width >= 270) expect(l.chip(i).width, greaterThanOrEqualTo(kLuckyCardMinTapDp - eps), reason: 'chip $i: $why');
      expect(l.chip(i).height, greaterThanOrEqualTo(kLuckyCardMinTapDp - eps), reason: 'chip $i: $why');
    }
    for (var i = 0; i < LuckyCardLayout.actionButtonCount; i++) {
      expect(l.actionButton(i).width, greaterThanOrEqualTo(kLuckyCardMinTapDp - eps), reason: 'button $i: $why');
      expect(l.actionButton(i).height, greaterThanOrEqualTo(kLuckyCardMinTapDp - eps), reason: 'button $i: $why');
    }
  }
}

void main() {
  group('every phone of the matrix (the tablets are in lucky_card_layout_tablet_test.dart)', () {
    for (final d in kPhoneMatrix) {
      test('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): sound, with every tap target at least 48 dp', () {
        expectSound(d.size);
      });
    }
  });

  group('the share of the screen used (spec §17M, Option B)', () {
    test('phones and 16:10 tablets are filled completely', () {
      for (final d in kDeviceMatrix.where((d) => d.ratio >= 1.6)) {
        expect(LuckyCardLayout.of(d.size).usedShare, closeTo(1.0, 1e-9), reason: '$d');
      }
    });

    test('a screen squarer than 1.6 : 1 that is still a phone uses 83% (a 1.6 : 1 canvas, centred)', () {
      final l = LuckyCardLayout.of(const Size(640, 480));
      expect(l.isTablet, isFalse);
      expect(l.usedShare, closeTo(640 / 480 / 1.6, 1e-9));
      expect(l.usedShare, greaterThan(0.82));
      expect(l.canvasRect.width, closeTo(640, eps), reason: 'full width');
      expect(l.canvasRect.top, greaterThan(0), reason: 'bars above and below');
    });

    test('a tablet always uses the whole screen, whatever its shape', () {
      for (final d in kTabletMatrix) {
        final l = LuckyCardLayout.of(d.size);
        expect(l.isTablet, isTrue, reason: '$d');
        expect(l.usedShare, closeTo(1.0, 1e-9), reason: '$d');
        expect(l.canvasRect, Offset.zero & d.size, reason: '$d');
      }
    });

    test('a very wide screen gets a 2.4 : 1 canvas, centred', () {
      final l = LuckyCardLayout.of(const Size(1200, 400));
      expect(l.canvasRect.width / l.canvasRect.height, closeTo(2.4, 1e-9));
      expect(l.canvasRect.height, 400);
      expect(l.canvasRect.left, closeTo((1200 - 960) / 2, eps));
    });
  });

  group('the board follows the reference design', () {
    test('the bet panel is 38% of the width, held between 244 and 360 dp (a phone; a tablet\'s is 29%, 300 to 400)', () {
      // 640 x 360: 243.2 is held up to 244; 844 x 390: 320.72; 932 x 430: 354.16; 1200 x 412 (a wide phone, a 988.8 dp canvas): 375.7 is held down to 360.
      expect(LuckyCardLayout.of(const Size(640, 360)).side.width, closeTo(244, eps));
      expect(LuckyCardLayout.of(const Size(844, 390)).side.width, closeTo(320.72, eps));
      expect(LuckyCardLayout.of(const Size(932, 430)).side.width, closeTo(354.16, eps));
      expect(LuckyCardLayout.of(const Size(1200, 412)).side.width, closeTo(360, eps));
    });

    test('on an 844 x 390 phone the board is the largest 1.48 : 1 box the body leaves, limited by its height', () {
      // Worked by hand from the design's rules: header 50.7 dp (13% of 390), body from 56.7 to 381.56
      // (padding 8.44), panel 320.72, gap 10, so the section is 496.4 x 324.86; 1.48 x 324.86 = 480.79
      // is narrower than 496.4, so the height limits the board, and 0.675 x 496.4 = 335.1 is taller than
      // 324.86, so the full height is used.
      final board = LuckyCardLayout.of(const Size(844, 390)).designBoard;
      expect(board.width, closeTo(480.79, 0.05));
      expect(board.height, closeTo(324.86, 0.05));
    });

    test('on a 640 x 360 phone the board is limited by its width, and its cells are the sizes worked out by hand', () {
      // Header 48 dp (the 48 dp floor), body 54 to 353.6 (padding 6.4), panel 244 (held up from 243.2), gap
      // 7.68: the section is 375.52 x 299.6. 1.48 x 299.6 = 443 is wider, so the width limits the board, and
      // 0.675 x 375.52 = 253.48 is its height. The gap is 3.7552; one width part is 0.155859 dp and one
      // height part 0.156362 dp, so a card is 458 x 464 parts = 71.38 x 72.55 dp, a bar 71.38 x 24.55 dp
      // (157 height parts) and a badge 481 width parts = 74.97 dp wide.
      final l = LuckyCardLayout.of(const Size(640, 360));
      expect(l.designBoard.width, closeTo(375.52, 0.05));
      expect(l.designBoard.height, closeTo(253.48, 0.05));
      expect(l.cardSize.width, closeTo(71.38, 0.05));
      expect(l.cardSize.height, closeTo(72.55, 0.05));
      expect(l.suitHeader(0).width, closeTo(71.38, 0.05));
      expect(l.suitHeader(0).height, closeTo(24.55, 0.05));
      expect(l.rankSelector(0).width, closeTo(74.97, 0.05));
    });

    test('the structure is the same at every ratio: the zones keep their order left to right', () {
      for (var r = 1.6; r <= 2.4; r += 0.1) {
        final l = LuckyCardLayout.of(Size(r * 1000, 1000));
        expect(l.grid.right, lessThan(l.rankColumn.left), reason: 'ratio $r');
        expect(l.rankColumn.right, lessThan(l.side.left), reason: 'ratio $r');
        // The board sits inside the body, not necessarily at its bottom (it is centred up and down).
        expect(l.grid.bottom, lessThanOrEqualTo(l.side.bottom + eps), reason: 'ratio $r');
        expect(l.grid.top, greaterThanOrEqualTo(l.side.top - eps), reason: 'ratio $r');
      }
    });

    test('a bigger screen gives a bigger board, bigger cards and bigger text, never smaller', () {
      LuckyCardLayout? previous;
      for (final height in [360.0, 390.0, 430.0, 600.0, 768.0, 1024.0]) {
        final l = LuckyCardLayout.of(Size(height * 1.9, height));
        if (previous != null) {
          expect(l.designBoard.width, greaterThanOrEqualTo(previous.designBoard.width), reason: 'board at $height');
          expect(l.cardSize.width, greaterThanOrEqualTo(previous.cardSize.width), reason: 'card at $height');
          expect(l.designCardFont, greaterThanOrEqualTo(previous.designCardFont), reason: 'text at $height');
        }
        previous = l;
      }
    });
  });

  group('across every shape between the devices', () {
    test('a sweep of ratios and heights keeps every rule (tap targets for screens at least 640 x 360)', () {
      var checked = 0;
      for (final height in [360.0, 390.0, 412.0, 540.0, 768.0, 800.0, 1024.0, 1440.0]) {
        for (var ratio = 1.2; ratio <= 2.8; ratio += 0.04) {
          final size = Size(height * ratio, height);
          if (LuckyCardLayout.isTabletScreen(size)) continue; // a tablet has its own rules (lucky_card_layout_tablet_test.dart)
          expectSound(size, tapTargets: size.width >= 640 && size.height >= 360);
          checked++;
        }
      }
      expect(checked, greaterThan(150));
    });

    test('the canvas and its units scale with the height (the design clamps its own body and panel)', () {
      final a = LuckyCardLayout.of(const Size(1000, 500));
      final b = LuckyCardLayout.of(const Size(2000, 1000));
      expect(b.scale, closeTo(a.scale * 2, 1e-9));
      // The design clamps its padding (6 to 10 dp) and its panel (244 to 360 dp), so the body does not
      // double: what still scales with the height is the canvas, and the sizes the design takes from it.
      expect(b.canvasSize.height, closeTo(a.canvasSize.height * 2, 1e-6));
      expect(b.dp(100), closeTo(a.dp(100) * 2, 1e-6));
    });

    test('a zero, tiny or huge screen does not throw and gives finite numbers', () {
      for (final s in [Size.zero, const Size(1, 1), const Size(0, 500), const Size(100000, 100000), const Size(5, 5000)]) {
        final l = LuckyCardLayout.of(s);
        for (final r in [...l.zones.values, l.canvasRect]) {
          expect(r.left.isFinite && r.top.isFinite && r.width.isFinite && r.height.isFinite, isTrue, reason: '$s');
        }
        expect(l.scale > 0, isTrue, reason: '$s');
      }
    });
  });

  group('text and picture sizes', () {
    test('a text size never goes below 11 dp, and grows with the canvas', () {
      final small = LuckyCardLayout.of(const Size(640, 360));
      expect(small.fontSize(20), kLuckyCardMinReadableDp, reason: '20 units is 7 dp on the smallest phone');
      expect(small.fontSize(20, minDp: 9), 9, reason: 'a different minimum');
      expect(small.fontSize(20, minDp: 5), closeTo(7.2, 1e-9), reason: 'the canvas size wins when it is larger');
      final large = LuckyCardLayout.of(const Size(1366, 1024));
      expect(large.fontSize(60), closeTo(large.dp(60), 1e-9));
      expect(large.fontSize(60), greaterThan(small.fontSize(60)));
    });

    test('a picture is decoded no wider than it is drawn', () {
      expect(LuckyCardLayout.cacheWidth(70.2, 3), 211);
      expect(LuckyCardLayout.cacheWidth(70, 1), 70);
      expect(LuckyCardLayout.cacheWidth(0, 2), 1);
      final small = LuckyCardLayout.of(const Size(640, 360));
      expect(LuckyCardLayout.cacheWidth(small.cardSize.width, 3), lessThan(300), reason: 'against a 549 px file');
    });

    test('the wheel is about 239 dp across on the smallest phone and 435 dp on a 1024 x 768 tablet', () {
      // Both grew with the grid reclaiming the removed status strip's 90 units (confirmed by
      // hand: at 640x360, grid.height/1.06 = 280.53, under grid.width = 316, so still
      // height-limited; at 1024x768 the grid is now tall enough that grid.width = 448 is the
      // smaller of the two, so the wheel is width-limited there for the first time).
      expect(LuckyCardLayout.of(const Size(640, 360)).wheelDiameter, closeTo(239.13, 1));
      // The tablet arrangement (the whole screen, a board of 1.48 : 1 beside a 300 dp panel): 435 dp.
      expect(LuckyCardLayout.of(const Size(1024, 768)).wheelDiameter, closeTo(434.95, 1));
      expect(LuckyCardLayout.phone(const Size(1024, 768)).wheelDiameter, closeTo(403.7, 1), reason: 'the phone arrangement, which no tablet gets any more');
    });

    test('the bet panel of the smallest phone, worked out by hand from the design', () {
      // 640 x 360: the panel is 244 dp, from 389.6 to 633.6 across and 54 to 353.6 down. Its padding is 2.4%
      // of 360 = 8.64 and its border 2, so the rows span 222.72 dp, from x 400.24 and y 64.64 to 342.96;
      // the gap between rows is 2.2% of 360 = 7.92.
      final l = LuckyCardLayout.of(const Size(640, 360));
      expect(l.side.left, closeTo(389.6, 0.01));
      expect(l.panelInner.width, closeTo(222.72, 0.01));
      expect(l.panelInner.top, closeTo(64.64, 0.01));
      expect(l.panelInner.bottom, closeTo(342.96, 0.01));
      // The two totals: (222.72 - 7) / 2 = 107.86 wide, 10 + 11 x 1.2 + 21.6 x 1.1 = 46.96 tall.
      expect(l.totalBetCell.width, closeTo(107.86, 0.01));
      expect(l.totalBetCell.height, closeTo(46.96, 0.01));
      // The results: 119.52 down. The buttons start 342.96 - 48 = 294.96 down and the chip row (4 + 48 = 52 tall)
      // sits above them with a gap each side, so the box gets 294.96 - 7.92 - 52 - 7.92 - 119.52 = 107.6 tall.
      // Four cards across, (222.72 - 10 - 9) / 4 = 50.93 wide; three rows, (107.6 - 10 - 6) / 3 = 30.53 tall
      // (the picture's own shape would allow 57.9, so the room is the limit).
      expect(l.resultsPanel.top, closeTo(119.52, 0.01));
      expect(l.resultsPanel.height, closeTo(107.6, 0.01));
      expect(l.resultTile(0).width, closeTo(50.93, 0.01));
      expect(l.resultTile(0).height, closeTo(30.53, 0.01));
      // Drawn on a card: a border of 1.5 dp (the floor), the letter 11 dp (the floor), the suit picture
      // 52% of the height (15.88), the bubble 18 dp tall with 11 dp text (the floors).
      expect(l.tileBorder, 1.5);
      expect(l.tileLetterFont, 11);
      expect(l.tileIconSize, closeTo(15.88, 0.01));
      expect(l.tileBubbleHeight, 18);
      expect(l.tileBubbleFont, 11);
      // The chips: the row is 119.52 + 107.6 + 7.92 = 235.04 down, a chip is drawn 35.84 across (5.6% of the 640 width)
      // and its tap area is (222.72 - 6) / 5 = 43.34 wide by 48 tall, the written exception.
      expect(l.chipRail.top, closeTo(235.04, 0.01));
      expect(l.designChipSize, closeTo(35.84, 0.01));
      expect(l.chip(0).width, closeTo(43.34, 0.01));
      expect(l.chip(0).height, closeTo(48, eps));
      // The buttons: (222.72 - 14) / 3 = 69.57 wide, 48 tall, on the bottom edge, one panel gap (7.92) under the chips.
      expect(l.actionButton(0).width, closeTo(69.57, 0.01));
      expect(l.actionButton(0).height, closeTo(48, eps));
      expect(l.actionButton(0).top - l.chipRail.bottom, closeTo(7.92, 0.01));
      expect(l.designBallHit, closeTo(kLuckyCardMinTapDp, eps), reason: 'the 48 dp floor, not the design\'s own smaller value');
      expect(l.resultTile(0).height, greaterThanOrEqualTo(30), reason: 'room for the letter, the suit and an 18 dp bubble');
      expect(l.resultTile(0).width, greaterThanOrEqualTo(50));
    });

    test('the results box takes what the panel has left above the chips; where there is more than a card needs, the card keeps its picture\'s shape', () {
      for (final d in kPhoneMatrix) {
        final l = LuckyCardLayout.of(d.size);
        final capped = l.designTileWidth * LuckyCardLayout.historyCardAspect;
        if (l.designTileHeight < capped - 0.01) {
          expect(l.chipRail.bottom + l.designPanelGap, closeTo(l.actionButton(0).top, 0.01), reason: 'filled: $d');
        } else {
          expect(l.designTileHeight, closeTo(capped, 0.01), reason: 'capped by the picture: $d');
          expect(l.chipRail.bottom + l.designPanelGap, lessThanOrEqualTo(l.actionButton(0).top + 0.01), reason: 'room to spare: $d');
        }
      }
      // A phone is limited by room (wide cards); a big screen by the picture (portrait cards).
      expect(LuckyCardLayout.of(const Size(640, 360)).designTileHeight, lessThan(LuckyCardLayout.of(const Size(640, 360)).designTileWidth));
      expect(LuckyCardLayout.of(const Size(1366, 1024)).designTileHeight, greaterThan(LuckyCardLayout.of(const Size(1366, 1024)).designTileWidth));
    });

    test('the pieces of the smallest phone are the sizes worked out from the design', () {
      final l = LuckyCardLayout.of(const Size(640, 360));
      // Worked by hand in 'on a 640 x 360 phone the board is limited by its width' above.
      expect(l.cardSize.width, closeTo(71.38, 0.05));
      expect(l.cardSize.height, closeTo(72.55, 0.05));
      expect(l.gridCell(0, 1).height, closeTo(72.55, 0.05));
      // The cards, the badges and the bars are at least 48 dp across; only the suit bars are under
      // 48 dp tall (24.55 dp), which is the written exception the user chose on 2026-10-23.
      expect(l.cardSize.width, greaterThanOrEqualTo(48));
      expect(l.suitHeader(0).width, greaterThanOrEqualTo(48));
      expect(l.suitHeader(0).height, lessThan(48));
    });
  });
}
