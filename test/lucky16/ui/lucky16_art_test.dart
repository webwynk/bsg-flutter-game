// Tests for where the Lucky 16 Card pictures come from (lib/widgets/lucky16/lucky16_art.dart).

import 'dart:io';

import 'package:best_smart_game/models/lucky16_board.dart';
import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_art.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every picture the screen asks for is a file on disk', () {
    for (final key in [...Lucky16ArtKey.all, Lucky16ArtKey.gameCard]) {
      expect(File(key.assetPath).existsSync(), isTrue, reason: key.assetPath);
    }
  });

  test(
      '37 pictures, none twice: 16 cards, 4 bars, 4 selectors, 4 suit icons, 5 chips, 2 frames, 2 win-popup pictures, coin, background',
      () {
    final all = Lucky16ArtKey.all;
    expect(all.length, 16 + 4 + 4 + 4 + 5 + 2 + 2 + 1 + 1);
    expect(all.toSet().length, all.length);
  });

  test('the board pictures are Lucky 16 Card\'s own; the rest are read in place from the other games', () {
    expect(Lucky16ArtKey.card(const Lucky16Card(Lucky16Rank.ace, Lucky16Suit.hearts)).assetPath,
        'assets/lucky16card/images/hearts-a-card.webp');
    expect(Lucky16ArtKey.suitBar(Lucky16Suit.diamonds).assetPath, 'assets/lucky16card/images/diamonds-bar.webp');
    expect(Lucky16ArtKey.rankSelector(Lucky16Rank.ace).assetPath, 'assets/lucky16card/images/a-selector.webp');
    expect(Lucky16ArtKey.suitIcon(Lucky16Suit.clubs).assetPath, 'assets/lucky_card/images/clubs-icon.webp');
    expect(Lucky16ArtKey.chip(Lucky16Chip.fiveHundred).assetPath, 'assets/lucky_card/images/chip_500.webp');
    expect(Lucky16ArtKey.chip(Lucky16Chip.ten).assetPath, 'assets/images/chip_10.webp');
    expect(Lucky16ArtKey.background.assetPath, 'assets/lucky_card/images/bg-lobby-lucky-card.webp');
    expect(Lucky16ArtKey.coin.assetPath, 'assets/images/bsg_coin.webp');
  });
}
