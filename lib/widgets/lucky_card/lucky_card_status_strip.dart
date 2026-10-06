// The status strip under the board: what the table is doing, in words.
//
//   * betting is open:                 "PLACE YOUR CHIPS"
//   * betting closed, 5 to 1 s left:   "NO MORE PLAY", flashing
//   * the wheel, the card and the win: "NO MORE PLAY", steady (a small deliberate
//     difference from Triple Chance, which goes back to "Place your chips" while
//     the wheel turns, spec §17W)
//
// Given the mode, nothing else. The flash stops when the phone's "reduce motion"
// setting is on (the words still change). The text never follows the phone's
// font-size setting.
//
// Belongs to Lucky Card only.

import 'package:flutter/material.dart';

import 'lucky_card_layout.dart';
import 'lucky_card_panel.dart';
import 'lucky_card_stake_text.dart';

enum LuckyCardStatusMode {
  /// Betting is open.
  placeChips,

  /// Betting has just closed: the last seconds, flashing.
  noMoreFlashing,

  /// Betting is closed and the round is being drawn, spun and shown.
  noMoreSteady,
}

/// The words of each mode.
String luckyCardStatusText(LuckyCardStatusMode mode) =>
    mode == LuckyCardStatusMode.placeChips ? 'PLACE YOUR CHIPS' : 'NO MORE PLAY';

class LuckyCardStatusStrip extends StatefulWidget {
  const LuckyCardStatusStrip({super.key, required this.layout, required this.mode, this.notice, this.noticeImportant = false});

  final LuckyCardLayout layout;
  final LuckyCardStatusMode mode;

  /// A short line shown in place of the words (a refused tap, a warning about the balance), or
  /// null. An ordinary line shows only while betting is open; an important one always.
  final String? notice;
  final bool noticeImportant;

  /// The colour of a notice (amber, as Triple Chance's balance warning).
  static const Color noticeColor = Color(0xFFFFA500);

  /// One flash: bright to dim and back.
  static const Duration flashPeriod = Duration(milliseconds: 700);

  @override
  State<LuckyCardStatusStrip> createState() => _LuckyCardStatusStripState();
}

class _LuckyCardStatusStripState extends State<LuckyCardStatusStrip> with SingleTickerProviderStateMixin {
  late final AnimationController _flash =
      AnimationController(vsync: this, duration: LuckyCardStatusStrip.flashPeriod);

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(LuckyCardStatusStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Runs the flash only while the mode asks for it (and motion is allowed).
  void _sync() {
    final flashing = widget.mode == LuckyCardStatusMode.noMoreFlashing && !_reduceMotion;
    if (flashing && !_flash.isAnimating) {
      _flash.repeat(reverse: true);
    } else if (!flashing && (_flash.isAnimating || _flash.value != 0)) {
      _flash.stop();
      _flash.value = 0;
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final closed = widget.mode != LuckyCardStatusMode.placeChips;
    final notice = widget.notice;
    final showNotice = notice != null && (!closed || widget.noticeImportant);
    final text = showNotice ? notice : luckyCardStatusText(widget.mode);
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: LuckyCardPanel(
        layout: layout,
        radiusUnits: 20,
        child: AnimatedBuilder(
          animation: _flash,
          builder: (context, child) => Opacity(opacity: 1.0 - 0.7 * _flash.value, child: child),
          child: LayoutBuilder(
            builder: (context, c) => LuckyCardStakeText(
              text,
              maxWidth: c.maxWidth,
              preferredSize: layout.fontSize(44),
              color: showNotice ? LuckyCardStatusStrip.noticeColor : (closed ? kLuckyCardAlert : kLuckyCardCream),
            ),
          ),
        ),
      ),
    );
  }
}
