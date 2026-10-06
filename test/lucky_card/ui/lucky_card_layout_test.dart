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

  // Margins: at least 20 units from every canvas edge, below the top bar.
  final m = l.dp(20) - eps;
  for (final name in ['grid', 'rankColumn', 'status', 'side']) {
    final z = zones[name]!;
    expect(z.left, greaterThanOrEqualTo(m), reason: '$name left margin: $why');
    expect(l.canvasSize.width - z.right, greaterThanOrEqualTo(m), reason: '$name right margin: $why');
    expect(l.canvasSize.height - z.bottom, greaterThanOrEqualTo(m), reason: '$name bottom margin: $why');
    expect(z.top - l.topBar.bottom, greaterThanOrEqualTo(m), reason: '$name under the top bar: $why');
  }

  // The 16 grid cells tile the grid exactly.
  var area = 0.0;
  for (var c = 0; c < LuckyCardLayout.gridColumns; c++) {
    for (var r = 0; r < LuckyCardLayout.gridRows; r++) {
      final cell = l.gridCell(c, r);
      expect(containsRect(l.grid, cell), isTrue, reason: 'cell $c,$r outside the grid: $why');
      area += cell.width * cell.height;
      for (var c2 = 0; c2 < LuckyCardLayout.gridColumns; c2++) {
        for (var r2 = 0; r2 < LuckyCardLayout.gridRows; r2++) {
          if (c2 * 10 + r2 > c * 10 + r) {
            expect(overlaps(cell, l.gridCell(c2, r2)), isFalse, reason: 'cells overlap: $why');
          }
        }
      }
    }
  }
  expect(area, closeTo(l.grid.width * l.grid.height, 0.01), reason: 'the cells fill the grid: $why');

  // The rank selectors are level with their rows of cards; card pictures are
  // squares centred in their cells.
  for (var r = 0; r < 3; r++) {
    final sel = l.rankSelector(r);
    expect(containsRect(l.rankColumn, sel), isTrue, reason: why);
    for (var c = 0; c < 4; c++) {
      final cell = l.cardCell(c, r);
      expect(sel.top, closeTo(cell.top, eps), reason: 'selector level with its row: $why');
      expect(sel.height, closeTo(cell.height, eps), reason: why);
      final img = l.cardImage(c, r);
      expect(containsRect(cell, img), isTrue, reason: 'card picture inside its cell: $why');
      expect(img.width, closeTo(img.height, eps), reason: why);
      expect(img.center.dx, closeTo(cell.center.dx, eps), reason: why);
    }
  }
  for (var c = 0; c < 4; c++) {
    expect(l.suitHeader(c).top, closeTo(l.grid.top, eps), reason: why);
  }
  expect(containsRect(l.rankColumn, l.rankHeaderSlot), isTrue, reason: why);

  // Each suit header holds its name above its bar picture, both inside the header;
  // each rank row holds its name above its selector picture, both inside the row.
  for (var c = 0; c < 4; c++) {
    final header = l.suitHeader(c);
    final label = l.suitLabel(c);
    final bar = l.suitBar(c);
    expect(containsRect(header, label), isTrue, reason: 'suit name inside its header: $why');
    expect(containsRect(header, bar), isTrue, reason: 'bar inside its header: $why');
    expect(label.bottom, lessThanOrEqualTo(bar.top + eps), reason: 'name above the bar: $why');
    expect(bar.width / bar.height, closeTo(LuckyCardLayout.barAspect, 1e-6), reason: 'bar keeps its shape: $why');
    expect(bar.center.dx, closeTo(header.center.dx, eps), reason: why);
    expect(label.height, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: 'name tall enough for 11 dp text: $why');
  }
  for (var r = 0; r < 3; r++) {
    final row = l.rankSelector(r);
    final label = l.rankLabel(r);
    final picture = l.rankPicture(r);
    expect(containsRect(row, label), isTrue, reason: 'rank name inside its row: $why');
    expect(containsRect(row, picture), isTrue, reason: 'selector inside its row: $why');
    expect(label.bottom, lessThanOrEqualTo(picture.top + eps), reason: 'name above the selector: $why');
    expect(picture.width / picture.height, closeTo(LuckyCardLayout.selectorAspect, 1e-6), reason: why);
    expect(picture.center.dx, closeTo(row.center.dx, eps), reason: why);
  }
  expect(l.labelFontSize, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: why);
  for (final dpr in [1.0, 2.0, 3.0]) {
    expect(l.cardCacheWidth(dpr), LuckyCardLayout.cacheWidth(l.cardSide, dpr), reason: why);
    expect(l.barCacheWidth(dpr), LuckyCardLayout.cacheWidth(l.suitBar(0).width, dpr), reason: why);
    expect(l.selectorCacheWidth(dpr), LuckyCardLayout.cacheWidth(l.rankPicture(0).width, dpr), reason: why);
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

  // The top bar: three buttons with tap areas as tall as the bar, the balance and
  // the countdown between them; nothing overlaps and everything is inside the bar.
  final bar = l.topBar;
  final hits = {'exit': l.exitHit, 'sound': l.soundHit, 'info': l.infoHit};
  final bits = {...hits, 'balance': l.balanceBox, 'countdown': l.countdownBox};
  for (final e in bits.entries) {
    expect(containsRect(bar, e.value), isTrue, reason: '${e.key} inside the top bar: $why');
  }
  final bitNames = bits.keys.toList();
  for (var i = 0; i < bitNames.length; i++) {
    for (var j = i + 1; j < bitNames.length; j++) {
      expect(overlaps(bits[bitNames[i]]!, bits[bitNames[j]]!), isFalse, reason: '${bitNames[i]} overlaps ${bitNames[j]}: $why');
    }
  }
  for (final pair in [(l.exitButton, l.exitHit), (l.soundButton, l.soundHit), (l.infoButton, l.infoHit)]) {
    expect(containsRect(pair.$2, pair.$1), isTrue, reason: 'a button is drawn inside its tap area: $why');
    expect(pair.$1.center.dx, closeTo(pair.$2.center.dx, eps), reason: why);
    expect(pair.$1.center.dy, closeTo(pair.$2.center.dy, eps), reason: why);
  }
  expect(l.countdownBox.center.dx, closeTo(l.canvasSize.width / 2, eps), reason: 'the countdown is in the middle: $why');
  expect(l.exitHit.left, greaterThanOrEqualTo(l.dp(20) - eps), reason: why);
  expect(l.canvasSize.width - l.infoHit.right, greaterThanOrEqualTo(l.dp(20) - eps), reason: why);

  // The side column: every piece inside it, none overlapping another.
  final sideBits = <String, Rect>{
    'chipRail': l.chipRail,
    'play': l.playCell,
    'win': l.winCell,
    'limits': l.limitsPanel,
    'results': l.resultsPanel,
    for (var i = 0; i < LuckyCardLayout.actionButtonCount; i++) 'button$i': l.actionButton(i),
  };
  for (final e in sideBits.entries) {
    expect(containsRect(l.side, e.value), isTrue, reason: '${e.key} inside the side column: $why');
    expect(e.value.width > 0 && e.value.height > 0, isTrue, reason: '${e.key} is empty: $why');
  }
  final sideNames = sideBits.keys.toList();
  for (var i = 0; i < sideNames.length; i++) {
    for (var j = i + 1; j < sideNames.length; j++) {
      expect(overlaps(sideBits[sideNames[i]]!, sideBits[sideNames[j]]!), isFalse, reason: '${sideNames[i]} overlaps ${sideNames[j]}: $why');
    }
  }
  for (var i = 0; i < LuckyCardLayout.chipCount; i++) {
    expect(containsRect(l.chipRail, l.chip(i)), isTrue, reason: 'chip $i inside the rail: $why');
    expect(l.chip(i).width, closeTo(l.chip(i).height, eps), reason: 'a chip is a square: $why');
    if (i > 0) expect(l.chip(i).top, greaterThan(l.chip(i - 1).bottom), reason: 'chips do not touch: $why');
  }
  expect(containsRect(l.resultsPanel, l.resultCurrent), isTrue, reason: why);
  for (var i = 0; i < 9; i++) {
    expect(containsRect(l.resultsPanel, l.resultTile(i)), isTrue, reason: 'result tile $i inside the panel: $why');
    expect(overlaps(l.resultCurrent, l.resultTile(i)), isFalse, reason: 'tile $i under the latest: $why');
    for (var j = i + 1; j < 9; j++) {
      expect(overlaps(l.resultTile(i), l.resultTile(j)), isFalse, reason: 'tiles $i and $j overlap: $why');
    }
  }
  expect(l.playCell.top, closeTo(l.winCell.top, eps), reason: 'PLAY and WIN side by side: $why');
  expect(l.playCell.right, lessThan(l.winCell.left), reason: why);
  expect(l.chipRail.right, lessThan(l.playCell.left), reason: 'the rail is left of the right part: $why');
  expect(l.actionButton(0).top, greaterThan(l.resultsPanel.bottom), reason: 'buttons under the results: $why');

  if (tapTargets) {
    for (var c = 0; c < 4; c++) {
      expect(l.suitHeader(c).width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'suit header width: $why');
      expect(l.suitHeader(c).height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'suit header height: $why');
      for (var r = 0; r < 3; r++) {
        expect(l.cardCell(c, r).width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'card width: $why');
        expect(l.cardCell(c, r).height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'card height: $why');
      }
    }
    for (var r = 0; r < 3; r++) {
      expect(l.rankSelector(r).width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
      expect(l.rankSelector(r).height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: why);
    }
    expect(l.cardSide, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'card picture: $why');
    for (final h in [l.exitHit, l.soundHit, l.infoHit]) {
      expect(h.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'top-bar tap area width: $why');
      expect(h.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'top-bar tap area height: $why');
    }
    for (var i = 0; i < LuckyCardLayout.chipCount; i++) {
      expect(l.chip(i).width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'chip $i: $why');
      expect(l.chip(i).height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'chip $i: $why');
    }
    for (var i = 0; i < LuckyCardLayout.actionButtonCount; i++) {
      expect(l.actionButton(i).width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'button $i: $why');
      expect(l.actionButton(i).height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: 'button $i: $why');
    }
  }
}

void main() {
  group('every device of the matrix', () {
    for (final d in kDeviceMatrix) {
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

    test('a 4:3 tablet uses 83% (a 1.6 : 1 canvas, centred)', () {
      for (final d in kDeviceMatrix.where((d) => d.ratio < 1.6)) {
        final l = LuckyCardLayout.of(d.size);
        expect(l.usedShare, closeTo(d.ratio / 1.6, 1e-9), reason: '$d');
        expect(l.usedShare, greaterThan(0.82), reason: '$d');
        expect(l.canvasRect.width, closeTo(d.width, eps), reason: 'full width: $d');
        expect(l.canvasRect.top, greaterThan(0), reason: 'bars above and below: $d');
      }
    });

    test('a very wide screen gets a 2.4 : 1 canvas, centred', () {
      final l = LuckyCardLayout.of(const Size(1200, 400));
      expect(l.canvasRect.width / l.canvasRect.height, closeTo(2.4, 1e-9));
      expect(l.canvasRect.height, 400);
      expect(l.canvasRect.left, closeTo((1200 - 960) / 2, eps));
    });
  });

  group('the canvas flexes: extra width goes to the cells, then the side column, then the margins', () {
    test('at 1.6 : 1 the side column is at its minimum and the cells give a little', () {
      final l = LuckyCardLayout.of(const Size(1600, 1000));
      expect(l.side.width, closeTo(560, eps));
      expect(l.gridCell(0, 0).width, closeTo(175, eps));
      expect(l.grid.left, closeTo(20, eps));
    });

    test('at about 2.04 : 1 the cells are full width and the side column has grown', () {
      final l = LuckyCardLayout.of(const Size(2040, 1000));
      expect(l.gridCell(0, 0).width, closeTo(230, eps));
      expect(l.side.width, greaterThan(560));
      expect(l.side.width, lessThanOrEqualTo(880 + eps));
    });

    test('at 2.4 : 1 everything is at its maximum and the content is centred, margins taking the rest', () {
      final l = LuckyCardLayout.of(const Size(2400, 1000));
      expect(l.gridCell(0, 0).width, closeTo(230, eps));
      expect(l.side.width, closeTo(880, eps));
      expect(l.grid.left, closeTo(l.canvasSize.width - l.side.right, eps), reason: 'centred');
      expect(l.grid.left, greaterThan(100));
    });

    test('the card picture is as large as the row allows from about 1.65 : 1, and at least 95% of that at 1.6 : 1', () {
      final tall = LuckyCardLayout.of(const Size(2040, 1000)).cardSide;
      final narrow = LuckyCardLayout.of(const Size(1600, 1000)).cardSide;
      expect(tall, closeTo(184, eps));
      expect(narrow / tall, greaterThan(0.95));
    });

    test('the structure is the same at every ratio: the zones keep their order left to right', () {
      for (var r = 1.6; r <= 2.4; r += 0.1) {
        final l = LuckyCardLayout.of(Size(r * 1000, 1000));
        expect(l.grid.right, lessThan(l.rankColumn.left), reason: 'ratio $r');
        expect(l.rankColumn.right, lessThan(l.side.left), reason: 'ratio $r');
        expect(l.status.top, greaterThan(l.grid.bottom), reason: 'ratio $r');
      }
    });
  });

  group('across every shape between the devices', () {
    test('a sweep of ratios and heights keeps every rule (tap targets for screens at least 640 x 360)', () {
      var checked = 0;
      for (final height in [360.0, 390.0, 412.0, 540.0, 768.0, 800.0, 1024.0, 1440.0]) {
        for (var ratio = 1.2; ratio <= 2.8; ratio += 0.04) {
          final size = Size(height * ratio, height);
          expectSound(size, tapTargets: size.width >= 640 && size.height >= 360);
          checked++;
        }
      }
      expect(checked, greaterThan(300));
    });

    test('the sizes scale with the height, nothing is a fixed number of dp', () {
      final a = LuckyCardLayout.of(const Size(1000, 500));
      final b = LuckyCardLayout.of(const Size(2000, 1000));
      expect(b.scale, closeTo(a.scale * 2, 1e-9));
      expect(b.cardSide, closeTo(a.cardSide * 2, 1e-6));
      expect(b.grid.width, closeTo(a.grid.width * 2, 1e-6));
      expect(b.side.height, closeTo(a.side.height * 2, 1e-6));
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
      expect(LuckyCardLayout.cacheWidth(small.cardSide, 3), lessThan(300), reason: 'against a 565 px file');
    });

    test('the wheel is about 250 dp across on the smallest phone and 444 dp on a 4:3 tablet', () {
      expect(LuckyCardLayout.of(const Size(640, 360)).wheelDiameter, closeTo(250, 1));
      expect(LuckyCardLayout.of(const Size(1024, 768)).wheelDiameter, closeTo(444, 1));
    });

    test('the side column of the smallest phone: 48 dp chips and buttons, the five chips fill the column, the results have room', () {
      final l = LuckyCardLayout.of(const Size(640, 360));
      expect(l.chip(0).width, closeTo(48.24, 0.01));
      expect(l.chip(0).top, closeTo(l.side.top, eps));
      expect(l.chip(4).bottom, closeTo(l.side.bottom, eps));
      expect(l.actionButton(0).width, closeTo(48.24, 0.01));
      expect(l.actionButton(2).right, closeTo(l.side.right, eps));
      expect(l.actionButton(0).bottom, closeTo(l.side.bottom, eps));
      expect(l.exitHit.height, closeTo(48.24, 0.01));
      expect(l.resultCurrent.height, greaterThanOrEqualTo(36));
      expect(l.resultTile(0).height, greaterThanOrEqualTo(l.resultTileIcon + l.dp(2) + kLuckyCardMinReadableDp * 1.1 + l.dp(8)),
          reason: 'an icon, a gap and a line of 11 dp text, with the rim');
      expect(l.resultTile(0).width, greaterThanOrEqualTo(46));
    });

    test('the pieces of the smallest phone are the sizes the spec worked out', () {
      final l = LuckyCardLayout.of(const Size(640, 360));
      expect(l.cardSide, closeTo(66.2, 0.1));
      expect(l.gridCell(0, 1).height, closeTo(66.2, 0.1));
      expect(math.min(l.suitHeader(0).width, l.suitHeader(0).height), greaterThanOrEqualTo(48));
    });
  });
}
