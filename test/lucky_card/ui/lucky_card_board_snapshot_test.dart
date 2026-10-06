// Tests for lib/widgets/lucky_card/lucky_card_board_snapshot.dart.

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_board_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

LuckyCard card(LuckyCardRank r, LuckyCardSuit s) => LuckyCard(r, s);

void main() {
  group('totals are worked out from the 12 stakes', () {
    test('an empty board has nothing anywhere', () {
      final s = LuckyCardBoardSnapshot.empty();
      expect(s.total, 0);
      expect(s.isEmpty, isTrue);
      expect(s.isLocked, isFalse);
      expect(s.activeChip, isNull);
      for (final c in LuckyCard.all) {
        expect(s.stakeOn(c), 0);
      }
      for (final suit in LuckyCardSuit.values) {
        expect(s.suitTotal(suit), 0);
      }
      for (final rank in LuckyCardRank.values) {
        expect(s.rankTotal(rank), 0);
      }
    });

    test("the spec's worked example (§3.2 step 2): hearts 35, others 5, J 30, Q 10, K 10, total 50", () {
      final s = LuckyCardBoardSnapshot.fromStakes({
        card(LuckyCardRank.jack, LuckyCardSuit.hearts): 15,
        card(LuckyCardRank.jack, LuckyCardSuit.spades): 5,
        card(LuckyCardRank.jack, LuckyCardSuit.diamonds): 5,
        card(LuckyCardRank.jack, LuckyCardSuit.clubs): 5,
        card(LuckyCardRank.queen, LuckyCardSuit.hearts): 10,
        card(LuckyCardRank.king, LuckyCardSuit.hearts): 10,
      });
      expect(s.suitTotal(LuckyCardSuit.hearts), 35);
      expect(s.suitTotal(LuckyCardSuit.spades), 5);
      expect(s.suitTotal(LuckyCardSuit.diamonds), 5);
      expect(s.suitTotal(LuckyCardSuit.clubs), 5);
      expect(s.rankTotal(LuckyCardRank.jack), 30);
      expect(s.rankTotal(LuckyCardRank.queen), 10);
      expect(s.rankTotal(LuckyCardRank.king), 10);
      expect(s.total, 50);
      expect(s.isEmpty, isFalse);
    });

    test('the seven labels are views of the twelve stakes: both groupings add up to the total', () {
      final stakes = {for (final c in LuckyCard.all) c: (c.key.hashCode.abs() % 7) * 5};
      final s = LuckyCardBoardSnapshot.fromStakes(stakes);
      expect(LuckyCardSuit.values.fold(0, (a, suit) => a + s.suitTotal(suit)), s.total);
      expect(LuckyCardRank.values.fold(0, (a, rank) => a + s.rankTotal(rank)), s.total);
    });

    test('the largest possible totals: 150,000 on a suit and 200,000 on a rank', () {
      final s = LuckyCardBoardSnapshot.fromStakes({for (final c in LuckyCard.all) c: 50000});
      expect(s.suitTotal(LuckyCardSuit.clubs), 150000);
      expect(s.rankTotal(LuckyCardRank.king), 200000);
      expect(s.total, 600000);
    });

    test('a card left out holds nothing', () {
      final s = LuckyCardBoardSnapshot.fromStakes({card(LuckyCardRank.queen, LuckyCardSuit.clubs): 100});
      expect(s.stakeOn(card(LuckyCardRank.jack, LuckyCardSuit.hearts)), 0);
      expect(s.stakeOn(card(LuckyCardRank.queen, LuckyCardSuit.clubs)), 100);
    });

    test('the lock and the chip in hand are carried', () {
      final s = LuckyCardBoardSnapshot.fromStakes(const {}, isLocked: true, activeChip: LuckyCardChip.fifty);
      expect(s.isLocked, isTrue);
      expect(s.activeChip, LuckyCardChip.fifty);
    });
  });

  group('a snapshot is a snapshot', () {
    test('changing the map it was made from afterwards changes nothing', () {
      final source = {card(LuckyCardRank.jack, LuckyCardSuit.hearts): 10};
      final s = LuckyCardBoardSnapshot.fromStakes(source);
      source[card(LuckyCardRank.jack, LuckyCardSuit.hearts)] = 999;
      source[card(LuckyCardRank.king, LuckyCardSuit.clubs)] = 5;
      expect(s.stakeOn(card(LuckyCardRank.jack, LuckyCardSuit.hearts)), 10);
      expect(s.total, 10);
    });

    test('a negative stake is refused', () {
      expect(
        () => LuckyCardBoardSnapshot.fromStakes({card(LuckyCardRank.jack, LuckyCardSuit.hearts): -5}),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('equality: equal when nothing differs, so an unchanged board is not redrawn', () {
    final jh = card(LuckyCardRank.jack, LuckyCardSuit.hearts);
    final kc = card(LuckyCardRank.king, LuckyCardSuit.clubs);

    test('same stakes, lock and chip are equal, however the map was built', () {
      final a = LuckyCardBoardSnapshot.fromStakes({jh: 10, kc: 5}, activeChip: LuckyCardChip.ten);
      final b = LuckyCardBoardSnapshot.fromStakes({kc: 5, jh: 10}, activeChip: LuckyCardChip.ten);
      final c = LuckyCardBoardSnapshot.fromStakes({jh: 10, kc: 5, card(LuckyCardRank.queen, LuckyCardSuit.spades): 0}, activeChip: LuckyCardChip.ten);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, c, reason: 'a zero stake is the same as no stake');
      expect(a.hashCode, c.hashCode);
      expect(LuckyCardBoardSnapshot.empty(), LuckyCardBoardSnapshot.empty());
    });

    test('a different stake, lock or chip is not equal', () {
      final base = LuckyCardBoardSnapshot.fromStakes({jh: 10}, activeChip: LuckyCardChip.ten);
      expect(base, isNot(LuckyCardBoardSnapshot.fromStakes({jh: 15}, activeChip: LuckyCardChip.ten)));
      expect(base, isNot(LuckyCardBoardSnapshot.fromStakes({jh: 10, kc: 5}, activeChip: LuckyCardChip.ten)));
      expect(base, isNot(LuckyCardBoardSnapshot.fromStakes({jh: 10}, activeChip: LuckyCardChip.ten, isLocked: true)));
      expect(base, isNot(LuckyCardBoardSnapshot.fromStakes({jh: 10}, activeChip: LuckyCardChip.five)));
      expect(base, isNot(LuckyCardBoardSnapshot.fromStakes({jh: 10})));
    });
  });
}
