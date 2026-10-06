// Where the Lucky Card pictures come from.
//
// The widgets never name an image file. They ask a [LuckyCardArt] for a picture
// by key and say how wide it will be drawn, and the answer is always decoded at
// that width, never larger (the card, bar and selector files are big: all of
// them at full size would take about 35 MB of memory; at their drawn size, about
// 2 MB).
//
// The real app uses [AssetLuckyCardArt]. The tests use a version that reads the
// same files from disk, because Flutter can only load an asset that
// `pubspec.yaml` lists, and the Lucky Card images are listed there only at App
// Step 9, with its own approval.
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky_card_board.dart';
import '../../models/lucky_card_models.dart';

/// Which picture. Holds only the file's path.
@immutable
class LuckyCardArtKey {
  const LuckyCardArtKey._(this.assetPath);

  static const String _own = 'assets/lucky_card/images';

  /// The picture of one card (565 x 571).
  factory LuckyCardArtKey.card(LuckyCard card) => LuckyCardArtKey._(
        '$_own/${card.suit.dbValue}-${card.rank.dbValue.toLowerCase()}-card.webp',
      );

  /// A suit's bar, with its emblem on the top edge (1231 x 507).
  factory LuckyCardArtKey.suitBar(LuckyCardSuit suit) =>
      LuckyCardArtKey._('$_own/${suit.dbValue}-bar.webp');

  /// A suit's bare symbol, transparent background (634 x 663).
  factory LuckyCardArtKey.suitIcon(LuckyCardSuit suit) =>
      LuckyCardArtKey._('$_own/${suit.dbValue}-icon.webp');

  /// A rank's selector, with its J, Q or K on the green disc (951 x 496).
  factory LuckyCardArtKey.rankSelector(LuckyCardRank rank) =>
      LuckyCardArtKey._('$_own/${rank.dbValue.toLowerCase()}-selector.webp');

  /// A chip. Chips 5, 10, 50 and 100 are Triple Chance's, used read-only; the 500
  /// chip is Lucky Card's own.
  factory LuckyCardArtKey.chip(LuckyCardChip chip) => LuckyCardArtKey._(
        chip == LuckyCardChip.fiveHundred
            ? '$_own/chip_500.webp'
            : 'assets/images/chip_${chip.amount}.webp',
      );

  /// Triple Chance's win-popup frame (823 x 455) and its title (754 x 129), used
  /// read-only by the win popup.
  static const LuckyCardArtKey winPopup = LuckyCardArtKey._('assets/images/win-popup.webp');
  static const LuckyCardArtKey winText = LuckyCardArtKey._('assets/images/win-text.webp');

  /// The in-game background: a red theatre stage (1003 x 564, spec §17B).
  static const LuckyCardArtKey background = LuckyCardArtKey._('$_own/bg-lobby-lucky-card.webp');

  /// The path of the file, as `pubspec.yaml` lists it.
  final String assetPath;

  @override
  bool operator ==(Object other) => other is LuckyCardArtKey && other.assetPath == assetPath;

  @override
  int get hashCode => assetPath.hashCode;

  @override
  String toString() => 'LuckyCardArtKey($assetPath)';

  /// Every picture the screen uses: 12 cards, 4 bars, 4 symbols, 3 selectors, 5 chips,
  /// the 2 win-popup pictures and the background.
  static List<LuckyCardArtKey> get all => [
        for (final card in LuckyCard.all) LuckyCardArtKey.card(card),
        for (final suit in LuckyCardSuit.values) LuckyCardArtKey.suitBar(suit),
        for (final suit in LuckyCardSuit.values) LuckyCardArtKey.suitIcon(suit),
        for (final rank in LuckyCardRank.values) LuckyCardArtKey.rankSelector(rank),
        for (final chip in LuckyCardChip.values) LuckyCardArtKey.chip(chip),
        winPopup,
        winText,
        background,
      ];
}

/// Where the one empty area of a picture sits, as fractions of the picture
/// (measured from the supplied files on 2026-10-06, spec §17O). The live number
/// is drawn in it, centred.
@immutable
class LuckyCardSlot {
  const LuckyCardSlot(this.centerX, this.centerY, this.width, this.height);

  final double centerX;
  final double centerY;

  /// Its width and height as fractions of the picture's width and height.
  final double width;
  final double height;

  /// The slot's rectangle inside a picture drawn at [picture].
  Rect within(Rect picture) => Rect.fromCenter(
        center: Offset(
          picture.left + centerX * picture.width,
          picture.top + centerY * picture.height,
        ),
        width: width * picture.width,
        height: height * picture.height,
      );
}

/// The empty areas of the three pictures that carry a live number.
abstract final class LuckyCardSlots {
  /// The red ribbon along the bottom of every card.
  static const LuckyCardSlot cardRibbon = LuckyCardSlot(0.50, 0.87, 0.72, 0.15);

  /// The red panel of a suit bar, below the emblem that sits on its top edge.
  static const LuckyCardSlot suitPanel = LuckyCardSlot(0.50, 0.64, 0.60, 0.40);

  /// The cream disc of a rank selector (a circle: its width is the diameter, as a
  /// fraction of the picture's width; the height fraction is its share of the
  /// picture's height).
  static const LuckyCardSlot rankDisc = LuckyCardSlot(0.74, 0.50, 0.39, 0.72);
}

/// Gives a picture for a key, decoded no wider than [cacheWidth] pixels.
abstract class LuckyCardArt {
  const LuckyCardArt();

  ImageProvider image(LuckyCardArtKey key, {required int cacheWidth});
}

/// The real thing: the pictures bundled with the app.
class AssetLuckyCardArt extends LuckyCardArt {
  const AssetLuckyCardArt();

  @override
  ImageProvider image(LuckyCardArtKey key, {required int cacheWidth}) =>
      ResizeImage(AssetImage(key.assetPath), width: cacheWidth);
}
