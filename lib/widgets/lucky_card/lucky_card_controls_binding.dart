// Connects the chip rail and the three buttons to the Lucky Card provider, and puts
// the whole side column together.
//
//   LuckyCardCanvas(
//     side: (context, layout) => LuckyCardSideColumn(provider: p, layout: layout, art: art),
//   )
//
// Like the other bindings, each piece reads only what it shows into a small value and
// redraws only when that value changes: a tick of the countdown redraws none of them;
// a chip placed redraws the buttons (their "is there a bet" state) and nothing else.
//
// What the buttons do, exactly as Triple Chance's:
//   * DOUBLE doubles every stake; shown while there is a bet or no earlier bet to repeat.
//   * REBET takes DOUBLE's place when the board is empty and an earlier bet exists; it
//     keeps its name when the player cannot afford it, and is then dimmed.
//   * CLEAR gives every chip back.
//   * REMOVE puts the chip in hand down; taps on the board then take chips back. It
//     is not an undo (spec §17Y).
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky_card_board.dart';
import '../../providers/lucky_card_provider.dart';
import 'lucky_card_action_buttons.dart';
import 'lucky_card_art.dart';
import 'lucky_card_chip_rail.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_readouts.dart';
import 'lucky_card_readouts_binding.dart';

/// What the chip rail shows.
@immutable
class LuckyCardChipRailSnapshot {
  const LuckyCardChipRailSnapshot({required this.activeChip, required this.isLocked});

  factory LuckyCardChipRailSnapshot.of(LuckyCardProvider p) =>
      LuckyCardChipRailSnapshot(activeChip: p.activeChip, isLocked: p.isLocked);

  final LuckyCardChip? activeChip;
  final bool isLocked;

  @override
  bool operator ==(Object other) =>
      other is LuckyCardChipRailSnapshot && other.activeChip == activeChip && other.isLocked == isLocked;

  @override
  int get hashCode => Object.hash(activeChip, isLocked);
}

/// What the three buttons show.
@immutable
class LuckyCardButtonsSnapshot {
  const LuckyCardButtonsSnapshot({
    required this.isLocked,
    required this.hasBets,
    required this.showRebet,
    required this.canAffordRebet,
  });

  factory LuckyCardButtonsSnapshot.of(LuckyCardProvider p) => LuckyCardButtonsSnapshot(
        isLocked: p.isLocked,
        hasBets: !p.isBoardEmpty,
        showRebet: p.canRebet,
        canAffordRebet: p.canRebet && p.canAffordRebet,
      );

  final bool isLocked;
  final bool hasBets;

  /// REBET is shown in DOUBLE's place.
  final bool showRebet;

  /// Only meaningful while [showRebet].
  final bool canAffordRebet;

  @override
  bool operator ==(Object other) =>
      other is LuckyCardButtonsSnapshot &&
      other.isLocked == isLocked &&
      other.hasBets == hasBets &&
      other.showRebet == showRebet &&
      other.canAffordRebet == canAffordRebet;

  @override
  int get hashCode => Object.hash(isLocked, hasBets, showRebet, canAffordRebet);
}

/// The chip rail, linked to the provider.
class LuckyCardChipRailBinding extends StatelessWidget {
  const LuckyCardChipRailBinding({
    super.key,
    required this.provider,
    required this.layout,
    required this.art,
    this.onChipSelected,
  });

  final LuckyCardProvider provider;
  final LuckyCardLayout layout;
  final LuckyCardArt art;

  /// A chip was picked up (the click sound).
  final void Function(LuckyCardChip chip)? onChipSelected;

  @override
  Widget build(BuildContext context) {
    return LuckyCardSelector<LuckyCardChipRailSnapshot>(
      provider: provider,
      select: LuckyCardChipRailSnapshot.of,
      builder: (context, s) => LuckyCardChipRail(
        layout: layout,
        art: art,
        activeChip: s.activeChip,
        isLocked: s.isLocked,
        onSelect: (chip) {
          final result = provider.selectChip(chip);
          if (result.isClean) onChipSelected?.call(chip);
          return result;
        },
      ),
    );
  }
}

/// DOUBLE (or REBET), CLEAR and REMOVE, linked to the provider.
class LuckyCardActionButtonsBinding extends StatelessWidget {
  const LuckyCardActionButtonsBinding({
    super.key,
    required this.provider,
    required this.layout,
    this.onPressed,
    this.onRefused,
  });

  final LuckyCardProvider provider;
  final LuckyCardLayout layout;

  /// A button was accepted (the click sound).
  final void Function(LuckyCardControl control)? onPressed;

  /// A button could not do all it was asked, and why.
  final LuckyCardControlRefused? onRefused;

  @override
  Widget build(BuildContext context) {
    final side = layout.side;
    return LuckyCardSelector<LuckyCardButtonsSnapshot>(
      provider: provider,
      select: LuckyCardButtonsSnapshot.of,
      builder: (context, s) {
        Widget button(int slot, LuckyCardControl control, bool enabled, LuckyCardBoardResult Function() action) {
          final rect = layout.actionButton(slot);
          return Positioned.fromRect(
            rect: layout.within(side, rect),
            child: LuckyCardActionButton(
              key: ValueKey('button-${control.name}'),
              layout: layout,
              control: control,
              size: rect.size,
              enabled: enabled,
              isLocked: s.isLocked,
              onTap: action,
              onPressed: onPressed == null ? null : () => onPressed!(control),
              onRefused: onRefused,
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            s.showRebet
                ? button(0, LuckyCardControl.rebet, s.canAffordRebet, provider.rebet)
                : button(0, LuckyCardControl.doubleBet, s.hasBets, provider.doubleBet),
            button(1, LuckyCardControl.clear, s.hasBets, provider.clearBoard),
            button(2, LuckyCardControl.remove, s.hasBets, () {
              provider.deselectChip();
              return const LuckyCardBoardResult();
            }),
          ],
        );
      },
    );
  }
}

/// The whole side column: PLAY | WIN, the limits, the results, the chip rail and the
/// three buttons.
class LuckyCardSideColumn extends StatelessWidget {
  const LuckyCardSideColumn({
    super.key,
    required this.provider,
    required this.layout,
    required this.art,
    this.onChipSelected,
    this.onButtonPressed,
    this.onButtonRefused,
  });

  final LuckyCardProvider provider;
  final LuckyCardLayout layout;
  final LuckyCardArt art;
  final void Function(LuckyCardChip chip)? onChipSelected;
  final void Function(LuckyCardControl control)? onButtonPressed;
  final LuckyCardControlRefused? onButtonRefused;

  @override
  Widget build(BuildContext context) {
    final side = layout.side;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: LuckyCardSideReadouts(provider: provider, layout: layout, art: art)),
        Positioned.fromRect(
          rect: layout.within(side, layout.chipRail),
          child: LuckyCardChipRailBinding(
            provider: provider,
            layout: layout,
            art: art,
            onChipSelected: onChipSelected,
          ),
        ),
        Positioned.fill(
          child: LuckyCardActionButtonsBinding(
            provider: provider,
            layout: layout,
            onPressed: onButtonPressed,
            onRefused: onButtonRefused,
          ),
        ),
      ],
    );
  }
}

/// Loads the chips and the suit icons into the image cache before the screen shows.
Future<void> precacheLuckyCardSideColumn(BuildContext context, LuckyCardLayout layout, LuckyCardArt art) =>
    Future.wait([precacheLuckyCardChips(context, layout, art), precacheLuckyCardResults(context, layout, art)]);
