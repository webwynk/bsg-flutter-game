// The header of the Lucky 16 Card screen, as the approved phone mockup draws it
// (reference-design/lucky16/lucky16-phone.html), which is Lucky Card's own header.
//
// Copied from lib/widgets/lucky_card/lucky_card_top_bar.dart (Lucky Card); only the names changed,
// so the two headers look and behave exactly alike. The dated decisions below are the user's,
// made for Lucky Card's header, and kept here because the user asked for the same look.
//
// One straight red bar, edge to edge (it is painted under a phone's notch as well, see
// [Lucky16TopBar.bleed]), with a gold line along its bottom edge only. It holds, from left
// to right: the EXIT ball, the balance (the BSG coin and the figure) in a sunken pill, then a
// flexible middle with the countdown and the line of words, and at the right the HISTORY,
// SOUND and RULES balls.
//
// Given plain values and four callbacks, nothing else: no provider (the binding in
// lucky16_top_bar_binding.dart connects it). In phone phase 1 the screen passes callbacks that do
// nothing for EXIT, HISTORY, SOUND and INFO (their dialogs and sounds are later phases), so the four
// balls are drawn lit but do nothing yet. A ball given no callback at all is drawn dimmed.
//
//   * The line of words in the middle is the game's status -- "PLACE YOUR CHIPS", or
//     "NO MORE PLAY" once betting closes -- and a refused tap borrows that same spot for a
//     moment, in red or amber ([statusColor]). The design draws no separate strip under the board,
//     and the game no longer has one.
//   * The countdown is the two digits on a purple disc. (A gold ring that emptied as the betting
//     window ran down used to go round it; the user had it removed, 2026-10-24.)
//   * RULES and HISTORY are dimmed and ignore taps while [infoEnabled] is false (betting is
//     closed or a result is playing): each opens a dialog that closes itself at the lock.
//     HISTORY is always drawn, even before the player has played a round.
//   * Each ball is DRAWN at the design's size but ANSWERS a tap over at least 48 dp, so the
//     design's look and spec §12.1 are both kept; a press pushes the ball down 2 dp, as the
//     design's own `button:active` does.
//   * No text follows the phone's font-size setting.
//
// The colours all come from lucky16_palette.dart, which was read out of the design.
//
// Belongs to Lucky 16 Card only.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'lucky16_art.dart';
import 'lucky16_layout.dart';
import 'lucky16_palette.dart';

/// The countdown as two digits: 90, 07, 00.
String lucky16CountdownText(int seconds) => seconds.clamp(0, 99).toString().padLeft(2, '0');

/// What a screen reader says for the balance.
String lucky16BalanceSemantics(int balance) => 'Balance: ${lucky16GroupedBalance(balance)} coins';

/// The countdown is red from 5 seconds down to 1; at 0 the round is being drawn.
bool lucky16CountdownUrgent(int seconds) => seconds >= 1 && seconds <= 5;

/// A number with a comma every three digits: 129695 is "129,695".
String lucky16GroupedBalance(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Text in the design's own number face, which never follows the phone's font setting.
Text _oswald(String text,
        {required double size, required Color color, double spacing = 0, Color? shadow, TextOverflow? overflow}) =>
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

/// Text in DM Sans, the face of the header's line of words. Like [_oswald], it never follows the
/// phone's font setting.
Text _dmSans(String text,
        {required double size, required Color color, double spacing = 0, Color? shadow, TextOverflow? overflow}) =>
    Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: overflow ?? TextOverflow.visible,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w800,
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
class Lucky16TopButton extends StatefulWidget {
  const Lucky16TopButton({
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
  State<Lucky16TopButton> createState() => _Lucky16TopButtonState();
}

class _Lucky16TopButtonState extends State<Lucky16TopButton> {
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
        gradient: lucky16BallGradient(widget.fill),
        boxShadow: _pressed ? null : [BoxShadow(color: widget.under, offset: Offset(0, drop))],
      ),
      child: Center(
        // Icon size increased per user instruction (not the icon box).
        child: Icon(widget.icon, size: math.max(widget.size * 0.58, 20), color: const Color(0xFFFFFFFF)),
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
class Lucky16BalanceBox extends StatelessWidget {
  const Lucky16BalanceBox({super.key, required this.layout, required this.art, required this.balance});

  final Lucky16Layout layout;
  final Lucky16Art art;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final height = layout.designPillHeight;
    final coin = layout.designCoinSize;
    return Semantics(
      label: lucky16BalanceSemantics(balance),
      excludeSemantics: true,
      child: Container(
        height: height,
        padding: EdgeInsets.only(left: height * 0.1, right: height * 0.32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: kLucky16BalanceWell,
          ),
          boxShadow: const [BoxShadow(color: kLucky16GlossTopSoft, offset: Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              key: const ValueKey('top-coin'),
              image: art.image(Lucky16ArtKey.coin,
                  cacheWidth: layout.coinCacheWidth(MediaQuery.devicePixelRatioOf(context))),
              width: coin,
              height: coin,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
            SizedBox(width: height * 0.19),
            _oswald(
              lucky16GroupedBalance(balance),
              size: layout.designBalanceFont,
              color: kLucky16BalanceText,
              spacing: 0.5,
              shadow: const Color(0xFF000000),
            ),
          ],
        ),
      ),
    );
  }
}

/// The countdown: the number on a purple disc [Lucky16Layout.designCountdownSize] across. It does
/// not change look as the window runs down; the last five seconds are shown by the words beside it,
/// which flash.
class Lucky16CountdownBox extends StatelessWidget {
  const Lucky16CountdownBox({super.key, required this.layout, required this.seconds});

  final Lucky16Layout layout;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final size = layout.designCountdownSize;
    return Semantics(
      label: 'Time left: $seconds seconds',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment(-0.3, -0.4),
            radius: 0.9,
            colors: kLucky16CountdownDisc,
          ),
        ),
        child: _oswald(
          lucky16CountdownText(seconds),
          size: layout.designCountdownFont,
          color: kLucky16CountdownText,
          shadow: kLucky16CountdownShadow,
        ),
      ),
    );
  }
}

/// The line of words in the middle of the header, in DM Sans, which fades in and out while [flashing]
/// (the last five seconds of betting), exactly as the strip under the board used to.
/// The phone's "remove animations" setting stops the fading; the words still change.
class Lucky16StatusLine extends StatefulWidget {
  const Lucky16StatusLine({
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
  State<Lucky16StatusLine> createState() => _Lucky16StatusLineState();
}

class _Lucky16StatusLineState extends State<Lucky16StatusLine> with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(vsync: this, duration: Lucky16StatusLine.flashPeriod);

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
  void didUpdateWidget(Lucky16StatusLine oldWidget) {
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
    final line = _dmSans(
      widget.text.toUpperCase(),
      size: widget.size,
      color: widget.color,
      spacing: 1,
      shadow: kLucky16StatusShadow,
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
class Lucky16TopBar extends StatelessWidget {
  const Lucky16TopBar({
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

  final Lucky16Layout layout;
  final Lucky16Art art;

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
  /// caller (usually a `Lucky16StatusLine`, key `top-status`) and placed as-is, not
  /// reconstructed here -- see lucky16_top_bar_binding.dart's
  /// `_Lucky16HeaderStatusSlot` for why: it must keep its own identity across a balance or
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

    Widget ball(String key, IconData icon, String label, List<Color> fill, Color under, VoidCallback? onTap,
            {bool enabled = true}) =>
        Lucky16TopButton(
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
                colors: kLucky16BarFill,
                stops: [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(color: kLucky16BarUnder, offset: Offset(0, bar.height * 0.08)),
                BoxShadow(
                    color: kLucky16DropShadow, blurRadius: bar.height * 0.32, offset: Offset(0, bar.height * 0.16)),
              ],
            ),
            // The gold line is painted over the finished bar (a `Border` inside `decoration` would
            // inset the child), as the rim was before.
            foregroundDecoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: kLucky16BarRim, width: rim)),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: bar,
          child: Container(
            key: const ValueKey('top-bar'),
            padding: const EdgeInsets.only(left: 30, right: 30),
            child: Row(
              children: [
                ball('top-exit', Icons.logout_rounded, 'Exit the game', kLucky16ExitFill, kLucky16ExitUnder, onExit),
                SizedBox(width: gap),
                Lucky16BalanceBox(key: const ValueKey('top-balance'), layout: layout, art: art, balance: balance),
                SizedBox(width: gap),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lucky16CountdownBox(key: const ValueKey('top-countdown'), layout: layout, seconds: countdown),
                      SizedBox(width: layout.designHeaderGap),
                      Flexible(child: statusWidget),
                    ],
                  ),
                ),
                SizedBox(width: gap),
                ball('top-history', Icons.history_rounded, 'Game history', kLucky16HistoryFill, kLucky16HistoryUnder,
                    onHistory,
                    enabled: infoEnabled),
                SizedBox(width: gap),
                ball(
                    'top-sound',
                    soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    soundOn ? 'Sound on, tap to mute' : 'Sound off, tap to turn on',
                    kLucky16SoundFill,
                    kLucky16SoundUnder,
                    onToggleSound),
                SizedBox(width: gap),
                ball('top-info', Icons.info_outline_rounded, 'How to play', kLucky16RulesFill, kLucky16RulesUnder,
                    onInfo,
                    enabled: infoEnabled),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
