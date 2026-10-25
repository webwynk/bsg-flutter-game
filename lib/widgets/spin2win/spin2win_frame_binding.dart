// Connects the Spin2Win frame to the provider: reads what the screen shows into a
// [Spin2WinFrameData] and hands every tap to the provider, exactly as Triple Chance's
// buttons work:
//   * a number card places the chip in hand on that number, or, with no chip in hand,
//     takes that number's newest chip back;
//   * ODD (1 3 5 7 9) and EVEN (0 2 4 6 8) do the same on five numbers at once; a number
//     already at 10,000 is skipped;
//   * a chip picks that chip up (tapping the one in hand keeps it in hand);
//   * DOUBLE doubles every stake; REBET (in DOUBLE's place after a round) puts last round's
//     bet back; CLEAR gives every chip back; REMOVE puts the chip in hand down, so taps on
//     the board then take chips back. It is not an undo.
// A tap the board could not fully do is handed to [Spin2WinFrameBinding.onRefused] with its
// reasons; the popups and the min/max banner for them come in Phase 5.
//
// The wheel ([Spin2WinSpinningWheel]) spins for each result and tells the provider when it has
// stopped; the winning card is ringed in gold while the result is shown (Phase 3).
//
// A win (Phase 4): the WIN box shows the payout and it and the coin box bump; gold coins burst from
// the hub for a win of 900 or more ([spin2WinShowsCoinBurst]); a smaller win waits the same 1.5 s
// without them (Hasan, 2026-10-25); then the win popup shows for 2.5 s. The provider decides those
// times; this only draws what it says.
//
// Belongs to Spin2Win only.

import 'package:flutter/widgets.dart';

import '../../models/spin2win_board.dart';
import '../../models/spin2win_models.dart';
import '../../providers/spin2win_provider.dart';
import '../../services/spin2win_round_clock.dart';
import 'spin2win_bet_panel.dart';
import 'spin2win_coin_burst.dart';
import 'spin2win_frame.dart';
import 'spin2win_history_strip.dart';
import 'spin2win_layout.dart';
import 'spin2win_wheel.dart';
import 'spin2win_wheel_spin.dart';
import 'spin2win_win_popup.dart';

/// What kind of tap did something (each has its own sound).
enum Spin2WinTapKind { number, chip, button }

/// What the screen shows for the provider as it is now.
Spin2WinFrameData spin2WinFrameDataOf(Spin2WinProvider p, {required bool muted}) {
  final history = p.history;
  final Spin2WinDome dome;
  double angle = 0;
  if (p.stage == Spin2WinStage.spinning || history.isEmpty) {
    // The result must not show before the wheel lands (Phase 3 spins it).
    dome = const Spin2WinDomeShuffling(1);
  } else {
    final last = history.first;
    dome = Spin2WinDomeLanded(last.winningNumber, last.bonusMultiplier);
    angle = spin2WinAngleFor(last.winningNumber);
  }
  return Spin2WinFrameData(
    balance: p.balance,
    play: p.total,
    win: p.lastOutcome?.payout ?? 0,
    muted: muted,
    stakes: {for (final n in kSpin2WinNumbers) n: p.stakeOn(n)},
    selectedChip: p.activeChip,
    countdown: p.countdown,
    rebetMode: p.canRebet,
    wheelAngle: angle,
    dome: dome,
    history: [
      for (final r in history.take(Spin2WinHistoryStrip.slots))
        Spin2WinHistoryTile(number: r.winningNumber, bonusMultiplier: r.bonusMultiplier, roundId: r.roundId),
    ],
    isLocked: p.isLocked,
    hasBets: !p.isBoardEmpty,
    canAffordRebet: p.canRebet && p.canAffordRebet,
    winningNumber: p.numberRevealed ? p.spinTarget?.winningNumber : null,
    winKey: (p.lastOutcome?.won ?? false) ? p.lastOutcome!.roundId : null,
    noMoreBets: spin2WinShowsNoMoreBets(p),
  );
}

/// Whether the NO MORE BETS sign is up: betting has closed at the lock mark (05) and the wheel has
/// not started yet (Triple Chance's "No More Play" rule: countdown 5 to 1, not spinning).
bool spin2WinShowsNoMoreBets(Spin2WinProvider p) =>
    p.isLocked && p.countdown > 0 && p.countdown <= kSpin2WinLockCountdown && p.stage == Spin2WinStage.none;

/// What the wheel should be doing for the provider as it is now.
Spin2WinWheelCue spin2WinWheelCueOf(Spin2WinProvider p) {
  final target = p.spinTarget;
  final history = p.history;
  // The resting number is the newest revealed result that is not the round being drawn.
  final rest = history.where((r) => r.roundId != target?.roundId).firstOrNull;
  return Spin2WinWheelCue(
    restNumber: rest?.winningNumber,
    restBonus: rest?.bonusMultiplier ?? 1,
    spinKey: target?.roundId,
    target: target?.winningNumber,
    targetBonus: target?.bonusMultiplier ?? 1,
    revealed: p.numberRevealed,
  );
}

/// The whole frame, redrawn whenever the provider or its round clock changes.
class Spin2WinFrameBinding extends StatelessWidget {
  const Spin2WinFrameBinding({
    super.key,
    required this.provider,
    required this.muted,
    this.chipImage = spin2WinAssetChipImage,
    this.onExit,
    this.onRecords,
    this.onSound,
    this.onRefused,
    this.onTapped,
    this.animateIdle = true,
  });

  final Spin2WinProvider provider;

  /// Whether the wheel's bulbs and glow move between spins.
  final bool animateIdle;
  final bool muted;
  final ImageProvider Function(Spin2WinChip chip) chipImage;
  final VoidCallback? onExit;
  final VoidCallback? onRecords;
  final VoidCallback? onSound;

  /// A tap the board could not fully do (not enough coins, a number at its maximum, ...).
  final void Function(Set<Spin2WinBoardIssue> issues)? onRefused;

  /// A tap that did something, for its sound: a card that changed the board, a chip picked up, or
  /// a button that did its job.
  final ValueChanged<Spin2WinTapKind>? onTapped;

  void _run(Spin2WinTapKind kind, Spin2WinBoardResult Function() action) {
    final result = action();
    if (!result.isClean) onRefused?.call(result.issues);
    final did = kind == Spin2WinTapKind.chip ? result.isClean : result.changedAnything;
    if (did) onTapped?.call(kind);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([provider, provider.sync]),
      builder: (context, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _frame()),
          if (_burstFor(provider) case final roundId?)
            Positioned.fill(
              child: Spin2WinAtHub(
                child: Spin2WinCoinBurst(key: ValueKey('burst-$roundId'), burstKey: roundId),
              ),
            ),
          if (provider.popup case final win?)
            Positioned.fill(
              child: Spin2WinZoom(
                zoom: Spin2WinLayoutScope.of(context).popupZoom,
                child: Spin2WinWinOverlay(
                  key: ValueKey('popup-${win.roundId}'),
                  number: win.winningNumber,
                  bonusMultiplier: win.bonusMultiplier,
                  amount: win.payout,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The round whose coins burst now: only while the provider shows the coin effect, and only for
  /// a win of [kSpin2WinCoinBurstMinWin] or more.
  static String? _burstFor(Spin2WinProvider p) {
    final outcome = p.lastOutcome;
    if (!p.showCoinFx || outcome == null || !spin2WinShowsCoinBurst(outcome.payout)) return null;
    return outcome.roundId;
  }

  Widget _frame() {
    return Spin2WinFrame(
      data: spin2WinFrameDataOf(provider, muted: muted),
      chipImage: chipImage,
      animate: animateIdle,
      wheel: Spin2WinSpinningWheel(
        cue: spin2WinWheelCueOf(provider),
        onLanded: provider.wheelLanded,
        animateIdle: animateIdle,
      ),
      actions: Spin2WinFrameActions(
        onExit: onExit,
        onRecords: onRecords,
        onSound: onSound,
        onNumber: (n) => _run(Spin2WinTapKind.number, () => provider.tapNumber(n)),
        onChip: (chip) => _run(Spin2WinTapKind.chip, () => provider.selectChip(chip)),
        onOdd: () => _run(Spin2WinTapKind.button, provider.tapOdd),
        onEven: () => _run(Spin2WinTapKind.button, provider.tapEven),
        onDoubleOrRebet: () => _run(Spin2WinTapKind.button, provider.canRebet ? provider.rebet : provider.doubleBet),
        onRemove: () {
          if (provider.activeChip == null) return;
          provider.deselectChip();
          onTapped?.call(Spin2WinTapKind.button);
        },
        onClear: () => _run(Spin2WinTapKind.button, provider.clearBoard),
      ),
    );
  }
}
