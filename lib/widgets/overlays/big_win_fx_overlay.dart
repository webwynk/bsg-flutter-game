import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Coin-burst FX shown for wins >=900 coins, in the gap between the wheel
/// stopping and the win popup opening. Plays assets/animations/coins.json at
/// its own native speed starting from frame 0 -- it does not know or need to
/// know how long it will stay mounted. GameProvider.onGlobalResult() is the
/// sole owner of that timing: it removes this widget from the tree (via
/// showBigWinFx flipping false) in the exact same notifyListeners() call
/// that opens the win popup, so this widget is always cut off cleanly rather
/// than left to reach its own ~5s natural end.
class BigWinFxOverlay extends StatefulWidget {
  const BigWinFxOverlay({super.key});

  @override
  State<BigWinFxOverlay> createState() => _BigWinFxOverlayState();
}

class _BigWinFxOverlayState extends State<BigWinFxOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.center,
        child: Lottie.asset(
          'assets/animations/coins.json',
          controller: _controller,
          onLoaded: (composition) {
            _controller.duration = composition.duration;
            _controller.forward();
          },
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
