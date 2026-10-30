// What every tappable piece of the board does the same way: a card, a suit
// header and a rank selector.
//
// It is the whole area it is given (never smaller than 48 dp, spec §12.2), larger
// than the picture drawn in it, so a tap just beside the picture still counts. It
// does not know about the game: when tapped it calls [onTap], and what the tap did
// comes back as the board's own receipt ([Lucky16BoardResult]). It answers that
// receipt:
//   * something changed: a short pulse (1.08x, 180 ms);
//   * something stopped it (in whole or in part): a short red flash over the
//     picture (260 ms) and [onRefused] with the reasons, so the screen can say why;
//   * the board is locked: dimmed to 55%, taps ignored, nothing said;
//   * the phone's "reduce motion" setting is on: nothing moves or flashes, but the
//     reason is still reported.
// A screen reader hears [semanticsLabel] and can activate it like a button.
//
// Copied from lib/widgets/lucky_card/lucky_card_tap_target.dart (Lucky Card); the names changed, and the
// counts are Lucky 16 Card's (16 cards, 4 on a suit bar, 4 rank selectors A, J, Q, K).
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky16_board.dart';

/// Builds what is drawn inside the area. [tinted] wraps the picture, and only the
/// picture, so the refusal flash colours the artwork and not the numbers.
typedef Lucky16TapContent = Widget Function(
  BuildContext context,
  Widget Function(Widget picture) tinted,
);

class Lucky16TapTarget extends StatefulWidget {
  const Lucky16TapTarget({
    super.key,
    required this.size,
    required this.semanticsLabel,
    required this.isLocked,
    required this.onTap,
    required this.content,
    this.onRefused,
  });

  /// The whole tappable area.
  final Size size;

  final String semanticsLabel;
  final bool isLocked;

  /// Called on a tap; answers with what the board did.
  final Lucky16BoardResult Function() onTap;

  /// Called when the tap was refused in whole or in part, with the reasons.
  final void Function(Set<Lucky16BoardIssue> issues)? onRefused;

  final Lucky16TapContent content;

  @override
  State<Lucky16TapTarget> createState() => _Lucky16TapTargetState();
}

class _Lucky16TapTargetState extends State<Lucky16TapTarget> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void dispose() {
    _pulse.dispose();
    _flash.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isLocked) return;
    final result = widget.onTap();
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (result.changedAnything && animate) _pulse.forward(from: 0);
    if (!result.isClean) {
      if (animate) {
        _flash
          ..value = 1
          ..reverse();
      }
      widget.onRefused?.call(result.issues);
    }
  }

  Widget _tinted(Widget picture) => AnimatedBuilder(
        animation: _flash,
        builder: (context, child) => _flash.value > 0
            ? ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Color.fromRGBO(255, 30, 30, 0.6 * _flash.value),
                  BlendMode.srcATop,
                ),
                child: child,
              )
            : child!,
        child: picture,
      );

  @override
  Widget build(BuildContext context) {
    Widget content = ScaleTransition(
      scale: TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 1),
      ]).animate(_pulse),
      child: widget.content(context, _tinted),
    );
    if (widget.isLocked) content = Opacity(opacity: 0.55, child: content);

    return Semantics(
      container: true,
      button: true,
      enabled: !widget.isLocked,
      excludeSemantics: true,
      label: widget.semanticsLabel,
      onTap: widget.isLocked ? null : _handleTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: RepaintBoundary(
          child: SizedBox(width: widget.size.width, height: widget.size.height, child: content),
        ),
      ),
    );
  }
}
