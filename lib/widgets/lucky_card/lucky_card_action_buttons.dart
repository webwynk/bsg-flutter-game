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
import 'lucky_card_palette.dart';
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

/// A button's colours: the gradient fill, stops, border, shadow under, outer glow, and text shadow.
class LuckyCardButtonLook {
  const LuckyCardButtonLook({
    required this.fill,
    this.stops,
    required this.border,
    required this.shadow,
    required this.glow,
    required this.textShadow,
    this.textColor = const Color(0xFFFFFFFF),
  });

  final List<Color> fill;
  final List<double>? stops;
  final Color border;
  final Color shadow;
  final Color glow;
  final Color textShadow;
  final Color textColor;

  Color get top => fill.first;
  Color get bottom => fill.last;
  Color get text => textColor;
  Color get rim => border;

  static const LuckyCardButtonLook doubleLook = LuckyCardButtonLook(
    fill: kDesignDoubleFill,
    stops: kDesignDoubleStops,
    border: kDesignDoubleBorder,
    shadow: kDesignDoubleUnder,
    glow: kDesignDoubleGlow,
    textShadow: kDesignDoubleTextShadow,
  );

  static const LuckyCardButtonLook rebetLook = LuckyCardButtonLook(
    fill: kDesignRebetFill,
    stops: kDesignRebetStops,
    border: kDesignRebetBorder,
    shadow: kDesignRebetUnder,
    glow: kDesignRebetGlow,
    textShadow: kDesignRebetTextShadow,
  );

  static const LuckyCardButtonLook clearLook = LuckyCardButtonLook(
    fill: kDesignClearFill,
    stops: kDesignClearStops,
    border: kDesignClearBorder,
    shadow: kDesignClearUnder,
    glow: kDesignClearGlow,
    textShadow: kDesignClearTextShadow,
  );

  static const LuckyCardButtonLook removeLook = LuckyCardButtonLook(
    fill: kDesignRemoveFill,
    stops: kDesignRemoveStops,
    border: kDesignRemoveBorder,
    shadow: kDesignRemoveUnder,
    glow: kDesignRemoveGlow,
    textShadow: kDesignRemoveTextShadow,
  );

  // Aliases for compatibility
  static const LuckyCardButtonLook gold = doubleLook;
  static const LuckyCardButtonLook purple = rebetLook;
  static const LuckyCardButtonLook red = clearLook;

  static LuckyCardButtonLook of(LuckyCardControl control) => switch (control) {
        LuckyCardControl.doubleBet => doubleLook,
        LuckyCardControl.rebet => rebetLook,
        LuckyCardControl.clear => clearLook,
        LuckyCardControl.remove => removeLook,
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
    const rim = 2.0;
    final radius = BorderRadius.circular(14);

    final face = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: look.fill,
          stops: look.stops,
        ),
        border: Border.all(color: look.border, width: rim),
        boxShadow: [
          BoxShadow(color: look.shadow, offset: const Offset(0, 4)),
          BoxShadow(color: look.glow, offset: const Offset(0, 6), blurRadius: 14),
          const BoxShadow(color: Color(0x2E000000), offset: Offset(0, -3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The gloss along the top half (from the reference design).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: widget.size.height * 0.47,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: kDesignButtonGlossStops,
                    colors: kDesignButtonGloss,
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
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final preferredSize = layout.designButtonFont;
                    final fontSize = fitLuckyCardFontSize(
                      text: label,
                      style: const TextStyle(
                        fontFamily: 'Oswald',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      maxWidth: c.maxWidth,
                      preferred: preferredSize,
                    );
                    return Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Oswald',
                        fontWeight: FontWeight.w700,
                        fontSize: fontSize,
                        letterSpacing: 0.5,
                        color: look.textColor,
                        shadows: [
                          Shadow(color: look.textShadow, offset: const Offset(0, 2)),
                        ],
                      ),
                    );
                  },
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
