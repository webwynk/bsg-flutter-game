// The words of the Lucky Card Info dialog: the RULES tab and the PAYOUTS tab.
//
// Written as plain functions, not as fixed strings, so that every number in them is read
// from the game's own rules (the smallest and largest stake, the lock mark, the chips, the
// payout multiplier) and cannot drift from the game. The wording comes from the spec
// (§3 betting, §4 payout, §5 bonus, §8 limits, §9 controls) and was reviewed by the user in a
// screenshot (spec §17Z).
//
// Plain letters only: the fonts have no card-suit symbols, so suits are written as words.
//
// Belongs to Lucky Card only.

import '../../models/lucky_card_board.dart';
import '../../models/lucky_card_models.dart';
import '../../services/lucky_card_round_clock.dart';
import 'lucky_card_panel.dart';

/// A winning card pays this many times the chips on it (before the bonus). Spec §4.
const int kLuckyCardPayoutMultiplier = 10;

/// The stake used in the payout example and the table.
const int kLuckyCardExampleStake = 10;

/// The bonus used in the payout example.
const int kLuckyCardExampleBonus = 4;

/// What a winning stake pays: the stake times 10 times the bonus (1 is "N", no bonus).
int luckyCardPayoutFor(int stake, int bonus) => stake * kLuckyCardPayoutMultiplier * (bonus < 1 ? 1 : bonus);

/// The titles of the two tabs.
const String kLuckyCardRulesTab = 'RULES';
const String kLuckyCardPayoutsTab = 'PAYOUTS';

/// "5, 10, 50, 100 or 500".
String luckyCardChipList() {
  final amounts = [for (final c in LuckyCardChip.values) '${c.amount}'];
  return '${amounts.sublist(0, amounts.length - 1).join(', ')} or ${amounts.last}';
}

/// The numbered rules of the RULES tab.
List<String> luckyCardRulesLines() => [
      'Pick a chip (${luckyCardChipList()}), then tap a card to put the chip on it.',
      'Tap a suit bar (Hearts, Spades, Diamonds, Clubs) to put the chip on that suit\'s 3 cards. '
          'Tap Jacks, Queens or Kings to put it on that rank\'s 4 cards.',
      'There are 12 cards: the Jack, Queen and King of each suit. Chips on a card add up, '
          'from $kLuckyCardMinStake up to ${luckyCardGrouped(kLuckyCardMaxStake)} on each card.',
      'Betting closes when the countdown reaches $kLuckyCardLockCountdown. Then the wheel spins.',
      'The wheel picks one winning card and a bonus: N (no bonus) or 2X up to 10X.',
      'Only the winning card pays. Chips on the other cards are lost.',
      'DOUBLE doubles every chip. REBET repeats your last bet. CLEAR gives every chip back. '
          'REMOVE puts the chip down; then tap a card to take its chips back.',
    ];

/// The sentence that says how a win is worked out.
String luckyCardPayoutRule() =>
    'A winning card pays $kLuckyCardPayoutMultiplier times the chips on it, multiplied by the bonus.';

/// The worked example.
String luckyCardExampleText() {
  final plain = luckyCardPayoutFor(kLuckyCardExampleStake, 1);
  final bonus = luckyCardPayoutFor(kLuckyCardExampleStake, kLuckyCardExampleBonus);
  return 'Example: you put $kLuckyCardExampleStake on the Queen of Spades. If it wins you get '
      '${luckyCardGrouped(plain)}. With a ${kLuckyCardExampleBonus}X bonus you get ${luckyCardGrouped(bonus)}.';
}

/// The title over the table.
String luckyCardTableTitle() => 'What a stake of $kLuckyCardExampleStake wins';

/// The table: the bonus label and what the example stake wins with it, N then 2X to 10X.
List<({String bonus, int win})> luckyCardPayoutTable() => [
      for (var bonus = 1; bonus <= 10; bonus++)
        (bonus: luckyCardBonusLabel(bonus), win: luckyCardPayoutFor(kLuckyCardExampleStake, bonus)),
    ];

/// The sentence about the smallest and the largest stake.
String luckyCardLimitsText() =>
    'The smallest stake on a card, $kLuckyCardMinStake, wins ${luckyCardGrouped(luckyCardPayoutFor(kLuckyCardMinStake, 1))}. '
    'The largest, ${luckyCardGrouped(kLuckyCardMaxStake)}, wins ${luckyCardGrouped(luckyCardPayoutFor(kLuckyCardMaxStake, 1))} '
    'before the bonus; the bonus is added on top.';
