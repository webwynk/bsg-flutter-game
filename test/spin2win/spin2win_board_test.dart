// Unit tests for lib/models/spin2win_board.dart.
//
// The board is a copy of Lucky Card's, so these tests follow Lucky Card's board
// tests behaviour by behaviour, with Spin2Win's numbers (0 to 9), the ODD and
// EVEN buttons, and the user's hard limits (min 5, max 10,000 per number),
// confirmed on 2026-10-24.

import 'dart:math';

import 'package:best_smart_game/models/spin2win_board.dart';
import 'package:best_smart_game/models/spin2win_models.dart';
import 'package:flutter_test/flutter_test.dart';

const odd = kSpin2WinOddNumbers; // 1 3 5 7 9
const even = kSpin2WinEvenNumbers; // 0 2 4 6 8

/// Lets a test act like the provider: it keeps the wallet and applies each
/// receipt to it.
class Table {
  Table(this.wallet) : start = wallet;

  final Spin2WinBoard board = Spin2WinBoard();
  int wallet;
  final int start;

  /// Coins that left the wallet for good because a round took the bet.
  int committed = 0;

  Spin2WinBoardResult apply(Spin2WinBoardResult r) {
    wallet -= r.coinsSpent;
    return r;
  }

  Spin2WinBoardResult select(Spin2WinChip chip) => apply(board.selectChip(chip));
  Spin2WinBoardResult tap(int n) => apply(board.placeOnNumber(n, balance: wallet));
  Spin2WinBoardResult tapGroup(List<int> ns) => apply(board.placeOnNumbers(ns, balance: wallet));
  Spin2WinBoardResult doubleUp() => apply(board.doubleStakes(balance: wallet));
  Spin2WinBoardResult rebet() => apply(board.rebet(balance: wallet));
  Spin2WinBoardResult removeLast() => apply(board.removeLast());
  Spin2WinBoardResult clear() => apply(board.clear());
  Spin2WinBoardResult removeFrom(List<int> ns) => apply(board.removeFromNumbers(ns));

  /// Fills [n] to exactly the maximum with 500 chips (20 of them).
  void fill(int n) {
    select(Spin2WinChip.fiveHundred);
    for (var i = 0; i < 20; i++) {
      expect(tap(n).isClean, isTrue);
    }
  }

  /// The money rule that must hold after every action.
  void expectBooksBalance() {
    expect(wallet, greaterThanOrEqualTo(0));
    expect(wallet + board.total + committed, start);
  }
}

void main() {
  group('the chips and the limits', () {
    test('five chips, 5 to 500, the 5 chip equals the minimum, the maximum is 10,000', () {
      expect(Spin2WinChip.values.map((c) => c.amount).toList(), [5, 10, 50, 100, 500]);
      expect(Spin2WinChip.values.first.amount, kSpin2WinMinStake);
      expect(kSpin2WinMinStake, 5);
      expect(kSpin2WinMaxStake, 10000);
      expect(Spin2WinChip.fromAmount(50), Spin2WinChip.fifty);
      expect(Spin2WinChip.fromAmount(2), isNull);
    });
  });

  group('a fresh board', () {
    test('is empty, unlocked, holds the 5 chip and offers no Rebet', () {
      final b = Spin2WinBoard();
      expect(b.isEmpty, isTrue);
      expect(b.total, 0);
      expect(b.isLocked, isFalse);
      expect(b.activeChip, Spin2WinChip.five);
      expect(b.canRebet, isFalse);
      expect(b.canRemoveLast, isFalse);
      expect(b.toBetMap(), isEmpty);
    });

    test('picking a chip moves no coins', () {
      final t = Table(1000);
      final r = t.select(Spin2WinChip.hundred);
      expect(r.coinsSpent, 0);
      expect(r.isClean, isTrue);
      expect(t.board.activeChip, Spin2WinChip.hundred);
      expect(t.wallet, 1000);
    });

    test('a number outside 0 to 9 is a bug in the screen and is refused loudly', () {
      final b = Spin2WinBoard();
      expect(() => b.placeOnNumber(10, balance: 1000), throwsArgumentError);
      expect(() => b.placeOnNumbers([1, -1], balance: 1000), throwsArgumentError);
      expect(b.isEmpty, isTrue);
    });
  });

  group('the user\'s examples', () {
    test('ODD with the 10 chip puts 10 on 1, 3, 5, 7 and 9', () {
      final t = Table(1000);
      t.select(Spin2WinChip.ten);
      final r = t.tapGroup(odd);
      expect(r.coinsSpent, 50);
      expect(r.changed, [1, 3, 5, 7, 9]);
      expect(r.isClean, isTrue);
      for (final n in odd) {
        expect(t.board.stakeOn(n), 10);
      }
      for (final n in even) {
        expect(t.board.stakeOn(n), 0);
      }
      expect(t.board.total, 50);
      expect(t.wallet, 950);
      t.expectBooksBalance();
    });

    test('EVEN includes 0', () {
      final t = Table(1000);
      t.select(Spin2WinChip.five);
      final r = t.tapGroup(even);
      expect(r.changed, [0, 2, 4, 6, 8]);
      expect(t.board.stakeOn(0), 5);
      expect(t.board.total, 25);
    });

    test('pressing EVEN again adds to what is there', () {
      final t = Table(1000);
      t.select(Spin2WinChip.ten);
      t.tapGroup(even);
      t.tapGroup(even);
      for (final n in even) {
        expect(t.board.stakeOn(n), 20);
      }
      expect(t.wallet, 900);
    });

    test('a number tap accumulates, nothing is replaced', () {
      final t = Table(1000);
      t.select(Spin2WinChip.fifty);
      t.tap(7);
      t.tap(7);
      t.select(Spin2WinChip.five);
      t.tap(7);
      expect(t.board.stakeOn(7), 105);
      expect(t.wallet, 895);
    });
  });

  group('placing on one number', () {
    test('refuses with no chip, and for lack of coins', () {
      final t = Table(100);
      t.board.deselectChip();
      expect(t.tap(7).issues, {Spin2WinBoardIssue.noChipSelected});

      t.select(Spin2WinChip.fiveHundred);
      final broke = t.tap(7);
      expect(broke.issues, {Spin2WinBoardIssue.notEnoughCoins});
      expect(broke.changedAnything, isFalse);
      expect(broke.coinsSpent, 0);
      expect(t.wallet, 100);
      expect(t.board.isEmpty, isTrue);
    });

    test('a number can reach exactly 10,000 and not one coin more', () {
      final t = Table(1000000);
      t.fill(7);
      expect(t.board.stakeOn(7), 10000);
      t.select(Spin2WinChip.five);
      final over = t.tap(7);
      expect(over.issues, {Spin2WinBoardIssue.numberAtMaximum});
      expect(t.board.stakeOn(7), 10000);
      t.expectBooksBalance();
    });

    test('9,995 plus a 10 chip would pass the maximum and is refused', () {
      final t = Table(1000000);
      t.fill(3);
      t.board.setLocked(false);
      t.board.deselectChip();
      t.removeFrom([3]); // back to 9,500
      t.select(Spin2WinChip.hundred);
      for (var i = 0; i < 4; i++) {
        t.tap(3);
      }
      t.select(Spin2WinChip.fifty);
      t.tap(3);
      t.select(Spin2WinChip.ten);
      t.tap(3);
      t.tap(3);
      t.tap(3);
      t.tap(3);
      t.select(Spin2WinChip.five);
      t.tap(3);
      expect(t.board.stakeOn(3), 9995);
      t.select(Spin2WinChip.ten);
      expect(t.tap(3).issues, {Spin2WinBoardIssue.numberAtMaximum});
      t.select(Spin2WinChip.five);
      expect(t.tap(3).isClean, isTrue);
      expect(t.board.stakeOn(3), 10000);
    });

    test('when both apply, lack of coins is reported, as in Triple Chance\'s single-cell bet', () {
      final b = Spin2WinBoard();
      b.selectChip(Spin2WinChip.fiveHundred);
      for (var i = 0; i < 20; i++) {
        b.placeOnNumber(7, balance: 1000);
      }
      expect(b.stakeOn(7), 10000);
      b.selectChip(Spin2WinChip.five);
      expect(b.placeOnNumber(7, balance: 3).issues, {Spin2WinBoardIssue.notEnoughCoins});
      expect(b.placeOnNumber(7, balance: 1000).issues, {Spin2WinBoardIssue.numberAtMaximum});
    });
  });

  group('ODD and EVEN when they cannot fully fit', () {
    test('50 chip on ODD with 120 coins: 1 and 3 are placed, the rest are not', () {
      final t = Table(120);
      t.select(Spin2WinChip.fifty);
      final r = t.tapGroup(odd);
      expect(r.coinsSpent, 100);
      expect(r.changed, [1, 3]);
      expect(r.issues, {Spin2WinBoardIssue.notEnoughCoins});
      expect(t.board.stakeOn(5), 0);
      expect(t.wallet, 20);
      t.expectBooksBalance();
    });

    test('a number already at 10,000 is skipped, the rest are placed, and the max warning is reported', () {
      final t = Table(1000000);
      t.fill(4);
      t.select(Spin2WinChip.five);
      final r = t.tapGroup(even);
      expect(r.changed, [0, 2, 6, 8]);
      expect(r.coinsSpent, 20);
      expect(r.issues, {Spin2WinBoardIssue.numberAtMaximum});
      expect(t.board.stakeOn(4), 10000);
      expect(t.board.stakeOn(0), 5);
    });

    test('when every number is full nothing is placed', () {
      final t = Table(10000000);
      for (final n in odd) {
        t.fill(n);
      }
      t.select(Spin2WinChip.five);
      final r = t.tapGroup(odd);
      expect(r.changedAnything, isFalse);
      expect(r.coinsSpent, 0);
      expect(r.issues, {Spin2WinBoardIssue.numberAtMaximum});
    });

    test('with no coins for even one number nothing is placed', () {
      final t = Table(4);
      final r = t.tapGroup(odd);
      expect(r.changedAnything, isFalse);
      expect(r.issues, {Spin2WinBoardIssue.notEnoughCoins});
      expect(t.board.isEmpty, isTrue);
    });

    test('a number listed twice is placed on once', () {
      final t = Table(1000);
      t.select(Spin2WinChip.ten);
      final r = t.tapGroup([7, 7, 3]);
      expect(r.coinsSpent, 20);
      expect(t.board.stakeOn(7), 10);
    });
  });

  group('Remove takes back one chip at a time', () {
    test('an ODD press placed five chips and needs five presses, newest first', () {
      final t = Table(1000);
      t.select(Spin2WinChip.ten);
      t.tapGroup(odd);
      expect(t.wallet, 950);

      final first = t.removeLast();
      expect(first.changed, [9]);
      expect(first.coinsSpent, -10);
      expect(t.board.total, 40);

      expect(t.removeLast().changed, [7]);
      expect(t.removeLast().changed, [5]);
      expect(t.removeLast().changed, [3]);
      expect(t.removeLast().changed, [1]);
      expect(t.board.isEmpty, isTrue);
      expect(t.wallet, 1000);
      expect(t.removeLast().issues, {Spin2WinBoardIssue.nothingToRemove});
    });

    test('removal goes back through mixed placements in the reverse order', () {
      final t = Table(1000);
      t.select(Spin2WinChip.ten);
      t.tap(7);
      t.select(Spin2WinChip.fifty);
      t.tap(7);
      t.tap(3);
      expect(t.removeLast().coinsSpent, -50);
      expect(t.board.stakeOn(3), 0);
      expect(t.removeLast().coinsSpent, -50);
      expect(t.board.stakeOn(7), 10);
      expect(t.removeLast().coinsSpent, -10);
      expect(t.board.isEmpty, isTrue);
      t.expectBooksBalance();
    });
  });

  group('with no chip held, tapping removes (chip deselect, as in Triple Chance)', () {
    test('a number gives back its most recent chip only', () {
      final t = Table(1000);
      t.select(Spin2WinChip.ten);
      t.tap(7);
      t.select(Spin2WinChip.fifty);
      t.tap(7);
      t.board.deselectChip();
      final r = t.removeFrom([7]);
      expect(r.coinsSpent, -50);
      expect(t.board.stakeOn(7), 10);
    });

    test('ODD takes the most recent chip from each of its numbers', () {
      final t = Table(1000);
      t.select(Spin2WinChip.ten);
      t.tap(1);
      t.tap(1);
      t.tapGroup(odd);
      expect(t.board.stakeOn(1), 30);
      t.board.deselectChip();
      final r = t.removeFrom(odd);
      expect(r.coinsSpent, -50);
      expect(r.changed, [1, 3, 5, 7, 9]);
      expect(t.board.stakeOn(1), 20);
      expect(t.board.stakeOn(3), 0);
      t.expectBooksBalance();
    });

    test('numbers with nothing on them are skipped, and nothing at all is reported', () {
      final t = Table(1000);
      t.select(Spin2WinChip.ten);
      t.tap(2);
      t.board.deselectChip();
      final partial = t.removeFrom(even);
      expect(partial.changed, [2]);
      expect(partial.isClean, isTrue);
      // The board is empty again, so the last chip is back in hand; put it
      // down before trying to remove.
      expect(t.board.activeChip, Spin2WinChip.ten);
      t.board.deselectChip();
      expect(t.removeFrom(even).issues, {Spin2WinBoardIssue.nothingToRemove});
    });

    test('while a chip is held, tapping to remove is refused', () {
      final t = Table(1000);
      t.tap(7);
      final r = t.removeFrom([7]);
      expect(r.issues, {Spin2WinBoardIssue.chipIsSelected});
      expect(t.board.stakeOn(7), 5);
    });
  });

  group('the last chip is picked up again when the board empties', () {
    test('after Clear the chip last used is held again', () {
      final t = Table(1000);
      t.select(Spin2WinChip.hundred);
      t.tap(7);
      t.board.deselectChip();
      expect(t.board.activeChip, isNull);
      t.clear();
      expect(t.board.activeChip, Spin2WinChip.hundred);
    });

    test('after Remove empties the board the last chip is held again', () {
      final t = Table(1000);
      t.select(Spin2WinChip.fifty);
      t.tap(7);
      t.board.deselectChip();
      t.removeLast();
      expect(t.board.activeChip, Spin2WinChip.fifty);
    });

    test('with no chip ever chosen it falls back to the 5 chip', () {
      final t = Table(1000);
      t.board.deselectChip();
      t.clear();
      expect(t.board.activeChip, Spin2WinChip.five);
    });

    test('no chip is picked up while the board still holds chips', () {
      final t = Table(1000);
      t.select(Spin2WinChip.ten);
      t.tap(7);
      t.tap(3);
      t.board.deselectChip();
      t.removeLast();
      expect(t.board.activeChip, isNull);
    });
  });

  group('Double', () {
    test('doubles every number and charges the amount that was on the board', () {
      final t = Table(1000);
      t.select(Spin2WinChip.ten);
      t.tapGroup(odd);
      final r = t.doubleUp();
      expect(r.coinsSpent, 50);
      expect(r.changed, [1, 3, 5, 7, 9]);
      expect(t.board.stakeOn(7), 20);
      expect(t.board.total, 100);
      expect(t.wallet, 900);
      t.expectBooksBalance();
    });

    test('with too few coins nothing changes at all', () {
      final t = Table(55);
      t.select(Spin2WinChip.ten);
      t.tapGroup(odd);
      expect(t.wallet, 5);
      final r = t.doubleUp();
      expect(r.issues, {Spin2WinBoardIssue.notEnoughCoins});
      expect(t.board.total, 50);
      expect(t.wallet, 5);
    });

    test('on an empty board there is nothing to do', () {
      final t = Table(1000);
      expect(t.doubleUp().issues, {Spin2WinBoardIssue.nothingToDo});
    });

    test('a number whose double would pass 10,000 is left alone and reported', () {
      final t = Table(10000000);
      t.select(Spin2WinChip.fiveHundred);
      for (var i = 0; i < 12; i++) {
        t.tap(7); // 6,000: doubling would make 12,000
      }
      t.select(Spin2WinChip.hundred);
      t.tap(3);
      final r = t.doubleUp();
      expect(r.changed, [3]);
      expect(r.coinsSpent, 100);
      expect(r.issues, {Spin2WinBoardIssue.numberAtMaximum});
      expect(t.board.stakeOn(7), 6000);
      expect(t.board.stakeOn(3), 200);
    });

    test('exactly 5,000 doubles to exactly 10,000', () {
      final t = Table(10000000);
      t.select(Spin2WinChip.fiveHundred);
      for (var i = 0; i < 10; i++) {
        t.tap(0);
      }
      final r = t.doubleUp();
      expect(r.isClean, isTrue);
      expect(t.board.stakeOn(0), 10000);
    });

    test('when every number is at its limit, nothing is charged', () {
      final t = Table(10000000);
      t.select(Spin2WinChip.fiveHundred);
      for (var i = 0; i < 12; i++) {
        t.tap(7);
      }
      final r = t.doubleUp();
      expect(r.changedAnything, isFalse);
      expect(r.coinsSpent, 0);
      expect(r.issues, {Spin2WinBoardIssue.numberAtMaximum});
    });

    test('F-8: after a Double that skipped a number, Remove never refunds more than was staked', () {
      final t = Table(10000000);
      t.select(Spin2WinChip.fiveHundred);
      for (var i = 0; i < 12; i++) {
        t.tap(7); // 6,000, will be skipped by Double
      }
      t.select(Spin2WinChip.hundred);
      t.tap(3);
      t.tap(3); // 200 in two chips, will be doubled
      t.doubleUp();
      expect(t.board.stakeOn(7), 6000);
      expect(t.board.stakeOn(3), 400);

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

    test('undo entries of a doubled number each double, so the number empties exactly', () {
      final t = Table(100000);
      t.select(Spin2WinChip.ten);
      t.tap(7);
      t.select(Spin2WinChip.fifty);
      t.tap(7); // 60 in two chips
      t.doubleUp(); // 120: entries 20 and 100
      expect(t.removeLast().coinsSpent, -100);
      expect(t.removeLast().coinsSpent, -20);
      expect(t.board.isEmpty, isTrue);
    });
  });

  group('Clear', () {
    test('gives everything back and empties the board', () {
      final t = Table(1000);
      t.select(Spin2WinChip.ten);
      t.tapGroup(odd);
      final r = t.clear();
      expect(r.coinsSpent, -50);
      expect(r.changed, [1, 3, 5, 7, 9]);
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
    Spin2WinBoard boardWithSavedBet() {
      final b = Spin2WinBoard();
      b.selectChip(Spin2WinChip.ten);
      b.placeOnNumbers(odd, balance: 1000);
      b.finishRound(saveForRebet: true);
      return b;
    }

    test('a finished round with a bet is offered back as Rebet, then restored', () {
      final t = Table(1000);
      t.select(Spin2WinChip.ten);
      t.tapGroup(odd);
      t.committed = t.board.total; // the round took 50 for good
      t.board.finishRound(saveForRebet: true);
      expect(t.board.isEmpty, isTrue);
      expect(t.board.canRebet, isTrue);
      expect(t.board.rebetTotal, 50);
      expect(t.board.canAffordRebet(50), isTrue);
      expect(t.board.canAffordRebet(49), isFalse);

      final r = t.rebet();
      expect(r.coinsSpent, 50);
      expect(r.changed, [1, 3, 5, 7, 9]);
      expect(t.board.stakeOn(7), 10);
      expect(t.board.total, 50);
      expect(t.board.canRebet, isFalse); // the button is Double again
      t.expectBooksBalance();
    });

    test('a restored bet can be taken back one chip at a time', () {
      final b = boardWithSavedBet();
      b.rebet(balance: 1000);
      expect(b.removeLast().changed, [9]);
    });

    test('too few coins: refused, nothing changes, still offered as Rebet', () {
      final b = boardWithSavedBet();
      final r = b.rebet(balance: 49);
      expect(r.issues, {Spin2WinBoardIssue.notEnoughCoins});
      expect(b.isEmpty, isTrue);
      expect(b.canRebet, isTrue);
    });

    test('any manual bet turns Rebet back into Double, and Clear brings it back', () {
      final b = boardWithSavedBet();
      b.placeOnNumber(7, balance: 1000);
      expect(b.canRebet, isFalse);
      b.clear();
      expect(b.canRebet, isTrue);
    });

    test('removing chips does not by itself bring Rebet back; Clear does', () {
      final b = boardWithSavedBet();
      b.placeOnNumber(7, balance: 1000);
      b.removeLast();
      expect(b.isEmpty, isTrue);
      expect(b.canRebet, isFalse);
      b.clear();
      expect(b.canRebet, isTrue);
    });

    test('Rebet refuses unless the board is empty (so it cannot lose chips)', () {
      final b = boardWithSavedBet();
      b.placeOnNumber(7, balance: 1000);
      final r = b.rebet(balance: 1000);
      expect(r.issues, {Spin2WinBoardIssue.boardNotEmpty});
      expect(b.stakeOn(7), 10);
      expect(b.total, 10);
    });

    test('with no saved bet there is nothing to repeat', () {
      final b = Spin2WinBoard();
      expect(b.rebet(balance: 1000).issues, {Spin2WinBoardIssue.nothingToDo});
      expect(b.rebetTotal, 0);
    });

    test('an empty finished round keeps the previous saved bet', () {
      final b = boardWithSavedBet();
      b.finishRound(saveForRebet: true);
      expect(b.canRebet, isTrue);
      expect(b.rebetTotal, 50);
    });

    test('a replayed round is not saved; the earlier saved bet stays', () {
      final b = boardWithSavedBet();
      b.placeOnNumber(3, balance: 1000);
      b.finishRound(saveForRebet: false);
      expect(b.isEmpty, isTrue);
      expect(b.rebetTotal, 50);
      expect(b.canRebet, isTrue);
    });

    test('a newer finished bet replaces the saved one', () {
      final b = boardWithSavedBet();
      b.selectChip(Spin2WinChip.fifty);
      b.placeOnNumber(0, balance: 1000);
      b.finishRound(saveForRebet: true);
      expect(b.rebetTotal, 50);
      expect((b..rebet(balance: 1000)).toBetMap(), {0: 50});
    });

    test('forgetting the saved bet', () {
      final b = boardWithSavedBet();
      b.clearRebetSnapshot();
      expect(b.canRebet, isFalse);
      expect(b.rebetTotal, 0);
    });

    test('the saved bet is a copy: changing the board afterwards does not change it', () {
      final b = Spin2WinBoard();
      b.placeOnNumber(7, balance: 1000);
      b.finishRound(saveForRebet: true);
      b.rebet(balance: 1000);
      b.doubleStakes(balance: 1000);
      expect(b.stakeOn(7), 10);
      b.finishRound(saveForRebet: false);
      expect(b.rebetTotal, 5);
    });
  });

  group('locking', () {
    test('while locked every action that changes the board refuses and changes nothing', () {
      final t = Table(1000);
      t.select(Spin2WinChip.ten);
      t.tap(7);
      t.board.finishRound(saveForRebet: true);
      t.tap(7);
      t.board.setLocked(true);
      expect(t.board.isLocked, isTrue);

      final totalBefore = t.board.total;
      final walletBefore = t.wallet;
      final results = [
        t.select(Spin2WinChip.fifty),
        t.tap(3),
        t.tapGroup(odd),
        t.tapGroup(even),
        t.removeFrom([7]),
        t.removeLast(),
        t.doubleUp(),
        t.clear(),
        t.rebet(),
      ];
      for (final r in results) {
        expect(r.issues, {Spin2WinBoardIssue.locked});
        expect(r.changedAnything, isFalse);
        expect(r.coinsSpent, 0);
      }
      expect(t.board.total, totalBefore);
      expect(t.wallet, walletBefore);
      expect(t.board.activeChip, Spin2WinChip.ten);

      t.board.setLocked(false);
      expect(t.tap(3).isClean, isTrue);
    });

    test('putting the chip down is never blocked, and the board can still be read and sent', () {
      final b = Spin2WinBoard();
      b.placeOnNumber(7, balance: 1000);
      b.setLocked(true);
      b.deselectChip();
      expect(b.activeChip, isNull);
      expect(b.toBetMap(), {7: 5});
      expect(b.total, 5);
    });
  });

  group('the bet to send, and dropping a board', () {
    test('toBetMap lists only numbers holding chips, in board order, as a copy', () {
      final b = Spin2WinBoard();
      b.selectChip(Spin2WinChip.ten);
      b.placeOnNumber(9, balance: 1000);
      b.placeOnNumber(0, balance: 1000);
      final map = b.toBetMap();
      expect(map.keys.toList(), [0, 9]);
      expect(map, {0: 10, 9: 10});
      map[3] = 999;
      expect(b.stakeOn(3), 0);
      expect(b.toBetMap().length, 2);
    });

    test('reset empties the board, says how many coins were on it, and keeps the saved bet', () {
      final b = Spin2WinBoard();
      b.placeOnNumber(7, balance: 1000);
      b.finishRound(saveForRebet: true);
      b.selectChip(Spin2WinChip.fifty);
      b.placeOnNumber(3, balance: 1000);
      b.placeOnNumber(5, balance: 1000);
      expect(b.reset(), 100);
      expect(b.isEmpty, isTrue);
      expect(b.canRemoveLast, isFalse);
      expect(b.rebetTotal, 5);
      expect(b.canRebet, isTrue);
    });
  });

  group('10,000 random sequences never let the money drift', () {
    test('wallet + board + committed always equals the start, and the board always drains exactly', () {
      final rng = Random(20261024);
      const groups = [odd, even];
      var numbersAtLimit = 0;
      var doublesDone = 0;
      var roundsFinished = 0;
      var rebetsDone = 0;

      // Plain checks, not expect(): there are millions of them, and expect() is
      // slow. Any failure stops the test with the sequence number.
      void check(bool ok, String what, int seq) {
        if (!ok) fail('sequence $seq: $what');
      }

      for (var seq = 0; seq < 10000; seq++) {
        // One in four sequences is rich enough to reach the 10,000 limit.
        final rich = seq % 4 == 0;
        final t = Table(rich ? 2000000 : rng.nextInt(2000));
        final steps = 20 + rng.nextInt(60);

        for (var step = 0; step < steps; step++) {
          switch (rng.nextInt(14)) {
            case 0:
            case 1:
              t.select(Spin2WinChip.values[rng.nextInt(5)]);
            case 2:
              t.board.deselectChip();
            case 3:
            case 4:
              t.tap(rng.nextInt(10));
            case 5:
            case 6:
              t.tapGroup(groups[rng.nextInt(2)]);
            case 7:
              t.removeLast();
            case 8:
              t.removeFrom(groups[rng.nextInt(2)]);
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
          var sumOfNumbers = 0;
          for (final n in kSpin2WinNumbers) {
            final stake = t.board.stakeOn(n);
            check(stake == 0 || (stake >= kSpin2WinMinStake && stake <= kSpin2WinMaxStake),
                'a number holds $stake', seq);
            if (stake == kSpin2WinMaxStake) numbersAtLimit++;
            sumOfNumbers += stake;
          }
          check(sumOfNumbers == t.board.total, 'the total is not the sum of the numbers', seq);
        }

        // The undo list must agree with the numbers exactly: draining it with
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
      expect(numbersAtLimit, greaterThan(0), reason: 'no number ever reached the 10,000 limit');
      expect(doublesDone, greaterThan(1000));
      expect(roundsFinished, greaterThan(100));
      expect(rebetsDone, greaterThan(10));
    });
  });
}
