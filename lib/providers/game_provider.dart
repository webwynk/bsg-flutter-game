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
  // Issue #113: bumped by abortSpin() when the user leaves mid-sequence. Each
  // onGlobalResult() captures the value when it starts and treats itself as
  // aborted the moment the counter differs. This replaced a shared
  // `_spinAborted` boolean, which a LATER sequence reset to false -- silently
  // reviving an earlier, already-aborted one that was still suspended on a
  // timer (it woke, saw "not aborted", and ran its end-of-round cleanup
  // concurrently with the live sequence). A counter can only move forward,
  // so nothing can un-abort anything.
  int _spinEpoch = 0;
  SpinResult? _lastResult;
  SpinResult? _lastWinBoxResult;
  SpinResult? _pendingResult;

  // Issue #107: the shortest the win popup may ever be visible for. Acts as a
  // floor under the absolute W+4.300 hide target, so that a late reveal can
  // never squeeze the popup to nothing. Sized to cover the popup's own 400ms
  // scale/fade entrance plus enough fully-rendered time to read the amount.
  static const Duration _minPopupVisible = Duration(milliseconds: 1200);

  // Issue #109: when the win popup opens, in ms after the wheel lands. One
  // constant shared by the popup's own deadline and by the coin fountain's
  // "is there room?" check below, so the two cannot drift apart.
  static const int _popupOpensAtMs = 1800;

  // Issue #109: the least time that must remain before the popup opens for the
  // coin fountain (and its sound) to be worth starting. On a late reveal the
  // popup is already due, and the flag would flip on and straight back off
  // before a single frame was drawn -- invisible coins, but with the coin
  // sound already started and then replaced by the win sound. Below ~0.5s
  // the fountain could not be seen anyway, so it is skipped entirely.
  static const Duration _minCoinFxSlot = Duration(milliseconds: 500);

  // Issue #106: minimum server-confirmed win, in coins, that earns the coin
  // fountain. Deliberately a compile-time constant rather than live server
  // config: unlike play_limits or the payout multipliers, this gates a purely
  // visual effect with no financial consequence, so it does not warrant the
  // extra RPC surface (and cannot repeat Issue #71's drift problem, which was
  // only serious because that threshold gated money).
  static const int _bigWinFxThreshold = 900;

  // Issue #106: drives the big-win coin fountain overlay. True only between
  // the balance reveal (wheel-stop + 0.300s) and the win popup opening
  // (wheel-stop + 1.800s), and only for wins of 900+ coins -- the 1.5s slot
  // Issue #105 opened. Issue #109: and only when at least _minCoinFxSlot of
  // that slot is still left at the reveal -- a late reveal skips it entirely
  // rather than flipping it on and off inside a single frame.
  // game_screen.dart mounts the CoinFountain while this is
  // true and unmounts it when it goes false, so flipping it back to false is
  // what stops the animation; there is no separate teardown call.
  bool _showCoinFx = false;

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
  SpinResult? get lastResult => _lastResult;
  SpinResult? get lastWinBoxResult => _lastWinBoxResult;
  bool get showCoinFx                => _showCoinFx;
  SpinResult? get pendingResult => _pendingResult;
  int get countdown          => _countdown;

  /// True when REBET button should be shown instead of DOUBLE.
  /// Deliberately does NOT check balance -- that's canAffordRebet() below,
  /// checked separately so an unaffordable rebet still shows the REBET
  /// label, disabled, rather than silently falling through to DOUBLE
  /// (which would be visually correct-looking but the wrong label, since
  /// the board is empty here and there's nothing to double).
  bool get canRebet =>
      _lastBetSnapshot != null &&
      !_lastBetSnapshot!.isEmpty &&
      !_rebetUsed &&
      !_isSpinning &&
      _board.isEmpty;

  /// True when the player currently has enough coins to actually repeat
  /// their last bet. Only meaningful once canRebet is already true -- this
  /// only ever gates whether the REBET button is enabled, never which
  /// button is shown. Reads auth.coinBalance live, so this automatically
  /// re-evaluates (and the button re-enables) the moment the balance
  /// changes -- e.g. an agent crediting coins arrives via the existing
  /// heartbeat sync, which already notifies listeners on every update.
  bool canAffordRebet(AuthProvider auth) =>
      _lastBetSnapshot != null && auth.coinBalance >= _lastBetSnapshot!.total;
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

  /// Issue #111: whether a countdown tick is the one on which the "NO MORE
  /// PLAY" mark (5s) was reached or passed -- the moment the player's board
  /// must be sent to the server.
  ///
  /// This used to be an exact-equality test (`_countdown == 5`), but the
  /// countdown is re-derived from the synced wall clock on every tick rather
  /// than counted down, so two ticks more than one second apart skip a value.
  /// A stalled tick (Timer.periodic does not queue missed ticks) or a +/-1s
  /// clock re-sync from RoundSyncService._poll() both do that. If the skipped
  /// value was 5 the submission never ran, the chips sat locked and unsent,
  /// and the only remaining attempt -- at countdown 00 -- was always rejected
  /// (the server stops taking bets at second 88): the player lost the round
  /// and was told they were too slow, when the server would still have
  /// accepted the bet at countdown 4 and 3.
  ///
  /// True once per approach from above: the previous tick must have been
  /// ABOVE 5 and this one at or below it, so 6->5 (normal), 7->4 and 6->3 all
  /// fire, while 5->4 never does -- nor does a clock re-sync moving 4->5,
  /// which the old equality form wrongly counted a second time. A re-sync
  /// that pushes the countdown back ABOVE 5 and then down again is a fresh
  /// approach and fires again (as the old form also did); that is harmless,
  /// because submitBets() ignores a repeat for a round already submitted.
  ///
  /// `currentCountdown > 0`: a tick that jumps clean through the draw second
  /// leaves nothing to submit to, so it is left to the result path, which
  /// already reconciles unsent chips silently (placed_bet = false).
  ///
  /// There is deliberately no lower floor at 3 to dodge the closed seconds
  /// (2 and 1): that would hard-code the server's bet_cutoff_second into the
  /// client, which Issue #71's closed decision rules out. A late attempt just
  /// gets the same rejection-and-refund the countdown-00 fallback produces.
  @visibleForTesting
  static bool crossedNoMoreBetsMark({
    required int previousCountdown,
    required int currentCountdown,
  }) =>
      currentCountdown <= 5 && currentCountdown > 0 && previousCountdown > 5;

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

        // Issue #111: "reached or passed 5", not "landed exactly on 5" -- see
        // crossedNoMoreBetsMark(). Fires once, on the first tick at or below 5.
        if (crossedNoMoreBetsMark(
          previousCountdown: _cycleToCountdown(previous),
          currentCountdown: _countdown,
        )) {
          SoundService().playNoBets();
          _lastWinBoxResult = null;
          if (_isDrawerOpen) closeDrawer();
          _onNoBets?.call(); // Triggers early bet submission at NO MORE PLAY (countdown 5, or the first tick after it)
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
    _spinEpoch++; // Issue #113: invalidates every onGlobalResult() already running
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

    // Issue #106: same reasoning for the coin fountain. Leaving the game
    // screen mid-animation unmounts the overlay anyway, but this flag must
    // not still be true when the player comes back, or the fountain would be
    // remounted (and restarted, since it autoPlays) for a round that is over.
    _showCoinFx = false;

    // Issue #108: and the same again for the win popup itself. This provider
    // is app-wide, so it outlives GameScreen and remembers _lastResult after
    // the screen is gone. onGlobalResult() -- suspended mid-popup -- will
    // resume, find its epoch stale and return before reaching either line that
    // would have cleared it, so nothing else ever does. Left set, the player
    // returns to the OLD win popup: it has no dismiss control and its backdrop
    // blocks every tap, until the next round's result arrives (up to ~90s).
    // A plain field write, like the resets above: abortSpin() already calls
    // stopCountdown(), which notifies, and no screen shows the popup once
    // it has been left.
    _lastResult = null;

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
    // Guards a repeat call only while the wheel is still turning
    // (_pendingResult is cleared at wheel-stop, while _isSpinning stays true
    // for the rest of the sequence). That narrow scope is deliberate and
    // enough, per Issue #113: a repeat later in the sequence is blocked by
    // RoundSyncService's per-round delivery lock, and a repeat after the
    // player left and came back is handled by the epoch below -- which is what
    // keeps the OLD sequence from resuming. Tightening this to `_isSpinning`
    // alone was considered and rejected: abortSpin() clears that flag, so it
    // would not stop the reachable case, and it would turn an uncaught
    // exception mid-sequence into a permanent freeze of every later result.
    if (_isSpinning && _pendingResult != null) return;

    _isSpinning = true;
    // Issue #113: this sequence's identity. It is stale the instant
    // abortSpin() moves the counter, and nothing can ever move it back.
    final epoch = _spinEpoch;
    bool stale() => epoch != _spinEpoch;
    _lastResult = null;
    _pendingResult = null;
    _showCoinFx = false; // Issue #106: defensive -- a stale fountain from a
                         // previous round must never leak into this one.
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
      bonusMultiplier: serverResult.bonusMultiplier,
    );

    // Trigger wheel animation. The completer is created and assigned before
    // notifyListeners() so it's guaranteed to exist by the time the wheel
    // widget reacts and starts animating -- no window where the wheel could
    // finish and call notifyWheelRevealComplete() before anything is
    // listening for it.
    final revealCompleter = Completer<void>();
    _wheelRevealCompleter = revealCompleter;
    _pendingResult = pendingSpin;
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
    if (stale()) return;
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
        _fetchConfirmedResult(cleanRoundId, pendingSpin, epoch),
        Future.delayed(const Duration(milliseconds: 300)),
      ]);
      resolvedResult = results[0] as SpinResult;
    }
    if (stale()) return;

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

    // Issue #106: the big-win coin fountain starts on this exact beat -- the
    // same notifyListeners() that makes the balance jump and the "WIN: X"
    // badge appear -- so the coins erupt as the number changes, not after it.
    // Gated on the server-confirmed amount, so a spectator (winAmount 0) and
    // any sub-threshold win never trigger it. Cleared again at the popup
    // below, giving the fountain at most the 1.5s slot and no more.
    //
    // Issue #109: and only started if there is actually room left. A normal
    // reveal (W+0.300) has 1.5s before the popup; a late one -- the server was
    // slow confirming a large round -- may have none, in which case the flag
    // would flip on and straight back off inside one frame. Nothing would be
    // drawn, yet playCoin() would already have started the coin sound for
    // playWin() to replace microtasks later. Skipping both is honest: no
    // pretending to show an effect that cannot be seen.
    final untilPopup = Duration(milliseconds: _popupOpensAtMs) -
        DateTime.now().difference(wheelStoppedAt);
    if (resolvedResult.winAmount >= _bigWinFxThreshold &&
        untilPopup >= _minCoinFxSlot) {
      _showCoinFx = true;
      SoundService().playCoin();
    }
    notifyListeners();

    // ── Post-wheel display sequence (Issue #105) ──────────────────────
    //
    // Every deadline below is an ABSOLUTE offset from wheelStoppedAt, never a
    // chain of relative delays. That distinction is the whole fix:
    //
    //  * Defect B (win/lose length mismatch): the win branch used to be
    //    anchored while the lose branch waited a flat 5000ms from wherever the
    //    reveal happened to land -- W+0.300 for a bettor, W+0.000 for a
    //    spectator, who skips the 300ms floor because it lives inside the
    //    `totalDeducted > 0` block above. That produced three different
    //    sequence lengths (13.0 / 12.3 / 12.0s) where the comments claimed
    //    one. No single flat value can fix it: the two lose paths start
    //    300ms apart, so they would still finish 300ms apart. Anchoring is
    //    the only arithmetic that makes all four coincide.
    //
    //  * Defect A (round-boundary overrun): the old sequence was 13.0s inside
    //    a 13.0s window (`103 - 90`), i.e. zero slack -- but it can never
    //    start at `into 90.000`. This client only learns the result by asking
    //    the server, so the wheel starts at 90 + d, where d is at least one
    //    network round-trip (and more if the round has not been drawn yet:
    //    the draw is performed by whichever happens first at/after second 90
    //    -- any player's get_current_round() poll, the dashboard's 5s poll, or
    //    the 10s tick_rounds cron -- so the digits may already exist when this
    //    client asks, but never before second 90 plus its own round-trip). The
    //    old sequence therefore always ended past the boundary, blocking bet
    //    placement into the next round. Ending at W+5.000 instead of W+6.000
    //    makes the sequence 12.0s, leaving 1.0s of slack for d.
    //
    // Timeline, all four outcome paths:
    //   W+0.300  reveal (above)          -- spectator: W+0.000, no stake
    //   W+1.800  popup opens             -- win only
    //   W+4.300  popup hides             -- win only (2.5s on screen)
    //   W+5.000  sequence ends           -- ALL paths, 12.0s total
    //
    // The W+0.300 -> W+1.800 gap is a deliberate 1.5s slot. Issue #106 fills
    // it with the big-win coin fountain; until then it is a quiet pause.

    /// Waits until exactly [msAfterWheelStop] past the wheel's landing, then
    /// reports whether THIS sequence is still live. Returns false if the
    /// player left mid-sequence (this sequence's epoch went stale) -- callers
    /// return immediately on false, exactly as they do after every other
    /// await in this method. Clamped at zero, so a slow server response can
    /// never produce a negative wait.
    Future<bool> holdUntil(int msAfterWheelStop) async {
      final remaining = Duration(milliseconds: msAfterWheelStop) -
          DateTime.now().difference(wheelStoppedAt);
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
      return !stale();
    }

    if (resolvedResult.won) {
      // Popup opens at W+1.800 and plays its win sound. Issue #106: the coin
      // fountain is cleared in this same notifyListeners(), so the two can
      // never be on screen together. The cut is invisible because the popup's
      // backdrop -- a BackdropFilter blur plus an 80% black scrim -- is NOT
      // animated (only the card inside it is), so it covers the screen at
      // full strength on this very frame. playWin() also stops coin.mp3 here,
      // since both share _player.
      if (!await holdUntil(_popupOpensAtMs)) return;
      _lastResult = resolvedResult;
      _showCoinFx = false;
      SoundService().playWin();
      notifyListeners();
      final popupOpenedAt = DateTime.now();

      // Popup hides at W+4.300 -- 2.5s on screen in the normal case.
      if (!await holdUntil(4300)) return;

      // Issue #107: ...but never before it has actually been visible for
      // _minPopupVisible. Both targets above are absolute offsets from the
      // wheel landing, which is what keeps every outcome path ending together
      // (Issue #105) -- but it means a LATE reveal is absorbed by the popup's
      // own screen time rather than by the sequence running long. The reveal
      // waits on _fetchConfirmedResult, which retries at 0/200ms/500ms/1s/2s/2s,
      // so on a large round still draining batches (Issue #42) it can arrive
      // at W+3.700 or W+5.700. Without this floor, W+3.700 left the popup up
      // for 0.6s, and W+5.700 pushed BOTH targets past due -- _lastResult was
      // set and cleared inside one frame and the winning player never saw the
      // popup at all, with no error anywhere to explain it (the connection is
      // healthy in this scenario, so no connection dialog fires either).
      //
      // Costs nothing on a normal round, and nothing on a moderately slow one
      // either -- a W+3.700 reveal is absorbed by the 0.7s tail and still ends
      // at W+5.000. Only a genuinely late reveal runs past the endpoint, and
      // then by a bounded ~0.9s rather than the ~4.7s the pre-Issue-#105 code
      // would have overrun by in the same situation.
      final shownFor = DateTime.now().difference(popupOpenedAt);
      final shortfall = _minPopupVisible - shownFor;
      if (shortfall > Duration.zero) {
        await Future.delayed(shortfall);
        if (stale()) return;
      }

      _lastResult = null;
      notifyListeners();
    }

    // Shared endpoint. A win arrives here at W+4.300 and waits out the 0.7s
    // tail; a loss or spectator arrives right after the reveal and waits out
    // the whole display window. Either way the sequence ends at W+5.000.
    if (!await holdUntil(5000)) return;

    // Cleanup and auto-resume UTC timer for next round cleanly at 90s
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
  ///
  /// Issue #113: [epoch] is the calling onGlobalResult()'s identity. Every
  /// abort check here compares against it rather than a shared flag, so a
  /// fetch belonging to an aborted sequence stops -- and, crucially, never
  /// writes its late reply (balance fields, the "not settled" banner) into a
  /// newer sequence that started in the meantime.
  Future<SpinResult> _fetchConfirmedResult(
    String roundId,
    SpinResult pending,
    int epoch,
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
      if (epoch != _spinEpoch) return pending;

      try {
        final myResult = await RoundApiService().getMyRoundResult(roundId);
        // Issue #113: the request can outlive the sequence that made it.
        if (epoch != _spinEpoch) return pending;
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
            bonusMultiplier: pending.bonusMultiplier,
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
    if (epoch != _spinEpoch) return pending; // Issue #113: not a stale sequence's banner to raise
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

  /// Issue #110: clears a board whose bet is ALREADY on the server for a round
  /// that ended without ever delivering a result (the round's draw failed --
  /// see Issue #14). Called from game_screen.dart's failed-delivery branch,
  /// and from the stale-board guard in _handleEarlyBetSubmission().
  ///
  /// The normal end-of-round cleanup lives only at the tail of
  /// onGlobalResult(), which never runs for a round that never resolved. Left
  /// alone, the chips stayed on the board with _betStatus == submitted and
  /// _submittedRoundId pointing at the dead round; at the next round's "5
  /// seconds" mark the auto-submit saw a non-empty board, and submitBets()'s
  /// idempotency check -- which compares round ids -- let it through as a
  /// "new" bet. The player was charged a second time for a bet they never
  /// placed this round, and again every round after that until one resolved.
  ///
  /// Deliberately does NOT refund: unlike refundRejectedBets(), the stake here
  /// was genuinely taken -- the server will settle that round on its own.
  ///
  /// Deliberately does NOT touch _lastBetSnapshot. That is REBET's source and
  /// is only ever written at the end of a round that COMPLETED, so it belongs
  /// to the previous completed round, not this one (abortSpin() documents the
  /// same rule). _rebetUsed IS reset, exactly as the normal cleanup does, so
  /// the REBET/DOUBLE button is in the same state it is after any other
  /// round end -- empty board, REBET offered if a saved bet exists.
  ///
  /// Does nothing mid-spin: while onGlobalResult() is running it owns the
  /// board and the REBET snapshot, and clearing under it would lose both.
  void discardUnresolvedBoard() {
    if (_isSpinning) return;
    _board.clearAll();
    _history.clear();
    _rebetUsed = false;
    _submittedBets = false;
    _betStatus = BetSubmissionStatus.idle;
    _submittedRoundId = null;
    _checkAndRestoreActiveChip();
    notifyListeners();
  }

  /// Issue #110: true when the board's bet was submitted for a DIFFERENT round
  /// than [currentRoundId] -- i.e. its chips are left over from a round that
  /// has ended. Used as a second, independent lock at the one place money
  /// actually moves (the auto-submit at countdown 05), so a submitted board
  /// that somehow outlives its round can never be re-bet, whatever left it
  /// behind.
  ///
  /// Conservative by construction: every unknown (no submitted round recorded,
  /// or the current round not yet known) means "not stale", so this can only
  /// ever stop a bet that is provably for the wrong round, never a legitimate
  /// one. A board the player has touched since is also correctly "not stale":
  /// placing any chip resets _betStatus to idle and clears _submittedRoundId.
  bool isBoardFromOlderRound(String? currentRoundId) =>
      _betStatus == BetSubmissionStatus.submitted &&
      _submittedRoundId != null &&
      currentRoundId != null &&
      _submittedRoundId != currentRoundId;

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
