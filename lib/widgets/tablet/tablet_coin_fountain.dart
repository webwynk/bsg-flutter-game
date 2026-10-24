import 'package:flutter/material.dart';
import '../overlays/coin_fountain.dart';
import 'scaled_box.dart';
import 'tablet_game_layout.dart';

/// The big-win coin fountain for the tablet game screen. Same fountain as the
/// phone's (`CoinFountain`, 60 coins a second, playing as soon as it appears),
/// with two differences for a tablet: it bursts from the middle of the wheel
/// (the phone works that out from its own 158px tab strip and 28% panel), and
/// it is drawn bigger, so the coins and their arch are in proportion to the
/// larger wheel.
class TabletCoinFountain extends StatelessWidget {
  const TabletCoinFountain({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = Size(constraints.maxWidth, constraints.maxHeight);
        final k = TabletGameLayout.overlayScale(screen);
        return ScaledBox(
          designWidth: screen.width / k,
          designHeight: screen.height / k,
          scale: k,
          child: CoinFountain(
            autoPlay: true,
            coinsPerSecond: 60,
            originFraction: Offset(TabletGameLayout.wheelCenterX(screen), 0.5),
          ),
        );
      },
    );
  }
}
