// Unit tests for lib/services/spin2win_round_clock.dart.

import 'package:best_smart_game/models/spin2win_models.dart';
import 'package:best_smart_game/services/spin2win_round_clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  group('the countdown', () {
    test('reads 90 at the start of the round, 5 at second 85 and 00 from second 90', () {
      expect(Spin2WinRoundClock.countdownForSecondsInto(0), 90);
      expect(Spin2WinRoundClock.countdownForSecondsInto(1), 89);
      expect(Spin2WinRoundClock.countdownForSecondsInto(48), 42);
      expect(Spin2WinRoundClock.countdownForSecondsInto(85), kSpin2WinLockCountdown);
      expect(Spin2WinRoundClock.countdownForSecondsInto(88), 2);
      expect(Spin2WinRoundClock.countdownForSecondsInto(89), 1);
      expect(Spin2WinRoundClock.countdownForSecondsInto(90), 0);
      expect(Spin2WinRoundClock.countdownForSecondsInto(91), 0);
      expect(Spin2WinRoundClock.countdownForSecondsInto(99), 0);
    });

    test('the constants are the live server\'s and the user\'s rules', () {
      expect(kSpin2WinCycleSeconds, 100);
      expect(kSpin2WinCountdownStart, 90);
      expect(kSpin2WinLockCountdown, 5);
    });
  });

  group('reading the clock', () {
    test('before the server has answered, the device clock is used as it is', () {
      // 17928120 * 100 + 48 seconds, the moment of the fixture.
      final device = DateTime.fromMillisecondsSinceEpoch((17928120 * 100 + 48) * 1000 + 400, isUtc: true);
      final clock = Spin2WinRoundClock(now: () => device);
      expect(clock.secondsInto, 48);
      expect(clock.roundNumber, 17928120);
      expect(clock.countdown, 42);
    });

    test('a device clock that is fast or slow is corrected from the server\'s answer', () {
      final round = Spin2WinRoundState.fromJson(loadFixtureMap('current_round_betting.json'));
      expect(round.secondsInto, 48);
      final serverSeconds = 17928120 * 100 + 48;
      for (final errorMillis in [0, 400, 2700, -2700, 61000]) {
        var device = DateTime.fromMillisecondsSinceEpoch(serverSeconds * 1000 + errorMillis, isUtc: true);
        final clock = Spin2WinRoundClock(now: () => device);
        clock.calibrate(round);
        expect(clock.secondsInto, 48, reason: 'error $errorMillis ms');
        expect(clock.roundNumber, 17928120);
        device = device.add(const Duration(seconds: 10));
        expect(clock.secondsInto, 58, reason: 'error $errorMillis ms, ten seconds later');
        expect(clock.countdown, 32);
      }
    });

    test('the clock rolls over into the next round', () {
      final round = Spin2WinRoundState.fromJson(loadFixtureMap('current_round_betting.json'));
      var device = DateTime.fromMillisecondsSinceEpoch((17928120 * 100 + 48) * 1000, isUtc: true);
      final clock = Spin2WinRoundClock(now: () => device)..calibrate(round);
      device = device.add(const Duration(seconds: 52)); // second 100 = second 0 of the next round
      expect(clock.secondsInto, 0);
      expect(clock.roundNumber, 17928121);
      expect(clock.countdown, 90);
    });
  });

  group('the lock mark', () {
    bool crossed(int previous, int current) =>
        Spin2WinRoundClock.crossedLockMark(previousCountdown: previous, currentCountdown: current);

    test('fires on the tick that reaches 5', () {
      expect(crossed(6, 5), isTrue);
    });

    test('also fires when a tick skips past 5 (a stalled timer or a re-calibration)', () {
      expect(crossed(7, 4), isTrue);
      expect(crossed(6, 3), isTrue);
      expect(crossed(8, 1), isTrue);
    });

    test('does not fire again below 5, nor while still above it', () {
      expect(crossed(5, 4), isFalse);
      expect(crossed(4, 3), isFalse);
      expect(crossed(90, 89), isFalse);
      expect(crossed(7, 6), isFalse);
    });

    test('does not fire when a re-calibration moves 4 back up to 5', () {
      expect(crossed(4, 5), isFalse);
    });

    test('does not fire for a tick that jumps straight to 00 (nothing is left to send a bet to)', () {
      expect(crossed(6, 0), isFalse);
    });

    test('a countdown pushed back above 5 and brought down again is a fresh approach', () {
      expect(crossed(6, 5), isTrue);
      expect(crossed(5, 7), isFalse);
      expect(crossed(7, 6), isFalse);
      expect(crossed(6, 5), isTrue);
    });
  });

  group('reaching 00', () {
    bool zero(int previous, int current) =>
        Spin2WinRoundClock.crossedZero(previousCountdown: previous, currentCountdown: current);

    test('fires once, on the tick that reaches 00, including a skipped tick', () {
      expect(zero(1, 0), isTrue);
      expect(zero(2, 0), isTrue);
      expect(zero(0, 0), isFalse);
      expect(zero(5, 4), isFalse);
      expect(zero(0, 90), isFalse); // the new round
    });
  });
}
