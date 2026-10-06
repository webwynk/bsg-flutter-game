// A simulated Lucky Card server for the round-sync tests.
//
// It follows the real server's rules, which were measured on the live database
// (spec §17F): a 103-second cycle, `seconds_into = round(now) mod 103`,
// `seconds_remaining = 103 - seconds_into`, the winner and the bonus returned
// only from the draw second (89) on. Its time comes from a function, so a test
// drives it from a fake clock.

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/services/lucky_card_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

class SimulatedLuckyCardServer implements LuckyCardApi {
  SimulatedLuckyCardServer({
    required this.now,
    this.latency = Duration.zero,
    this.drawAtSecond = 89,
    this.resultFromSecond = 89,
  });

  /// The server's true time.
  final DateTime Function() now;

  /// How long every answer takes.
  Duration latency;

  /// The draw second reported to the app (`draw_at_second`).
  final int drawAtSecond;

  /// The second of the cycle from which the winner is returned. Normally the draw
  /// second; later to simulate a slow draw, or 1000 to simulate one that never
  /// happens.
  int resultFromSecond;

  /// While true every call fails as if the device were offline.
  bool offline = false;

  /// The next [failNext] calls fail with this error.
  int _failuresLeft = 0;
  LuckyCardError _failureError = LuckyCardError.offline;

  // ── The player's account and bets ───────────────────────────────────────

  /// The player's real balance in the database.
  int serverBalance = 1000;
  int ledgerVersion = 100;

  /// How long a bet takes to reach the server (its arrival time is when the
  /// cutoff is judged).
  Duration uplink = Duration.zero;

  /// The server stops taking bets from this second of the cycle (the live
  /// `bet_cutoff_second`).
  final int cutoffSecond = 88;

  /// Every bet that reached the server: when, for which round, and what it held.
  final List<({DateTime arrived, String roundId, Map<LuckyCard, int> bets})> betLog = [];

  /// The stake on record per round.
  final Map<String, int> _stakeOn = {};

  /// While true every bet fails as if the device were offline.
  bool betsOffline = false;
  int _betFailuresLeft = 0;
  LuckyCardError _betFailureError = LuckyCardError.offline;

  /// The next [count] bets fail with [error] before reaching the account.
  void failBetsNext(int count, {LuckyCardError error = LuckyCardError.offline}) {
    _betFailuresLeft = count;
    _betFailureError = error;
  }

  int get betsReceived => betLog.length;

  /// What the database has recorded as staked on a round.
  int stakedOn(String roundId) => _stakeOn[roundId] ?? 0;

  /// Every call to [getCurrentRound]: the server time it arrived, and whether
  /// the answer carried the winner.
  final List<({DateTime at, bool drawn})> pollLog = [];

  LuckyCardError? _lastRoundError;

  @override
  LuckyCardError? get lastRoundError => _lastRoundError;

  void failNext(int count, {LuckyCardError error = LuckyCardError.offline}) {
    _failuresLeft = count;
    _failureError = error;
  }

  int get polls => pollLog.length;

  /// The server's rounded clock in whole seconds.
  static int roundedSeconds(DateTime t) =>
      (t.millisecondsSinceEpoch / 1000 + 0.5).floor();

  /// The card a round is decided for, fixed by the round number so tests can
  /// predict it.
  static LuckyCard winnerOf(int roundNumber) => LuckyCard.all[roundNumber % 12];

  /// The bonus a round was pinned with.
  static int bonusOf(int roundNumber) => 1 + roundNumber % 10;

  @override
  Future<LuckyCardRoundState?> getCurrentRound() async {
    final arrival = now();
    final epoch = roundedSeconds(arrival);
    final number = epoch ~/ 103;
    final into = epoch % 103;
    final drawn = into >= resultFromSecond;
    pollLog.add((at: arrival, drawn: drawn));
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    if (offline || _failuresLeft > 0) {
      if (_failuresLeft > 0) _failuresLeft--;
      _lastRoundError = offline ? LuckyCardError.offline : _failureError;
      return null;
    }
    _lastRoundError = null;
    return LuckyCardRoundState(
      roundId: 'round-$number',
      roundNumber: number,
      phase: drawn ? 'settled' : 'betting',
      scheduledAt: DateTime.fromMillisecondsSinceEpoch((number + 1) * 103 * 1000, isUtc: true),
      secondsRemaining: 103 - into,
      secondsInto: into,
      drawAtSecond: drawAtSecond,
      winningCard: drawn ? winnerOf(number) : null,
      bonusMultiplier: drawn ? bonusOf(number) : null,
    );
  }

  @override
  Future<LuckyCardPlaceBetResult> placeBet({
    required String roundId,
    required Map<LuckyCard, int> bets,
  }) async {
    if (uplink > Duration.zero) await Future<void>.delayed(uplink);
    final arrival = now();
    betLog.add((arrived: arrival, roundId: roundId, bets: Map.of(bets)));
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    if (betsOffline || _betFailuresLeft > 0) {
      final error = betsOffline ? LuckyCardError.offline : _betFailureError;
      if (_betFailuresLeft > 0) _betFailuresLeft--;
      betLog.removeLast(); // it never reached the account
      return LuckyCardPlaceBetResult.failure(error);
    }
    final epoch = roundedSeconds(arrival);
    final number = epoch ~/ 103;
    final into = epoch % 103;
    if (roundId != 'round-$number' || into >= cutoffSecond) {
      return const LuckyCardPlaceBetResult.failure(LuckyCardError.roundClosed);
    }
    final stake = bets.values.fold<int>(0, (a, b) => a + b);
    final delta = stake - (_stakeOn[roundId] ?? 0);
    if (serverBalance < delta) {
      return const LuckyCardPlaceBetResult.failure(LuckyCardError.insufficientCoins);
    }
    serverBalance -= delta;
    ledgerVersion++;
    _stakeOn[roundId] = stake;
    _betsByRound[roundId] = Map.of(bets);
    return LuckyCardPlaceBetResult(
      success: true,
      totalStake: stake,
      coinBalance: serverBalance,
      ledgerVersion: ledgerVersion,
    );
  }

  // ── The player's result ─────────────────────────────────────────────────

  /// From this second of its cycle a round's bets count as settled (the draw is
  /// at 89; later simulates a big round still being settled in batches).
  int settleFromSecond = 89;

  /// How long a result answer takes, if different from [latency].
  Duration? resultLatency;

  /// While true every result request fails as if the device were offline.
  bool resultsOffline = false;

  /// Every result request: when it arrived and for which round.
  final List<({DateTime at, String roundId})> resultCalls = [];

  final Map<String, Map<LuckyCard, int>> _betsByRound = {};
  final Set<String> _credited = {};

  /// The simulated payout rule: only the winning card pays, ten times its stake
  /// times the bonus. (The real rules are proven in the database tests; the app
  /// only has to show what the server says.)
  static int payoutOf(Map<LuckyCard, int> bets, int roundNumber) =>
      (bets[winnerOf(roundNumber)] ?? 0) * 10 * bonusOf(roundNumber);

  @override
  Future<LuckyCardMyResult?> getMyRoundResult(String roundId) async {
    final arrival = now();
    resultCalls.add((at: arrival, roundId: roundId));
    final wait = resultLatency ?? latency;
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (resultsOffline) return null;

    final bets = _betsByRound[roundId];
    if (bets == null) {
      return LuckyCardMyResult(
        placedBet: false,
        totalStake: 0,
        totalPayout: 0,
        isSettled: false,
        coinBalance: serverBalance,
        ledgerVersion: ledgerVersion,
      );
    }
    final number = int.parse(roundId.substring('round-'.length));
    final epoch = roundedSeconds(arrival);
    final settled = epoch ~/ 103 > number ||
        (epoch ~/ 103 == number && epoch % 103 >= settleFromSecond);
    if (!settled) {
      return LuckyCardMyResult(
        placedBet: true,
        totalStake: _stakeOn[roundId] ?? 0,
        totalPayout: 0,
        isSettled: false,
        coinBalance: serverBalance,
        ledgerVersion: ledgerVersion,
      );
    }
    final payout = payoutOf(bets, number);
    if (_credited.add(roundId)) {
      serverBalance += payout;
      ledgerVersion++;
    }
    return LuckyCardMyResult(
      placedBet: true,
      totalStake: _stakeOn[roundId] ?? 0,
      totalPayout: payout,
      isSettled: true,
      coinBalance: serverBalance,
      ledgerVersion: ledgerVersion,
    );
  }

  /// While true the history request fails; like the real service, which answers
  /// an empty list when anything goes wrong.
  bool recentOffline = false;

  /// Every history request: when it arrived.
  final List<DateTime> recentCalls = [];

  /// The last [limit] DRAWN rounds, newest first. As in the database, a round is
  /// in the list from the moment it is drawn (second 89), which is before the
  /// player's countdown reads 00.
  @override
  Future<List<LuckyCardRecentRound>> getRecentRounds({int limit = 10}) async {
    final arrival = now();
    recentCalls.add(arrival);
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (recentOffline || offline) return const [];
    final epoch = roundedSeconds(arrival);
    final number = epoch ~/ 103;
    final drawnNow = epoch % 103 >= resultFromSecond;
    final newest = drawnNow ? number : number - 1;
    return [
      for (var n = newest; n > newest - limit; n--)
        LuckyCardRecentRound(
          roundId: 'round-$n',
          roundNumber: n,
          winningCard: winnerOf(n),
          bonusMultiplier: bonusOf(n),
          scheduledAt: DateTime.fromMillisecondsSinceEpoch((n + 1) * 103 * 1000, isUtc: true),
        ),
    ];
  }
}

/// The fake world a round-sync test lives in: one clock for the server and a
/// device clock that may be wrong by a fraction of a second.
class SimWorld {
  SimWorld(this.tester, {required this.cycleNumber, double startInto = 0, double skewSeconds = 0})
      : _start = tester.binding.clock.now(),
        _base = DateTime.fromMillisecondsSinceEpoch(
          ((cycleNumber * 103 + startInto) * 1000).round(),
          isUtc: true,
        ),
        _skewMillis = (skewSeconds * 1000).round();

  final WidgetTester tester;
  final int cycleNumber;
  final DateTime _start;
  final DateTime _base;
  int _skewMillis;

  /// The server's true time.
  DateTime get serverNow => _base.add(tester.binding.clock.now().difference(_start));

  /// The device's clock: the server's time plus its error.
  DateTime get deviceNow => serverNow.add(Duration(milliseconds: _skewMillis));

  /// Moves the device's clock, as a manual time change or a network time sync would.
  set skewSeconds(double s) => _skewMillis = (s * 1000).round();

  /// Where the server is in its cycle, in seconds with a fraction, exactly:
  /// `0.0` is the moment the server's rounded clock reaches the cycle's first
  /// second, and the server's `seconds_into` is the whole part.
  double get cyclePosition => ((serverNow.millisecondsSinceEpoch / 1000) + 0.5) % 103;

  /// Lets [duration] of fake time pass, a little at a time so that every timer
  /// and every delayed answer runs in its proper order.
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
