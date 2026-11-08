// A simulated Triple Chance server and a fake world, for the round-sync tests.
//
// It follows the live rules of get_current_round() and place_bet(), read from
// the live database (ezcmxxfhjtzqolbtmshr, read only) on 2026-11-08:
//   * a 103-second cycle; the server's clock is EXTRACT(EPOCH FROM NOW())::BIGINT,
//     ROUNDED to the nearest second, so `seconds_into = round(now) mod 103` and
//     `seconds_remaining = 103 - seconds_into`;
//   * draw_at_second = 90: the first call at or after second 90 draws the round,
//     and from then on the digits (and the bonus) are returned;
//   * bet_cutoff_second = 88: a bet arriving at second 88 or later is refused
//     (ROUND_CLOSED), and a bet for another round's id is refused too.
// Its time comes from a function, so a test drives it from a fake clock.
// Modelled on test/lucky16/sim_server.dart.

import 'package:best_smart_game/services/api_contract.dart';
import 'package:best_smart_game/services/round_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

class SimulatedTcServer implements TcRoundApi {
  SimulatedTcServer({
    required this.now,
    this.latency = const Duration(milliseconds: 100),
    this.resultFromSecond = 90,
  });

  /// The server's true time.
  final DateTime Function() now;

  /// How long every answer takes.
  Duration latency;

  /// The second of the cycle from which the digits are returned. Normally the
  /// draw second (90); later to simulate a slow draw, 1000 for one that never
  /// happens.
  int resultFromSecond;

  /// The draw second reported to the app (`draw_at_second`, live 90).
  final int drawAtSecond = 90;

  /// The live `bet_cutoff_second`.
  final int cutoffSecond = 88;

  /// While true every round call fails as if the device were offline.
  bool offline = false;

  int _failuresLeft = 0;
  String _failureError = BetError.offline;

  /// The next [count] round calls fail with [error].
  void failNext(int count, {String error = BetError.offline}) {
    _failuresLeft = count;
    _failureError = error;
  }

  /// Every call to [getCurrentRound]: the server time it arrived, and whether
  /// the answer carried the digits.
  final List<({DateTime at, bool drawn})> pollLog = [];

  int get polls => pollLog.length;

  /// Every bet that reached the server: when, for which round, accepted or not.
  final List<({DateTime arrived, String roundId, bool accepted})> betLog = [];

  int balance = 1000;
  int ledgerVersion = 100;

  String? _lastRoundError;

  @override
  String? get lastRoundError => _lastRoundError;

  /// The server's rounded clock in whole seconds.
  static int roundedSeconds(DateTime t) => (t.millisecondsSinceEpoch / 1000 + 0.5).floor();

  /// The digits a round is drawn with, fixed by the round number so tests can
  /// predict them.
  static ({int red, int green, int black}) digitsOf(int roundNumber) =>
      (red: roundNumber % 10, green: (roundNumber ~/ 10) % 10, black: (roundNumber ~/ 100) % 10);

  /// Where a moment falls in its round, in seconds with a fraction.
  static double positionOf(DateTime t) => (t.millisecondsSinceEpoch / 1000 + 0.5) % 103;

  @override
  Future<GlobalRoundState?> getCurrentRound() async {
    final arrival = now();
    final epoch = roundedSeconds(arrival);
    final number = epoch ~/ 103;
    final into = epoch % 103;
    final drawn = into >= resultFromSecond;
    pollLog.add((at: arrival, drawn: drawn));
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    if (offline || _failuresLeft > 0) {
      if (_failuresLeft > 0) _failuresLeft--;
      _lastRoundError = offline ? BetError.offline : _failureError;
      return null;
    }
    _lastRoundError = null;
    final d = digitsOf(number);
    return GlobalRoundState(
      roundId: 'round-$number',
      roundNumber: number,
      phase: drawn ? 'settled' : 'betting',
      scheduledAt: DateTime.fromMillisecondsSinceEpoch((number + 1) * 103 * 1000, isUtc: true),
      secondsRemaining: 103 - into,
      secondsInto: into,
      drawAtSecond: drawAtSecond,
      red: drawn ? d.red : null,
      green: drawn ? d.green : null,
      black: drawn ? d.black : null,
      bonusMultiplier: drawn ? 1 : null,
    );
  }

  @override
  Future<PlaceBetResult> placeBet({
    required String roundId,
    required Map<String, int> singleBets,
    required Map<String, int> doubleBets,
    required Map<String, int> tripleBets,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency ~/ 2);
    final arrival = now();
    final epoch = roundedSeconds(arrival);
    final number = epoch ~/ 103;
    final into = epoch % 103;
    final accepted = roundId == 'round-$number' && into < cutoffSecond;
    betLog.add((arrived: arrival, roundId: roundId, accepted: accepted));
    if (latency > Duration.zero) await Future<void>.delayed(latency ~/ 2);
    if (!accepted) return const PlaceBetResult(success: false, error: BetError.roundClosed);
    final stake = [singleBets, doubleBets, tripleBets].expand((m) => m.values).fold<int>(0, (a, b) => a + b);
    balance -= stake;
    ledgerVersion++;
    return PlaceBetResult(success: true, totalStake: stake, coinBalance: balance, ledgerVersion: ledgerVersion);
  }
}

/// The fake world a test lives in: one clock for the server and a device clock
/// that may be wrong by some seconds.
class SimWorld {
  SimWorld(this.tester, {required this.cycleNumber, double startInto = 0, double skewSeconds = 0})
      : _start = tester.binding.clock.now(),
        _base = DateTime.fromMillisecondsSinceEpoch(((cycleNumber * 103 + startInto) * 1000).round(), isUtc: true),
        _skewMillis = (skewSeconds * 1000).round();

  final WidgetTester tester;
  final int cycleNumber;
  final DateTime _start;
  final DateTime _base;
  int _skewMillis;

  /// Time that passed while the phone slept (see [sleepPhone]): it moved the
  /// server's and the device's clocks on, but not [elapsed].
  Duration _slept = Duration.zero;

  /// The server's true time.
  DateTime get serverNow => _base.add(tester.binding.clock.now().difference(_start) + _slept);

  /// Monotonic time since the world was created, without the device's error or
  /// any time the phone slept. Passed to the sync as its stopwatch.
  Duration get elapsed => tester.binding.clock.now().difference(_start);

  /// The phone sleeps for [duration] and wakes: the server's and the device's
  /// clocks jump on at once, while the stopwatch ([elapsed]) stands still.
  void sleepPhone(Duration duration) => _slept += duration;

  /// The device's clock: the server's time plus its error.
  DateTime get deviceNow => serverNow.add(Duration(milliseconds: _skewMillis));

  /// Moves the device's clock, as a manual time change or a network time sync would.
  set skewSeconds(double s) => _skewMillis = (s * 1000).round();

  /// Where the server is in its cycle, in seconds with a fraction: `0.0` is the
  /// moment the server's rounded clock reaches the cycle's first second.
  double get cyclePosition => SimulatedTcServer.positionOf(serverNow);

  /// Lets [duration] of fake time pass, a little at a time.
  Future<void> run(Duration duration, {Duration step = const Duration(milliseconds: 100)}) async {
    var left = duration;
    while (left > Duration.zero) {
      final slice = left < step ? left : step;
      await tester.pump(slice);
      left -= slice;
    }
  }

  /// Runs until the server is at [position] seconds of its cycle (or past it).
  Future<void> runUntil(double position, {Duration step = const Duration(milliseconds: 100)}) async {
    var guard = 0;
    while (cyclePosition < position && ++guard < 100000) {
      await tester.pump(step);
    }
  }
}
