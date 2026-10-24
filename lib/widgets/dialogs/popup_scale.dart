import 'package:flutter/widgets.dart';
import '../../utils/device_type.dart';
import '../desktop/desktop_game_layout.dart';
import '../tablet/scaled_box.dart';
import '../tablet/tablet_game_layout.dart';

/// How much bigger than on the phone a Triple Chance popup is drawn on a
/// screen of this size: 1.0 on a phone, the tablet layout's win-popup scale on
/// a tablet-sized screen, and the desktop layout's win-popup scale on a
/// desktop-sized window (the desktop rule is checked first, as in
/// `GameScreen`). The same numbers the win popup and the coin fountain use, so
/// every popup grows with the layout it sits over.
double popupScaleFor(Size screen) {
  if (isDesktopScreen(screen)) return DesktopGameLayout.overlayScale(screen);
  if (isTabletScreen(screen)) return TabletGameLayout.overlayScale(screen);
  return 1.0;
}

/// Draws a whole-screen popup page bigger on tablet and desktop-sized screens,
/// for popups that size themselves from `MediaQuery` (the Info popup): the
/// child is laid out at the screen size divided by [popupScaleFor] (so it picks
/// the same widths and heights it would on a smaller screen) and enlarged by
/// that factor, text and touch areas with it, the way the win popup is. On a
/// phone the scale is 1.0 and the child is returned as it is.
///
/// Meant for the page of a `showGeneralDialog`, which is given the whole screen.
class ScaledPopup extends StatelessWidget {
  final Widget child;
  const ScaledPopup({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = Size(constraints.maxWidth, constraints.maxHeight);
        final k = popupScaleFor(screen);
        if (k == 1.0) return child;
        return ScaledBox(
          designWidth: screen.width / k,
          designHeight: screen.height / k,
          scale: k,
          child: child,
        );
      },
    );
  }
}
