// Tests for the tablet arrangement of lib/widgets/lucky_card/lucky_card_layout.dart
// (LuckyCardLayout.tablet, spec §17BN, step T1): the geometry alone, at the six sizes of the
// reference design's tablet files and across a sweep of shapes between them.

import 'dart:math' as math;

import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

const double eps = 0.001;

/// The six tablet files of reference-design/royal-cards-standalone/, in dp.
const List<Device> kTabletReferenceSizes = [
  Device('android 7-8 tablet', 1024, 600),
  Device('ipad mini', 1133, 744),
  Device('ipad air', 1180, 820),
  Device('ipad pro 11', 1194, 834),
  Device('galaxy tab s', 1280, 800),
  Device('ipad pro 12.9', 1366, 1024),
];

bool overlaps(Rect a, Rect b) {
  final i = a.intersect(b);
  return i.width > eps && i.height > eps;
}

bool containsRect(Rect outer, Rect inner) =>
    inner.left >= outer.left - eps &&
    inner.top >= outer.top - eps &&
    inner.right <= outer.right + eps &&
    inner.bottom <= outer.bottom + eps;

/// CSS clamp(min, value, max).
double clamp(double v, double lo, double hi) => math.max(lo, math.min(v, hi));

/// Every rule that must hold at any tablet size.
void expectTabletSound(Size screen) {
  final l = LuckyCardLayout.tablet(screen);
  final why = '$screen';
  final w = screen.width;
  final h = screen.height;
  final canvas = Offset.zero & l.canvasSize;

  // The canvas is the whole screen.
  expect(l.isTablet, isTrue, reason: why);
  expect(l.canvasRect, Offset.zero & screen, reason: why);
  expect(l.usedShare, closeTo(1.0, 1e-9), reason: why);
  expect(l.scale, closeTo(h / 1000, 1e-9), reason: why);

  // Five zones, inside the canvas, never overlapping.
  final zones = l.zones;
  expect(zones.keys.toSet(), {'topBar', 'grid', 'rankColumn', 'side', 'chipBar'}, reason: why);
  for (final e in zones.entries) {
    expect(containsRect(canvas, e.value), isTrue, reason: '${e.key} outside the canvas: $why');
    expect(e.value.width > 0 && e.value.height > 0, isTrue, reason: '${e.key} is empty: $why');
  }
  final names = zones.keys.toList();
  for (var i = 0; i < names.length; i++) {
    for (var j = i + 1; j < names.length; j++) {
      expect(overlaps(zones[names[i]]!, zones[names[j]]!), isFalse, reason: '${names[i]} overlaps ${names[j]}: $why');
    }
  }

  // The header: the flat bar, flush with the top and both sides, 8.5% of the height (56 to 84 dp).
  final bar = l.designHeaderBar;
  expect(bar, Rect.fromLTWH(0, 0, w, clamp(h * 0.085, 56, 84)), reason: why);
  expect(l.topBar, bar, reason: why);
  expect(l.designBallHit, greaterThanOrEqualTo(kLuckyCardMinTapDp - eps), reason: 'a round button answers at least 48 dp: $why');
  expect(l.designBallSize, lessThanOrEqualTo(l.designBallHit + eps), reason: why);
  expect(l.designBallHit, lessThanOrEqualTo(bar.height + eps), reason: 'the tap area fits the bar: $why');
  expect(l.designPillHeight, lessThanOrEqualTo(bar.height), reason: why);
  expect(l.designCoinSize, lessThan(l.designPillHeight), reason: why);
  expect(l.designCountdownSize, lessThanOrEqualTo(bar.height + eps), reason: 'the countdown fits the bar: $why');
  for (final f in [l.designBalanceFont, l.designCountdownFont, l.designStatusFont]) {
    expect(f, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: why);
  }
  expect(l.designCountdownFont, lessThan(l.designCountdownSize * 0.82), reason: 'the digits fit inside the disc: $why');

  // The body: 1.4% of the width of padding (10 to 20 dp), the gap under the header 1.4% of the
  // height (8 to 14 dp); the panel 29% of the width (300 to 400 dp), the full height of the body.
  final body = l.designBody;
  final pad = clamp(w * 0.014, 10, 20);
  expect(body.left, closeTo(pad, eps), reason: why);
  expect(w - body.right, closeTo(pad, eps), reason: why);
  expect(h - body.bottom, closeTo(pad, eps), reason: why);
  expect(body.top - bar.bottom, closeTo(clamp(h * 0.014, 8, 14), eps), reason: why);
  expect(l.bodyGapY, closeTo(body.top - bar.bottom, eps), reason: why);
  expect(l.side.width, closeTo(clamp(w * 0.29, 300, 400), eps), reason: why);
  expect(l.side.right, closeTo(body.right, eps), reason: why);
  expect(l.side.top, closeTo(body.top, eps), reason: why);
  expect(l.side.bottom, closeTo(body.bottom, eps), reason: why);

  // The left column: the board in a section, then a gap, then the chip bar at the bottom.
  final columnRight = l.side.left - l.designBodyGapX;
  expect(l.designBodyGapX, closeTo(clamp(w * 0.012, 10, 18), eps), reason: why);
  final chipBar = l.chipBar;
  expect(chipBar.left, closeTo(body.left, eps), reason: why);
  expect(chipBar.right, closeTo(columnRight, eps), reason: why);
  expect(chipBar.bottom, closeTo(body.bottom, eps), reason: why);
  expect(chipBar.height, closeTo(clamp(h * 0.13, 80, 124), eps), reason: why);
  final section = l.designSection;
  expect(section.left, closeTo(body.left, eps), reason: why);
  expect(section.top, closeTo(body.top, eps), reason: why);
  expect(section.right, closeTo(columnRight, eps), reason: why);
  expect(chipBar.top - section.bottom, closeTo(l.bodyGapY, eps), reason: 'the gap between the board and the chip bar: $why');

  // The board: the largest 1.48 : 1 box that fits the section, centred in it.
  final board = l.designBoard;
  expect(containsRect(section, board), isTrue, reason: why);
  expect(board.center.dx, closeTo(section.center.dx, eps), reason: why);
  expect(board.center.dy, closeTo(section.center.dy, eps), reason: why);
  expect(board.width >= section.width - eps || board.height >= section.height - eps, isTrue, reason: 'as large as the section allows: $why');
  // Its shape is the design's 1.48 : 1 (its height is 0.675 of its width, so 1.4815 : 1 when the section is the limit).
  expect(board.width / board.height, lessThanOrEqualTo(1 / 0.675 + 1e-9), reason: why);
  expect(containsRect(board, l.grid), isTrue, reason: why);
  expect(containsRect(board, l.rankColumn), isTrue, reason: why);
  expect(l.designBoardGap, closeTo(board.width * 0.009, eps), reason: why);
  expect(l.designCardFont, closeTo(board.width * 0.032, eps), reason: why);
  expect(l.designBarFont, closeTo(board.width * 0.019, eps), reason: why);
  expect(l.designBadgeFont, closeTo(board.width * 0.021, eps), reason: why);
  for (var c = 0; c < 4; c++) {
    expect(l.suitHeader(c).width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
    for (var r = 0; r < 3; r++) {
      expect(l.cardCell(c, r).width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
      expect(l.cardCell(c, r).height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
    }
  }
  for (var r = 0; r < 3; r++) {
    expect(l.rankSelector(r).width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
    expect(l.rankSelector(r).height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
  }

  // The wheel and the reveal still work from the grid and the rank column.
  expect(containsRect(l.grid, l.wheelBox), isTrue, reason: why);
  expect(containsRect(l.rankColumn, l.revealCard), isTrue, reason: why);
  expect(containsRect(canvas, l.winPopup), isTrue, reason: why);

  // The chips: five slots that touch, centred in the chip bar, none under 48 dp either way, the
  // chip itself 50 to 80 dp across (smaller only if the bar is too narrow) and inside its slot.
  final rail = l.chipRail;
  expect(containsRect(chipBar, rail), isTrue, reason: 'the chips inside their bar: $why');
  expect(rail.center.dx, closeTo(chipBar.center.dx, eps), reason: 'centred across: $why');
  expect(rail.center.dy, closeTo(chipBar.center.dy, eps), reason: 'centred up and down: $why');
  expect(l.designChipSize, inInclusiveRange(1, 80), reason: why);
  for (var i = 0; i < LuckyCardLayout.chipCount; i++) {
    final chip = l.chip(i);
    expect(containsRect(rail, chip), isTrue, reason: 'chip $i: $why');
    expect(chip.width, closeTo(l.chip(0).width, eps), reason: why);
    expect(chip.height, closeTo(rail.height, eps), reason: why);
    expect(chip.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'chip $i tall enough: $why');
    expect(chip.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'chip $i wide enough: $why');
    expect(chip.width, greaterThanOrEqualTo(l.designChipSize + 4 - eps), reason: 'the chip is drawn inside its slot: $why');
    expect(chip.height, greaterThanOrEqualTo(l.designChipSize - eps), reason: why);
    if (i > 0) expect(chip.left, closeTo(l.chip(i - 1).right, eps), reason: 'slots touch and never overlap: $why');
  }
  expect(l.chip(0).left, closeTo(rail.left, eps), reason: why);
  expect(l.chip(4).right, closeTo(rail.right, eps), reason: why);

  // The panel: a border and padding round three rows, from the top PLAY | WIN, the results and
  // (at the bottom) the three stacked buttons. No chips in it.
  final inner = l.panelInner;
  final edge = LuckyCardLayout.designPanelBorder + l.designPanelPad;
  expect(l.designPanelPad, closeTo(clamp(h * 0.016, 12, 18), eps), reason: why);
  expect(l.designPanelGap, closeTo(clamp(h * 0.016, 10, 16), eps), reason: why);
  expect(inner, l.side.deflate(edge), reason: why);

  expect(l.totalBetCell.top, closeTo(inner.top, eps), reason: why);
  expect(l.winCell.top, closeTo(l.totalBetCell.top, eps), reason: why);
  expect(l.winCell.width, closeTo(l.totalBetCell.width, eps), reason: why);
  expect(l.cellGap, 10, reason: why);
  expect(l.winCell.left - l.totalBetCell.right, closeTo(10, eps), reason: why);
  expect(l.totalBetCell.left, closeTo(inner.left, eps), reason: why);
  expect(l.winCell.right, closeTo(inner.right, eps), reason: why);
  expect(l.designTotalLabelFont, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: why);

  final results = l.resultsPanel;
  expect(results.left, closeTo(inner.left, eps), reason: why);
  expect(results.width, closeTo(inner.width, eps), reason: why);
  expect(results.top - l.totalBetCell.bottom, closeTo(l.designPanelGap, eps), reason: why);
  expect(results.height, closeTo(2 * l.resultsPad + 3 * l.designTileHeight + 2 * l.tileGap, eps), reason: why);
  expect(l.resultsPad, closeTo(clamp(h * 0.014, 10, 14), eps), reason: why);
  expect(l.tileGap, closeTo(clamp(h * 0.01, 6, 10), eps), reason: why);
  expect(LuckyCardLayout.designResultTiles, 12);
  expect(l.designTileWidth, closeTo((inner.width - 2 * l.resultsPad - 3 * l.tileGap) / 4, eps), reason: why);
  // On a tablet the panel has room, so a card has the picture's own portrait shape (or, on a short
  // screen, what room there is).
  expect(l.designTileHeight, lessThanOrEqualTo(l.designTileWidth * LuckyCardLayout.historyCardAspect + eps), reason: why);
  expect(l.designTileHeight, greaterThan(l.designTileWidth * 0.8), reason: 'nearly square or portrait, never a wide strip (a very wide, short tablet is the limit): $why');
  for (var i = 0; i < LuckyCardLayout.designResultTiles; i++) {
    final tile = l.resultTile(i);
    expect(containsRect(results, tile), isTrue, reason: 'result card $i: $why');
    expect(tile.width, closeTo(l.resultTile(0).width, eps), reason: why);
    for (var j = i + 1; j < LuckyCardLayout.designResultTiles; j++) {
      expect(overlaps(tile, l.resultTile(j)), isFalse, reason: 'cards $i and $j overlap: $why');
    }
    if (i % 4 > 0) expect(tile.left - l.resultTile(i - 1).right, closeTo(l.tileGap, eps), reason: why);
    if (i >= 4) expect(tile.top - l.resultTile(i - 4).bottom, closeTo(l.tileGap, eps), reason: why);
  }
  expect(l.resultTile(0).left, closeTo(results.left + l.resultsPad, eps), reason: why);
  expect(l.resultTile(3).right, closeTo(results.right - l.resultsPad, eps), reason: why);
  expect(l.resultTile(11).bottom, closeTo(results.bottom - l.resultsPad, eps), reason: why);
  for (final f in [l.tileLetterFont, l.tileBubbleFont]) {
    expect(f, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: why);
  }
  expect(l.tileBubbleHeight, inInclusiveRange(18, 30), reason: why);
  expect(l.tileBorder, greaterThanOrEqualTo(1.5), reason: why);

  // Stacked buttons: the panel's full width, top to bottom in order, a gap apart, the last at the
  // bottom of the panel, each at least 48 dp tall.
  expect(l.designButtonHeight, closeTo(math.max(clamp(h * 0.074, 46, 70), 48), eps), reason: why);
  expect(l.buttonGapY, closeTo(clamp(h * 0.013, 8, 14), eps), reason: why);
  for (var i = 0; i < LuckyCardLayout.actionButtonCount; i++) {
    final b = l.actionButton(i);
    expect(b.left, closeTo(inner.left, eps), reason: why);
    expect(b.width, closeTo(inner.width, eps), reason: why);
    expect(b.height, greaterThanOrEqualTo(kLuckyCardMinTapDp - eps), reason: 'button $i: $why');
    expect(b.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
    if (i > 0) expect(b.top - l.actionButton(i - 1).bottom, closeTo(l.buttonGapY, eps), reason: why);
  }
  expect(l.actionButton(2).bottom, closeTo(inner.bottom, eps), reason: why);
  expect(l.designButtonFont, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: why);

  // The three rows fit one above the other, in order, inside the panel.
  final rows = [l.totalBetCell, l.winCell, results, l.actionButton(0), l.actionButton(1), l.actionButton(2)];
  for (final r in rows) {
    expect(containsRect(inner, r), isTrue, reason: 'inside the panel: $why');
  }
  expect(results.bottom, lessThanOrEqualTo(l.actionButton(0).top + eps), reason: 'the results above the buttons: $why');
}

void main() {
  group('the six reference tablet sizes', () {
    for (final d in kTabletReferenceSizes) {
      test('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): sound, with every tap target at least 48 dp', () {
        expectTabletSound(d.size);
      });
    }

    test('every file of the reference is a tablet by the 600 dp rule', () {
      for (final d in kTabletReferenceSizes) {
        expect(math.min(d.width, d.height), greaterThanOrEqualTo(LuckyCardLayout.tabletShortSide), reason: '$d');
      }
    });
  });

  group('the tablets of the device matrix', () {
    for (final d in kTabletMatrix) {
      test('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): sound, with every tap target at least 48 dp', () {
        expectTabletSound(d.size);
      });
    }
  });

  group('the sizes worked out by hand from the reference', () {
    test('1366 x 1024 (the iPad Pro 12.9 file): every figure the file prints', () {
      final l = LuckyCardLayout.tablet(const Size(1366, 1024));
      // Header 87.04 held to 84; body padding 19.124; the gap under the header 14.336 held to 14.
      expect(l.designHeaderHeight, 84);
      expect(l.designBodyPad, closeTo(19.124, eps));
      expect(l.bodyGapY, 14);
      expect(l.designBody.top, closeTo(98, eps));
      // The panel 396.14 wide; the gap to the board 16.392.
      expect(l.side.width, closeTo(396.14, eps));
      expect(l.designBodyGapX, closeTo(16.392, eps));
      // The chip bar 133.12 held to 124; the board section above it; the board limited by width.
      expect(l.chipBar.height, 124);
      expect(l.chipBar.width, closeTo(915.22, 0.01));
      expect(l.designBoard.width, closeTo(915.22, 0.01));
      expect(l.designBoard.height, closeTo(617.77, 0.01));
      // Chips 83.97 held to 80, gap 40.98, slot 120.98.
      expect(l.designChipSize, 80);
      expect(l.chipGap, closeTo(40.98, eps));
      expect(l.chip(0).width, closeTo(120.98, eps));
      // Panel: padding 16.384, inner 359.372 wide; PLAY/WIN 81.4 tall; tiles 60 tall; buttons 70.
      expect(l.designPanelPad, closeTo(16.384, eps));
      expect(l.panelInner.width, closeTo(359.372, eps));
      expect(l.designTotalHeight, closeTo(81.4, eps));
      // Cards: (359.372 - 28 - 30) / 4 = 75.34 wide, the picture's shape 686 / 604 of that = 85.57 tall.
      expect(l.designTileWidth, closeTo(75.343, 0.001));
      expect(l.designTileHeight, closeTo(85.57, 0.01));
      expect(l.resultsPanel.height, closeTo(28 + 3 * 85.57 + 20, 0.05));
      expect(l.tileBorder, closeTo(2.225, 0.01));
      expect(l.tileLetterFont, closeTo(30.8, 0.1));
      expect(l.tileBubbleHeight, closeTo(30, eps));
      expect(l.designButtonHeight, 70);
      expect(l.buttonGapY, closeTo(13.312, eps));
      // Header pieces: ball 68, pill 56, coin 44, ring 72, digits 28, balance 32, words 30.
      expect(l.designBallSize, 68);
      expect(l.designPillHeight, 56);
      expect(l.designCoinSize, 44);
      expect(l.designCountdownSize, closeTo(72 * LuckyCardLayout.countdownDiscShare, eps));
      expect(l.designCountdownFont, closeTo(28, eps));
      expect(l.designBalanceFont, 32);
      expect(l.designStatusFont, 30);
      expect(l.designHeaderGap, closeTo(13.66, eps));
    });

    test('1024 x 600 (the smallest tablet file): the floors of the design and of the 48 dp rule hold', () {
      final l = LuckyCardLayout.tablet(const Size(1024, 600));
      expect(l.designHeaderHeight, 56);
      expect(l.designBodyPad, closeTo(14.336, eps));
      expect(l.bodyGapY, closeTo(8.4, eps));
      expect(l.side.width, 300);
      expect(l.chipBar.height, 80);
      expect(l.chipBar.width, closeTo(683.04, 0.01));
      // The board is limited by its height here: 432.864 tall, 640.64 wide.
      expect(l.designBoard.height, closeTo(432.864, 0.01));
      expect(l.designBoard.width, closeTo(640.64, 0.01));
      expect(l.designChipSize, 50);
      expect(l.chip(0).width, closeTo(80.72, eps));
      // The buttons are held at 48 dp (the design says 46), PLAY / WIN's label at 11 dp (design 10).
      expect(l.designButtonHeight, 48);
      expect(l.designTotalLabelFont, 11);
      expect(l.designTotalHeight, closeTo(55.6, eps));
      expect(l.designTileWidth, closeTo(58.5, 0.001));
      expect(l.designTileHeight, closeTo(66.45, 0.01));
      expect(l.designBallSize, 46);
      expect(l.designBallHit, 48);
      expect(l.panelInner.width, closeTo(272, eps));
      expect(l.actionButton(2).bottom, closeTo(l.panelInner.bottom, eps));
    });
  });

  group('which screens get the tablet arrangement (LuckyCardLayout.of)', () {
    test('a screen at least 600 dp on its short side and 800 dp on its long side is a tablet, any other a phone', () {
      for (final d in kTabletReferenceSizes) {
        expect(LuckyCardLayout.isTabletScreen(d.size), isTrue, reason: '$d');
        expect(LuckyCardLayout.of(d.size).isTablet, isTrue, reason: '$d');
      }
      for (final d in kTabletMatrix) {
        expect(LuckyCardLayout.of(d.size).isTablet, isTrue, reason: '$d');
      }
      for (final d in kPhoneMatrix) {
        expect(LuckyCardLayout.isTabletScreen(d.size), isFalse, reason: '$d');
        expect(LuckyCardLayout.of(d.size).isTablet, isFalse, reason: '$d');
      }
      // The edges of the rule.
      expect(LuckyCardLayout.isTabletScreen(const Size(800, 600)), isTrue);
      expect(LuckyCardLayout.isTabletScreen(const Size(799, 600)), isFalse, reason: 'too short a long side');
      expect(LuckyCardLayout.isTabletScreen(const Size(1024, 599)), isFalse, reason: 'too short a short side');
      expect(LuckyCardLayout.isTabletScreen(const Size(640, 640)), isFalse, reason: 'an odd square screen stays a phone');
      expect(LuckyCardLayout.isTabletScreen(const Size(2400, 1000)), isTrue, reason: 'a very wide big screen');
      expect(LuckyCardLayout.isTabletScreen(const Size(960, 412)), isFalse, reason: 'the widest phone of the matrix');
      // The orientation does not matter.
      expect(LuckyCardLayout.isTabletScreen(const Size(768, 1024)), LuckyCardLayout.isTabletScreen(const Size(1024, 768)));
    });

    test('LuckyCardLayout.phone is the phone arrangement at any size, tablets included', () {
      for (final d in kDeviceMatrix) {
        final l = LuckyCardLayout.phone(d.size);
        expect(l.isTablet, isFalse, reason: '$d');
        expect(l.chipBar, Rect.zero, reason: '$d');
        expect(l.zones.keys.toSet(), {'topBar', 'grid', 'rankColumn', 'side'}, reason: '$d');
        expect(l.cellGap, LuckyCardLayout.designCellGap, reason: '$d');
        expect(l.resultsPad, LuckyCardLayout.designResultsPad, reason: '$d');
        expect(l.tileGap, LuckyCardLayout.designTileGap, reason: '$d');
        expect(l.bodyGapY, LuckyCardLayout.designBodyGapY, reason: '$d');
      }
    });

    test('a phone gets the same numbers from of() and phone()', () {
      for (final d in kPhoneMatrix) {
        final a = LuckyCardLayout.of(d.size);
        final b = LuckyCardLayout.phone(d.size);
        expect(a.canvasRect, b.canvasRect, reason: '$d');
        expect(a.side, b.side, reason: '$d');
        expect(a.designBoard, b.designBoard, reason: '$d');
        expect(a.resultsPanel, b.resultsPanel, reason: '$d');
        expect(a.chipRail, b.chipRail, reason: '$d');
      }
    });
  });

  group('across every shape between the tablets', () {
    test('a sweep of widths and heights (shorter side at least 600 dp) keeps every rule', () {
      var count = 0;
      for (var w = 800.0; w <= 1700; w += 50) {
        for (var h = 600.0; h <= 1200; h += 50) {
          final size = Size(w, h);
          if (!LuckyCardLayout.isTabletScreen(size) || w / h > 2.4) continue; // only what the app gives the tablet arrangement
          expectTabletSound(size);
          count++;
        }
      }
      expect(count, greaterThan(150));
    });

    test('a bigger tablet gives a bigger board and never a smaller one (at one ratio)', () {
      var last = 0.0;
      for (final s in [Size(1024, 600), Size(1280, 750), Size(1536, 900), Size(1792, 1050)]) {
        final board = LuckyCardLayout.tablet(s).designBoard.width;
        expect(board, greaterThan(last), reason: '$s');
        last = board;
      }
    });

    test('a narrow bar shrinks the chips instead of letting them overflow; nothing throws or goes non-finite', () {
      for (final s in [const Size(700, 600), const Size(640, 640), const Size(1, 1), const Size(0, 0), const Size(5000, 3000)]) {
        final l = LuckyCardLayout.tablet(s);
        for (final r in [...l.zones.values, l.chipRail, l.chip(0), l.chip(4), l.actionButton(0), l.resultTile(11), l.winCell]) {
          expect(r.left.isFinite && r.top.isFinite && r.width.isFinite && r.height.isFinite, isTrue, reason: '$s');
        }
      }
      // 600 x 600: the bar is only 280 dp wide, too narrow for five full-size chips and their gaps.
      for (final s in [const Size(700, 600), const Size(600, 600)]) {
        final narrow = LuckyCardLayout.tablet(s);
        expect(narrow.chip(4).right, lessThanOrEqualTo(narrow.chipBar.right + eps), reason: '$s');
        expect(narrow.chip(0).left, greaterThanOrEqualTo(narrow.chipBar.left - eps), reason: '$s');
        expect(narrow.designChipSize, lessThanOrEqualTo(narrow.chip(0).width - 4 + eps), reason: 'the chip stays inside its slot: $s');
      }
      expect(LuckyCardLayout.tablet(const Size(600, 600)).designChipSize, lessThan(50), reason: 'drawn smaller when the bar is narrow');
    });
  });

  group('the tablet layout map (pictures to look at)', () {
    // The zones drawn as flat colours, the 16 board cells, the chips, the PLAY / WIN cells, the ten
    // result cards and the three buttons, so the arrangement can be compared with the reference.
    for (final d in const [Device('android tablet', 1024, 600), Device('ipad air', 1180, 820), Device('ipad pro 12.9', 1366, 1024)]) {
      testWidgets('${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) async {
        final layout = LuckyCardLayout.tablet(d.size);
        await pumpAtSize(tester, d.size, CustomPaint(painter: _MapPainter(layout), size: d.size));
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(CustomPaint).first, matchesGoldenFile('goldens/tablet_map_${d.width.toInt()}x${d.height.toInt()}.png'));
      });
    }
  });
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.l);

  final LuckyCardLayout l;

  @override
  void paint(Canvas canvas, Size size) {
    void fill(Rect r, Color c) => canvas.drawRect(r, Paint()..color = c);
    fill(Offset.zero & size, const Color(0xFF2A070C));
    fill(l.topBar, const Color(0xFF8E1B2A));
    fill(l.side, const Color(0xFF3B1466));
    fill(l.chipBar, const Color(0xFF3B1466));
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 4; r++) {
        fill(l.gridCell(c, r).deflate(1), r == 0 ? const Color(0xFFB71C1C) : const Color(0xFFFFD54F));
      }
    }
    for (var r = 0; r < 3; r++) {
      fill(l.rankSelector(r).deflate(1), const Color(0xFF7E57C2));
    }
    fill(l.totalBetCell, const Color(0xFF2459E0));
    fill(l.winCell, const Color(0xFF1FA34A));
    fill(l.resultsPanel, const Color(0xFF1A0630));
    for (var i = 0; i < 12; i++) {
      fill(l.resultTile(i), i == 0 ? const Color(0xFF4FDC7A) : const Color(0xFFFFFFFF));
    }
    const buttons = [Color(0xFFFFB300), Color(0xFFFF2E7E), Color(0xFF1AA3FF)];
    for (var i = 0; i < 3; i++) {
      fill(l.actionButton(i), buttons[i]);
    }
    final ring = Paint()
      ..color = const Color(0xFFFFD34D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 5; i++) {
      final slot = l.chip(i);
      canvas.drawRect(slot, Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke);
      canvas.drawCircle(slot.center, l.designChipSize / 2, Paint()..color = [const Color(0xFFE0282E), const Color(0xFF2A63E0), const Color(0xFF1FA34A), const Color(0xFFF07A12), const Color(0xFF7A35E0)][i]);
      if (i == 0) canvas.drawCircle(slot.center, l.designChipSize / 2 + 4, ring);
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => false;
}
