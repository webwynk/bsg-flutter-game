// The three buttons under the results: DOUBLE (or REBET), CLEAR and REMOVE, side by
// side, as in Triple Chance's right panel (colours included): DOUBLE gold, REBET
// purple, CLEAR and REMOVE red.
//
// One button does one thing: when tapped it calls its action and answers with the
// board's receipt; if the action could not do all it was asked (not enough coins, a
// card at its maximum) the button flashes red for a moment and tells [onRefused] why,
// so the screen can say it. It never knows about the game.
//
//   * Each button is the whole area it is given, at least 48 dp each way.
//   * Closed table: dimmed to 55% like the board, taps ignored. Open table but nothing
//     to act on (an empty board): dimmed to 40%, taps ignored (Triple Chance's look).
//   * While a finger is down the button shrinks a little. With the phone's "reduce
//     motion" setting on, nothing moves or flashes, but the reason is still reported.
//   * The text is Oswald, never below 11 dp, and ignores the phone's font-size setting.
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky_card_board.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_stake_text.dart';

/// The four things a button can do.
enum LuckyCardControl { doubleBet, rebet, clear, remove }

/// Called when a button's action was refused in whole or in part, with the reasons.
typedef LuckyCardControlRefused = void Function(LuckyCardControl control, Set<LuckyCardBoardIssue> issues);

/// What each button says, in capitals, as in Triple Chance.
String luckyCardControlLabel(LuckyCardControl control) => switch (control) {
      LuckyCardControl.doubleBet => 'DOUBLE',
      LuckyCardControl.rebet => 'REBET',
      LuckyCardControl.clear => 'CLEAR',
      LuckyCardControl.remove => 'REMOVE',
    };

/// What a screen reader says for each button.
String luckyCardControlSemantics(LuckyCardControl control) => switch (control) {
      LuckyCardControl.doubleBet => 'Double every bet',
      LuckyCardControl.rebet => 'Repeat the last bet',
      LuckyCardControl.clear => 'Clear the board',
      LuckyCardControl.remove => 'Remove: put the chip down, then tap chips to take them back',
    };

/// A button's colours: the face (top, bottom), the label, the rim.
class LuckyCardButtonLook {
  const LuckyCardButtonLook(this.top, this.bottom, this.text, this.rim);

  final Color top;
  final Color bottom;
  final Color text;
  final Color rim;

  static const LuckyCardButtonLook gold =
      LuckyCardButtonLook(Color(0xFFFFD700), Color(0xFF8B6914), Color(0xFF350000), Color(0xFFFFD700));
  static const LuckyCardButtonLook purple =
      LuckyCardButtonLook(Color(0xFF6A0DAD), Color(0xFF3A0060), Color(0xFFFFFFFF), Color(0xFFCC88FF));
  static const LuckyCardButtonLook red =
      LuckyCardButtonLook(Color(0xFF8B0000), Color(0xFF3E0000), Color(0xFFFFFFFF), Color(0xFFFF6666));

  static LuckyCardButtonLook of(LuckyCardControl control) => switch (control) {
        LuckyCardControl.doubleBet => gold,
        LuckyCardControl.rebet => purple,
        LuckyCardControl.clear || LuckyCardControl.remove => red,
      };
}

class LuckyCardActionButton extends StatefulWidget {
  const LuckyCardActionButton({
    super.key,
    required this.layout,
    required this.control,
    required this.size,
    required this.enabled,
    required this.isLocked,
    required this.onTap,
    this.onPressed,
    this.onRefused,
  });

  final LuckyCardLayout layout;
  final LuckyCardControl control;

  /// The whole tappable area, in dp.
  final Size size;

  /// False when there is nothing for the button to act on.
  final bool enabled;

  /// True while betting is closed.
  final bool isLocked;

  /// Does the action; answers with what the board did.
  final LuckyCardBoardResult Function() onTap;

  /// Called on every accepted tap, before the action (the click sound).
  final VoidCallback? onPressed;

  final LuckyCardControlRefused? onRefused;

  /// How long the red flash of a refused tap lasts.
  static const Duration flashDuration = Duration(milliseconds: 260);

  @override
  State<LuckyCardActionButton> createState() => _LuckyCardActionButtonState();
}

class _LuckyCardActionButtonState extends State<LuckyCardActionButton> with SingleTickerProviderStateMixin {
  late final AnimationController _flash =
      AnimationController(vsync: this, duration: LuckyCardActionButton.flashDuration);
  bool _pressed = false;

  bool get _active => widget.enabled && !widget.isLocked;

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (_pressed != pressed && mounted) setState(() => _pressed = pressed);
  }

  void _handleTap() {
    if (!_active) return;
    widget.onPressed?.call();
    final result = widget.onTap();
    if (!result.isClean) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        _flash
          ..value = 1
          ..reverse();
      }
      widget.onRefused?.call(widget.control, result.issues);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final look = LuckyCardButtonLook.of(widget.control);
    final label = luckyCardControlLabel(widget.control);
    final rim = layout.dp(5).clamp(1.2, 3.0).toDouble();
    final radius = BorderRadius.circular(layout.dp(18));

    final face = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [look.top, look.bottom]),
        border: Border.all(color: look.rim, width: rim),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The gloss along the top edge.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: widget.size.height * 0.3,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            // The red flash of a refused tap.
            AnimatedBuilder(
              animation: _flash,
              builder: (context, _) => _flash.value > 0
                  ? ColoredBox(color: Color.fromRGBO(255, 30, 30, 0.6 * _flash.value))
                  : const SizedBox.shrink(),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: layout.dp(8)),
              child: LayoutBuilder(
                builder: (context, c) => LuckyCardStakeText(
                  label,
                  maxWidth: c.maxWidth,
                  preferredSize: layout.fontSize(36),
                  color: look.text,
                  shadowColor: look.text == const Color(0xFFFFFFFF) ? const Color(0xCC000000) : const Color(0x66FFFFFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final opacity = widget.isLocked ? 0.55 : (widget.enabled ? 1.0 : 0.4);
    return Semantics(
      container: true,
      button: true,
      enabled: _active,
      excludeSemantics: true,
      label: luckyCardControlSemantics(widget.control),
      onTap: _active ? _handleTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _active ? _handleTap : null,
        onTapDown: _active ? (_) => _setPressed(true) : null,
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: SizedBox(
          width: widget.size.width,
          height: widget.size.height,
          child: Opacity(
            opacity: opacity,
            child: AnimatedScale(
              scale: _pressed ? 0.94 : 1.0,
              duration: const Duration(milliseconds: 90),
              child: face,
            ),
          ),
        ),
      ),
    );
  }
}
