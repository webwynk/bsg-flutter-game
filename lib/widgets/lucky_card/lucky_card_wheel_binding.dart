// Connects the wheel to the Lucky Card provider, and places it in the grid zone.
//
// The provider hands the wheel the server's result when the countdown reaches 00
// (`stage` becomes spinning, `spinTarget` holds the card and the bonus). This
// starts one spin per round, on the segments every phone derives from the round
// number (`luckyCardWheelStopFor`), and when the inner rim stops, five seconds
// later, tells the provider with `wheelLanded()`: the balance moves, the coins and
// the popup follow (Step 3b-2a). Nothing here decides anything; the wheel only
// plays what the provider holds.
//
//   LuckyCardCanvas(
//     grid: (context, layout) => LuckyCardWheelBinding(provider: provider, layout: layout),
//     ...
//   )
//
// A screen that opens in the middle of a spin (a late joiner) starts the spin as
// soon as the wheel is on screen.
//
// Belongs to Lucky Card only.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../providers/lucky_card_provider.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_wheel.dart';

class LuckyCardWheelBinding extends StatefulWidget {
  const LuckyCardWheelBinding({
    super.key,
    required this.provider,
    required this.layout,
    this.onSpinStart,
    this.onRankLanded,
  });

  final LuckyCardProvider provider;
  final LuckyCardLayout layout;

  /// Both rims begin to turn (the spin sound starts here).
  final VoidCallback? onSpinStart;

  /// The outer rim has stopped, at 3 s: the first "ding".
  final VoidCallback? onRankLanded;

  @override
  State<LuckyCardWheelBinding> createState() => _LuckyCardWheelBindingState();
}

class _LuckyCardWheelBindingState extends State<LuckyCardWheelBinding> {
  final GlobalKey<LuckyCardWheelState> _wheel = GlobalKey<LuckyCardWheelState>();

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
  void didUpdateWidget(LuckyCardWheelBinding oldWidget) {
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
    final target = provider.spinTarget;
    if (provider.stage != LuckyCardStage.spinning || target == null) return;
    if (_spunRoundId == target.roundId) return;
    final wheel = _wheel.currentState;
    if (wheel == null) return;
    _spunRoundId = target.roundId;
    // The wheel refuses a value it cannot show (a bonus outside 1 to 10 cannot
    // come from the database, but a crash in the middle of the reveal would be
    // worse than a wheel that stays still), and says so at the call.
    try {
      unawaited(
        wheel
            .spinTo(
              card: target.winningCard,
              roundNumber: target.roundNumber,
              bonus: target.bonusMultiplier,
            )
            .catchError((Object e) {
          debugPrint('LuckyCardWheelBinding: the spin failed: $e');
          return null;
        }),
      );
    } on ArgumentError catch (e) {
      debugPrint('LuckyCardWheelBinding: the wheel refused the spin: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: layout.wheelBox.shift(-layout.grid.topLeft),
          child: LuckyCardWheel(
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
