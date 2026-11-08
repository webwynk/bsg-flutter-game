// Keeps the Lucky 16 Card screen in step with the server's round: the
// countdown, "what round is it?" on a smart schedule (see
// [Lucky16RoundSync.pollInterval]), the lock mark, and the moment the result
// may be shown.
//
// It holds NO bet, balance or animation. It only watches the round and tells
// the Lucky 16 Card game provider four things, through callbacks:
//   * [onLockMark]          the countdown reached the lock mark (5): lock the
//                           board and send the bet;
//   * [onResult]            the winning card, delivered ONCE per round and
//                           never before the player's countdown reads 00;
//   * [onResultUnavailable] the round ended and its result never arrived;
//   * [onNewCycle]          a new round began.
//
// Everything it depends on is passed in (the API, the clock and the
// stopwatch), so a whole 103-second round runs in a test on a fake clock.
//
// Mirrors Triple Chance's RoundSyncService, whose hard-won rules are kept from
// the start: three failed polls before "disconnected", the clock calibrated
// from every answer, one delivery per round, an 8-attempt result fetch, and a
// generation counter so a screen that was left can never be brought back to
// life by an old, still-running call. The deliberate differences:
//   * the result is HELD until the countdown reads 00. Lucky 16 Card draws at
//     second 89 (the server reply's draw_at_second) and the countdown reaches
//     00 at second 90, so a request can return the winner about a second
//     early, every round; the card must not be shown before 00;
//   * it is an ordinary object created per screen, not a shared singleton;
//   * the round is not asked for every 2 seconds but on a smart schedule
//     (2026-11-09, load reduction, the same schedule as Spin2Win's sync): once
//     at the start of each round, every 10 seconds while betting (to keep the
//     clock calibrated), every second from the draw second until the result is
//     in hand, and every 2 seconds while the connection is failing. About 11
//     requests per 103-second round instead of about 52; the countdown runs
//     from the device's own clock either way. The schedule is timed on a
//     monotonic stopwatch, not the device's clock, so moving the phone's clock
//     cannot pause it; a move of the device's clock, or a phone that slept, is
//     noticed and answered with an immediate request that recalibrates the
//     countdown.
//
// Its own copy of the schedule in lib/services/spin2win_round_sync.dart (only
// the names and the Lucky 16 wording changed), so each game stays independent.
// Belongs to Lucky 16 Card only.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/lucky16_models.dart';
import 'lucky16_api_service.dart';
import 'lucky16_round_clock.dart';

class Lucky16RoundSync extends ChangeNotifier {
  Lucky16RoundSync({
    required Lucky16Api api,
    DateTime Function()? now,
    Duration Function()? elapsed,
    this.pollInterval = const Duration(seconds: 10),
    this.resultPollInterval = const Duration(seconds: 1),
    this.failingPollInterval = const Duration(seconds: 2),
    this.scheduleInterval = const Duration(milliseconds: 500),
    this.tickInterval = const Duration(seconds: 1),
    this.clockJumpTolerance = const Duration(seconds: 2),
  })  : _api = api,
        _now = now ?? DateTime.now,
        _elapsed = elapsed ?? _startStopwatch(),
        clock = Lucky16RoundClock(now: now);

  final Lucky16Api _api;
  final DateTime Function() _now;

  /// Monotonic time since this sync was created: it never runs backwards and
  /// does not follow changes to the device's clock. The poll schedule is
  /// measured on it. Tests pass the fake world's elapsed time.
  final Duration Function() _elapsed;

  /// A real stopwatch, started now, as the default [_elapsed].
  static Duration Function() _startStopwatch() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  /// The round clock; the countdown and the second of the cycle come from it.
  final Lucky16RoundClock clock;

  /// How often the round is asked for while betting is open and the connection
  /// is healthy. Only to keep the clock calibrated: the countdown itself runs
  /// from the device's clock, and the round's id does not change within a
  /// round. The 10-second server timer (the cron job 'bsg-lucky16-tick-rounds')
  /// is the server's own safety net for the draw.
  final Duration pollInterval;

  /// How often the round is asked for from the draw second until this round's
  /// result is in hand (when the countdown-at-00 fetch is not already doing it).
  final Duration resultPollInterval;

  /// How often the round is asked for after a failed poll, until one succeeds:
  /// the old 2-second rhythm, so an outage is reported and recovered from at
  /// the same pace once it has been noticed.
  final Duration failingPollInterval;

  /// How often the schedule checks whether a poll is due. No request by itself.
  final Duration scheduleInterval;

  /// How often the countdown is re-read.
  final Duration tickInterval;

  /// How far the device's clock may drift from the stopwatch, between two
  /// requests, before it counts as "the clock was moved (or the phone slept)"
  /// and the round is asked for at once to recalibrate the countdown. Small
  /// network-time corrections (well under a second) stay below it.
  final Duration clockJumpTolerance;

  // ── What the rest of the app listens for ────────────────────────────────

  /// The countdown reached the lock mark. Lock the board and send the bet.
  VoidCallback? onLockMark;

  /// The result of the round that just ended. Called once per round.
  void Function(Lucky16RoundResult result)? onResult;

  /// The result of the round that just ended never arrived within the retry
  /// budget. Nothing was delivered for it.
  VoidCallback? onResultUnavailable;

  /// A new round began (the cycle wrapped back to second 0).
  VoidCallback? onNewCycle;

  // ── State ───────────────────────────────────────────────────────────────

  Lucky16RoundState? _currentRound;
  bool _isConnected = false;
  Lucky16Error? _connectionError;
  int _failedPolls = 0;

  /// Bumped by every [attach] and [detach]. A call that started under an older
  /// value is stale: it neither writes its results nor starts a timer for a
  /// screen that is no longer open.
  int _generation = 0;

  Timer? _pollTimer;
  Timer? _tickTimer;
  bool _pollInFlight = false;
  bool _resultFetchRunning = false;

  /// When the server was last asked for the round (any request), on the
  /// monotonic stopwatch; the schedule measures its intervals from here.
  Duration? _lastAskedElapsed;

  /// The device's clock at that same moment. Compared with the stopwatch to
  /// notice that the device's clock was moved, or that the phone slept.
  DateTime? _lastAskedWall;

  /// Records that the server is being asked for the round now. Called just
  /// before every request for the round, so a slow answer does not stretch
  /// the schedule.
  void _markAsked() {
    _lastAskedElapsed = _elapsed();
    _lastAskedWall = _now();
  }

  /// The round number whose result has already been delivered: the one-time lock.
  int? _deliveredRoundNumber;

  /// The round whose result fetch gave up ([onResultUnavailable] was called).
  /// The 1-second result polling stops for it; the normal schedule continues.
  int? _gaveUpRoundNumber;

  /// A drawn round seen before the countdown reached 00, held back.
  Lucky16RoundState? _heldResult;

  /// The round whose result is being fetched as a catch-up replay (the player
  /// opened the screen after it finished). While set, a poll must not deliver
  /// that round as a live one: the fetch delivers it, marked as a replay.
  int? _catchUpRoundNumber;

  int? _lastCountdown;
  int? _lastSecondsInto;

  /// The most recent answer from the server; null before the first.
  Lucky16RoundState? get currentRound => _currentRound;

  /// False once three polls in a row have failed, and until one succeeds.
  bool get isConnected => _isConnected;

  /// Why the connection is down; null while it is up.
  Lucky16Error? get connectionError => _connectionError;

  /// True while the sync has a timer running: between [attach] and [detach].
  /// Lets the screen, and the tests, check that leaving really stopped everything.
  bool get isWatching => _tickTimer != null || _pollTimer != null;

  /// What the player's countdown reads (90 down to 0).
  int get countdown => clock.countdown;

  /// The second of the round the server is in, as this device reads it.
  int get secondsInto => clock.secondsInto;

  /// Why the last request for the round failed; null after a success.
  Lucky16Error? get lastRoundError => _api.lastRoundError;

  // ── Life cycle ──────────────────────────────────────────────────────────

  /// Starts watching the round. Call when the game screen opens.
  ///
  /// The countdown starts at once from the device's clock and is corrected as
  /// soon as the server answers. The round is asked for up to three times, half
  /// a second apart, so one bad instant at screen-open does not read as an
  /// outage; the poll schedule starts even if all three fail, so the connection
  /// can recover on its own.
  Future<void> attach() async {
    final generation = ++_generation;
    _cancelTimers();
    _failedPolls = 0;
    _lastAskedElapsed = null;
    _lastAskedWall = null;
    _gaveUpRoundNumber = null;
    _connectionError = null;
    _deliveredRoundNumber = null;
    _heldResult = null;
    _pollInFlight = false;
    _resultFetchRunning = false;
    _catchUpRoundNumber = null;
    _lastCountdown = clock.countdown;
    _lastSecondsInto = clock.secondsInto;
    _startTicker(generation);
    notifyListeners();

    await _fetchInitialRound(generation);
    if (generation != _generation) return;
    _pollTimer = Timer.periodic(scheduleInterval, (_) => _pollIfDue(generation));
  }

  /// Stops watching. Call when the game screen closes. Any call still in flight
  /// is ignored when it finishes.
  void detach() {
    _generation++;
    _cancelTimers();
    _heldResult = null;
    _deliveredRoundNumber = null;
    _catchUpRoundNumber = null;
    _pollInFlight = false;
    _resultFetchRunning = false;
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  void _cancelTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void _startTicker(int generation) {
    _tickTimer = Timer.periodic(tickInterval, (_) => _tick(generation));
  }

  // ── Betting support ─────────────────────────────────────────────────────

  /// The round a bet should be sent to: the one already known if it is this
  /// cycle's round and, by the live clock, the draw second has not yet been
  /// reached; otherwise a fresh one from the server. Returns null if no answer
  /// came; [lastRoundError] says why.
  ///
  /// The live clock is used, not the second recorded when the round was last
  /// read (which can be up to 10 seconds old): a round read at second 88 could
  /// still say "open" at second 90 by its own stale field. Checking the round number
  /// also stops a bet being aimed at an earlier round's id after a stretch
  /// without answers. The server still has the last word; this only avoids
  /// sending a bet that is certain to be refused.
  Future<Lucky16RoundState?> roundForBet() async {
    final known = _currentRound;
    if (known != null &&
        !known.isDrawn &&
        known.roundNumber == clock.roundNumber &&
        clock.secondsInto < known.drawAtSecond) {
      return known;
    }
    final generation = _generation;
    _markAsked();
    final fresh = await _api.getCurrentRound();
    if (generation != _generation || fresh == null) return null;
    _observe(fresh, generation);
    return fresh;
  }

  // ── The 1-second tick ───────────────────────────────────────────────────

  void _tick(int generation) {
    if (generation != _generation) return;
    final countdown = clock.countdown;
    final into = clock.secondsInto;
    final previousCountdown = _lastCountdown ?? countdown;
    final previousInto = _lastSecondsInto ?? into;
    _lastCountdown = countdown;
    _lastSecondsInto = into;

    // The cycle wrapped: a new round has begun.
    if (into < previousInto) {
      _heldResult = null;
      onNewCycle?.call();
    }
    if (Lucky16RoundClock.crossedLockMark(
      previousCountdown: previousCountdown,
      currentCountdown: countdown,
    )) {
      onLockMark?.call();
    }
    if (Lucky16RoundClock.crossedZero(
      previousCountdown: previousCountdown,
      currentCountdown: countdown,
    )) {
      _onCountdownReachedZero(generation);
    }
    if (countdown != previousCountdown) notifyListeners();
  }

  /// The countdown just read 00: show the result, which is either already held
  /// from a poll or has to be fetched now.
  void _onCountdownReachedZero(int generation) {
    final number = clock.roundNumber;
    if (_deliveredRoundNumber == number) return;
    final held = _heldResult;
    if (held != null && held.roundNumber == number) {
      _deliver(held, isCatchUpReplay: false);
      return;
    }
    _fetchAndDeliver(generation, roundNumber: number, isCatchUpReplay: false);
  }

  // ── The poll schedule ───────────────────────────────────────────────────

  /// Called every [scheduleInterval]; asks for the round only when it is due:
  ///   * while the last poll failed (or the connection is down): every
  ///     [failingPollInterval], as before, so recovery is just as quick;
  ///   * when the round known is not this cycle's round (a new round has just
  ///     begun, or nothing is known yet): at once, so its id is fresh before
  ///     the player bets;
  ///   * from the draw second until this round's result is in hand: every
  ///     [resultPollInterval];
  ///   * otherwise, while betting: every [pollInterval];
  ///   * at once, whatever the interval, when the device's clock has moved
  ///     away from the stopwatch by [clockJumpTolerance] or more since the
  ///     last request (the clock was changed, or the phone slept), so the
  ///     countdown is recalibrated straight away.
  /// Intervals are measured on the monotonic stopwatch, never on the device's
  /// clock, so moving that clock back cannot pause the schedule.
  /// Never while another poll or the countdown-at-00 result fetch is running.
  void _pollIfDue(int generation) {
    if (generation != _generation) return;
    if (_pollInFlight || _resultFetchRunning) return;
    final Duration due;
    if (!_isConnected || _failedPolls > 0) {
      due = failingPollInterval;
    } else if (_knownRoundIsStale) {
      due = Duration.zero;
    } else if (_awaitingResult) {
      due = resultPollInterval;
    } else {
      due = pollInterval;
    }
    final lastElapsed = _lastAskedElapsed;
    final lastWall = _lastAskedWall;
    if (lastElapsed != null && lastWall != null) {
      final sinceAsked = _elapsed() - lastElapsed;
      final clockMoved =
          (_now().difference(lastWall) - sinceAsked).abs() >= clockJumpTolerance;
      if (!clockMoved && sinceAsked < due) return;
    }
    _poll(generation);
  }

  /// True when no round is known, or the one known is not the round the
  /// clock says is running now.
  bool get _knownRoundIsStale {
    final known = _currentRound;
    return known == null || known.roundNumber != clock.roundNumber;
  }

  /// True from the draw second until this round's result has been delivered,
  /// is held for delivery at 00, or has been given up on.
  bool get _awaitingResult {
    final known = _currentRound;
    if (known == null || clock.secondsInto < known.drawAtSecond) return false;
    final number = clock.roundNumber;
    if (_deliveredRoundNumber == number) return false;
    if (_gaveUpRoundNumber == number) return false;
    if (_heldResult?.roundNumber == number) return false;
    return true;
  }

  Future<void> _poll(int generation) async {
    if (generation != _generation) return;
    if (_pollInFlight) return; // never overlap requests on a slow network
    _pollInFlight = true;
    _markAsked();
    try {
      final round = await _api.getCurrentRound();
      if (generation != _generation) return;

      if (round == null) {
        _failedPolls++;
        // Three failed polls in a row before the connection is called dead, so a
        // tunnel or a dropped packet never interrupts the player. The first
        // failure switches the schedule to [failingPollInterval], so the second
        // and third follow 2 seconds apart (about 4 seconds after the first).
        if (_failedPolls >= 3) {
          final reason = _api.lastRoundError ?? Lucky16Error.offline;
          if (_isConnected || _connectionError != reason) {
            _isConnected = false;
            _connectionError = reason;
            notifyListeners();
          }
        }
        return;
      }
      _failedPolls = 0;
      _observe(round, generation);
    } finally {
      if (generation == _generation) _pollInFlight = false;
    }
  }

  /// Takes in an answer from the server: remembers the round, corrects the
  /// clock, restores the connection, and handles a drawn round.
  void _observe(Lucky16RoundState round, int generation) {
    if (generation != _generation) return;
    final held = _heldResult;
    if (held != null && held.roundNumber != round.roundNumber) _heldResult = null;
    _currentRound = round;
    clock.calibrate(round);
    if (!_isConnected || _connectionError != null) {
      _isConnected = true;
      _connectionError = null;
    }
    if (round.isDrawn && round.roundNumber != _deliveredRoundNumber) {
      // The winner is known, but the card must not be shown before the player's
      // countdown reads 00: hold it unless that has already happened.
      if (clock.countdown == 0 &&
          clock.roundNumber == round.roundNumber &&
          _catchUpRoundNumber != round.roundNumber) {
        _deliver(round, isCatchUpReplay: false);
      } else {
        _heldResult = round;
      }
    }
    notifyListeners();
  }

  // ── The first fetch, and joining late ───────────────────────────────────

  Future<void> _fetchInitialRound(int generation) async {
    Lucky16RoundState? round;
    for (var attempt = 1;; attempt++) {
      _markAsked();
      round = await _api.getCurrentRound();
      if (generation != _generation) return;
      if (round != null || attempt >= 3) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (generation != _generation) return;
    }
    if (round == null) {
      _isConnected = false;
      _connectionError = _api.lastRoundError ?? Lucky16Error.offline;
      notifyListeners();
      return;
    }
    _currentRound = round;
    clock.calibrate(round);
    _lastCountdown = clock.countdown;
    _lastSecondsInto = clock.secondsInto;
    _isConnected = true;
    _connectionError = null;
    notifyListeners();

    // The player opened the screen after the countdown had reached 00: this
    // round has already finished. Show it as a replay, which is not offered for
    // Rebet. (Triple Chance does the same when the cycle has 13 seconds or less
    // left.)
    if (clock.secondsInto >= kLucky16CountdownStart) {
      final number = clock.roundNumber;
      if (round.isDrawn && round.roundNumber == number) {
        _deliver(round, isCatchUpReplay: true);
      } else {
        _catchUpRoundNumber = number;
        _fetchAndDeliver(generation, roundNumber: number, isCatchUpReplay: true);
      }
    }
  }

  // ── Fetching the result ─────────────────────────────────────────────────

  /// Asks for the round up to 8 times, a second apart, until its result is
  /// there, then delivers it. Used when the countdown reaches 00 and the winner
  /// is not already in hand. Gives up, once, with [onResultUnavailable].
  Future<void> _fetchAndDeliver(
    int generation, {
    required int roundNumber,
    required bool isCatchUpReplay,
  }) async {
    if (_resultFetchRunning) return;
    _resultFetchRunning = true;
    try {
      for (var attempt = 1; attempt <= 8; attempt++) {
        if (generation != _generation) return;
        _markAsked();
        final round = await _api.getCurrentRound();
        if (generation != _generation) return;
        if (round != null) {
          _observe(round, generation);
          if (_deliveredRoundNumber == roundNumber) return;
          // The cycle has moved on: that round's result can no longer be fetched.
          if (round.roundNumber != roundNumber) break;
          if (round.isDrawn) {
            _deliver(round, isCatchUpReplay: isCatchUpReplay);
            return;
          }
        }
        if (attempt < 8) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      if (generation == _generation && _deliveredRoundNumber != roundNumber) {
        _gaveUpRoundNumber = roundNumber;
        onResultUnavailable?.call();
      }
    } finally {
      if (generation == _generation) {
        _resultFetchRunning = false;
        if (_catchUpRoundNumber == roundNumber) _catchUpRoundNumber = null;
      }
    }
  }

  // ── Delivery ────────────────────────────────────────────────────────────

  /// Hands the result over, once per round number.
  void _deliver(Lucky16RoundState round, {required bool isCatchUpReplay}) {
    if (!round.isDrawn) return;
    if (_deliveredRoundNumber == round.roundNumber) return;
    _deliveredRoundNumber = round.roundNumber;
    _heldResult = null;
    onResult?.call(
      Lucky16RoundResult.fromRound(round, isCatchUpReplay: isCatchUpReplay),
    );
  }
}
