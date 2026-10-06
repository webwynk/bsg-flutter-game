// The top bar of the Lucky Card screen: EXIT at the left, the balance beside it, the
// countdown in the middle, SOUND and INFO at the right.
//
// Given plain values and three callbacks, nothing else: no provider (the binding in
// lucky_card_readouts_binding.dart connects it). The bar is 134 units high so that
// each button has a tap area of at least 48 dp; the button is drawn smaller, in the
// middle of its tap area, and a tap anywhere in the area counts.
//
//   * EXIT, SOUND and INFO call their callbacks. What they do (leave the screen,
//     mute, open the rules) is the screen's business, built in App Step 8 and 7b.
//   * INFO is dimmed and ignores taps while [infoEnabled] is false (betting is
//     closed or a result is playing), as in Triple Chance.
//   * The countdown is two digits ("90" to "00") and turns red for the last five
//     seconds.
//   * The text never follows the phone's font-size setting.
//
// Belongs to Lucky Card only.

import 'package:flutter/material.dart';

import 'lucky_card_layout.dart';
import 'lucky_card_panel.dart';
import 'lucky_card_stake_text.dart';

/// The countdown as two digits: 90, 07, 00.
String luckyCardCountdownText(int seconds) => seconds.clamp(0, 99).toString().padLeft(2, '0');

/// What a screen reader says for the balance.
String luckyCardBalanceSemantics(int balance) => 'Balance: ${luckyCardGrouped(balance)} coins';

/// The countdown is red from 5 seconds down to 1; at 0 the round is being drawn.
bool luckyCardCountdownUrgent(int seconds) => seconds >= 1 && seconds <= 5;

/// One round button of the top bar, with its tap area.
class LuckyCardTopButton extends StatefulWidget {
  const LuckyCardTopButton({
    super.key,
    required this.layout,
    required this.hit,
    required this.drawn,
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
    this.enabled = true,
  });

  final LuckyCardLayout layout;

  /// The tap area and the button as drawn, both in the top bar's own coordinates.
  final Rect hit;
  final Rect drawn;

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
    final drawn = widget.drawn.shift(-widget.hit.topLeft);
    final iconSize = widget.layout.fontSize(widget.drawn.width / widget.layout.scale * 0.55, minDp: 14);
    return Positioned.fromRect(
      rect: widget.hit,
      child: Semantics(
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
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: drawn,
                child: AnimatedScale(
                  scale: _pressed ? 0.9 : 1.0,
                  duration: const Duration(milliseconds: 90),
                  child: LuckyCardPanel(
                    layout: widget.layout,
                    dimmed: !active,
                    radiusUnits: 50,
                    child: Center(child: Icon(widget.icon, size: iconSize, color: kLuckyCardCream)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The balance: a small gold coin and the number.
class LuckyCardBalanceBox extends StatelessWidget {
  const LuckyCardBalanceBox({super.key, required this.layout, required this.balance});

  final LuckyCardLayout layout;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final coin = layout.dp(58);
    return Semantics(
      label: luckyCardBalanceSemantics(balance),
      excludeSemantics: true,
      child: LuckyCardPanel(
        layout: layout,
        padding: EdgeInsets.symmetric(horizontal: layout.dp(18)),
        child: Row(
          children: [
            Container(
              width: coin,
              height: coin,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFE680), Color(0xFFD4AF37), Color(0xFF8B6914)],
                  stops: [0.0, 0.6, 1.0],
                ),
                border: Border.all(color: const Color(0xFF8B6914), width: 1),
              ),
            ),
            SizedBox(width: layout.dp(14)),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => LuckyCardStakeText(
                  luckyCardGrouped(balance),
                  maxWidth: c.maxWidth,
                  preferredSize: layout.fontSize(54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The countdown.
class LuckyCardCountdownBox extends StatelessWidget {
  const LuckyCardCountdownBox({super.key, required this.layout, required this.seconds});

  final LuckyCardLayout layout;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final urgent = luckyCardCountdownUrgent(seconds);
    return Semantics(
      label: 'Time left: $seconds seconds',
      excludeSemantics: true,
      child: LuckyCardPanel(
        layout: layout,
        highlighted: urgent,
        radiusUnits: 24,
        child: LayoutBuilder(
          builder: (context, c) => LuckyCardStakeText(
            luckyCardCountdownText(seconds),
            maxWidth: c.maxWidth,
            preferredSize: layout.fontSize(84),
            color: urgent ? kLuckyCardAlert : kLuckyCardGoldBright,
          ),
        ),
      ),
    );
  }
}

/// The whole bar, filling the top-bar zone.
class LuckyCardTopBar extends StatelessWidget {
  const LuckyCardTopBar({
    super.key,
    required this.layout,
    required this.balance,
    required this.countdown,
    required this.soundOn,
    required this.infoEnabled,
    this.onExit,
    this.onToggleSound,
    this.onInfo,
  });

  final LuckyCardLayout layout;
  final int balance;
  final int countdown;
  final bool soundOn;
  final bool infoEnabled;
  final VoidCallback? onExit;
  final VoidCallback? onToggleSound;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final bar = layout.topBar;
    Rect inBar(Rect r) => layout.within(bar, r);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(rect: inBar(layout.balanceBox), child: LuckyCardBalanceBox(key: const ValueKey('top-balance'), layout: layout, balance: balance)),
        Positioned.fromRect(rect: inBar(layout.countdownBox), child: LuckyCardCountdownBox(key: const ValueKey('top-countdown'), layout: layout, seconds: countdown)),
        LuckyCardTopButton(
          key: const ValueKey('top-exit'),
          layout: layout,
          hit: inBar(layout.exitHit),
          drawn: inBar(layout.exitButton),
          icon: Icons.logout_rounded,
          semanticsLabel: 'Exit the game',
          onTap: onExit,
        ),
        LuckyCardTopButton(
          key: const ValueKey('top-sound'),
          layout: layout,
          hit: inBar(layout.soundHit),
          drawn: inBar(layout.soundButton),
          icon: soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          semanticsLabel: soundOn ? 'Sound on, tap to mute' : 'Sound off, tap to turn on',
          onTap: onToggleSound,
        ),
        LuckyCardTopButton(
          key: const ValueKey('top-info'),
          layout: layout,
          hit: inBar(layout.infoHit),
          drawn: inBar(layout.infoButton),
          icon: Icons.info_outline_rounded,
          semanticsLabel: 'How to play',
          onTap: onInfo,
          enabled: infoEnabled,
        ),
      ],
    );
  }
}
