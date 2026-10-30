// Where the Lucky 16 Card pictures come from.
//
// Copied from lib/widgets/lucky_card/lucky_card_art.dart (Lucky Card). The widgets never name an
// image file: they ask a [Lucky16Art] for a picture by key and say how wide it will be drawn, and
// the answer is always decoded at that width, never larger.
//
// Lucky 16 Card's own pictures are in assets/lucky16card/images/: the 16 cards (A, J, Q, K of each
// suit, 700 x 476), the four suit bars (1049 x 270), the four rank selectors (640 x 687) and the
// lobby poster (474 x 680). Everything else is another game's picture, read in place and never
// copied or changed: the suit icons, the history-card frames, the 500 chip and the background are
// Lucky Card's; the 5, 10, 50 and 100 chips, the BSG coin and the win-popup frame and title are
// Triple Chance's.
//
// The real app will use [AssetLucky16Art] once assets/lucky16card/images/ is listed in
// `pubspec.yaml` (a later phase, with its own approval; until then the screen is not reachable from
// the lobby). The tests read the same files from disk.
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky16_board.dart';
import '../../models/lucky16_models.dart';

/// Which picture. Holds only the file's path.
@immutable
class Lucky16ArtKey {
  const Lucky16ArtKey._(this.assetPath);

  static const String _own = 'assets/lucky16card/images';
  static const String _luckyCard = 'assets/lucky_card/images';

  /// The picture of one card (700 x 476), for example `hearts-a-card.webp`.
  factory Lucky16ArtKey.card(Lucky16Card card) =>
      Lucky16ArtKey._('$_own/${card.suit.dbValue}-${card.rank.dbValue.toLowerCase()}-card.webp');

  /// A suit's bar: its emblem at the left and an empty plate at the right (1049 x 270).
  factory Lucky16ArtKey.suitBar(Lucky16Suit suit) => Lucky16ArtKey._('$_own/${suit.dbValue}-bar.webp');

  /// A rank's selector: its A, J, Q or K over an empty plate (640 x 687).
  factory Lucky16ArtKey.rankSelector(Lucky16Rank rank) =>
      Lucky16ArtKey._('$_own/${rank.dbValue.toLowerCase()}-selector.webp');

  /// A suit's bare symbol (Lucky Card's, read-only), for the history cards.
  factory Lucky16ArtKey.suitIcon(Lucky16Suit suit) => Lucky16ArtKey._('$_luckyCard/${suit.dbValue}-icon.webp');

  /// A chip: 5, 10, 50 and 100 are Triple Chance's, the 500 is Lucky Card's (all read-only).
  factory Lucky16ArtKey.chip(Lucky16Chip chip) => Lucky16ArtKey._(
        chip == Lucky16Chip.fiveHundred ? '$_luckyCard/chip_500.webp' : 'assets/images/chip_${chip.amount}.webp',
      );

  /// The BSG coin (Triple Chance's, read-only), drawn in the header beside the balance.
  static const Lucky16ArtKey coin = Lucky16ArtKey._('assets/images/bsg_coin.webp');

  /// The history-card frames (Lucky Card's, read-only): cream for older rounds, green for the newest.
  static const Lucky16ArtKey historyCard = Lucky16ArtKey._('$_luckyCard/history-card.webp');
  static const Lucky16ArtKey latestHistoryCard = Lucky16ArtKey._('$_luckyCard/latest-history-card.webp');

  /// Triple Chance's win-popup frame (823 x 455) and its title (754 x 129), read-only, as Lucky Card's
  /// win popup uses them.
  static const Lucky16ArtKey winPopup = Lucky16ArtKey._('assets/images/win-popup.webp');
  static const Lucky16ArtKey winText = Lucky16ArtKey._('assets/images/win-text.webp');

  /// The in-game background (Lucky Card's red theatre stage, read-only).
  static const Lucky16ArtKey background = Lucky16ArtKey._('$_luckyCard/bg-lobby-lucky-card.webp');

  /// The lobby poster (474 x 680).
  static const Lucky16ArtKey gameCard = Lucky16ArtKey._('$_own/lucky-16-game-card.webp');

  /// The path of the file, as `pubspec.yaml` lists it.
  final String assetPath;

  @override
  bool operator ==(Object other) => other is Lucky16ArtKey && other.assetPath == assetPath;

  @override
  int get hashCode => assetPath.hashCode;

  @override
  String toString() => 'Lucky16ArtKey($assetPath)';

  /// Every picture the game screen uses: 16 cards, 4 bars, 4 selectors, 4 suit icons, 5 chips,
  /// the 2 history-card frames, the 2 win-popup pictures, the coin and the background (the poster is the
  /// lobby's).
  static List<Lucky16ArtKey> get all => [
        for (final card in Lucky16Card.all) Lucky16ArtKey.card(card),
        for (final suit in Lucky16Suit.values) Lucky16ArtKey.suitBar(suit),
        for (final rank in Lucky16Rank.values) Lucky16ArtKey.rankSelector(rank),
        for (final suit in Lucky16Suit.values) Lucky16ArtKey.suitIcon(suit),
        for (final chip in Lucky16Chip.values) Lucky16ArtKey.chip(chip),
        historyCard,
        latestHistoryCard,
        winPopup,
        winText,
        coin,
        background,
      ];
}

/// Where the one empty area of a picture sits, as fractions of the picture. The live number or name is
/// drawn in it, centred. (Copied from Lucky Card's `LuckyCardSlot`.)
@immutable
class Lucky16Slot {
  const Lucky16Slot(this.centerX, this.centerY, this.width, this.height);

  final double centerX;
  final double centerY;

  /// Its width and height as fractions of the picture's width and height.
  final double width;
  final double height;

  /// The slot's rectangle inside a picture drawn at [picture].
  Rect within(Rect picture) => Rect.fromCenter(
        center: Offset(picture.left + centerX * picture.width, picture.top + centerY * picture.height),
        width: width * picture.width,
        height: height * picture.height,
      );
}

/// The empty areas of the three Lucky 16 pictures that carry a live number or name, measured on the
/// pictures themselves (2026-10-28).
abstract final class Lucky16Slots {
  /// The red plate along the bottom of every card (700 x 476): about 345 to 460 px down, 25 to 675 px
  /// across, so centred 84.5% down; the text keeps inside 84% of the width and 22% of the height.
  static const Lucky16Slot cardPlate = Lucky16Slot(0.50, 0.845, 0.84, 0.22);

  /// The plate of a suit bar (1049 x 270), right of its emblem: about 330 to 1015 px across.
  static const Lucky16Slot suitPlate = Lucky16Slot(0.645, 0.50, 0.60, 0.80);

  /// The purple ribbon of a rank selector (640 x 687), under its letter: about 445 to 610 px down; the
  /// text keeps inside the ribbon's flat middle, 70% of the width.
  static const Lucky16Slot rankPlate = Lucky16Slot(0.50, 0.765, 0.70, 0.20);
}

/// Gives a picture for a key, decoded no wider than [cacheWidth] pixels.
abstract class Lucky16Art {
  const Lucky16Art();

  ImageProvider image(Lucky16ArtKey key, {required int cacheWidth});
}

/// The real thing: the pictures bundled with the app.
class AssetLucky16Art extends Lucky16Art {
  const AssetLucky16Art();

  @override
  ImageProvider image(Lucky16ArtKey key, {required int cacheWidth}) =>
      ResizeImage(AssetImage(key.assetPath), width: cacheWidth);
}
