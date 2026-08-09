import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/spin_result_model.dart';
import '../models/bet_model.dart';
import '../models/play_limits_config.dart';
import '../services/round_api_service.dart';
import '../services/sound_service.dart';
import '../services/round_sync_service.dart';
import 'auth_provider.dart';


enum BetSubmissionStatus { idle, submitting, submitted, failed }

class GameProvider extends ChangeNotifier {
  GameProvider() {
    // Bug #8 fix: initialise with safe fallback limits immediately so caps are
    // enforced from the very first frame — before the server responds.
    _playLimits = PlayLimitsConfig.fallback();
    _loadPlayLimits(); // server values will override the fallback when ready
  }

  // Bug #8 fix: non-nullable — always has safe hardcoded defaults as minimum.
  // 'late' satisfies Dart's definite-assignment rules since it is set in the constructor body.
  late PlayLimitsConfig _playLimits;
  PlayLimitsConfig get playLimits => _playLimits;

  // Bug #7 fix: exposed so game_screen can show a non-blocking warning.
  bool _balanceSyncFailed = false;
  bool get balanceSyncFailed => _balanceSyncFailed;
  void clearBalanceSyncFailed() {
    _balanceSyncFailed = false;
  }

  BetSubmissionStatus _betStatus = BetSubmissionStatus.idle;
  String? _submittedRoundId;

  BetSubmissionStatus get betStatus => _betStatus;
  String? get submittedRoundId => _submittedRoundId;

  void setBetStatus(BetSubmissionStatus status, {String? roundId}) {
    _betStatus = status;
    if (roundId != null) {
      _submittedRoundId = roundId;
    }
    notifyListeners();
  }

  void resetBetSubmissionStatus() {
    _betStatus = BetSubmissionStatus.idle;
    _submittedRoundId = null;
    notifyListeners();
  }

  BetRejection _lastRejection = BetRejection.ok;
  BetRejection get lastRejection => _lastRejection;

  void clearRejection() {
    _lastRejection = BetRejection.ok;
  }

  Future<void> _loadPlayLimits() async {
    // Override the fallback with the server's limits. If the call fails the
    // fallback stays in force, so caps are never absent.
    final limitsJson = await RoundApiService().getPlayLimits();
    if (limitsJson == null) return;
    _playLimits = PlayLimitsConfig.fromJson(limitsJson);
    notifyListeners();
  }

  // Issue #43 fix: was only ever fetched once, in the constructor above, so
  // a payout-multiplier change made on the dashboard never reached an
  // already-running app until it was fully closed and relaunched. Public so
  // RoundSyncService can call it once per round (see _deliverResult), right
  // when a fresh round -- and its own pinned rate -- has just begun.
  Future<void> refreshPlayLimits() => _loadPlayLimits();

  // ── Mode ─────────────────────────────────────────────────────────
  String _mode = 'single';
  bool _isDrawerOpen = false;

  // ── Betting ───────────────────────────────────────────────────────
  ChipValue? _activeChip = ChipValue.two;
  ChipValue? _lastActiveChip = ChipValue.two;
  final BetBoardState _board = BetBoardState();
  final List<BetAction> _history = []; // LIFO undo stack for REMOVE

  // ── REBET ─────────────────────────────────────────────────────────
  BetBoardState? _lastBetSnapshot; // snapshot of bets from previous spin
  bool _rebetUsed = false;          // true once rebet pressed OR manual bet placed

  // ── Global round ─────────────────────────────────────────────────
  // True once bets have been submitted to the server for the current round.
  bool _submittedBets = false;

  // ── Spin state ────────────────────────────────────────────────────
  bool _isSpinning = false;
  bool _isWaitingForResult = false;
  bool _spinAborted = false; // set true when user exits mid-spin
  SpinResult? _lastResult;
  SpinResult? _lastWinBoxResult;
  SpinResult? _pendingResult;

  // Balance data _fetchConfirmedResult() has learned from the server but not
  // yet applied. It only ever records these -- it must never call
  // auth.syncAuthoritativeBalance() itself, or the balance can update the
  // instant the server answers (often mid-spin, since the server usually
  // finishes settling well before the wheel stops), bypassing the staged
  // reveal timing entirely. onGlobalResult() is the sole place that applies
  // these, at the correct moment.
  int? _pendingSyncBalance;
  int? _pendingSyncLedgerVersion;

  // Set by RoundSyncService._fetchInitialRound() right before it triggers a
  // catch-up replay of a round that already finished while this player
  // wasn't on the game screen. onGlobalResult()'s tail cleanup checks this so
  // it doesn't set up a REBET option for a round the player only just caught
  // the replay of, rather than actually watching live.
  bool _isCatchUpReplay = false;
  void markPendingCatchUpReplay() => _isCatchUpReplay = true;

  // Completed by WheelWidget the instant its 3rd (black) ring finishes
  // landing -- the real signal that all 3 digits are visually revealed.
  // onGlobalResult() waits on this instead of guessing a fixed duration, so
  // the balance/popup reveal can never outrun what's actually on screen.
  Completer<void>? _wheelRevealCompleter;

  /// Called by WheelWidget once its animation has genuinely finished.
  void notifyWheelRevealComplete() => _completeWheelReveal();

  void _completeWheelReveal() {
    final c = _wheelRevealCompleter;
    if (c != null && !c.isCompleted) c.complete();
  }

  String? _error;

  // ── Countdown ─────────────────────────────────────────────────────
  int _countdown = 90;
  Timer? _countdownTimer;
  VoidCallback? _onTimerExpire;

  // ── History ───────────────────────────────────────────────────────
  final List<SpinResult> _globalHistory = [];

  // ── Triple page ───────────────────────────────────────────────────
  int _triplePage = 0;

  // ── Getters ───────────────────────────────────────────────────────
  String? get error          => _error;
  void clearError() {
    _error = null;
  }

  String get mode            => _mode;
  bool get isDrawerOpen      => _isDrawerOpen;
  ChipValue? get activeChip  => _activeChip;
  BetBoardState get board    => _board;
  bool get isSpinning        => _isSpinning;
  bool get isWaitingForResult => _isWaitingForResult;
  SpinResult? get lastResult => _lastResult;
  SpinResult? get lastWinBoxResult => _lastWinBoxResult;
  SpinResult? get pendingResult => _pendingResult;
  int get countdown          => _countdown;

  /// True when REBET button should be shown instead of DOUBLE.
  bool get canRebet =>
      _lastBetSnapshot != null &&
      !_lastBetSnapshot!.isEmpty &&
      !_rebetUsed &&
      !_isSpinning &&
      _board.isEmpty;
  List<SpinResult> get globalHistory => List.unmodifiable(_globalHistory);
  int get triplePage         => _triplePage;

  /// Total stake across all three boards.
  int get totalBet => _board.total;

  /// Per-mode play amount for the left tab strip badges.
  int playForMode(String m) {
    if (m == 'single') return _board.singleTotal;
    if (m == 'double') return _board.doubleTotal;
    if (m == 'triple') return _board.tripleTotal;
    return 0;
  }

  /// Per-mode win amount (last round) — shows only that board's contribution.
  int winForMode(String m) {
    final result = _lastWinBoxResult;
    if (result == null || !result.won) return 0;
    if (m == 'single') return result.singleWinAmount;
    if (m == 'double') return result.doubleWinAmount;
    if (m == 'triple') return result.tripleWinAmount;
    return 0;
  }

  // ── Auto Spin Callback ──────────────────────────────────────────
  VoidCallback? _onNoBets;

  void setAutoSpinCallback(VoidCallback? expireCallback, {VoidCallback? noBetsCallback}) {
    _onTimerExpire = expireCallback;
    _onNoBets = noBetsCallback;
  }

  // ── Mode management ───────────────────────────────────────────────
  void openDrawerWithMode(String newMode, AuthProvider auth) {
    if (_isSpinning || _countdown <= 5) return;
    if (_mode == newMode && _isDrawerOpen) {
      _isDrawerOpen = false;
      notifyListeners();
      return;
    }
    _mode = newMode;
    _triplePage = 0;
    _isDrawerOpen = true;
    _updateTimerState(auth);
    notifyListeners();
  }

  void closeDrawer() {
    _isDrawerOpen = false;
    notifyListeners();
  }

  // ── Chip selection ─────────────────────────────────────────────────
  /// Selects the active chip. Does NOT move any balance — the chip
  /// is just "picked up" ready for the next cell tap.
  void selectChip(ChipValue chip) {
    if (_countdown <= 5) return;
    _activeChip = chip;
    _lastActiveChip = chip;
    SoundService().playButtonClick();
    notifyListeners();
  }

  /// Deselects the active chip — "puts it down" without placing it.
  void deselectChip() {
    _activeChip = null;
    notifyListeners();
  }

  // ── Number selection (chip-stack model) ────────────────────────────
  /// Adds the active chip's amount to [cellKey] on [boardType].
  /// Deducts from balance immediately.
  void placeBet(BoardType boardType, String cellKey, AuthProvider auth) {
    if (_countdown <= 5) return;
    if (_activeChip == null) return;
    final amount = _activeChip!.amount;
    if (auth.coinBalance < amount) {
      _error = 'INSUFFICIENT_COINS';
      notifyListeners();
      return; // insufficient funds guard
    }

    final map = _board.boardFor(boardType);
    final currentAmount = map[cellKey] ?? 0;

    // Bug #8 fix: _playLimits is always non-null (fallback applied at construction).
    final cap = _playLimits.limitsFor(boardType).max;
    if (currentAmount + amount > cap) {
      _lastRejection = BetRejection(BetRejectReason.cellMaxExceeded, board: boardType, cellKey: cellKey, cap: cap);
      notifyListeners();
      return;
    }

    _lastRejection = BetRejection.ok;
    _rebetUsed = true; // any manual bet switches REBET → DOUBLE
    _lastWinBoxResult = null; // reset WIN display as soon as user bets
    _betStatus = BetSubmissionStatus.idle;
    _submittedRoundId = null;
    map[cellKey] = currentAmount + amount;
    _history.add(BetAction(board: boardType, cellKey: cellKey, amount: amount));
    auth.updateBalance(auth.coinBalance - amount);

    SoundService().playNumberSelect();
    HapticFeedback.selectionClick();
    _updateTimerState(auth);
    notifyListeners();
  }

  /// Places a bet on every cell in a row using the active chip.
  /// [cellKeys] is the list of cell key strings for that row.
  void placeBetOnRow(BoardType boardType, List<String> cellKeys, AuthProvider auth) {
    if (_countdown <= 5) return;
    if (_activeChip == null) return;
    final amount = _activeChip!.amount;

    final map = _board.boardFor(boardType);
    // Bug #8 fix: _playLimits is always non-null.
    final cap = _playLimits.limitsFor(boardType).max;

    // Build filtered list: skip cells that would exceed the cap
    bool anySkipped = false;
    final validKeys = <String>[];
    for (final key in cellKeys) {
      final current = map[key] ?? 0;
      if (current + amount > cap) {
        anySkipped = true; // this cell is full — skip but continue
      } else {
        validKeys.add(key);
      }
    }

    // If every cell was skipped (e.g., entire row is full), just show warning
    if (validKeys.isEmpty) {
      _lastRejection = BetRejection(BetRejectReason.cellMaxExceeded, board: boardType, cap: cap);
      notifyListeners();
      return;
    }

    _lastRejection = BetRejection.ok;
    _rebetUsed = true; // any manual bet switches REBET → DOUBLE
    _lastWinBoxResult = null; // reset WIN display as soon as user bets
    bool hasInsufficientFunds = false;
    for (final key in validKeys) {
      if (auth.coinBalance < amount) {
        hasInsufficientFunds = true;
        break;
      }
      map[key] = (map[key] ?? 0) + amount;
      _history.add(BetAction(board: boardType, cellKey: key, amount: amount));
      auth.updateBalance(auth.coinBalance - amount);
    }
    if (hasInsufficientFunds) {
      _error = 'INSUFFICIENT_COINS';
    }
    // Show limit warning if some cells were skipped (informational)
    if (anySkipped) {
      _lastRejection = BetRejection(BetRejectReason.cellMaxExceeded, board: boardType, cap: cap);
    }
    SoundService().playChipClick();
    _updateTimerState(auth);
    notifyListeners();
  }

  /// Randomly places bets on [count] cells for [boardType].
  /// Refunds any existing bets on the board type first to avoid overflow.
  void placeRandomBets(BoardType boardType, int count, AuthProvider auth) {
    if (_countdown <= 5) return;
    if (_activeChip == null) return;

    // 1. Clear existing bets for this board type (or only current page for Triple) and refund them
    final map = _board.boardFor(boardType);
    int totalRefund = 0;

    if (boardType == BoardType.triple) {
      final base = _triplePage * 100;
      final Set<String> pageKeys = List.generate(100, (i) => (base + i).toString().padLeft(3, '0')).toSet();
      
      // Refund only bets on the current page
      for (final key in pageKeys) {
        if (map.containsKey(key)) {
          totalRefund += map[key]!;
          map.remove(key);
        }
      }
      // Remove only current page actions from history
      _history.removeWhere((action) => action.board == BoardType.triple && pageKeys.contains(action.cellKey));
    } else {
      // For Single or Double board, clear the entire board
      for (final val in map.values) {
        totalRefund += val;
      }
      map.clear();
      _history.removeWhere((action) => action.board == boardType);
    }
    auth.updateBalance(auth.coinBalance + totalRefund);

    // 2. Build candidates (100 cells)
    List<String> pool = [];
    if (boardType == BoardType.double_) {
      pool = List.generate(100, (i) => i.toString().padLeft(2, '0'));
    } else if (boardType == BoardType.triple) {
      final base = _triplePage * 100;
      pool = List.generate(100, (i) => (base + i).toString().padLeft(3, '0'));
    } else {
      pool = List.generate(10, (i) => '$i');
    }

    // 3. Shuffle pool and take count
    final random = math.Random();
    pool.shuffle(random);
    final selectedKeys = pool.take(count).toList();

    // 4. Place active chip bets
    final betAmount = _activeChip!.amount;
    // Bug #8 fix: _playLimits is always non-null.
    final cap = _playLimits.limitsFor(boardType).max;

    // If the active chip itself exceeds the cap, we can't place any random bets.
    if (betAmount > cap) {
      _lastRejection = BetRejection(BetRejectReason.cellMaxExceeded, board: boardType, cap: cap);
      notifyListeners();
      return;
    }

    _lastRejection = BetRejection.ok;
    _rebetUsed = true; // any manual bet switches REBET → DOUBLE
    bool hasInsufficientFunds = false;
    for (final key in selectedKeys) {
      if (auth.coinBalance < betAmount) {
        hasInsufficientFunds = true;
        break;
      }
      map[key] = betAmount;
      _history.add(BetAction(board: boardType, cellKey: key, amount: betAmount));
      auth.updateBalance(auth.coinBalance - betAmount);
    }
    if (hasInsufficientFunds) {
      _error = 'INSUFFICIENT_COINS';
    }

    SoundService().playChipClick();
    _updateTimerState(auth);
    notifyListeners();
  }

  // ── DOUBLE button ──────────────────────────────────────────────────
  /// Doubles every staked amount on every board, skipping cells that
  /// would exceed their board's cap. Shows a warning if any were skipped.
  void doDouble(AuthProvider auth) {
    if (_isSpinning || _board.isEmpty || _countdown <= 5) return;

    // Calculate the extra cost of doubling only valid cells
    int extraCost = 0;
    bool anySkipped = false;
    BoardType? skippedBoard;
    int? skippedCap;

    // Bug #8 fix: _playLimits is always non-null.
    for (final type in BoardType.values) {
      final cap = _playLimits.limitsFor(type).max;
      final map = _board.boardFor(type);
      for (final entry in map.entries) {
        if (entry.value * 2 > cap) {
          anySkipped = true;
          skippedBoard = type;
          skippedCap = cap;
          // This cell stays as-is, no cost
        } else {
          extraCost += entry.value; // cost to double = current value
        }
      }
    }

    // Check balance against cells that WILL be doubled
    if (auth.coinBalance < extraCost) {
      _error = 'INSUFFICIENT_COINS';
      notifyListeners();
      return;
    }

    _lastRejection = BetRejection.ok;
    auth.updateBalance(auth.coinBalance - extraCost);
    _lastWinBoxResult = null; // reset WIN display when user doubles

    // F-8 FIX — decide skip/double ONCE per cell, then apply that same decision
    // to both the board and the undo history.
    //
    // The previous version made the decision twice. The board loop skipped a
    // cell when `value * 2 > cap`, but the history loop then re-read the board
    // AFTER the update and doubled the record whenever `currentVal <= cap` —
    // which is true for a skipped cell, since it was left unchanged. The undo
    // entry therefore doubled while the stake did not.
    //
    // Reproduction (triple cap 100): stake 60 on "000" -> DOUBLE leaves the
    // cell at 60 but records 120 -> REMOVE refunds 120 for a 60-coin stake.
    // The player's displayed balance gained 60 coins they never staked, and
    // their next bet was rejected server-side for insufficient funds.
    final doubled = <BoardType, Set<String>>{};

    for (final type in BoardType.values) {
      final cap = _playLimits.limitsFor(type).max;
      final map = _board.boardFor(type);
      final applied = <String>{};

      for (final key in map.keys.toList()) {
        final value = map[key]!;
        if (value * 2 > cap) continue; // at cap — leave the stake alone
        map[key] = value * 2;
        applied.add(key);
      }
      doubled[type] = applied;
    }

    // Only history entries whose cell actually doubled are doubled too.
    for (int i = 0; i < _history.length; i++) {
      final action = _history[i];
      if (doubled[action.board]?.contains(action.cellKey) ?? false) {
        _history[i] = BetAction(
          board: action.board,
          cellKey: action.cellKey,
          amount: action.amount * 2,
        );
      }
    }

    // If some cells were skipped, show the warning
    if (anySkipped) {
      _lastRejection = BetRejection(BetRejectReason.cellMaxExceeded, board: skippedBoard, cap: skippedCap ?? 0);
    }

    _updateTimerState(auth);
    notifyListeners();
  }

  // ── CLEAR button ───────────────────────────────────────────────
  void clearBets(AuthProvider auth) {
    if (_isSpinning || _countdown <= 5) return;
    // Refund the full board total back to balance
    auth.updateBalance(auth.coinBalance + _board.total);
    _board.clearAll();
    _history.clear();
    _rebetUsed = false; // allow REBET to reappear after clearing
    _betStatus = BetSubmissionStatus.idle;
    _submittedRoundId = null;
    _checkAndRestoreActiveChip();
    _updateTimerState(auth);
    notifyListeners();
  }

  // ── REMOVE button ─────────────────────────────────────────────────
  /// Undoes the last chip placement (LIFO). Refunds the chip amount.
  void removeLast(AuthProvider auth) {
    if (_countdown <= 5) return;
    if (_history.isEmpty) return;
    final last = _history.removeLast();
    final map = _board.boardFor(last.board);
    final remaining = (map[last.cellKey] ?? 0) - last.amount;
    if (remaining <= 0) {
      map.remove(last.cellKey);
    } else {
      map[last.cellKey] = remaining;
    }
    auth.updateBalance(auth.coinBalance + last.amount);
    _checkAndRestoreActiveChip();
    _updateTimerState(auth);
    notifyListeners();
  }

  /// Removes only the LAST chip placed on [cellKey] of [boardType].
  /// Used when no chip is selected (tap-to-deselect mode).
  void removeChipFromCell(BoardType boardType, String cellKey, AuthProvider auth) {
    if (_countdown <= 5) return;
    if (_activeChip != null) return; // only in deselect mode
    // Find the most recent history entry for this exact cell
    final idx = _history.lastIndexWhere(
        (a) => a.board == boardType && a.cellKey == cellKey);
    if (idx < 0) return; // nothing on this cell
    final action = _history[idx];
    _history.removeAt(idx);
    final map = _board.boardFor(boardType);
    final remaining = (map[cellKey] ?? 0) - action.amount;
    if (remaining <= 0) {
      map.remove(cellKey);
    } else {
      map[cellKey] = remaining;
    }
    auth.updateBalance(auth.coinBalance + action.amount);
    SoundService().playButtonClick();
    HapticFeedback.selectionClick();
    _checkAndRestoreActiveChip();
    _updateTimerState(auth);
    notifyListeners();
  }

  /// Removes the last chip from each occupied cell in [cellKeys] on [boardType].
  /// Called when a row/col arrow is tapped in "remove mode" (no chip held).
  void removeChipFromRow(BoardType boardType, List<String> cellKeys, AuthProvider auth) {
    if (_countdown <= 5) return;
    if (_activeChip != null) return; // only active in deselect mode

    bool anyRemoved = false;
    for (final cellKey in cellKeys) {
      // Find the most recent history entry for this cell
      final idx = _history.lastIndexWhere(
          (a) => a.board == boardType && a.cellKey == cellKey);
      if (idx < 0) continue; // cell is empty — skip

      final action = _history[idx];
      _history.removeAt(idx);
      final map = _board.boardFor(boardType);
      final remaining = (map[cellKey] ?? 0) - action.amount;
      if (remaining <= 0) {
        map.remove(cellKey);
      } else {
        map[cellKey] = remaining;
      }
      auth.updateBalance(auth.coinBalance + action.amount);
      anyRemoved = true;
    }

    if (anyRemoved) {
      SoundService().playButtonClick();
      HapticFeedback.selectionClick();
      _checkAndRestoreActiveChip();
      _updateTimerState(auth);
      notifyListeners();
    }
  }

  // NOTE: Legacy single-player doSpin is removed (BUG-03).
  // All rounds are 100% multiplayer synchronized driven by onGlobalResult().


  void clearRebetSnapshot() {
    _lastBetSnapshot = null;
    _rebetUsed = false;
    notifyListeners();
  }

  void _checkAndRestoreActiveChip() {
    if (_board.total == 0 && _activeChip == null) {
      _activeChip = _lastActiveChip ?? ChipValue.two;
    }
  }

  void clearLastResult() {
    _lastResult = null;
    notifyListeners();
  }

  // ── REBET ─────────────────────────────────────────────────────────────
  /// Restores the previous round's bets onto the current board.
  void rebet(AuthProvider auth) {
    if (_countdown <= 5) return;
    if (_lastBetSnapshot == null || _lastBetSnapshot!.isEmpty) return;

    // Calculate total cost of previous bets
    final total = _lastBetSnapshot!.total;
    if (auth.coinBalance < total) {
      _error = 'INSUFFICIENT_COINS';
      notifyListeners();
      return;
    }

    // Restore bets board by board
    for (final type in BoardType.values) {
      final srcMap = _lastBetSnapshot!.boardFor(type);
      final dstMap = _board.boardFor(type);
      for (final entry in srcMap.entries) {
        dstMap[entry.key] = entry.value;
        _history.add(BetAction(board: type, cellKey: entry.key, amount: entry.value));
      }
    }

    auth.updateBalance(auth.coinBalance - total);
    _rebetUsed = true; // switches button back to DOUBLE
    _lastWinBoxResult = null; // reset WIN display on rebet
    SoundService().playChipClick();
    _updateTimerState(auth);
    notifyListeners();
  }

  Future<void> loadGlobalHistory() async {
    try {
      // v2 returns typed RecentRound objects, and only rounds that were really
      // drawn. v1 synthesised MD5 digits for missing rounds, so the strip could
      // show numbers that never settled a bet (finding C-3).
      final rounds = await RoundApiService().getRecentRounds(limit: 10);
      if (rounds.isNotEmpty) {
        _globalHistory
          ..clear()
          ..addAll(rounds.map((r) => SpinResult(
                id: r.roundId,
                red: r.red,
                green: r.green,
                black: r.black,
                mode: 'global',
                selections: const [],
                chipValue: 0,
                won: false,
                deductedAmount: 0,
                winAmount: 0,
                singleWinAmount: 0,
                doubleWinAmount: 0,
                tripleWinAmount: 0,
                netChange: 0,
                createdAt: r.scheduledAt,
              )));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('loadGlobalHistory error: $e');
    }
  }

  // ── Countdown (UTC Wall-Clock Synchronized — must match server's epoch formula) ────────
  void _updateTimerState(AuthProvider auth) {
    if (!_isSpinning) {
      _startCountdownInternal();
    } else {
      _stopCountdownTimer();
    }
  }

  /// Returns the current cycle position (1–103) from raw UTC epoch seconds.
  /// Must NOT have any timezone offset — the server (get_current_round RPC)
  /// uses bare EXTRACT(EPOCH FROM NOW()) with no offset.
  int _computeUtcRemainingCycle() {
    final nowSecs = RoundSyncService().syncedNowSecs;
    return (103 - (nowSecs % 103)).toInt(); // 1 to 103
  }

  int _cycleToCountdown(int cycle) {
    if (cycle >= 13) return (cycle - 13).clamp(0, 90);
    return 0;
  }

  /// Called when the app resumes after being backgrounded long enough that
  /// the countdown timer may have been frozen by the OS straight through its
  /// own 5-second submission trigger (Timer.periodic does not queue up
  /// missed ticks -- it just resumes from wherever the clock actually is).
  ///
  /// Recomputes the countdown directly from the real clock (not from
  /// whatever the frozen timer last saw) and, if the round has genuinely
  /// passed its cutoff but the board was never actually sent, fires the
  /// exact same trigger the normal 5-second mark uses -- not a separate
  /// submission path -- so _handleEarlyBetSubmission's own
  /// markBetsSubmitted() runs synchronously before this returns, and
  /// abortSpin()'s existing refund-if-unsubmitted check correctly sees a
  /// bet in flight instead of wrongly refunding one that should go through.
  void catchUpMissedSubmissionIfNeeded() {
    if (_isSpinning || _board.isEmpty) return;
    if (_betStatus == BetSubmissionStatus.submitted || _betStatus == BetSubmissionStatus.submitting) return;
    final liveCountdown = _cycleToCountdown(_computeUtcRemainingCycle());
    if (liveCountdown <= 5) {
      _onNoBets?.call();
    }
  }

  void startCountdown() {
    _startCountdownInternal();
  }

  void _startCountdownInternal() {
    if (_countdownTimer != null && _countdownTimer!.isActive) return;
    
    int lastCycle = _computeUtcRemainingCycle();
    _countdown = _cycleToCountdown(lastCycle);
    notifyListeners();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_isSpinning) return; // Keep countdown frozen at 00 during spin

      final currentCycle = _computeUtcRemainingCycle();
      
      if (lastCycle != currentCycle) {
        final previous = lastCycle;
        lastCycle = currentCycle;
        
        _countdown = _cycleToCountdown(currentCycle);

        if (_countdown == 5 && previous >= 14) {
          SoundService().playNoBets();
          _lastWinBoxResult = null;
          if (_isDrawerOpen) closeDrawer();
          _onNoBets?.call(); // Triggers early bet submission at NO MORE PLAY (countdown 5)
        }

        // Did we cross the betting boundary? (previous 14 -> current 13, which is 00s / draw second)
        if (previous == 14 && currentCycle == 13 && _onTimerExpire != null) {
          _onTimerExpire?.call(); // Triggers GameScreen._handleSpin()
        }

        notifyListeners();
      }
    });
  }

  /// Stops the countdown timer WITHOUT resetting the value (used mid-spin).
  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    // F-11: recompute from the wall clock rather than hard-coding a value.
    // v1 reset to 60 in a 90-second model, so the UI briefly showed a
    // countdown that had never been correct.
    _countdown = _cycleToCountdown(_computeUtcRemainingCycle());
    notifyListeners();
  }

  /// Called when user exits the game screen.
  /// Aborts any pending spin, cancels timers, and clears callbacks.
  ///
  /// Issue #10 fix: the board is always cleared here if it has anything on
  /// it -- onGlobalResult()'s own end-of-round cleanup can't be relied on to
  /// do this, since polling (and onGlobalResult itself) stops the moment
  /// this screen is left and won't resume until the player returns.
  /// Whether the balance is also *refunded* depends on _submittedBets: if
  /// the bet was never actually sent to the server, it's refunded (nothing
  /// real happened); if it was already submitted, the board still clears
  /// (so the player doesn't see stale chips) but the coins are left alone --
  /// that's a real, valid bet the server will settle on its own regardless
  /// of this client's connection state, and the balance updates correctly
  /// via the heartbeat or the next round's own confirmation. Deliberately
  /// does NOT touch _lastBetSnapshot -- that's the *previous*, actually-
  /// completed round's bets, kept for the REBET button, unrelated to this
  /// abandoned board.
  ///
  /// [auth] is nullable so every other abort mechanic below (unchanged from
  /// before this fix) still runs unconditionally even in the rare case the
  /// caller couldn't obtain an AuthProvider (e.g. context already torn
  /// down) -- only the refund step (never the board-clear itself) is
  /// skipped in that case.
  void abortSpin(AuthProvider? auth) {
    _spinAborted = true;
    _isSpinning = false;
    _onTimerExpire = null;
    stopCountdown();
    SoundService().stopAll();
    // Unblock onGlobalResult() immediately if it's mid-wait for the wheel --
    // otherwise it would sit idle until the safety timeout, for no reason,
    // since there's no longer a screen to reveal the result on anyway.
    _completeWheelReveal();

    // The "WIN: X" badge is normally cleared either by placing a new bet or
    // by the countdown ticking down to 5s while the player stays on screen --
    // neither is guaranteed here: the countdown timer just stopped above, and
    // right after a win the board is already empty (the round's own cleanup
    // already ran), so the board-clear block below wouldn't touch it either.
    // Cleared unconditionally so a stale win from an already-finished round
    // can't still be showing the next time the player opens the game.
    _lastWinBoxResult = null;

    // The board is always cleared here, regardless of submission status --
    // onGlobalResult()'s own cleanup can't be relied on to do it, since
    // polling (and therefore onGlobalResult itself) stops the moment this
    // screen is left, and won't resume until the player comes back. A
    // submitted bet is only ever refunded if it was never actually sent to
    // the server (!_submittedBets) -- a real, submitted bet is left to settle
    // normally; its balance still correctly arrives via the heartbeat or the
    // next round's own confirmation, independent of this board's state.
    if (!_board.isEmpty) {
      if (auth != null && !_submittedBets) {
        auth.updateBalance(auth.coinBalance + _board.total);
      }
      _board.clearAll();
      _history.clear();
      _rebetUsed = false;
      // Matches clearBets()/refundRejectedBets()'s existing cleanup exactly,
      // for consistency -- reset so a stale "submitted" status from this
      // abandoned round can't linger into whatever the player does next.
      _submittedBets = false;
      _betStatus = BetSubmissionStatus.idle;
      _submittedRoundId = null;
      _checkAndRestoreActiveChip();
      notifyListeners();
    }
  }

  void resetCountdown(AuthProvider auth) {
    stopCountdown();
    _isSpinning = false;
    if (_onTimerExpire != null) {
      _startCountdownInternal();
    }
  }


  // ── Global Round Result ────────────────────────────────────────────
  /// Called by RoundSyncService when the server broadcasts the global round result.
  /// The [result] contains red/green/black from the server.
  /// We calculate win amounts locally from the player's own staked bets.
  Future<void> onGlobalResult(SpinResult serverResult, AuthProvider auth) async {
    // M-5: the old holdHeartbeatBalance() lock that used to open this method is
    // gone. Balance ordering is now handled by ledger_version, so the six early
    // returns below can no longer leak a lock and freeze the balance.
    if (_isSpinning && _pendingResult != null) return; // guard against double-call during active spin

    _isSpinning = true;
    _spinAborted = false;
    _lastResult = null;
    _pendingResult = null;
    _pendingSyncBalance = null; // defensive: discard any unconsumed data from a prior aborted spin
    _pendingSyncLedgerVersion = null;
    _balanceSyncFailed = false; // FIX #3A: Clear any stale banner from previous round BEFORE spin starts
    // Captured into a local and reset immediately -- not left live across the
    // whole function -- so it can never leak into a later round if THIS
    // round's own processing gets aborted before reaching the tail cleanup
    // below where it's actually used.
    final isCatchUpReplay = _isCatchUpReplay;
    _isCatchUpReplay = false;
    _stopCountdownTimer();
    notifyListeners();

    // Snapshot existing bets BEFORE clearing them
    final singleSnap = Map<String, int>.from(_board.single);
    final doubleSnap  = Map<String, int>.from(_board.double_);
    final tripleSnap  = Map<String, int>.from(_board.triple);
    final totalDeducted = _board.total; // already deducted server-side via submitBets

    // Issue #22 resolution: no local win calculation anymore. The drawn
    // digits are shown immediately (everyone sees the same digits at the
    // same time -- that part never needed a guess), but the win amount is
    // unknown until the server confirms it via _fetchConfirmedResult below.
    final pendingSpin = SpinResult(
      id:              serverResult.id,
      red:             serverResult.red,
      green:           serverResult.green,
      black:           serverResult.black,
      mode:            _mode,
      selections:      [...singleSnap.keys, ...doubleSnap.keys, ...tripleSnap.keys],
      chipValue:       0,
      won:             false,
      deductedAmount:  totalDeducted,
      winAmount:       0,
      singleWinAmount: 0,
      doubleWinAmount: 0,
      tripleWinAmount: 0,
      netChange:       0,
      createdAt:       serverResult.createdAt,
    );

    // Trigger wheel animation. The completer is created and assigned before
    // notifyListeners() so it's guaranteed to exist by the time the wheel
    // widget reacts and starts animating -- no window where the wheel could
    // finish and call notifyWheelRevealComplete() before anything is
    // listening for it.
    final revealCompleter = Completer<void>();
    _wheelRevealCompleter = revealCompleter;
    _pendingResult = pendingSpin;
    _isWaitingForResult = false;
    notifyListeners();

    // Wait for the wheel to report it has genuinely finished revealing all 3
    // digits, instead of guessing a fixed duration -- a device hiccup could
    // previously make the real 8-second wait outrun the wheel's own (~7s)
    // animation, revealing the balance/popup while the wheel was still mid-
    // spin. The 9s ceiling is a safety net only (covers the wheel's own
    // worst-case ~7s plus tolerance for it to start reacting), not the
    // primary mechanism -- it should essentially never be hit in practice.
    try {
      await revealCompleter.future.timeout(const Duration(milliseconds: 9000));
    } on TimeoutException {
      debugPrint('onGlobalResult: wheel did not report completion within 9s; revealing anyway.');
    }
    if (_spinAborted) return;
    final wheelStoppedAt = DateTime.now();

    // Ask the server for the real, confirmed result. Sequential and
    // awaited -- not fire-and-forget -- so two rounds' confirmations can
    // never race each other (this is what closes Issue #45's root cause
    // structurally, not just with a version-check guard).
    //
    // Issue #48 amendment: run the fetch alongside a flat 300ms floor and
    // wait for whichever finishes later, so the balance can never become
    // visible before wheel-stop + 300ms -- even though the server has
    // typically already answered by the time the wheel stops. The fetch's
    // own retry logic is untouched; this only holds back when its result is
    // allowed to be revealed.
    var resolvedResult = pendingSpin;
    if (totalDeducted > 0) {
      // FIX BUG #6: Use the round ID bets were submitted to, NOT the result round ID.
      // After a round transition, serverResult.id may point to a DIFFERENT round than
      // the one the bet was placed on, causing get_my_round_result to return placed_bet=false.
      final betRoundId = RoundSyncService().betRoundId;
      final cleanRoundId = (betRoundId ?? serverResult.id).replaceFirst('round_', '');
      final results = await Future.wait([
        _fetchConfirmedResult(cleanRoundId, pendingSpin),
        Future.delayed(const Duration(milliseconds: 300)),
      ]);
      resolvedResult = results[0] as SpinResult;
    }
    if (_spinAborted) return;

    // ⚡ Push result to top history grid. Guarded against the round already
    // being there -- a defense-in-depth safety net for the narrow case where
    // loadGlobalHistory()'s own initial fetch (fired when the game screen
    // first opens) happens to land after this insert for the same round,
    // e.g. joining mid-round triggers a catch-up replay of the round
    // loadGlobalHistory() may have just fetched.
    if (_globalHistory.isEmpty || _globalHistory.first.id != resolvedResult.id) {
      _globalHistory.insert(0, resolvedResult);
      if (_globalHistory.length > 10) _globalHistory.removeLast();
    }

    // Balance + the small "WIN: X" badge reveal now -- wheel-stop + 300ms
    // (or later, only if the server genuinely hadn't answered by then). This
    // is the ONLY place _fetchConfirmedResult()'s discovered balance is ever
    // applied -- see _pendingSyncBalance's doc comment for why it isn't
    // applied inside the fetch itself.
    if (_pendingSyncBalance != null && _pendingSyncLedgerVersion != null) {
      auth.syncAuthoritativeBalance(_pendingSyncBalance!, _pendingSyncLedgerVersion!);
      _pendingSyncBalance = null;
      _pendingSyncLedgerVersion = null;
    }
    _lastWinBoxResult = resolvedResult;
    _pendingResult = null;
    notifyListeners();

    // Wait 5s result display window (exact 13s total sequence: 7s spin + 1s gap + 5s display)
    if (resolvedResult.won) {
      // 1. Popup opens at wheel-stop + 1.0s exactly -- wait out whatever's
      // left of that budget after the balance reveal above. Clamped so a
      // slow server response can never make this wait a negative duration.
      final elapsedSinceWheelStop = DateTime.now().difference(wheelStoppedAt);
      final remainingToPopup = const Duration(milliseconds: 1000) - elapsedSinceWheelStop;
      if (remainingToPopup > Duration.zero) {
        await Future.delayed(remainingToPopup);
      }
      if (_spinAborted) return;

      _lastResult = resolvedResult;
      SoundService().playWin();
      notifyListeners();

      // 2. Show Win Popup for 2.5 seconds (2,500ms)
      await Future.delayed(const Duration(milliseconds: 2500));
      if (_spinAborted) return;

      // 3. Hide Win Popup after 2.5 seconds
      _lastResult = null;
      notifyListeners();

      // 4. Wait remaining 2.5 seconds (2,500ms) to complete exact 5.0-second display window
      await Future.delayed(const Duration(milliseconds: 2500));
      if (_spinAborted) return;
    } else {
      // Loss: Wait full 5.0 seconds (5,000ms)
      await Future.delayed(const Duration(milliseconds: 5000));
      if (_spinAborted) return;
    }

    // Cleanup and auto-resume UTC timer for next round cleanly at 90s
    _isWaitingForResult = false;
    _lastResult = null;

    if (isCatchUpReplay) {
      // This round already finished while the player wasn't on the game
      // screen -- they only just caught its replay after rejoining, not
      // watched it live. Don't offer it as a REBET option.
    } else if (!_board.isEmpty) {
      _lastBetSnapshot = BetBoardState()
        ..single.addAll(_board.single)
        ..double_.addAll(_board.double_)
        ..triple.addAll(_board.triple);
    }
    _rebetUsed = false;
    _submittedBets = false;
    _betStatus = BetSubmissionStatus.idle;
    _submittedRoundId = null;
    _board.clearAll();
    _history.clear();
    _checkAndRestoreActiveChip();
    _isSpinning = false;
    resetCountdown(auth);
  }

  /// Waits for the server's real, confirmed result for [roundId] -- replaces
  /// the old _syncBalanceInBackground (which fired an unawaited background
  /// guess-correction after showing a local estimate). This is now the ONLY
  /// way a round's win amount is ever determined -- there is no local
  /// calculation left to correct.
  ///
  /// Fast-first, backing off: checks immediately (often already settled by
  /// the time the 8s spin animation finishes), then re-checks at increasing
  /// intervals if not. Bounded (~5.7s total) so a very large, still-draining
  /// round (Issue #42's batching) degrades to "not yet resolved" rather than
  /// polling forever or flooding the server the way a flat, aggressive
  /// interval would at real scale.
  ///
  /// Deliberately does not call auth.syncAuthoritativeBalance() itself --
  /// only records what it learns into _pendingSyncBalance/_pendingSyncLedger-
  /// Version. Calling AuthProvider directly here would apply the balance the
  /// instant the server answers (often mid-spin, since the server usually
  /// finishes settling before the wheel even stops), bypassing
  /// onGlobalResult()'s staged reveal timing entirely.
  Future<SpinResult> _fetchConfirmedResult(
    String roundId,
    SpinResult pending,
  ) async {
    const delays = [
      Duration.zero,
      Duration(milliseconds: 200),
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 2),
    ];

    for (int attempt = 0; attempt < delays.length; attempt++) {
      if (delays[attempt] > Duration.zero) {
        await Future.delayed(delays[attempt]);
      }
      if (_spinAborted) return pending;

      try {
        final myResult = await RoundApiService().getMyRoundResult(roundId);
        if (myResult == null) continue;

        if (!myResult.placedBet) {
          // DB has no bet row for this round. Two possible causes:
          //   A) submit_round_bet failed (M-3 now surfaces this to the player)
          //   B) Timing race: bet row not yet visible (very rare)
          // In case A the DB balance is the ground truth -- no stake was ever
          // deducted server-side. Recorded, not applied here -- see the
          // _pendingSyncBalance doc comment for why.
          _pendingSyncBalance = myResult.coinBalance;
          _pendingSyncLedgerVersion = myResult.ledgerVersion;
          debugPrint('_fetchConfirmedResult: placed_bet=false on attempt ${attempt + 1}.');
          return pending; // nothing more to learn -- stop retrying
        }

        if (myResult.isSettled) {
          _pendingSyncBalance = myResult.coinBalance;
          _pendingSyncLedgerVersion = myResult.ledgerVersion;
          _balanceSyncFailed = false;
          return SpinResult(
            id:              pending.id,
            red:             pending.red,
            green:           pending.green,
            black:           pending.black,
            mode:            pending.mode,
            selections:      pending.selections,
            chipValue:       0,
            won:             myResult.totalPayout > 0,
            deductedAmount:  pending.deductedAmount,
            winAmount:       myResult.totalPayout,
            singleWinAmount: myResult.singlePayout,
            doubleWinAmount: myResult.doublePayout,
            tripleWinAmount: myResult.triplePayout,
            netChange:       myResult.totalPayout - pending.deductedAmount,
            createdAt:       pending.createdAt,
          );
        }
        // Bet exists but not settled yet -- large round still draining
        // batches (Issue #42). Keep retrying.
        debugPrint('_fetchConfirmedResult: bet not yet resolved, attempt ${attempt + 1}');
      } catch (e) {
        debugPrint('_fetchConfirmedResult: getMyRoundResult attempt ${attempt + 1} failed: $e');
      }
    }

    // Still not settled after the full retry budget -- genuinely still
    // catching up, most likely a very large round. Don't guess -- show as
    // unresolved-for-now rather than a fabricated number. The player's real
    // balance will catch up via the next round's own confirmation or the
    // periodic heartbeat.
    _balanceSyncFailed = true;
    notifyListeners();
    debugPrint('_fetchConfirmedResult: still not settled after full retry budget, preserving local state');
    return pending;
  }


  bool get submittedBets => _submittedBets;
  int get uncommittedStake => _submittedBets ? 0 : _board.total;
  void markBetsSubmitted() {
    _submittedBets = true;
    notifyListeners();
  }

  /// M-3 FIX: checks every staked cell against its board's minimum before the
  /// bets are sent. Chips stack, so a cell can only be validated once betting
  /// closes — catching it here gives a precise message and avoids a round trip
  /// that submit_round_bet would reject with P0007.
  ///
  /// Returns null when the board is valid.
  BetRejection? validateMinimums() {
    for (final type in BoardType.values) {
      final min = _playLimits.limitsFor(type).min;
      final map = _board.boardFor(type);
      for (final entry in map.entries) {
        if (entry.value < min) {
          return BetRejection(
            BetRejectReason.cellMinNotMet,
            board: type,
            cellKey: entry.key,
            cap: min,
          );
        }
      }
    }
    return null;
  }

  /// M-3 FIX: undoes a round's local bet when the server refused it.
  ///
  /// Chips are deducted from the on-screen balance the moment they are placed,
  /// but nothing reaches the database until submit_round_bet runs at the close
  /// of betting. If that call is rejected the stake was never actually taken —
  /// the RAISE rolls the deduction back — so the local balance must be restored
  /// or the player sees coins missing that they still have.
  void refundRejectedBets(AuthProvider auth) {
    if (_board.isEmpty) return;
    auth.updateBalance(auth.coinBalance + _board.total);
    _board.clearAll();
    _history.clear();
    _lastBetSnapshot = null;
    _rebetUsed = false;
    _submittedBets = false;
    _checkAndRestoreActiveChip();
    notifyListeners();
  }

  // ── Triple page ────────────────────────────────────────────────────
  /// Switching triple page no longer clears bets — they persist by key.
  void setTriplePage(int page, AuthProvider auth) {
    if (_triplePage == page) return;
    _triplePage = page;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
