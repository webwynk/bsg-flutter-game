// The exit question of the Lucky Card screen, "EXIT GAME / Do you want to exit?", as Triple Chance asks
// it (spec §17AC), in the design Hasan approved for Lucky 16 Card (lucky_card_popup_kit.dart), with a
// green NO and a red YES.
//
//   final leave = await LuckyCardExitDialog.show(context);   // true only for YES
//
// How it behaves did not change with the new design:
//   * it cancels itself after 5 seconds, answering "stay", so a forgotten question never keeps the
//     player from the game. New in this design: a gold bar drains over those 5 seconds beside
//     "STAYING IN 3S", so the player can see it coming;
//   * tapping outside does not dismiss it; the system back gesture answers "stay";
//   * it answers once, however many times it is activated (two quick taps never pop a second route,
//     which would take the player out of the screen behind);
//   * NO and YES answer over at least 48 dp; all text is at least 11 dp and ignores the phone's
//     font-size setting;
//   * the notification sound at opening is a hook ([onOpen]) for the screen.
//
// Belongs to Lucky Card only.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'lucky_card_layout.dart';
import 'lucky_card_panel.dart';
import 'lucky_card_popup_kit.dart';

/// The words of the popup.
const String kLuckyCardExitTitle = 'EXIT GAME';
const String kLuckyCardExitMessage = 'Do you want to exit?';
const String kLuckyCardExitNo = 'NO';
const String kLuckyCardExitYes = 'YES';

/// What the bar says with [seconds] left before the popup answers "stay".
String luckyCardExitCountdownText(int seconds) => 'STAYING IN ${seconds}S';

class LuckyCardExitDialog extends StatefulWidget {
  const LuckyCardExitDialog({super.key});

  /// How long the popup waits before answering "stay" by itself.
  static const Duration autoCancel = Duration(seconds: 5);

  /// How much of the canvas's width the popup covers.
  static const double widthShare = 0.46;

  /// Shows the popup; completes with true for YES, false for NO or the time running out, and null if
  /// the system back gesture closed it.
  static Future<bool?> show(BuildContext context, {VoidCallback? onOpen}) {
    onOpen?.call();
    return showLuckyCardPopup<bool>(
      context,
      barrierDismissible: false,
      barrierLabel: 'Exit',
      builder: (_) => const LuckyCardExitDialog(),
    );
  }

  @override
  State<LuckyCardExitDialog> createState() => _LuckyCardExitDialogState();
}

class _LuckyCardExitDialogState extends State<LuckyCardExitDialog> with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _answered = false;

  /// Runs from 1 (the bar full) to 0 (time up) over the 5 seconds. Only the bar reads it: the answer
  /// comes from [_timer], so it does not depend on the phone's "remove animations" setting.
  late final AnimationController _left =
      AnimationController(vsync: this, duration: LuckyCardExitDialog.autoCancel, value: 1);

  @override
  void initState() {
    super.initState();
    _timer = Timer(LuckyCardExitDialog.autoCancel, () => _answer(false));
    _left.reverse();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _left.dispose();
    super.dispose();
  }

  void _answer(bool leave) {
    if (_answered || !mounted) return;
    _answered = true;
    _timer?.cancel();
    Navigator.of(context).pop(leave);
  }

  /// One answer: a 3D button, the whole of its half of the row.
  Widget _button(
    LuckyCardLayout layout, {
    required String label,
    required bool leave,
    required String key,
    required List<Color> fill,
    required Color rim,
    required Color edge,
    required Color glow,
  }) {
    final height = math.max(layout.dp(124), kLuckyCardMinTapDp);
    final radius = BorderRadius.circular(layout.dp(22));
    return Expanded(
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: label,
        onTap: () => _answer(leave),
        child: GestureDetector(
          key: ValueKey(key),
          behavior: HitTestBehavior.opaque,
          onTap: () => _answer(leave),
          child: Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: fill,
                stops: const [0.0, 0.52, 1.0],
              ),
              border: Border.all(color: rim, width: math.max(layout.dp(3), 1.2)),
              boxShadow: [
                BoxShadow(color: edge, offset: Offset(0, math.max(layout.dp(8), 2))),
                BoxShadow(color: glow, blurRadius: layout.dp(24)),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.35), width: math.max(layout.dp(6), 1.5)),
              ),
            ),
            child: luckyCardPopupText(
              label,
              layout,
              weight: FontWeight.w700,
              units: 48,
              spacing: 0.14,
              color: const Color(0xFFFFFFFF),
              shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(0, 2))],
            ),
          ),
        ),
      ),
    );
  }

  /// The gold bar that drains over the 5 seconds, and the seconds left.
  Widget _bar(LuckyCardLayout layout) {
    final barHeight = math.max(layout.dp(12), 5.0);
    return AnimatedBuilder(
      animation: _left,
      builder: (context, _) {
        final seconds = math.max((_left.value * LuckyCardExitDialog.autoCancel.inSeconds).ceil(), 1);
        return Row(
          children: [
            Expanded(
              child: Container(
                key: const ValueKey('exit-bar'),
                height: barHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(barHeight),
                  color: Colors.black.withValues(alpha: 0.5),
                  border: Border.all(color: kLuckyCardGold.withValues(alpha: 0.35)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(barHeight),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      key: const ValueKey('exit-bar-fill'),
                      widthFactor: _left.value,
                      heightFactor: 1,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFFC8961E), kLuckyCardGoldBright]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: layout.dp(14)),
            luckyCardPopupText(
              luckyCardExitCountdownText(seconds),
              layout,
              key: const ValueKey('exit-countdown'),
              units: 26,
              color: kLuckyCardCream.withValues(alpha: 0.75),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = LuckyCardLayout.of(media.size);
    final width = layout.canvasRect.width * LuckyCardExitDialog.widthShare;
    final gem = math.max(layout.dp(128), 44.0);
    final gap = layout.dp(14);

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: kLuckyCardExitTitle,
        // Slightly low of the middle (54%), so the gem over its top edge has room.
        child: Align(
          alignment: const Alignment(0, 0.08),
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              key: const ValueKey('exit-dialog'),
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: gem / 2),
                    child: LuckyCardPopupFrame(
                      layout: layout,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          layout.dp(46),
                          math.max(layout.dp(92), gem / 2 + 4),
                          layout.dp(46),
                          layout.dp(40),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // The popup's own label already says the title to a screen reader.
                            ExcludeSemantics(child: LuckyCardGoldText(kLuckyCardExitTitle, layout: layout, units: 64)),
                            SizedBox(height: gap),
                            luckyCardPopupText(
                              kLuckyCardExitMessage,
                              layout,
                              key: const ValueKey('exit-message'),
                              family: 'DMSans',
                              units: 38,
                              height: 1.3,
                              maxLines: null,
                              align: TextAlign.center,
                            ),
                            SizedBox(height: gap),
                            _bar(layout),
                            SizedBox(height: gap * 1.4),
                            Row(
                              children: [
                                _button(
                                  layout,
                                  label: kLuckyCardExitNo,
                                  leave: false,
                                  key: 'exit-no',
                                  fill: const [Color(0xFF55FF55), Color(0xFF00AA00), Color(0xFF005500)],
                                  rim: const Color(0xFF99FF99),
                                  edge: const Color(0xFF003300),
                                  glow: const Color(0x4055FF55),
                                ),
                                SizedBox(width: layout.dp(26)),
                                _button(
                                  layout,
                                  label: kLuckyCardExitYes,
                                  leave: true,
                                  key: 'exit-yes',
                                  fill: const [Color(0xFFFF5555), Color(0xFFCC0000), Color(0xFF660000)],
                                  rim: const Color(0xFFFFAAAA),
                                  edge: const Color(0xFF3A0000),
                                  glow: const Color(0x33000000),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    key: const ValueKey('exit-gem'),
                    width: gem,
                    height: gem,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-0.2, -0.3),
                        colors: [Color(0xFFFFF0A8), kLuckyCardGoldBright, Color(0xFF9C7A1C)],
                        stops: [0.0, 0.35, 1.0],
                      ),
                      border: Border.all(color: const Color(0xFFFFF0A8), width: math.max(layout.dp(5), 1.5)),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF5A4208), offset: Offset(0, math.max(layout.dp(6), 2))),
                        BoxShadow(color: kLuckyCardGoldBright.withValues(alpha: 0.5), blurRadius: layout.dp(30)),
                      ],
                    ),
                    child: Icon(Icons.warning_amber_rounded, size: gem * 0.62, color: const Color(0xFF5C0006)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
