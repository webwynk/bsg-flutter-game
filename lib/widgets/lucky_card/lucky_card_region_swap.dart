// The in-place swap of spec §7.4 (Q41): at the lock, the two regions beside the side
// column change, and nothing else moves.
//
//   betting open:    the board in the big region, the rank selectors in the column
//   betting closed:  the wheel in the big region, the card column in the column
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
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import '../../providers/lucky_card_provider.dart';
import 'lucky_card_readouts_binding.dart';

class LuckyCardRegionSwap extends StatelessWidget {
  const LuckyCardRegionSwap({
    super.key,
    required this.provider,
    required this.betting,
    required this.reveal,
  });

  final LuckyCardProvider provider;

  /// What shows while betting is open.
  final WidgetBuilder betting;

  /// What shows while betting is closed.
  final WidgetBuilder reveal;

  /// How long the cross-fade takes.
  static const Duration fade = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    return LuckyCardSelector<bool>(
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
