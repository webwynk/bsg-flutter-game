// The Lucky 16 Card screen's frame: a background over the whole screen, and on top of it a canvas,
// shaped by [Lucky16Layout], holding the four zones (header, grid, rank column, bet panel), on a tablet the chip bar under the board, and on the desktop the results row and the bottom bar.
//
// Copied from lib/widgets/lucky_card/lucky_card_canvas.dart (Lucky Card), phone zones only. It does
// three things and nothing else:
//   * places each zone where [Lucky16Layout] says, giving it that layout so it can size what it
//     draws (every zone is optional, so the frame can be built and tested before the zones exist);
//   * makes the phone's font-size setting have no effect on anything inside, so "large font"
//     cannot push the layout out of shape;
//   * paints the background over the whole screen, so the part of the screen the canvas does not
//     use reads as background, not as bars.
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'lucky16_layout.dart';

/// Builds what goes in one zone, given the layout it is part of.
typedef Lucky16ZoneBuilder = Widget Function(BuildContext context, Lucky16Layout layout);

/// Gives every widget under a [Lucky16Canvas] its [Lucky16Layout].
class Lucky16LayoutScope extends InheritedWidget {
  const Lucky16LayoutScope({super.key, required this.layout, required super.child});

  final Lucky16Layout layout;

  static Lucky16Layout of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<Lucky16LayoutScope>();
    assert(scope != null, 'No Lucky16Canvas above this widget');
    return scope!.layout;
  }

  @override
  bool updateShouldNotify(Lucky16LayoutScope oldWidget) => oldWidget.layout.screen != layout.screen;
}

class Lucky16Canvas extends StatelessWidget {
  const Lucky16Canvas({
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
    this.layoutOf = Lucky16Canvas.defaultLayoutOf,
  });

  /// The layout for a screen of this size ([Lucky16Layout.of] by default).
  final Lucky16Layout Function(Size screen) layoutOf;

  static Lucky16Layout defaultLayoutOf(Size screen) => Lucky16Layout.of(screen);

  /// Painted over the whole screen. A plain dark one stands in when none is given.
  final Widget? background;

  final Lucky16ZoneBuilder? topBar;
  final Lucky16ZoneBuilder? grid;
  final Lucky16ZoneBuilder? rankColumn;
  final Lucky16ZoneBuilder? side;

  /// The bar under the board that holds the chips: a tablet-only zone, left out on a phone whatever is
  /// passed, because a phone's chips are in [side].
  final Lucky16ZoneBuilder? chipBar;

  /// The desktop-only row of the newest results, and bar of chips and buttons. Left out elsewhere,
  /// whatever is passed.
  final Lucky16ZoneBuilder? resultsBar;
  final Lucky16ZoneBuilder? actionBar;

  /// Drawn over everything, across the whole screen (not just the canvas).
  final Lucky16ZoneBuilder? overlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedWidth && constraints.hasBoundedHeight,
          'Lucky16Canvas needs a bounded size (give it the whole screen)',
        );
        final layout = layoutOf(constraints.biggest);
        final media = MediaQuery.maybeOf(context) ?? const MediaQueryData();
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.noScaling),
          child: Lucky16LayoutScope(
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
                if (overlay != null) Positioned.fill(child: Builder(builder: (context) => overlay!(context, layout))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _zone(Rect rect, Lucky16ZoneBuilder? builder, Lucky16Layout layout) {
    if (builder == null) return const SizedBox.shrink();
    return Positioned.fromRect(rect: rect, child: Builder(builder: (context) => builder(context, layout)));
  }
}

class _PlaceholderBackground extends StatelessWidget {
  const _PlaceholderBackground();

  @override
  Widget build(BuildContext context) =>
      const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.darkBgGradient));
}
