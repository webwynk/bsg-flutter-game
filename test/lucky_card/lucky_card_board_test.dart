// Unit tests for lib/models/lucky_card_board.dart.
//
// Every number in the worked examples comes from the spec (§3.2, confirmed by
// the user on 2026-10-04) or from the four behaviours the user chose on
// 2026-10-06 ("the Triple Chance way").

import 'dart:math';

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:flutter_test/flutter_test.dart';

LuckyCard card(String key) => LuckyCard.fromKey(key);

final jh = card('j_hearts');
final jc = card('j_clubs');
final qh = card('q_hearts');
final kh = card('k_hearts');
final ks = card('k_spades');

/// Lets a test act like the provider: it keeps the wallet and applies each
/// receipt to it.
class Table {
  Table(this.wallet) : start = wallet;

  final LuckyCardBoard board = LuckyCardBoard();
  int wallet;
  final int start;

  /// Coins that left the wallet for good because a round took the bet.
  int committed = 0;

  LuckyCardBoardResult apply(LuckyCardBoardResult r) {
    wallet -= r.coinsSpent;
    return r;
  }

  LuckyCardBoardResult select(LuckyCardChip chip) => apply(board.selectChip(chip));
  LuckyCardBoardResult tap(LuckyCard c) => apply(board.placeOnCard(c, balance: wallet));
  LuckyCardBoardResult tapGroup(List<LuckyCard> cs) => apply(board.placeOnCards(cs, balance: wallet));
  LuckyCardBoardResult doubleUp() => apply(board.doubleStakes(balance: wallet));
  LuckyCardBoardResult rebet() => apply(board.rebet(balance: wallet));
  LuckyCardBoardResult removeLast() => apply(board.removeLast());
  LuckyCardBoardResult clear() => apply(board.clear());
  LuckyCardBoardResult removeFrom(List<LuckyCard> cs) => apply(board.removeFromCards(cs));

  /// The money rule that must hold after every action.
  void expectBooksBalance() {
    expect(wallet, greaterThanOrEqualTo(0));
    expect(wallet + board.total + committed, start);
  }
}

void main() {
  group('the chips', () {
    test('five chips, 5 to 500, and the 5 chip equals the minimum stake', () {
      expect(LuckyCardChip.values.map((c) => c.amount).toList(), [5, 10, 50, 100, 500]);
      expect(LuckyCardChip.values.first.amount, kLuckyCardMinStake);
      expect(LuckyCardChip.fromAmount(50), LuckyCardChip.fifty);
      expect(LuckyCardChip.fromAmount(2), isNull);
      expect(kLuckyCardMaxStake, 50000);
    });

    test('the suit and rank groups hold the right cards in a fixed order', () {
      expect(LuckyCard.ofSuit(LuckyCardSuit.hearts).map((c) => c.key), ['j_hearts', 'q_hearts', 'k_hearts']);
      expect(LuckyCard.ofRank(LuckyCardRank.jack).map((c) => c.key), ['j_hearts', 'j_spades', 'j_diamonds', 'j_clubs']);
      for (final s in LuckyCardSuit.values) {
        expect(LuckyCard.ofSuit(s).length, 3);
      }
      for (final r in LuckyCardRank.values) {
        expect(LuckyCard.ofRank(r).length, 4);
      }
    });
  });

  group('a fresh board', () {
    test('is empty, unlocked, holds the 5 chip and offers no Rebet', () {
      final b = LuckyCardBoard();
      expect(b.isEmpty, isTrue);
      expect(b.total, 0);
      expect(b.isLocked, isFalse);
      expect(b.activeChip, LuckyCardChip.five);
      expect(b.canRebet, isFalse);
      expect(b.canRemoveLast, isFalse);
      expect(b.toBetMap(), isEmpty);
    });

    test('picking a chip moves no coins', () {
      final t = Table(1000);
      final r = t.select(LuckyCardChip.hundred);
      expect(r.coinsSpent, 0);
      expect(r.isClean, isTrue);
      expect(t.board.activeChip, LuckyCardChip.hundred);
      expect(t.wallet, 1000);
    });
  });

  group('the confirmed worked example (spec §3.2)', () {
    test('10 chip on the Hearts bar, then 5 chip on the J selector', () {
      final t = Table(1000);

      // Step 1: 10 chip -> Hearts bar.
      t.select(LuckyCardChip.ten);
      final r1 = t.tapGroup(LuckyCard.ofSuit(LuckyCardSuit.hearts));
      expect(r1.coinsSpent, 30);
      expect(r1.changed, [jh, qh, kh]);
      expect(r1.isClean, isTrue);
      expect(t.board.stakeOn(jh), 10);
      expect(t.board.stakeOn(qh), 10);
      expect(t.board.stakeOn(kh), 10);
      expect(t.board.suitTotal(LuckyCardSuit.hearts), 30);
      expect(t.board.suitTotal(LuckyCardSuit.spades), 0);
      expect(t.board.suitTotal(LuckyCardSuit.diamonds), 0);
      expect(t.board.suitTotal(LuckyCardSuit.clubs), 0);
      for (final rank in LuckyCardRank.values) {
        expect(t.board.rankTotal(rank), 10);
      }
      expect(t.board.total, 30);
      expect(t.wallet, 970);

      // Step 2: 5 chip -> J selector (adds 5 to all four jacks).
      t.select(LuckyCardChip.five);
      final r2 = t.tapGroup(LuckyCard.ofRank(LuckyCardRank.jack));
      expect(r2.coinsSpent, 20);
      expect(t.board.stakeOn(jh), 15);
      expect(t.board.stakeOn(card('j_spades')), 5);
      expect(t.board.stakeOn(card('j_diamonds')), 5);
      expect(t.board.stakeOn(jc), 5);
      expect(t.board.suitTotal(LuckyCardSuit.hearts), 35);
      expect(t.board.suitTotal(LuckyCardSuit.spades), 5);
      expect(t.board.suitTotal(LuckyCardSuit.diamonds), 5);
      expect(t.board.suitTotal(LuckyCardSuit.clubs), 5);
      expect(t.board.rankTotal(LuckyCardRank.jack), 30);
      expect(t.board.rankTotal(LuckyCardRank.queen), 10);
      expect(t.board.rankTotal(LuckyCardRank.king), 10);
      expect(t.board.total, 50);
      expect(t.wallet, 950);
      t.expectBooksBalance();
    });

    test('the 7 labels are views of the 12 cards, never extra bets', () {
      final t = Table(1000);
      t.select(LuckyCardChip.ten);
      t.tapGroup(LuckyCard.ofSuit(LuckyCardSuit.hearts));
      t.tapGroup(LuckyCard.ofRank(LuckyCardRank.jack));
      final suits = LuckyCardSuit.values.fold<int>(0, (s, x) => s + t.board.suitTotal(x));
      final ranks = LuckyCardRank.values.fold<int>(0, (s, x) => s + t.board.rankTotal(x));
      expect(suits, t.board.total);
      expect(ranks, t.board.total);
      expect(t.board.toBetMap().values.fold<int>(0, (s, v) => s + v), t.board.total);
    });

    test('a single card tap accumulates, nothing is replaced', () {
      final t = Table(1000);
      t.select(LuckyCardChip.fifty);
      t.tap(jh);
      t.tap(jh);
      t.select(LuckyCardChip.five);
      t.tap(jh);
      expect(t.board.stakeOn(jh), 105);
      expect(t.wallet, 895);
    });
  });

  group('placing on one card', () {
    test('refuses with no chip, for lack of coins, and at the maximum', () {
      final t = Table(100);
      t.board.deselectChip();
      expect(t.tap(jh).issues, {LuckyCardBoardIssue.noChipSelected});

      t.select(LuckyCardChip.fiveHundred);
      final broke = t.tap(jh);
      expect(broke.issues, {LuckyCardBoardIssue.notEnoughCoins});
      expect(broke.changedAnything, isFalse);
      expect(broke.coinsSpent, 0);
      expect(t.wallet, 100);
      expect(t.board.isEmpty, isTrue);
    });

    test('a card can reach exactly 50,000 and not one coin more', () {
      final t = Table(10000000);
      t.select(LuckyCardChip.fiveHundred);
      for (var i = 0; i < 100; i++) {
        expect(t.tap(jh).isClean, isTrue, reason: 'tap ${i + 1}');
      }
      expect(t.board.stakeOn(jh), 50000);
      t.select(LuckyCardChip.five);
      final over = t.tap(jh);
      expect(over.issues, {LuckyCardBoardIssue.cardAtMaximum});
      expect(t.board.stakeOn(jh), 50000);
      t.expectBooksBalance();
    });

    test('when both apply, lack of coins is reported, as in Triple Chance\'s single-cell bet', () {
      final b = LuckyCardBoard();
      b.selectChip(LuckyCardChip.fiveHundred);
      for (var i = 0; i < 100; i++) {
        b.placeOnCard(jh, balance: 1000);
      }
      expect(b.stakeOn(jh), 50000);
      b.selectChip(LuckyCardChip.five);
      // The card is full AND the player has 3 coins: coins win.
      expect(b.placeOnCard(jh, balance: 3).issues, {LuckyCardBoardIssue.notEnoughCoins});
      // With coins to spare, the maximum is what is reported.
      expect(b.placeOnCard(jh, balance: 1000).issues, {LuckyCardBoardIssue.cardAtMaximum});
    });
  });

  group('behaviour 1: a shortcut that cannot fully fit places what fits', () {
    test('50 chip on the Hearts bar with 120 coins: J and Q are placed, K is not', () {
      final t = Table(120);
      t.select(LuckyCardChip.fifty);
      final r = t.tapGroup(LuckyCard.ofSuit(LuckyCardSuit.hearts));
      expect(r.coinsSpent, 100);
      expect(r.changed, [jh, qh]);
      expect(r.issues, {LuckyCardBoardIssue.notEnoughCoins});
      expect(t.board.stakeOn(jh), 50);
      expect(t.board.stakeOn(qh), 50);
      expect(t.board.stakeOn(kh), 0);
      expect(t.wallet, 20);
      t.expectBooksBalance();
    });

    test('a card already at 50,000 is skipped and the rest are still placed', () {
      final t = Table(10000000);
      t.select(LuckyCardChip.fiveHundred);
      for (var i = 0; i < 100; i++) {
        t.tap(kh);
      }
      t.select(LuckyCardChip.five);
      final r = t.tapGroup(LuckyCard.ofSuit(LuckyCardSuit.hearts));
      expect(r.changed, [jh, qh]);
      expect(r.coinsSpent, 10);
      expect(r.issues, {LuckyCardBoardIssue.cardAtMaximum});
      expect(t.board.stakeOn(kh), 50000);
      expect(t.board.stakeOn(jh), 5);
    });

    test('when every card is full nothing is placed', () {
      final t = Table(100000000);
      t.select(LuckyCardChip.fiveHundred);
      for (final c in LuckyCard.ofSuit(LuckyCardSuit.hearts)) {
        for (var i = 0; i < 100; i++) {
          t.tap(c);
        }
      }
      t.select(LuckyCardChip.five);
      final r = t.tapGroup(LuckyCard.ofSuit(LuckyCardSuit.hearts));
      expect(r.changedAnything, isFalse);
      expect(r.coinsSpent, 0);
      expect(r.issues, {LuckyCardBoardIssue.cardAtMaximum});
    });

    test('with no coins for even one card nothing is placed', () {
      final t = Table(4);
      final r = t.tapGroup(LuckyCard.ofSuit(LuckyCardSuit.hearts));
      expect(r.changedAnything, isFalse);
      expect(r.issues, {LuckyCardBoardIssue.notEnoughCoins});
      expect(t.board.isEmpty, isTrue);
    });

    test('a card listed twice is placed on once', () {
      final t = Table(1000);
      t.select(LuckyCardChip.ten);
      final r = t.tapGroup([jh, jh, qh]);
      expect(r.coinsSpent, 20);
      expect(t.board.stakeOn(jh), 10);
    });
  });

  group('behaviour 2: Remove takes back one chip at a time', () {
    test('a Hearts bar tap placed three chips and needs three presses, newest first', () {
      final t = Table(1000);
      t.select(LuckyCardChip.ten);
      t.tapGroup(LuckyCard.ofSuit(LuckyCardSuit.hearts));
      expect(t.wallet, 970);

      final first = t.removeLast();
      expect(first.changed, [kh]);
      expect(first.coinsSpent, -10);
      expect(t.board.total, 20);

      expect(t.removeLast().changed, [qh]);
      expect(t.removeLast().changed, [jh]);
      expect(t.board.isEmpty, isTrue);
      expect(t.wallet, 1000);
      expect(t.removeLast().issues, {LuckyCardBoardIssue.nothingToRemove});
    });

    test('removal goes back through mixed placements in the reverse order', () {
      final t = Table(1000);
      t.select(LuckyCardChip.ten);
      t.tap(jh);
      t.select(LuckyCardChip.fifty);
      t.tap(jh);
      t.tap(qh);
      expect(t.removeLast().coinsSpent, -50);
      expect(t.board.stakeOn(qh), 0);
      expect(t.removeLast().coinsSpent, -50);
      expect(t.board.stakeOn(jh), 10);
      expect(t.removeLast().coinsSpent, -10);
      expect(t.board.isEmpty, isTrue);
      t.expectBooksBalance();
    });
  });

  group('behaviour 3: with no chip held, tapping removes', () {
    test('a card gives back its most recent chip only', () {
      final t = Table(1000);
      t.select(LuckyCardChip.ten);
      t.tap(jh);
      t.select(LuckyCardChip.fifty);
      t.tap(jh);
      t.board.deselectChip();
      final r = t.removeFrom([jh]);
      expect(r.coinsSpent, -50);
      expect(t.board.stakeOn(jh), 10);
    });

    test('a suit bar takes the most recent chip from each of its cards', () {
      final t = Table(1000);
      t.select(LuckyCardChip.ten);
      t.tap(jh);
      t.tap(jh);
      t.tapGroup(LuckyCard.ofSuit(LuckyCardSuit.hearts));
      expect(t.board.stakeOn(jh), 30);
      t.board.deselectChip();
      final r = t.removeFrom(LuckyCard.ofSuit(LuckyCardSuit.hearts));
      expect(r.coinsSpent, -30);
      expect(r.changed, [jh, qh, kh]);
      expect(t.board.stakeOn(jh), 20);
      expect(t.board.stakeOn(qh), 0);
      expect(t.board.stakeOn(kh), 0);
      t.expectBooksBalance();
    });

    test('cards with nothing on them are skipped, and nothing at all is reported', () {
      final t = Table(1000);
      t.select(LuckyCardChip.ten);
      t.tap(jh);
      t.board.deselectChip();
      final partial = t.removeFrom([jh, qh, kh]);
      expect(partial.changed, [jh]);
      expect(partial.isClean, isTrue);
      // The board is empty again, so the last chip is back in hand (behaviour
      // 4); put it down before trying to remove.
      expect(t.board.activeChip, LuckyCardChip.ten);
      t.board.deselectChip();
      final none = t.removeFrom([jh, qh]);
      expect(none.issues, {LuckyCardBoardIssue.nothingToRemove});
    });

    test('while a chip is held, tapping to remove is refused', () {
      final t = Table(1000);
      t.tap(jh);
      final r = t.removeFrom([jh]);
      expect(r.issues, {LuckyCardBoardIssue.chipIsSelected});
      expect(t.board.stakeOn(jh), 5);
    });
  });

  group('behaviour 4: the last chip is picked up again when the board empties', () {
    test('after Clear the chip last used is held again', () {
      final t = Table(1000);
      t.select(LuckyCardChip.hundred);
      t.tap(jh);
      t.board.deselectChip();
      expect(t.board.activeChip, isNull);
      t.clear();
      expect(t.board.activeChip, LuckyCardChip.hundred);
    });

    test('after Remove empties the board the last chip is held again', () {
      final t = Table(1000);
      t.select(LuckyCardChip.fifty);
      t.tap(jh);
      t.board.deselectChip();
      t.removeLast();
      expect(t.board.activeChip, LuckyCardChip.fifty);
    });

    test('with no chip ever chosen it falls back to the 5 chip', () {
      final t = Table(1000);
      t.board.deselectChip();
      t.clear();
      expect(t.board.activeChip, LuckyCardChip.five);
    });

    test('no chip is picked up while the board still holds chips', () {
      final t = Table(1000);
      t.select(LuckyCardChip.ten);
      t.tap(jh);
      t.tap(qh);
      t.board.deselectChip();
      t.removeLast();
      expect(t.board.activeChip, isNull);
    });
  });

  group('Double', () {
    test('doubles every card and charges the amount that was on the board', () {
      final t = Table(1000);
      t.select(LuckyCardChip.ten);
      t.tapGroup(LuckyCard.ofSuit(LuckyCardSuit.hearts));
      final r = t.doubleUp();
      expect(r.coinsSpent, 30);
      expect(r.changed, [jh, qh, kh]);
      expect(t.board.stakeOn(jh), 20);
      expect(t.board.total, 60);
      expect(t.wallet, 940);
      t.expectBooksBalance();
    });

    test('with too few coins nothing changes at all', () {
      final t = Table(35);
      t.select(LuckyCardChip.ten);
      t.tapGroup(LuckyCard.ofSuit(LuckyCardSuit.hearts));
      expect(t.wallet, 5);
      final r = t.doubleUp();
      expect(r.issues, {LuckyCardBoardIssue.notEnoughCoins});
      expect(t.board.total, 30);
      expect(t.wallet, 5);
    });

    test('on an empty board there is nothing to do', () {
      final t = Table(1000);
      expect(t.doubleUp().issues, {LuckyCardBoardIssue.nothingToDo});
    });

    test('a card whose double would pass 50,000 is left alone and reported', () {
      final t = Table(100000000);
      t.select(LuckyCardChip.fiveHundred);
      for (var i = 0; i < 60; i++) {
        t.tap(jh); // 30,000: doubling would make 60,000
      }
      t.select(LuckyCardChip.hundred);
      t.tap(qh);
      final r = t.doubleUp();
      expect(r.changed, [qh]);
      expect(r.coinsSpent, 100);
      expect(r.issues, {LuckyCardBoardIssue.cardAtMaximum});
      expect(t.board.stakeOn(jh), 30000);
      expect(t.board.stakeOn(qh), 200);
    });

    test('when every card is at its limit, nothing is charged', () {
      final t = Table(100000000);
      t.select(LuckyCardChip.fiveHundred);
      for (var i = 0; i < 60; i++) {
        t.tap(jh);
      }
      final r = t.doubleUp();
      expect(r.changedAnything, isFalse);
      expect(r.coinsSpent, 0);
      expect(r.issues, {LuckyCardBoardIssue.cardAtMaximum});
    });

    test('F-8: after a Double that skipped a card, Remove never refunds more than was staked', () {
      // Triple Chance once doubled the undo entry of a card that Double had
      // skipped, so Remove refunded twice what was staked.
      final t = Table(100000000);
      t.select(LuckyCardChip.fiveHundred);
      for (var i = 0; i < 60; i++) {
        t.tap(jh); // 30,000, will be skipped by Double
      }
      t.select(LuckyCardChip.hundred);
      t.tap(qh);
      t.tap(qh); // 200 in two chips, will be doubled
      t.doubleUp();
      expect(t.board.stakeOn(jh), 30000);
      expect(t.board.stakeOn(qh), 400);

      final totalBefore = t.board.total;
      var refunded = 0;
      while (t.board.canRemoveLast) {
        final r = t.removeLast();
        expect(r.coinsSpent, lessThan(0));
        refunded += -r.coinsSpent;
        t.expectBooksBalance();
      }
      expect(refunded, totalBefore);
      expect(t.board.isEmpty, isTrue);
      expect(t.wallet, t.start);
    });

    test('undo entries of a doubled card each double, so the card empties exactly', () {
      final t = Table(100000);
      t.select(LuckyCardChip.ten);
      t.tap(jh);
      t.select(LuckyCardChip.fifty);
      t.tap(jh); // 60 in two chips
      t.doubleUp(); // 120: entries 20 and 100
      expect(t.removeLast().coinsSpent, -100);
      expect(t.removeLast().coinsSpent, -20);
      expect(t.board.isEmpty, isTrue);
    });
  });

  group('Clear', () {
    test('gives everything back and empties the board', () {
      final t = Table(1000);
      t.select(LuckyCardChip.ten);
      t.tapGroup(LuckyCard.ofSuit(LuckyCardSuit.hearts));
      final r = t.clear();
      expect(r.coinsSpent, -30);
      expect(r.changed, [jh, qh, kh]);
      expect(t.board.isEmpty, isTrue);
      expect(t.wallet, 1000);
      expect(t.board.canRemoveLast, isFalse);
    });

    test('on an empty board it changes nothing and costs nothing', () {
      final t = Table(1000);
      final r = t.clear();
      expect(r.coinsSpent, 0);
      expect(r.changedAnything, isFalse);
    });
  });

  group('Rebet', () {
    LuckyCardBoard boardWithSavedBet() {
      final b = LuckyCardBoard();
      b.selectChip(LuckyCardChip.ten);
      b.placeOnCards(LuckyCard.ofSuit(LuckyCardSuit.hearts), balance: 1000);
      b.finishRound(saveForRebet: true);
      return b;
    }

    test('a finished round with a bet is offered back as Rebet, then restored', () {
      final t = Table(1000);
      t.select(LuckyCardChip.ten);
      t.tapGroup(LuckyCard.ofSuit(LuckyCardSuit.hearts));
      t.committed = t.board.total; // the round took 30 for good
      t.board.finishRound(saveForRebet: true);
      expect(t.board.isEmpty, isTrue);
      expect(t.board.canRebet, isTrue);
      expect(t.board.rebetTotal, 30);
      expect(t.board.canAffordRebet(30), isTrue);
      expect(t.board.canAffordRebet(29), isFalse);

      final r = t.rebet();
      expect(r.coinsSpent, 30);
      expect(r.changed, [jh, qh, kh]);
      expect(t.board.stakeOn(jh), 10);
      expect(t.board.total, 30);
      expect(t.board.canRebet, isFalse); // the button is Double again
      t.expectBooksBalance();
    });

    test('a restored bet can be taken back one chip at a time', () {
      final t = Table(1000);
      final b = boardWithSavedBet();
      expect(b.canRebet, isTrue);
      b.rebet(balance: t.wallet);
      expect(b.removeLast().changed, [kh]);
    });

    test('too few coins: refused, nothing changes, still offered as Rebet', () {
      final b = boardWithSavedBet();
      final r = b.rebet(balance: 29);
      expect(r.issues, {LuckyCardBoardIssue.notEnoughCoins});
      expect(b.isEmpty, isTrue);
      expect(b.canRebet, isTrue);
    });

    test('any manual bet turns Rebet back into Double, and Clear brings it back', () {
      final b = boardWithSavedBet();
      b.placeOnCard(jh, balance: 1000);
      expect(b.canRebet, isFalse);
      b.clear();
      expect(b.canRebet, isTrue);
    });

    test('removing chips does not by itself bring Rebet back; Clear does', () {
      final b = boardWithSavedBet();
      b.placeOnCard(jh, balance: 1000);
      b.removeLast();
      expect(b.isEmpty, isTrue);
      expect(b.canRebet, isFalse);
      b.clear();
      expect(b.canRebet, isTrue);
    });

    test('Rebet refuses unless the board is empty (so it cannot lose chips)', () {
      final b = boardWithSavedBet();
      b.placeOnCard(jh, balance: 1000);
      final r = b.rebet(balance: 1000);
      expect(r.issues, {LuckyCardBoardIssue.boardNotEmpty});
      // The 10 chip was still held when jh was tapped, and the refused Rebet
      // changed nothing.
      expect(b.stakeOn(jh), 10);
      expect(b.total, 10);
    });

    test('with no saved bet there is nothing to repeat', () {
      final b = LuckyCardBoard();
      expect(b.rebet(balance: 1000).issues, {LuckyCardBoardIssue.nothingToDo});
      expect(b.rebetTotal, 0);
    });

    test('an empty finished round keeps the previous saved bet', () {
      final b = boardWithSavedBet();
      b.finishRound(saveForRebet: true);
      expect(b.canRebet, isTrue);
      expect(b.rebetTotal, 30);
    });

    test('a replayed round is not saved; the earlier saved bet stays', () {
      final b = boardWithSavedBet();
      b.placeOnCard(qh, balance: 1000);
      b.finishRound(saveForRebet: false);
      expect(b.isEmpty, isTrue);
      expect(b.rebetTotal, 30);
      expect(b.canRebet, isTrue);
    });

    test('a newer finished bet replaces the saved one', () {
      final b = boardWithSavedBet();
      b.selectChip(LuckyCardChip.fifty);
      b.placeOnCard(ks, balance: 1000);
      b.finishRound(saveForRebet: true);
      expect(b.rebetTotal, 50);
    });

    test('forgetting the saved bet', () {
      final b = boardWithSavedBet();
      b.clearRebetSnapshot();
      expect(b.canRebet, isFalse);
      expect(b.rebetTotal, 0);
    });

    test('the saved bet is a copy: changing the board afterwards does not change it', () {
      final b = LuckyCardBoard();
      b.placeOnCard(jh, balance: 1000);
      b.finishRound(saveForRebet: true);
      b.rebet(balance: 1000);
      b.doubleStakes(balance: 1000);
      expect(b.stakeOn(jh), 10);
      b.finishRound(saveForRebet: false);
      expect(b.rebetTotal, 5);
    });
  });

  group('locking', () {
    test('while locked every action that changes the board refuses and changes nothing', () {
      final t = Table(1000);
      t.select(LuckyCardChip.ten);
      t.tap(jh);
      t.board.finishRound(saveForRebet: true);
      t.tap(jh);
      t.board.setLocked(true);
      expect(t.board.isLocked, isTrue);

      final totalBefore = t.board.total;
      final walletBefore = t.wallet;
      final results = [
        t.select(LuckyCardChip.fifty),
        t.tap(qh),
        t.tapGroup(LuckyCard.ofSuit(LuckyCardSuit.hearts)),
        t.removeFrom([jh]),
        t.removeLast(),
        t.doubleUp(),
        t.clear(),
        t.rebet(),
      ];
      for (final r in results) {
        expect(r.issues, {LuckyCardBoardIssue.locked});
        expect(r.changedAnything, isFalse);
        expect(r.coinsSpent, 0);
      }
      expect(t.board.total, totalBefore);
      expect(t.wallet, walletBefore);
      expect(t.board.activeChip, LuckyCardChip.ten);

      t.board.setLocked(false);
      expect(t.tap(qh).isClean, isTrue);
    });

    test('putting the chip down is never blocked, and the board can still be read and sent', () {
      final b = LuckyCardBoard();
      b.placeOnCard(jh, balance: 1000);
      b.setLocked(true);
      b.deselectChip();
      expect(b.activeChip, isNull);
      expect(b.toBetMap(), {jh: 5});
      expect(b.total, 5);
    });
  });

  group('the bet to send, and dropping a board', () {
    test('toBetMap lists only cards holding chips, in board order, as a copy', () {
      final b = LuckyCardBoard();
      b.selectChip(LuckyCardChip.ten);
      b.placeOnCard(ks, balance: 1000);
      b.placeOnCard(jh, balance: 1000);
      final map = b.toBetMap();
      expect(map.keys.toList(), [jh, ks]);
      expect(map, {jh: 10, ks: 10});
      map[qh] = 999;
      expect(b.stakeOn(qh), 0);
      expect(b.toBetMap().length, 2);
    });

    test('reset empties the board, says how many coins were on it, and keeps the saved bet', () {
      final b = LuckyCardBoard();
      b.placeOnCard(jh, balance: 1000);
      b.finishRound(saveForRebet: true);
      b.selectChip(LuckyCardChip.fifty);
      b.placeOnCard(qh, balance: 1000);
      b.placeOnCard(kh, balance: 1000);
      expect(b.reset(), 100);
      expect(b.isEmpty, isTrue);
      expect(b.canRemoveLast, isFalse);
      expect(b.rebetTotal, 5);
      expect(b.canRebet, isTrue);
    });
  });

  group('10,000 random sequences never let the money drift', () {
    test('wallet + board + committed always equals the start, and the board always drains exactly', () {
      final rng = Random(20261006);
      const allCards = LuckyCard.all;
      final groups = <List<LuckyCard>>[
        for (final s in LuckyCardSuit.values) LuckyCard.ofSuit(s),
        for (final r in LuckyCardRank.values) LuckyCard.ofRank(r),
      ];
      var cardsAtLimit = 0;
      var doublesDone = 0;
      var roundsFinished = 0;
      var rebetsDone = 0;

      // Plain checks, not expect(): there are millions of them, and expect() is
      // slow. Any failure stops the test with the sequence number.
      void check(bool ok, String what, int seq) {
        if (!ok) fail('sequence $seq: $what');
      }

      for (var seq = 0; seq < 10000; seq++) {
        // One in four sequences is rich enough to reach the 50,000 limit.
        final rich = seq % 4 == 0;
        final t = Table(rich ? 20000000 : rng.nextInt(2000));
        final steps = 20 + rng.nextInt(60);

        for (var step = 0; step < steps; step++) {
          switch (rng.nextInt(14)) {
            case 0:
            case 1:
              t.select(LuckyCardChip.values[rng.nextInt(5)]);
            case 2:
              t.board.deselectChip();
            case 3:
            case 4:
              t.tap(allCards[rng.nextInt(12)]);
            case 5:
            case 6:
              t.tapGroup(groups[rng.nextInt(groups.length)]);
            case 7:
              t.removeLast();
            case 8:
              t.removeFrom(groups[rng.nextInt(groups.length)]);
            case 9:
            case 10:
              if (t.doubleUp().changedAnything) doublesDone++;
            case 11:
              if (rng.nextInt(6) == 0) t.clear();
            case 12:
              if (t.board.canRebet) {
                if (t.rebet().changedAnything) rebetsDone++;
              } else if (t.board.total > 0 && rng.nextInt(3) == 0) {
                // The round ends: the bet is taken for good and saved for Rebet.
                t.committed += t.board.total;
                t.board.finishRound(saveForRebet: true);
                roundsFinished++;
              }
            case 13:
              t.board.setLocked(rng.nextInt(5) == 0);
          }

          check(t.wallet >= 0, 'the wallet went negative', seq);
          check(t.wallet + t.board.total + t.committed == t.start, 'coins appeared or vanished', seq);
          var sumOfCards = 0;
          for (final c in allCards) {
            final stake = t.board.stakeOn(c);
            check(stake >= 0 && stake <= kLuckyCardMaxStake, 'a card holds $stake', seq);
            if (stake == kLuckyCardMaxStake) cardsAtLimit++;
            sumOfCards += stake;
          }
          check(sumOfCards == t.board.total, 'the total is not the sum of the cards', seq);
          var suits = 0;
          for (final s in LuckyCardSuit.values) {
            suits += t.board.suitTotal(s);
          }
          var ranks = 0;
          for (final r in LuckyCardRank.values) {
            ranks += t.board.rankTotal(r);
          }
          check(suits == t.board.total && ranks == t.board.total, 'a label disagrees with the cards', seq);
        }

        // The undo list must agree with the cards exactly: draining it with
        // Remove must empty the board and return every coin.
        t.board.setLocked(false);
        var guard = 0;
        while (t.board.canRemoveLast) {
          final before = t.board.total;
          final r = t.removeLast();
          check(r.coinsSpent < 0, 'Remove charged coins', seq);
          check(t.board.total == before + r.coinsSpent, 'Remove refunded the wrong amount', seq);
          check(t.wallet + t.board.total + t.committed == t.start, 'coins drifted while draining', seq);
          check(++guard < 100000, 'Remove never finished', seq);
        }
        check(t.board.isEmpty, 'chips were left that the undo list did not know about', seq);
        check(t.wallet + t.committed == t.start, 'coins are missing after draining', seq);
      }

      // The run must really have exercised the hard paths, not just easy ones.
      expect(cardsAtLimit, greaterThan(0), reason: 'no card ever reached the 50,000 limit');
      expect(doublesDone, greaterThan(1000));
      expect(roundsFinished, greaterThan(100));
      expect(rebetsDone, greaterThan(10));
    });
  });
}
