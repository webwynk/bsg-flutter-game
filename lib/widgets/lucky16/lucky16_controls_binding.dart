// Connects the chip row and the three buttons to the Lucky 16 Card provider, and puts the whole bet
// panel together.
//
//   Lucky16Canvas(
//     side: (context, layout) => Lucky16SideColumn(provider: p, layout: layout, art: art),
//   )
//
// Copied from lib/widgets/lucky_card/lucky_card_controls_binding.dart (Lucky Card), phone arrangement
// and tablet. Like the other bindings, each piece reads only what
// it shows into a small value and redraws only when that value changes: a tick of the countdown redraws
// none of them; a chip placed redraws the buttons (their "is there a bet" state) and nothing else.
//
// What the buttons do, exactly as Lucky Card's (and Triple Chance's):
//   * DOUBLE doubles every stake; shown while there is a bet or no earlier bet to repeat.
//   * REBET takes DOUBLE's place when the board is empty and an earlier bet exists; it keeps its
//     name when the player cannot afford it, and is then dimmed.
//   * CLEAR gives every chip back.
//   * REMOVE puts the chip in hand down; taps on the board then take chips back. It is not an undo.
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky16_board.dart';
import '../../providers/lucky16_provider.dart';
import 'lucky16_action_buttons.dart';
import 'lucky16_art.dart';
import 'lucky16_bet_panel.dart';
import 'lucky16_chip_rail.dart';
import 'lucky16_layout.dart';
import 'lucky16_readouts.dart';
import 'lucky16_readouts_binding.dart';
import 'lucky16_top_bar_binding.dart';

/// What the chip row shows.
@immutable
class Lucky16ChipRailSnapshot {
  const Lucky16ChipRailSnapshot({required this.activeChip, required this.isLocked});

  factory Lucky16ChipRailSnapshot.of(Lucky16Provider p) =>
      Lucky16ChipRailSnapshot(activeChip: p.activeChip, isLocked: p.isLocked);

  final Lucky16Chip? activeChip;
  final bool isLocked;

  @override
  bool operator ==(Object other) =>
      other is Lucky16ChipRailSnapshot && other.activeChip == activeChip && other.isLocked == isLocked;

  @override
  int get hashCode => Object.hash(activeChip, isLocked);
}

/// What the three buttons show.
@immutable
class Lucky16ButtonsSnapshot {
  const Lucky16ButtonsSnapshot({
    required this.isLocked,
    required this.hasBets,
    required this.showRebet,
    required this.canAffordRebet,
  });

  factory Lucky16ButtonsSnapshot.of(Lucky16Provider p) => Lucky16ButtonsSnapshot(
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
      other is Lucky16ButtonsSnapshot &&
      other.isLocked == isLocked &&
      other.hasBets == hasBets &&
      other.showRebet == showRebet &&
      other.canAffordRebet == canAffordRebet;

  @override
  int get hashCode => Object.hash(isLocked, hasBets, showRebet, canAffordRebet);
}

/// The chip row, linked to the provider.
class Lucky16ChipRailBinding extends StatelessWidget {
  const Lucky16ChipRailBinding({
    super.key,
    required this.provider,
    required this.layout,
    required this.art,
    this.onChipSelected,
  });

  final Lucky16Provider provider;
  final Lucky16Layout layout;
  final Lucky16Art art;

  /// A chip was picked up (for the click sound, a later phase).
  final void Function(Lucky16Chip chip)? onChipSelected;

  @override
  Widget build(BuildContext context) {
    return Lucky16Selector<Lucky16ChipRailSnapshot>(
      provider: provider,
      select: Lucky16ChipRailSnapshot.of,
      builder: (context, s) => Lucky16ChipRail(
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
class Lucky16ActionButtonsBinding extends StatelessWidget {
  const Lucky16ActionButtonsBinding({
    super.key,
    required this.provider,
    required this.layout,
    this.zone,
    this.onPressed,
    this.onRefused,
  });

  final Lucky16Provider provider;
  final Lucky16Layout layout;

  /// The canvas zone the buttons are placed in. Null means the bet panel; the desktop passes its bottom
  /// bar, [Lucky16Layout.actionBar].
  final Rect? zone;

  /// A button was accepted (for the click sound, a later phase).
  final void Function(Lucky16Control control)? onPressed;

  /// A button could not do all it was asked, and why.
  final Lucky16ControlRefused? onRefused;

  @override
  Widget build(BuildContext context) {
    final side = zone ?? layout.side;
    return Lucky16Selector<Lucky16ButtonsSnapshot>(
      provider: provider,
      select: Lucky16ButtonsSnapshot.of,
      builder: (context, s) {
        Widget button(int slot, Lucky16Control control, bool enabled, Lucky16BoardResult Function() action) {
          final rect = layout.actionButton(slot);
          return Positioned.fromRect(
            rect: layout.within(side, rect),
            child: Lucky16ActionButton(
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
                ? button(0, Lucky16Control.rebet, s.canAffordRebet, provider.rebet)
                : button(0, Lucky16Control.doubleBet, s.hasBets, provider.doubleBet),
            button(1, Lucky16Control.clear, s.hasBets, provider.clearBoard),
            button(2, Lucky16Control.remove, s.hasBets, () {
              provider.deselectChip();
              return const Lucky16BoardResult();
            }),
          ],
        );
      },
    );
  }
}

/// The tablet's chip bar, under the board: the same purple box as the bet panel with the five chips
/// centred in it. On a phone the chips are in the panel, so this is not used there.
class Lucky16ChipBar extends StatelessWidget {
  const Lucky16ChipBar({
    super.key,
    required this.provider,
    required this.layout,
    required this.art,
    this.onChipSelected,
  });

  final Lucky16Provider provider;
  final Lucky16Layout layout;
  final Lucky16Art art;
  final void Function(Lucky16Chip chip)? onChipSelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: Lucky16BetPanelFrame(key: const ValueKey('chip-bar'), radius: layout.panelRadius)),
        Positioned.fromRect(
          rect: layout.within(layout.chipBar, layout.chipRail),
          child: Lucky16ChipRailBinding(provider: provider, layout: layout, art: art, onChipSelected: onChipSelected),
        ),
      ],
    );
  }
}

/// The whole bet panel: its frame, PLAY | WIN, the results, the three buttons and, on a phone, the chip
/// row (on a tablet the chips are in [Lucky16ChipBar]).
class Lucky16SideColumn extends StatelessWidget {
  const Lucky16SideColumn({
    super.key,
    required this.provider,
    required this.layout,
    required this.art,
    this.onChipSelected,
    this.onButtonPressed,
    this.onButtonRefused,
  });

  final Lucky16Provider provider;
  final Lucky16Layout layout;
  final Lucky16Art art;
  final void Function(Lucky16Chip chip)? onChipSelected;
  final void Function(Lucky16Control control)? onButtonPressed;
  final Lucky16ControlRefused? onButtonRefused;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: Lucky16BetPanelFrame(key: const ValueKey('bet-panel'), radius: layout.panelRadius)),
        Positioned.fill(child: Lucky16SideReadouts(provider: provider, layout: layout, art: art)),
        if (!layout.isTablet)
          Positioned.fromRect(
            rect: layout.within(layout.side, layout.chipRail),
            child: Lucky16ChipRailBinding(provider: provider, layout: layout, art: art, onChipSelected: onChipSelected),
          ),
        Positioned.fill(
          child: Lucky16ActionButtonsBinding(
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

/// Loads the chips, the suit icons and the history-card frames into the image cache before the screen
/// shows.
Future<void> precacheLucky16SideColumn(BuildContext context, Lucky16Layout layout, Lucky16Art art) =>
    Future.wait([precacheLucky16Chips(context, layout, art), precacheLucky16Results(context, layout, art)]);
