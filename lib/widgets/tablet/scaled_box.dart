import 'package:flutter/material.dart';

/// Lays [child] out at a fixed design size ([designWidth] x [designHeight]) and
/// draws it enlarged by [scale], so this box takes up
/// `designWidth * scale` x `designHeight * scale` on screen.
///
/// Used by the tablet game screen to reuse the verified phone widgets unchanged:
/// they are laid out at the phone-sized space they were designed for, then
/// drawn bigger. Everything inside (text, images, shadows, hit areas) grows by
/// the same factor, so touches land where they are drawn.
///
/// Inside the box, `MediaQuery.size` reports the design size (not the real
/// screen), because some phone widgets read it to work out their own widths.
class ScaledBox extends StatelessWidget {
  final double designWidth;
  final double designHeight;
  final double scale;
  final Widget child;

  const ScaledBox({
    super.key,
    required this.designWidth,
    required this.designHeight,
    required this.scale,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final designSize = Size(designWidth, designHeight);
    return SizedBox(
      width: designWidth * scale,
      height: designHeight * scale,
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: designWidth,
          height: designHeight,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(size: designSize),
            child: child,
          ),
        ),
      ),
    );
  }
}
