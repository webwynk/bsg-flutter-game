// The two desktop-only pieces of the Lucky 16 Card screen, which have no phone or tablet twin. Copied from
// lib/widgets/lucky_card/lucky_card_desktop_pieces.dart (Lucky Card); only the names changed.
//
//   * [Lucky16DesktopSide]: the wheel's column at the left. The wheel is ALWAYS on screen (betting open or
//     closed) and PLAY and WIN are at the bottom of the column, as wide as the wheel. On a phone and a
//     tablet this zone is the bet panel instead, and the wheel only takes the board's place while betting
//     is closed.
//   * [Lucky16ActionBar]: the bar at the bottom of the right column holding the five chips at its left and
//     DOUBLE (or REBET), CLEAR and REMOVE in a row to their right. It is the same purple box as the bet
//     panel and the tablet's chip bar.
//
// The results row is [Lucky16ResultsBarBinding]; the board and the rank selectors are the ordinary ones,
// left in place and dimmed by their own lock while betting is closed.
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky16_board.dart';
import '../../providers/lucky16_provider.dart';
import 'lucky16_action_buttons.dart';
import 'lucky16_art.dart';
import 'lucky16_bet_panel.dart';
import 'lucky16_controls_binding.dart';
import 'lucky16_layout.dart';
import 'lucky16_readouts_binding.dart';
import 'lucky16_wheel_binding.dart';

/// The desktop's wheel column: the permanent wheel, with PLAY and WIN under it.
class Lucky16DesktopSide extends StatelessWidget {
  const Lucky16DesktopSide({
    super.key,
    required this.provider,
    required this.layout,
    required this.art,
    this.onSpinStart,
    this.onRankLanded,
  });

  final Lucky16Provider provider;
  final Lucky16Layout layout;
  final Lucky16Art art;

  /// Both rims begin to turn (the spin sound starts here).
  final VoidCallback? onSpinStart;

  /// The outer rim has stopped: the first "ding".
  final VoidCallback? onRankLanded;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Lucky16WheelBinding(
            provider: provider,
            layout: layout,
            zone: layout.side,
            permanent: true,
            onSpinStart: onSpinStart,
            onRankLanded: onRankLanded,
          ),
        ),
        Positioned.fill(child: Lucky16SideReadouts(provider: provider, layout: layout, art: art)),
      ],
    );
  }
}

/// The desktop's bottom bar: the purple box with the five chips at the left and the three buttons in a
/// row at the right.
class Lucky16ActionBar extends StatelessWidget {
  const Lucky16ActionBar({
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
    final bar = layout.actionBar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: Lucky16BetPanelFrame(key: const ValueKey('action-bar'), radius: layout.panelRadius)),
        Positioned.fromRect(
          rect: layout.within(bar, layout.chipRail),
          child: Lucky16ChipRailBinding(provider: provider, layout: layout, art: art, onChipSelected: onChipSelected),
        ),
        Positioned.fill(
          child: Lucky16ActionButtonsBinding(
            provider: provider,
            layout: layout,
            zone: bar,
            onPressed: onButtonPressed,
            onRefused: onButtonRefused,
          ),
        ),
      ],
    );
  }
}
