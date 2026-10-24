// Tests for the desktop arrangement of lib/widgets/lucky_card/lucky_card_layout.dart
// (LuckyCardLayout.desktop, spec §17BP, step D1): the geometry alone, at the seven sizes of the
// reference design's desktop files and across a sweep of shapes between them. With the user's changes
// of 2026-10-24: ten history cards, the board flush left in its column, PLAY and WIN at the bottom of
// the wheel's column, the wheel's column as wide as the board leaves room for.

import 'dart:math' as math;

import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

const double eps = 0.001;

/// The seven desktop files of reference-design/royal-cards-standalone/, in dp.
const List<Device> kDesktopReferenceSizes = [
  Device('laptop hd', 1280, 720),
  Device('laptop', 1366, 768),
  Device('macbook air 13', 1440, 900),
  Device('windows laptop 125%', 1536, 864),
  Device('macbook pro 16', 1680, 1050),
  Device('full hd monitor', 1920, 1080),
  Device('qhd 2k monitor', 2560, 1440),
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

/// Every rule that must hold at any desktop size.
void expectDesktopSound(Size screen) {
  final l = LuckyCardLayout.desktop(screen);
  final why = '$screen';
  final w = screen.width;
  final h = screen.height;
  final canvas = Offset.zero & l.canvasSize;

  expect(l.isDesktop, isTrue, reason: why);
  expect(l.isTablet, isFalse, reason: why);
  expect(l.canvasRect, Offset.zero & screen, reason: why);
  expect(l.usedShare, closeTo(1.0, 1e-9), reason: why);
  expect(l.scale, closeTo(h / 1000, 1e-9), reason: why);

  // Six zones, inside the canvas, never overlapping.
  final zones = l.zones;
  expect(zones.keys.toSet(), {'topBar', 'grid', 'rankColumn', 'side', 'resultsBar', 'actionBar'}, reason: why);
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

  // The header: the flat bar, 8% of the height (64 to 100 dp), flush with the top and both sides.
  final bar = l.designHeaderBar;
  expect(bar, Rect.fromLTWH(0, 0, w, clamp(h * 0.08, 64, 100)), reason: why);
  expect(l.topBar, bar, reason: why);
  expect(l.designBallHit, greaterThanOrEqualTo(kLuckyCardMinTapDp - eps), reason: why);
  expect(l.designBallSize, closeTo(clamp(h * 0.062, 50, 80), eps), reason: why);
  expect(l.designBallHit, lessThanOrEqualTo(bar.height + eps), reason: 'the tap area fits the bar: $why');
  expect(l.designPillHeight, lessThanOrEqualTo(bar.height), reason: why);
  expect(l.designCoinSize, lessThan(l.designPillHeight), reason: why);
  expect(l.designCountdownSize, lessThanOrEqualTo(bar.height + eps), reason: 'the countdown disc fits the bar: $why');
  expect(l.designCountdownFont, lessThan(l.designCountdownSize * 0.82), reason: 'the digits fit the disc: $why');
  for (final f in [l.designBalanceFont, l.designCountdownFont, l.designStatusFont]) {
    expect(f, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: why);
  }

  // The body: 1.4% of the width of padding (14 to 32 dp); 1.4% of the height under the header (12 to 22).
  final body = l.designBody;
  expect(body.left, closeTo(clamp(w * 0.014, 14, 32), eps), reason: why);
  expect(w - body.right, closeTo(body.left, eps), reason: why);
  expect(h - body.bottom, closeTo(body.left, eps), reason: why);
  expect(body.top - bar.bottom, closeTo(clamp(h * 0.014, 12, 22), eps), reason: why);

  // The wheel's column at the LEFT, the full height of the body: at least 34% of the width (360 to
  // 780 dp), and as wide as the board (1.48 times the height above the results row) leaves room for; the
  // right column starts a gap (1.3% of the width, 16 to 32 dp) to its right and ends at the body's edge.
  expect(l.side.left, closeTo(body.left, eps), reason: why);
  final boardHeightWanted = body.height - clamp(h * 0.115, 92, 150) - clamp(h * 0.058, 50, 76) - 2 * clamp(h * 0.013, 10, 20);
  expect(l.side.width, closeTo(math.max(clamp(w * 0.34, 360, 780), body.width - clamp(w * 0.013, 16, 32) - boardHeightWanted * 1.48), eps), reason: why);
  expect(l.side.width, greaterThanOrEqualTo(clamp(w * 0.34, 360, 780) - eps), reason: why);
  expect(l.side.top, closeTo(body.top, eps), reason: why);
  expect(l.side.bottom, closeTo(body.bottom, eps), reason: why);
  expect(l.designBodyGapX, closeTo(clamp(w * 0.013, 16, 32), eps), reason: why);
  final column = l.rightColumn;
  expect(column.left, closeTo(l.side.right + l.designBodyGapX, eps), reason: why);
  expect(column.right, closeTo(body.right, eps), reason: why);
  expect(column.top, closeTo(body.top, eps), reason: why);
  expect(column.bottom, closeTo(body.bottom, eps), reason: why);

  // The right column, top to bottom: the board, the results row, the bottom bar, a gap apart.
  final gap = l.columnGap;
  expect(gap, closeTo(clamp(h * 0.013, 10, 20), eps), reason: why);
  expect(l.actionBar.bottom, closeTo(column.bottom, eps), reason: why);
  expect(l.actionBar.height, closeTo(clamp(h * 0.115, 92, 150), eps), reason: why);
  expect(l.actionBar.left, closeTo(column.left, eps), reason: why);
  expect(l.actionBar.right, closeTo(column.right, eps), reason: why);
  expect(l.resultsBar.height, closeTo(clamp(h * 0.058, 50, 76), eps), reason: why);
  expect(l.actionBar.top - l.resultsBar.bottom, closeTo(gap, eps), reason: why);
  expect(l.resultsBar.left, closeTo(column.left, eps), reason: why);
  expect(l.resultsBar.right, closeTo(column.right, eps), reason: why);

  // The board: the largest 1.48 : 1 box that fits above the results row, FLUSH with the column's left
  // edge and centred up and down; where the height is what limits it, it fills the column exactly.
  final board = l.designBoard;
  final section = Rect.fromLTRB(column.left, column.top, column.right, l.resultsBar.top - gap);
  expect(containsRect(section, board), isTrue, reason: why);
  expect(board.left, closeTo(section.left, eps), reason: 'flush left: $why');
  expect(board.center.dy, closeTo(section.center.dy, eps), reason: why);
  if (l.side.width > clamp(w * 0.34, 360, 780) + eps) {
    expect(board.width, closeTo(column.width, 0.01), reason: 'the wheel\'s column took what the board did not need: $why');
  }
  expect(board.width >= section.width - eps || board.height >= section.height - eps, isTrue, reason: 'as large as the section allows: $why');
  expect(containsRect(board, l.grid), isTrue, reason: why);
  expect(containsRect(board, l.rankColumn), isTrue, reason: why);
  expect(l.designBoardGap, closeTo(board.width * 0.009, eps), reason: why);
  expect(l.designCardFont, closeTo(board.width * 0.032, eps), reason: why);
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

  // The wheel: centred across the column, at most its width, as tall as its pointer needs, centred up
  // and down in what is above PLAY and WIN; PLAY and WIN at the BOTTOM of the column, as wide as the
  // wheel, their bottom edge on the line of the bottom bar's bottom edge.
  final wheel = l.wheelBox;
  expect(containsRect(l.side, wheel), isTrue, reason: 'the wheel inside its column: $why');
  expect(wheel.center.dx, closeTo(l.side.center.dx, eps), reason: why);
  expect(wheel.width, closeTo(l.wheelDiameter, eps), reason: why);
  expect(wheel.height, closeTo(l.wheelDiameter * LuckyCardLayout.wheelHeightFactor, eps), reason: why);
  expect(l.wheelDiameter, lessThanOrEqualTo(l.side.width + eps), reason: why);
  expect(l.wheelDiameter, closeTo(math.min(l.side.width, (l.side.height - l.designTotalHeight - l.wheelGap) / LuckyCardLayout.wheelHeightFactor), eps), reason: why);
  expect(l.wheelGap, closeTo(clamp(h * 0.028, 20, 36), eps), reason: why);
  expect(l.totalBetCell.top - wheel.bottom, greaterThanOrEqualTo(l.wheelGap - eps), reason: 'a gap between the wheel and PLAY / WIN: $why');
  expect(l.totalBetCell.bottom, closeTo(l.side.bottom, eps), reason: 'PLAY and WIN at the bottom: $why');
  expect(l.totalBetCell.bottom, closeTo(l.actionBar.bottom, eps), reason: 'on the bottom bar\'s bottom line: $why');
  expect(l.winCell.bottom, closeTo(l.actionBar.bottom, eps), reason: why);
  expect(l.winCell.top, closeTo(l.totalBetCell.top, eps), reason: why);
  expect(l.totalBetCell.left, closeTo(wheel.left, eps), reason: 'as wide as the wheel: $why');
  expect(l.winCell.right, closeTo(wheel.right, eps), reason: why);
  expect(l.winCell.width, closeTo(l.totalBetCell.width, eps), reason: why);
  expect(l.winCell.left - l.totalBetCell.right, closeTo(14, eps), reason: why);
  expect(l.totalBetCell.height, closeTo(l.designTotalHeight, eps), reason: why);
  expect(containsRect(l.side, l.totalBetCell), isTrue, reason: why);
  expect(containsRect(l.side, l.winCell), isTrue, reason: why);
  final above = l.totalBetCell.top - l.wheelGap - l.side.top;
  expect(wheel.top - l.side.top, closeTo((above - wheel.height) / 2, eps), reason: 'centred up and down above PLAY / WIN: $why');
  expect(l.designTotalLabelFont, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: why);
  expect(l.designTotalValueFont, closeTo(clamp(h * 0.038, 28, 52), eps), reason: why);
  expect(containsRect(canvas, l.wheelBox), isTrue, reason: why);
  expect(l.wheelCenter.dx, closeTo(wheel.center.dx, eps), reason: why);

  // The results: the ten newest cards in ONE row filling the results bar.
  final bar2 = l.resultsBar;
  expect(l.resultsPanel, bar2, reason: why);
  expect(l.resultColumns, 10);
  expect(l.resultRows, 1);
  expect(l.resultCount, 10);
  expect(l.resultsPad, closeTo(clamp(h * 0.006, 5, 9), eps), reason: why);
  expect(l.tileGap, closeTo(clamp(h * 0.006, 4, 8), eps), reason: why);
  expect(l.designTileHeight, closeTo(bar2.height - 2 * l.resultsPad, eps), reason: why);
  expect(l.designTileWidth, closeTo((bar2.width - 2 * l.resultsPad - 9 * l.tileGap) / 10, eps), reason: why);
  for (var i = 0; i < l.resultCount; i++) {
    final tile = l.resultTile(i);
    expect(containsRect(bar2, tile), isTrue, reason: 'card $i: $why');
    expect(tile.top, closeTo(bar2.top + l.resultsPad, eps), reason: 'one row: $why');
    expect(tile.width, closeTo(l.designTileWidth, eps), reason: why);
    if (i > 0) expect(tile.left - l.resultTile(i - 1).right, closeTo(l.tileGap, eps), reason: why);
  }
  expect(l.resultTile(0).left, closeTo(bar2.left + l.resultsPad, eps), reason: why);
  expect(l.resultTile(9).right, closeTo(bar2.right - l.resultsPad, eps), reason: why);
  for (final f in [l.tileLetterFont, l.tileBubbleFont]) {
    expect(f, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: why);
  }

  // The bottom bar: the five chips from its padding in, vertically centred; then the three buttons in a
  // row to the other padding, equal, a gap apart, at least 48 dp tall, centred.
  final ab = l.actionBar;
  final pad = l.actionBarPad;
  expect(pad, closeTo(clamp(w * 0.014, 16, 28), eps), reason: why);
  expect(l.designChipSize, inInclusiveRange(1, 100), reason: why);
  expect(l.chipGap, closeTo(clamp(w * 0.01, 12, 22), eps), reason: why);
  for (var i = 0; i < LuckyCardLayout.chipCount; i++) {
    final chip = l.chip(i);
    expect(containsRect(ab, chip), isTrue, reason: 'chip $i inside the bar: $why');
    expect(chip.center.dy, closeTo(ab.center.dy, eps), reason: 'centred up and down: $why');
    expect(chip.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
    expect(chip.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
    expect(chip.width, closeTo(l.chip(0).width, eps), reason: why);
    if (i > 0) expect(chip.left, closeTo(l.chip(i - 1).right, eps), reason: 'slots touch: $why');
  }
  final firstChipEdge = l.chip(0).center.dx - l.designChipSize / 2;
  expect(firstChipEdge, closeTo(ab.left + pad, eps), reason: 'the first chip starts at the bar\'s padding: $why');
  final chipsRight = l.chip(4).center.dx + l.designChipSize / 2;
  expect(chipsRight - firstChipEdge, lessThanOrEqualTo((ab.width - 2 * pad) * 0.55 + eps), reason: 'chips take no more than 55% of the bar: $why');

  expect(l.designButtonHeight, closeTo(math.max(clamp(h * 0.067, 54, 88), 48), eps), reason: why);
  for (var i = 0; i < LuckyCardLayout.actionButtonCount; i++) {
    final b = l.actionButton(i);
    expect(containsRect(ab, b), isTrue, reason: 'button $i inside the bar: $why');
    expect(b.center.dy, closeTo(ab.center.dy, eps), reason: why);
    expect(b.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
    expect(b.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
    expect(b.width, closeTo(l.actionButton(0).width, eps), reason: why);
    if (i > 0) expect(b.left - l.actionButton(i - 1).right, closeTo(l.buttonGapX, eps), reason: why);
  }
  expect(l.actionButton(2).right, closeTo(ab.right - pad, eps), reason: why);
  expect(l.actionButton(0).left, greaterThanOrEqualTo(chipsRight + l.actionBarGap - eps), reason: 'a gap between the chips and the buttons: $why');
  expect(l.actionButton(0).left, greaterThanOrEqualTo(l.chip(4).right - eps), reason: 'no button over a chip\'s tap area: $why');
  expect(l.designButtonFont, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: why);
}

void main() {
  group('the seven reference desktop sizes', () {
    for (final d in kDesktopReferenceSizes) {
      test('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): sound, with every tap target at least 48 dp', () {
        expectDesktopSound(d.size);
      });
    }

    test('every file of the reference is a desktop screen by the 1280 x 720 rule', () {
      for (final d in kDesktopReferenceSizes) {
        expect(LuckyCardLayout.isDesktopScreen(d.size), isTrue, reason: '$d');
      }
    });
  });

  group('the sizes worked out by hand from the reference', () {
    test('1920 x 1080 (the full HD file): every figure the file prints', () {
      final l = LuckyCardLayout.desktop(const Size(1920, 1080));
      expect(l.designBodyPad, closeTo(26.88, eps));
      expect(l.designHeaderHeight, closeTo(86.4, eps));
      expect(l.bodyGapY, closeTo(15.12, eps));
      expect(l.designBallSize, closeTo(66.96, eps));
      expect(l.designPillHeight, closeTo(60.48, eps));
      expect(l.designCoinSize, closeTo(45.36, eps));
      expect(l.designBalanceFont, closeTo(31.32, eps));
      expect(l.designStatusFont, closeTo(33.48, eps));
      expect(l.designHeaderGap, closeTo(19.2, eps));
      // The board (1090.29 wide, limited by its height) leaves the wheel's column 1866.24 - 24.96 - 1090.29
      // = 751.0 dp (the reference's 652.8 is the least); the wheel is as wide as the column, so 15% bigger.
      expect(l.designBodyGapX, closeTo(24.96, eps));
      expect(l.side.width, closeTo(750.99, 0.01));
      expect(l.wheelDiameter, closeTo(750.99, 0.01));
      expect(l.wheelGap, closeTo(30.24, eps));
      // PLAY / WIN: padding 11.88, label 14.04, figure 41.04: 23.76 + 16.848 + 45.144 = 85.752 tall.
      expect(l.designTotalLabelFont, closeTo(14.04, eps));
      expect(l.designTotalValueFont, closeTo(41.04, eps));
      expect(l.designTotalHeight, closeTo(85.752, eps));
      // The right column is exactly the board's width, 1090.29; the bar 124.2 and the results row 62.64 tall, 14.04 apart.
      expect(l.rightColumn.width, closeTo(1090.29, 0.01));
      expect(l.designBoard.left, closeTo(l.rightColumn.left, eps));
      expect(l.actionBar.height, closeTo(124.2, eps));
      expect(l.resultsBar.height, closeTo(62.64, eps));
      expect(l.columnGap, closeTo(14.04, eps));
      // The board is 1090.29 wide (1.48 times the 736.68 the height allows) and 735.94 tall (the design's 0.675 of its width).
      expect(l.designBoard.height, closeTo(735.94, 0.01));
      expect(l.designBoard.width, closeTo(1090.29, 0.01));
      // Chips 82.08 across and 19.2 apart; buttons 163.3 wide, 72.36 tall, 15.36 apart.
      expect(l.designChipSize, closeTo(82.08, eps));
      expect(l.chipGap, closeTo(19.2, eps));
      expect(l.actionBarPad, closeTo(26.88, eps));
      expect(l.actionBarGap, closeTo(28.8, eps));
      expect(l.actionButton(0).width, closeTo(163.3, 0.1));
      expect(l.designButtonHeight, closeTo(72.36, eps));
      expect(l.buttonGapX, closeTo(15.36, eps));
      // The ten cards: padding and gap 6.48; each 101.9 x 49.68.
      expect(l.designTileWidth, closeTo(101.9, 0.01));
      expect(l.designTileHeight, closeTo(49.68, 0.01));
      // PLAY and WIN: 751 wide in all, on the bottom line (1053.12) with the bottom bar.
      expect(l.totalBetCell.bottom, closeTo(1053.12, 0.01));
      expect(l.actionBar.bottom, closeTo(1053.12, 0.01));
    });

    test('1280 x 720 (the smallest desktop file): the floors of the design hold', () {
      final l = LuckyCardLayout.desktop(const Size(1280, 720));
      expect(l.designHeaderHeight, 64);
      expect(l.designBodyPad, closeTo(17.92, eps));
      expect(l.bodyGapY, 12);
      // The board (686.84 wide) leaves 1244.16 - 16.64 - 686.84 = 540.68 for the wheel's column (the
      // reference's 435.2 is the least); the wheel is then limited by its height: 515.0 dp, centred in it.
      expect(l.side.width, closeTo(540.68, 0.01));
      expect(l.wheelDiameter, closeTo(515.0, 0.1), reason: 'limited by the height');
      expect(l.wheelBox.center.dx, closeTo(l.side.center.dx, eps));
      expect(l.rightColumn.width, closeTo(686.84, 0.01));
      expect(l.actionBar.height, 92);
      expect(l.resultsBar.height, 50);
      expect(l.columnGap, 10);
      // The board is 686.84 wide (1.48 times the 464.08 the height allows) and 463.62 tall.
      expect(l.designBoard.height, closeTo(463.62, 0.01));
      expect(l.designBoard.width, closeTo(686.84, 0.01));
      // The chips keep the design's 58 dp and 12.8 dp (they take 52% of the bar, under the 55% limit).
      expect(l.designChipSize, 58);
      expect(l.chip(0).width, closeTo(70.8, 0.05));
      expect(l.designButtonHeight, 54);
      expect(l.designTotalLabelFont, 11);
      expect(l.designTotalValueFont, 28);
    });
  });

  group('the desktop arrangement is chosen by platform and size, and the others are not touched', () {
    test('of() makes the desktop arrangement only for a desktop platform and a screen of at least 1280 x 720', () {
      for (final d in kDesktopReferenceSizes) {
        expect(LuckyCardLayout.of(d.size, desktopPlatform: true).isDesktop, isTrue, reason: '$d');
        expect(LuckyCardLayout.of(d.size).isDesktop, isFalse, reason: 'not told it is a desktop platform: $d');
        expect(LuckyCardLayout.of(d.size).isTablet, isTrue, reason: 'a 1280 x 720 or bigger screen is a tablet to the size rule: $d');
      }
      // A desktop platform with a smaller window falls back to the size rule.
      expect(LuckyCardLayout.of(const Size(1100, 700), desktopPlatform: true).isDesktop, isFalse);
      expect(LuckyCardLayout.of(const Size(1100, 700), desktopPlatform: true).isTablet, isTrue);
      expect(LuckyCardLayout.of(const Size(1279, 800), desktopPlatform: true).isDesktop, isFalse);
      expect(LuckyCardLayout.of(const Size(1280, 719), desktopPlatform: true).isDesktop, isFalse);
      expect(LuckyCardLayout.of(const Size(800, 400), desktopPlatform: true).isTablet, isFalse);
      expect(LuckyCardLayout.of(const Size(800, 400), desktopPlatform: true).isDesktop, isFalse);
      // The phone and tablet matrices are the same as before when no platform is given.
      for (final d in kPhoneMatrix) {
        expect(LuckyCardLayout.of(d.size).isTablet || LuckyCardLayout.of(d.size).isDesktop, isFalse, reason: '$d');
      }
      for (final d in kTabletMatrix) {
        expect(LuckyCardLayout.of(d.size).isTablet, isTrue, reason: '$d');
      }
    });

    test('a tablet or a phone shows twelve history cards and the desktop ten', () {
      expect(LuckyCardLayout.desktop(const Size(1920, 1080)).resultCount, 10);
      expect(LuckyCardLayout.tablet(const Size(1280, 800)).resultCount, 12);
      expect(LuckyCardLayout.phone(const Size(844, 390)).resultCount, 12);
    });

    test('the desktop has none of a tablet\'s zones and a tablet or phone none of the desktop\'s', () {
      final desktop = LuckyCardLayout.desktop(const Size(1920, 1080));
      expect(desktop.chipBar, Rect.zero);
      expect(desktop.zones.containsKey('chipBar'), isFalse);
      for (final l in [LuckyCardLayout.tablet(const Size(1280, 800)), LuckyCardLayout.phone(const Size(844, 390))]) {
        expect(l.isDesktop, isFalse);
        expect(l.actionBar, Rect.zero);
        expect(l.resultsBar, Rect.zero);
        expect(l.rightColumn, Rect.zero);
        expect(l.zones.containsKey('actionBar'), isFalse);
        expect(l.zones.containsKey('resultsBar'), isFalse);
        expect(l.resultColumns, 4);
        expect(l.resultRows, 3);
      }
    });
  });

  group('across every shape between the desktops', () {
    test('a sweep of widths and heights keeps every rule', () {
      var count = 0;
      for (var w = 1280.0; w <= 2600; w += 80) {
        for (var h = 720.0; h <= 1500; h += 60) {
          final ratio = w / h;
          if (ratio < 1.3 || ratio > 2.4) continue;
          expectDesktopSound(Size(w, h));
          count++;
        }
      }
      expect(count, greaterThan(150));
    });

    test('a bigger screen at one ratio gives a bigger board and wheel, never a smaller one', () {
      var board = 0.0;
      var wheel = 0.0;
      for (final s in [Size(1280, 720), Size(1600, 900), Size(1920, 1080), Size(2560, 1440)]) {
        final l = LuckyCardLayout.desktop(s);
        expect(l.designBoard.width, greaterThan(board), reason: '$s');
        expect(l.wheelDiameter, greaterThan(wheel), reason: '$s');
        board = l.designBoard.width;
        wheel = l.wheelDiameter;
      }
    });

    test('a tiny, zero or huge screen does not throw and gives finite numbers', () {
      for (final s in [const Size(1, 1), const Size(0, 0), const Size(5000, 3000), const Size(1280, 100), const Size(300, 720)]) {
        final l = LuckyCardLayout.desktop(s);
        for (final r in [...l.zones.values, l.chipRail, l.chip(0), l.chip(4), l.actionButton(0), l.actionButton(2), l.resultTile(9), l.winCell, l.totalBetCell, l.wheelBox]) {
          expect(r.left.isFinite && r.top.isFinite && r.width.isFinite && r.height.isFinite, isTrue, reason: '$s');
        }
      }
    });
  });

  group('the desktop layout map (pictures to look at)', () {
    for (final d in const [Device('laptop hd', 1280, 720), Device('macbook air', 1440, 900), Device('full hd', 1920, 1080)]) {
      testWidgets('${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) async {
        final layout = LuckyCardLayout.desktop(d.size);
        await pumpAtSize(tester, d.size, CustomPaint(painter: _MapPainter(layout), size: d.size));
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(CustomPaint).first, matchesGoldenFile('goldens/desktop_map_${d.width.toInt()}x${d.height.toInt()}.png'));
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
    fill(l.wheelBox, const Color(0x44FFD34D));
    canvas.drawCircle(l.wheelBox.bottomCenter - Offset(0, l.wheelDiameter / 2), l.wheelDiameter / 2, Paint()..color = const Color(0xFFB8860B));
    fill(l.totalBetCell, const Color(0xFF2459E0));
    fill(l.winCell, const Color(0xFF1FA34A));
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 4; r++) {
        fill(l.gridCell(c, r).deflate(1), r == 0 ? const Color(0xFFB71C1C) : const Color(0xFFFFD54F));
      }
    }
    for (var r = 0; r < 3; r++) {
      fill(l.rankSelector(r).deflate(1), const Color(0xFF7E57C2));
    }
    fill(l.resultsBar, const Color(0xFF1A0630));
    for (var i = 0; i < l.resultCount; i++) {
      fill(l.resultTile(i), i == 0 ? const Color(0xFF4FDC7A) : const Color(0xFFFFFFFF));
    }
    fill(l.actionBar, const Color(0xFF3B1466));
    const chips = [Color(0xFFE0282E), Color(0xFF2A63E0), Color(0xFF1FA34A), Color(0xFFF07A12), Color(0xFF7A35E0)];
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(l.chip(i).center, l.designChipSize / 2, Paint()..color = chips[i]);
      canvas.drawRect(l.chip(i), Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke);
    }
    const buttons = [Color(0xFFFFB300), Color(0xFFFF2E7E), Color(0xFF1AA3FF)];
    for (var i = 0; i < 3; i++) {
      fill(l.actionButton(i), buttons[i]);
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => false;
}
