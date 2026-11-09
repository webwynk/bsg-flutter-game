/// Measures how long the app was in the background, for the "away" rule
/// (20 seconds away means the player is logged out with "YOU WERE AWAY").
///
/// Written 2026-11-09 (docs/loadtest/AWAY_MESSAGE_PLAN_2026-11-09.md): an
/// ordinary Timer can not be trusted for this on a phone. Android's monotonic
/// clock stops while the phone is asleep, and the system can freeze a
/// backgrounded app, so a 20-second timer may fire late or not at all, and
/// coming back cancels it. This takes the LARGER of two measures:
///   * the device's wall clock, which keeps running through sleep (but can be
///     moved by the player or by network time);
///   * a stopwatch, which can not be moved (but may stand still in sleep).
/// Moving the clock back can therefore not hide being away. Moving it forward
/// while away can only make a return count as away early, which logs out a
/// player who did leave the app.
class AwayClock {
  AwayClock({DateTime Function()? now, Stopwatch Function()? stopwatch})
      : _now = now ?? DateTime.now,
        _newStopwatch = stopwatch ?? Stopwatch.new;

  final DateTime Function() _now;
  final Stopwatch Function() _newStopwatch;

  DateTime? _leftAt;
  Stopwatch? _watch;

  /// The app just went to the background.
  void markLeft() {
    _leftAt = _now();
    _watch = _newStopwatch()..start();
  }

  /// How long since [markLeft]; null if the app has not left since the last
  /// [clear].
  Duration? get awayFor {
    final leftAt = _leftAt;
    final watch = _watch;
    if (leftAt == null || watch == null) return null;
    final byClock = _now().difference(leftAt);
    final byWatch = watch.elapsed;
    return byClock > byWatch ? byClock : byWatch;
  }

  /// True if the app left and has been away for [threshold] or more.
  bool awayAtLeast(Duration threshold) {
    final away = awayFor;
    return away != null && away >= threshold;
  }

  /// Forgets the last departure (call on return, after deciding).
  void clear() {
    _leftAt = null;
    _watch?.stop();
    _watch = null;
  }
}
