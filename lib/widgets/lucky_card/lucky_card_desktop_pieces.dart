// The two desktop-only pieces (spec §17BP, step D2) that have no phone or tablet twin:
//
//   * [LuckyCardDesktopSide]: the wheel's column at the left. The wheel is ALWAYS on screen (betting
//     open or closed) with the mystery gift box in its hub, and PLAY and WIN are at the bottom of the
//     column, as wide as the wheel. On a phone and a tablet this zone is the bet panel instead
//     ([LuckyCardSideColumn]) and the wheel only takes the board's place while betting is closed.
//   * [LuckyCardActionBar]: the bar at the bottom of the right column holding the five chips at its
//     left and DOUBLE (or REBET), CLEAR and REMOVE in a row to their right. It is the same purple box
//     as the bet panel and the tablet's chip bar.
//
// The results row is [LuckyCardResultsBarBinding] (lucky_card_readouts_binding.dart); the board and
// the rank selectors are the ordinary ones, left in place and dimmed by their own lock while betting
// is closed (no wheel replaces them and no card flips over the rank column on the desktop).
//
//   LuckyCardCanvas(
//     layoutOf: (screen) => LuckyCardLayout.of(screen, desktopPlatform: true),
//     side: (context, layout) => LuckyCardDesktopSide(provider: p, layout: layout, art: art),
//     resultsBar: (context, layout) => LuckyCardResultsBarBinding(provider: p, layout: layout, art: art),
//     actionBar: (context, layout) => LuckyCardActionBar(provider: p, layout: layout, art: art),
//   )
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky_card_board.dart';
import '../../providers/lucky_card_provider.dart';
import 'lucky_card_action_buttons.dart';
import 'lucky_card_art.dart';
import 'lucky_card_bet_panel.dart';
import 'lucky_card_controls_binding.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_readouts_binding.dart';
import 'lucky_card_wheel_binding.dart';

/// The desktop's wheel column: the permanent wheel, with PLAY and WIN under it.
class LuckyCardDesktopSide extends StatelessWidget {
  const LuckyCardDesktopSide({
    super.key,
    required this.provider,
    required this.layout,
    required this.art,
    this.onSpinStart,
    this.onRankLanded,
  });

  final LuckyCardProvider provider;
  final LuckyCardLayout layout;
  final LuckyCardArt art;

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
          child: LuckyCardWheelBinding(
            provider: provider,
            layout: layout,
            zone: layout.side,
            permanent: true,
            onSpinStart: onSpinStart,
            onRankLanded: onRankLanded,
          ),
        ),
        Positioned.fill(child: LuckyCardSideReadouts(provider: provider, layout: layout, art: art)),
      ],
    );
  }
}

/// The desktop's bottom bar: the purple box with the five chips at the left and the three buttons in a
/// row at the right.
class LuckyCardActionBar extends StatelessWidget {
  const LuckyCardActionBar({
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
    final bar = layout.actionBar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: LuckyCardBetPanelFrame(radius: layout.panelRadius)),
        Positioned.fromRect(
          rect: layout.within(bar, layout.chipRail),
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
            zone: bar,
            onPressed: onButtonPressed,
            onRefused: onButtonRefused,
          ),
        ),
      ],
    );
  }
}
