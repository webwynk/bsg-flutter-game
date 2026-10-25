// The full-width bar at the bottom of a game screen: Triple Chance's PLAY LIMIT REACHED and
// "balance sync failed" bars, Lucky Card's CARD PLAY LIMIT REACHED bar and Spin2Win's two bars
// all use it, so they look and behave the same in every game.
//
//   ScaffoldMessenger.of(context).showSnackBar(gameBottomBanner(
//     icon: Icons.warning_amber_rounded, text: 'PLAY LIMIT REACHED', detail: 'Max 10,000 / number', ...));
//
//   * Edge to edge (Hasan's phone test, 2026-10-25): a Material SnackBar keeps itself clear of the
//     phone's camera cut-out and system bars, which left a blank strip at the side of the games
//     (they draw edge to edge). The bar's background now reaches the screen's edges; its icon and
//     words stay clear of the cut-out.
//   * Sized for the device: about 44 dp tall on a phone (it was 36), 1.3 times that on a tablet
//     and 1.5 times on a desktop, using the same tablet and desktop rules as Triple Chance
//     (utils/device_type.dart).
//
// Shared by every game: change it only with Hasan's OK.

import 'package:flutter/material.dart';

import '../../utils/device_type.dart';

/// How much bigger the bar is drawn on this screen: 1 on a phone, 1.3 on a tablet, 1.5 on a
/// desktop.
double gameBottomBannerScale(Size screen) {
  if (isDesktopScreen(screen)) return 1.5;
  if (isTabletScreen(screen)) return 1.3;
  return 1;
}

/// The bar as a SnackBar, ready for `ScaffoldMessenger.showSnackBar`.
///
/// [gradient] runs left to right behind the bar, [edge] is the thin line on top and [glow] the
/// soft shadow above it. [detail], when given, is written in white on the right.
SnackBar gameBottomBanner({
  Key? key,
  required IconData icon,
  required String text,
  String? detail,
  required Color iconColor,
  required Color textColor,
  required List<Color> gradient,
  required Color edge,
  required Color glow,
  FontWeight textWeight = FontWeight.w900,
  double letterSpacing = 1.2,
  required Duration duration,
}) {
  return SnackBar(
    key: key,
    backgroundColor: Colors.transparent,
    elevation: 0,
    behavior: SnackBarBehavior.fixed,
    padding: EdgeInsets.zero,
    duration: duration,
    content: GameBottomBannerBar(
      icon: icon,
      text: text,
      detail: detail,
      iconColor: iconColor,
      textColor: textColor,
      gradient: gradient,
      edge: edge,
      glow: glow,
      textWeight: textWeight,
      letterSpacing: letterSpacing,
    ),
  );
}

/// What [gameBottomBanner] shows (also usable on its own).
class GameBottomBannerBar extends StatelessWidget {
  const GameBottomBannerBar({
    super.key,
    required this.icon,
    required this.text,
    this.detail,
    required this.iconColor,
    required this.textColor,
    required this.gradient,
    required this.edge,
    required this.glow,
    this.textWeight = FontWeight.w900,
    this.letterSpacing = 1.2,
  });

  final IconData icon;
  final String text;
  final String? detail;
  final Color iconColor;
  final Color textColor;
  final List<Color> gradient;
  final Color edge;
  final Color glow;
  final FontWeight textWeight;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final s = gameBottomBannerScale(MediaQuery.sizeOf(context));
    // The SnackBar has already kept this bar clear of the screen's insets (and removed them from
    // the MediaQuery here), so they are read from the window itself.
    final view = View.of(context);
    final insets = EdgeInsets.fromViewPadding(view.padding, view.devicePixelRatio);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The background reaches out over the insets to the screen's edges.
        Positioned(
          left: -insets.left,
          right: -insets.right,
          top: 0,
          bottom: -insets.bottom,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient, begin: Alignment.centerLeft, end: Alignment.centerRight),
              border: Border(top: BorderSide(color: edge, width: 2.0)),
              boxShadow: [BoxShadow(color: glow, blurRadius: 10, spreadRadius: 1, offset: const Offset(0, -2))],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(14 * s, 2 + 10 * s, 14 * s, 10 * s),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22 * s),
              SizedBox(width: 8 * s),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12 * s,
                    fontWeight: textWeight,
                    letterSpacing: letterSpacing,
                  ),
                ),
              ),
              if (detail != null) ...[
                SizedBox(width: 8 * s),
                Text(
                  detail!,
                  style: TextStyle(color: Colors.white, fontSize: 12 * s, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
