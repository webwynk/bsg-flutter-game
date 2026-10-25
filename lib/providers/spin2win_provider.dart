// The Spin2Win game provider: the betting board as the player uses it, the lock
// at countdown 5, sending the bet with every way it can fail, and the result
// sequence (the wheel, the confirmed result, the balance, the coins and the
// popup), the last-10 history strip, and a round that never resolves.
//
// A copy of Lucky Card's provider with Spin2Win's board (numbers 0 to 9, ODD
// and EVEN) and Spin2Win's timing (the user's rules, 2026-10-24): the wheel
// spins for 4 s from countdown 00, then a winner gets 1.5 s of coins, a 2.5 s
// popup and a 2 s pause, and a loser waits 6 s; 90 + 4 + 6 = the 100 s round.
//
// The provider is an ordinary object created for one screen. Everything it
// depends on is passed in: the API, the wallet, and the round sync (which owns
// the clock and the poll). It exposes the board only as read-only amounts, so no
// screen can change a chip without the matching coins moving in the wallet.
//
// How a failure is reported follows Triple Chance's three kinds (as Lucky Card
// does; the user asked for all of Triple Chance's error popups, 2026-10-24). The provider only says WHAT happened, through
// [onProblem]; the screen shows the dialogs later:
//   * betRejected       the server refused the bet (too late, not enough coins,
//                       not a player, or an unknown fault after retries). The
//                       chips have been returned on screen. The player stays in
//                       the game.
//   * connectionProblem offline, a sign-in that no longer works, or a blocked
//                       account, after the retries. The chips have been returned
//                       on screen first. Triple Chance ends the session here.
//   * roundUnresolved   the round never produced a result. Nothing is claimed as
//                       refunded, because the stake really was taken; the board
//                       is dropped and the saved Rebet bet is kept.
//
// Belongs to Spin2Win only.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/spin2win_board.dart';
import '../models/spin2win_models.dart';
import '../services/spin2win_api_service.dart';
import '../services/spin2win_round_clock.dart';
import '../services/spin2win_round_sync.dart';
import '../services/spin2win_wallet.dart';

/// Where the player's bet for this round stands.
enum Spin2WinBetStatus {
  /// Nothing has been sent.
  idle,

  /// The bet is on its way to the server.
  submitting,

  /// The server has accepted the bet.
  submitted,

  /// The server refused the bet or could not be reached; the chips were returned.
  failed,
}

/// Where the result sequence stands. Separate from [Spin2WinPhase] on purpose:
/// the betting/locked meaning stays exactly as it was proven in Lucky Card.
enum Spin2WinStage {
  /// No result is being shown.
  none,

  /// The result is in hand and the wheel is turning. The number is not shown yet.
  spinning,

  /// The wheel has stopped: the number is shown, the balance has moved, and for
  /// a winner the coins and then the popup follow.
  revealing,
}

/// What one round came to for this player, once the server has confirmed it.
@immutable
class Spin2WinOutcome {
  const Spin2WinOutcome({
    required this.roundId,
    required this.winningNumber,
    required this.bonusMultiplier,
    required this.stake,
    required this.payout,
  });

  final String roundId;
  /// 0 to 9.
  final int winningNumber;

  /// 1 = N, 2 to 4.
  final int bonusMultiplier;

  /// What the player had on the board (0 for a spectator).
  final int stake;

  /// What the server paid out (0 for a loss or a spectator).
  final int payout;

  bool get won => payout > 0;
}

/// What the player can do right now.
enum Spin2WinPhase {
  /// Betting is open: chips can be placed, removed, doubled and cleared.
  betting,

  /// The board is locked: from the lock mark until the next round begins.
  locked,
}

/// The kinds of problem the screen has to tell the player about.
enum Spin2WinProblemKind { betRejected, connectionProblem, roundUnresolved }

/// A problem, with its reason.
class Spin2WinProblem {
  const Spin2WinProblem(this.kind, Spin2WinError this.reason);

  /// The round never produced a result. There is no error code: the server
  /// simply did not draw it in time.
  const Spin2WinProblem.unresolved()
      : kind = Spin2WinProblemKind.roundUnresolved,
        reason = null;

  final Spin2WinProblemKind kind;

  /// Null only for [Spin2WinProblemKind.roundUnresolved].
  final Spin2WinError? reason;

  @override
  String toString() => 'Spin2WinProblem(${kind.name}, ${reason?.name})';
}

class Spin2WinProvider extends ChangeNotifier {
  Spin2WinProvider({
    required Spin2WinApi api,
    required Spin2WinWallet wallet,
    required this.sync,
    Spin2WinBoard? board,
    DateTime Function()? now,
  })  : _api = api,
        _wallet = wallet,
        _board = board ?? Spin2WinBoard(),
        _now = now ?? DateTime.now;

  final Spin2WinApi _api;
  final Spin2WinWallet _wallet;

  /// The clock the result sequence measures its deadlines with.
  final DateTime Function() _now;

  /// The round sync: the clock, the poll and the events.
  final Spin2WinRoundSync sync;

  final Spin2WinBoard _board;

  /// Told when a problem has to be shown to the player.
  void Function(Spin2WinProblem problem)? onProblem;

  Spin2WinBetStatus _betStatus = Spin2WinBetStatus.idle;
  Spin2WinPhase _phase = Spin2WinPhase.betting;

  /// The round the bet was sent to.
  String? _submittedRoundId;

  /// True from the moment the board starts being sent until the round is over:
  /// the chips are no longer "unsent", so the background balance check must not
  /// subtract them again.
  bool _submittedBets = false;

  bool _attached = false;

  // ── The result sequence ─────────────────────────────────────────────────

  /// True from the moment a result is handed over until the round is ended. The
  /// board stays locked and the heartbeat is told not to apply a balance.
  bool _sequenceRunning = false;
  Spin2WinStage _stage = Spin2WinStage.none;

  /// The number and bonus the wheel must land on; null outside a sequence.
  Spin2WinRoundResult? _spinTarget;
  bool _numberRevealed = false;
  bool _showCoinFx = false;
  Spin2WinOutcome? _popup;
  Spin2WinOutcome? _lastOutcome;

  /// True when the server had not settled this player's bet by the end of the
  /// confirmation retries. The real balance catches up through the heartbeat.
  bool _balanceSyncFailed = false;

  /// Completed by [wheelLanded], or by the ceiling, so the sequence can go on.
  Completer<void>? _wheelLanded;

  // ── The history strip ───────────────────────────────────────────────────

  /// The last 10 results, newest first, global to every player.
  final List<Spin2WinRecentRound> _history = [];

  /// Rounds this screen has revealed. A round of the current cycle is shown in
  /// the strip only once it is in here.
  final Set<int> _revealedRounds = {};

  /// Bumped by every [attach] and [leave]. A call that began under an older value
  /// is stale and must not touch anything.
  int _epoch = 0;

  // ── What the screen reads ───────────────────────────────────────────────

  Spin2WinBetStatus get betStatus => _betStatus;
  Spin2WinPhase get phase => _phase;
  String? get submittedRoundId => _submittedRoundId;

  /// The last 10 results, newest first. The first entry is the current result.
  /// A round that has been drawn but not yet revealed on this screen is not in
  /// it, so the strip never gives the winner away before the wheel lands.
  List<Spin2WinRecentRound> get history => List.unmodifiable(_history);

  Spin2WinStage get stage => _stage;
  bool get isSequenceRunning => _sequenceRunning;

  /// The number and bonus the wheel must land on, from the moment the spin
  /// starts, so the wheel can be aimed. The screen shuffles the bonus while the
  /// wheel turns and shows the number and the real bonus only once
  /// [numberRevealed].
  Spin2WinRoundResult? get spinTarget => _spinTarget;

  /// True from the moment the wheel stops: the screen may show the number.
  bool get numberRevealed => _numberRevealed;

  /// True while the coin effect should play (winners only).
  bool get showCoinFx => _showCoinFx;

  /// The win popup's content while it is open; null otherwise.
  Spin2WinOutcome? get popup => _popup;

  /// The latest confirmed outcome, for the small "WIN" badge, until the player
  /// next touches the board.
  Spin2WinOutcome? get lastOutcome => _lastOutcome;
  bool get balanceSyncFailed => _balanceSyncFailed;

  /// True once the board has started to be sent, until the round is over.
  bool get isBetSubmitted => _submittedBets;

  /// The countdown: 90 down to 0.
  int get countdown => sync.countdown;

  /// The player's balance as the screen shows it.
  int get balance => _wallet.balance;

  int stakeOn(int number) => _board.stakeOn(number);
  int get total => _board.total;
  bool get isBoardEmpty => _board.isEmpty;
  Spin2WinChip? get activeChip => _board.activeChip;
  bool get isLocked => _board.isLocked;
  bool get canRemoveLast => _board.canRemoveLast;

  /// True when Rebet should be offered instead of Double.
  bool get canRebet => _board.canRebet;

  /// True when the balance covers the saved bet; only meaningful with [canRebet].
  bool get canAffordRebet => _board.canAffordRebet(_wallet.balance);

  // ── Life cycle ──────────────────────────────────────────────────────────

  /// Starts everything for a screen that has just opened.
  Future<void> attach() async {
    final epoch = ++_epoch;
    _attached = true;
    _wallet.setUncommittedStakeGetter(() => _submittedBets ? 0 : _board.total);
    _wallet.setIsSpinningGetter(() => _sequenceRunning);
    sync.onLockMark = _onLockMark;
    sync.onNewCycle = _onNewCycle;
    sync.onResult = _onResult;
    sync.onResultUnavailable = _onResultUnavailable;
    sync.addListener(notifyListeners);
    _applyLockToCountdown();
    await sync.attach();
    if (epoch != _epoch) return;
    _applyLockToCountdown();
    // After the sync has attached, so its clock is calibrated and the current
    // round is known when the list is filtered. Not awaited: the strip fills in
    // when it arrives, as in Triple Chance.
    unawaited(_loadHistory(epoch));
  }

  /// Stops everything, for a screen that is closing (or a player being logged
  /// out). Chips that were never sent are given back on screen; a bet that was
  /// already sent is left to settle normally. Safe to call more than once.
  void leave() {
    _epoch++;
    if (_attached) {
      sync.removeListener(notifyListeners);
      sync.onLockMark = null;
      sync.onNewCycle = null;
      sync.onResult = null;
      sync.onResultUnavailable = null;
      sync.detach();
      _wallet.setUncommittedStakeGetter(null);
      _wallet.setIsSpinningGetter(null);
      _attached = false;
    }
    if (!_board.isEmpty) {
      final onBoard = _board.reset();
      if (!_submittedBets) _wallet.setLocalBalance(_wallet.balance + onBoard);
    }
    _submittedBets = false;
    _betStatus = Spin2WinBetStatus.idle;
    _submittedRoundId = null;
    _clearSequence();
    _history.clear();
    _revealedRounds.clear();
    _board.setLocked(false);
    _phase = Spin2WinPhase.betting;
  }

  /// Forgets everything about a result sequence and lets a waiting one go (it is
  /// stale by now, so it stops at its next check).
  void _clearSequence() {
    _sequenceRunning = false;
    _stage = Spin2WinStage.none;
    _spinTarget = null;
    _numberRevealed = false;
    _showCoinFx = false;
    _popup = null;
    _lastOutcome = null;
    _balanceSyncFailed = false;
    _completeWheel();
  }

  @override
  void dispose() {
    leave();
    sync.dispose();
    super.dispose();
  }

  // ── The player's actions on the board ───────────────────────────────────
  // Each one changes the board, moves the coins in the wallet by exactly what
  // the board says, and returns the board's receipt so the screen can say why
  // anything could not be done.

  /// Picks a chip up.
  Spin2WinBoardResult selectChip(Spin2WinChip chip) => _apply(_board.selectChip(chip));

  /// Puts the chip down, so taps remove chips instead of placing them.
  void deselectChip() {
    _board.deselectChip();
    notifyListeners();
  }

  /// A tap on a number: places the held chip, or with no chip held takes the
  /// most recent chip back, as Triple Chance's grid does.
  Spin2WinBoardResult tapNumber(int number) => _apply(
        _board.activeChip != null
            ? _board.placeOnNumber(number, balance: _wallet.balance)
            : _board.removeFromNumber(number),
      );

  /// The ODD button: 1, 3, 5, 7 and 9.
  Spin2WinBoardResult tapOdd() => _tapGroup(kSpin2WinOddNumbers);

  /// The EVEN button: 0, 2, 4, 6 and 8 (0 counts as even).
  Spin2WinBoardResult tapEven() => _tapGroup(kSpin2WinEvenNumbers);

  Spin2WinBoardResult _tapGroup(List<int> numbers) => _apply(
        _board.activeChip != null
            ? _board.placeOnNumbers(numbers, balance: _wallet.balance)
            : _board.removeFromNumbers(numbers),
      );

  /// The Remove button: one chip back, newest first.
  Spin2WinBoardResult removeLast() => _apply(_board.removeLast());

  /// The Double button.
  Spin2WinBoardResult doubleBet() => _apply(_board.doubleStakes(balance: _wallet.balance));

  /// The Clear button.
  Spin2WinBoardResult clearBoard() => _apply(_board.clear());

  /// The Rebet button.
  Spin2WinBoardResult rebet() => _apply(_board.rebet(balance: _wallet.balance));

  /// Moves the coins by what the board says and tells the screen.
  Spin2WinBoardResult _apply(Spin2WinBoardResult result) {
    if (result.coinsSpent != 0) {
      _wallet.setLocalBalance(_wallet.balance - result.coinsSpent);
    }
    // Changing the board starts the bet afresh, as Triple Chance does.
    if (result.changedAnything && _betStatus == Spin2WinBetStatus.failed) {
      _betStatus = Spin2WinBetStatus.idle;
      _submittedRoundId = null;
    }
    // The last round's "WIN" badge goes as soon as the player starts the next.
    if (result.changedAnything) _lastOutcome = null;
    notifyListeners();
    return result;
  }

  // ── The lock, and the end of a round ────────────────────────────────────

  void _onLockMark() {
    _lastOutcome = null;
    _lockBoard();
    unawaited(_submitBet());
  }

  void _onNewCycle() {
    // A bet that was sent belongs to the round that just ended, and a sequence
    // that is still running (a slow confirmation, a late joiner) still owns the
    // board; the end-of-round cleanup releases both. Until then it stays locked.
    if (_submittedBets || _sequenceRunning) return;
    _betStatus = Spin2WinBetStatus.idle;
    _submittedRoundId = null;
    _unlockBoard();
  }

  /// Ends a round and gets the board ready for the next one: the board is
  /// cleared, the bet is remembered for Rebet when [saveForRebet] is true, and
  /// the bet status is reset. The board unlocks at once if the countdown allows
  /// betting, otherwise when the next round begins. Called by the result
  /// sequence.
  void endRound({required bool saveForRebet}) {
    _board.finishRound(saveForRebet: saveForRebet);
    _submittedBets = false;
    _betStatus = Spin2WinBetStatus.idle;
    _submittedRoundId = null;
    _applyLockToCountdown();
    notifyListeners();
  }

  /// Betting is closed whenever the countdown is at the lock mark or below.
  void _applyLockToCountdown() {
    if (sync.countdown <= kSpin2WinLockCountdown ||
        _submittedBets ||
        _sequenceRunning) {
      _lockBoard();
    } else {
      _unlockBoard();
    }
  }

  void _lockBoard() {
    _board.setLocked(true);
    _phase = Spin2WinPhase.locked;
    notifyListeners();
  }

  void _unlockBoard() {
    _board.setLocked(false);
    _phase = Spin2WinPhase.betting;
    notifyListeners();
  }

  /// Called when the app comes back after being in the background. The timer may
  /// have been frozen straight through the lock mark, so the bet was never sent.
  /// If the countdown is already at or below the mark and the board was never
  /// sent, it is sent now, by the same path the normal mark uses. A late attempt
  /// just gets the same refusal and refund as any other late bet.
  void catchUpMissedSubmissionIfNeeded() {
    if (_board.isEmpty || _submittedBets) return;
    if (sync.countdown <= kSpin2WinLockCountdown) {
      _lockBoard();
      unawaited(_submitBet());
    }
  }

  // ── The result sequence ─────────────────────────────────────────────────
  //
  // The user's timeline (2026-10-24), anchored to W, the moment the wheel stops
  // (the wheel says so through [wheelLanded]). Every deadline is an ABSOLUTE
  // offset from W, never a chain of delays, so a late confirmation is absorbed
  // by the popup's own time instead of pushing the end of the round (Triple
  // Chance Issue #105):
  //
  //   00 (spin)   the number and bonus are handed to the wheel, which turns for
  //               4 s while the bonus shuffles; for a bettor the confirmed
  //               result is asked for at once, while the wheel turns
  //   W           balance applied, number revealed, coin effect (winners)
  //   W + 1.5     win popup opens (winners)
  //   W + 4.0     win popup closes (2.5 s on screen)
  //   W + 6.0     after the 2 s pause (or the loser's 6 s wait) the round ends:
  //               board cleared, Rebet saved
  //
  // The provider plays no sound; the screen reacts to these state changes.

  /// The wheel never reporting is covered by this ceiling: the 4-second spin plus
  /// Triple Chance's 2-second margin (its own ceiling is 9 s for a 7 s wheel).
  static const Duration kWheelCeiling = Duration(seconds: 6);

  /// Offsets from W.
  static const Duration _popupOpensAt = Duration(milliseconds: 1500);
  static const Duration _popupClosesAt = Duration(milliseconds: 4000);
  static const Duration _sequenceEndsAt = Duration(milliseconds: 6000);

  /// The popup is never on screen for less than this, however late the reveal.
  static const Duration _minPopupVisible = Duration(milliseconds: 1200);

  /// The coin effect is not started if less than this is left before the popup.
  static const Duration _minCoinFxSlot = Duration(milliseconds: 500);

  /// The confirmation is asked for at these gaps: Triple Chance's budget, about
  /// 5.7 s in all, so a big round still being settled in batches gets time.
  static const List<Duration> _confirmDelays = [
    Duration.zero,
    Duration(milliseconds: 200),
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 2),
  ];

  /// The wheel calls this once, when it has stopped. Anything else (no
  /// sequence running, a second call) is ignored.
  void wheelLanded() => _completeWheel();

  void _completeWheel() {
    final waiting = _wheelLanded;
    _wheelLanded = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  void _onResult(Spin2WinRoundResult result) {
    unawaited(_runSequence(result));
  }

  Future<void> _runSequence(Spin2WinRoundResult result) async {
    // One sequence at a time (a repeat is also blocked by the sync's once-per-
    // round delivery), and none for a screen that has been left.
    if (!_attached || _sequenceRunning) return;
    final epoch = _epoch;
    bool stale() => epoch != _epoch;

    final stake = _board.total;
    // Sent (or still on its way): this player is a bettor. The round to ask about
    // is the one the bet went to, as in Triple Chance's Fix #6; a bet that was
    // still being sent when the result came belongs to the result's own round.
    final String? betRoundId = _submittedBets ? (_submittedRoundId ?? result.roundId) : null;

    final landed = Completer<void>();
    _wheelLanded = landed;
    _sequenceRunning = true;
    _stage = Spin2WinStage.spinning;
    _spinTarget = result;
    _numberRevealed = false;
    _showCoinFx = false;
    _popup = null;
    _lastOutcome = null;
    _balanceSyncFailed = false;
    _lockBoard(); // notifies

    // Asked for NOW, while the wheel turns, not after it has stopped.
    final Future<_Confirmed?>? confirmation =
        betRoundId == null ? null : _fetchConfirmed(betRoundId, epoch);

    try {
      await landed.future.timeout(kWheelCeiling);
    } on TimeoutException {
      debugPrint('Spin2WinProvider: the wheel did not report within $kWheelCeiling; carrying on.');
    }
    if (stale()) return;
    final landedAt = _now();

    final confirmed = confirmation == null ? null : await confirmation;
    if (stale()) return;

    // The reveal: the balance moves only now (as in Lucky Card: never before the
    // wheel has stopped), together with the number and the coins.
    if (confirmed != null && confirmed.balance != null && confirmed.ledgerVersion != null) {
      _wallet.syncAuthoritativeBalance(confirmed.balance!, confirmed.ledgerVersion!);
    }
    _balanceSyncFailed = confirmed != null && !confirmed.settledOrNoBet;
    final outcome = Spin2WinOutcome(
      roundId: result.roundId,
      winningNumber: result.winningNumber,
      bonusMultiplier: result.bonusMultiplier,
      stake: stake,
      payout: confirmed?.payout ?? 0,
    );
    _lastOutcome = outcome;
    // The strip gets the round at the same beat as the hub, never before.
    _revealedRounds.add(result.roundNumber);
    _mergeHistory([
      Spin2WinRecentRound(
        roundId: result.roundId,
        roundNumber: result.roundNumber,
        winningNumber: result.winningNumber,
        bonusMultiplier: result.bonusMultiplier,
        scheduledAt: result.scheduledAt,
      ),
    ]);
    _stage = Spin2WinStage.revealing;
    _numberRevealed = true;
    // Only started if there is room before the popup; a late reveal may have none.
    final untilPopup = _popupOpensAt - _now().difference(landedAt);
    if (outcome.won && untilPopup >= _minCoinFxSlot) _showCoinFx = true;
    notifyListeners();

    /// Waits until [offset] after W, then says whether this sequence is still
    /// the live one. Never waits a negative time.
    Future<bool> holdUntil(Duration offset) async {
      final remaining = offset - _now().difference(landedAt);
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      return !stale();
    }

    if (outcome.won) {
      if (!await holdUntil(_popupOpensAt)) return;
      _popup = outcome;
      _showCoinFx = false;
      notifyListeners();
      final popupOpenedAt = _now();

      if (!await holdUntil(_popupClosesAt)) return;
      // Never less than the minimum on screen, even when the reveal was late
      // (Triple Chance Issue #107).
      final shortfall = _minPopupVisible - _now().difference(popupOpenedAt);
      if (shortfall > Duration.zero) {
        await Future<void>.delayed(shortfall);
        if (stale()) return;
      }
      _popup = null;
      notifyListeners();
    }

    if (!await holdUntil(_sequenceEndsAt)) return;

    // The end of the round. A round caught only as a replay is not offered for
    // Rebet, as in Triple Chance.
    _sequenceRunning = false;
    _stage = Spin2WinStage.none;
    _spinTarget = null;
    _numberRevealed = false;
    _showCoinFx = false;
    _popup = null;
    endRound(saveForRebet: !result.isCatchUpReplay);
  }

  /// Asks the server what this player's bet came to, at Triple Chance's gaps
  /// (0 / 0.2 / 0.5 / 1 / 2 / 2 s). Returns null if the sequence went stale.
  /// Applies nothing itself: the balance is applied at the reveal, never earlier.
  Future<_Confirmed?> _fetchConfirmed(String roundId, int epoch) async {
    for (final delay in _confirmDelays) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (epoch != _epoch) return null;
      Spin2WinMyResult? mine;
      try {
        mine = await _api.getMyRoundResult(roundId);
      } catch (e) {
        debugPrint('Spin2WinProvider: getMyRoundResult failed: $e');
      }
      if (epoch != _epoch) return null;
      if (mine == null) continue;
      if (!mine.placedBet) {
        // The server has no bet for this round (it refused it, or it never
        // arrived): nothing was staked, and its balance is the truth.
        return _Confirmed(
          payout: 0,
          balance: mine.coinBalance,
          ledgerVersion: mine.ledgerVersion,
          settledOrNoBet: true,
        );
      }
      if (mine.isSettled) {
        return _Confirmed(
          payout: mine.totalPayout,
          balance: mine.coinBalance,
          ledgerVersion: mine.ledgerVersion,
          settledOrNoBet: true,
        );
      }
      // Placed but not settled yet: a big round is settled in batches. Ask again.
    }
    // Still not settled after the whole budget. Nothing is guessed: the real
    // balance catches up through the heartbeat.
    return const _Confirmed(payout: 0, settledOrNoBet: false);
  }

  // ── The history strip ───────────────────────────────────────────────────

  /// Loads the last 10 results from the server and merges them in. A failed or
  /// empty answer leaves the strip as it is, as Triple Chance does.
  Future<void> _loadHistory(int epoch) async {
    List<Spin2WinRecentRound> rounds;
    try {
      // One more than the strip holds: the current round may be hidden, and the
      // strip must still be full.
      rounds = await _api.getRecentRounds(limit: _historySize + 1);
    } catch (e) {
      debugPrint('Spin2WinProvider: getRecentRounds failed: $e');
      return;
    }
    if (epoch != _epoch || rounds.isEmpty) return;
    _mergeHistory(rounds);
    notifyListeners();
  }

  /// The strip shows the latest 10 results (the user's rule, 2026-10-24).
  static const int _historySize = 10;

  /// Merges [incoming] into the strip: by round (no duplicates, what is already
  /// there is kept), newest first, at most 10. A round of the CURRENT cycle that
  /// this screen has not revealed yet is left out: the database returns a round
  /// from the moment it is drawn (second 90), which is before the wheel stops,
  /// and the number must not show anywhere before then. Triple Chance does not
  /// have this rule, and its strip can show a winner early to a player who
  /// opens the screen mid-reveal; Lucky Card has it.
  void _mergeHistory(Iterable<Spin2WinRecentRound> incoming) {
    final current = sync.currentRound?.roundNumber ?? sync.clock.roundNumber;
    final byNumber = {for (final r in _history) r.roundNumber: r};
    for (final r in incoming) {
      if (r.roundNumber >= current && !_revealedRounds.contains(r.roundNumber)) continue;
      byNumber.putIfAbsent(r.roundNumber, () => r);
    }
    final merged = byNumber.values.toList()
      ..sort((a, b) => b.roundNumber.compareTo(a.roundNumber));
    _history
      ..clear()
      ..addAll(merged.take(_historySize));
  }

  // ── A round that never resolves ─────────────────────────────────────────

  /// The sync gave up: the round ended and its result never arrived. Mirrors
  /// Triple Chance (Issues #14 and #110): everyone is told, a bettor's board is
  /// dropped WITHOUT a refund (the stake really was taken, and the server will
  /// settle it on its own, so claiming a refund would be reversed by the next
  /// honest balance sync), and the saved Rebet bet is left alone. Nothing is
  /// done to the board while a sequence is running; it owns the board then.
  void _onResultUnavailable() {
    if (!_attached) return;
    if (!_sequenceRunning) {
      if (!_board.isEmpty) {
        final onBoard = _board.reset();
        // Only chips that were never sent can be given back.
        if (!_submittedBets) _wallet.setLocalBalance(_wallet.balance + onBoard);
      }
      _submittedBets = false;
      _betStatus = Spin2WinBetStatus.idle;
      _submittedRoundId = null;
      _applyLockToCountdown();
    }
    notifyListeners();
    onProblem?.call(const Spin2WinProblem.unresolved());
  }

  // ── Sending the bet ─────────────────────────────────────────────────────

  /// Sends the board to the server, once. Mirrors Triple Chance's early bet
  /// submission and its retry rules.
  Future<void> _submitBet() async {
    if (_board.isEmpty) return; // a spectator this round: nothing to send
    final epoch = _epoch;
    bool stale() => epoch != _epoch;

    // Second lock at the one place money moves: a bet that was already sent for
    // a DIFFERENT round means the board is left over from a round that ended
    // without being cleaned up (Triple Chance's Issue #110). Sending it again
    // would charge the player twice for a bet they did not place this round.
    // Dropped without a refund, because that stake was really taken.
    final currentRoundId = sync.currentRound?.roundId;
    if (_betStatus == Spin2WinBetStatus.submitted &&
        _submittedRoundId != null &&
        currentRoundId != null &&
        _submittedRoundId != currentRoundId) {
      _dropLeftoverBoard();
      return;
    }
    // Already sent, or on its way, for this round: sending it again is pointless.
    if (_betStatus == Spin2WinBetStatus.submitting ||
        _betStatus == Spin2WinBetStatus.submitted) {
      return;
    }

    _submittedBets = true;
    _betStatus = Spin2WinBetStatus.submitting;
    notifyListeners();

    final round = await sync.roundForBet();
    if (stale()) return;
    if (round == null) {
      _rejectBet(sync.lastRoundError ?? Spin2WinError.offline);
      return;
    }
    // The server would certainly refuse a bet for a round that has been drawn.
    if (round.isDrawn) {
      _rejectBet(Spin2WinError.roundClosed);
      return;
    }

    final bets = _board.toBetMap();
    var result = await _api.placeBet(roundId: round.roundId, bets: bets);
    if (stale()) return;

    // Retry only what may be a passing glitch (offline, a sign-in that briefly
    // failed to attach, an unrecognised error), at most 3 attempts a second
    // apart. Every other reason is a final answer from the server and retrying
    // it would only get the same answer, or waste the few seconds left.
    var attempt = 1;
    while (!result.success && (result.error?.isRetryable ?? false) && attempt < 3) {
      attempt++;
      await Future<void>.delayed(const Duration(seconds: 1));
      if (stale()) return;
      result = await _api.placeBet(roundId: round.roundId, bets: bets);
      if (stale()) return;
    }

    if (result.success) {
      _betStatus = Spin2WinBetStatus.submitted;
      _submittedRoundId = round.roundId;
      // The server's own balance, anchored to its version so an older figure
      // arriving late cannot undo it.
      _wallet.syncAuthoritativeBalance(result.coinBalance, result.ledgerVersion);
      notifyListeners();
    } else {
      _rejectBet(result.error ?? Spin2WinError.unknown);
    }
  }

  /// The server did not take the bet: give the chips back on screen, drop the
  /// board, forget the saved Rebet bet, and tell the screen why.
  void _rejectBet(Spin2WinError reason) {
    if (!_board.isEmpty) {
      final onBoard = _board.reset();
      _wallet.setLocalBalance(_wallet.balance + onBoard);
    }
    _board.clearRebetSnapshot();
    _submittedBets = false;
    _submittedRoundId = null;
    _betStatus = Spin2WinBetStatus.failed;
    notifyListeners();
    final kind = switch (reason) {
      Spin2WinError.offline ||
      Spin2WinError.unauthenticated ||
      Spin2WinError.accountBlocked =>
        Spin2WinProblemKind.connectionProblem,
      _ => Spin2WinProblemKind.betRejected,
    };
    onProblem?.call(Spin2WinProblem(kind, reason));
  }

  /// Drops a board left over from an earlier round, without a refund and without
  /// telling the player: that stake was genuinely taken, and the board was never
  /// theirs this round. The saved Rebet bet is untouched.
  void _dropLeftoverBoard() {
    _board.reset();
    _submittedBets = false;
    _betStatus = Spin2WinBetStatus.idle;
    _submittedRoundId = null;
    notifyListeners();
  }
}

/// What the server said about this player's bet for a round.
class _Confirmed {
  const _Confirmed({
    required this.payout,
    this.balance,
    this.ledgerVersion,
    required this.settledOrNoBet,
  });

  final int payout;
  final int? balance;
  final int? ledgerVersion;

  /// False only when the confirmation budget ran out with the bet still unsettled.
  final bool settledOrNoBet;
}
