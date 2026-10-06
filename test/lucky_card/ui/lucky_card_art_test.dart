// Tests for lib/widgets/lucky_card/lucky_card_art.dart: every picture key points at
// a file that exists, with the name the spec lists; pictures are decoded at their
// drawn size; the test version reads the same files as the real one.

import 'dart:io';

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

void main() {
  group('the keys', () {
    test('there are 31 pictures, all different', () {
      final all = LuckyCardArtKey.all;
      expect(all.length, 31, reason: '12 cards, 4 bars, 4 symbols, 3 selectors, 5 chips, 2 win-popup pictures, the background');
      expect(all.toSet().length, 31);
      expect(all, contains(LuckyCardArtKey.background));
    });

    test('every key points at a file that exists on disk', () {
      for (final key in LuckyCardArtKey.all) {
        expect(File(key.assetPath).existsSync(), isTrue, reason: '${key.assetPath} is missing');
      }
    });

    test('the background is the supplied stage, in the Lucky Card folder', () {
      expect(LuckyCardArtKey.background.assetPath, 'assets/lucky_card/images/bg-lobby-lucky-card.webp');
    });

    test('the names follow the files the spec lists', () {
      expect(LuckyCardArtKey.card(LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts)).assetPath,
          'assets/lucky_card/images/hearts-j-card.webp');
      expect(LuckyCardArtKey.card(LuckyCard(LuckyCardRank.king, LuckyCardSuit.clubs)).assetPath,
          'assets/lucky_card/images/clubs-k-card.webp');
      expect(LuckyCardArtKey.suitBar(LuckyCardSuit.diamonds).assetPath, 'assets/lucky_card/images/diamonds-bar.webp');
      expect(LuckyCardArtKey.suitIcon(LuckyCardSuit.spades).assetPath, 'assets/lucky_card/images/spades-icon.webp');
      expect(LuckyCardArtKey.rankSelector(LuckyCardRank.queen).assetPath, 'assets/lucky_card/images/q-selector.webp');
      expect(LuckyCardArtKey.chip(LuckyCardChip.fiveHundred).assetPath, 'assets/lucky_card/images/chip_500.webp',
          reason: "Lucky Card's own chip");
      for (final chip in [LuckyCardChip.five, LuckyCardChip.ten, LuckyCardChip.fifty, LuckyCardChip.hundred]) {
        expect(LuckyCardArtKey.chip(chip).assetPath, 'assets/images/chip_${chip.amount}.webp',
            reason: "Triple Chance's chip, used read-only");
      }
    });

    test('equal keys are equal', () {
      expect(LuckyCardArtKey.chip(LuckyCardChip.ten), LuckyCardArtKey.chip(LuckyCardChip.ten));
      expect(LuckyCardArtKey.chip(LuckyCardChip.ten), isNot(LuckyCardArtKey.chip(LuckyCardChip.five)));
    });
  });

  group('the sources', () {
    test('the real one gives an asset picture decoded no wider than asked', () {
      final image = const AssetLuckyCardArt().image(LuckyCardArtKey.suitBar(LuckyCardSuit.hearts), cacheWidth: 150);
      expect(image, isA<ResizeImage>());
      final resize = image as ResizeImage;
      expect(resize.width, 150);
      expect(resize.height, isNull);
      expect(resize.imageProvider, isA<AssetImage>());
      expect((resize.imageProvider as AssetImage).assetName, 'assets/lucky_card/images/hearts-bar.webp');
    });

    test('the test one gives the same file, from disk, at the same width', () {
      final key = LuckyCardArtKey.suitBar(LuckyCardSuit.hearts);
      final image = const FileLuckyCardArt().image(key, cacheWidth: 150) as ResizeImage;
      expect(image.width, 150);
      expect((image.imageProvider as FileImage).file.path, key.assetPath);
    });
  });

  group('memory', () {
    // Decoded sizes of the supplied files, in pixels (spec §17).
    const dims = {
      'card': (565, 571),
      'bar': (1231, 507),
      'icon': (634, 663),
      'selector': (951, 496),
    };

    test('drawn at their sizes, the board pictures take a small share of what full-size decoding would', () {
      var full = 0;
      for (final e in dims.entries) {
        final n = switch (e.key) { 'card' => 12, 'bar' => 4, 'icon' => 4, _ => 3 };
        full += n * e.value.$1 * e.value.$2 * 4;
      }
      expect(full / 1e6, closeTo(38.0, 1.0), reason: 'the full-size figure quoted in the spec');

      for (final d in kDeviceMatrix) {
        final l = LuckyCardLayout.of(d.size);
        // Phones are about 3x density, tablets about 2x.
        final dpr = d.width >= 1000 ? 2.0 : 3.0;
        // Cards drawn at the card side, bars at the cell width, selectors at the
        // rank column width, symbols at a quarter of the card side.
        int bytes(double widthDp, (int, int) dim) {
          final w = LuckyCardLayout.cacheWidth(widthDp, dpr);
          return w * (w * dim.$2 / dim.$1).ceil() * 4;
        }

        final used = 12 * bytes(l.cardSide, dims['card']!) +
            4 * bytes(l.suitHeader(0).width, dims['bar']!) +
            3 * bytes(l.rankColumn.width, dims['selector']!) +
            4 * bytes(l.cardSide / 4, dims['icon']!);
        expect(used / full, lessThan(0.25), reason: '$d at ${dpr}x takes ${(used / 1e6).toStringAsFixed(1)} MB');
        expect(used / 1e6, lessThan(10), reason: '$d');
      }
    });
  });
}
