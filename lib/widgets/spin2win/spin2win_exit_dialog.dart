// The Spin2Win exit question, asked for the EXIT button and the phone's back gesture with Triple
// Chance's own words and rules: "EXIT GAME / Do you want to exit?", a green NO and a red YES.
//
//   final leave = await Spin2WinExitDialog.show(context);   // true only for YES
//
//   * It answers "stay" by itself after 5 seconds (as Triple Chance's does), so a forgotten
//     question never keeps the player from the game.
//   * Tapping outside does nothing; the back gesture answers "stay".
//   * It answers once, however many times it is tapped (two quick taps never close the game
//     screen behind it as well).
//   * It is drawn in Spin2Win's look (the records popup's gold-framed blue card).
//
// Belongs to Spin2Win only.

import 'dart:async';

import 'package:flutter/material.dart';

import 'spin2win_dialog_frame.dart';
import 'spin2win_palette.dart';

const String kSpin2WinExitTitle = 'EXIT GAME';
const String kSpin2WinExitMessage = 'Do you want to exit?';

class Spin2WinExitDialog extends StatefulWidget {
  const Spin2WinExitDialog({super.key, this.autoCancel = true});

  /// Whether it answers "stay" by itself (a screenshot test turns it off).
  final bool autoCancel;

  /// How long the question waits before answering "stay" by itself.
  static const Duration autoCancelAfter = Duration(seconds: 5);

  /// Completes with true for YES, false for NO or the time running out, and null if the back
  /// gesture closed it.
  static Future<bool?> show(BuildContext context) {
    return spin2WinShowDialog<bool>(context, label: 'Exit game', builder: (_) => const Spin2WinExitDialog());
  }

  @override
  State<Spin2WinExitDialog> createState() => _Spin2WinExitDialogState();
}

class _Spin2WinExitDialogState extends State<Spin2WinExitDialog> {
  Timer? _timer;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoCancel) _timer = Timer(Spin2WinExitDialog.autoCancelAfter, () => _answer(false));
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
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: kSpin2WinExitTitle,
      child: Spin2WinDialogCard(
        key: const ValueKey('spin2win-exit-dialog'),
        width: 340,
        height: null,
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFF0C0), width: 2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFE07A), Color(0xFFFFB52E), Color(0xFFD98300)],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF663C00), offset: Offset(0, 4)),
                    BoxShadow(color: Color(0x73FFB52E), blurRadius: 14),
                  ],
                ),
                child: const Center(
                  child: Spin2WinOutlinedText('!', size: 30, height: 1, stroke: Color(0xFF7A4500), strokeWidth: 4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Spin2WinOutlinedText(
                kSpin2WinExitTitle,
                size: 22,
                height: 1,
                letterSpacing: 1.5,
                color: kS2wGold,
                strokeWidth: 4,
                stroke: Color(0xE63A1F96),
                shadows: [Shadow(color: Color(0x59000000), offset: Offset(0, 3))],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              kSpin2WinExitMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w600, color: Color(0xFFDCE6FA)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Spin2WinDialogButton(
                    key: const ValueKey('spin2win-exit-no'),
                    label: 'NO',
                    colors: const [Color(0xFF7DFFAE), Color(0xFF19D96B), Color(0xFF0A9A45)],
                    edge: const Color(0xFFC8FFDD),
                    under: const Color(0xFF04461F),
                    onTap: () => _answer(false),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Spin2WinDialogButton(
                    key: const ValueKey('spin2win-exit-yes'),
                    label: 'YES',
                    colors: const [Color(0xFFFF7A8E), Color(0xFFFF3155), Color(0xFFC8102E)],
                    edge: const Color(0xFFFFC2CC),
                    under: const Color(0xFF5E0716),
                    onTap: () => _answer(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
