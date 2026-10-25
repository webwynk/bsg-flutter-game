// The Spin2Win betting board: the ten chip amounts (numbers 0 to 9), the undo
// list and the Rebet memory, with every rule for changing them.
//
// Pure Dart. It never touches the player's wallet, sound, vibration, timers or
// the network. Each action takes the coins the player currently has and answers
// with a [Spin2WinBoardResult]: how many coins the player's balance must go
// down (or up) by, which numbers changed, and why anything could not be done.
// The provider applies that to the real balance, so the money arithmetic lives
// in one small place that is tested on its own.
//
// A copy of Lucky Card's board, whose behaviour already follows Triple
// Chance's, as the user asked ("DOUBLE, REMOVE, CLEAR and REBET exactly like
// Triple Chance", 2026-10-24):
//   1. ODD and EVEN place the held chip on every odd (1, 3, 5, 7, 9) or even
//      (0, 2, 4, 6, 8) number. Pressing again adds to what is there. A number
//      that would pass the maximum is skipped and the rest are still placed,
//      and placing stops at the first number the player can no longer afford;
//      both reasons are reported so the screen can show the warning.
//   2. Remove undoes ONE chip at a time, so an ODD press that placed five chips
//      needs five presses.
//   3. With no chip selected, tapping a number removes its most recent chip,
//      and tapping ODD or EVEN removes the most recent chip from each of its
//      numbers.
//   4. When the board becomes empty and no chip is held, the last chip used is
//      held again (the 5 chip if none was used).
// The deliberate differences from Triple Chance are listed on [rebet] and on
// the "rebetUsed" rule below.
//
// Belongs to Spin2Win only; it reuses nothing from Triple Chance or Lucky Card.

import 'spin2win_models.dart';

/// The smallest stake a number can hold (the user's hard rule, 2026-10-24). Also the smallest chip, so a
/// chip placed from the board can never fall below it.
const int kSpin2WinMinStake = 5;

/// The most one number can hold (the user's hard rule, 2026-10-24; no admin
/// control). The database enforces it too.
const int kSpin2WinMaxStake = 10000;

/// The five chips, smallest first: 5, 10, 50 and 100 look like Triple
/// Chance's chips, 500 like Lucky Card's.
enum Spin2WinChip {
  five(5),
  ten(10),
  fifty(50),
  hundred(100),
  fiveHundred(500);

  const Spin2WinChip(this.amount);

  /// Coins this chip adds to a number.
  final int amount;

  /// The chip worth exactly [value], or null if there is none.
  static Spin2WinChip? fromAmount(int value) {
    for (final chip in values) {
      if (chip.amount == value) return chip;
    }
    return null;
  }
}

/// Why an action did nothing, or only part of what was asked.
enum Spin2WinBoardIssue {
  /// Betting is closed (the countdown reached its lock mark).
  locked,

  /// A chip is needed to place a bet and none is held.
  noChipSelected,

  /// Removing by tapping needs the hands empty; a chip is held.
  chipIsSelected,

  /// The player does not have enough coins for the chip, the double or the rebet.
  notEnoughCoins,

  /// At least one number could not take more because it would pass the maximum.
  numberAtMaximum,

  /// There was nothing for the action to work on (an empty board, or no saved
  /// bet to repeat).
  nothingToDo,

  /// There is no chip to take back from that number, or from the board.
  nothingToRemove,

  /// Rebet only restores a bet onto an empty board.
  boardNotEmpty,
}

/// What an action did.
class Spin2WinBoardResult {
  const Spin2WinBoardResult({
    this.coinsSpent = 0,
    this.changed = const [],
    this.issues = const {},
  });

  /// How much the player's balance must go DOWN by. Negative means coins go back
  /// to the player: placing a chip is +50, removing it is -50.
  final int coinsSpent;

  /// The numbers whose amount changed, in board order.
  final List<int> changed;

  /// Everything that stopped the action from being complete. Empty on a clean
  /// success. A partial success (a shortcut that placed some numbers) has both a
  /// non-empty [changed] and a non-empty [issues].
  final Set<Spin2WinBoardIssue> issues;

  /// True when at least one number changed.
  bool get changedAnything => changed.isNotEmpty;

  /// True when the action did everything that was asked.
  bool get isClean => issues.isEmpty;
}

/// One chip placed: kept in order so Remove can take them back one at a time.
class _Placement {
  _Placement(this.number, this.amount);

  final int number;
  int amount;
}

/// The board. See the file comment.
class Spin2WinBoard {
  final Map<int, int> _stakes = {};
  final List<_Placement> _history = [];
  Map<int, int>? _rebetSnapshot;

  // Triple Chance starts with its smallest chip held; so does Spin2Win.
  Spin2WinChip? _activeChip = Spin2WinChip.five;
  Spin2WinChip? _lastActiveChip = Spin2WinChip.five;

  /// True once a chip has been placed (or Rebet pressed) since the board was
  /// last cleared or the round last ended: the Rebet button then turns back into
  /// Double. Triple Chance sets it slightly earlier, before it knows whether
  /// anything will actually be placed; here it is set only when a chip really
  /// is, which differs only when every placement fails for lack of coins.
  bool _rebetUsed = false;

  bool _locked = false;

  // ── What the board holds ───────────────────────────────────────────────

  /// The chip held in the player's hand, or null when none is.
  Spin2WinChip? get activeChip => _activeChip;

  /// True while betting is closed: every action that changes the board refuses.
  bool get isLocked => _locked;

  /// The amount on [number].
  int stakeOn(int number) => _stakes[number] ?? 0;

  /// The round total: the sum of the ten numbers.
  int get total => _stakes.values.fold(0, (sum, v) => sum + v);

  /// True when no number holds anything.
  bool get isEmpty => _stakes.isEmpty;

  /// True when Remove has a chip to take back.
  bool get canRemoveLast => _history.isNotEmpty;

  /// The bet to send to the database: only the numbers holding chips, in board
  /// order, as a fresh copy.
  Map<int, int> toBetMap() => {
        for (final number in kSpin2WinNumbers)
          if (stakeOn(number) > 0) number: stakeOn(number),
      };

  // ── Rebet ──────────────────────────────────────────────────────────────

  /// True when the Rebet button should be offered instead of Double: a bet from
  /// a finished round is saved, nothing has been placed since, and the board is
  /// empty. It does not check coins (see [canAffordRebet]) so an unaffordable
  /// Rebet still shows as Rebet, disabled, never as Double. The caller also
  /// requires that no round reveal is running; the board does not know that.
  bool get canRebet {
    final saved = _rebetSnapshot;
    return saved != null && saved.isNotEmpty && !_rebetUsed && isEmpty;
  }

  /// The cost of repeating the saved bet; 0 when none is saved.
  int get rebetTotal =>
      _rebetSnapshot?.values.fold<int>(0, (sum, v) => sum + v) ?? 0;

  /// True when [balance] covers the saved bet. Only meaningful once [canRebet].
  bool canAffordRebet(int balance) => balance >= rebetTotal;

  // ── Locking ────────────────────────────────────────────────────────────

  /// Opens or closes betting. The provider closes it at the lock mark (countdown
  /// 05) and opens it again for the next round.
  void setLocked(bool locked) => _locked = locked;

  // ── The chip in hand ───────────────────────────────────────────────────

  /// Picks a chip up. Moves no coins.
  Spin2WinBoardResult selectChip(Spin2WinChip chip) {
    if (_locked) return _refused(Spin2WinBoardIssue.locked);
    _activeChip = chip;
    _lastActiveChip = chip;
    return const Spin2WinBoardResult();
  }

  /// Puts the chip down without placing it, so taps remove chips instead.
  void deselectChip() => _activeChip = null;

  // ── Placing ────────────────────────────────────────────────────────────

  /// Adds the held chip to one number.
  ///
  /// Refuses for lack of coins before it checks the maximum, as Triple Chance's
  /// single-cell bet does.
  Spin2WinBoardResult placeOnNumber(int number, {required int balance}) {
    _checkNumber(number);
    if (_locked) return _refused(Spin2WinBoardIssue.locked);
    final chip = _activeChip;
    if (chip == null) return _refused(Spin2WinBoardIssue.noChipSelected);
    if (balance < chip.amount) return _refused(Spin2WinBoardIssue.notEnoughCoins);
    if (stakeOn(number) + chip.amount > kSpin2WinMaxStake) {
      return _refused(Spin2WinBoardIssue.numberAtMaximum);
    }
    _place(number, chip.amount);
    _rebetUsed = true;
    return Spin2WinBoardResult(coinsSpent: chip.amount, changed: [number]);
  }

  /// Adds the held chip to each of [numbers] (ODD's five or EVEN's five), in
  /// the order given.
  ///
  /// A number that would pass the maximum is skipped and the rest are still
  /// placed; placing stops at the first number the player can no longer afford.
  /// Both reasons are reported. This is Triple Chance's row-bet behaviour.
  Spin2WinBoardResult placeOnNumbers(List<int> numbers, {required int balance}) {
    if (_locked) return _refused(Spin2WinBoardIssue.locked);
    final chip = _activeChip;
    if (chip == null) return _refused(Spin2WinBoardIssue.noChipSelected);

    final fits = <int>[];
    var skippedForMaximum = false;
    for (final number in _unique(numbers)) {
      if (stakeOn(number) + chip.amount > kSpin2WinMaxStake) {
        skippedForMaximum = true;
      } else {
        fits.add(number);
      }
    }
    if (fits.isEmpty) return _refused(Spin2WinBoardIssue.numberAtMaximum);

    final placed = <int>[];
    var spent = 0;
    var ranOutOfCoins = false;
    for (final number in fits) {
      if (balance - spent < chip.amount) {
        ranOutOfCoins = true;
        break;
      }
      _place(number, chip.amount);
      spent += chip.amount;
      placed.add(number);
    }
    if (placed.isNotEmpty) _rebetUsed = true;
    return Spin2WinBoardResult(
      coinsSpent: spent,
      changed: placed,
      issues: {
        if (ranOutOfCoins) Spin2WinBoardIssue.notEnoughCoins,
        if (skippedForMaximum) Spin2WinBoardIssue.numberAtMaximum,
      },
    );
  }

  // ── Removing ───────────────────────────────────────────────────────────

  /// Takes back the most recent chip on [number]. Only works when no chip is held
  /// (the player taps a number with empty hands to remove).
  Spin2WinBoardResult removeFromNumber(int number) =>
      removeFromNumbers([number]);

  /// Takes back the most recent chip from each of [numbers] that holds one. Only
  /// works when no chip is held.
  Spin2WinBoardResult removeFromNumbers(List<int> numbers) {
    if (_locked) return _refused(Spin2WinBoardIssue.locked);
    if (_activeChip != null) return _refused(Spin2WinBoardIssue.chipIsSelected);

    final changed = <int>[];
    var refunded = 0;
    for (final number in _unique(numbers)) {
      final index = _history.lastIndexWhere((p) => p.number == number);
      if (index < 0) continue;
      refunded += _takeBack(index);
      changed.add(number);
    }
    if (changed.isEmpty) return _refused(Spin2WinBoardIssue.nothingToRemove);
    _restoreChipIfBoardEmpty();
    return Spin2WinBoardResult(coinsSpent: -refunded, changed: changed);
  }

  /// Takes back the most recently placed chip, wherever it is: the Remove
  /// button. One chip per press, so an ODD press that placed five chips needs
  /// five presses.
  Spin2WinBoardResult removeLast() {
    if (_locked) return _refused(Spin2WinBoardIssue.locked);
    if (_history.isEmpty) return _refused(Spin2WinBoardIssue.nothingToRemove);
    final number = _history.last.number;
    final refunded = _takeBack(_history.length - 1);
    _restoreChipIfBoardEmpty();
    return Spin2WinBoardResult(coinsSpent: -refunded, changed: [number]);
  }

  // ── Double, Clear, Rebet ───────────────────────────────────────────────

  /// Doubles every number that can be doubled; a number whose double would pass the
  /// maximum is left as it is and reported. If the player cannot afford the
  /// doubling of the numbers that qualify, nothing at all changes.
  ///
  /// The decision for each number is made once, and the undo list is changed for
  /// exactly the numbers that were doubled, so Remove can never refund more than
  /// was staked (the mismatch Triple Chance's fix F-8 corrected).
  Spin2WinBoardResult doubleStakes({required int balance}) {
    if (_locked) return _refused(Spin2WinBoardIssue.locked);
    if (isEmpty) return _refused(Spin2WinBoardIssue.nothingToDo);

    final doubled = <int>[];
    var skippedForMaximum = false;
    var cost = 0;
    for (final number in kSpin2WinNumbers) {
      final stake = stakeOn(number);
      if (stake == 0) continue;
      if (stake * 2 > kSpin2WinMaxStake) {
        skippedForMaximum = true;
      } else {
        doubled.add(number);
        cost += stake;
      }
    }
    if (balance < cost) return _refused(Spin2WinBoardIssue.notEnoughCoins);

    final doubledSet = doubled.toSet();
    for (final number in doubled) {
      _stakes[number] = stakeOn(number) * 2;
    }
    for (final placement in _history) {
      if (doubledSet.contains(placement.number)) placement.amount *= 2;
    }
    return Spin2WinBoardResult(
      coinsSpent: cost,
      changed: doubled,
      issues: {if (skippedForMaximum) Spin2WinBoardIssue.numberAtMaximum},
    );
  }

  /// Empties the board and gives everything back. Also lets Rebet appear again.
  Spin2WinBoardResult clear() {
    if (_locked) return _refused(Spin2WinBoardIssue.locked);
    final refunded = total;
    final changed = [for (final c in kSpin2WinNumbers) if (stakeOn(c) > 0) c];
    _stakes.clear();
    _history.clear();
    _rebetUsed = false;
    _restoreChipIfBoardEmpty();
    return Spin2WinBoardResult(coinsSpent: -refunded, changed: changed);
  }

  /// Puts the saved bet back on an empty board.
  ///
  /// Differs from Triple Chance in one safe way: it refuses ([boardNotEmpty])
  /// unless the board is empty. Triple Chance's version would overwrite the
  /// numbers it restores and lose what they held without a refund; its button is
  /// only shown on an empty board, so that path is never reached there, and
  /// here it cannot be reached at all.
  Spin2WinBoardResult rebet({required int balance}) {
    if (_locked) return _refused(Spin2WinBoardIssue.locked);
    final saved = _rebetSnapshot;
    if (saved == null || saved.isEmpty) return _refused(Spin2WinBoardIssue.nothingToDo);
    if (!isEmpty) return _refused(Spin2WinBoardIssue.boardNotEmpty);
    final cost = rebetTotal;
    if (balance < cost) return _refused(Spin2WinBoardIssue.notEnoughCoins);

    final restored = <int>[];
    for (final number in kSpin2WinNumbers) {
      final amount = saved[number];
      if (amount == null) continue;
      _stakes[number] = amount;
      _history.add(_Placement(number, amount));
      restored.add(number);
    }
    _rebetUsed = true;
    return Spin2WinBoardResult(coinsSpent: cost, changed: restored);
  }

  // ── End of round ───────────────────────────────────────────────────────

  /// Ends a round that finished normally: when [saveForRebet] is true and the
  /// board held a bet, that bet is remembered for Rebet. Then the board is
  /// cleared, Rebet becomes available again, and the last chip is held again.
  /// The provider passes false for a round the player only caught as a replay
  /// after coming back, as Triple Chance does.
  void finishRound({required bool saveForRebet}) {
    if (saveForRebet && !isEmpty) _rebetSnapshot = Map.of(_stakes);
    _stakes.clear();
    _history.clear();
    _rebetUsed = false;
    _restoreChipIfBoardEmpty();
  }

  /// Clears the board WITHOUT touching the saved Rebet bet, and returns how
  /// many coins were on it. For a board that has to be dropped (a rejected bet,
  /// a round that never resolved, leaving the screen): the caller decides
  /// whether those coins go back to the player.
  int reset() {
    final onBoard = total;
    _stakes.clear();
    _history.clear();
    _rebetUsed = false;
    _restoreChipIfBoardEmpty();
    return onBoard;
  }

  /// Forgets the saved Rebet bet.
  void clearRebetSnapshot() {
    _rebetSnapshot = null;
    _rebetUsed = false;
  }

  // ── Internals ──────────────────────────────────────────────────────────

  Spin2WinBoardResult _refused(Spin2WinBoardIssue issue) =>
      Spin2WinBoardResult(issues: {issue});

  /// [numbers] without repeats, keeping the first occurrence, so a number listed
  /// twice cannot be placed on or taken from twice by one tap.
  static List<int> _unique(List<int> numbers) {
    numbers.forEach(_checkNumber);
    final seen = <int>{};
    return [for (final c in numbers) if (seen.add(c)) c];
  }

  /// A number outside 0 to 9 can only come from a bug in the screen; it is
  /// refused loudly rather than put on the board and sent to the database.
  static void _checkNumber(int number) {
    if (!isSpin2WinNumber(number)) {
      throw ArgumentError.value(number, 'number', 'not a Spin2Win number');
    }
  }

  void _place(int number, int amount) {
    _stakes[number] = stakeOn(number) + amount;
    _history.add(_Placement(number, amount));
  }

  /// Removes the history entry at [index] from its number and returns its amount.
  int _takeBack(int index) {
    final placement = _history.removeAt(index);
    final remaining = stakeOn(placement.number) - placement.amount;
    if (remaining <= 0) {
      _stakes.remove(placement.number);
    } else {
      _stakes[placement.number] = remaining;
    }
    return placement.amount;
  }

  /// When the board has just become empty and the hands are empty, picks the
  /// last chip up again (the 5 chip if none was used), so the next tap places a
  /// bet instead of silently doing nothing.
  void _restoreChipIfBoardEmpty() {
    if (isEmpty && _activeChip == null) {
      _activeChip = _lastActiveChip ?? Spin2WinChip.five;
    }
  }
}
