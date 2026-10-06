// Unit tests for lib/models/lucky_card_models.dart.
//
// Parsing is checked against real answers captured from the live database
// (test/lucky_card/fixtures/).

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  group('the 12 cards', () {
    test('there are exactly 12, all different, in the database column order', () {
      expect(LuckyCard.all.map((c) => c.key).toList(), [
        'j_hearts', 'j_spades', 'j_diamonds', 'j_clubs',
        'q_hearts', 'q_spades', 'q_diamonds', 'q_clubs',
        'k_hearts', 'k_spades', 'k_diamonds', 'k_clubs',
      ]);
      expect(LuckyCard.all.toSet().length, 12);
    });

    test('every key turns back into its own card', () {
      for (final card in LuckyCard.all) {
        expect(LuckyCard.fromKey(card.key), card);
      }
    });

    test('a key that is not one of the 12 is refused, not guessed', () {
      for (final bad in ['x_hearts', 'J_hearts', 'j_Hearts', 'j_heart', '', 'jhearts']) {
        expect(() => LuckyCard.fromKey(bad), throwsFormatException, reason: bad);
      }
    });

    test('ranks and suits parse from the database words and refuse anything else', () {
      expect(LuckyCardRank.fromDb('J'), LuckyCardRank.jack);
      expect(LuckyCardRank.fromDb('Q'), LuckyCardRank.queen);
      expect(LuckyCardRank.fromDb('K'), LuckyCardRank.king);
      expect(LuckyCardSuit.fromDb('hearts'), LuckyCardSuit.hearts);
      expect(LuckyCardSuit.fromDb('clubs'), LuckyCardSuit.clubs);
      for (final bad in ['X', 'j', '']) {
        expect(() => LuckyCardRank.fromDb(bad), throwsFormatException, reason: bad);
      }
      for (final bad in ['Hearts', 'heart', 'spade', '']) {
        expect(() => LuckyCardSuit.fromDb(bad), throwsFormatException, reason: bad);
      }
    });

    test('hearts and diamonds are red, spades and clubs are black', () {
      expect(LuckyCardSuit.values.where((s) => s.isRed), [LuckyCardSuit.hearts, LuckyCardSuit.diamonds]);
      expect(LuckyCardSuit.values.where((s) => !s.isRed), [LuckyCardSuit.spades, LuckyCardSuit.clubs]);
    });

    test('names and symbols for the screen', () {
      const card = LuckyCard(LuckyCardRank.queen, LuckyCardSuit.clubs);
      expect(card.shortName, 'Q♣');
      expect(card.rank.label, 'Queen');
      expect(card.suit.label, 'Clubs');
    });

    test('a card can be used as a map key', () {
      final board = <LuckyCard, int>{
        const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts): 50,
      };
      board[const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts)] = 100;
      expect(board.length, 1);
      expect(board[LuckyCard.fromKey('j_hearts')], 100);
    });
  });

  group('the bonus text', () {
    test('1 (or less) is N, everything else is 2X to 10X in capitals', () {
      expect(luckyCardBonusLabel(1), 'N');
      expect(luckyCardBonusLabel(0), 'N');
      expect(luckyCardBonusLabel(2), '2X');
      expect(luckyCardBonusLabel(7), '7X');
      expect(luckyCardBonusLabel(10), '10X');
    });
  });

  group('failure reasons', () {
    test('only offline, unauthenticated and unknown are worth a retry', () {
      expect(
        LuckyCardError.values.where((e) => e.isRetryable).toSet(),
        {LuckyCardError.offline, LuckyCardError.unauthenticated, LuckyCardError.unknown},
      );
    });
  });

  group('a round, from the real database answers', () {
    test('while betting is open the winning card and the bonus are hidden', () {
      final round = LuckyCardRoundState.fromJson(loadFixtureMap('current_round_betting.json'));
      expect(round.phase, 'betting');
      expect(round.winningCard, isNull);
      expect(round.bonusMultiplier, isNull);
      expect(round.isDrawn, isFalse);
      expect(round.drawAtSecond, 89);
      expect(round.secondsInto, 48);
      expect(round.secondsRemaining, 55);
      expect(round.acceptsBets, isTrue);
      expect(round.scheduledAt.isUtc, isTrue);
    });

    test('once drawn the card and the bonus arrive together', () {
      final round = LuckyCardRoundState.fromJson(loadFixtureMap('current_round_drawn.json'));
      expect(round.isDrawn, isTrue);
      expect(round.winningCard, const LuckyCard(LuckyCardRank.queen, LuckyCardSuit.clubs));
      expect(round.bonusMultiplier, 3);
      expect(round.phase, 'settled');
      // Drawn means betting is over, even though the clock says second 48.
      expect(round.acceptsBets, isFalse);
    });

    test('not drawn but at or past the draw second also means no more bets', () {
      final json = loadFixtureMap('current_round_betting.json')..['seconds_into'] = 89;
      expect(LuckyCardRoundState.fromJson(json).acceptsBets, isFalse);
      json['seconds_into'] = 88;
      expect(LuckyCardRoundState.fromJson(json).acceptsBets, isTrue);
    });

    test('an answer with only a rank or only a suit is refused', () {
      final onlyRank = loadFixtureMap('current_round_drawn.json')..['winning_suit'] = null;
      final onlySuit = loadFixtureMap('current_round_drawn.json')..['winning_rank'] = null;
      expect(() => LuckyCardRoundState.fromJson(onlyRank), throwsFormatException);
      expect(() => LuckyCardRoundState.fromJson(onlySuit), throwsFormatException);
    });

    test('an unknown rank or suit is refused instead of becoming a wrong card', () {
      final badRank = loadFixtureMap('current_round_drawn.json')..['winning_rank'] = 'A';
      final badSuit = loadFixtureMap('current_round_drawn.json')..['winning_suit'] = 'stars';
      expect(() => LuckyCardRoundState.fromJson(badRank), throwsFormatException);
      expect(() => LuckyCardRoundState.fromJson(badSuit), throwsFormatException);
    });

    test('a missing required field is refused', () {
      final json = loadFixtureMap('current_round_betting.json')..remove('round_id');
      expect(() => LuckyCardRoundState.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  group('a bet and a player\'s result, from the real database answers', () {
    test('a placed bet', () {
      final r = LuckyCardPlaceBetResult.fromJson(loadFixtureMap('place_bet_success.json'));
      expect(r.success, isTrue);
      expect(r.totalStake, 120);
      expect(r.coinBalance, 67322);
      expect(r.ledgerVersion, 1460);
      expect(r.error, isNull);
    });

    test('a failure carries only its reason', () {
      const r = LuckyCardPlaceBetResult.failure(LuckyCardError.roundClosed);
      expect(r.success, isFalse);
      expect(r.error, LuckyCardError.roundClosed);
      expect(r.totalStake, 0);
    });

    test('no bet on the round', () {
      final r = LuckyCardMyResult.fromJson(loadFixtureMap('my_result_no_bet.json'));
      expect(r.placedBet, isFalse);
      expect(r.totalStake, 0);
      expect(r.totalPayout, 0);
      expect(r.isSettled, isFalse);
      expect(r.coinBalance, 67442);
    });

    test('a bet placed but not yet settled', () {
      final r = LuckyCardMyResult.fromJson(loadFixtureMap('my_result_unsettled.json'));
      expect(r.placedBet, isTrue);
      expect(r.totalStake, 120);
      expect(r.totalPayout, 0);
      expect(r.isSettled, isFalse);
    });

    test('a settled winner: 10 on every card at 3X paid 10 x 10 x 3', () {
      final r = LuckyCardMyResult.fromJson(loadFixtureMap('my_result_settled_win.json'));
      expect(r.placedBet, isTrue);
      expect(r.isSettled, isTrue);
      expect(r.totalStake, 120);
      expect(r.totalPayout, 300);
      expect(r.coinBalance, 67622);
    });

    test('missing fields fall back to a safe "no bet", never a crash', () {
      final r = LuckyCardMyResult.fromJson(<String, dynamic>{});
      expect(r.placedBet, isFalse);
      expect(r.totalStake, 0);
      expect(r.isSettled, isFalse);
    });
  });

  group('the history list, from the real database answer', () {
    test('three rounds, newest first, each with its card and its bonus', () {
      final list = (loadFixture('recent_rounds.json') as List)
          .map((e) => LuckyCardRecentRound.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      expect(list.length, 3);
      expect(list[0].roundNumber > list[1].roundNumber && list[1].roundNumber > list[2].roundNumber, isTrue);
      expect(list.map((r) => r.bonusMultiplier).toList(), [10, 3, 1]);
      expect(list[0].winningCard, const LuckyCard(LuckyCardRank.king, LuckyCardSuit.clubs));
      expect(list[1].winningCard, const LuckyCard(LuckyCardRank.queen, LuckyCardSuit.diamonds));
      expect(list[2].winningCard, const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.spades));
      expect(luckyCardBonusLabel(list[0].bonusMultiplier), '10X');
      expect(luckyCardBonusLabel(list[2].bonusMultiplier), 'N');
    });
  });
}
