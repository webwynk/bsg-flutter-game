// The header of the Lucky Card screen, built to the reference design
// (reference-design/royal-cards-standalone/, the phone layout).
//
// One straight red bar, edge to edge (it is painted under a phone's notch as well, see
// [LuckyCardTopBar.bleed]), with a gold line along its bottom edge only. It holds, from left
// to right: the EXIT ball, the balance (the BSG coin and the figure) in a sunken pill, then a
// flexible middle with the countdown ring and the line of words, and at the right the HISTORY,
// SOUND and RULES balls.
//
// Given plain values and four callbacks, nothing else: no provider (the binding in
// lucky_card_readouts_binding.dart connects it).
//
//   * The line of words in the middle is the game's status -- "PLACE YOUR CHIPS", or
//     "NO MORE PLAY" once betting closes -- and a refused tap borrows that same spot for a
//     moment, in red or amber ([statusColor]). The design draws no separate strip under the board,
//     and the game no longer has one.
//   * The countdown sits in a gold ring that empties as the betting window runs down.
//   * RULES and HISTORY are dimmed and ignore taps while [infoEnabled] is false (betting is
//     closed or a result is playing): each opens a dialog that closes itself at the lock.
//     HISTORY is always drawn, even before the player has played a round.
//   * Each ball is DRAWN at the design's size but ANSWERS a tap over at least 48 dp, so the
//     design's look and spec §12.1 are both kept; a press pushes the ball down 2 dp, as the
//     design's own `button:active` does.
//   * No text follows the phone's font-size setting.
//
// The colours all come from lucky_card_palette.dart, which was read out of the design.
//
// Belongs to Lucky Card only.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/lucky_card_round_clock.dart';
import 'lucky_card_art.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_palette.dart';

/// The countdown as two digits: 90, 07, 00.
String luckyCardCountdownText(int seconds) => seconds.clamp(0, 99).toString().padLeft(2, '0');

/// What a screen reader says for the balance.
String luckyCardBalanceSemantics(int balance) => 'Balance: ${luckyCardGroupedBalance(balance)} coins';

/// The countdown is red from 5 seconds down to 1; at 0 the round is being drawn.
bool luckyCardCountdownUrgent(int seconds) => seconds >= 1 && seconds <= 5;

/// How full the countdown ring is: all of it at the start of the betting window, none of it
/// once the window has run out.
double luckyCardCountdownFraction(int seconds) =>
    (seconds / kLuckyCardCountdownStart).clamp(0.0, 1.0).toDouble();

/// A number with a comma every three digits: 129695 is "129,695".
String luckyCardGroupedBalance(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Text in the design's own number face, which never follows the phone's font setting.
Text _oswald(String text, {required double size, required Color color, double spacing = 0, Color? shadow, TextOverflow? overflow}) =>
    Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: overflow ?? TextOverflow.visible,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: 'Oswald',
        fontWeight: FontWeight.w700,
        fontSize: size,
        height: 1.0,
        letterSpacing: spacing,
        color: color,
        shadows: shadow == null ? null : [Shadow(color: shadow, offset: const Offset(0, 2))],
      ),
    );

/// One round button of the header: a lit ball with a gold rim and a hard shadow under it.
///
/// It is drawn [size] across and centred in a tap area [hit] across, which is at least
/// 48 dp. A press pushes it down 2 dp and takes its shadow away, as the design does.
class LuckyCardTopButton extends StatefulWidget {
  const LuckyCardTopButton({
    super.key,
    required this.size,
    required this.hit,
    required this.fill,
    required this.under,
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
    this.enabled = true,
  });

  /// The ball as drawn, and the square that answers a tap.
  final double size;
  final double hit;

  /// The light, middle and dark of the ball, and the hard shadow beneath it.
  final List<Color> fill;
  final Color under;

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<LuckyCardTopButton> createState() => _LuckyCardTopButtonState();
}

class _LuckyCardTopButtonState extends State<LuckyCardTopButton> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (_pressed != pressed && mounted) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    final drop = math.max(widget.size * 0.07, 1.5);
    // No gold rim on the ball itself (user, 2026-10-23: the bar's own rim is enough; a ring
    // on every small button crowded the header). The icon is drawn a little smaller too, for
    // the same reason.
    final ball = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      width: widget.size,
      height: widget.size,
      transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: designBallGradient(widget.fill),
        boxShadow: _pressed ? null : [BoxShadow(color: widget.under, offset: Offset(0, drop))],
      ),
      child: Center(
        // Never under 14 dp (the same icon floor used everywhere else in Lucky Card), even
        // where the design's own 0.4 share would dip just under it on the smallest phone.
        child: Icon(widget.icon, size: math.max(widget.size * 0.4, 14), color: const Color(0xFFFFFFFF)),
      ),
    );
    return Semantics(
      button: true,
      enabled: active,
      excludeSemantics: true,
      label: widget.semanticsLabel,
      onTap: active ? widget.onTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? widget.onTap : null,
        onTapDown: active ? (_) => _set(true) : null,
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: SizedBox(
          width: widget.hit,
          height: widget.hit,
          child: Center(child: active ? ball : Opacity(opacity: 0.4, child: ball)),
        ),
      ),
    );
  }
}

/// The balance: the BSG coin and the figure, in a pill sunk into the bar.
class LuckyCardBalanceBox extends StatelessWidget {
  const LuckyCardBalanceBox({super.key, required this.layout, required this.art, required this.balance});

  final LuckyCardLayout layout;
  final LuckyCardArt art;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final height = layout.designPillHeight;
    final coin = layout.designCoinSize;
    return Semantics(
      label: luckyCardBalanceSemantics(balance),
      excludeSemantics: true,
      child: Container(
        height: height,
        padding: EdgeInsets.only(left: height * 0.1, right: height * 0.32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: kDesignBalanceWell,
          ),
          boxShadow: const [BoxShadow(color: kDesignGlossTopSoft, offset: Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              key: const ValueKey('top-coin'),
              image: art.image(LuckyCardArtKey.coin, cacheWidth: layout.coinCacheWidth(MediaQuery.devicePixelRatioOf(context))),
              width: coin,
              height: coin,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
            SizedBox(width: height * 0.19),
            _oswald(
              luckyCardGroupedBalance(balance),
              size: layout.designBalanceFont,
              color: kDesignBalanceText,
              spacing: 0.5,
              shadow: const Color(0xFF000000),
            ),
          ],
        ),
      ),
    );
  }
}

/// The countdown: a gold ring that empties as the betting window runs down, around a purple
/// disc holding the number.
class LuckyCardCountdownBox extends StatelessWidget {
  const LuckyCardCountdownBox({super.key, required this.layout, required this.seconds});

  final LuckyCardLayout layout;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final size = layout.designCountdownSize;
    final urgent = luckyCardCountdownUrgent(seconds);
    final left = luckyCardCountdownFraction(seconds);
    return Semantics(
      label: 'Time left: $seconds seconds',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // The ring: gold for the share of the window still to run, dark for the rest.
          gradient: SweepGradient(
            transform: const GradientRotation(-math.pi / 2),
            colors: [
              urgent ? kDesignAlertText : kDesignRing,
              urgent ? kDesignAlertText : kDesignRing,
              kDesignRingSpent,
              kDesignRingSpent,
            ],
            stops: [0.0, left, left, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: (urgent ? kDesignAlertText : kDesignRing).withValues(alpha: 0.55),
              blurRadius: size * 0.25,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: size * 0.82,
            height: size * 0.82,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.4),
                radius: 0.9,
                colors: kDesignCountdownDisc,
              ),
            ),
            child: _oswald(
              luckyCardCountdownText(seconds),
              size: layout.designCountdownFont,
              color: kDesignCountdownText,
              shadow: kDesignCountdownShadow,
            ),
          ),
        ),
      ),
    );
  }
}

/// The line of words in the middle of the header, which fades in and out while [flashing]
/// (the last five seconds of betting), exactly as the strip under the board used to.
/// The phone's "remove animations" setting stops the fading; the words still change.
class LuckyCardStatusLine extends StatefulWidget {
  const LuckyCardStatusLine({
    super.key,
    required this.text,
    required this.size,
    required this.color,
    required this.flashing,
  });

  final String text;
  final double size;
  final Color color;
  final bool flashing;

  /// One fade out and back.
  static const Duration flashPeriod = Duration(milliseconds: 700);

  @override
  State<LuckyCardStatusLine> createState() => _LuckyCardStatusLineState();
}

class _LuckyCardStatusLineState extends State<LuckyCardStatusLine> with SingleTickerProviderStateMixin {
  late final AnimationController _flash =
      AnimationController(vsync: this, duration: LuckyCardStatusLine.flashPeriod);

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
  void didUpdateWidget(LuckyCardStatusLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Runs the flash only while it is asked for and motion is allowed.
  void _sync() {
    final flashing = widget.flashing && !_reduceMotion;
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
    final line = _oswald(
      widget.text.toUpperCase(),
      size: widget.size,
      color: widget.color,
      spacing: 1,
      shadow: kDesignStatusShadow,
      overflow: TextOverflow.ellipsis,
    );
    return Semantics(
      liveRegion: true,
      label: widget.text,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _flash,
        builder: (context, child) => Opacity(opacity: 1.0 - 0.7 * _flash.value, child: child),
        child: line,
      ),
    );
  }
}

/// The whole header, filling the top-bar zone.
class LuckyCardTopBar extends StatelessWidget {
  const LuckyCardTopBar({
    super.key,
    required this.layout,
    required this.art,
    required this.balance,
    required this.countdown,
    required this.soundOn,
    required this.infoEnabled,
    required this.statusWidget,
    this.bleed = EdgeInsets.zero,
    this.onExit,
    this.onToggleSound,
    this.onInfo,
    this.onHistory,
  });

  final LuckyCardLayout layout;
  final LuckyCardArt art;

  /// How far the bar's paint reaches past the zone to the left, top and right: the phone's own
  /// safe-area insets (a notch or a camera cut-out), so the bar runs edge to edge while its
  /// content stays inside the safe area (the user's decision of 2026-10-23). Zero on a phone
  /// with no such inset.
  final EdgeInsets bleed;
  final int balance;
  final int countdown;
  final bool soundOn;

  /// Whether RULES and HISTORY may be used: betting is open and nothing is playing.
  final bool infoEnabled;

  /// The line of words in the middle: the status, or a refused tap's warning. Built by the
  /// caller (usually a `LuckyCardStatusLine`, key `top-status`) and placed as-is, not
  /// reconstructed here -- see lucky_card_readouts_binding.dart's
  /// `_LuckyCardHeaderStatusSlot` for why: it must keep its own identity across a balance or
  /// countdown change, which rebuilds everything else in this row.
  final Widget statusWidget;

  final VoidCallback? onExit;
  final VoidCallback? onToggleSound;
  final VoidCallback? onInfo;
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    final bar = layout.designHeaderBar;
    final size = layout.designBallSize;
    final hit = layout.designBallHit;
    // The tap areas are wider than the balls, so the gap between them is reduced by as much,
    // leaving the DRAWN spacing the design's own.
    final gap = math.max(layout.designHeaderGap - (hit - size), 0.0);
    final rim = math.max(bar.height * 0.04, 1.2);

    Widget ball(String key, IconData icon, String label, List<Color> fill, Color under, VoidCallback? onTap, {bool enabled = true}) =>
        LuckyCardTopButton(
          key: ValueKey(key),
          size: size,
          hit: hit,
          fill: fill,
          under: under,
          icon: icon,
          semanticsLabel: label,
          onTap: onTap,
          enabled: enabled,
        );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The bar's paint: straight, edge to edge (past the zone by the phone's insets), with the
        // gold line along its bottom edge only. Painted apart from the row below so the row's tap
        // areas and the zone stay exactly the bar's own size.
        Positioned(
          left: bar.left - bleed.left,
          top: bar.top - bleed.top,
          width: bar.width + bleed.left + bleed.right,
          height: bar.height + bleed.top,
          child: Container(
            key: const ValueKey('top-bar-back'),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: kDesignBarFill,
                stops: [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(color: kDesignBarUnder, offset: Offset(0, bar.height * 0.08)),
                BoxShadow(color: kDesignDropShadow, blurRadius: bar.height * 0.32, offset: Offset(0, bar.height * 0.16)),
              ],
            ),
            // The gold line is painted over the finished bar (a `Border` inside `decoration` would
            // inset the child), as the rim was before.
            foregroundDecoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: kDesignBarRim, width: rim)),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: bar,
          child: Container(
            key: const ValueKey('top-bar'),
            padding: EdgeInsets.symmetric(horizontal: layout.designHeaderPad),
            child: Row(
              children: [
                ball('top-exit', Icons.logout_rounded, 'Exit the game', kDesignExitFill, kDesignExitUnder, onExit),
                SizedBox(width: gap),
                LuckyCardBalanceBox(key: const ValueKey('top-balance'), layout: layout, art: art, balance: balance),
                SizedBox(width: gap),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LuckyCardCountdownBox(key: const ValueKey('top-countdown'), layout: layout, seconds: countdown),
                      SizedBox(width: layout.designHeaderGap),
                      Flexible(child: statusWidget),
                    ],
                  ),
                ),
                SizedBox(width: gap),
                ball('top-history', Icons.history_rounded, 'Game history', kDesignHistoryFill, kDesignHistoryUnder, onHistory, enabled: infoEnabled),
                SizedBox(width: gap),
                ball('top-sound', soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    soundOn ? 'Sound on, tap to mute' : 'Sound off, tap to turn on', kDesignSoundFill, kDesignSoundUnder, onToggleSound),
                SizedBox(width: gap),
                ball('top-info', Icons.info_outline_rounded, 'How to play', kDesignRulesFill, kDesignRulesUnder, onInfo, enabled: infoEnabled),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
