import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/spin_result_model.dart';
import '../providers/game_provider.dart';
import '../providers/auth_provider.dart';
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
  }

  /// Called from GameScreen.dispose — cleans up.
  void detach() {
    _deliveredRoundNumber = null;
    _betRoundId = null;
  }

  /// Fetches the initial round state when joining the game screen.
  Future<void> _fetchInitialRound(GameProvider game, AuthProvider auth) async {
    final round = await _api.getCurrentRound();
    if (round == null) {
      _isConnected = false;
      _isConnecting = false;
      _connectionError = 'NO_CONNECTION';
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
  }) async {
    _lastSubmitError = null;
    if (singleBets.isEmpty && doubleBets.isEmpty && tripleBets.isEmpty) {
      return true;
    }

    // Ensure targetRound is available
    var targetRound = _currentRound;
    if (targetRound == null) {
      targetRound = await _api.getCurrentRound();
      if (targetRound != null) {
        _currentRound = targetRound;
      }
    }

    final roundId = targetRound?.roundId;
    if (roundId == null) {
      debugPrint('RoundSyncService.submitBets: no active round available');
      _lastSubmitError = 'OFFLINE';
      return false;
    }

    // FIX BUG #6: Save which round the bets were submitted to
    _betRoundId = roundId;

    final result = await _api.placeBet(
      roundId:    roundId,
      singleBets: singleBets,
      doubleBets: doubleBets,
      tripleBets: tripleBets,
    );

    if (result.success) {
      // Anchor to the version the deduction produced, so an in-flight heartbeat
      // carrying the pre-bet balance cannot undo it.
      auth.syncAuthoritativeBalance(result.coinBalance, result.ledgerVersion);
      return true;
    } else {
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
