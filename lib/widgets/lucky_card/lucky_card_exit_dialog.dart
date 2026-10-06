// The exit confirmation of the Lucky Card screen, exactly as Triple Chance asks it
// (spec §17AC): "EXIT GAME / Do you want to exit?" with a green NO and a red YES.
//
//   final leave = await LuckyCardExitDialog.show(context);   // true only for YES
//
//   * It cancels itself after 5 seconds, answering "stay" (Triple Chance does the same), so
//     a forgotten dialog never keeps the player from the game.
//   * Tapping outside does not dismiss it; the system back gesture answers "stay".
//   * It answers once, however many times it is activated (two quick taps never pop a second
//     route, which would take the player out of the screen behind).
//   * NO and YES are at least 48 dp each way; all text is at least 11 dp and ignores the
//     phone's font-size setting. Sizes follow the canvas, like the Info dialog.
//   * The notification sound at opening is a hook ([onOpen]) for the screen (App Step 8b).
//
// Belongs to Lucky Card only.

import 'dart:async';

import 'package:flutter/material.dart';

import 'lucky_card_layout.dart';
import 'lucky_card_panel.dart';
import 'lucky_card_stake_text.dart';

/// The words of the dialog.
const String kLuckyCardExitTitle = 'EXIT GAME';
const String kLuckyCardExitMessage = 'Do you want to exit?';
const String kLuckyCardExitNo = 'NO';
const String kLuckyCardExitYes = 'YES';

class LuckyCardExitDialog extends StatefulWidget {
  const LuckyCardExitDialog({super.key});

  /// How long the dialog waits before answering "stay" by itself.
  static const Duration autoCancel = Duration(seconds: 5);

  /// How much of the canvas's width the dialog covers.
  static const double widthShare = 0.46;

  /// Shows the dialog; completes with true for YES, false for NO or the time running out,
  /// and null if the system back gesture closed it.
  static Future<bool?> show(BuildContext context, {VoidCallback? onOpen}) {
    onOpen?.call();
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Exit',
      barrierColor: const Color(0xBF000000),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const LuckyCardExitDialog(),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }

  @override
  State<LuckyCardExitDialog> createState() => _LuckyCardExitDialogState();
}

class _LuckyCardExitDialogState extends State<LuckyCardExitDialog> {
  Timer? _timer;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(LuckyCardExitDialog.autoCancel, () => _answer(false));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _answer(bool leave) {
    if (_answered || !mounted) return;
    _answered = true;
    _timer?.cancel();
    Navigator.of(context).pop(leave);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = LuckyCardLayout.of(media.size);
    final width = layout.canvasRect.width * LuckyCardExitDialog.widthShare;
    final button = layout.dp(134);

    Widget answer(String label, bool leave, List<Color> colors, Color rim, String key) {
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
            child: SizedBox(
              height: button,
              child: Center(
                child: FractionallySizedBox(
                  heightFactor: 0.78,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(layout.dp(18)),
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
                      border: Border.all(color: rim, width: layout.dp(5).clamp(1.2, 3.0).toDouble()),
                      boxShadow: const [BoxShadow(color: Color(0x61000000), blurRadius: 3, offset: Offset(0, 2))],
                    ),
                    child: LayoutBuilder(
                      builder: (context, c) => LuckyCardStakeText(
                        label,
                        maxWidth: c.maxWidth,
                        preferredSize: layout.fontSize(42),
                        color: const Color(0xFFFFFFFF),
                        shadowColor: const Color(0xCC000000),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: kLuckyCardExitTitle,
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              key: const ValueKey('exit-dialog'),
              width: width,
              child: LuckyCardPanel(
                layout: layout,
                radiusUnits: 28,
                padding: EdgeInsets.symmetric(horizontal: layout.dp(40), vertical: layout.dp(30)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: layout.fontSize(90, minDp: 28), color: kLuckyCardGoldBright),
                    SizedBox(height: layout.dp(12)),
                    SizedBox(
                      height: layout.fontSize(54) * 1.2,
                      child: LayoutBuilder(
                        builder: (context, c) => LuckyCardStakeText(
                          kLuckyCardExitTitle,
                          maxWidth: c.maxWidth,
                          preferredSize: layout.fontSize(54),
                          color: kLuckyCardGoldBright,
                        ),
                      ),
                    ),
                    SizedBox(height: layout.dp(10)),
                    Text(
                      kLuckyCardExitMessage,
                      key: const ValueKey('exit-message'),
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(fontFamily: 'DMSans', fontWeight: FontWeight.w500, fontSize: layout.fontSize(38), height: 1.3, color: kLuckyCardCream),
                    ),
                    SizedBox(height: layout.dp(16)),
                    Row(
                      children: [
                        answer(kLuckyCardExitNo, false, const [Color(0xFF55FF55), Color(0xFF00AA00), Color(0xFF005500)], const Color(0xFF99FF99), 'exit-no'),
                        SizedBox(width: layout.dp(24)),
                        answer(kLuckyCardExitYes, true, const [Color(0xFFFF5555), Color(0xFFCC0000), Color(0xFF660000)], const Color(0xFFFFAAAA), 'exit-yes'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
