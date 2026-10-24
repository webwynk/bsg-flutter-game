// Whether the app is running as a desktop program or in a web browser. The real app no longer asks:
// since 2026-10-25 its default setup passes `desktopPlatform: true`, so the Lucky Card desktop
// arrangement is chosen by screen size alone (at least 1280 x 720 dp, [LuckyCardLayout.isDesktopScreen]),
// like Triple Chance, which also lets an Android emulator on a desktop (BlueStacks) get it. This answer
// is only the fallback for a screen set up without `desktopPlatform` (the tests): Windows, macOS, Linux
// and the web say yes; Android and iOS say no.
//
// Uses only `kIsWeb` and `defaultTargetPlatform` (not dart:io), so it also works in a browser.
//
// Belongs to Lucky Card only.

import 'package:flutter/foundation.dart';

/// True on the web and on Windows, macOS and Linux; false on Android, iOS and Fuchsia. A test chooses
/// the platform with `debugDefaultTargetPlatformOverride` (a test's `kIsWeb` is always false).
bool luckyCardRunsOnDesktop() {
  if (kIsWeb) return true;
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
    TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => false,
  };
}
