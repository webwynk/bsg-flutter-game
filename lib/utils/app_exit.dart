import 'dart:io' show Platform, exit;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Set true right before any flow is about to force a full logout + close
/// (e.g. the away-too-long popup in main.dart). Lets other popups that react
/// to their own independent triggers -- the connection-lost dialog in
/// game_screen.dart reacts to RoundSyncService, not to this -- check this
/// first and skip showing themselves redundantly right as the app is
/// already on its way out. Reset back to false once the closing flow
/// actually completes (or is abandoned), so a later, unrelated disconnect
/// isn't permanently suppressed by an old flag.
final ValueNotifier<bool> isClosingApp = ValueNotifier(false);

/// Closes the app outright rather than returning to any in-app screen.
///
/// This app is not distributed through the App Store/Play Store, so the
/// usual "never let an app quit itself" guideline doesn't apply here.
/// SystemNavigator.pop() is the correct, standard way to exit on Android
/// (properly signals the OS to tear the activity down); it has documented,
/// limited effect on iOS, where dart:io's exit() is the reliable way to
/// actually terminate the process.
///
/// Shared by the connection-lost popup (game_screen.dart) and the
/// blocked-account popup (login_screen.dart) -- one implementation instead
/// of two copies drifting apart.
void closeApp() {
  if (Platform.isIOS) {
    exit(0);
  } else {
    SystemNavigator.pop();
  }
}
