// The three buttons under the results: DOUBLE (or REBET), CLEAR and REMOVE, side by
// side, in the reference design's gradient looks (lucky16_palette.dart): DOUBLE lime to orange, REBET
// purple, CLEAR pink, REMOVE cyan.
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
// Copied from lib/widgets/lucky_card/lucky_card_action_buttons.dart (Lucky Card); the names changed, and it is
// the phone arrangement only.
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky16_board.dart';
import 'lucky16_layout.dart';
import 'lucky16_palette.dart';
import 'lucky16_stake_text.dart';

/// The four things a button can do.
enum Lucky16Control { doubleBet, rebet, clear, remove }

/// Called when a button's action was refused in whole or in part, with the reasons.
typedef Lucky16ControlRefused = void Function(Lucky16Control control, Set<Lucky16BoardIssue> issues);

/// What each button says, in capitals, as in Triple Chance.
String lucky16ControlLabel(Lucky16Control control) => switch (control) {
      Lucky16Control.doubleBet => 'DOUBLE',
      Lucky16Control.rebet => 'REBET',
      Lucky16Control.clear => 'CLEAR',
      Lucky16Control.remove => 'REMOVE',
    };

/// What a screen reader says for each button.
String lucky16ControlSemantics(Lucky16Control control) => switch (control) {
      Lucky16Control.doubleBet => 'Double every bet',
      Lucky16Control.rebet => 'Repeat the last bet',
      Lucky16Control.clear => 'Clear the board',
      Lucky16Control.remove => 'Remove: put the chip down, then tap chips to take them back',
    };

/// A button's colours: the gradient fill, stops, border, shadow under, outer glow, and text shadow.
class Lucky16ButtonLook {
  const Lucky16ButtonLook({
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

  static const Lucky16ButtonLook doubleLook = Lucky16ButtonLook(
    fill: kLucky16DoubleFill,
    stops: kLucky16DoubleStops,
    border: kLucky16DoubleBorder,
    shadow: kLucky16DoubleUnder,
    glow: kLucky16DoubleGlow,
    textShadow: kLucky16DoubleTextShadow,
  );

  static const Lucky16ButtonLook rebetLook = Lucky16ButtonLook(
    fill: kLucky16RebetFill,
    stops: kLucky16RebetStops,
    border: kLucky16RebetBorder,
    shadow: kLucky16RebetUnder,
    glow: kLucky16RebetGlow,
    textShadow: kLucky16RebetTextShadow,
  );

  static const Lucky16ButtonLook clearLook = Lucky16ButtonLook(
    fill: kLucky16ClearFill,
    stops: kLucky16ClearStops,
    border: kLucky16ClearBorder,
    shadow: kLucky16ClearUnder,
    glow: kLucky16ClearGlow,
    textShadow: kLucky16ClearTextShadow,
  );

  static const Lucky16ButtonLook removeLook = Lucky16ButtonLook(
    fill: kLucky16RemoveFill,
    stops: kLucky16RemoveStops,
    border: kLucky16RemoveBorder,
    shadow: kLucky16RemoveUnder,
    glow: kLucky16RemoveGlow,
    textShadow: kLucky16RemoveTextShadow,
  );

  // Aliases for compatibility
  static const Lucky16ButtonLook gold = doubleLook;
  static const Lucky16ButtonLook purple = rebetLook;
  static const Lucky16ButtonLook red = clearLook;

  static Lucky16ButtonLook of(Lucky16Control control) => switch (control) {
        Lucky16Control.doubleBet => doubleLook,
        Lucky16Control.rebet => rebetLook,
        Lucky16Control.clear => clearLook,
        Lucky16Control.remove => removeLook,
      };
}

class Lucky16ActionButton extends StatefulWidget {
  const Lucky16ActionButton({
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

  final Lucky16Layout layout;
  final Lucky16Control control;

  /// The whole tappable area, in dp.
  final Size size;

  /// False when there is nothing for the button to act on.
  final bool enabled;

  /// True while betting is closed.
  final bool isLocked;

  /// Does the action; answers with what the board did.
  final Lucky16BoardResult Function() onTap;

  /// Called on every accepted tap, before the action (the click sound).
  final VoidCallback? onPressed;

  final Lucky16ControlRefused? onRefused;

  /// How long the red flash of a refused tap lasts.
  static const Duration flashDuration = Duration(milliseconds: 260);

  @override
  State<Lucky16ActionButton> createState() => _Lucky16ActionButtonState();
}

class _Lucky16ActionButtonState extends State<Lucky16ActionButton> with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(vsync: this, duration: Lucky16ActionButton.flashDuration);
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
    final look = Lucky16ButtonLook.of(widget.control);
    final label = lucky16ControlLabel(widget.control);
    const rim = 2.0;
    final radius = BorderRadius.circular(layout.buttonRadius);

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
                    stops: kLucky16ButtonGlossStops,
                    colors: kLucky16ButtonGloss,
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
                    final fontSize = fitLucky16FontSize(
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
      label: lucky16ControlSemantics(widget.control),
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
