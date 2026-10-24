// The purple box the right-hand rows sit on (the reference design's bet panel): a vertical
// purple gradient, a 2 dp gold border, rounded corners, and a hard shadow under it with a soft
// one behind that. Drawn in code, no picture. The tablet's chip bar under the board is the same box
// (its own size), so it is drawn by this too.
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import 'lucky_card_layout.dart';
import 'lucky_card_palette.dart';

class LuckyCardBetPanelFrame extends StatelessWidget {
  /// [radius] is the corner: [LuckyCardLayout.panelRadius] (18 dp on a phone, 22 dp on a tablet).
  const LuckyCardBetPanelFrame({super.key, this.radius = LuckyCardLayout.designPanelRadius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: kDesignPanelFill),
        boxShadow: const [
          BoxShadow(color: kDesignPanelUnder, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x73000000), offset: Offset(0, 8), blurRadius: 16),
        ],
      ),
      // The border is drawn over the content's edge, so it never insets what is inside.
      position: DecorationPosition.background,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          border: const Border.fromBorderSide(BorderSide(color: kDesignBarRim, width: LuckyCardLayout.designPanelBorder)),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
