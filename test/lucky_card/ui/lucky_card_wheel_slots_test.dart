// Tests for lib/widgets/lucky_card/lucky_card_wheel_slots.dart: which segments of
// the two rims the wheel stops on for a card, the same on every phone.

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel_slots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the rims', () {
    test('the outer rim reads J K Q and the inner rim diamonds, clubs, hearts, spades (spec Q46)', () {
      expect(kLuckyCardWheelRanks, ['J', 'K', 'Q']);
      expect(kLuckyCardWheelSuits, [LuckyCardSuit.diamonds, LuckyCardSuit.clubs, LuckyCardSuit.hearts, LuckyCardSuit.spades]);
      expect(kLuckyCardWheelSegments, 12);
    });

    test('every rank has four segments and every suit three, so no card is left out', () {
      for (final rank in LuckyCardRank.values) {
        final n = [for (var i = 0; i < 12; i++) if (kLuckyCardWheelRanks[i % 3] == rank.dbValue) i].length;
        expect(n, 4, reason: rank.dbValue);
      }
      for (final suit in LuckyCardSuit.values) {
        final n = [for (var i = 0; i < 12; i++) if (kLuckyCardWheelSuits[i % 4] == suit) i].length;
        expect(n, 3, reason: suit.dbValue);
      }
    });
  });

  group('the segments for a card', () {
    test('for every card and every round the two segments under the pointer spell exactly that card', () {
      for (final card in LuckyCard.all) {
        for (var round = 0; round < 60; round++) {
          final stop = luckyCardWheelStopFor(card, round);
          expect(stop.outerIndex, inInclusiveRange(0, 11), reason: '${card.key} round $round');
          expect(stop.innerIndex, inInclusiveRange(0, 11), reason: '${card.key} round $round');
          expect(kLuckyCardWheelRanks[stop.outerIndex % 3], card.rank.dbValue, reason: '${card.key} round $round: the rank letter');
          expect(kLuckyCardWheelSuits[stop.innerIndex % 4], card.suit, reason: '${card.key} round $round: the suit');
          expect(luckyCardAtWheelStop(stop.outerIndex, stop.innerIndex), card, reason: '${card.key} round $round');
        }
      }
    });

    test('the same card and round always give the same segments (the same on every phone)', () {
      for (final card in LuckyCard.all) {
        for (final round in [0, 1, 7, 12, 17390003]) {
          expect(luckyCardWheelStopFor(card, round), luckyCardWheelStopFor(card, round));
        }
      }
    });

    test('over 12 rounds a card uses all four outer segments and all three inner ones, in 12 different pairs', () {
      for (final card in LuckyCard.all) {
        final stops = [for (var r = 5000; r < 5012; r++) luckyCardWheelStopFor(card, r)];
        expect({for (final s in stops) s.outerIndex}.length, 4, reason: '${card.key} outer');
        expect({for (final s in stops) s.innerIndex}.length, 3, reason: '${card.key} inner');
        expect(stops.toSet().length, 12, reason: '${card.key} pairs');
      }
    });

    test('the outer segment changes every round', () {
      final card = LuckyCard.all.first;
      for (var r = 100; r < 140; r++) {
        expect(luckyCardWheelStopFor(card, r).outerIndex, isNot(luckyCardWheelStopFor(card, r + 1).outerIndex), reason: 'round $r');
      }
    });

    test('worked examples', () {
      const jackDiamonds = LuckyCard(LuckyCardRank.jack, LuckyCardSuit.diamonds);
      expect(luckyCardWheelStopFor(jackDiamonds, 0), const LuckyCardWheelStop(0, 0));
      expect(luckyCardWheelStopFor(jackDiamonds, 1), const LuckyCardWheelStop(3, 0));
      expect(luckyCardWheelStopFor(jackDiamonds, 4), const LuckyCardWheelStop(0, 4));
      const queenSpades = LuckyCard(LuckyCardRank.queen, LuckyCardSuit.spades);
      expect(luckyCardWheelStopFor(queenSpades, 5), const LuckyCardWheelStop(5, 7));
      const kingHearts = LuckyCard(LuckyCardRank.king, LuckyCardSuit.hearts);
      expect(luckyCardWheelStopFor(kingHearts, 0), const LuckyCardWheelStop(1, 2));
      expect(luckyCardWheelStopFor(kingHearts, 11), const LuckyCardWheelStop(10, 10));
    });

    test('a large or negative round number does not break it', () {
      for (final card in LuckyCard.all) {
        for (final round in [-1, -13, 1 << 40]) {
          final stop = luckyCardWheelStopFor(card, round);
          expect(luckyCardAtWheelStop(stop.outerIndex, stop.innerIndex), card, reason: '${card.key} round $round');
        }
      }
    });
  });

  group('the stop value', () {
    test('equal stops are equal', () {
      expect(const LuckyCardWheelStop(3, 5), const LuckyCardWheelStop(3, 5));
      expect(const LuckyCardWheelStop(3, 5).hashCode, const LuckyCardWheelStop(3, 5).hashCode);
      expect(const LuckyCardWheelStop(3, 5), isNot(const LuckyCardWheelStop(3, 6)));
      expect(const LuckyCardWheelStop(3, 5), isNot(const LuckyCardWheelStop(4, 5)));
    });
  });
}
