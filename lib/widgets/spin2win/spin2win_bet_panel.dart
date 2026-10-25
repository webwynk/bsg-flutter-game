// The Spin2Win betting panel, as the reference design draws it right of the wheel: the ten number
// cards (0 to 4 over 5 to 9) with the coins on each, the row of five chips, the ODD and EVEN
// buttons over DOUBLE (REBET after a round), REMOVE and CLEAR, and the green timer.
//
// Given what to show and what each tap does, nothing else: no provider (spin2win_frame_binding.dart
// connects it). What the buttons allow, exactly as Triple Chance's:
//   * while betting is closed everything is dimmed and ignores taps;
//   * DOUBLE (and CLEAR and REMOVE) work only while there is a bet; REBET takes DOUBLE's place
//     when the board is empty and an earlier bet exists, and is dimmed when the player cannot
//     afford it;
//   * a dimmed button is drawn at 40%, the way Triple Chance draws it.
//
// Belongs to Spin2Win only.

import 'package:flutter/widgets.dart';

import '../../models/spin2win_board.dart';
import 'spin2win_palette.dart';

/// Where each chip's picture is: 5 to 100 are Triple Chance's chips, 500 is Lucky Card's.
String spin2WinChipAsset(Spin2WinChip chip) => switch (chip) {
      Spin2WinChip.fiveHundred => 'assets/lucky_card/images/chip_500.webp',
      _ => 'assets/images/chip_${chip.amount}.webp',
    };

/// The countdown as the timer writes it: two digits, so 5 seconds shows "05".
String spin2WinCountdownText(int seconds) => seconds.clamp(0, 99).toString().padLeft(2, '0');

/// The panel's inner sizes. The phone's are the design's phone board; the tablet and desktop
/// boards draw a taller panel (bigger cards, chips and buttons), enlarged again as a whole by the
/// board (spin2win_layout.dart).
class Spin2WinPanelMetrics {
  const Spin2WinPanelMetrics({
    required this.inset,
    required this.gap,
    required this.cardGap,
    required this.cardHeight,
    required this.cardRadius,
    required this.cardPadding,
    required this.cardUnder,
    required this.numberSize,
    required this.numberHeight,
    required this.numberStroke,
    required this.stakeHeight,
    required this.stakeRadius,
    required this.stakeSize,
    required this.chipRowHeight,
    required this.chipRowPadding,
    required this.chipRowRadius,
    required this.chipSize,
    required this.chipLift,
    required this.actionGap,
    required this.bigGap,
    required this.bigRadius,
    required this.bigSize,
    required this.bigSpacing,
    required this.bigStroke,
    required this.smallGap,
    required this.smallHeight,
    required this.smallRadius,
    required this.smallSize,
    required this.smallStroke,
    required this.timerWidth,
    required this.timerRadius,
    required this.timerSize,
    required this.timerHeight,
    required this.secSize,
    required this.secSpacing,
    required this.secStroke,
  });

  /// Inside the faint gold band (the design's padding less the 2 dp band).
  final double inset;

  /// Between the cards, the chips and the buttons.
  final double gap;
  final double cardGap;
  final double cardHeight;
  final double cardRadius;
  final EdgeInsets cardPadding;
  final double cardUnder;
  final double numberSize;
  final double numberHeight;
  final double numberStroke;
  final double stakeHeight;
  final double stakeRadius;
  final double stakeSize;
  final double chipRowHeight;
  final EdgeInsets chipRowPadding;
  final double chipRowRadius;
  final double chipSize;
  final double chipLift;

  /// Between the buttons and the timer.
  final double actionGap;

  /// ODD and EVEN: the gap between them, their corners, words and outline.
  final double bigGap;
  final double bigRadius;
  final double bigSize;
  final double bigSpacing;
  final double bigStroke;

  /// DOUBLE (REBET), REMOVE and CLEAR: the gap above and between them, their height, corners,
  /// words and outline.
  final double smallGap;
  final double smallHeight;
  final double smallRadius;
  final double smallSize;
  final double smallStroke;
  final double timerWidth;
  final double timerRadius;
  final double timerSize;

  /// The countdown's line height, as a multiple of [timerSize].
  final double timerHeight;
  final double secSize;
  final double secSpacing;
  final double secStroke;

  static const phone = Spin2WinPanelMetrics(
    inset: 4,
    gap: 6,
    cardGap: 6,
    cardHeight: 56,
    cardRadius: 11,
    // The amount box is 3 dp taller than the design's 15, and the card's bottom padding 2 dp less
    // than its 5 (Hasan's phone test, 2026-10-25: the amounts looked cramped).
    cardPadding: EdgeInsets.fromLTRB(6, 3, 6, 3),
    cardUnder: 4,
    numberSize: 25,
    numberHeight: 27 / 25,
    numberStroke: 3,
    stakeHeight: 18,
    stakeRadius: 4,
    stakeSize: 12,
    chipRowHeight: 52,
    chipRowPadding: EdgeInsets.fromLTRB(10, 2, 10, 0),
    chipRowRadius: 12,
    chipSize: 42,
    chipLift: 3,
    actionGap: 6,
    bigGap: 8,
    bigRadius: 12,
    bigSize: 24,
    bigSpacing: 1,
    bigStroke: 3,
    smallGap: 7,
    smallHeight: 31,
    smallRadius: 10,
    smallSize: 15,
    smallStroke: 2.5,
    timerWidth: 92,
    timerRadius: 14,
    timerSize: 40,
    timerHeight: 1,
    secSize: 13,
    secSpacing: 1.5,
    secStroke: 2,
  );

  /// The tablet board's panel: 126 dp cards with 66 dp numbers.
  static const tablet = Spin2WinPanelMetrics(
    inset: 6,
    gap: 12,
    cardGap: 8,
    cardHeight: 126,
    cardRadius: 13,
    cardPadding: EdgeInsets.fromLTRB(8, 6, 8, 8),
    cardUnder: 5,
    numberSize: 66,
    numberHeight: 70 / 66,
    numberStroke: 4,
    stakeHeight: 28,
    stakeRadius: 7,
    stakeSize: 19,
    chipRowHeight: 92,
    chipRowPadding: EdgeInsets.fromLTRB(12, 4, 12, 0),
    chipRowRadius: 14,
    chipSize: 62,
    chipLift: 4,
    actionGap: 10,
    bigGap: 10,
    bigRadius: 14,
    bigSize: 36,
    bigSpacing: 1.5,
    bigStroke: 4,
    smallGap: 10,
    smallHeight: 50,
    smallRadius: 12,
    smallSize: 20,
    smallStroke: 3,
    timerWidth: 124,
    timerRadius: 16,
    timerSize: 64,
    timerHeight: 62 / 64,
    secSize: 18,
    secSpacing: 2,
    secStroke: 3,
  );

  /// The desktop board's panel: as the tablet's, with 104 dp cards and 60 dp numbers.
  static const desktop = Spin2WinPanelMetrics(
    inset: 6,
    gap: 12,
    cardGap: 8,
    cardHeight: 104,
    cardRadius: 13,
    cardPadding: EdgeInsets.fromLTRB(8, 4, 8, 7),
    cardUnder: 5,
    numberSize: 60,
    numberHeight: 1,
    numberStroke: 4,
    stakeHeight: 27,
    stakeRadius: 7,
    stakeSize: 19,
    chipRowHeight: 92,
    chipRowPadding: EdgeInsets.fromLTRB(12, 4, 12, 0),
    chipRowRadius: 14,
    chipSize: 62,
    chipLift: 4,
    actionGap: 10,
    bigGap: 10,
    bigRadius: 14,
    bigSize: 36,
    bigSpacing: 1.5,
    bigStroke: 4,
    smallGap: 10,
    smallHeight: 50,
    smallRadius: 12,
    smallSize: 20,
    smallStroke: 3,
    timerWidth: 124,
    timerRadius: 16,
    timerSize: 64,
    timerHeight: 62 / 64,
    secSize: 18,
    secSpacing: 2,
    secStroke: 3,
  );
}

class Spin2WinBetPanel extends StatelessWidget {
  const Spin2WinBetPanel({
    super.key,
    required this.stakes,
    required this.selectedChip,
    required this.countdown,
    this.rebetMode = false,
    this.isLocked = false,
    this.hasBets = false,
    this.canAffordRebet = false,
    this.winningNumber,
    this.chipImage = spin2WinAssetChipImage,
    this.onNumber,
    this.onChip,
    this.onOdd,
    this.onEven,
    this.onDoubleOrRebet,
    this.onRemove,
    this.onClear,
    this.metrics = Spin2WinPanelMetrics.phone,
  });

  /// The inner sizes: the phone's, or the tablet's or desktop's taller panel.
  final Spin2WinPanelMetrics metrics;

  /// The coins on each number, 0 to 9 (a number not in the map holds none).
  final Map<int, int> stakes;

  /// The chip in hand, or null when none is.
  final Spin2WinChip? selectedChip;

  /// Seconds left to bet.
  final int countdown;

  /// True while the first button reads REBET (after a round, before the first bet).
  final bool rebetMode;

  /// True while betting is closed (from countdown 05 until the next round).
  final bool isLocked;

  /// True while any number holds coins.
  final bool hasBets;

  /// True when the balance covers the saved bet (only used with [rebetMode]).
  final bool canAffordRebet;

  /// The number the wheel stopped on, ringed in pulsing gold while the result is shown; null otherwise.
  final int? winningNumber;

  /// The picture of a chip; the app reads the asset, a test may read from disk.
  final ImageProvider Function(Spin2WinChip chip) chipImage;

  final ValueChanged<int>? onNumber;
  final ValueChanged<Spin2WinChip>? onChip;
  final VoidCallback? onOdd;
  final VoidCallback? onEven;
  final VoidCallback? onDoubleOrRebet;
  final VoidCallback? onRemove;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kS2wGoldBorder, width: 2),
        gradient: kS2wPanelFill,
        boxShadow: const [
          BoxShadow(color: kS2wGoldUnder, offset: Offset(0, 5)),
          BoxShadow(color: Color(0x99000000), offset: Offset(0, 10), blurRadius: 20),
        ],
      ),
      child: Container(
        // inset 0 0 0 2px rgba(255,212,90,.25): a faint gold band inside the border.
        padding: EdgeInsets.all(m.inset),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x40FFD45A), width: 2),
        ),
        child: Column(
          children: [
            for (final row in const [
              [0, 1, 2, 3, 4],
              [5, 6, 7, 8, 9],
            ]) ...[
              if (row.first != 0) SizedBox(height: m.cardGap),
              SizedBox(
                height: m.cardHeight,
                child: Row(
                  children: [
                    for (final n in row) ...[
                      if (n != row.first) SizedBox(width: m.cardGap),
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.none,
                          fit: StackFit.expand,
                          children: [
                            Spin2WinNumberCard(
                              number: n,
                              stake: stakes[n] ?? 0,
                              enabled: !isLocked,
                              lit: winningNumber == n,
                              metrics: m,
                              onTap: onNumber == null ? null : () => onNumber!(n),
                            ),
                            // Over the card, so the dimming of the locked board does not fade it.
                            if (winningNumber == n)
                              const Positioned(
                                  left: -4, top: -4, right: -4, bottom: -4, child: Spin2WinCardWinOutline()),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            SizedBox(height: m.gap),
            _ChipRow(selected: selectedChip, chipImage: chipImage, enabled: !isLocked, onChip: onChip, metrics: m),
            SizedBox(height: m.gap),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _BigButton.odd(enabled: !isLocked, onTap: onOdd, metrics: m)),
                              SizedBox(width: m.bigGap),
                              Expanded(child: _BigButton.even(enabled: !isLocked, onTap: onEven, metrics: m)),
                            ],
                          ),
                        ),
                        SizedBox(height: m.smallGap),
                        SizedBox(
                          height: m.smallHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: rebetMode
                                    ? _SmallButton.rebet(
                                        enabled: !isLocked && canAffordRebet, onTap: onDoubleOrRebet, metrics: m)
                                    : _SmallButton.double(
                                        enabled: !isLocked && hasBets, onTap: onDoubleOrRebet, metrics: m),
                              ),
                              SizedBox(width: m.bigGap),
                              Expanded(
                                  child:
                                      _SmallButton.remove(enabled: !isLocked && hasBets, onTap: onRemove, metrics: m)),
                              SizedBox(width: m.bigGap),
                              Expanded(
                                  child: _SmallButton.clear(enabled: !isLocked && hasBets, onTap: onClear, metrics: m)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: m.actionGap),
                  Spin2WinTimer(seconds: countdown, metrics: m),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chip pictures from the app's assets.
ImageProvider spin2WinAssetChipImage(Spin2WinChip chip) => AssetImage(spin2WinChipAsset(chip));

/// How strongly a dimmed button is drawn: Triple Chance's 40%.
const double kSpin2WinDimmedOpacity = 0.4;

/// Betting closed: the cards, chips, ODD and EVEN are drawn at this strength (still readable,
/// clearly off).
const double kSpin2WinLockedOpacity = 0.55;

/// A tap area with a screen-reader label around a drawn button. A button that is not [enabled]
/// is drawn at [dimmedOpacity] and ignores taps.
class _Tap extends StatelessWidget {
  const _Tap({
    required this.label,
    required this.onTap,
    required this.child,
    this.enabled = true,
    this.dimmedOpacity = kSpin2WinDimmedOpacity,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final bool enabled;
  final double dimmedOpacity;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            opacity: enabled ? 1 : dimmedOpacity,
            duration: const Duration(milliseconds: 150),
            child: child,
          ),
        ),
      );
}

/// One number card: the number over a white box with the coins on it.
class Spin2WinNumberCard extends StatelessWidget {
  const Spin2WinNumberCard({
    super.key,
    required this.number,
    required this.stake,
    this.enabled = true,
    this.lit = false,
    this.onTap,
    this.metrics = Spin2WinPanelMetrics.phone,
  });

  final int number;
  final int stake;
  final bool enabled;
  final Spin2WinPanelMetrics metrics;

  /// The winning card while the result is shown: drawn at full strength although the board is locked.
  final bool lit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shades = spin2WinShades(number);
    final m = metrics;
    return _Tap(
      label: 'Bet on $number, $stake coins',
      enabled: enabled,
      dimmedOpacity: lit ? 1 : kSpin2WinLockedOpacity,
      onTap: onTap,
      child: Container(
        key: ValueKey('spin2win-card-$number'),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(m.cardRadius),
          gradient: shades.rim,
          boxShadow: [
            BoxShadow(color: shades.under, offset: Offset(0, m.cardUnder)),
            BoxShadow(
                color: const Color(0x80000000), offset: Offset(0, m.cardUnder + 3), blurRadius: m.cardUnder * 2.5),
          ],
        ),
        child: Spin2WinGlossBox(
          radius: m.cardRadius - 2,
          padding: m.cardPadding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(m.cardRadius - 2),
            gradient: shades.face,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Spin2WinOutlinedText('$number', size: m.numberSize, height: m.numberHeight, strokeWidth: m.numberStroke),
              Container(
                height: m.stakeHeight,
                width: double.infinity,
                alignment: Alignment.center,
                // A little room each side, so a big bet such as 10,000 never touches the box's edges.
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(m.stakeRadius),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFFFFF), Color(0xFFD8E3F5)],
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Spin2WinCapsCentred(
                    size: m.stakeSize,
                    child: Text(
                      spin2WinAmountText(stake),
                      key: ValueKey('spin2win-stake-$number'),
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: kSpin2WinFont,
                        fontWeight: FontWeight.w900,
                        fontSize: m.stakeSize,
                        height: 1,
                        letterSpacing: 0.3,
                        color: const Color(0xFF102650),
                      ),
                    ),
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

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.selected,
    required this.chipImage,
    required this.enabled,
    required this.onChip,
    required this.metrics,
  });

  final Spin2WinChip? selected;
  final Spin2WinPanelMetrics metrics;
  final bool enabled;
  final ImageProvider Function(Spin2WinChip chip) chipImage;
  final ValueChanged<Spin2WinChip>? onChip;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: metrics.chipRowHeight,
      padding: metrics.chipRowPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(metrics.chipRowRadius),
        border: Border.all(color: const Color(0x7300E5FF)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF060F26), Color(0xFF0A1A3E), Color(0xFF0D2250)],
          stops: [0, .25, 1],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final chip in Spin2WinChip.values)
            _Tap(
              label: '${chip.amount} chip${chip == selected ? ', selected' : ''}',
              enabled: enabled,
              dimmedOpacity: kSpin2WinLockedOpacity,
              onTap: onChip == null ? null : () => onChip!(chip),
              child: _Chip(
                key: ValueKey('spin2win-chip-${chip.amount}'),
                image: chipImage(chip),
                selected: chip == selected,
                size: metrics.chipSize,
                lift: metrics.chipLift,
              ),
            ),
        ],
      ),
    );
  }
}

/// One chip (phone: 42 dp): the one in hand raised (3 dp) with a cyan ring and glow.
class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.image, required this.selected, required this.size, required this.lift});

  final ImageProvider image;
  final bool selected;
  final double size;
  final double lift;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      transform: Matrix4.translationValues(0, selected ? -lift : 0, 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: selected
            ? [
                BoxShadow(color: const Color(0xBF00E5FF), spreadRadius: lift, blurRadius: lift * 16 / 3),
                BoxShadow(color: const Color(0x8C000000), offset: Offset(0, lift + 5), blurRadius: lift + 7),
                const BoxShadow(color: kS2wCyan, spreadRadius: 2),
              ]
            : [BoxShadow(color: const Color(0x8C000000), offset: Offset(0, lift * 2), blurRadius: lift * 8 / 3)],
      ),
      child: Image(
        image: image,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// The look of one of the action buttons: its fill, border, shadows and outline colour.
class _ButtonLook {
  const _ButtonLook({
    required this.label,
    required this.semantics,
    required this.border,
    required this.fill,
    required this.under,
    required this.stroke,
    this.glow,
  });

  final String label;
  final String semantics;
  final Color border;
  final List<Color> fill;
  final Color under;
  final Color stroke;
  final Color? glow;
}

/// ODD and EVEN: 24 dp words on a tall red or blue button with a gold border.
class _BigButton extends StatelessWidget {
  const _BigButton(this.look, {required this.enabled, required this.onTap, required this.metrics});

  const _BigButton.odd({required bool enabled, required VoidCallback? onTap, required Spin2WinPanelMetrics metrics})
      : this(
          const _ButtonLook(
            label: 'ODD',
            semantics: 'Bet on odd',
            border: kS2wGold,
            fill: [Color(0xFFFF7A8E), Color(0xFFFF3155), Color(0xFFC8102E)],
            under: Color(0xFF5E0716),
            stroke: Color(0xD95E0716),
          ),
          enabled: enabled,
          onTap: onTap,
          metrics: metrics,
        );

  const _BigButton.even({required bool enabled, required VoidCallback? onTap, required Spin2WinPanelMetrics metrics})
      : this(
          const _ButtonLook(
            label: 'EVEN',
            semantics: 'Bet on even',
            border: kS2wGold,
            fill: [Color(0xFF6FB0FF), Color(0xFF1677FF), Color(0xFF0A4FC4)],
            under: Color(0xFF052866),
            stroke: Color(0xD9052866),
          ),
          enabled: enabled,
          onTap: onTap,
          metrics: metrics,
        );

  final _ButtonLook look;
  final bool enabled;
  final VoidCallback? onTap;
  final Spin2WinPanelMetrics metrics;

  @override
  Widget build(BuildContext context) => _Tap(
        label: look.semantics,
        enabled: enabled,
        dimmedOpacity: kSpin2WinLockedOpacity,
        onTap: onTap,
        child: Spin2WinGlossBox(
          key: ValueKey('spin2win-${look.label.toLowerCase()}'),
          radius: metrics.bigRadius,
          borderWidth: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(metrics.bigRadius),
            border: Border.all(color: look.border, width: 2),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: look.fill),
            boxShadow: [
              BoxShadow(color: look.under, offset: Offset(0, metrics.cardUnder)),
              BoxShadow(
                  color: const Color(0x80000000),
                  offset: Offset(0, metrics.cardUnder + 3),
                  blurRadius: metrics.cardUnder * 2.5),
            ],
          ),
          child: Center(
            child: Spin2WinOutlinedText(
              look.label,
              size: metrics.bigSize,
              letterSpacing: metrics.bigSpacing,
              stroke: look.stroke,
              strokeWidth: metrics.bigStroke,
              height: 1,
              centreCaps: true,
            ),
          ),
        ),
      );
}

/// DOUBLE (or REBET), REMOVE and CLEAR: 15 dp words on a short glowing button.
class _SmallButton extends StatelessWidget {
  const _SmallButton(this.look, {required this.enabled, required this.onTap, required this.metrics});

  const _SmallButton.double(
      {required bool enabled, required VoidCallback? onTap, required Spin2WinPanelMetrics metrics})
      : this(_doubleLook, enabled: enabled, onTap: onTap, metrics: metrics);

  const _SmallButton.rebet({required bool enabled, required VoidCallback? onTap, required Spin2WinPanelMetrics metrics})
      : this(_rebetLook, enabled: enabled, onTap: onTap, metrics: metrics);

  const _SmallButton.remove(
      {required bool enabled, required VoidCallback? onTap, required Spin2WinPanelMetrics metrics})
      : this(
          const _ButtonLook(
            label: 'REMOVE',
            semantics: 'Remove the last chip',
            border: Color(0xFFE0CCFF),
            fill: [Color(0xFFC9A6FF), Color(0xFF9A4DFF), Color(0xFF5A1FC2)],
            under: Color(0xFF2A0C5E),
            stroke: Color(0xE62A0C5E),
            glow: Color(0x809A4DFF),
          ),
          enabled: enabled,
          onTap: onTap,
          metrics: metrics,
        );

  const _SmallButton.clear({required bool enabled, required VoidCallback? onTap, required Spin2WinPanelMetrics metrics})
      : this(
          const _ButtonLook(
            label: 'CLEAR',
            semantics: 'Clear the board',
            border: Color(0xFFFFD0F3),
            fill: [Color(0xFFFF9AE8), Color(0xFFFF35C7), Color(0xFFB80A85)],
            under: Color(0xFF5A0445),
            stroke: Color(0xE65A0445),
            glow: Color(0x80FF35C7),
          ),
          enabled: enabled,
          onTap: onTap,
          metrics: metrics,
        );

  static const _doubleLook = _ButtonLook(
    label: 'DOUBLE',
    semantics: 'Double every bet',
    border: Color(0xFFFFF0C0),
    fill: [Color(0xFFFFE07A), Color(0xFFFF9A1F), Color(0xFFE05A00)],
    under: Color(0xFF6B2A00),
    stroke: Color(0xE66B2A00),
    glow: Color(0x73FF9A1F),
  );

  /// REBET wears DOUBLE's colours, in its place.
  static const _rebetLook = _ButtonLook(
    label: 'REBET',
    semantics: "Place last round's bets again",
    border: Color(0xFFFFF0C0),
    fill: [Color(0xFFFFE07A), Color(0xFFFF9A1F), Color(0xFFE05A00)],
    under: Color(0xFF6B2A00),
    stroke: Color(0xE66B2A00),
    glow: Color(0x73FF9A1F),
  );

  final _ButtonLook look;
  final bool enabled;
  final VoidCallback? onTap;
  final Spin2WinPanelMetrics metrics;

  @override
  Widget build(BuildContext context) => _Tap(
        label: look.semantics,
        enabled: enabled,
        onTap: onTap,
        child: Spin2WinGlossBox(
          key: ValueKey('spin2win-${look.label.toLowerCase()}'),
          radius: metrics.smallRadius,
          borderWidth: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(metrics.smallRadius),
            border: Border.all(color: look.border, width: 2),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: look.fill),
            boxShadow: [
              BoxShadow(color: look.under, offset: Offset(0, metrics.cardUnder)),
              BoxShadow(
                  color: const Color(0x80000000),
                  offset: Offset(0, metrics.cardUnder + 2),
                  blurRadius: metrics.cardUnder * 2.25),
              if (look.glow != null) BoxShadow(color: look.glow!, blurRadius: metrics.smallRadius),
            ],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Spin2WinOutlinedText(
                look.label,
                size: metrics.smallSize,
                letterSpacing: 1,
                stroke: look.stroke,
                strokeWidth: metrics.smallStroke,
                height: 1,
                centreCaps: true,
              ),
            ),
          ),
        ),
      );
}

/// The green timer: the seconds left over "SEC".
class Spin2WinTimer extends StatelessWidget {
  const Spin2WinTimer({super.key, required this.seconds, this.metrics = Spin2WinPanelMetrics.phone});

  final int seconds;
  final Spin2WinPanelMetrics metrics;

  @override
  Widget build(BuildContext context) {
    const stroke = Color(0xE604461F);
    final m = metrics;
    return Semantics(
      label: '$seconds seconds left',
      excludeSemantics: true,
      child: Spin2WinGlossBox(
        key: const ValueKey('spin2win-timer'),
        width: m.timerWidth,
        radius: m.timerRadius,
        borderWidth: 3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(m.timerRadius),
          border: Border.all(color: kS2wGold, width: 3),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7DFFAE), Color(0xFF19D96B), Color(0xFF0A9A45)],
            stops: [0, .45, 1],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0xFF04461F), offset: Offset(0, 5)),
            BoxShadow(color: Color(0x8C000000), offset: Offset(0, 8), blurRadius: 14),
            BoxShadow(color: Color(0x5919D96B), blurRadius: 12),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spin2WinOutlinedText(
              spin2WinCountdownText(seconds),
              key: const ValueKey('spin2win-countdown'),
              size: m.timerSize,
              height: m.timerHeight,
              stroke: stroke,
              strokeWidth: m.bigStroke,
            ),
            Spin2WinOutlinedText(
              'SEC',
              size: m.secSize,
              letterSpacing: m.secSpacing,
              stroke: stroke,
              strokeWidth: m.secStroke,
              height: 1.2,
            ),
          ],
        ),
      ),
    );
  }
}

/// The pulsing gold ring around the winning number's card (the design's `cardwin`): a 3 dp gold
/// border with a glow, its strength and size breathing (1 to 0.55, 100% to 105%) every 0.75 s.
class Spin2WinCardWinOutline extends StatefulWidget {
  const Spin2WinCardWinOutline({super.key});

  @override
  State<Spin2WinCardWinOutline> createState() => _Spin2WinCardWinOutlineState();
}

class _Spin2WinCardWinOutlineState extends State<Spin2WinCardWinOutline> with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _beat,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_beat.value);
          return Opacity(
            opacity: 1 - 0.45 * t,
            child: Transform.scale(scale: 1 + 0.05 * t, child: child),
          );
        },
        child: const CustomPaint(key: ValueKey('spin2win-card-win'), painter: _CardWinPainter()),
      ),
    );
  }
}

/// The ring itself: a 3 dp gold line with a soft glow on both sides of it (CSS draws a box-shadow
/// only outside the box, and the inset one only inside, so neither covers the card).
class _CardWinPainter extends CustomPainter {
  const _CardWinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = RRect.fromRectAndRadius((Offset.zero & size).deflate(1.5), const Radius.circular(12.5));
    canvas.drawRRect(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0xD9FFD45A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawRRect(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = kS2wGold,
    );
  }

  @override
  bool shouldRepaint(_CardWinPainter oldDelegate) => false;
}
