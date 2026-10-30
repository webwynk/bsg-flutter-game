import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart';

/// True for a screen big enough for the tablet arrangement of the Triple
/// Chance game screen: at least 600dp on the shorter side (Android's own
/// tablet breakpoint; the biggest phones are about 430dp) and at least 800dp
/// on the longer side (so an odd near-square screen stays on the phone
/// arrangement). Landscape or portrait does not matter. Same rule the Lucky
/// Card screen uses for its own tablet arrangement.
bool isTabletScreen(Size screen) =>
    math.min(screen.width, screen.height) >= 600 && math.max(screen.width, screen.height) >= 800;

/// True for a screen big enough for the desktop arrangement of the Triple
/// Chance game screen (all three boards on screen at once): at least 1280dp
/// wide and 720dp high, in logical pixels. Checked before [isTabletScreen], so
/// a big tablet or an emulator window of this size gets the desktop layout.
/// Same threshold the Lucky Card screen uses for its own desktop arrangement.
bool isDesktopScreen(Size screen) => screen.width >= 1280 && screen.height >= 720;

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

/// Which arrangement the splash and login screens use. Decided from the device
/// itself, so it does not change when the screen turns.
enum LoginDeviceKind { phone, tablet, desktop }

/// The rule behind [loginDeviceKind], with its inputs passed in.
///
/// Windows, macOS and Linux are always desktop. Android, iOS and web go by the
/// shorter side of the screen in dp: under 600 is a phone, 600 or more a
/// tablet, the same 600 the games use. A size of zero, which a device can
/// report before its first frame, counts as a phone, so nothing changes for a
/// phone while the size is still unknown.
LoginDeviceKind classifyLoginDevice({
  required bool isWeb,
  required TargetPlatform platform,
  required Size logicalSize,
}) {
  if (!isWeb &&
      (platform == TargetPlatform.windows ||
          platform == TargetPlatform.macOS ||
          platform == TargetPlatform.linux)) {
    return LoginDeviceKind.desktop;
  }
  return logicalSize.shortestSide >= 600 ? LoginDeviceKind.tablet : LoginDeviceKind.phone;
}

/// The kind of device this app is running on. Reads the view directly so it
/// works before any screen exists (from main()) and in any orientation, and
/// uses [defaultTargetPlatform] rather than dart:io so it is safe on web.
LoginDeviceKind loginDeviceKind() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  final view = views.isEmpty ? null : views.first;
  final size = view == null ? Size.zero : view.physicalSize / view.devicePixelRatio;
  return classifyLoginDevice(isWeb: kIsWeb, platform: defaultTargetPlatform, logicalSize: size);
}

/// The screen directions for the splash and login screens: portrait on a phone
/// (as it has always been), landscape on a tablet or desktop.
List<DeviceOrientation> loginOrientations(LoginDeviceKind kind) => kind == LoginDeviceKind.phone
    ? const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
    : const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];
