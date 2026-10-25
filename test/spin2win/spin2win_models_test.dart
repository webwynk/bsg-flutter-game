// Unit tests for lib/models/spin2win_models.dart.
//
// Parsing is checked against answers shaped as the live Spin2Win functions
// build them (test/spin2win/fixtures/).

import 'package:best_smart_game/models/spin2win_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  group('the ten numbers', () {
    test('0 to 9, in the database column order n0 to n9', () {
      expect(kSpin2WinNumbers, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(kSpin2WinNumbers.map(spin2WinKey).toList(),
          ['n0', 'n1', 'n2', 'n3', 'n4', 'n5', 'n6', 'n7', 'n8', 'n9']);
    });

    test('ODD is 1 3 5 7 9 and EVEN is 0 2 4 6 8 (0 counts as even)', () {
      expect(kSpin2WinOddNumbers, [1, 3, 5, 7, 9]);
      expect(kSpin2WinEvenNumbers, [0, 2, 4, 6, 8]);
      expect({...kSpin2WinOddNumbers, ...kSpin2WinEvenNumbers}.length, 10);
    });

    test('a number outside 0 to 9 has no key', () {
      for (final bad in [-1, 10, 99]) {
        expect(() => spin2WinKey(bad), throwsArgumentError, reason: '$bad');
        expect(isSpin2WinNumber(bad), isFalse);
      }
    });

    test('a winning number from the database is refused unless it is 0 to 9', () {
      expect(spin2WinNumberFromDb(0), 0);
      expect(spin2WinNumberFromDb(9), 9);
      for (final bad in [10, -1, 3.5, '3', null]) {
        expect(() => spin2WinNumberFromDb(bad), throwsFormatException, reason: '$bad');
      }
    });
  });

  group('the payout rule', () {
    test('the user\'s example: 5 on the winner pays 45 / 90 / 135 / 180', () {
      expect(spin2WinPayout(5, 1), 45);
      expect(spin2WinPayout(5, 2), 90);
      expect(spin2WinPayout(5, 3), 135);
      expect(spin2WinPayout(5, 4), 180);
    });

    test('a bet of 10 that wins with N pays 90', () {
      expect(spin2WinPayout(10, 1), 90);
    });
  });

  group('the bonus text', () {
    test('1 (or less) is N, everything else is 2X to 4X in capitals', () {
      expect(spin2WinBonusLabel(1), 'N');
      expect(spin2WinBonusLabel(0), 'N');
      expect(spin2WinBonusLabel(2), '2X');
      expect(spin2WinBonusLabel(3), '3X');
      expect(spin2WinBonusLabel(4), '4X');
    });
  });

  group('failure reasons', () {
    test('only offline, unauthenticated and unknown are worth a retry', () {
      expect(
        Spin2WinError.values.where((e) => e.isRetryable).toSet(),
        {Spin2WinError.offline, Spin2WinError.unauthenticated, Spin2WinError.unknown},
      );
    });
  });

  group('a round, from the database answers', () {
    test('while betting is open the winning number and the bonus are hidden', () {
      final round = Spin2WinRoundState.fromJson(loadFixtureMap('current_round_betting.json'));
      expect(round.phase, 'betting');
      expect(round.winningNumber, isNull);
      expect(round.bonusMultiplier, isNull);
      expect(round.isDrawn, isFalse);
      expect(round.drawAtSecond, 90);
      expect(round.secondsInto, 48);
      expect(round.secondsRemaining, 52);
      expect(round.acceptsBets, isTrue);
      expect(round.scheduledAt.isUtc, isTrue);
    });

    test('once drawn the number and the bonus arrive together', () {
      final round = Spin2WinRoundState.fromJson(loadFixtureMap('current_round_drawn.json'));
      expect(round.isDrawn, isTrue);
      expect(round.winningNumber, 7);
      expect(round.bonusMultiplier, 3);
      expect(round.phase, 'settled');
      expect(round.acceptsBets, isFalse);
    });

    test('drawn means no more bets, whatever the clock says', () {
      final json = loadFixtureMap('current_round_drawn.json')..['seconds_into'] = 10;
      expect(Spin2WinRoundState.fromJson(json).acceptsBets, isFalse);
    });

    test('not drawn but at or past the draw second also means no more bets', () {
      final json = loadFixtureMap('current_round_betting.json')..['seconds_into'] = 90;
      expect(Spin2WinRoundState.fromJson(json).acceptsBets, isFalse);
      json['seconds_into'] = 89;
      expect(Spin2WinRoundState.fromJson(json).acceptsBets, isTrue);
    });

    test('a winning number outside 0 to 9 is refused instead of becoming a wrong result', () {
      final bad = loadFixtureMap('current_round_drawn.json')..['winning_number'] = 10;
      expect(() => Spin2WinRoundState.fromJson(bad), throwsFormatException);
    });

    test('a missing required field is refused', () {
      final json = loadFixtureMap('current_round_betting.json')..remove('round_id');
      expect(() => Spin2WinRoundState.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  group('a bet and a player\'s result, from the database answers', () {
    test('a placed bet', () {
      final r = Spin2WinPlaceBetResult.fromJson(loadFixtureMap('place_bet_success.json'));
      expect(r.success, isTrue);
      expect(r.totalStake, 100);
      expect(r.coinBalance, 67322);
      expect(r.ledgerVersion, 1460);
      expect(r.error, isNull);
    });

    test('a failure carries only its reason', () {
      const r = Spin2WinPlaceBetResult.failure(Spin2WinError.roundClosed);
      expect(r.success, isFalse);
      expect(r.error, Spin2WinError.roundClosed);
      expect(r.totalStake, 0);
    });

    test('no bet on the round', () {
      final r = Spin2WinMyResult.fromJson(loadFixtureMap('my_result_no_bet.json'));
      expect(r.placedBet, isFalse);
      expect(r.totalStake, 0);
      expect(r.totalPayout, 0);
      expect(r.isSettled, isFalse);
      expect(r.coinBalance, 67442);
    });

    test('a bet placed but not yet settled', () {
      final r = Spin2WinMyResult.fromJson(loadFixtureMap('my_result_unsettled.json'));
      expect(r.placedBet, isTrue);
      expect(r.totalStake, 100);
      expect(r.totalPayout, 0);
      expect(r.isSettled, isFalse);
    });

    test('a settled winner: 10 on every number at 3X paid 10 x 9 x 3', () {
      final r = Spin2WinMyResult.fromJson(loadFixtureMap('my_result_settled_win.json'));
      expect(r.placedBet, isTrue);
      expect(r.isSettled, isTrue);
      expect(r.totalStake, 100);
      expect(r.totalPayout, 270);
      expect(r.totalPayout, spin2WinPayout(10, 3));
      expect(r.coinBalance, 67592);
    });

    test('missing fields fall back to a safe "no bet", never a crash', () {
      final r = Spin2WinMyResult.fromJson(<String, dynamic>{});
      expect(r.placedBet, isFalse);
      expect(r.totalStake, 0);
      expect(r.isSettled, isFalse);
    });
  });

  group('the history strip, from the database answer', () {
    test('three rounds, newest first, each with its number and its bonus', () {
      final list = (loadFixture('recent_rounds.json') as List)
          .map((e) => Spin2WinRecentRound.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      expect(list.length, 3);
      expect(list[0].roundNumber > list[1].roundNumber && list[1].roundNumber > list[2].roundNumber, isTrue);
      expect(list.map((r) => r.winningNumber).toList(), [0, 9, 4]);
      expect(list.map((r) => r.bonusMultiplier).toList(), [4, 2, 1]);
      expect(spin2WinBonusLabel(list[0].bonusMultiplier), '4X');
      expect(spin2WinBonusLabel(list[2].bonusMultiplier), 'N');
    });
  });

  group('a round\'s result', () {
    test('built from a drawn round, and refused for one that is not drawn', () {
      final drawn = Spin2WinRoundState.fromJson(loadFixtureMap('current_round_drawn.json'));
      final r = Spin2WinRoundResult.fromRound(drawn, isCatchUpReplay: false);
      expect(r.winningNumber, 7);
      expect(r.bonusMultiplier, 3);
      final open = Spin2WinRoundState.fromJson(loadFixtureMap('current_round_betting.json'));
      expect(() => Spin2WinRoundResult.fromRound(open, isCatchUpReplay: false), throwsStateError);
    });
  });
}
