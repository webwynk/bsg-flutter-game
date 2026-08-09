import 'dart:io' show Platform;
import 'package:flutter/widgets.dart';

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
