// The Spin2Win top bar, as the reference design draws it (40 dp tall, 30 dp in from each side on
// the phone): the red EXIT button, the coin box with the balance, the PLAY / WIN bar, and the round
// trophy (My Records) and sound buttons. When a win is paid in, the coin box and the WIN figure bump
// twice (the design's `coinbump`).
//
// Given the numbers to show and what each button does, nothing else: no provider. A button with
// no handler still draws, so the frame can be shown before it is wired up.
//
// Belongs to Spin2Win only.

import 'package:flutter/widgets.dart';

import 'spin2win_bump.dart';
import 'spin2win_icons.dart';
import 'spin2win_palette.dart';

class Spin2WinTopBar extends StatelessWidget {
  const Spin2WinTopBar({
    super.key,
    required this.balance,
    required this.play,
    required this.win,
    required this.muted,
    this.winKey,
    this.onExit,
    this.onRecords,
    this.onSound,
    this.sidePadding = 30,
  });

  /// In from each side: the phone's 30 dp (the tablet's 21, the desktop's none).
  final double sidePadding;

  final int balance;

  /// The coins on the board this round.
  final int play;

  /// What the last round paid.
  final int win;
  final bool muted;

  /// The winning round just paid in; a new one bumps the coin box and the WIN figure.
  final Object? winKey;
  final VoidCallback? onExit;
  final VoidCallback? onRecords;
  final VoidCallback? onSound;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sidePadding),
      child: Row(
        children: [
          _Tap(
            key: const ValueKey('spin2win-exit'),
            label: 'Exit game',
            onTap: onExit,
            child: Spin2WinGlossBox(
              width: 42,
              height: 36,
              radius: 10,
              borderWidth: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFC2CC), width: 2),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFF7A8E), Color(0xFFFF3155), Color(0xFFC8102E)],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF5E0716), offset: Offset(0, 4)),
                  BoxShadow(color: Color(0x80000000), offset: Offset(0, 6), blurRadius: 10),
                ],
              ),
              child: const Center(
                child: CustomPaint(size: Size(22, 22), painter: Spin2WinExitIconPainter()),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Spin2WinBump(bumpKey: winKey, child: _CoinBox(balance: balance)),
          const SizedBox(width: 8),
          Expanded(child: _PlayWinBar(play: play, win: win, winKey: winKey)),
          const SizedBox(width: 8),
          _RoundButton(
            key: const ValueKey('spin2win-records'),
            label: 'Open records',
            onTap: onRecords,
            icon: const CustomPaint(size: Size(24, 24), painter: Spin2WinTrophyPainter()),
          ),
          const SizedBox(width: 8),
          _RoundButton(
            key: const ValueKey('spin2win-sound'),
            label: muted ? 'Sound off' : 'Sound on',
            onTap: onSound,
            icon: CustomPaint(size: const Size(20, 20), painter: Spin2WinSpeakerPainter(muted: muted)),
          ),
        ],
      ),
    );
  }
}

/// A tap area with a screen-reader label around a drawn button.
class _Tap extends StatelessWidget {
  const _Tap({super.key, required this.label, required this.onTap, required this.child});

  final String label;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
      );
}

/// The design's sunken navy box that holds a number (the balance, PLAY and WIN).
BoxDecoration _well({Border? border}) => BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: border,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF02081C), kS2wNavyWell],
        stops: [0, 0.3],
      ),
    );

const TextStyle _digits = TextStyle(
  fontFamily: kSpin2WinDigitsFont,
  fontWeight: FontWeight.w600,
  fontSize: 17,
  letterSpacing: 0.6,
  color: kS2wGold,
  height: 1,
);

class _CoinBox extends StatelessWidget {
  const _CoinBox({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('spin2win-balance'),
      width: 220,
      height: 36,
      padding: const EdgeInsets.fromLTRB(4, 0, 3, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kS2wGoldBorder, width: 2),
        gradient: kS2wBarFill,
        boxShadow: const [
          BoxShadow(color: kS2wGoldUnder, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x80000000), offset: Offset(0, 6), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          const CustomPaint(size: Size(28, 26), painter: Spin2WinCoinStackPainter()),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.centerRight,
              decoration: _well(),
              child: Spin2WinCapsCentred(
                digitsFont: true,
                size: _digits.fontSize!,
                child: Text(
                  spin2WinAmountText(balance),
                  maxLines: 1,
                  style: _digits.copyWith(
                    shadows: const [Shadow(color: Color(0x99FFB52E), blurRadius: 8)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayWinBar extends StatelessWidget {
  const _PlayWinBar({required this.play, required this.win, required this.winKey});

  final int play;
  final int win;
  final Object? winKey;

  static const TextStyle _label = TextStyle(
    fontFamily: kSpin2WinDigitsFont,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    height: 1,
    letterSpacing: 0.6,
    color: Color(0xFFFFFFFF),
    shadows: [Shadow(color: Color(0x80000000), offset: Offset(0, 2))],
  );

  @override
  Widget build(BuildContext context) {
    Widget value(String key, int amount, {Object? bumpKey}) => Expanded(
          child: Spin2WinBump(
            bumpKey: bumpKey,
            child: Container(
              key: ValueKey(key),
              height: 26,
              alignment: Alignment.center,
              decoration: _well(border: Border.all(color: const Color(0x991677FF))),
              child: Spin2WinCapsCentred(
                digitsFont: true,
                size: _digits.fontSize!,
                child: Text(spin2WinAmountText(amount), maxLines: 1, style: _digits),
              ),
            ),
          ),
        );
    return Container(
      height: 36,
      padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kS2wCyan, width: 2),
        gradient: kS2wBarFill,
        boxShadow: const [
          BoxShadow(color: Color(0xFF003A58), offset: Offset(0, 4)),
          BoxShadow(color: Color(0x80000000), offset: Offset(0, 6), blurRadius: 10),
          BoxShadow(color: Color(0x4000E5FF), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Spin2WinCapsCentred(digitsFont: true, size: _label.fontSize!, child: const Text('PLAY:', style: _label)),
          const SizedBox(width: 8),
          value('spin2win-play', play),
          const SizedBox(width: 8),
          Spin2WinCapsCentred(digitsFont: true, size: _label.fontSize!, child: const Text('WIN:', style: _label)),
          const SizedBox(width: 8),
          value('spin2win-win', win, bumpKey: winKey),
        ],
      ),
    );
  }
}

/// The blue round button with a gold rim (trophy and sound).
class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.label, required this.onTap, required this.icon});

  final String label;
  final VoidCallback? onTap;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return _Tap(
      label: label,
      onTap: onTap,
      child: Spin2WinGlossBox(
        width: 38,
        height: 38,
        circle: true,
        borderWidth: 2,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: kS2wGoldBorder, width: 2)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6FB0FF), Color(0xFF1677FF), Color(0xFF0A4FC4)],
          ),
          boxShadow: [
            BoxShadow(color: Color(0xFF052866), offset: Offset(0, 4)),
            BoxShadow(color: Color(0x80000000), offset: Offset(0, 6), blurRadius: 10),
          ],
        ),
        child: Center(child: icon),
      ),
    );
  }
}
