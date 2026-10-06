// The 4 suit headers and the 3 rank selectors: the shortcuts that put a chip on
// several cards at once, and show what is on those cards (spec §3: they are views
// of the 12 stakes, never bets of their own).
//
//   * A suit header is its name (Hearts), its bar picture, and the suit's total on
//     the bar's red panel. A tap places or takes back a chip on the suit's three
//     cards. Blank at 0.
//   * A rank selector is its name (Jacks), its selector picture, and the rank's
//     total on the cream disc, in dark text. A tap does the same on the rank's four
//     cards. Blank at 0; from 100,000 up the disc shows 100K, 200K (§17O).
//
// Each is the whole area of its cell (never under 48 dp) and answers a tap the way
// every board piece does ([LuckyCardTapTarget]). Neither knows about the game.
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky_card_board.dart';
import '../../models/lucky_card_models.dart';
import 'lucky_card_art.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_stake_text.dart';
import 'lucky_card_tap_target.dart';

/// Called when a suit header is tapped; answers with what the board did.
typedef LuckyCardSuitTap = LuckyCardBoardResult Function(LuckyCardSuit suit);

/// Called when a rank selector is tapped; answers with what the board did.
typedef LuckyCardRankTap = LuckyCardBoardResult Function(LuckyCardRank rank);

/// Called when a suit header's tap was refused, with the reasons.
typedef LuckyCardSuitRefused = void Function(LuckyCardSuit suit, Set<LuckyCardBoardIssue> issues);

/// Called when a rank selector's tap was refused, with the reasons.
typedef LuckyCardRankRefused = void Function(LuckyCardRank rank, Set<LuckyCardBoardIssue> issues);

/// The plural a rank's name is shown in ("Jacks").
String luckyCardRankName(LuckyCardRank rank) => '${rank.label}s';

String _coins(int total) => total <= 0 ? 'no coins' : '$total coins';

class _Name extends StatelessWidget {
  const _Name(this.text, {required this.rect, required this.fontSize});

  final String text;
  final Rect rect;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: Center(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontWeight: FontWeight.w500,
              fontSize: fontSize,
              height: 1.0,
              color: const Color(0xFFF5E6C4),
              shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 2, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

class LuckyCardSuitHeader extends StatelessWidget {
  const LuckyCardSuitHeader({
    super.key,
    required this.suit,
    required this.layout,
    required this.art,
    required this.total,
    required this.isLocked,
    required this.onTap,
    this.onRefused,
  });

  final LuckyCardSuit suit;
  final LuckyCardLayout layout;
  final LuckyCardArt art;

  /// The sum of the suit's three cards.
  final int total;
  final bool isLocked;
  final LuckyCardSuitTap onTap;
  final LuckyCardSuitRefused? onRefused;

  @override
  Widget build(BuildContext context) {
    final column = suit.index;
    final cell = layout.suitHeader(column);
    final bar = layout.suitBar(column).shift(-cell.topLeft);
    final label = layout.suitLabel(column).shift(-cell.topLeft);
    final panel = LuckyCardSlots.suitPanel.within(bar);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final image = Image(
      image: art.image(LuckyCardArtKey.suitBar(suit), cacheWidth: layout.barCacheWidth(dpr)),
      width: bar.width,
      height: bar.height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );

    return LuckyCardTapTarget(
      size: cell.size,
      isLocked: isLocked,
      semanticsLabel: '${suit.label}, 3 cards, ${_coins(total)}',
      onTap: () => onTap(suit),
      onRefused: onRefused == null ? null : (issues) => onRefused!(suit, issues),
      content: (context, tinted) => Stack(
        clipBehavior: Clip.none,
        children: [
          _Name(suit.label, rect: label, fontSize: layout.labelFontSize),
          Positioned.fromRect(rect: bar, child: tinted(image)),
          Positioned.fromRect(
            rect: panel,
            child: LuckyCardStakeText(
              luckyCardSuitLabel(total),
              maxWidth: panel.width * 0.92,
              preferredSize: layout.fontSize(bar.height * 0.40 / layout.scale),
            ),
          ),
        ],
      ),
    );
  }
}

class LuckyCardRankSelector extends StatelessWidget {
  const LuckyCardRankSelector({
    super.key,
    required this.rank,
    required this.layout,
    required this.art,
    required this.total,
    required this.isLocked,
    required this.onTap,
    this.onRefused,
  });

  final LuckyCardRank rank;
  final LuckyCardLayout layout;
  final LuckyCardArt art;

  /// The sum of the rank's four cards.
  final int total;
  final bool isLocked;
  final LuckyCardRankTap onTap;
  final LuckyCardRankRefused? onRefused;

  @override
  Widget build(BuildContext context) {
    final row = rank.index;
    final cell = layout.rankSelector(row);
    final picture = layout.rankPicture(row).shift(-cell.topLeft);
    final label = layout.rankLabel(row).shift(-cell.topLeft);
    final disc = LuckyCardSlots.rankDisc.within(picture);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final image = Image(
      image: art.image(LuckyCardArtKey.rankSelector(rank), cacheWidth: layout.selectorCacheWidth(dpr)),
      width: picture.width,
      height: picture.height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );

    return LuckyCardTapTarget(
      size: cell.size,
      isLocked: isLocked,
      semanticsLabel: '${luckyCardRankName(rank)}, 4 cards, ${_coins(total)}',
      onTap: () => onTap(rank),
      onRefused: onRefused == null ? null : (issues) => onRefused!(rank, issues),
      content: (context, tinted) => Stack(
        clipBehavior: Clip.none,
        children: [
          _Name(luckyCardRankName(rank), rect: label, fontSize: layout.labelFontSize),
          Positioned.fromRect(rect: picture, child: tinted(image)),
          Positioned.fromRect(
            rect: disc,
            child: LuckyCardStakeText(
              luckyCardRankLabel(total),
              // The disc is round: a little less than its width is usable.
              maxWidth: disc.width * 0.85,
              preferredSize: layout.fontSize(picture.height * 0.30 / layout.scale),
              // Dark on the cream disc; no shadow.
              color: const Color(0xFF4A1A00),
              shadowColor: const Color(0x00000000),
            ),
          ),
        ],
      ),
    );
  }
}
