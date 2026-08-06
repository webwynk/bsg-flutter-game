import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/spin_result_model.dart';
import '../providers/game_provider.dart';
import '../providers/auth_provider.dart';
import 'api_contract.dart';
import 'round_api_service.dart';

/// Manages synchronization between the Flutter app and the global game round.
///
/// Responsibilities:
/// - Fetches current round from server on game open
/// - Syncs the local countdown to the server's scheduled time
/// - Polls every 2 seconds to detect round completion
/// - When a round completes, calls [GameProvider.onGlobalResult] with the result
/// - Shows "No Connection" when offline
class RoundSyncService extends ChangeNotifier {
  static final RoundSyncService _instance = RoundSyncService._internal();
  factory RoundSyncService() => _instance;
  RoundSyncService._internal();

  final RoundApiService _api = RoundApiService();

  // ── State ─────────────────────────────────────────────────────────
  GlobalRoundState? _currentRound;
  String? _betRoundId;    // FIX BUG #6: Track the round ID bets were submitted to
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _connectionError;
  int _failedPollCount = 0;

  // M-3 FIX: retain why the last submission failed so the UI can explain it.
  // Previously submitBets() returned false and the caller discarded it, so a
  // server-rejected bet was completely invisible to the player.
  String? _lastSubmitError;
  String? get lastSubmitError => _lastSubmitError;

  GlobalRoundState? get currentRound     => _currentRound;
  String? get betRoundId                 => _betRoundId;
  bool get isConnected                   => _isConnected;
  bool get isConnecting                  => _isConnecting;
  String? get connectionError            => _connectionError;
  String? get currentRoundId             => _currentRound?.roundId;

  // ── Polling & Server Clock Offset ──────────────────────────────────
  int? _deliveredRoundNumber;      // single-delivery lock per round number
  int _serverTimeOffset = 0;       // dynamic clock offset between server and device

  int get serverTimeOffset => _serverTimeOffset;
  int get syncedNowSecs => (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + _serverTimeOffset;

  void _calibrateServerTimeOffset(GlobalRoundState round) {
    try {
      final localNowSecs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final serverNowSecs = (round.scheduledAt.millisecondsSinceEpoch ~/ 1000) - round.secondsRemaining;
      _serverTimeOffset = serverNowSecs - localNowSecs;
    } catch (_) {}
  }

  /// Called from GameScreen.initState — attaches to the game provider
  Future<void> attach(GameProvider game, AuthProvider auth) async {
    _isConnecting = true;
    _connectionError = null;
    notifyListeners();

    game.startCountdown();
    game.loadGlobalHistory();
    await _fetchInitialRound(game, auth);
    _startPolling(game, auth);
  }

  /// Called from GameScreen.dispose — cleans up.
  void detach() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _deliveredRoundNumber = null;
    _betRoundId = null;
  }

  // ── Continuous polling ─────────────────────────────────────────────
  Timer? _pollTimer;
  bool _pollInFlight = false;

  /// Polls the round every 2s for as long as the game screen is open.
  ///
  /// The class docs claimed this existed from the start; it did not. Without
  /// it the round was read exactly twice per cycle — once on attach, once in
  /// the draw window — which caused two distinct failures:
  ///
  ///   * `_currentRound` went stale for the whole betting phase, so bets were
  ///     submitted against the previous, already-finished round.
  ///   * the result was delivered only if `_onTimerExpire` fired on the exact
  ///     `cycle 14 -> 13` tick. Any missed tick and the wheel simply never
  ///     span for that round, with no way to recover until the next one.
  ///
  /// Polling makes delivery level-triggered rather than edge-triggered: the
  /// wheel spins whenever a result exists that this client has not shown yet,
  /// regardless of how the client got there.
  void _startPolling(GameProvider game, AuthProvider auth) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll(game, auth));
  }

  Future<void> _poll(GameProvider game, AuthProvider auth) async {
    if (_pollInFlight) return;   // never overlap requests on a slow network
    _pollInFlight = true;
    try {
      final round = await _api.getCurrentRound();

      if (round == null) {
        _failedPollCount++;
        // Require 2 consecutive failed polls before marking connection as dead,
        // so transient PC emulator NAT stutters do not trigger the banner.
        if (_failedPollCount >= 2) {
          final err = _api.lastRoundError ?? BetError.offline;
          if (_isConnected || _connectionError != err) {
            _isConnected = false;
            _connectionError = err;
            notifyListeners();
          }
        }
        return;
      }

      _failedPollCount = 0;
      _currentRound = round;
      _calibrateServerTimeOffset(round);
      if (!_isConnected || _connectionError != null) {
        _isConnected = true;
        _connectionError = null;
        _isConnecting = false;
        notifyListeners();
      }

      if (round.red != null && round.green != null && round.black != null &&
          _deliveredRoundNumber != round.roundNumber) {
        _deliveredRoundNumber = round.roundNumber;
        debugPrint('RoundSyncService: delivering round #${round.roundNumber} from poll');
        _deliverResult(round, game, auth);
      }
    } finally {
      _pollInFlight = false;
    }
  }

  /// Fetches the initial round state when joining the game screen.
  Future<void> _fetchInitialRound(GameProvider game, AuthProvider auth) async {
    final round = await _api.getCurrentRound();
    if (round == null) {
      _isConnected = false;
      _isConnecting = false;
      // Report the ACTUAL cause. This used to be hard-coded to NO_CONNECTION,
      // so a server-side failure was indistinguishable from a dead network —
      // which is how a broken draw_round presented to the player as
      // "NO INTERNET CONNECTION" on a device with working internet.
      _connectionError = _api.lastRoundError ?? BetError.offline;
      notifyListeners();
      return;
    }
    _currentRound = round;
    _calibrateServerTimeOffset(round);
    _isConnected = true;
    _isConnecting = false;
    _connectionError = null;
    notifyListeners();

    // If player opens game mid-spin, deliver result immediately.
    final nowSecs = syncedNowSecs;
    final cycle = 103 - (nowSecs % 103);
    if (cycle <= 13) {
      fetchAndDeliverResult(game, auth);
    }
  }

  /// Called at 00s remaining by GameProvider clock to deliver the result.
  /// Uses a robust 8-attempt polling loop to handle multi-device clock drift and network lag.
  Future<void> fetchAndDeliverResult(GameProvider game, AuthProvider auth) async {
    for (int attempt = 1; attempt <= 8; attempt++) {
      final round = await _api.getCurrentRound();
      if (round != null) {
        _currentRound = round;
        _calibrateServerTimeOffset(round);
        if (round.red != null && round.green != null && round.black != null) {
          if (_deliveredRoundNumber != round.roundNumber) {
            _deliveredRoundNumber = round.roundNumber;
            debugPrint('RoundSyncService: exactly-once delivery for round #${round.roundNumber} on attempt $attempt');
            _deliverResult(round, game, auth);
            return;
          } else {
            return; // Already delivered for this round
          }
        }
      }
      if (attempt < 8) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
  }

  /// Submits the player's bets to the server for the current active round.
  /// Returns true if bets were submitted and accepted by DB.
  ///
  /// v2: `totalStake` and `token` are gone. The server recomputes the stake
  /// from the bet maps — v1 accepted a client total and ignored it — and the
  /// authenticated Supabase client carries the identity.
  Future<bool> submitBets({
    required Map<String, int> singleBets,
    required Map<String, int> doubleBets,
    required Map<String, int> tripleBets,
    required AuthProvider auth,
    required GameProvider game,
  }) async {
    _lastSubmitError = null;
    if (singleBets.isEmpty && doubleBets.isEmpty && tripleBets.isEmpty) {
      return true;
    }

    // 1. Enterprise Idempotency Check:
    // If bets for the active target round were ALREADY accepted by the DB,
    // return true immediately without making any RPC network call.
    final currentTargetId = _currentRound?.roundId;
    if (game.betStatus == BetSubmissionStatus.submitted &&
        currentTargetId != null &&
        game.submittedRoundId == currentTargetId) {
      debugPrint('RoundSyncService.submitBets: idempotent no-op for already-submitted round $currentTargetId');
      return true;
    }

    if (game.betStatus == BetSubmissionStatus.submitting) {
      debugPrint('RoundSyncService.submitBets: submission already in flight');
      return true;
    }

    game.setBetStatus(BetSubmissionStatus.submitting);

    // Use the active _currentRound if valid (updated every 2s by background poll).
    // Only fetch fresh if absent or no longer accepting bets.
    var targetRound = _currentRound;
    if (targetRound == null || !targetRound.acceptsBets) {
      targetRound = await _api.getCurrentRound();
      if (targetRound == null) {
        debugPrint('RoundSyncService.submitBets: could not read the current round');
        _lastSubmitError = _api.lastRoundError ?? BetError.offline;
        game.setBetStatus(BetSubmissionStatus.failed);
        return false;
      }
      _currentRound = targetRound;
      _calibrateServerTimeOffset(targetRound);
    }

    final roundId = targetRound.roundId;

    // Double-check idempotency after fresh round fetch
    if (game.betStatus == BetSubmissionStatus.submitted && game.submittedRoundId == roundId) {
      return true;
    }

    // Save which round the bets were submitted to
    _betRoundId = roundId;

    final result = await _api.placeBet(
      roundId:    roundId,
      singleBets: singleBets,
      doubleBets: doubleBets,
      tripleBets: tripleBets,
    );

    if (result.success) {
      game.setBetStatus(BetSubmissionStatus.submitted, roundId: roundId);
      // Anchor to the version the deduction produced, so an in-flight heartbeat
      // carrying the pre-bet balance cannot undo it.
      auth.syncAuthoritativeBalance(result.coinBalance, result.ledgerVersion);
      return true;
    } else {
      game.setBetStatus(BetSubmissionStatus.failed);
      _lastSubmitError = result.error;
      debugPrint('RoundSyncService.submitBets failed: ${result.error}');
      return false;
    }
  }

  /// Delivers the global result to the GameProvider so it can animate & show outcome.
  void _deliverResult(GlobalRoundState round, GameProvider game, AuthProvider auth) {
    if (round.red == null || round.green == null || round.black == null) return;

    final targetRoundId = round.roundId;

    final spinResult = SpinResult(
      id:              targetRoundId,
      red:             round.red!,
      green:           round.green!,
      black:           round.black!,
      mode:            'global',
      selections:      [],
      chipValue:       0,
      won:             false,   // GameProvider.onGlobalResult calculates this
      deductedAmount:  0,       // already deducted server-side via submitBets
      winAmount:       0,
      singleWinAmount: 0,
      doubleWinAmount: 0,
      tripleWinAmount: 0,
      netChange:       0,
      createdAt:       round.scheduledAt,
    );

    game.onGlobalResult(spinResult, auth);
    game.loadGlobalHistory();
  }

  /// Manual retry when connection was lost.

  Future<void> retry(GameProvider game, AuthProvider auth) async {
    _isConnecting = true;
    _connectionError = null;
    notifyListeners();
    await _fetchInitialRound(game, auth);
  }
}
