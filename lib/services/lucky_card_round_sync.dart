// Keeps the Lucky Card screen in step with the server's round: the countdown,
// "what round is it?" every 2 seconds, the lock mark, and the moment the result
// may be shown.
//
// It holds NO bet, balance or animation. It only watches the round and tells
// the game provider (App Step 3b) four things, through callbacks:
//   * [onLockMark]          the countdown reached the lock mark (5): lock the
//                           board and send the bet;
//   * [onResult]            the winning card, delivered ONCE per round and
//                           never before the player's countdown reads 00;
//   * [onResultUnavailable] the round ended and its result never arrived;
//   * [onNewCycle]          a new round began.
//
// Everything it depends on is passed in (the API and the clock), so a whole
// 103-second round runs in a test on a fake clock.
//
// Mirrors Triple Chance's RoundSyncService, whose hard-won rules are kept from
// the start: a 2-second poll, three failed polls before "disconnected", the
// clock calibrated from every answer, one delivery per round, an 8-attempt
// result fetch, and a generation counter so a screen that was left can never be
// brought back to life by an old, still-running call. The deliberate differences:
//   * the result is HELD until the countdown reads 00. Lucky Card draws at
//     second 89 and the countdown reaches 00 at second 90, so a poll can return
//     the winner up to about 1.2 seconds early (measured, spec §17F), and the
//     wheel must not start before 00;
//   * it is an ordinary object created per screen, not a shared singleton.
//
// Belongs to Lucky Card only.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/lucky_card_models.dart';
import 'lucky_card_api_service.dart';
import 'lucky_card_round_clock.dart';

class LuckyCardRoundSync extends ChangeNotifier {
  LuckyCardRoundSync({
    required LuckyCardApi api,
    DateTime Function()? now,
    this.pollInterval = const Duration(seconds: 2),
    this.tickInterval = const Duration(seconds: 1),
  })  : _api = api,
        clock = LuckyCardRoundClock(now: now);

  final LuckyCardApi _api;

  /// The round clock; the countdown and the second of the cycle come from it.
  final LuckyCardRoundClock clock;

  /// How often the round is asked for. The Lucky Card spec and Triple Chance's
  /// own app both use 2 seconds; the 10-second server timer is only a safety net
  /// that relies on this poll (spec §14.18).
  final Duration pollInterval;

  /// How often the countdown is re-read.
  final Duration tickInterval;

  // ── What the rest of the app listens for ────────────────────────────────

  /// The countdown reached the lock mark. Lock the board and send the bet.
  VoidCallback? onLockMark;

  /// The result of the round that just ended. Called once per round.
  void Function(LuckyCardRoundResult result)? onResult;

  /// The result of the round that just ended never arrived within the retry
  /// budget. Nothing was delivered for it.
  VoidCallback? onResultUnavailable;

  /// A new round began (the cycle wrapped back to second 0).
  VoidCallback? onNewCycle;

  // ── State ───────────────────────────────────────────────────────────────

  LuckyCardRoundState? _currentRound;
  bool _isConnected = false;
  LuckyCardError? _connectionError;
  int _failedPolls = 0;

  /// Bumped by every [attach] and [detach]. A call that started under an older
  /// value is stale: it neither writes its results nor starts a timer for a
  /// screen that is no longer open.
  int _generation = 0;

  Timer? _pollTimer;
  Timer? _tickTimer;
  bool _pollInFlight = false;
  bool _resultFetchRunning = false;

  /// The round number whose result has already been delivered: the one-time lock.
  int? _deliveredRoundNumber;

  /// A drawn round seen before the countdown reached 00, held back.
  LuckyCardRoundState? _heldResult;

  /// The round whose result is being fetched as a catch-up replay (the player
  /// opened the screen after it finished). While set, a poll must not deliver
  /// that round as a live one: the fetch delivers it, marked as a replay.
  int? _catchUpRoundNumber;

  int? _lastCountdown;
  int? _lastSecondsInto;

  /// The most recent answer from the server; null before the first.
  LuckyCardRoundState? get currentRound => _currentRound;

  /// False once three polls in a row have failed, and until one succeeds.
  bool get isConnected => _isConnected;

  /// Why the connection is down; null while it is up.
  LuckyCardError? get connectionError => _connectionError;

  /// True while the sync has a timer running: between [attach] and [detach].
  /// Lets the screen, and the tests, check that leaving really stopped everything.
  bool get isWatching => _tickTimer != null || _pollTimer != null;

  /// What the player's countdown reads (90 down to 0).
  int get countdown => clock.countdown;

  /// The second of the round the server is in, as this device reads it.
  int get secondsInto => clock.secondsInto;

  /// Why the last request for the round failed; null after a success.
  LuckyCardError? get lastRoundError => _api.lastRoundError;

  // ── Life cycle ──────────────────────────────────────────────────────────

  /// Starts watching the round. Call when the game screen opens.
  ///
  /// The countdown starts at once from the device's clock and is corrected as
  /// soon as the server answers. The round is asked for up to three times, half
  /// a second apart, so one bad instant at screen-open does not read as an
  /// outage; polling starts even if all three fail, so the connection can
  /// recover on its own.
  Future<void> attach() async {
    final generation = ++_generation;
    _cancelTimers();
    _failedPolls = 0;
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
    _pollTimer = Timer.periodic(pollInterval, (_) => _poll(generation));
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
  /// read (which can be up to 2 seconds old): a round read at second 88 still
  /// said "open" at second 90 by its own stale field. Checking the round number
  /// also stops a bet being aimed at an earlier round's id after a stretch
  /// without answers. The server still has the last word; this only avoids
  /// sending a bet that is certain to be refused.
  Future<LuckyCardRoundState?> roundForBet() async {
    final known = _currentRound;
    if (known != null &&
        !known.isDrawn &&
        known.roundNumber == clock.roundNumber &&
        clock.secondsInto < known.drawAtSecond) {
      return known;
    }
    final generation = _generation;
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
    if (LuckyCardRoundClock.crossedLockMark(
      previousCountdown: previousCountdown,
      currentCountdown: countdown,
    )) {
      onLockMark?.call();
    }
    if (LuckyCardRoundClock.crossedZero(
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

  // ── The 2-second poll ───────────────────────────────────────────────────

  Future<void> _poll(int generation) async {
    if (generation != _generation) return;
    if (_pollInFlight) return; // never overlap requests on a slow network
    _pollInFlight = true;
    try {
      final round = await _api.getCurrentRound();
      if (generation != _generation) return;

      if (round == null) {
        _failedPolls++;
        // Three failed polls in a row (about 6 seconds) before the connection is
        // called dead, so a tunnel or a dropped packet never interrupts the player.
        if (_failedPolls >= 3) {
          final reason = _api.lastRoundError ?? LuckyCardError.offline;
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
  void _observe(LuckyCardRoundState round, int generation) {
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
      // The winner is known, but the wheel must not start before the player's
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
    LuckyCardRoundState? round;
    for (var attempt = 1;; attempt++) {
      round = await _api.getCurrentRound();
      if (generation != _generation) return;
      if (round != null || attempt >= 3) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (generation != _generation) return;
    }
    if (round == null) {
      _isConnected = false;
      _connectionError = _api.lastRoundError ?? LuckyCardError.offline;
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
    if (clock.secondsInto >= kLuckyCardCountdownStart) {
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
  void _deliver(LuckyCardRoundState round, {required bool isCatchUpReplay}) {
    if (!round.isDrawn) return;
    if (_deliveredRoundNumber == round.roundNumber) return;
    _deliveredRoundNumber = round.roundNumber;
    _heldResult = null;
    onResult?.call(
      LuckyCardRoundResult.fromRound(round, isCatchUpReplay: isCatchUpReplay),
    );
  }
}
