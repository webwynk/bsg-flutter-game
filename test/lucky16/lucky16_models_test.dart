// Unit tests for lib/models/lucky16_models.dart.
//
// Copied from test/lucky_card/lucky_card_models_test.dart and changed for 16
// cards (the A rank), 14x and the 10,000 maximum. Parsing is checked against
// the fixtures in test/lucky16/fixtures/, adapted from Lucky Card's live
// captures (see fixtures/README.md).

import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  group('the 16 cards', () {
    test('there are exactly 16, all different, in the database column order', () {
      expect(Lucky16Card.all.map((c) => c.key).toList(), [
        'a_hearts', 'a_spades', 'a_diamonds', 'a_clubs',
        'j_hearts', 'j_spades', 'j_diamonds', 'j_clubs',
        'q_hearts', 'q_spades', 'q_diamonds', 'q_clubs',
        'k_hearts', 'k_spades', 'k_diamonds', 'k_clubs',
      ]);
      expect(Lucky16Card.all.toSet().length, 16);
    });

    test('the ranks run A, J, Q, K, top to bottom of the grid', () {
      expect(Lucky16Rank.values, [Lucky16Rank.ace, Lucky16Rank.jack, Lucky16Rank.queen, Lucky16Rank.king]);
      expect(Lucky16Rank.values.map((r) => r.dbValue).toList(), ['A', 'J', 'Q', 'K']);
      expect(Lucky16Rank.ace.label, 'Ace');
    });

    test('every suit has 4 cards, in rank order A, J, Q, K', () {
      for (final suit in Lucky16Suit.values) {
        final cards = Lucky16Card.ofSuit(suit);
        expect(cards.length, 4, reason: suit.name);
        expect(cards.map((c) => c.rank).toList(), Lucky16Rank.values, reason: suit.name);
        expect(cards.every((c) => c.suit == suit), isTrue);
      }
      expect(Lucky16Card.ofSuit(Lucky16Suit.spades).map((c) => c.key).toList(),
          ['a_spades', 'j_spades', 'q_spades', 'k_spades']);
    });

    test('every rank has 4 cards, in suit order hearts, spades, diamonds, clubs', () {
      for (final rank in Lucky16Rank.values) {
        final cards = Lucky16Card.ofRank(rank);
        expect(cards.length, 4, reason: rank.name);
        expect(cards.map((c) => c.suit).toList(), Lucky16Suit.values, reason: rank.name);
      }
      expect(Lucky16Card.ofRank(Lucky16Rank.ace).map((c) => c.key).toList(),
          ['a_hearts', 'a_spades', 'a_diamonds', 'a_clubs']);
    });

    test('an ace has an a_ key and an A short name', () {
      const ace = Lucky16Card(Lucky16Rank.ace, Lucky16Suit.diamonds);
      expect(ace.key, 'a_diamonds');
      expect(ace.shortName, 'A♦');
      expect(Lucky16Card.fromKey('a_diamonds'), ace);
    });

    test('every key turns back into its own card', () {
      for (final card in Lucky16Card.all) {
        expect(Lucky16Card.fromKey(card.key), card);
      }
    });

    test('a key that is not one of the 16 is refused, not guessed', () {
      for (final bad in ['x_hearts', 'J_hearts', 'A_hearts', 'j_Hearts', 'j_heart', '', 'jhearts', 'ace_hearts']) {
        expect(() => Lucky16Card.fromKey(bad), throwsFormatException, reason: bad);
      }
    });

    test('ranks and suits parse from the database words and refuse anything else', () {
      expect(Lucky16Rank.fromDb('A'), Lucky16Rank.ace);
      expect(Lucky16Rank.fromDb('J'), Lucky16Rank.jack);
      expect(Lucky16Rank.fromDb('Q'), Lucky16Rank.queen);
      expect(Lucky16Rank.fromDb('K'), Lucky16Rank.king);
      expect(Lucky16Suit.fromDb('hearts'), Lucky16Suit.hearts);
      expect(Lucky16Suit.fromDb('clubs'), Lucky16Suit.clubs);
      for (final bad in ['X', 'j', 'a', '1', '']) {
        expect(() => Lucky16Rank.fromDb(bad), throwsFormatException, reason: bad);
      }
      for (final bad in ['Hearts', 'heart', 'spade', '']) {
        expect(() => Lucky16Suit.fromDb(bad), throwsFormatException, reason: bad);
      }
    });

    test('hearts and diamonds are red, spades and clubs are black', () {
      expect(Lucky16Suit.values.where((s) => s.isRed), [Lucky16Suit.hearts, Lucky16Suit.diamonds]);
      expect(Lucky16Suit.values.where((s) => !s.isRed), [Lucky16Suit.spades, Lucky16Suit.clubs]);
    });

    test('names and symbols for the screen', () {
      const card = Lucky16Card(Lucky16Rank.queen, Lucky16Suit.clubs);
      expect(card.shortName, 'Q♣');
      expect(card.rank.label, 'Queen');
      expect(card.suit.label, 'Clubs');
    });

    test('a card can be used as a map key', () {
      final board = <Lucky16Card, int>{
        const Lucky16Card(Lucky16Rank.jack, Lucky16Suit.hearts): 50,
      };
      board[const Lucky16Card(Lucky16Rank.jack, Lucky16Suit.hearts)] = 100;
      expect(board.length, 1);
      expect(board[Lucky16Card.fromKey('j_hearts')], 100);
    });
  });

  group('the bonus text', () {
    test('1 (or less) is N, everything else is 2X to 10X in capitals', () {
      expect(lucky16BonusLabel(1), 'N');
      expect(lucky16BonusLabel(0), 'N');
      expect(lucky16BonusLabel(2), '2X');
      expect(lucky16BonusLabel(7), '7X');
      expect(lucky16BonusLabel(10), '10X');
    });
  });

  group('failure reasons', () {
    test('only offline, unauthenticated and unknown are worth a retry', () {
      expect(
        Lucky16Error.values.where((e) => e.isRetryable).toSet(),
        {Lucky16Error.offline, Lucky16Error.unauthenticated, Lucky16Error.unknown},
      );
    });
  });

  group('a round, from the adapted database answers', () {
    test('while betting is open the winning card and the bonus are hidden', () {
      final round = Lucky16RoundState.fromJson(loadFixtureMap('current_round_betting.json'));
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

    test('once drawn the card (here an ace) and the bonus arrive together', () {
      final round = Lucky16RoundState.fromJson(loadFixtureMap('current_round_drawn.json'));
      expect(round.isDrawn, isTrue);
      expect(round.winningCard, const Lucky16Card(Lucky16Rank.ace, Lucky16Suit.hearts));
      expect(round.bonusMultiplier, 3);
      expect(round.phase, 'settled');
      // Drawn means betting is over, even though the clock says second 48.
      expect(round.acceptsBets, isFalse);
    });

    test('not drawn but at or past the draw second also means no more bets', () {
      final json = loadFixtureMap('current_round_betting.json')..['seconds_into'] = 89;
      expect(Lucky16RoundState.fromJson(json).acceptsBets, isFalse);
      json['seconds_into'] = 88;
      expect(Lucky16RoundState.fromJson(json).acceptsBets, isTrue);
    });

    test('an answer with only a rank or only a suit is refused', () {
      final onlyRank = loadFixtureMap('current_round_drawn.json')..['winning_suit'] = null;
      final onlySuit = loadFixtureMap('current_round_drawn.json')..['winning_rank'] = null;
      expect(() => Lucky16RoundState.fromJson(onlyRank), throwsFormatException);
      expect(() => Lucky16RoundState.fromJson(onlySuit), throwsFormatException);
    });

    test('an unknown rank or suit is refused instead of becoming a wrong card', () {
      final badRank = loadFixtureMap('current_round_drawn.json')..['winning_rank'] = 'X';
      final badSuit = loadFixtureMap('current_round_drawn.json')..['winning_suit'] = 'stars';
      expect(() => Lucky16RoundState.fromJson(badRank), throwsFormatException);
      expect(() => Lucky16RoundState.fromJson(badSuit), throwsFormatException);
    });

    test('a missing required field is refused', () {
      final json = loadFixtureMap('current_round_betting.json')..remove('round_id');
      expect(() => Lucky16RoundState.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  group('a bet and a player\'s result, from the adapted database answers', () {
    test('a placed bet', () {
      final r = Lucky16PlaceBetResult.fromJson(loadFixtureMap('place_bet_success.json'));
      expect(r.success, isTrue);
      expect(r.totalStake, 160);
      expect(r.coinBalance, 67282);
      expect(r.ledgerVersion, 1460);
      expect(r.error, isNull);
    });

    test('a failure carries only its reason', () {
      const r = Lucky16PlaceBetResult.failure(Lucky16Error.roundClosed);
      expect(r.success, isFalse);
      expect(r.error, Lucky16Error.roundClosed);
      expect(r.totalStake, 0);
    });

    test('no bet on the round', () {
      final r = Lucky16MyResult.fromJson(loadFixtureMap('my_result_no_bet.json'));
      expect(r.placedBet, isFalse);
      expect(r.totalStake, 0);
      expect(r.totalPayout, 0);
      expect(r.isSettled, isFalse);
      expect(r.coinBalance, 67442);
    });

    test('a bet placed but not yet settled', () {
      final r = Lucky16MyResult.fromJson(loadFixtureMap('my_result_unsettled.json'));
      expect(r.placedBet, isTrue);
      expect(r.totalStake, 160);
      expect(r.totalPayout, 0);
      expect(r.isSettled, isFalse);
    });

    test('a settled winner: 10 on every one of the 16 cards at 3X paid 10 x 14 x 3', () {
      final r = Lucky16MyResult.fromJson(loadFixtureMap('my_result_settled_win.json'));
      expect(r.placedBet, isTrue);
      expect(r.isSettled, isTrue);
      expect(r.totalStake, 160);
      expect(r.totalPayout, 420);
      expect(r.coinBalance, 67702);
    });

    test('missing fields fall back to a safe "no bet", never a crash', () {
      final r = Lucky16MyResult.fromJson(<String, dynamic>{});
      expect(r.placedBet, isFalse);
      expect(r.totalStake, 0);
      expect(r.isSettled, isFalse);
    });
  });

  group('the history list, from the adapted database answer', () {
    test('three rounds, newest first, each with its card and its bonus', () {
      final list = (loadFixture('recent_rounds.json') as List)
          .map((e) => Lucky16RecentRound.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      expect(list.length, 3);
      expect(list[0].roundNumber > list[1].roundNumber && list[1].roundNumber > list[2].roundNumber, isTrue);
      expect(list.map((r) => r.bonusMultiplier).toList(), [10, 3, 1]);
      expect(list[0].winningCard, const Lucky16Card(Lucky16Rank.king, Lucky16Suit.clubs));
      expect(list[1].winningCard, const Lucky16Card(Lucky16Rank.ace, Lucky16Suit.diamonds));
      expect(list[2].winningCard, const Lucky16Card(Lucky16Rank.jack, Lucky16Suit.spades));
      expect(lucky16BonusLabel(list[0].bonusMultiplier), '10X');
      expect(lucky16BonusLabel(list[2].bonusMultiplier), 'N');
    });
  });
}
