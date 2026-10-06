// Tests for lib/widgets/lucky_card/lucky_card_reveal_plan.dart: which faces the big
// card flips through, in which order, and when. Pure arithmetic.

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_reveal_plan.dart';
import 'package:flutter_test/flutter_test.dart';

const LuckyCard queenSpades = LuckyCard(LuckyCardRank.queen, LuckyCardSuit.spades);

LuckyCardRevealPlan plan([int round = 17390003, LuckyCard winner = queenSpades]) =>
    luckyCardRevealPlan(winner: winner, roundNumber: round);

void main() {
  group('the faces', () {
    test('there are 11 flips and every face shown is different', () {
      for (final round in [0, 1, 7, 17390003]) {
        final faces = plan(round).steps.map((s) => s.face).toList();
        expect(faces.length, 11);
        expect(faces.toSet().length, 11, reason: 'round $round');
      }
    });

    test('the last random face is never the winner, for every winner and 300 rounds', () {
      for (final winner in LuckyCard.all) {
        for (var round = 0; round < 300; round++) {
          expect(plan(round, winner).steps.last.face, isNot(winner), reason: '${winner.key} round $round');
        }
      }
    });

    test('the order comes from the round number: the same on every phone, different from round to round', () {
      expect(plan(42).steps.map((s) => s.face).toList(), plan(42).steps.map((s) => s.face).toList());
      final orders = {for (var r = 100; r < 130; r++) plan(r).steps.map((s) => s.face.key).join(',')};
      expect(orders.length, greaterThan(25), reason: 'the rounds do not all shuffle alike');
    });

    test('the winner decides nothing about the order except that it is not last', () {
      // The same round with two different winners gives the same faces, except at
      // most one position.
      final a = plan(5000, LuckyCard.all[0]).steps.map((s) => s.face).toList();
      final b = plan(5000, LuckyCard.all[7]).steps.map((s) => s.face).toList();
      var differences = 0;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) differences++;
      }
      expect(differences, lessThanOrEqualTo(1));
    });

    test('a negative or huge round number works', () {
      for (final round in [-1, -17390003, 1 << 40]) {
        final p = plan(round);
        expect(p.steps.length, 11);
        expect(p.steps.last.face, isNot(queenSpades));
      }
    });
  });

  group('the timing', () {
    test('the first flip starts at once, the others later, every gap longer than the one before', () {
      final steps = plan().steps;
      expect(steps.first.at, Duration.zero);
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i].at, greaterThan(steps[i - 1].at), reason: 'flip $i');
      }
      for (var i = 2; i < steps.length; i++) {
        final gap = steps[i].at - steps[i - 1].at;
        final before = steps[i - 1].at - steps[i - 2].at;
        expect(gap, greaterThan(before), reason: 'slowing down at flip $i');
      }
    });

    test('it starts fast (a flip every 0.1 to 0.2 s) and ends slow (0.6 to 0.7 s)', () {
      final steps = plan().steps;
      final first = steps[1].at - steps[0].at;
      final last = steps.last.at - steps[steps.length - 2].at;
      expect(first.inMilliseconds, inInclusiveRange(100, 200));
      expect(last.inMilliseconds, inInclusiveRange(600, 700));
    });

    test('the last random flip starts at 4.6 s and the whole shuffle is over before the wheel lands at 5 s', () {
      final p = plan();
      expect(p.steps.last.at.inMilliseconds, closeTo(4600, 1));
      expect(p.total, lessThan(const Duration(seconds: 5)));
      expect(p.total, greaterThan(const Duration(milliseconds: 4600)));
    });

    test('every flip finishes before the next begins, and none is too quick to see', () {
      final steps = plan().steps;
      for (var i = 0; i < steps.length - 1; i++) {
        expect(steps[i].at + steps[i].flip, lessThanOrEqualTo(steps[i + 1].at), reason: 'flip $i');
      }
      for (final s in steps) {
        expect(s.flip.inMilliseconds, inInclusiveRange(80, 280));
      }
    });

    test('a different span stretches it', () {
      final p = luckyCardRevealPlan(winner: queenSpades, roundNumber: 1, span: const Duration(seconds: 2));
      expect(p.steps.last.at.inMilliseconds, closeTo(2000, 1));
      expect(p.span, const Duration(seconds: 2));
    });
  });

  group('where the card is at a moment', () {
    test('before anything: the back; at the start the card begins to turn from its back', () {
      final p = plan();
      final start = luckyCardRevealFrameAt(p, Duration.zero);
      expect(start.from, isNull);
      expect(start.to, p.steps.first.face);
      expect(start.progress, 0);
      expect(start.visible, isNull, reason: 'still the back');
      final before = luckyCardRevealFrameAt(p, const Duration(milliseconds: -50));
      expect(before.visible, isNull);
      expect(before.to, isNull);
    });

    test('half way through a flip the new face takes over', () {
      final p = plan();
      final s = p.steps[3];
      final almost = luckyCardRevealFrameAt(p, s.at + s.flip * 0.49);
      final past = luckyCardRevealFrameAt(p, s.at + s.flip * 0.51);
      expect(almost.visible, p.steps[2].face);
      expect(past.visible, s.face);
      expect(past.from, p.steps[2].face);
      expect(past.to, s.face);
    });

    test('between flips the card rests on the last face', () {
      final p = plan();
      final s = p.steps[4];
      final rest = luckyCardRevealFrameAt(p, s.at + s.flip + const Duration(milliseconds: 20));
      expect(rest.progress, 1);
      expect(rest.visible, s.face);
    });

    test('after the last flip it holds the last random face for as long as it is asked', () {
      final p = plan();
      for (final t in [p.total, const Duration(seconds: 5), const Duration(seconds: 9)]) {
        final f = luckyCardRevealFrameAt(p, t);
        expect(f.visible, p.steps.last.face, reason: '$t');
        expect(f.progress, 1);
      }
    });
  });
}
