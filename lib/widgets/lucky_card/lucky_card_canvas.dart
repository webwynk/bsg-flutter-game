// The Lucky Card screen's frame: a background over the whole screen, and on top
// of it a canvas, shaped by [LuckyCardLayout], holding the four zones (five on a tablet: the chip
// bar under the board; six on the desktop: the results row and the bottom bar of chips and buttons).
//
// It does three things and nothing else:
//   * places each zone where [LuckyCardLayout] says, giving it that layout so it
//     can size what it draws (every zone is optional, so the frame can be built
//     and tested before the zones exist);
//   * makes the phone's font-size setting have no effect on anything inside, so a
//     phone set to "large font" cannot push the layout out of shape (spec §12.2);
//   * paints the background over the whole screen, so the part of the screen the
//     canvas does not use reads as background, not as bars.
//
// Belongs to Lucky Card only.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'lucky_card_layout.dart';

/// Builds what goes in one zone, given the layout it is part of.
typedef LuckyCardZoneBuilder = Widget Function(BuildContext context, LuckyCardLayout layout);

/// Gives every widget under a [LuckyCardCanvas] its [LuckyCardLayout].
class LuckyCardLayoutScope extends InheritedWidget {
  const LuckyCardLayoutScope({super.key, required this.layout, required super.child});

  final LuckyCardLayout layout;

  static LuckyCardLayout of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LuckyCardLayoutScope>();
    assert(scope != null, 'No LuckyCardCanvas above this widget');
    return scope!.layout;
  }

  @override
  bool updateShouldNotify(LuckyCardLayoutScope oldWidget) =>
      oldWidget.layout.screen != layout.screen;
}

class LuckyCardCanvas extends StatelessWidget {
  const LuckyCardCanvas({
    super.key,
    this.background,
    this.topBar,
    this.grid,
    this.rankColumn,
    this.side,
    this.chipBar,
    this.resultsBar,
    this.actionBar,
    this.overlay,
    this.layoutOf = LuckyCardCanvas.defaultLayoutOf,
  });

  /// The layout for a screen of this size: [LuckyCardLayout.of], which gives a tablet-sized screen the
  /// tablet arrangement and any other the phone one (spec §17BN). The desktop arrangement is never
  /// chosen here (it needs to be told the platform): the screen and tests pass their own.
  final LuckyCardLayout Function(Size screen) layoutOf;

  static LuckyCardLayout defaultLayoutOf(Size screen) => LuckyCardLayout.of(screen);

  /// Painted over the whole screen. A plain dark one stands in until the real
  /// background is supplied.
  final Widget? background;

  final LuckyCardZoneBuilder? topBar;
  final LuckyCardZoneBuilder? grid;
  final LuckyCardZoneBuilder? rankColumn;
  final LuckyCardZoneBuilder? side;

  /// The bar under the board that holds the chips: a tablet-only zone. It is left out on a phone,
  /// whatever is passed, because a phone's chips are in [side].
  final LuckyCardZoneBuilder? chipBar;

  /// The desktop-only row of the newest history cards, under the board. Left out on a phone and a tablet,
  /// whatever is passed (their results are in [side]).
  final LuckyCardZoneBuilder? resultsBar;

  /// The desktop-only bar at the bottom of the right column that holds the chips and the three buttons.
  /// Left out on a phone and a tablet, whatever is passed (their chips and buttons are in [side] and
  /// [chipBar]).
  final LuckyCardZoneBuilder? actionBar;

  /// Drawn over everything, across the whole screen (not just the canvas): the
  /// coins and the win popup.
  final LuckyCardZoneBuilder? overlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedWidth && constraints.hasBoundedHeight,
          'LuckyCardCanvas needs a bounded size (give it the whole screen)',
        );
        final layout = layoutOf(constraints.biggest);
        final media = MediaQuery.maybeOf(context) ?? const MediaQueryData();
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.noScaling),
          child: LuckyCardLayoutScope(
            layout: layout,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: background ?? const _PlaceholderBackground()),
                Positioned.fromRect(
                  rect: layout.canvasRect,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _zone(layout.topBar, topBar, layout),
                      _zone(layout.grid, grid, layout),
                      _zone(layout.rankColumn, rankColumn, layout),
                      _zone(layout.side, side, layout),
                      if (layout.isTablet) _zone(layout.chipBar, chipBar, layout),
                      if (layout.isDesktop) ...[
                        _zone(layout.resultsBar, resultsBar, layout),
                        _zone(layout.actionBar, actionBar, layout),
                      ],
                    ],
                  ),
                ),
                if (overlay != null)
                  Positioned.fill(child: Builder(builder: (context) => overlay!(context, layout))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _zone(Rect rect, LuckyCardZoneBuilder? builder, LuckyCardLayout layout) {
    if (builder == null) return const SizedBox.shrink();
    return Positioned.fromRect(
      rect: rect,
      child: Builder(builder: (context) => builder(context, layout)),
    );
  }
}

class _PlaceholderBackground extends StatelessWidget {
  const _PlaceholderBackground();

  @override
  Widget build(BuildContext context) =>
      const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.darkBgGradient));
}
