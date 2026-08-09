import 'dart:io' show Platform, exit;
import 'package:flutter/services.dart';

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
