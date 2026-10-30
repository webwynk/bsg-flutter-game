// Tests for where the Lucky 16 Card wheel stops (lib/widgets/lucky16/lucky16_wheel_slots.dart) and for
// the reveal card's shuffle plan (lib/widgets/lucky16/lucky16_reveal_plan.dart): pure arithmetic.

import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_reveal_plan.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_wheel.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_wheel_slots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the rims', () {
    test('the outer rim reads A J K Q three times round (Hasan\'s order); each rank has 3 segments', () {
      expect(kLucky16WheelRanks, ['A', 'J', 'K', 'Q']);
      final letters = [
        for (var i = 0; i < kLucky16WheelSegments; i++) kLucky16WheelRanks[i % kLucky16WheelRanks.length]
      ];
      expect(letters.join(), 'AJKQAJKQAJKQ');
      for (final rank in Lucky16Rank.values) {
        expect(letters.where((l) => l == rank.dbValue).length, 3, reason: rank.dbValue);
      }
    });

    test('the inner rim is Lucky Card\'s: diamonds, clubs, hearts, spades three times round', () {
      expect(kLucky16WheelSuits, [Lucky16Suit.diamonds, Lucky16Suit.clubs, Lucky16Suit.hearts, Lucky16Suit.spades]);
      expect(kLucky16WheelSegments, 12);
    });
  });

  group('where the wheel stops', () {
    test('for every one of the 16 cards, in any round, the two segments spell that card', () {
      for (final card in Lucky16Card.all) {
        for (var round = 17390000; round < 17390040; round++) {
          final stop = lucky16WheelStopFor(card, round);
          expect(stop.outerIndex, inInclusiveRange(0, 11));
          expect(stop.innerIndex, inInclusiveRange(0, 11));
          expect(lucky16CardAtWheelStop(stop.outerIndex, stop.innerIndex), card, reason: '${card.key} round $round');
        }
      }
    });

    test('the same card in the same round always stops in the same place (every phone sees the same wheel)', () {
      for (final card in Lucky16Card.all) {
        expect(lucky16WheelStopFor(card, 17390003), lucky16WheelStopFor(card, 17390003));
      }
    });

    test('over nine rounds in a row a card uses each of its 3 outer and 3 inner segments, all 9 pairs once', () {
      for (final card in Lucky16Card.all) {
        final stops = {for (var round = 900; round < 909; round++) lucky16WheelStopFor(card, round)};
        expect(stops.length, 9, reason: card.key);
        expect(stops.map((s) => s.outerIndex).toSet().length, 3);
        expect(stops.map((s) => s.innerIndex).toSet().length, 3);
      }
    });

    test('the example round: A of spades in round 17390003 stops on an A and a spade', () {
      const aceSpades = Lucky16Card(Lucky16Rank.ace, Lucky16Suit.spades);
      final stop = lucky16WheelStopFor(aceSpades, 17390003);
      expect(kLucky16WheelRanks[stop.outerIndex % 4], 'A');
      expect(kLucky16WheelSuits[stop.innerIndex % 4], Lucky16Suit.spades);
    });
  });

  test('the hub writes every bonus as Lucky Card does: N, then 2X to 10X', () {
    expect([for (var b = 1; b <= 10; b++) lucky16WheelBonusLabel(b)],
        ['N', '2X', '3X', '4X', '5X', '6X', '7X', '8X', '9X', '10X']);
  });

  group('the reveal card\'s shuffle', () {
    test('for every card and many rounds: 11 different faces, the winner never the last one shown', () {
      for (final winner in Lucky16Card.all) {
        for (var round = 1; round < 60; round++) {
          final plan = lucky16RevealPlan(winner: winner, roundNumber: round);
          final faces = plan.steps.map((s) => s.face).toList();
          expect(faces.length, 11);
          expect(faces.toSet().length, 11, reason: 'every face shown is different');
          expect(faces.last, isNot(winner));
          expect(plan.winner, winner);
        }
      }
    });

    test('the faces can be any of the 16 cards, aces included', () {
      final seen = <Lucky16Card>{};
      for (var round = 1; round < 200; round++) {
        seen.addAll(lucky16RevealPlan(winner: Lucky16Card.all.first, roundNumber: round).steps.map((s) => s.face));
      }
      expect(seen.length, 16);
    });

    test('the flips slow down: every gap is longer than the one before', () {
      final plan = lucky16RevealPlan(winner: Lucky16Card.all.first, roundNumber: 17390003);
      for (var k = 2; k < plan.steps.length; k++) {
        final gap = plan.steps[k].at - plan.steps[k - 1].at;
        final before = plan.steps[k - 1].at - plan.steps[k - 2].at;
        expect(gap, greaterThan(before));
      }
    });
  });
}
