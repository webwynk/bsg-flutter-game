import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../controls/exit_corner_button.dart';
import '../panels/left_tab_strip.dart';
import '../wheel/wheel_widget.dart';
import 'scaled_box.dart';
import 'tablet_right_panel.dart';
import 'tablet_status_pill.dart';

/// The Triple Chance game layout for tablet-sized screens (see `isTabletScreen`).
/// `GameScreen` uses it in place of the phone layout; all game logic, dialogs
/// and callbacks stay in `GameScreen` ([onSpin] is its spin handler).
///
/// Same parts as the phone, in tablet positions:
///  - left: the three mode tabs and their number grids (the phone widget, drawn bigger),
///  - centre: the wheel (the phone widget, drawn bigger), the status pill above it
///    and the exit key at its top-right corner,
///  - right: the tablet control panel (`TabletRightPanel`: the phone panel's
///    parts, with the chips in a row), drawn bigger.
/// Later tablet phases arrange the action buttons as a 2 x 2 block.
///
/// Zone widths follow the screen shape: a wide screen (width/height >= 1.5,
/// e.g. 16:10) gets 20% left and 30% right; a squarer one (e.g. 4:3) gets
/// 22% and 32%.
class TabletGameLayout extends StatelessWidget {
  final VoidCallback onSpin;
  const TabletGameLayout({super.key, required this.onSpin});

  // The phone widgets' own design sizes: the closed tab strip is 158 wide
  // (3 tabs of 50 + 8 padding), the right panel is 236 wide on an 844-wide
  // phone, and the wheel is laid out in a 390 square.
  static const double _stripDesignWidth = 158.0;
  static const double _panelDesignWidth = 236.0;
  static const double _wheelDesignSize = 390.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final bool wide = w / h >= 1.5;
        final double left = w * (wide ? 0.20 : 0.22);
        final double right = w * (wide ? 0.30 : 0.32);
        final double centre = w - left - right;

        final double kLeft = left / _stripDesignWidth;
        final double kRight = right / _panelDesignWidth;
        final double kWheel = math.min(centre, h) / _wheelDesignSize;
        final double pillScale = (w / 1280).clamp(0.8, 1.2).toDouble();

        return Stack(
          fit: StackFit.expand,
          children: [
            // Centre: the wheel, drawn under the panels.
            Positioned(
              left: left,
              width: centre,
              top: 0,
              bottom: 0,
              child: Center(
                child: ScaledBox(
                  designWidth: _wheelDesignSize,
                  designHeight: _wheelDesignSize,
                  scale: kWheel,
                  child: Consumer<GameProvider>(
                    builder: (context, game, child) {
                      return ClipRect(
                        child: GestureDetector(
                          onTap: () {
                            if (game.isDrawerOpen) game.closeDrawer();
                          },
                          child: const WheelWidget(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // "Place your chips" / "No More Play" above the wheel.
            Positioned(
              left: left,
              width: centre,
              top: 16 * pillScale,
              child: Center(child: TabletStatusPill(scale: pillScale)),
            ),

            // Exit key at the wheel area's top-right corner (same exit call as
            // the phone). Under the left panel, as on the phone.
            Positioned(
              top: 8,
              right: right + 8,
              child: const ScaledBox(
                designWidth: 40,
                designHeight: 40,
                scale: 1.45,
                child: ExitCornerButton(),
              ),
            ),

            // Left: the tabs and number grids, expanding over the wheel.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: w - right,
              child: ScaledBox(
                designWidth: (w - right) / kLeft,
                designHeight: h / kLeft,
                scale: kLeft,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: LeftAccordionPanel(areaWidth: (w - right) / kLeft),
                ),
              ),
            ),

            // Right: the control panel (its status header is replaced by the pill).
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: right,
              child: ScaledBox(
                designWidth: right / kRight,
                designHeight: h / kRight,
                scale: kRight,
                child: TabletRightPanel(onSpin: onSpin),
              ),
            ),
          ],
        );
      },
    );
  }
}
