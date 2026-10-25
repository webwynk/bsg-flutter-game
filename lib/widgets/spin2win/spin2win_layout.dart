// The three boards of the reference design (screens Phase 7): the phone (844 x 390), the tablet
// (1180 x 820) and the laptop / desktop (1920 x 1080). The tablet and desktop boards are the
// phone's own pieces, enlarged as the design enlarges them (its CSS `zoom`): the top bar and the
// history strip by 1.45 (tablet) or 1.9 (desktop), the wheel by 2 or 2.7, and a taller betting
// panel ([Spin2WinPanelMetrics.tablet] / [.desktop]) by 1.15 or 1.6. The YOU WIN and records
// popups are enlarged as the top bar is, the coin burst by 1.5 or 2.
//
//   * [Spin2WinLayout.forScreen] picks the board: a phone-sized screen (shorter side under 600 dp)
//     gets the phone board; a bigger one gets the tablet board when it is squarer than 16:10,
//     the desktop board otherwise.
//   * Each board is laid out at its design height and between its [minWidth] and [maxWidth]
//     wide (the betting panel takes up the difference), then scaled to the screen.
//   * [Spin2WinLayoutScope] hands the chosen board and its laid-out size to the frame and the
//     effects drawn over it.
//
// Belongs to Spin2Win only.

import 'package:flutter/widgets.dart';

import 'spin2win_bet_panel.dart';

enum Spin2WinLayout {
  phone(
    height: 390,
    minWidth: 760,
    maxWidth: 940,
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    gap: 6,
    barZoom: 1,
    barSidePadding: 30,
    wheelZoom: 1,
    bodyGap: 10,
    panelZoom: 1,
    panel: Spin2WinPanelMetrics.phone,
    burstZoom: 1,
    popupZoom: 1,
  ),
  tablet(
    height: 820,
    minWidth: 1120,
    maxWidth: 1312,
    padding: EdgeInsets.all(16),
    gap: 12,
    barZoom: 1.45,
    barSidePadding: 21,
    wheelZoom: 2,
    bodyGap: 16,
    panelZoom: 1.15,
    panel: Spin2WinPanelMetrics.tablet,
    burstZoom: 1.5,
    popupZoom: 1.45,
  ),
  desktop(
    height: 1080,
    minWidth: 1728,
    maxWidth: 2100,
    padding: EdgeInsets.all(28),
    gap: 18,
    barZoom: 1.9,
    barSidePadding: 0,
    wheelZoom: 2.7,
    bodyGap: 24,
    panelZoom: 1.6,
    panel: Spin2WinPanelMetrics.desktop,
    burstZoom: 2,
    popupZoom: 1.9,
  );

  const Spin2WinLayout({
    required this.height,
    required this.minWidth,
    required this.maxWidth,
    required this.padding,
    required this.gap,
    required this.barZoom,
    required this.barSidePadding,
    required this.wheelZoom,
    required this.bodyGap,
    required this.panelZoom,
    required this.panel,
    required this.burstZoom,
    required this.popupZoom,
  });

  /// The design height everything is laid out at.
  final double height;

  /// The narrowest and widest the board is laid out; a screen of another shape gets background
  /// above and below, or at the sides.
  final double minWidth;
  final double maxWidth;

  /// Around the board, and between the top bar, the body and the history strip.
  final EdgeInsets padding;
  final double gap;

  /// How much the top bar and the history strip are enlarged, and the top bar's own side padding
  /// (in its unenlarged units).
  final double barZoom;
  final double barSidePadding;

  /// How much the wheel is enlarged (tablet and desktop: the 280 x 300 wheel box).
  final double wheelZoom;

  /// Between the wheel and the betting panel.
  final double bodyGap;

  /// How much the betting panel is enlarged, and its inner sizes.
  final double panelZoom;
  final Spin2WinPanelMetrics panel;

  /// How much the coin burst and the popups (YOU WIN, records, exit) are enlarged.
  final double burstZoom;
  final double popupZoom;

  /// Screens whose shorter side is at least this get the tablet or desktop board.
  static const double largeScreenMinSide = 600;

  /// Large screens wider than this shape (16:10) get the desktop board.
  static const double desktopMinAspect = 1.6;

  /// The tablet and desktop wheel box, before enlarging, and where the phone's wheel column sits
  /// in it (the design moves the rim from (24, 8) to (6, 22)).
  static const Size largeWheelBox = Size(280, 300);
  static const Offset largeWheelShift = Offset(-18, 14);

  /// The top bar's and the history strip's own heights.
  static const double barHeight = 40;
  static const double historyHeight = 52;

  bool get isLarge => this != phone;

  static Spin2WinLayout forScreen(Size screen) {
    if (screen.shortestSide < largeScreenMinSide) return phone;
    return screen.width / screen.height < desktopMinAspect ? tablet : desktop;
  }

  /// The design-space size this board is laid out at for a [screen] of this size.
  Size designSizeFor(Size screen) {
    if (screen.width <= 0 || screen.height <= 0) return Size((minWidth + maxWidth) / 2, height);
    return Size((screen.width * height / screen.height).clamp(minWidth, maxWidth), height);
  }

  /// The body's height (wheel and panel) on this board.
  double get bodyHeight => height - padding.vertical - (barHeight + historyHeight) * barZoom - 2 * gap;

  /// The middle of the wheel's hub in the board's design space, where the coins burst from.
  Offset get hubCentre {
    if (!isLarge) return const Offset(168, 194);
    final wheelTop = padding.top + barHeight * barZoom + gap + (bodyHeight - largeWheelBox.height * wheelZoom) / 2;
    // The rim's middle: (6 + 134, 22 + 134) in the wheel box.
    return Offset(padding.left + 140 * wheelZoom, wheelTop + 156 * wheelZoom);
  }
}

/// The chosen board, and the size it is laid out at, for the frame and the effects over it.
class Spin2WinLayoutScope extends InheritedWidget {
  const Spin2WinLayoutScope({super.key, required this.board, required super.child});

  final Spin2WinLayout board;

  /// The board in use; the phone board when none was given (a frame drawn on its own).
  static Spin2WinLayout of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Spin2WinLayoutScope>()?.board ?? Spin2WinLayout.phone;

  @override
  bool updateShouldNotify(Spin2WinLayoutScope oldWidget) => board != oldWidget.board;
}

/// Draws [child] enlarged by [zoom], the way CSS `zoom` does: the child is laid out in the space
/// given divided by [zoom], then scaled up to fill it. Taps land where they are drawn.
class Spin2WinZoom extends StatelessWidget {
  const Spin2WinZoom({super.key, required this.zoom, required this.child});

  final double zoom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (zoom == 1) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return SizedBox.fromSize(
          size: size,
          child: FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.topLeft,
            child: SizedBox(width: size.width / zoom, height: size.height / zoom, child: child),
          ),
        );
      },
    );
  }
}

/// Draws [child], made for the phone board around its hub (the coin burst), on the board in use:
/// moved to that board's hub and enlarged as the design enlarges it (1.5 on the tablet, 2 on the
/// desktop).
class Spin2WinAtHub extends StatelessWidget {
  const Spin2WinAtHub({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final board = Spin2WinLayoutScope.of(context);
    if (!board.isLarge) return child;
    final hub = board.hubCentre;
    final phoneHub = Spin2WinLayout.phone.hubCentre;
    final zoom = board.burstZoom;
    return Transform(
      transform: Matrix4.diagonal3Values(zoom, zoom, 1)
        ..setTranslationRaw(hub.dx - phoneHub.dx * zoom, hub.dy - phoneHub.dy * zoom, 0),
      child: child,
    );
  }
}
