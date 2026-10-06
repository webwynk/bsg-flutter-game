// Tests for lib/widgets/lucky_card/lucky_card_background.dart: the supplied stage fills the whole
// screen at every shape, is decoded no wider than the screen needs, takes no taps and is silent
// to a screen reader; and it is preloaded.

import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_background.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

/// Records which pictures were asked for.
class SpyArt extends LuckyCardArt {
  SpyArt(this._inner);

  final LuckyCardArt _inner;
  final List<(LuckyCardArtKey, int)> asked = [];

  @override
  ImageProvider image(LuckyCardArtKey key, {required int cacheWidth}) {
    asked.add((key, cacheWidth));
    return _inner.image(key, cacheWidth: cacheWidth);
  }
}

Image theImage(WidgetTester tester) => tester.widget<Image>(find.byType(Image));

void main() {
  group('on every device of the matrix', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): the picture covers the whole screen', (tester) async {
        await pumpAtSize(tester, d.size, const LuckyCardBackground(art: FileLuckyCardArt()));
        expect(tester.takeException(), isNull);
        final r = tester.getRect(find.byType(Image));
        expect(r, Offset.zero & d.size, reason: 'exactly the screen');
        expect(theImage(tester).fit, BoxFit.cover);
      });
    }
  });

  group('the picture', () {
    testWidgets('is the stage', (tester) async {
      final spy = SpyArt(const FileLuckyCardArt());
      await pumpAtSize(tester, const Size(844, 390), LuckyCardBackground(art: spy));
      expect(spy.asked.map((e) => e.$1).toSet(), {LuckyCardArtKey.background});
    });

    testWidgets('is decoded as wide as the screen at any pixel density, and never more', (tester) async {
      for (final dpr in [1.0, 2.0, 3.0]) {
        final spy = SpyArt(const FileLuckyCardArt());
        await pumpAtSize(tester, const Size(844, 390), LuckyCardBackground(art: spy), devicePixelRatio: dpr);
        expect(spy.asked.last.$2, (844 * dpr).ceil(), reason: 'dpr $dpr');
        final provider = theImage(tester).image as ResizeImage;
        expect(provider.width, (844 * dpr).ceil());
        expect(provider.allowUpscaling, isFalse, reason: 'a small picture is not blown up in memory');
      }
    });

    testWidgets('takes no taps', (tester) async {
      var taps = 0;
      await pumpAtSize(
        tester,
        const Size(844, 390),
        Stack(children: [
          GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++),
          const LuckyCardBackground(art: FileLuckyCardArt()),
        ]),
      );
      await tester.tapAt(const Offset(400, 200));
      expect(taps, 1, reason: 'the tap went through the picture to what is under it');
    });

    testWidgets('is silent to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), const LuckyCardBackground(art: FileLuckyCardArt()));
      expect(find.byType(Semantics).evaluate().where((e) => (e.widget as Semantics).properties.label != null), isEmpty);
      expect(theImage(tester).excludeFromSemantics, isTrue);
      handle.dispose();
    });

    testWidgets('keeps showing the old picture while a new one loads (no flash)', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), const LuckyCardBackground(art: FileLuckyCardArt()));
      expect(theImage(tester).gaplessPlayback, isTrue);
    });
  });

  group('preloading', () {
    testWidgets('asks for the background at the screen\'s width', (tester) async {
      final spy = SpyArt(const FileLuckyCardArt());
      late BuildContext context;
      await pumpAtSize(tester, const Size(844, 390), Builder(builder: (c) {
        context = c;
        return const SizedBox.shrink();
      }), devicePixelRatio: 2);
      final cache = PaintingBinding.instance.imageCache..clear();
      await tester.runAsync(() => precacheLuckyCardBackground(context, spy));
      expect(spy.asked.map((e) => e.$1), [LuckyCardArtKey.background]);
      expect(spy.asked.single.$2, LuckyCardLayout.cacheWidth(844, 2));
      expect(cache.currentSize, 1);
      cache.clear();
    });
  });
}
