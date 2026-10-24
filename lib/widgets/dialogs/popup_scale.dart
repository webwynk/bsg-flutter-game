import 'package:flutter/widgets.dart';
import '../../utils/device_type.dart';
import '../desktop/desktop_game_layout.dart';
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
