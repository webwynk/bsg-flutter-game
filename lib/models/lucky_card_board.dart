// The Lucky Card betting board: the 12 chip amounts, the undo list and the
// Rebet memory, with every rule for changing them.
//
// Pure Dart. It never touches the player's wallet, sound, vibration, timers or
// the network. Each action takes the coins the player currently has and answers
// with a [LuckyCardBoardResult]: how many coins the player's balance must go
// down (or up) by, which cards changed, and why anything could not be done. The
// provider built in the next step applies that to the real balance, so the
// money arithmetic lives in one small place that is tested on its own.
//
// Behaviour follows Triple Chance's board (game_provider.dart, read 2026-10-06)
// wherever the spec says so (§9) or leaves it open, and the user chose "the
// Triple Chance way" for the four open points on 2026-10-06:
//   1. A shortcut that cannot fully fit places what fits, in order, and says why.
//   2. Remove undoes ONE chip at a time, so a shortcut that placed three chips
//      needs three presses.
//   3. With no chip selected, tapping a suit bar or rank selector removes the
//      most recent chip from each of its cards.
//   4. When the board becomes empty and no chip is held, the last chip used is
//      held again (the 5 chip if none was used).
// The deliberate differences from Triple Chance are listed on [rebet] and on
// the "rebetUsed" rule below.
//
// Belongs to Lucky Card only; it reuses nothing from Triple Chance.

import 'lucky_card_models.dart';

/// The smallest stake a card can hold (spec §8). Also the smallest chip, so a
/// chip placed from the board can never fall below it.
const int kLuckyCardMinStake = 5;

/// The most one card can hold (spec §8). The database enforces it too.
const int kLuckyCardMaxStake = 50000;

/// The five chips, smallest first.
enum LuckyCardChip {
  five(5),
  ten(10),
  fifty(50),
  hundred(100),
  fiveHundred(500);

  const LuckyCardChip(this.amount);

  /// Coins this chip adds to a card.
  final int amount;

  /// The chip worth exactly [value], or null if there is none.
  static LuckyCardChip? fromAmount(int value) {
    for (final chip in values) {
      if (chip.amount == value) return chip;
    }
    return null;
  }
}

/// Why an action did nothing, or only part of what was asked.
enum LuckyCardBoardIssue {
  /// Betting is closed (the countdown reached its lock mark).
  locked,

  /// A chip is needed to place a bet and none is held.
  noChipSelected,

  /// Removing by tapping needs the hands empty; a chip is held.
  chipIsSelected,

  /// The player does not have enough coins for the chip, the double or the rebet.
  notEnoughCoins,

  /// At least one card could not take more because it would pass the maximum.
  cardAtMaximum,

  /// There was nothing for the action to work on (an empty board, or no saved
  /// bet to repeat).
  nothingToDo,

  /// There is no chip to take back from that card, or from the board.
  nothingToRemove,

  /// Rebet only restores a bet onto an empty board.
  boardNotEmpty,
}

/// What an action did.
class LuckyCardBoardResult {
  const LuckyCardBoardResult({
    this.coinsSpent = 0,
    this.changed = const [],
    this.issues = const {},
  });

  /// How much the player's balance must go DOWN by. Negative means coins go back
  /// to the player: placing a chip is +50, removing it is -50.
  final int coinsSpent;

  /// The cards whose amount changed, in board order.
  final List<LuckyCard> changed;

  /// Everything that stopped the action from being complete. Empty on a clean
  /// success. A partial success (a shortcut that placed some cards) has both a
  /// non-empty [changed] and a non-empty [issues].
  final Set<LuckyCardBoardIssue> issues;

  /// True when at least one card changed.
  bool get changedAnything => changed.isNotEmpty;

  /// True when the action did everything that was asked.
  bool get isClean => issues.isEmpty;
}

/// One chip placed: kept in order so Remove can take them back one at a time.
class _Placement {
  _Placement(this.card, this.amount);

  final LuckyCard card;
  int amount;
}

/// The board. See the file comment.
class LuckyCardBoard {
  final Map<LuckyCard, int> _stakes = {};
  final List<_Placement> _history = [];
  Map<LuckyCard, int>? _rebetSnapshot;

  // Triple Chance starts with its smallest chip held; so does Lucky Card.
  LuckyCardChip? _activeChip = LuckyCardChip.five;
  LuckyCardChip? _lastActiveChip = LuckyCardChip.five;

  /// True once a chip has been placed (or Rebet pressed) since the board was
  /// last cleared or the round last ended: the Rebet button then turns back into
  /// Double. Triple Chance sets it slightly earlier, before it knows whether
  /// anything will actually be placed; here it is set only when a chip really
  /// is, which differs only when every placement fails for lack of coins.
  bool _rebetUsed = false;

  bool _locked = false;

  // ── What the board holds ───────────────────────────────────────────────

  /// The chip held in the player's hand, or null when none is.
  LuckyCardChip? get activeChip => _activeChip;

  /// True while betting is closed: every action that changes the board refuses.
  bool get isLocked => _locked;

  /// The amount on [card].
  int stakeOn(LuckyCard card) => _stakes[card] ?? 0;

  /// The live total of a suit bar: the sum of its 3 cards.
  int suitTotal(LuckyCardSuit suit) =>
      LuckyCard.ofSuit(suit).fold(0, (sum, c) => sum + stakeOn(c));

  /// The live total of a rank selector: the sum of its 4 cards.
  int rankTotal(LuckyCardRank rank) =>
      LuckyCard.ofRank(rank).fold(0, (sum, c) => sum + stakeOn(c));

  /// The round total: the sum of the 12 cards. The 7 labels are views of the 12
  /// cards, never extra bets.
  int get total => _stakes.values.fold(0, (sum, v) => sum + v);

  /// True when no card holds anything.
  bool get isEmpty => _stakes.isEmpty;

  /// True when Remove has a chip to take back.
  bool get canRemoveLast => _history.isNotEmpty;

  /// The bet to send to the database: only the cards holding chips, in board
  /// order, as a fresh copy.
  Map<LuckyCard, int> toBetMap() => {
        for (final card in LuckyCard.all)
          if (stakeOn(card) > 0) card: stakeOn(card),
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
  LuckyCardBoardResult selectChip(LuckyCardChip chip) {
    if (_locked) return _refused(LuckyCardBoardIssue.locked);
    _activeChip = chip;
    _lastActiveChip = chip;
    return const LuckyCardBoardResult();
  }

  /// Puts the chip down without placing it, so taps remove chips instead.
  void deselectChip() => _activeChip = null;

  // ── Placing ────────────────────────────────────────────────────────────

  /// Adds the held chip to one card.
  ///
  /// Refuses for lack of coins before it checks the maximum, as Triple Chance's
  /// single-cell bet does.
  LuckyCardBoardResult placeOnCard(LuckyCard card, {required int balance}) {
    if (_locked) return _refused(LuckyCardBoardIssue.locked);
    final chip = _activeChip;
    if (chip == null) return _refused(LuckyCardBoardIssue.noChipSelected);
    if (balance < chip.amount) return _refused(LuckyCardBoardIssue.notEnoughCoins);
    if (stakeOn(card) + chip.amount > kLuckyCardMaxStake) {
      return _refused(LuckyCardBoardIssue.cardAtMaximum);
    }
    _place(card, chip.amount);
    _rebetUsed = true;
    return LuckyCardBoardResult(coinsSpent: chip.amount, changed: [card]);
  }

  /// Adds the held chip to each of [cards] (a suit bar's three, or a rank
  /// selector's four), in the order given.
  ///
  /// A card that would pass the maximum is skipped and the rest are still
  /// placed; placing stops at the first card the player can no longer afford.
  /// Both reasons are reported. This is Triple Chance's row-bet behaviour.
  LuckyCardBoardResult placeOnCards(List<LuckyCard> cards, {required int balance}) {
    if (_locked) return _refused(LuckyCardBoardIssue.locked);
    final chip = _activeChip;
    if (chip == null) return _refused(LuckyCardBoardIssue.noChipSelected);

    final fits = <LuckyCard>[];
    var skippedForMaximum = false;
    for (final card in _unique(cards)) {
      if (stakeOn(card) + chip.amount > kLuckyCardMaxStake) {
        skippedForMaximum = true;
      } else {
        fits.add(card);
      }
    }
    if (fits.isEmpty) return _refused(LuckyCardBoardIssue.cardAtMaximum);

    final placed = <LuckyCard>[];
    var spent = 0;
    var ranOutOfCoins = false;
    for (final card in fits) {
      if (balance - spent < chip.amount) {
        ranOutOfCoins = true;
        break;
      }
      _place(card, chip.amount);
      spent += chip.amount;
      placed.add(card);
    }
    if (placed.isNotEmpty) _rebetUsed = true;
    return LuckyCardBoardResult(
      coinsSpent: spent,
      changed: placed,
      issues: {
        if (ranOutOfCoins) LuckyCardBoardIssue.notEnoughCoins,
        if (skippedForMaximum) LuckyCardBoardIssue.cardAtMaximum,
      },
    );
  }

  // ── Removing ───────────────────────────────────────────────────────────

  /// Takes back the most recent chip on [card]. Only works when no chip is held
  /// (the player taps a card with empty hands to remove).
  LuckyCardBoardResult removeFromCard(LuckyCard card) =>
      removeFromCards([card]);

  /// Takes back the most recent chip from each of [cards] that holds one. Only
  /// works when no chip is held.
  LuckyCardBoardResult removeFromCards(List<LuckyCard> cards) {
    if (_locked) return _refused(LuckyCardBoardIssue.locked);
    if (_activeChip != null) return _refused(LuckyCardBoardIssue.chipIsSelected);

    final changed = <LuckyCard>[];
    var refunded = 0;
    for (final card in _unique(cards)) {
      final index = _history.lastIndexWhere((p) => p.card == card);
      if (index < 0) continue;
      refunded += _takeBack(index);
      changed.add(card);
    }
    if (changed.isEmpty) return _refused(LuckyCardBoardIssue.nothingToRemove);
    _restoreChipIfBoardEmpty();
    return LuckyCardBoardResult(coinsSpent: -refunded, changed: changed);
  }

  /// Takes back the most recently placed chip, wherever it is: the Remove
  /// button. One chip per press, so a shortcut that placed three chips needs
  /// three presses.
  LuckyCardBoardResult removeLast() {
    if (_locked) return _refused(LuckyCardBoardIssue.locked);
    if (_history.isEmpty) return _refused(LuckyCardBoardIssue.nothingToRemove);
    final card = _history.last.card;
    final refunded = _takeBack(_history.length - 1);
    _restoreChipIfBoardEmpty();
    return LuckyCardBoardResult(coinsSpent: -refunded, changed: [card]);
  }

  // ── Double, Clear, Rebet ───────────────────────────────────────────────

  /// Doubles every card that can be doubled; a card whose double would pass the
  /// maximum is left as it is and reported. If the player cannot afford the
  /// doubling of the cards that qualify, nothing at all changes.
  ///
  /// The decision for each card is made once, and the undo list is changed for
  /// exactly the cards that were doubled, so Remove can never refund more than
  /// was staked (the mismatch Triple Chance's fix F-8 corrected).
  LuckyCardBoardResult doubleStakes({required int balance}) {
    if (_locked) return _refused(LuckyCardBoardIssue.locked);
    if (isEmpty) return _refused(LuckyCardBoardIssue.nothingToDo);

    final doubled = <LuckyCard>[];
    var skippedForMaximum = false;
    var cost = 0;
    for (final card in LuckyCard.all) {
      final stake = stakeOn(card);
      if (stake == 0) continue;
      if (stake * 2 > kLuckyCardMaxStake) {
        skippedForMaximum = true;
      } else {
        doubled.add(card);
        cost += stake;
      }
    }
    if (balance < cost) return _refused(LuckyCardBoardIssue.notEnoughCoins);

    final doubledSet = doubled.toSet();
    for (final card in doubled) {
      _stakes[card] = stakeOn(card) * 2;
    }
    for (final placement in _history) {
      if (doubledSet.contains(placement.card)) placement.amount *= 2;
    }
    return LuckyCardBoardResult(
      coinsSpent: cost,
      changed: doubled,
      issues: {if (skippedForMaximum) LuckyCardBoardIssue.cardAtMaximum},
    );
  }

  /// Empties the board and gives everything back. Also lets Rebet appear again.
  LuckyCardBoardResult clear() {
    if (_locked) return _refused(LuckyCardBoardIssue.locked);
    final refunded = total;
    final changed = [for (final c in LuckyCard.all) if (stakeOn(c) > 0) c];
    _stakes.clear();
    _history.clear();
    _rebetUsed = false;
    _restoreChipIfBoardEmpty();
    return LuckyCardBoardResult(coinsSpent: -refunded, changed: changed);
  }

  /// Puts the saved bet back on an empty board.
  ///
  /// Differs from Triple Chance in one safe way: it refuses ([boardNotEmpty])
  /// unless the board is empty. Triple Chance's version would overwrite the
  /// cards it restores and lose what they held without a refund; its button is
  /// only shown on an empty board, so that path is never reached there, and
  /// here it cannot be reached at all.
  LuckyCardBoardResult rebet({required int balance}) {
    if (_locked) return _refused(LuckyCardBoardIssue.locked);
    final saved = _rebetSnapshot;
    if (saved == null || saved.isEmpty) return _refused(LuckyCardBoardIssue.nothingToDo);
    if (!isEmpty) return _refused(LuckyCardBoardIssue.boardNotEmpty);
    final cost = rebetTotal;
    if (balance < cost) return _refused(LuckyCardBoardIssue.notEnoughCoins);

    final restored = <LuckyCard>[];
    for (final card in LuckyCard.all) {
      final amount = saved[card];
      if (amount == null) continue;
      _stakes[card] = amount;
      _history.add(_Placement(card, amount));
      restored.add(card);
    }
    _rebetUsed = true;
    return LuckyCardBoardResult(coinsSpent: cost, changed: restored);
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

  LuckyCardBoardResult _refused(LuckyCardBoardIssue issue) =>
      LuckyCardBoardResult(issues: {issue});

  /// [cards] without repeats, keeping the first occurrence, so a card listed
  /// twice cannot be placed on or taken from twice by one tap.
  static List<LuckyCard> _unique(List<LuckyCard> cards) {
    final seen = <LuckyCard>{};
    return [for (final c in cards) if (seen.add(c)) c];
  }

  void _place(LuckyCard card, int amount) {
    _stakes[card] = stakeOn(card) + amount;
    _history.add(_Placement(card, amount));
  }

  /// Removes the history entry at [index] from its card and returns its amount.
  int _takeBack(int index) {
    final placement = _history.removeAt(index);
    final remaining = stakeOn(placement.card) - placement.amount;
    if (remaining <= 0) {
      _stakes.remove(placement.card);
    } else {
      _stakes[placement.card] = remaining;
    }
    return placement.amount;
  }

  /// When the board has just become empty and the hands are empty, picks the
  /// last chip up again (the 5 chip if none was used), so the next tap places a
  /// bet instead of silently doing nothing.
  void _restoreChipIfBoardEmpty() {
    if (isEmpty && _activeChip == null) {
      _activeChip = _lastActiveChip ?? LuckyCardChip.five;
    }
  }
}
