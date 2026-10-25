// The "NO MORE BETS" sign over the betting panel from the lock mark (05) until the wheel starts at
// 00, as Triple Chance shows "No More Play" then: the words flash between gold and red every
// 0.3 s. It pops in when it appears. It takes no taps.
//
// Belongs to Spin2Win only.

import 'package:flutter/widgets.dart';

import 'spin2win_palette.dart';

const String kSpin2WinNoMoreBets = 'NO MORE BETS';

class Spin2WinNoMoreBets extends StatefulWidget {
  const Spin2WinNoMoreBets({super.key, this.animate = true});

  /// Whether it flashes (a screenshot test holds it still on gold).
  final bool animate;

  @override
  State<Spin2WinNoMoreBets> createState() => _Spin2WinNoMoreBetsState();
}

class _Spin2WinNoMoreBetsState extends State<Spin2WinNoMoreBets> with TickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  late final AnimationController _pop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 350), value: widget.animate ? 0 : 1);

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _flash.repeat(reverse: true);
      _pop.forward();
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_flash, _pop]),
        builder: (context, _) {
          final color = Color.lerp(kS2wGold, const Color(0xFFFF3155), Curves.easeInOut.transform(_flash.value))!;
          return Transform.scale(
            scale: 0.6 + 0.4 * const Cubic(.2, 1.5, .4, 1).transform(_pop.value),
            child: Opacity(
              opacity: _pop.value.clamp(0.0, 1.0),
              child: Container(
                key: const ValueKey('spin2win-no-more-bets'),
                width: 300,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kS2wGoldBorder, width: 3),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF6B0016), Color(0xFF2A0008)],
                  ),
                  boxShadow: const [
                    BoxShadow(color: kS2wGoldUnder, offset: Offset(0, 5)),
                    BoxShadow(color: Color(0xB3000000), offset: Offset(0, 8), blurRadius: 16),
                    BoxShadow(color: Color(0x66FF3155), blurRadius: 24),
                  ],
                ),
                child: Spin2WinOutlinedText(
                  kSpin2WinNoMoreBets,
                  size: 26,
                  height: 1,
                  letterSpacing: 2,
                  color: color,
                  strokeWidth: 4,
                  stroke: const Color(0xE6300008),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
