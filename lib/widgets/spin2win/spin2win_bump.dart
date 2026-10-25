// Two small Spin2Win "something changed" animations from the reference design:
//   * [Spin2WinBump]: grows to 110% and brightens, twice (0.45 s each), as the coin box does when a
//     win is paid in (`coinbump`);
//   * [Spin2WinPopIn]: grows from 20% to full size with an overshoot (0.5 s), as the newest history
//     tile does (`newtile`).
//
// Each plays when its key changes to a new, non-null value. Never on the first build, so opening
// the game (or coming back to it) does not replay an old win.
//
// Belongs to Spin2Win only.

import 'package:flutter/widgets.dart';

/// Plays [_play] when the key moves on after the first build.
mixin _PlaysOnNewKey<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController controller = AnimationController(vsync: this, duration: duration, value: 1);

  Duration get duration;
  Object? keyOf(T widget);

  @override
  void didUpdateWidget(T old) {
    super.didUpdateWidget(old);
    final next = keyOf(widget);
    if (next != null && next != keyOf(old)) controller.forward(from: 0);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class Spin2WinBump extends StatefulWidget {
  const Spin2WinBump({super.key, required this.bumpKey, required this.child});

  /// A new value makes the child bump.
  final Object? bumpKey;
  final Widget child;

  /// Both bumps together.
  static const Duration duration = Duration(milliseconds: 900);

  @override
  State<Spin2WinBump> createState() => _Spin2WinBumpState();
}

class _Spin2WinBumpState extends State<Spin2WinBump> with SingleTickerProviderStateMixin, _PlaysOnNewKey<Spin2WinBump> {
  @override
  Duration get duration => Spin2WinBump.duration;

  @override
  Object? keyOf(Spin2WinBump widget) => widget.bumpKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        // Two rounds of 0 -> 1 -> 0, eased.
        final t = (controller.value * 2) % 1;
        final up = controller.value >= 1 ? 0.0 : Curves.easeInOut.transform(t < 0.5 ? t * 2 : 2 - t * 2);
        if (up == 0) return child!;
        final b = 0.3 * up; // brightness(1.3) at the top
        return Transform.scale(
          scale: 1 + 0.1 * up,
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix([
              1 + b, 0, 0, 0, 0, //
              0, 1 + b, 0, 0, 0,
              0, 0, 1 + b, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: child,
          ),
        );
      },
    );
  }
}

class Spin2WinPopIn extends StatefulWidget {
  const Spin2WinPopIn({super.key, required this.popKey, required this.child});

  /// A new value makes the child pop in.
  final Object? popKey;
  final Widget child;

  static const Duration duration = Duration(milliseconds: 500);
  static const Cubic curve = Cubic(.2, 1.6, .4, 1);

  @override
  State<Spin2WinPopIn> createState() => _Spin2WinPopInState();
}

class _Spin2WinPopInState extends State<Spin2WinPopIn>
    with SingleTickerProviderStateMixin, _PlaysOnNewKey<Spin2WinPopIn> {
  @override
  Duration get duration => Spin2WinPopIn.duration;

  @override
  Object? keyOf(Spin2WinPopIn widget) => widget.popKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        if (controller.value >= 1) return child!;
        final p = Spin2WinPopIn.curve.transform(controller.value);
        return Opacity(
          opacity: (controller.value / 0.4).clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.2 + 0.8 * p, child: child),
        );
      },
    );
  }
}
