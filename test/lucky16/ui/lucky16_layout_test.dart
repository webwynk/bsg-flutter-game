// Tests for the Lucky 16 Card phone layout (lib/widgets/lucky16/lucky16_layout.dart): pure
// arithmetic, checked at every phone size.

import 'dart:ui';

import 'package:best_smart_game/widgets/lucky16/lucky16_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

bool inside(Rect outer, Rect inner, {double slack = 0.01}) =>
    inner.left >= outer.left - slack &&
    inner.top >= outer.top - slack &&
    inner.right <= outer.right + slack &&
    inner.bottom <= outer.bottom + slack;

void main() {
  for (final d in kPhoneMatrix) {
    group('$d', () {
      final l = Lucky16Layout.of(d.size);
      final canvas = Offset.zero & l.canvasSize;

      test('the canvas is the screen (every phone is between 1.6 : 1 and 2.4 : 1)', () {
        expect(l.canvasRect, Offset.zero & d.size);
        expect(l.scale, closeTo(d.height / 1000, 1e-9));
      });

      test('every zone is inside the canvas and none overlaps another', () {
        final zones = l.zones.entries.toList();
        for (final z in zones) {
          expect(inside(canvas, z.value), isTrue, reason: '${z.key} ${z.value}');
          expect(z.value.width, greaterThan(0));
          expect(z.value.height, greaterThan(0));
        }
        for (var i = 0; i < zones.length; i++) {
          for (var j = i + 1; j < zones.length; j++) {
            final overlap = zones[i].value.intersect(zones[j].value);
            expect(overlap.width <= 0.01 || overlap.height <= 0.01, isTrue,
                reason: '${zones[i].key} overlaps ${zones[j].key}');
          }
        }
      });

      test('the header is Lucky Card\'s phone header: 13% of the height, 48 to 56 dp, edge to edge', () {
        expect(l.topBar, Rect.fromLTWH(0, 0, d.width, (d.height * 0.13).clamp(48.0, 56.0)));
        expect(l.designBallHit, greaterThanOrEqualTo(kLucky16MinTapDp));
        expect(l.designBallHit, lessThanOrEqualTo(l.designHeaderHeight));
      });

      test('the bet panel is Lucky Card\'s phone panel: 38% of the width (244 to 360 dp), full body height', () {
        expect(l.side.width, closeTo((d.width * 0.38).clamp(244.0, 360.0), 1e-9));
        expect(l.side.right, closeTo(d.width - l.designBodyPad, 1e-9));
        expect(l.side.top, closeTo(l.topBar.bottom + 6, 1e-9));
        expect(l.side.bottom, closeTo(d.height - l.designBodyPad, 1e-9));
      });

      test('the board fits the section left of the panel and touches it on one side at least', () {
        final s = l.designSection;
        final b = l.designBoard;
        expect(inside(s, b), isTrue);
        final fillsWidth = (b.width - s.width).abs() < 0.01;
        final fillsHeight = (b.height - s.height).abs() < 0.01;
        expect(fillsWidth || fillsHeight, isTrue, reason: 'the board is the largest that fits');
        expect(l.grid.left, closeTo(b.left, 1e-6));
        expect(l.rankColumn.right, closeTo(b.right, 1e-6));
        expect(l.grid.bottom, closeTo(b.bottom, 1e-6));
      });

      test('5 rows (suit bars, A, J, Q, K) x 4 suits, each picture in its own shape', () {
        final card = l.cardSize;
        expect(card.width / card.height, closeTo(700 / 476, 1e-6), reason: 'a card is 700 x 476');
        for (var c = 0; c < 4; c++) {
          final bar = l.suitHeader(c);
          expect(bar.width, closeTo(card.width, 1e-6));
          expect(bar.width / bar.height, closeTo(1049 / 270, 1e-6), reason: 'a suit bar is 1049 x 270');
          for (var r = 0; r < 4; r++) {
            final cell = l.cardCell(c, r);
            expect(cell.size.width, closeTo(card.width, 1e-6));
            expect(cell.size.height, closeTo(card.height, 1e-6));
            expect(inside(l.grid, cell), isTrue);
          }
        }
        for (var r = 0; r < 4; r++) {
          final sel = l.rankSelector(r);
          expect(sel.top, closeTo(l.cardCell(0, r).top, 1e-6), reason: 'a selector is level with its row');
          expect(sel.height, closeTo(card.height, 1e-6));
          expect(sel.width / sel.height, closeTo(640 / 687, 1e-6), reason: 'a selector is 640 x 687');
          expect(inside(l.rankColumn, sel), isTrue);
        }
      });

      test('the cells never touch: 1% of the board\'s width apart', () {
        final g = l.designBoardGap;
        expect(g, closeTo(l.designBoard.width * 0.01, 1e-9));
        expect(l.cardCell(1, 0).left - l.cardCell(0, 0).right, closeTo(g, 1e-6));
        expect(l.cardCell(0, 0).top - l.suitHeader(0).bottom, closeTo(g, 1e-6));
        expect(l.cardCell(0, 1).top - l.cardCell(0, 0).bottom, closeTo(g, 1e-6));
        expect(l.rankSelector(0).left - l.cardCell(3, 0).right, closeTo(g, 1e-6));
      });
    });
  }

  test('915 x 412: a card is about 108 x 74 dp, as in the approved mockup (about 110 x 75)', () {
    final card = Lucky16Layout.of(const Size(915, 412)).cardSize;
    expect(card.width, closeTo(108.3, 0.2));
    expect(card.height, closeTo(73.7, 0.2));
  });

  test('the phone arrangement on a squarer screen is a centred 1.6 : 1 canvas', () {
    final l = Lucky16Layout.phone(const Size(1024, 768));
    expect(l.canvasSize.width / l.canvasSize.height, closeTo(1.6, 1e-9));
    expect(l.canvasRect.center, const Offset(512, 384));
  });

  test('a very wide screen gets a centred 2.4 : 1 canvas', () {
    final l = Lucky16Layout.of(const Size(1200, 400));
    expect(l.canvasSize, const Size(960, 400));
    expect(l.canvasRect.left, 120);
  });
}
