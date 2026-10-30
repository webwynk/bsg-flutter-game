// The purple box the right-hand rows sit on (the reference design's bet panel): a vertical
// purple gradient, a 2 dp gold border, rounded corners, and a hard shadow under it with a soft
// one behind that. Drawn in code, no picture. The tablet's chip bar under the board is the same box.
// (Its look is Lucky Card's phone panel.)
//
// Copied from lib/widgets/lucky_card/lucky_card_bet_panel.dart (Lucky Card); the names changed, and it is
// the phone arrangement only.
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import 'lucky16_layout.dart';
import 'lucky16_palette.dart';

class Lucky16BetPanelFrame extends StatelessWidget {
  /// [radius] is the corner: [Lucky16Layout.panelRadius] (18 dp on a phone, 22 dp on a tablet).
  const Lucky16BetPanelFrame({super.key, this.radius = Lucky16Layout.designPanelRadius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        gradient:
            const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: kLucky16PanelFill),
        boxShadow: const [
          BoxShadow(color: kLucky16PanelUnder, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x73000000), offset: Offset(0, 8), blurRadius: 16),
        ],
      ),
      // The border is drawn over the content's edge, so it never insets what is inside.
      position: DecorationPosition.background,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          border:
              const Border.fromBorderSide(BorderSide(color: kLucky16BarRim, width: Lucky16Layout.designPanelBorder)),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
