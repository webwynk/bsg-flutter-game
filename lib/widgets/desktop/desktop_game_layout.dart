import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../tablet/scaled_box.dart';
import '../tablet/tablet_chip_row.dart';
import '../wheel/wheel_widget.dart';
import 'desktop_top_bar.dart';

/// The Triple Chance game layout for desktop-sized screens (see
/// `isDesktopScreen`): laptops and desktops running the web build or the
/// Windows app, and any other window at least 1280 x 720. `GameScreen` uses it
/// in place of the tablet and phone layouts; all game logic, dialogs and
/// callbacks stay in `GameScreen` ([onSpin] is its spin handler).
///
/// One screen, designed at [designWidth] x [designHeight], drawn scaled to fit
/// the window (the larger the window, the bigger everything; the background
/// behind it fills any leftover edges). Built so far: the top bar, the wheel
/// and the chip tray. The three boards, the buttons and the results follow in
/// later desktop phases.
class DesktopGameLayout extends StatelessWidget {
  final VoidCallback onSpin;
  /// Key of the wheel, owned by `GameScreen`, so the wheel keeps its state
  /// (a spin in progress, the landed result) if the window is resized and
  /// another layout takes over.
  final Key? wheelKey;
  const DesktopGameLayout({super.key, required this.onSpin, this.wheelKey});

  static const double designWidth = 1280;
  static const double designHeight = 720;

  // The wheel is laid out at the phone widget's 390 square and drawn
  // [_wheelDrawnSize] design units wide, centred at (635, 288).
  static const double _wheelDesignSize = 390;
  static const double _wheelDrawnSize = 440;
  static const Offset _wheelCenter = Offset(635, 288);

  /// How much the design is enlarged on a window of this size: the biggest
  /// factor at which the whole design still fits.
  static double scaleFor(Size window) =>
      math.min(window.width / designWidth, window.height / designHeight);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = scaleFor(Size(constraints.maxWidth, constraints.maxHeight));
        return Center(
          child: ScaledBox(
            designWidth: designWidth,
            designHeight: designHeight,
            scale: scale,
            child: Stack(
              children: [
                // The wheel, under the top bar.
                Positioned(
                  left: _wheelCenter.dx - _wheelDrawnSize / 2,
                  top: _wheelCenter.dy - _wheelDrawnSize / 2,
                  child: ScaledBox(
                    designWidth: _wheelDesignSize,
                    designHeight: _wheelDesignSize,
                    scale: _wheelDrawnSize / _wheelDesignSize,
                    child: ClipRect(child: WheelWidget(key: wheelKey)),
                  ),
                ),

                // The chip tray under the wheel.
                const Positioned(left: 450, top: 614, width: 370, height: 92, child: _ChipTray()),

                const Positioned(left: 0, top: 0, right: 0, child: DesktopTopBar()),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The tray the chips sit in: a dark teal plate with a gold rim. The chips are
/// the tablet's chip row (same selecting and locking), drawn 1.3 times bigger.
class _ChipTray extends StatelessWidget {
  const _ChipTray();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3A40), Color(0xFF06191C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF120000), offset: Offset(0, 5)),
          BoxShadow(color: Color(0x99000000), blurRadius: 14, offset: Offset(0, 10)),
        ],
      ),
      alignment: Alignment.center,
      child: const ScaledBox(
        designWidth: 270,
        designHeight: 60,
        scale: 1.3,
        child: TabletChipRow(),
      ),
    );
  }
}
