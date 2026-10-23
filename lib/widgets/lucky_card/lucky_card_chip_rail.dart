// The chip row: the five chips (5, 10, 50, 100, 500) side by side in the bet panel, under the
// results, as the reference design has them.
//
// Given the chip in hand and whether betting is closed, nothing else: no provider
// (lucky_card_controls_binding.dart connects it).
//
//   * Every chip has a tap area 48 dp tall and a fifth of the row wide (about 44 dp on the
//     smallest phone, the written exception of 2026-10-23) and is drawn inside it: the chip
//     in hand full size with a gold glow, the others smaller, so the chosen chip is easy to
//     tell at a glance. Tapping the chip already in hand
//     keeps it in hand, as in Triple Chance.
//   * While betting is closed the chips are dimmed like the rest of the board and
//     ignore taps.
//   * The tap goes to [onSelect], which answers with the board's receipt; a chip
//     is never refused except for the lock, which the dimming already shows.
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky_card_board.dart';
import 'lucky_card_art.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_palette.dart';
import 'lucky_card_panel.dart';
import 'lucky_card_tap_target.dart';

/// The words a screen reader says for a chip.
String luckyCardChipSemantics(LuckyCardChip chip, {required bool selected}) =>
    '${chip.amount} chip${selected ? ', in hand' : ''}';

class LuckyCardChipRail extends StatelessWidget {
  const LuckyCardChipRail({
    super.key,
    required this.layout,
    required this.art,
    required this.activeChip,
    required this.isLocked,
    required this.onSelect,
  });

  final LuckyCardLayout layout;
  final LuckyCardArt art;

  /// The chip in hand, or null when the hands are empty.
  final LuckyCardChip? activeChip;
  final bool isLocked;
  final LuckyCardBoardResult Function(LuckyCardChip chip) onSelect;

  /// The share of its tap area a chip is drawn at: in hand, and not in hand.
  static const double selectedShare = 0.94;
  static const double restingShare = 0.74;

  @override
  Widget build(BuildContext context) {
    final rail = layout.chipRail;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final chip in LuckyCardChip.values)
          Positioned.fromRect(
            rect: layout.within(rail, layout.chip(chip.index)),
            child: LuckyCardTapTarget(
              key: ValueKey('chip-${chip.amount}'),
              size: layout.chip(chip.index).size,
              semanticsLabel: luckyCardChipSemantics(chip, selected: chip == activeChip),
              isLocked: isLocked,
              onTap: () => onSelect(chip),
              content: (context, tinted) {
                final selected = chip == activeChip;
                final side = layout.designChipSize * (selected ? 1.0 : restingShare / selectedShare);
                return Center(
                  child: AnimatedContainer(
                    key: ValueKey('chip-face-${chip.amount}'),
                    duration: const Duration(milliseconds: 150),
                    transform: Matrix4.translationValues(0, selected ? -layout.dp(3) : 0, 0),
                    width: side,
                    height: side,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: selected
                          ? [
                              BoxShadow(color: kDesignChipUnder, offset: Offset(0, layout.dp(3))),
                              BoxShadow(color: kDesignChipInnerRing, spreadRadius: layout.dp(3)),
                              BoxShadow(color: kDesignChipGoldRing, spreadRadius: layout.dp(5)),
                              BoxShadow(color: kDesignChipGoldGlow, spreadRadius: layout.dp(5), blurRadius: layout.dp(14)),
                            ]
                          : const [],
                    ),
                    child: tinted(
                      Image(
                        image: art.image(LuckyCardArtKey.chip(chip), cacheWidth: layout.chipCacheWidth(dpr)),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Loads the five chip pictures (at the width the rail draws them) into the image
/// cache, so no chip pops in when the screen opens.
Future<void> precacheLuckyCardChips(BuildContext context, LuckyCardLayout layout, LuckyCardArt art) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return Future.wait([
    for (final chip in LuckyCardChip.values)
      precacheImage(art.image(LuckyCardArtKey.chip(chip), cacheWidth: layout.chipCacheWidth(dpr)), context),
  ]);
}
