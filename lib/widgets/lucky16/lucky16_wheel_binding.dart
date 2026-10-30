// Connects the Lucky 16 Card wheel to the provider, and places it in the grid zone, where it takes the
// board's place while betting is closed (phone and tablet), or in the wheel's column, where it stays on
// screen all the time (desktop).
//
// Copied from lib/widgets/lucky_card/lucky_card_wheel_binding.dart (Lucky Card). The provider hands the wheel the server's
// result when the countdown reaches 00 (`stage` becomes spinning, `spinTarget` holds the card and the
// bonus). This starts one spin per round, on the segments every phone derives from the round number
// (`lucky16WheelStopFor`), and when the inner rim stops, five seconds later, tells the provider with
// `wheelLanded()`. Nothing here decides anything; the wheel only plays what the provider holds.
//
//   Lucky16Canvas(
//     grid: (context, layout) => Lucky16WheelBinding(provider: provider, layout: layout),
//     ...
//   )
//
// A screen that opens in the middle of a spin (a late joiner) starts the spin as soon as the wheel is
// on screen.
//
// Belongs to Lucky 16 Card only.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../providers/lucky16_provider.dart';
import 'lucky16_layout.dart';
import 'lucky16_wheel.dart';

class Lucky16WheelBinding extends StatefulWidget {
  const Lucky16WheelBinding({
    super.key,
    required this.provider,
    required this.layout,
    this.zone,
    this.permanent = false,
    this.onSpinStart,
    this.onRankLanded,
  });

  final Lucky16Provider provider;
  final Lucky16Layout layout;

  /// The canvas zone this is placed in. Null means the grid zone; the desktop passes its wheel column.
  final Rect? zone;

  /// True when the wheel stays on screen between rounds (the desktop): when betting opens again the hub
  /// goes back to the mystery gift box.
  final bool permanent;

  /// Both rims begin to turn (for the spin sound, a later phase).
  final VoidCallback? onSpinStart;

  /// The outer rim has stopped, at 3 s (for the first "ding", a later phase).
  final VoidCallback? onRankLanded;

  @override
  State<Lucky16WheelBinding> createState() => _Lucky16WheelBindingState();
}

class _Lucky16WheelBindingState extends State<Lucky16WheelBinding> {
  final GlobalKey<Lucky16WheelState> _wheel = GlobalKey<Lucky16WheelState>();

  /// The round the wheel last spun for: one spin per round.
  String? _spunRoundId;

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_startIfDue);
    // The wheel is not built yet: a spin already under way starts after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfDue());
  }

  @override
  void didUpdateWidget(Lucky16WheelBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      oldWidget.provider.removeListener(_startIfDue);
      widget.provider.addListener(_startIfDue);
      WidgetsBinding.instance.addPostFrameCallback((_) => _startIfDue());
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_startIfDue);
    super.dispose();
  }

  void _startIfDue() {
    if (!mounted) return;
    final provider = widget.provider;
    if (widget.permanent && !provider.isLocked) _wheel.currentState?.clearResult();
    final target = provider.spinTarget;
    if (provider.stage != Lucky16Stage.spinning || target == null) return;
    if (_spunRoundId == target.roundId) return;
    final wheel = _wheel.currentState;
    if (wheel == null) return;
    _spunRoundId = target.roundId;
    // The wheel refuses a value it cannot show (a bonus outside 1 to 10 cannot come from the
    // database, but a crash in the middle of the reveal would be worse than a wheel that stays
    // still), and says so at the call.
    try {
      unawaited(
        wheel
            .spinTo(card: target.winningCard, roundNumber: target.roundNumber, bonus: target.bonusMultiplier)
            .catchError((Object e) {
          debugPrint('Lucky16WheelBinding: the spin failed: $e');
          return null;
        }),
      );
    } on ArgumentError catch (e) {
      debugPrint('Lucky16WheelBinding: the wheel refused the spin: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: layout.wheelBox.shift(-(widget.zone ?? layout.grid).topLeft),
          child: Lucky16Wheel(
            key: _wheel,
            size: layout.wheelDiameter,
            onSpinStart: widget.onSpinStart,
            onOuterLand: widget.onRankLanded,
            onInnerLand: (_) => widget.provider.wheelLanded(),
          ),
        ),
      ],
    );
  }
}
