// The Spin2Win wheel in motion: turns [Spin2WinWheel] for 4 seconds onto the winning number when
// a result comes in (Hasan's rule, 2026-10-25: 4 s, then the winning number shows), shuffles the
// bonus in the dome while it turns, and when it stops shows the number and its bonus, lights the
// winning segment and bounces the pointer. The bulbs twinkle and the glow behind the wheel breathes
// all the time, as in the reference design.
//
// Given a [Spin2WinWheelCue] (what the round is doing), nothing else: no provider
// (spin2win_frame_binding.dart makes the cue). It tells [Spin2WinSpinningWheel.onLanded] when the
// wheel has stopped, which is the provider's `wheelLanded`.
//
// The turn: at least 6 whole turns plus what it takes to bring the winning number under the
// pointer, in 4 s. Smooth stop (Hasan's phone test, 2026-10-25: "feels stuck and slow when the
// number is selected"; the design's ease spent 1.1 s on the last segment):
//   * fast at first, a steady slow-down, still turning at 180°/s when the number reaches the
//     pointer at 4.0 s (the last segment takes about 0.2 s) ([spin2WinSpinProgress]);
//   * then it snaps: about 3° past the number and back, settled by 4.35 s ([spin2WinSettleOffset]);
//   * the number pops the moment the wheel reaches it (full size in 0.22 s), the segment lights in
//     0.15 s and the pointer kicks for 0.4 s (spin2win_wheel.dart);
//   * the bonus changes every 70 ms, growing to 160 ms, right up to the stop.
//
// Belongs to Spin2Win only.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'spin2win_wheel.dart';

/// What the wheel should be doing, read from the round.
@immutable
class Spin2WinWheelCue {
  const Spin2WinWheelCue({
    this.restNumber,
    this.restBonus = 1,
    this.spinKey,
    this.target,
    this.targetBonus = 1,
    this.revealed = false,
  });

  /// The last result, shown standing still between rounds; null before there is one (the dome
  /// then shows "BONUS N").
  final int? restNumber;
  final int restBonus;

  /// The round being drawn, from the moment its result is in hand until its sequence ends; null
  /// otherwise. A new key starts a spin.
  final String? spinKey;

  /// The number the wheel must stop on, and the round's bonus (with [spinKey]).
  final int? target;
  final int targetBonus;

  /// True once the game has revealed the result (the wheel is then shown stopped on it, even if
  /// this screen never saw it turn).
  final bool revealed;

  @override
  bool operator ==(Object other) =>
      other is Spin2WinWheelCue &&
      other.restNumber == restNumber &&
      other.restBonus == restBonus &&
      other.spinKey == spinKey &&
      other.target == target &&
      other.targetBonus == targetBonus &&
      other.revealed == revealed;

  @override
  int get hashCode => Object.hash(restNumber, restBonus, spinKey, target, targetBonus, revealed);
}

/// The face's angle that puts [number] under the pointer, as close as possible to [from] (so
/// standing still never makes the wheel jump a whole turn).
double spin2WinNearestAngle(double from, int number) {
  final target = spin2WinAngleFor(number);
  final turns = ((from - target) / 360).round();
  return target + 360.0 * turns;
}

/// The angle a spin from [from] ends at: at least [extraTurns] whole turns clockwise, landing with
/// [number] under the pointer (the design's `base + 360 * 6 + ...`).
double spin2WinSpinEnd(double from, int number, {int extraTurns = 6}) {
  final base = (from / 36).round() * 36.0;
  final target = (spin2WinAngleFor(number) % 360 + 360) % 360;
  final baseMod = (base % 360 + 360) % 360;
  return base + 360.0 * extraTurns + ((target - baseMod + 360) % 360);
}

/// The wheel's speed when the winning number reaches the pointer, degrees a second.
const double kSpin2WinArriveSpeed = 180;

/// How far through a spin of [distance] degrees the wheel is at [t] (0 to 1 of the spin time):
/// a quartic slow-down mixed with a steady part, so it arrives at [kSpin2WinArriveSpeed] instead
/// of crawling the last few degrees.
double spin2WinSpinProgress(double t, double distance, {Duration time = Spin2WinSpinningWheel.spinTime}) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  final steady = (kSpin2WinArriveSpeed * time.inMilliseconds / 1000 / distance).clamp(0.0, 0.5);
  final u = 1 - t;
  return (1 - steady) * (1 - u * u * u * u) + steady * t;
}

/// The snap after the wheel reaches the number: past it and back, a damped swing that starts at
/// [kSpin2WinArriveSpeed] and dies away by the end of [Spin2WinSpinningWheel.settleTime]. [s] is
/// seconds since arriving; degrees, positive past the number.
double spin2WinSettleOffset(double s) {
  if (s <= 0) return 0;
  const swing = 30.0; // radians a second
  const decay = 12.0;
  return kSpin2WinArriveSpeed / swing * math.exp(-decay * s) * math.sin(swing * s);
}

class Spin2WinSpinningWheel extends StatefulWidget {
  const Spin2WinSpinningWheel({super.key, required this.cue, this.onLanded, this.animateIdle = true});

  final Spin2WinWheelCue cue;

  /// Told once per spin, when the wheel has stopped.
  final VoidCallback? onLanded;

  /// Whether the bulbs twinkle and the glow breathes (a screenshot test turns them off).
  final bool animateIdle;

  /// How long a spin takes.
  static const Duration spinTime = Duration(seconds: 4);

  /// The snap past the number and back, after [spinTime].
  static const Duration settleTime = Duration(milliseconds: 350);

  /// The landed dome's pop (0.22 s), the badge's drop (0.35 s), the highlight's fade-in (0.15 s)
  /// and the pointer's kick (0.4 s) all happen inside this.
  static const Duration revealTime = Duration(milliseconds: 850);

  /// The bonuses the dome shuffles through while the wheel turns.
  static const List<int> shuffleOrder = [1, 2, 3, 4];

  @override
  State<Spin2WinSpinningWheel> createState() => _Spin2WinSpinningWheelState();
}

class _Spin2WinSpinningWheelState extends State<Spin2WinSpinningWheel> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: Spin2WinSpinningWheel.spinTime)
    ..addStatusListener(_onSpinStatus);
  late final AnimationController _reveal = AnimationController(vsync: this, duration: Spin2WinSpinningWheel.revealTime);
  late final AnimationController _twinkle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _halo = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _reel = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
  late final AnimationController _settle =
      AnimationController(vsync: this, duration: Spin2WinSpinningWheel.settleTime, value: 1);

  /// The face's angle when standing still, and a spin's start and end.
  double _angle = 0;
  double _from = 0;
  double _to = 0;

  String? _spinningKey;
  String? _landedKey;
  int _shuffleIndex = 0;
  Timer? _shuffleTimer;

  @override
  void initState() {
    super.initState();
    if (widget.animateIdle) {
      _twinkle.repeat(reverse: true);
      _halo.repeat(reverse: true);
    }
    final cue = widget.cue;
    if (cue.restNumber != null) _angle = spin2WinAngleFor(cue.restNumber!);
    _follow(cue, opening: true);
  }

  @override
  void didUpdateWidget(Spin2WinSpinningWheel old) {
    super.didUpdateWidget(old);
    if (old.cue != widget.cue) _follow(widget.cue, opening: false);
  }

  /// Starts, finishes or drops a spin to match the round.
  void _follow(Spin2WinWheelCue cue, {required bool opening}) {
    final key = cue.spinKey;
    final target = cue.target;
    if (key == null || target == null) {
      // Between rounds: stand still on the last result; the highlight goes.
      if (_spin.isAnimating) _stopSpin();
      _settle.value = 1;
      _landedKey = null;
      _spinningKey = null;
      _pulse.stop();
      if (cue.restNumber != null) _angle = spin2WinNearestAngle(_angle, cue.restNumber!);
      return;
    }
    if (key == _spinningKey || key == _landedKey) {
      // The same round. Revealed before this screen's own wheel stopped (it was away): stop now.
      if (cue.revealed && _spin.isAnimating) _land(target, snap: false);
      return;
    }
    if (cue.revealed) {
      // Opened (or came back) after the result was shown: no spin, just the result.
      _angle = spin2WinNearestAngle(_angle, target);
      _landedKey = key;
      _reveal.value = 1;
      _startPulse();
      return;
    }
    // A new result: spin.
    _spinningKey = key;
    _landedKey = null;
    _from = _angle;
    _to = spin2WinSpinEnd(_from, target);
    _reveal.value = 0;
    _pulse.stop();
    _shuffleIndex = 0;
    _reel.repeat();
    _spin.forward(from: 0);
    _scheduleShuffle();
  }

  void _scheduleShuffle() {
    _shuffleTimer?.cancel();
    final p = _spin.value;
    if (!_spin.isAnimating) return;
    final wait = Duration(milliseconds: (70 + 90 * p * p).round());
    _shuffleTimer = Timer(wait, () {
      if (!mounted || !_spin.isAnimating) return;
      setState(() => _shuffleIndex = (_shuffleIndex + 1) % Spin2WinSpinningWheel.shuffleOrder.length);
      _scheduleShuffle();
    });
  }

  void _onSpinStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _spinningKey != null) _land(widget.cue.target!);
  }

  void _stopSpin() {
    _shuffleTimer?.cancel();
    _reel.stop();
    _spin.stop();
  }

  /// The wheel has reached [target]: show it and tell the game. With [snap] it swings a little past
  /// the number and back; without (the game revealed early) it simply stands on it.
  void _land(int target, {bool snap = true}) {
    _stopSpin();
    if (snap) {
      _settle.forward(from: 0);
    } else {
      _settle.value = 1;
    }
    setState(() {
      _angle = spin2WinNearestAngle(_to, target);
      _landedKey = _spinningKey;
      _spinningKey = null;
    });
    _reveal.forward(from: 0);
    _startPulse();
    widget.onLanded?.call();
  }

  void _startPulse() {
    // The highlight fades in, then pulses between full and 45% (the design's `hlPulse`).
    _pulse.value = 1;
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    _spin.dispose();
    _reveal.dispose();
    _twinkle.dispose();
    _halo.dispose();
    _pulse.dispose();
    _reel.dispose();
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_spin, _reveal, _twinkle, _halo, _pulse, _reel, _settle]),
      builder: (context, _) {
        final cue = widget.cue;
        final spinning = _spinningKey != null && _spin.isAnimating;
        final landed = _landedKey != null && cue.target != null;
        final double angle;
        final Spin2WinDome dome;
        double? highlight;
        var reveal = 1.0;
        var pointerDrop = 0.0;
        if (spinning) {
          angle = _from + (_to - _from) * spin2WinSpinProgress(_spin.value, _to - _from);
          dome = Spin2WinDomeShuffling(Spin2WinSpinningWheel.shuffleOrder[_shuffleIndex]);
        } else if (landed) {
          final settling = _settle.isAnimating;
          angle = _angle +
              (settling
                  ? spin2WinSettleOffset(_settle.value * Spin2WinSpinningWheel.settleTime.inMilliseconds / 1000)
                  : 0);
          dome = Spin2WinDomeLanded(cue.target!, cue.targetBonus);
          reveal = _reveal.value;
          // The fade-in over the first 0.15 s, then the pulse (1 to 0.45).
          final fadeIn = (reveal / (150 / 850)).clamp(0.0, 1.0);
          highlight = fadeIn * (0.45 + 0.55 * _pulse.value);
          pointerDrop = _pointerBounce(reveal * 850 / 400);
        } else {
          angle = _angle;
          dome = cue.restNumber == null
              ? const Spin2WinDomeShuffling(1)
              : Spin2WinDomeLanded(cue.restNumber!, cue.restBonus);
        }
        return Spin2WinWheel(
          angle: angle,
          dome: dome,
          twinkle: Curves.easeInOut.transform(_twinkle.value),
          halo: Curves.easeInOut.transform(_halo.value),
          highlight: highlight,
          pointerDrop: pointerDrop,
          domeReveal: reveal,
          reel: _reel.value,
        );
      },
    );
  }

  /// The design's `ptrHit`: up 9 dp at a quarter, down 3 dp past half way, back at the end.
  static double _pointerBounce(double t) {
    if (t <= 0 || t >= 1) return 0;
    if (t < 0.25) return -9 * (t / 0.25);
    if (t < 0.55) return -9 + 12 * ((t - 0.25) / 0.30);
    return 3 - 3 * ((t - 0.55) / 0.45);
  }
}
