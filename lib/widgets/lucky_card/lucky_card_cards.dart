// The 12 cards of the board: each a picture that fills its cell, with its live stake on the red
// plate under the card ("Play" while empty, then the whole number, never shortened), tapped to
// place or take back a chip. The plate's place and the text's size are the reference design's.
//
// A cell does not know about the game. It is told its stake and whether the board
// is locked, and it calls [LuckyCardCardTap] when tapped; how a tap is answered (a
// pulse, a red flash, the locked look, the screen-reader label) is the shared
// [LuckyCardTapTarget].
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky_card_board.dart';
import '../../models/lucky_card_models.dart';
import 'lucky_card_art.dart';
import 'lucky_card_board_snapshot.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_stake_text.dart';
import 'lucky_card_tap_target.dart';

/// Called when a card is tapped; answers with what the board did.
typedef LuckyCardCardTap = LuckyCardBoardResult Function(LuckyCard card);

/// Called when a tap was refused (in whole or in part), with the reasons.
typedef LuckyCardRefusedTap = void Function(LuckyCard card, Set<LuckyCardBoardIssue> issues);

class LuckyCardCardCell extends StatelessWidget {
  const LuckyCardCardCell({
    super.key,
    required this.card,
    required this.layout,
    required this.art,
    required this.stake,
    required this.isLocked,
    required this.onTap,
    this.onRefused,
  });

  final LuckyCard card;
  final LuckyCardLayout layout;
  final LuckyCardArt art;
  final int stake;
  final bool isLocked;
  final LuckyCardCardTap onTap;
  final LuckyCardRefusedTap? onRefused;

  @override
  Widget build(BuildContext context) {
    final cell = layout.cardCell(card.suit.index, card.rank.index);
    // The picture fills the whole cell (the design's own object-fit: fill): the cell has the
    // card picture's shape, so nothing is squeezed.
    final picture = Offset.zero & cell.size;
    final plate = LuckyCardSlots.cardPlate.within(picture);
    final empty = stake <= 0;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final image = Image(
      image: art.image(LuckyCardArtKey.card(card), cacheWidth: layout.cardCacheWidth(dpr)),
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
      semanticsLabel: '${card.rank.label} of ${card.suit.label}, '
          '${empty ? 'no coins' : '$stake coins'}',
      onTap: () => onTap(card),
      onRefused: onRefused == null ? null : (issues) => onRefused!(card, issues),
      content: (context, tinted) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(rect: picture, child: tinted(image)),
          Positioned.fromRect(
            rect: plate,
            child: LuckyCardStakeText(
              luckyCardRibbonLabel(stake),
              maxWidth: plate.width,
              preferredSize: layout.designCardFont,
              // White like the design's own card letters; "Play" is a touch dimmer so an empty
              // card still reads as empty next to one with a stake on it.
              color: empty ? const Color(0xCCFFFFFF) : const Color(0xFFFFFFFF),
              shadowColor: const Color(0xFF5A0610),
              weight: FontWeight.w700,
              shadowOffset: const Offset(0, 2),
              shadowBlur: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// The 12 cards, placed in the grid zone's rows 1 to 3 (row 0 is the suit
/// headers). Give it the grid zone; positions are relative to that zone.
class LuckyCardCardLayer extends StatelessWidget {
  const LuckyCardCardLayer({
    super.key,
    required this.layout,
    required this.art,
    required this.snapshot,
    required this.onTapCard,
    this.onRefused,
  });

  final LuckyCardLayout layout;
  final LuckyCardArt art;
  final LuckyCardBoardSnapshot snapshot;
  final LuckyCardCardTap onTapCard;
  final LuckyCardRefusedTap? onRefused;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final card in LuckyCard.all)
          Positioned.fromRect(
            rect: layout.cardCell(card.suit.index, card.rank.index).shift(-layout.grid.topLeft),
            child: LuckyCardCardCell(
              key: ValueKey(card.key),
              card: card,
              layout: layout,
              art: art,
              stake: snapshot.stakeOn(card),
              isLocked: snapshot.isLocked,
              onTap: onTapCard,
              onRefused: onRefused,
            ),
          ),
      ],
    );
  }
}
