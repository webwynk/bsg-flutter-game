import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/desktop_window.dart';

/// Keeps the desktop layouts on small laptop windows. In the Windows app, a
/// window smaller than 1280 x 720 draws the whole app at a design size of at
/// least 1280 x 720 and shrinks it to fit, so every screen and every game still
/// sees a desktop-sized screen instead of falling back to its tablet layout.
///
/// Anywhere else, and in a window that is big enough, it returns [child] as it
/// is. It also does so for a window with no size, as when minimised.
class DesktopFitBox extends StatelessWidget {
  final Widget child;

  const DesktopFitBox({super.key, required this.child});

  /// How much the app shrinks in a [window]: 1 when it already fits.
  static double scaleFor(Size window) => math.min(
        1.0,
        math.min(window.width / kDesktopDesignSize.width, window.height / kDesktopDesignSize.height),
      );

  @override
  Widget build(BuildContext context) {
    if (!isWindowsApp) return child;
    final media = MediaQuery.of(context);
    final window = media.size;
    if (window.isEmpty) return child;
    final scale = scaleFor(window);
    if (scale >= 1) return child;
    final design = window / scale;
    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: design.width,
        height: design.height,
        child: MediaQuery(
          data: media.copyWith(size: design, devicePixelRatio: media.devicePixelRatio * scale),
          child: child,
        ),
      ),
    );
  }
}
