// Tests for lib/widgets/lucky_card/lucky_card_canvas.dart: the frame is placed
// where the layout says, at every device of the matrix, with no overflow, with the
// phone's font size ignored, and with the background over the whole screen.

import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

const _zoneKeys = {
  'topBar': Key('zone-topBar'),
  'grid': Key('zone-grid'),
  'rankColumn': Key('zone-rankColumn'),
  'status': Key('zone-status'),
  'side': Key('zone-side'),
};

/// A zone filled with a labelled box that must fit inside it.
LuckyCardZoneBuilder probe(String name, Color color) => (context, layout) => ColoredBox(
      key: _zoneKeys[name],
      color: color,
      child: Center(
        child: Text('probe $name', style: TextStyle(fontSize: layout.fontSize(40), color: Colors.white)),
      ),
    );

Widget fullCanvas({Widget? background}) => LuckyCardCanvas(
      background: background,
      topBar: probe('topBar', Colors.brown),
      grid: probe('grid', Colors.green),
      rankColumn: probe('rankColumn', Colors.indigo),
      status: probe('status', Colors.orange),
      side: probe('side', Colors.purple),
    );

void main() {
  group('every device of the matrix', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): every zone is where the layout puts it, with no overflow', (tester) async {
        await pumpAtSize(tester, d.size, fullCanvas());
        expect(tester.takeException(), isNull);

        final layout = LuckyCardLayout.of(d.size);
        for (final e in layout.zones.entries) {
          final box = tester.getRect(find.byKey(_zoneKeys[e.key]!));
          final want = e.value.shift(layout.canvasRect.topLeft);
          expect(box.left, closeTo(want.left, 0.01), reason: '${e.key} left');
          expect(box.top, closeTo(want.top, 0.01), reason: '${e.key} top');
          expect(box.width, closeTo(want.width, 0.01), reason: '${e.key} width');
          expect(box.height, closeTo(want.height, 0.01), reason: '${e.key} height');
        }
      });
    }

    for (final d in kDeviceMatrix) {
      testWidgets('${d.name}: an empty canvas builds without error', (tester) async {
        await pumpAtSize(tester, d.size, const LuckyCardCanvas());
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the background', () {
    testWidgets('covers the whole screen, even where the canvas does not (a 4:3 tablet)', (tester) async {
      const key = Key('background');
      await pumpAtSize(tester, const Size(1024, 768), fullCanvas(background: const ColoredBox(key: key, color: Colors.black)));
      final bg = tester.getRect(find.byKey(key));
      expect(bg, const Rect.fromLTWH(0, 0, 1024, 768));
      final canvas = LuckyCardLayout.of(const Size(1024, 768)).canvasRect;
      expect(canvas.height, lessThan(768), reason: 'the canvas is smaller than the screen here');
    });

    testWidgets('a plain dark one stands in when none is given', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), const LuckyCardCanvas());
      expect(find.byType(DecoratedBox), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group("the phone's font-size setting", () {
    testWidgets('has no effect: text inside is the same size at 0.5, 1 and 3 times', (tester) async {
      Future<Size> textSize(double scale) async {
        await pumpAtSize(tester, const Size(844, 390), fullCanvas(), textScale: scale);
        expect(tester.takeException(), isNull, reason: 'scale $scale');
        return tester.getSize(find.text('probe grid'));
      }

      final a = await textSize(0.5);
      final b = await textSize(1);
      final c = await textSize(3);
      expect(a, b);
      expect(b, c);
    });

    testWidgets('is neutralised for everything under the canvas, and left alone outside it', (tester) async {
      TextScaler? inside;
      await pumpAtSize(
        tester,
        const Size(844, 390),
        LuckyCardCanvas(grid: (context, layout) {
          inside = MediaQuery.textScalerOf(context);
          return const SizedBox.expand();
        }),
        textScale: 2.5,
      );
      expect(inside, TextScaler.noScaling);
      expect(MediaQuery.textScalerOf(tester.element(find.byType(Scaffold))).scale(10), 25, reason: 'outside the canvas the setting is untouched');
    });
  });

  group('the layout scope', () {
    testWidgets('hands every widget under the canvas the layout, and follows a resize', (tester) async {
      LuckyCardLayout? seen;
      Widget canvas() => LuckyCardCanvas(
            side: (context, layout) => Builder(builder: (context) {
              seen = LuckyCardLayoutScope.of(context);
              return const SizedBox.expand();
            }),
          );

      await pumpAtSize(tester, const Size(844, 390), canvas());
      expect(seen!.screen, const Size(844, 390));
      expect(seen!.scale, closeTo(0.39, 1e-9));

      await pumpAtSize(tester, const Size(1366, 1024), canvas());
      expect(seen!.screen, const Size(1366, 1024));
      expect(seen!.usedShare, lessThan(1));
    });
  });

  group('the layout map (a picture to look at)', () {
    Widget map() => LuckyCardCanvas(
          topBar: (context, l) => const ColoredBox(color: Color(0xFF5D4037)),
          grid: (context, l) => Stack(children: [
            for (var c = 0; c < 4; c++)
              for (var r = 0; r < 4; r++)
                Positioned.fromRect(
                  rect: l.gridCell(c, r).shift(-l.grid.topLeft).deflate(2),
                  child: ColoredBox(color: r == 0 ? const Color(0xFFB71C1C) : const Color(0xFF2E7D32)),
                ),
            for (var c = 0; c < 4; c++)
              for (var r = 0; r < 3; r++)
                Positioned.fromRect(
                  rect: l.cardImage(c, r).shift(-l.grid.topLeft),
                  child: const ColoredBox(color: Color(0xFFFFD54F)),
                ),
          ]),
          rankColumn: (context, l) => Stack(children: [
            for (var r = 0; r < 3; r++)
              Positioned.fromRect(
                rect: l.rankSelector(r).shift(-l.rankColumn.topLeft).deflate(2),
                child: const ColoredBox(color: Color(0xFF3949AB)),
              ),
          ]),
          status: (context, l) => const ColoredBox(color: Color(0xFFEF6C00)),
          side: (context, l) => const ColoredBox(color: Color(0xFF6A1B9A)),
        );

    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets('${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) async {
        await pumpAtSize(tester, d.size, map());
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/layout_map_${d.width.toInt()}x${d.height.toInt()}.png'));
      });
    }
  });
}
