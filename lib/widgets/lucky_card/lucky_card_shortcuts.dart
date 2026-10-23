// The 4 suit bars and the 3 rank badges: the shortcuts that put a chip on several cards at
// once, and show what is on those cards (spec §3: they are views of the 12 stakes, never bets
// of their own). Built to the reference design.
//
//   * A suit bar is its picture (the suit's emblem in a hexagon, then an empty red plate) with
//     the suit's NAME on the plate (HEARTS) while nothing is on its three cards, and the suit's
//     total, written in full, once there is one. A tap places or takes back a chip on the
//     suit's three cards.
//   * A rank badge is its picture (the letter over an empty purple oval) with the rank's NAME
//     on the oval (JACKS) while nothing is on its four cards, and the rank's total, written in
//     full, once there is one. A tap does the same on the rank's four cards.
//
// Neither ever shortens a number (the user's decision of 2026-10-23: no "100K").
//
// Each is the whole area of its cell (never under 48 dp) and answers a tap the way every board
// piece does ([LuckyCardTapTarget]). Neither knows about the game.
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky_card_board.dart';
import '../../models/lucky_card_models.dart';
import 'lucky_card_art.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_stake_text.dart';
import 'lucky_card_tap_target.dart';

/// Called when a suit bar is tapped; answers with what the board did.
typedef LuckyCardSuitTap = LuckyCardBoardResult Function(LuckyCardSuit suit);

/// Called when a rank badge is tapped; answers with what the board did.
typedef LuckyCardRankTap = LuckyCardBoardResult Function(LuckyCardRank rank);

/// Called when a suit bar's tap was refused, with the reasons.
typedef LuckyCardSuitRefused = void Function(LuckyCardSuit suit, Set<LuckyCardBoardIssue> issues);

/// Called when a rank badge's tap was refused, with the reasons.
typedef LuckyCardRankRefused = void Function(LuckyCardRank rank, Set<LuckyCardBoardIssue> issues);

/// The plural a rank's name is shown in ("Jacks").
String luckyCardRankName(LuckyCardRank rank) => '${rank.label}s';

String _coins(int total) => total <= 0 ? 'no coins' : '$total coins';

/// A name on a plate: the design's heavy sans, upper case, white, with a hard shadow in the
/// plate's own dark colour and a soft one behind it. It shrinks to fit the plate (never under
/// 11 dp) rather than being cut.
class _PlateName extends StatelessWidget {
  const _PlateName(this.text, {required this.rect, required this.fontSize, required this.shadow});

  final String text;
  final Rect rect;
  final double fontSize;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    final size = fitLuckyCardFontSize(
      text: text.toUpperCase(),
      style: const TextStyle(fontFamily: 'DMSans', fontWeight: FontWeight.w800, letterSpacing: 0.3, height: 1.0),
      maxWidth: rect.width,
      preferred: fontSize,
    );
    return Positioned.fromRect(
      rect: rect,
      child: Center(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontWeight: FontWeight.w800,
              fontSize: size,
              letterSpacing: 0.3,
              height: 1.0,
              color: const Color(0xFFFFFFFF),
              shadows: [
                Shadow(color: shadow, offset: const Offset(0, 1)),
                const Shadow(color: Color(0x80000000), blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A total on a plate, in the board's number face: bold white with the plate's hard shadow.
class _PlateTotal extends StatelessWidget {
  const _PlateTotal(this.text, {required this.rect, required this.fontSize, required this.shadow});

  final String text;
  final Rect rect;
  final double fontSize;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: LuckyCardStakeText(
        text,
        maxWidth: rect.width,
        preferredSize: fontSize,
        color: const Color(0xFFFFFFFF),
        shadowColor: shadow,
        weight: FontWeight.w700,
        shadowOffset: const Offset(0, 2),
        shadowBlur: 0,
      ),
    );
  }
}

/// The dark red the design shades its suit bars' and cards' text with, and the dark purple it
/// shades a rank badge's with.
const Color _kBarShadow = Color(0xFF5A0610);
const Color _kBadgeShadow = Color(0xFF2E0F63);

/// How much larger a total's digits are than the name's letters on the same plate: the design
/// draws no totals, and its narrow number face reads smaller than its heavy sans at one size.
const double _kTotalFontScale = 1.5;

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
    final cell = layout.suitHeader(suit.index);
    final bar = Offset.zero & cell.size;
    final plate = LuckyCardSlots.suitPlate.within(bar);
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
          Positioned.fromRect(rect: bar, child: tinted(image)),
          if (total <= 0)
            _PlateName(suit.label, rect: plate, fontSize: layout.designBarFont, shadow: _kBarShadow)
          else
            _PlateTotal(luckyCardSuitLabel(total), rect: plate, fontSize: layout.designBarFont * _kTotalFontScale, shadow: _kBarShadow),
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
    final cell = layout.rankSelector(rank.index);
    final picture = Offset.zero & cell.size;
    final plate = LuckyCardSlots.rankPlate.within(picture);
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
          Positioned.fromRect(rect: picture, child: tinted(image)),
          if (total <= 0)
            _PlateName(luckyCardRankName(rank), rect: plate, fontSize: layout.designBadgeFont, shadow: _kBadgeShadow)
          else
            _PlateTotal(luckyCardRankLabel(total), rect: plate, fontSize: layout.designBadgeFont * _kTotalFontScale, shadow: _kBadgeShadow),
        ],
      ),
    );
  }
}
