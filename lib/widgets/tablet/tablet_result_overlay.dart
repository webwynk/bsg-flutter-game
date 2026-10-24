import 'package:flutter/material.dart';
import '../overlays/result_overlay.dart';
import 'scaled_box.dart';
import 'tablet_game_layout.dart';

/// The win popup for the tablet game screen: the phone's `ResultOverlay`
/// (same card, same numbers, same animation, still centered on the whole
/// screen) drawn bigger, so the card is in proportion to the larger screen.
class TabletResultOverlay extends StatelessWidget {
  const TabletResultOverlay({super.key});

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
          child: const ResultOverlay(),
        );
      },
    );
  }
}
