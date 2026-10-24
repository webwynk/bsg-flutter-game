import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// True for a screen big enough for the tablet arrangement of the Triple
/// Chance game screen: at least 600dp on the shorter side (Android's own
/// tablet breakpoint; the biggest phones are about 430dp) and at least 800dp
/// on the longer side (so an odd near-square screen stays on the phone
/// arrangement). Landscape or portrait does not matter. Same rule the Lucky
/// Card screen uses for its own tablet arrangement.
bool isTabletScreen(Size screen) =>
    math.min(screen.width, screen.height) >= 600 && math.max(screen.width, screen.height) >= 800;

/// True only for a phone-sized Android/iOS device.
///
/// Two conditions, not one: the OS check alone would still say true on a
/// tablet (an iPad or Android tablet runs the same OS as a phone) and would
/// fire on desktop platforms once this app supports them. The shortest-side
/// check (600dp is the standard Android/Material breakpoint) is what
/// actually distinguishes "phone" from "tablet" -- both matter, since this
/// app's future plan is desktop/laptop/tablet as their own layouts, not
/// just "not a phone."
bool isMobilePhone(BuildContext context) {
  final isPhoneOs = Platform.isAndroid || Platform.isIOS;
  if (!isPhoneOs) return false;
  return MediaQuery.of(context).size.shortestSide < 600;
}
