// The in-place swap (Lucky Card spec §7.4, Q41): at the lock, the two regions beside the bet panel
// change, and nothing else moves. Copied from lib/widgets/lucky_card/lucky_card_region_swap.dart
// (Lucky Card); only the names changed.
//
//   betting open:    the board in the big region, the rank selectors in the column
//   betting closed:  the wheel in the big region, the reveal card (right of the wheel) from the column
//
// "Closed" is the provider's own lock: it starts at countdown 5, stays through the
// spin, the card, the win and the gap before the next round, and ends when the next
// round opens, so the board comes back exactly when chips can be placed again. A screen
// that opens while the table is closed starts with the wheel.
//
// Each side is built only while it is shown, so the wheel and the card column start
// fresh at every lock. The change is a short cross-fade (the phone's "reduce motion"
// setting makes it instant).
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import '../../providers/lucky16_provider.dart';
import 'lucky16_top_bar_binding.dart';

class Lucky16RegionSwap extends StatelessWidget {
  const Lucky16RegionSwap({
    super.key,
    required this.provider,
    required this.betting,
    required this.reveal,
  });

  final Lucky16Provider provider;

  /// What shows while betting is open.
  final WidgetBuilder betting;

  /// What shows while betting is closed.
  final WidgetBuilder reveal;

  /// How long the cross-fade takes.
  static const Duration fade = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    return Lucky16Selector<bool>(
      provider: provider,
      select: (p) => p.isLocked,
      builder: (context, closed) => AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : fade,
        child: KeyedSubtree(
          key: ValueKey(closed ? 'region-reveal' : 'region-betting'),
          child: closed ? reveal(context) : betting(context),
        ),
      ),
    );
  }
}
