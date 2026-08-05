import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/spin_result_model.dart';
import '../models/bet_model.dart';
import '../models/play_limits_config.dart';
import '../services/api_service.dart';
import '../services/round_api_service.dart';
import '../services/sound_service.dart';
import '../services/round_sync_service.dart';
import 'auth_provider.dart';


class GameProvider extends ChangeNotifier {
  GameProvider() {
    // Bug #8 fix: initialise with safe fallback limits immediately so caps are
    // enforced from the very first frame — before the server responds.
    _playLimits = PlayLimitsConfig.fallback();
    _loadDrawnNumbersHistory();
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

  BetRejection _lastRejection = BetRejection.ok;
  BetRejection get lastRejection => _lastRejection;

  void clearRejection() {
    _lastRejection = BetRejection.ok;
  }

  Future<void> _loadPlayLimits() async {
    // Override fallback with real server limits (may raise or lower caps).
    final limitsJson = await ApiService().fetchPlayLimits();
    _playLimits = PlayLimitsConfig.fromJson(limitsJson);
    notifyListeners();
  }

  Future<void> _loadDrawnNumbersHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getString('bsg_drawn_numbers_history');
      if (listJson != null && listJson.isNotEmpty) {
        final list = jsonDecode(listJson) as List;
        _spinHistory.clear();
        _spinHistory.addAll(list.map((e) => SpinResult.fromJson(e as Map<String, dynamic>)));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveDrawnNumbersHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = jsonEncode(_spinHistory.map((e) => e.toJson()).toList());
      await prefs.setString('bsg_drawn_numbers_history', listJson);
    } catch (_) {}
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
  bool _isWaitingForResult = false;
  bool _spinAborted = false; // set true when user exits mid-spin
  SpinResult? _lastResult;
  SpinResult? _lastWinBoxResult;
  SpinResult? _pendingResult;

  String? _error;

  // ── Countdown ─────────────────────────────────────────────────────
  int _countdown = 90;
  Timer? _countdownTimer;
  VoidCallback? _onTimerExpire;

  // ── History ───────────────────────────────────────────────────────
  final List<int> _blackHistory = [];    // last 30 BLACK ring results
  final List<SpinResult> _spinHistory = [];
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
  List<int> get blackHistory => List.unmodifiable(_blackHistory);

  /// True when REBET button should be shown instead of DOUBLE.
  bool get canRebet =>
      _lastBetSnapshot != null &&
      !_lastBetSnapshot!.isEmpty &&
      !_rebetUsed &&
      !_isSpinning &&
      _board.isEmpty;
  List<SpinResult> get spinHistory => List.unmodifiable(_spinHistory);
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
  void setAutoSpinCallback(VoidCallback? callback) {
    _onTimerExpire = callback;
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
    if (auth.balance < amount) {
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
    map[cellKey] = currentAmount + amount;
    _history.add(BetAction(board: boardType, cellKey: cellKey, amount: amount));
    auth.updateBalance(auth.balance - amount);

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
      if (auth.balance < amount) {
        hasInsufficientFunds = true;
        break;
      }
      map[key] = (map[key] ?? 0) + amount;
      _history.add(BetAction(board: boardType, cellKey: key, amount: amount));
      auth.updateBalance(auth.balance - amount);
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
    auth.updateBalance(auth.balance + totalRefund);

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
      if (auth.balance < betAmount) {
        hasInsufficientFunds = true;
        break;
      }
      map[key] = betAmount;
      _history.add(BetAction(board: boardType, cellKey: key, amount: betAmount));
      auth.updateBalance(auth.balance - betAmount);
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
    if (auth.balance < extraCost) {
      _error = 'INSUFFICIENT_COINS';
      notifyListeners();
      return;
    }

    _lastRejection = BetRejection.ok;
    auth.updateBalance(auth.balance - extraCost);
    _lastWinBoxResult = null; // reset WIN display when user doubles

    // Double only cells within their cap
    for (final type in BoardType.values) {
      final cap = _playLimits.limitsFor(type).max;
      final map = _board.boardFor(type);
      map.updateAll((key, value) {
        if (value * 2 > cap) return value; // skip — already at cap
        return value * 2;
      });
    }

    // If some cells were skipped, show the warning
    if (anySkipped) {
      _lastRejection = BetRejection(BetRejectReason.cellMaxExceeded, board: skippedBoard, cap: skippedCap ?? 0);
    }

    // Double all entry amounts in history to keep it synced with the board, respecting cap limits
    for (int i = 0; i < _history.length; i++) {
      final action = _history[i];
      final cap = _playLimits.limitsFor(action.board).max;
      final boardMap = _board.boardFor(action.board);
      final currentVal = boardMap[action.cellKey] ?? 0;

      if (currentVal <= cap) {
        _history[i] = BetAction(
          board: action.board,
          cellKey: action.cellKey,
          amount: action.amount * 2,
        );
      }
    }
    _updateTimerState(auth);
    notifyListeners();
  }

  // ── CLEAR button ───────────────────────────────────────────────
  void clearBets(AuthProvider auth) {
    if (_isSpinning || _countdown <= 5) return;
    // Refund the full board total back to balance
    auth.updateBalance(auth.balance + _board.total);
    _board.clearAll();
    _history.clear();
    _rebetUsed = false; // allow REBET to reappear after clearing
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
    auth.updateBalance(auth.balance + last.amount);
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
    auth.updateBalance(auth.balance + action.amount);
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
      auth.updateBalance(auth.balance + action.amount);
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
    if (auth.balance < total) {
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

    auth.updateBalance(auth.balance - total);
    _rebetUsed = true; // switches button back to DOUBLE
    _lastWinBoxResult = null; // reset WIN display on rebet
    SoundService().playChipClick();
    _updateTimerState(auth);
    notifyListeners();
  }

  Future<void> loadGlobalHistory() async {
    try {
      final rounds = await RoundApiService().getRecentRounds(limit: 10);
      if (rounds.isNotEmpty) {
        _globalHistory.clear();
        for (final r in rounds) {
          if (r['red'] != null && r['green'] != null && r['black'] != null) {
            _globalHistory.add(SpinResult(
              id: r['id']?.toString() ?? 'round_${r['round_number']}',
              red: (r['red'] as num).toInt(),
              green: (r['green'] as num).toInt(),
              black: (r['black'] as num).toInt(),
              mode: 'global',
              selections: [],
              chipValue: 0,
              won: false,
              deductedAmount: 0,
              winAmount: 0,
              singleWinAmount: 0,
              doubleWinAmount: 0,
              tripleWinAmount: 0,
              netChange: 0,
              createdAt: r['scheduled_at'] != null
                  ? DateTime.tryParse(r['scheduled_at'].toString()) ?? DateTime.now()
                  : DateTime.now(),
            ));
          }
        }
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
    if (cycle >= 14) return cycle - 13;
    return 0;
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

        if (_countdown == 5 && previous >= 14 && _onTimerExpire != null) {
          SoundService().playNoBets();
          _lastWinBoxResult = null;
          if (_isDrawerOpen) closeDrawer();
        }

        // Did we cross the betting boundary? (previous 14 -> current 13)
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
    _countdown = 60;
    notifyListeners();
  }

  /// Called when user exits the game screen.
  /// Aborts any pending spin, cancels timers, and clears callbacks.
  void abortSpin() {
    _spinAborted = true;
    _isSpinning = false;
    _onTimerExpire = null;
    stopCountdown();
    SoundService().stopAll();
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
    // FIX #1: Lock heartbeat balance update as the ABSOLUTE FIRST operation.
    // This prevents the 15s background timer from overwriting auth.balance
    // between spin start and win display — the root cause of the 42-coin rollback.
    auth.holdHeartbeatBalance();

    if (_isSpinning && _pendingResult != null) return; // guard against double-call during active spin

    _isSpinning = true;
    _spinAborted = false;
    _lastResult = null;
    _pendingResult = null;
    _balanceSyncFailed = false; // FIX #3A: Clear any stale banner from previous round BEFORE spin starts
    _stopCountdownTimer();
    notifyListeners();

    // FIX #2: Snapshot the authoritative post-bet balance ONCE at spin start.
    // Never use live auth.balance for win math — it may be polluted by a stale heartbeat.
    final balanceAtSpinStart = auth.balance;

    // Snapshot existing bets BEFORE clearing them
    final singleSnap = Map<String, int>.from(_board.single);
    final doubleSnap  = Map<String, int>.from(_board.double_);
    final tripleSnap  = Map<String, int>.from(_board.triple);

    // Calculate wins from local bets vs global result with robust multi-key lookup (padded & unpadded)
    final singleKey = '${serverResult.black}';
    final greenStr = '${serverResult.green}';
    final blackStr = '${serverResult.black}';
    final doubleKeyPadded = '$greenStr$blackStr'.padLeft(2, '0');
    final doubleKeyUnpadded = (serverResult.green * 10 + serverResult.black).toString();

    final redStr = '${serverResult.red}';
    final tripleKeyPadded = '$redStr$greenStr$blackStr'.padLeft(3, '0');
    final tripleKeyUnpadded = (serverResult.red * 100 + serverResult.green * 10 + serverResult.black).toString();

    final singleBetAmt = singleSnap[singleKey] ?? singleSnap[int.tryParse(singleKey)?.toString() ?? ''] ?? 0;
    final doubleBetAmt = doubleSnap[doubleKeyPadded] ?? doubleSnap[doubleKeyUnpadded] ?? 0;
    final tripleBetAmt = tripleSnap[tripleKeyPadded] ?? tripleSnap[tripleKeyUnpadded] ?? 0;

    final singleWin = singleBetAmt * 9;
    final doubleWin = doubleBetAmt * 90;
    final tripleWin = tripleBetAmt * 900;
    final totalWin  = singleWin + doubleWin + tripleWin;
    final totalDeducted = _board.total; // already deducted server-side via submitBets

    final resolvedResult = SpinResult(
      id:              serverResult.id,
      red:             serverResult.red,
      green:           serverResult.green,
      black:           serverResult.black,
      mode:            _mode,
      selections:      [...singleSnap.keys, ...doubleSnap.keys, ...tripleSnap.keys],
      chipValue:       0,
      won:             totalWin > 0,
      deductedAmount:  totalDeducted,
      winAmount:       totalWin,
      singleWinAmount: singleWin,
      doubleWinAmount: doubleWin,
      tripleWinAmount: tripleWin,
      netChange:       totalWin - totalDeducted,
      createdAt:       serverResult.createdAt,
    );

    // Trigger wheel animation
    _pendingResult = resolvedResult;
    _isWaitingForResult = false;
    notifyListeners();

    // Wait for wheel to finish animating (8s)
    await Future.delayed(const Duration(milliseconds: 8000));
    if (_spinAborted) return;

    // ⚡ INSTANT UPDATE: Push win result to top history grid immediately at second 8 (0s delay)
    _globalHistory.insert(0, resolvedResult);
    if (_globalHistory.length > 10) _globalHistory.removeLast();

    if (totalDeducted > 0) {
      _blackHistory.add(serverResult.black);
      if (_blackHistory.length > 30) _blackHistory.removeAt(0);
      _spinHistory.insert(0, resolvedResult);
      if (_spinHistory.length > 50) _spinHistory.removeLast();
      _saveDrawnNumbersHistory();
    }

    // Reveal result immediately to UI & play win audio
    _lastResult = resolvedResult;
    _lastWinBoxResult = resolvedResult;
    _pendingResult = null;
    if (resolvedResult.won) {
      // FIX #2: Apply win to the SNAPSHOT balance captured at spin start.
      // Using balanceAtSpinStart (post-bet deduction) guarantees correctness:
      //   42 (start) - 20 (bet) = 22 (balanceAtSpinStart) + 18 (win) = 40 ✅
      // NOT auth.balance which may have been polluted by a stale heartbeat to 42.
      auth.updateBalance(balanceAtSpinStart + resolvedResult.winAmount);
      SoundService().playWin();
    }
    notifyListeners();

    // FIX #3B: Only sync balance from DB when player actually placed bets this round.
    // If totalDeducted = 0 (watching, no bet), there is no bet row in triple_chance_bets,
    // so get_my_round_result returns placed_bet=false → retries 4× → ALWAYS shows banner.
    if (totalDeducted > 0) {
      final cleanRoundId = serverResult.id.replaceFirst('round_', '');
      unawaited(_syncBalanceInBackground(cleanRoundId, auth));
    }

    // Wait 5s result display window (exact 13s total sequence: 8s spin + 5s display)
    if (resolvedResult.won) {
      // 1. Show Win Popup for 2.5 seconds (2,500ms)
      await Future.delayed(const Duration(milliseconds: 2500));
      if (_spinAborted) return;

      // 2. Hide Win Popup after 2.5 seconds
      _lastResult = null;
      notifyListeners();

      // 3. Wait remaining 2.5 seconds (2,500ms) to complete exact 5.0-second display window
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

    if (!_board.isEmpty) {
      _lastBetSnapshot = BetBoardState()
        ..single.addAll(_board.single)
        ..double_.addAll(_board.double_)
        ..triple.addAll(_board.triple);
    }
    _rebetUsed = false;
    _submittedBets = false;
    _board.clearAll();
    _history.clear();
    _checkAndRestoreActiveChip();
    _isSpinning = false;
    auth.releaseHeartbeatBalance();
    resetCountdown(auth);
  }

  Future<void> _syncBalanceInBackground(String roundId, AuthProvider auth) async {
    bool synced = false;
    for (int attempt = 1; attempt <= 4 && !synced; attempt++) {
      try {
        final myResult = await RoundApiService().getMyRoundResult(
          roundId: roundId,
          token: auth.token,
        );
        if (myResult != null) {
          if (!myResult.placedBet && myResult.balance > 0) {
            // FIX #3C: DB returned no bet row for this round (placed_bet=false).
            // This happens when the bet was placed but DB timing hasn't created the row yet,
            // OR if this path is hit despite the totalDeducted>0 guard (safety net).
            // The balance field is still authoritative — apply it and mark synced.
            auth.updateBalance(myResult.balance);
            _balanceSyncFailed = false;
            synced = true;
            notifyListeners();
          } else if (myResult.isResolved && myResult.balance > 0) {
            // FIX #3D: Bet fully resolved server-side — DB balance is the authoritative final value.
            // Apply unconditionally (no >= guard that could reject correct DB value).
            auth.updateBalance(myResult.balance);
            _balanceSyncFailed = false;
            synced = true;
            notifyListeners();
          } else if (myResult.placedBet && !myResult.isResolved) {
            // Bet exists on server but resolve_round_payouts hasn't run yet — retry
            debugPrint('onGlobalResult: bet not yet resolved on server, attempt $attempt');
          }
        }
      } catch (e) {
        debugPrint('onGlobalResult: getMyRoundResult attempt $attempt failed: $e');
      }
      if (!synced && attempt < 4) {
        await Future.delayed(const Duration(seconds: 2));
        if (_spinAborted) return;
      }
    }

    if (!synced) {
      _balanceSyncFailed = true;
      notifyListeners();
      debugPrint('onGlobalResult: balance sync failed after 4 attempts, preserving local balance');
    }
  }

  void clearSpinHistory() {
    _spinHistory.clear();
    _blackHistory.clear();
    notifyListeners();
  }


  bool get submittedBets => _submittedBets;
  int get uncommittedStake => _submittedBets ? 0 : _board.total;
  void markBetsSubmitted() {
    _submittedBets = true;
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
