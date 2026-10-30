// The 16 cards of the board: each a picture that fills its cell, with its live stake on the red
// plate under the card ("Play" while empty, then the whole number, never shortened), tapped to
// place or take back a chip. The plate's place was measured on the Lucky 16 pictures
// ([Lucky16Slots.cardPlate]) and the text's size matches the approved mockup.
//
// A cell does not know about the game. It is told its stake and whether the board
// is locked, and it calls [Lucky16CardTap] when tapped; how a tap is answered (a
// pulse, a red flash, the locked look, the screen-reader label) is the shared
// [Lucky16TapTarget].
//
// Copied from lib/widgets/lucky_card/lucky_card_cards.dart (Lucky Card); the names changed, and the
// counts are Lucky 16 Card's (16 cards, 4 on a suit bar, 4 rank selectors A, J, Q, K).
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky16_board.dart';
import '../../models/lucky16_models.dart';
import 'lucky16_art.dart';
import 'lucky16_board_snapshot.dart';
import 'lucky16_layout.dart';
import 'lucky16_stake_text.dart';
import 'lucky16_tap_target.dart';

/// Called when a card is tapped; answers with what the board did.
typedef Lucky16CardTap = Lucky16BoardResult Function(Lucky16Card card);

/// Called when a tap was refused (in whole or in part), with the reasons.
typedef Lucky16RefusedTap = void Function(Lucky16Card card, Set<Lucky16BoardIssue> issues);

class Lucky16CardCell extends StatelessWidget {
  const Lucky16CardCell({
    super.key,
    required this.card,
    required this.layout,
    required this.art,
    required this.stake,
    required this.isLocked,
    required this.onTap,
    this.onRefused,
  });

  final Lucky16Card card;
  final Lucky16Layout layout;
  final Lucky16Art art;
  final int stake;
  final bool isLocked;
  final Lucky16CardTap onTap;
  final Lucky16RefusedTap? onRefused;

  @override
  Widget build(BuildContext context) {
    final cell = layout.cardCell(card.suit.index, card.rank.index);
    // The picture fills the whole cell (the design's own object-fit: fill): the cell has the
    // card picture's shape, so nothing is squeezed.
    final picture = Offset.zero & cell.size;
    final plate = Lucky16Slots.cardPlate.within(picture);
    final empty = stake <= 0;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final image = Image(
      image: art.image(Lucky16ArtKey.card(card), cacheWidth: layout.cardCacheWidth(dpr)),
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
            child: Lucky16StakeText(
              lucky16RibbonLabel(stake),
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

/// The 16 cards, placed in the grid zone's rows 1 to 4 (row 0 is the suit
/// headers). Give it the grid zone; positions are relative to that zone.
class Lucky16CardLayer extends StatelessWidget {
  const Lucky16CardLayer({
    super.key,
    required this.layout,
    required this.art,
    required this.snapshot,
    required this.onTapCard,
    this.onRefused,
  });

  final Lucky16Layout layout;
  final Lucky16Art art;
  final Lucky16BoardSnapshot snapshot;
  final Lucky16CardTap onTapCard;
  final Lucky16RefusedTap? onRefused;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final card in Lucky16Card.all)
          Positioned.fromRect(
            rect: layout.cardCell(card.suit.index, card.rank.index).shift(-layout.grid.topLeft),
            child: Lucky16CardCell(
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
