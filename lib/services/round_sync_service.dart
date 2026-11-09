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
/// - Asks for the round on a smart schedule (2026-11-09, load reduction; see
///   [_pollIfDue]): once at the start of each round, every 10 seconds while
///   betting, every 2 seconds from the draw second until the result is in hand
///   (the same rhythm as before, so the wheel starts at the same moment), every
///   2 seconds while the connection is failing, and at once when the device's
///   clock moved or the phone slept. About 12 requests per 103-second round
///   instead of about 52. Intervals are timed on a monotonic stopwatch.
/// - When a round completes, calls [GameProvider.onGlobalResult] with the result
/// - Shows "No Connection" when offline
class RoundSyncService extends ChangeNotifier {
  static final RoundSyncService _instance = RoundSyncService._internal();
  factory RoundSyncService() => _instance;
  RoundSyncService._internal();

  // The server and the clock. Always the real ones in the app; only tests swap
  // them, through [configureForTest] (2026-11-09).
  TcRoundApi _api = RoundApiService();
  DateTime Function() _now = DateTime.now;

  /// Monotonic time since the app started: never runs backwards and does not
  /// follow changes to the device's clock. The poll schedule is measured on it.
  Duration Function() _elapsed = _startStopwatch();

  /// A real stopwatch, started now, as the default [_elapsed].
  static Duration Function() _startStopwatch() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  /// Tests only: puts in a simulated server, a fake clock and (optionally) a
  /// fake stopwatch, and clears the state this app-wide object kept from an
  /// earlier test. Never called by the app.
  @visibleForTesting
  void configureForTest({
    required TcRoundApi api,
    required DateTime Function() now,
    Duration Function()? elapsed,
  }) {
    _api = api;
    _now = now;
    _elapsed = elapsed ?? _startStopwatch();
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollInFlight = false;
    _resultFetchRunning = false;
    _lastAskedElapsed = null;
    _lastAskedWall = null;
    _gaveUpRoundNumber = null;
    _zeroFetchRoundNumber = null;
    _currentRound = null;
    _betRoundId = null;
    _isConnected = false;
    _connectionError = null;
    _failedPollCount = 0;
    _lastSubmitError = null;
    _deliveredRoundNumber = null;
    _serverTimeOffset = 0;
  }

  // ── State ─────────────────────────────────────────────────────────
  GlobalRoundState? _currentRound;
  String? _betRoundId;    // FIX BUG #6: Track the round ID bets were submitted to
  bool _isConnected = false;
  String? _connectionError;
  int _failedPollCount = 0;

  // Issue #56 (part 2): bumped by every attach()/detach(), captured locally
  // by attach() as "myGeneration". Lets a still-in-flight attach() (its
  // _fetchInitialRound retry loop still running) recognize, once it finally
  // resolves, that it's been superseded by a detach() or a newer attach()
  // in the meantime -- so it neither writes its (possibly stale) results
  // over a newer attempt's already-correct state, nor starts an orphaned
  // polling timer for a screen that's no longer open.
  int _attachGeneration = 0;

  // M-3 FIX: retain why the last submission failed so the UI can explain it.
  // Previously submitBets() returned false and the caller discarded it, so a
  // server-rejected bet was completely invisible to the player.
  String? _lastSubmitError;
  String? get lastSubmitError => _lastSubmitError;

  GlobalRoundState? get currentRound     => _currentRound;
  String? get betRoundId                 => _betRoundId;
  bool get isConnected                   => _isConnected;
  String? get connectionError            => _connectionError;

  // ── Polling & Server Clock Offset ──────────────────────────────────
  int? _deliveredRoundNumber;      // single-delivery lock per round number
  int _serverTimeOffset = 0;       // dynamic clock offset between server and device

  int get syncedNowSecs => (_now().toUtc().millisecondsSinceEpoch ~/ 1000) + _serverTimeOffset;

  /// The round number the synced clock is in now (103-second cycle, as the
  /// server's get_current_round counts it).
  int get _clockRoundNumber => syncedNowSecs ~/ 103;

  /// The second of the round the synced clock is in now (0-102).
  int get _clockSecondsInto => syncedNowSecs % 103;

  void _calibrateServerTimeOffset(GlobalRoundState round) {
    try {
      final localNowSecs = _now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final serverNowSecs = (round.scheduledAt.millisecondsSinceEpoch ~/ 1000) - round.secondsRemaining;
      _serverTimeOffset = serverNowSecs - localNowSecs;
    } catch (_) {}
  }

  /// Called from GameScreen.initState — attaches to the game provider
  Future<void> attach(GameProvider game, AuthProvider auth) async {
    final myGeneration = ++_attachGeneration;
    _connectionError = null;
    // Issue #56: RoundSyncService is a singleton, so without this a quick
    // detach()/attach() cycle (leave the game screen, come right back)
    // inherited whatever strikes _poll() had already accumulated before the
    // player left. A single fresh failure after re-entry could then be
    // enough to trip the 3-strike threshold below, not the intended 3.
    _failedPollCount = 0;
    _lastAskedElapsed = null;
    _lastAskedWall = null;
    _gaveUpRoundNumber = null;
    _zeroFetchRoundNumber = null;
    _resultFetchRunning = false;
    notifyListeners();

    game.startCountdown();
    game.loadGlobalHistory();
    await _fetchInitialRound(game, auth, myGeneration);

    // Issue #56 (part 2): a detach() (or a newer attach()) happened while
    // _fetchInitialRound's retry loop was still running above -- this call
    // is stale. Starting a polling timer now would orphan it: nothing would
    // ever cancel a timer created after the screen that owns it already
    // called detach().
    if (myGeneration != _attachGeneration) return;
    _startPolling(game, auth, myGeneration);
  }

  /// Called from GameScreen.dispose — cleans up.
  void detach() {
    // Issue #56 (part 2): invalidates any attach() still awaiting
    // _fetchInitialRound above -- see _attachGeneration's own comment.
    _attachGeneration++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _deliveredRoundNumber = null;
    _betRoundId = null;
    // B-4 fix: a result fetch still running sees the new generation and stops;
    // this flag must not stay set for the next attach().
    _resultFetchRunning = false;
  }

  // ── Continuous polling ─────────────────────────────────────────────
  Timer? _pollTimer;
  bool _pollInFlight = false;

  /// True while [fetchAndDeliverResult] is asking for the result. The schedule
  /// does not add its own requests meanwhile.
  bool _resultFetchRunning = false;

  /// The round whose result fetch gave up. The 2-second draw checks stop for it.
  int? _gaveUpRoundNumber;

  /// The round for which the result fetch at countdown 00 has started. Until
  /// it has, the schedule does not ask in the draw window (see [_pollIfDue]),
  /// so the result is never shown before the screen reads 00.
  int? _zeroFetchRoundNumber;

  /// When the server was last asked for the round (any request), on the
  /// monotonic stopwatch; the schedule measures its intervals from here.
  Duration? _lastAskedElapsed;

  /// The device's clock at that same moment. Compared with the stopwatch to
  /// notice that the device's clock was moved, or that the phone slept.
  DateTime? _lastAskedWall;

  /// How often the round is asked for while betting is open and the connection
  /// is healthy: only to keep the clock offset right. The 10-second server
  /// timer (cron job bsg-tick-rounds) is the server's own safety net.
  static const Duration _bettingPollInterval = Duration(seconds: 10);

  /// How often the round is asked for from the draw second until the result
  /// is in hand, and after a failed request: the old 2-second rhythm.
  static const Duration _drawPollInterval = Duration(seconds: 2);
  static const Duration _failingPollInterval = Duration(seconds: 2);

  /// How often the schedule checks whether a request is due. No request by itself.
  static const Duration _scheduleInterval = Duration(milliseconds: 500);

  /// How far the device's clock may drift from the stopwatch, between two
  /// requests, before it counts as "the clock was moved (or the phone slept)".
  static const Duration _clockJumpTolerance = Duration(seconds: 2);

  /// Records that the server is being asked for the round now. Called just
  /// before every request for the round, so a slow answer does not stretch
  /// the schedule.
  void _markAsked() {
    _lastAskedElapsed = _elapsed();
    _lastAskedWall = _now();
  }

  /// Asks for the round on the smart schedule ([_pollIfDue], checked every
  /// 0.5 s) for as long as the game screen is open. (Until 2026-11-09 this was
  /// a fixed 2-second poll; the reasons below for having a poll at all still
  /// hold.)
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
  void _startPolling(GameProvider game, AuthProvider auth, int generation) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_scheduleInterval, (_) => _pollIfDue(game, auth, generation));
  }

  /// Called every [_scheduleInterval]; asks for the round only when it is due:
  ///   * while the last request failed (or the connection is down): every
  ///     [_failingPollInterval], so an outage is noticed and recovered from at
  ///     the old pace;
  ///   * when the round known is not the round the clock is in (a new round
  ///     has just begun, or nothing is known yet): at once, so its id is fresh
  ///     before the player bets;
  ///   * from the draw second: nothing until the result fetch at countdown 00
  ///     has started (it is the request that draws and shows the result, at
  ///     the moment the screen reads 00), or, if the countdown missed that
  ///     tick, until 2 seconds after the draw second; then every
  ///     [_drawPollInterval] until this round's result is in hand (or the
  ///     fetch gave up);
  ///   * otherwise, while betting: every [_bettingPollInterval];
  ///   * at once, whatever the interval, when the device's clock has moved
  ///     away from the stopwatch by [_clockJumpTolerance] or more since the
  ///     last request (the clock was changed, or the phone slept).
  /// Never while another request or the result fetch at 00 is running.
  void _pollIfDue(GameProvider game, AuthProvider auth, int generation) {
    if (generation != _attachGeneration) return;
    if (_pollInFlight || _resultFetchRunning) return;
    final Duration due;
    if (!_isConnected || _failedPollCount > 0) {
      due = _failingPollInterval;
    } else if (_waitingForZeroFetch) {
      return;
    } else if (_knownRoundIsStale) {
      due = Duration.zero;
    } else if (_awaitingResult) {
      due = _drawPollInterval;
    } else {
      due = _bettingPollInterval;
    }
    final lastElapsed = _lastAskedElapsed;
    final lastWall = _lastAskedWall;
    if (lastElapsed != null && lastWall != null) {
      final sinceAsked = _elapsed() - lastElapsed;
      final clockMoved = (_now().difference(lastWall) - sinceAsked).abs() >= _clockJumpTolerance;
      if (!clockMoved && sinceAsked < due) return;
    }
    _poll(game, auth);
  }

  /// True when no round is known, or the one known is not the round the clock
  /// is in now.
  bool get _knownRoundIsStale {
    final known = _currentRound;
    return known == null || known.roundNumber != _clockRoundNumber;
  }

  /// True from the draw second until this round's result has been delivered
  /// or its fetch gave up.
  bool get _awaitingResult {
    final known = _currentRound;
    if (known == null || _clockSecondsInto < known.drawAtSecond) return false;
    final number = _clockRoundNumber;
    return _deliveredRoundNumber != number && _gaveUpRoundNumber != number;
  }

  /// True in the first 2 seconds of the draw window while the result fetch at
  /// countdown 00 has not started yet: the schedule leaves the first request
  /// of the draw to that fetch, so a result is never shown before 00.
  bool get _waitingForZeroFetch {
    final known = _currentRound;
    if (known == null || known.roundNumber != _clockRoundNumber) return false;
    final into = _clockSecondsInto;
    if (into < known.drawAtSecond || into >= known.drawAtSecond + 2) return false;
    final number = _clockRoundNumber;
    return _zeroFetchRoundNumber != number && _deliveredRoundNumber != number;
  }

  /// The known round, if a bet or a printed ticket can still go to it: it is
  /// the round the clock is in, it is not drawn, and by the live clock the
  /// draw second has not been reached. The live clock is used, not the
  /// round's own seconds_into, which can be up to 10 seconds old.
  GlobalRoundState? get _roundStillOpen {
    final known = _currentRound;
    if (known == null) return null;
    if (known.red != null && known.green != null && known.black != null) return null;
    if (known.roundNumber != _clockRoundNumber) return null;
    if (_clockSecondsInto >= known.drawAtSecond) return null;
    return known;
  }

  /// The round a printed ticket goes to (Windows Print): [_roundStillOpen],
  /// with no request. Null means betting is closed for this ticket.
  GlobalRoundState? roundForPrint() => _roundStillOpen;

  Future<void> _poll(GameProvider game, AuthProvider auth) async {
    if (_pollInFlight) return;   // never overlap requests on a slow network
    _pollInFlight = true;
    _markAsked();
    try {
      final round = await _api.getCurrentRound();

      if (round == null) {
        _failedPollCount++;
        // Require 3 consecutive failed polls before marking connection as
        // dead, so a brief blip -- a tunnel, one dropped packet, a momentary
        // server stutter -- never interrupts the player. Only a real, sustained
        // outage reaches the popup. The first failure switches the schedule to
        // every 2 seconds, so "disconnected" follows about 4 seconds after it
        // (4-14 seconds after the network actually went, depending on when the
        // next check was due).
        if (_failedPollCount >= 3) {
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
  ///
  /// Issue #56: retries silently up to 3 times, ~500ms apart, before giving
  /// up -- mirroring _poll()'s own 3-strike tolerance below. Previously this
  /// was a single, ungraced attempt: unlike every other reconnection check
  /// in this service, one bad instant right at screen-open (a real
  /// possibility, not a rare fluke -- e.g. quickly leaving and re-entering
  /// mid-blip) was enough on its own to trigger the severe "Connection
  /// Lost" popup, which always ends in a full logout regardless of whether
  /// the very next check would have succeeded.
  Future<void> _fetchInitialRound(GameProvider game, AuthProvider auth, int myGeneration) async {
    GlobalRoundState? round;
    var attempt = 1;
    while (true) {
      _markAsked();
      round = await _api.getCurrentRound();
      if (round != null || attempt >= 3) break;
      attempt++;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Issue #56 (part 2): a detach() (or a newer attach()) already
    // superseded this call while the retry loop above was still running.
    // Bail out before writing anything -- this attempt's results (success
    // or failure) are stale and must not clobber whatever a newer attach()
    // has already established, or is about to.
    if (myGeneration != _attachGeneration) return;

    if (round == null) {
      _isConnected = false;
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
    _connectionError = null;
    notifyListeners();

    // If player opens game mid-spin, deliver result immediately -- this is a
    // replay of a round that already finished while they weren't here, so it
    // shouldn't offer REBET the way a genuinely-watched live round does.
    final nowSecs = syncedNowSecs;
    final cycle = 103 - (nowSecs % 103);
    if (cycle <= 13) {
      game.markPendingCatchUpReplay();
      // Return value deliberately ignored here: this is a replay of a round
      // that already finished while the player wasn't looking, not a bet
      // they're actively watching resolve, and this service has no
      // BuildContext to show a dialog from anyway. If it fails, the player
      // simply doesn't see a replay animation -- a much lower-stakes gap
      // than the live-spin case game_screen.dart handles.
      fetchAndDeliverResult(game, auth);
    }
  }

  /// Called at 00s remaining by GameProvider clock to deliver the result.
  /// Uses a robust 8-attempt polling loop to handle multi-device clock drift and network lag.
  ///
  /// Issue #14: returns false if the round's numbers never arrived within
  /// the retry budget (the round genuinely failed to resolve server-side --
  /// with get_current_round()'s own fault-isolation fix, this now reliably
  /// means "still not drawn" rather than a thrown error). Previously this
  /// returned void and gave up completely silently: no wheel animation, no
  /// message, the player's stake just never resolved. The caller uses the
  /// false return to refund the player and tell them honestly instead.
  ///
  /// B-4 fix (2026-11-09): the fetch belongs to the screen that started it. If
  /// that screen is left (detach) or replaced (a new attach), it stops at its
  /// next step, sends no further request and hands nothing to the game; it
  /// then returns false, which no caller acts on once its screen is gone.
  /// While it runs, the poll schedule adds no requests of its own.
  Future<bool> fetchAndDeliverResult(GameProvider game, AuthProvider auth) async {
    final generation = _attachGeneration;
    final roundNumber = _clockRoundNumber;
    _zeroFetchRoundNumber = roundNumber;
    _resultFetchRunning = true;
    try {
      for (int attempt = 1; attempt <= 8; attempt++) {
        if (generation != _attachGeneration) return false;
        _markAsked();
        final round = await _api.getCurrentRound();
        if (generation != _attachGeneration) return false;
        if (round != null) {
          _currentRound = round;
          _calibrateServerTimeOffset(round);
          if (round.red != null && round.green != null && round.black != null) {
            if (_deliveredRoundNumber != round.roundNumber) {
              _deliveredRoundNumber = round.roundNumber;
              debugPrint('RoundSyncService: exactly-once delivery for round #${round.roundNumber} on attempt $attempt');
              _deliverResult(round, game, auth);
              return true;
            } else {
              return true; // Already delivered for this round
            }
          }
        }
        if (attempt < 8) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
      debugPrint('RoundSyncService: gave up waiting for round result after 8 attempts');
      if (generation == _attachGeneration) _gaveUpRoundNumber = roundNumber;
      return false;
    } finally {
      if (generation == _attachGeneration) _resultFetchRunning = false;
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

    // Use the known round if a bet can still go to it ([_roundStillOpen]: the
    // round the clock is in, not drawn, before the draw second by the live
    // clock). It is read at the start of each round and refreshed every 10
    // seconds, so at the 5-second mark no request is needed. Otherwise fetch
    // a fresh one.
    var targetRound = _roundStillOpen;
    if (targetRound == null) {
      _markAsked();
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

    PlaceBetResult result = await _api.placeBet(
      roundId:    roundId,
      singleBets: singleBets,
      doubleBets: doubleBets,
      tripleBets: tripleBets,
    );

    // Enterprise retry: only re-attempt when the failure looks like a
    // transient connectivity blip (OFFLINE, or UNAUTHENTICATED -- a JWT that
    // briefly failed to attach reads the same way as a dropped request).
    // Every other reason (INSUFFICIENT_COINS, ROUND_CLOSED, BELOW_MIN,
    // EXCEEDS_MAX, BAD_KEY, ACCOUNT_BLOCKED) is a real, final answer from the
    // server -- retrying would either get the identical answer again or, for
    // ROUND_CLOSED specifically, be pointless since that round is genuinely
    // over. Capped at 3 total attempts, ~1s apart, so a real, sustained
    // outage still fails fast -- worst case this adds ~2s, comfortably
    // inside the 5-second window between the submission trigger (05s) and
    // the round's own close (00s).
    // Issue #23: UNKNOWN joins this set for the same reason OFFLINE is here --
    // an error this app doesn't recognize might still be a transient blip
    // worth one more try. NOT_A_PLAYER deliberately stays out: it's a
    // deterministic final answer from the server (this account isn't a
    // player), so retrying it would only waste the 5-second submission
    // window on a call that will never succeed.
    const retryableErrors = {BetError.offline, BetError.unauthenticated, BetError.unknown};
    // A first try that failed this way may still have reached the server and
    // been accepted, with only its reply lost (see the check after the retries).
    final mayHaveReachedServer = !result.success && retryableErrors.contains(result.error);
    var attempt = 1;
    while (!result.success && retryableErrors.contains(result.error) && attempt < 3) {
      attempt++;
      await Future.delayed(const Duration(seconds: 1));
      result = await _api.placeBet(
        roundId:    roundId,
        singleBets: singleBets,
        doubleBets: doubleBets,
        tripleBets: tripleBets,
      );
    }

    // Lost-reply check (2026-11-09): a later try can be refused (ROUND_CLOSED
    // once it arrives at second 88) although an earlier try was accepted and
    // only its reply was lost. Before reporting a failure -- which makes the
    // screen refund the chips and say the bet was not placed -- ask the server
    // once whether this round holds the bet.
    if (!result.success && mayHaveReachedServer) {
      final sent = [singleBets, doubleBets, tripleBets]
          .expand((m) => m.values)
          .fold<int>(0, (a, b) => a + b);
      final mine = await _api.getMyRoundResult(roundId);
      if (mine != null && mine.placedBet && mine.totalStake == sent) {
        // It counted: treated as an accepted bet. The balance is not taken
        // from this answer: the round may already be settled, and its balance
        // would show a win before the wheel. The screen already shows the stake
        // taken; onGlobalResult sets the real balance after the wheel.
        game.setBetStatus(BetSubmissionStatus.submitted, roundId: roundId);
        return true;
      }
      if (mine == null || mine.placedBet) {
        // Could not tell (the check failed, or a different total is on
        // record): reported as sent, so the screen neither refunds nor shows a
        // dialog. The board stays, and onGlobalResult asks the server for this
        // round's result (get_my_round_result), which shows what really
        // happened and sets the true balance.
        debugPrint('RoundSyncService.submitBets: bet outcome unknown after a lost reply; left to the result check');
        game.setBetStatus(BetSubmissionStatus.submitted, roundId: roundId);
        return true;
      }
      // The server holds no bet for this round: a real refusal, below.
    }

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
      bonusMultiplier: round.bonusMultiplier ?? 1,
    );

    // Issue: this used to also call game.loadGlobalHistory() here, racing
    // against onGlobalResult()'s own wheel-synced insert into the same list.
    // Since loadGlobalHistory() has no wait built in, it would usually win
    // that race -- showing this round's digits in the grid almost
    // immediately, then onGlobalResult() would add the same round again once
    // the wheel actually finished, several seconds later. onGlobalResult()
    // already correctly maintains the grid on every round it processes
    // (all rounds, not just ones this player bet on), so the extra fetch
    // here was redundant as well as racy. Removed.
    game.onGlobalResult(spinResult, auth);
  }
}
