import 'package:flutter/material.dart';
import '../overlays/coin_fountain.dart';
import '../tablet/scaled_box.dart';
import 'desktop_game_layout.dart';

/// The big-win coin fountain for the desktop game screen. The same fountain as
/// the phone's and tablet's (`CoinFountain`, 60 coins a second, playing as soon
/// as it appears), with two differences: it bursts from the middle of the
/// desktop wheel (`DesktopGameLayout.wheelCenterFraction`, which follows the
/// layout when the window is scaled and centred), and it is drawn
/// `DesktopGameLayout.overlayScale` times bigger, so the coins and their arch
/// stay in proportion to the wheel in any window size.
class DesktopCoinFountain extends StatelessWidget {
  const DesktopCoinFountain({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = Size(constraints.maxWidth, constraints.maxHeight);
        final k = DesktopGameLayout.overlayScale(screen);
        return ScaledBox(
          designWidth: screen.width / k,
          designHeight: screen.height / k,
          scale: k,
          child: CoinFountain(
            autoPlay: true,
            coinsPerSecond: 60,
            originFraction: DesktopGameLayout.wheelCenterFraction(screen),
          ),
        );
      },
    );
  }
}
