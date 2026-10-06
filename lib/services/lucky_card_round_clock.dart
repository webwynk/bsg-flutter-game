// The round clock: where in the 103-second cycle the server is right now, as
// far as this device can tell, and what the player's countdown reads.
//
// Pure arithmetic, no timers and no network. The rules are the server's, and
// were measured against the live database on 2026-10-06 (spec §17F):
//   * a cycle is 103 seconds;
//   * `seconds_into = round(now()) mod 103` (the server rounds its clock to the
//     nearest whole second) and `seconds_remaining = 103 - seconds_into`;
//   * the player's countdown reads 90 at second 0 and 00 from second 90 until
//     the cycle ends, which is `90 - seconds_into`, never below 0.
// The device cannot read the server's clock, so every answer from the server
// is used to calibrate an offset (the same method as Triple Chance). Whole
// seconds only, so the countdown can differ from the server's own by one
// second; that is why the server, not the app, decides what is accepted.
//
// Belongs to Lucky Card only; nothing here is shared with Triple Chance.

import '../models/lucky_card_models.dart';

/// Seconds in one round, from the first bet to the next round's first bet.
const int kLuckyCardCycleSeconds = 103;

/// The countdown reads this at second 0 of the cycle.
const int kLuckyCardCountdownStart = 90;

/// The board locks and the bet is sent when the countdown reaches this.
const int kLuckyCardLockCountdown = 5;

class LuckyCardRoundClock {
  /// [now] is the device's clock; tests pass a controllable one.
  LuckyCardRoundClock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Whole seconds to add to the device's clock to get the server's rounded
  /// clock. Zero until the first answer from the server arrives.
  int _offsetSeconds = 0;

  /// The device's own whole seconds (UTC).
  int get localNowSeconds => _now().toUtc().millisecondsSinceEpoch ~/ 1000;

  /// The server's rounded clock as far as this device can tell.
  int get syncedNowSeconds => localNowSeconds + _offsetSeconds;

  /// Seconds since this round began, 0 to 102.
  int get secondsInto => syncedNowSeconds % kLuckyCardCycleSeconds;

  /// The number of the round the server is in, as the server numbers it
  /// (`round(now()) ~/ 103`).
  int get roundNumber => syncedNowSeconds ~/ kLuckyCardCycleSeconds;

  /// What the player's countdown reads: 90 down to 0.
  int get countdown => countdownForSecondsInto(secondsInto);

  /// The countdown for a given second of the cycle. 90 at second 0, 5 at second
  /// 85, 0 from second 90 on.
  static int countdownForSecondsInto(int secondsInto) {
    final remaining = kLuckyCardCountdownStart - secondsInto;
    return remaining < 0 ? 0 : remaining;
  }

  /// Learns the offset from an answer the server just gave: its own clock is
  /// `scheduled_at - seconds_remaining`.
  void calibrate(LuckyCardRoundState round) {
    final serverNowSeconds =
        round.scheduledAt.toUtc().millisecondsSinceEpoch ~/ 1000 -
            round.secondsRemaining;
    _offsetSeconds = serverNowSeconds - localNowSeconds;
  }

  /// True on the one tick where the countdown has just reached or passed the
  /// lock mark: it was above 5 and is now 5 or below, but not yet 0 (a tick that
  /// jumps clean through to 0 leaves nothing to send a bet to).
  ///
  /// "Reached or passed", not "landed exactly on 5": the countdown is re-read
  /// from the clock on every tick, so a stalled tick or a re-calibration can
  /// skip a value (7 to 4, 6 to 3), and an exact test would silently never fire.
  /// This is the lesson of Triple Chance's Issue #111. It does not fire for 5 to
  /// 4, nor when a re-calibration moves 4 back to 5; if the countdown is pushed
  /// back above 5 and comes down again, that is a fresh approach and fires again.
  static bool crossedLockMark({
    required int previousCountdown,
    required int currentCountdown,
  }) =>
      currentCountdown <= kLuckyCardLockCountdown &&
      currentCountdown > 0 &&
      previousCountdown > kLuckyCardLockCountdown;

  /// True on the tick where the countdown has just reached 00.
  static bool crossedZero({
    required int previousCountdown,
    required int currentCountdown,
  }) =>
      previousCountdown > 0 && currentCountdown == 0;
}
