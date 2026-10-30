// The 4 suit bars and the 4 rank selectors: the shortcuts that put a chip on several cards at
// once, and show what is on those cards (they are views of the 16 stakes, never bets of their
// own). Drawn as the approved mockup (reference-design/lucky16/lucky16-phone.html) places them.
//
//   * A suit bar is its picture (the suit's emblem at the left, then an empty plate) with the
//     suit's NAME on the plate (HEARTS) while nothing is on its four cards, and the suit's
//     total, written in full, once there is one. A tap places or takes back a chip on the
//     suit's four cards (A, J, Q, K).
//   * A rank selector is its picture (the letter over an empty purple ribbon) with the rank's
//     NAME on the ribbon (ACES) while nothing is on its four cards, and the rank's total, written
//     in full, once there is one. A tap does the same on the rank's four cards.
//
// Neither ever shortens a number (the user's decision of 2026-10-23: no "100K").
//
// Each is the whole area of its cell (never under 48 dp) and answers a tap the way every board
// piece does ([Lucky16TapTarget]). Neither knows about the game.
//
// Copied from lib/widgets/lucky_card/lucky_card_shortcuts.dart (Lucky Card); the names changed, and the
// counts are Lucky 16 Card's (16 cards, 4 on a suit bar, 4 rank selectors A, J, Q, K).
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky16_board.dart';
import '../../models/lucky16_models.dart';
import 'lucky16_art.dart';
import 'lucky16_layout.dart';
import 'lucky16_stake_text.dart';
import 'lucky16_tap_target.dart';

/// Called when a suit bar is tapped; answers with what the board did.
typedef Lucky16SuitTap = Lucky16BoardResult Function(Lucky16Suit suit);

/// Called when a rank badge is tapped; answers with what the board did.
typedef Lucky16RankTap = Lucky16BoardResult Function(Lucky16Rank rank);

/// Called when a suit bar's tap was refused, with the reasons.
typedef Lucky16SuitRefused = void Function(Lucky16Suit suit, Set<Lucky16BoardIssue> issues);

/// Called when a rank badge's tap was refused, with the reasons.
typedef Lucky16RankRefused = void Function(Lucky16Rank rank, Set<Lucky16BoardIssue> issues);

/// The plural a rank's name is shown in ("Jacks").
String lucky16RankName(Lucky16Rank rank) => '${rank.label}s';

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
    final size = fitLucky16FontSize(
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
      child: Lucky16StakeText(
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

/// The shade under a suit bar's text (a near-black: Lucky 16's bars are red, blue, red and green, so
/// Lucky Card's dark red would only suit two of them), and the dark purple under a rank selector's.
const Color _kBarShadow = Color(0xCC000000);
const Color _kBadgeShadow = Color(0xFF2E0F63);

/// How much larger a total's digits are than the name's letters on the same plate (the narrow number
/// face reads smaller than the heavy sans at one size): 1.3 on a suit bar and 1.1 on a selector's
/// ribbon, which gives the approved mockup's sizes.
const double _kBarTotalFontScale = 1.3;
const double _kBadgeTotalFontScale = 1.1;

class Lucky16SuitHeader extends StatelessWidget {
  const Lucky16SuitHeader({
    super.key,
    required this.suit,
    required this.layout,
    required this.art,
    required this.total,
    required this.isLocked,
    required this.onTap,
    this.onRefused,
  });

  final Lucky16Suit suit;
  final Lucky16Layout layout;
  final Lucky16Art art;

  /// The sum of the suit's four cards.
  final int total;
  final bool isLocked;
  final Lucky16SuitTap onTap;
  final Lucky16SuitRefused? onRefused;

  @override
  Widget build(BuildContext context) {
    final cell = layout.suitHeader(suit.index);
    final bar = Offset.zero & cell.size;
    final plate = Lucky16Slots.suitPlate.within(bar);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final image = Image(
      image: art.image(Lucky16ArtKey.suitBar(suit), cacheWidth: layout.barCacheWidth(dpr)),
      width: bar.width,
      height: bar.height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );

    return Lucky16TapTarget(
      size: cell.size,
      isLocked: isLocked,
      semanticsLabel: '${suit.label}, 4 cards, ${_coins(total)}',
      onTap: () => onTap(suit),
      onRefused: onRefused == null ? null : (issues) => onRefused!(suit, issues),
      content: (context, tinted) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(rect: bar, child: tinted(image)),
          if (total <= 0)
            _PlateName(suit.label, rect: plate, fontSize: layout.designBarFont, shadow: _kBarShadow)
          else
            _PlateTotal(lucky16SuitLabel(total),
                rect: plate, fontSize: layout.designBarFont * _kBarTotalFontScale, shadow: _kBarShadow),
        ],
      ),
    );
  }
}

class Lucky16RankSelector extends StatelessWidget {
  const Lucky16RankSelector({
    super.key,
    required this.rank,
    required this.layout,
    required this.art,
    required this.total,
    required this.isLocked,
    required this.onTap,
    this.onRefused,
  });

  final Lucky16Rank rank;
  final Lucky16Layout layout;
  final Lucky16Art art;

  /// The sum of the rank's four cards.
  final int total;
  final bool isLocked;
  final Lucky16RankTap onTap;
  final Lucky16RankRefused? onRefused;

  @override
  Widget build(BuildContext context) {
    final cell = layout.rankSelector(rank.index);
    final picture = Offset.zero & cell.size;
    final plate = Lucky16Slots.rankPlate.within(picture);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final image = Image(
      image: art.image(Lucky16ArtKey.rankSelector(rank), cacheWidth: layout.selectorCacheWidth(dpr)),
      width: picture.width,
      height: picture.height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );

    return Lucky16TapTarget(
      size: cell.size,
      isLocked: isLocked,
      semanticsLabel: '${lucky16RankName(rank)}, 4 cards, ${_coins(total)}',
      onTap: () => onTap(rank),
      onRefused: onRefused == null ? null : (issues) => onRefused!(rank, issues),
      content: (context, tinted) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(rect: picture, child: tinted(image)),
          if (total <= 0)
            _PlateName(lucky16RankName(rank), rect: plate, fontSize: layout.designBadgeFont, shadow: _kBadgeShadow)
          else
            _PlateTotal(lucky16RankLabel(total),
                rect: plate, fontSize: layout.designBadgeFont * _kBadgeTotalFontScale, shadow: _kBadgeShadow),
        ],
      ),
    );
  }
}
