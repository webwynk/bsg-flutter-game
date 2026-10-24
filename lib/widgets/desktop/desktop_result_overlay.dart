import 'package:flutter/material.dart';
import '../overlays/result_overlay.dart';
import '../tablet/scaled_box.dart';
import 'desktop_game_layout.dart';

/// The win popup for the desktop game screen: the phone's `ResultOverlay` (same
/// card, same numbers, same animation, still centred on the whole window) drawn
/// `DesktopGameLayout.overlayScale` times bigger, so the card is in proportion
/// to the scaled desktop layout in any window size.
class DesktopResultOverlay extends StatelessWidget {
  const DesktopResultOverlay({super.key});

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
          child: const ResultOverlay(),
        );
      },
    );
  }
}
