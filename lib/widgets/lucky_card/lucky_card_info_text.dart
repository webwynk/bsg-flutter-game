// The words of the Lucky Card Info dialog: the RULES tab and the PAYOUTS tab.
//
// Written as plain functions, not as fixed strings, so that every number in them is read
// from the game's own rules (the smallest and largest stake, the lock mark, the chips, the
// payout multiplier) and cannot drift from the game. The meaning comes from the spec
// (§3 betting, §4 payout, §5 bonus, §8 limits, §9 controls); the wording is shaped for the rule
// cards of the design Hasan approved for Lucky 16 Card.
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

/// The popup's title and the titles of the two tabs.
const String kLuckyCardInfoTitle = 'HOW TO PLAY';
const String kLuckyCardRulesTab = 'RULES';
const String kLuckyCardPayoutsTab = 'PAYOUTS';

/// "5, 10, 50, 100 or 500".
String luckyCardChipList() {
  final amounts = [for (final c in LuckyCardChip.values) '${c.amount}'];
  return '${amounts.sublist(0, amounts.length - 1).join(', ')} or ${amounts.last}';
}

/// The six rule cards of the RULES tab, heading then body, in order.
List<({String heading, String body})> luckyCardRulesLines() => [
      (
        heading: 'PICK A CHIP',
        body: 'Choose ${luckyCardChipList()}, then tap a card to put the chip on it.',
      ),
      (
        heading: 'BET A SUIT OR A RANK',
        body: 'A suit bar puts the chip on that suit\'s 3 cards. Jacks, Queens or Kings puts it on that rank\'s 4 cards.',
      ),
      (
        heading: '${LuckyCard.all.length} CARDS',
        body: 'The Jack, Queen and King of each suit. Chips add up, from $kLuckyCardMinStake to '
            '${luckyCardGrouped(kLuckyCardMaxStake)} on each card.',
      ),
      (
        heading: 'BETTING CLOSES AT $kLuckyCardLockCountdown',
        body: 'When the countdown reaches $kLuckyCardLockCountdown, betting closes and the wheel spins.',
      ),
      (
        heading: 'THE WHEEL PICKS',
        body: 'One winning card and a bonus: N (no bonus) or 2X up to 10X.',
      ),
      (
        heading: 'ONLY THE WINNER PAYS',
        body: 'The winning card pays $kLuckyCardPayoutMultiplier times its chips, times the bonus. Other chips are lost.',
      ),
    ];

/// The heading of the seventh rule card, and its four buttons: the label and one line on what it does.
const String kLuckyCardButtonsHeading = 'THE BUTTONS';
const List<({String label, String body})> kLuckyCardButtonLines = [
  (label: 'DOUBLE', body: 'Doubles every chip'),
  (label: 'REBET', body: 'Repeats your last bet'),
  (label: 'CLEAR', body: 'Gives every chip back'),
  (label: 'REMOVE', body: 'Then tap a card to take its chips back'),
];

/// The small heading over the formula.
const String kLuckyCardPayoutKicker = 'HOW A WIN IS PAID';

/// The worked example.
String luckyCardExampleText() {
  final plain = luckyCardPayoutFor(kLuckyCardExampleStake, 1);
  final bonus = luckyCardPayoutFor(kLuckyCardExampleStake, kLuckyCardExampleBonus);
  return 'Example: you put $kLuckyCardExampleStake on the Queen of Spades. If it wins you get '
      '${luckyCardGrouped(plain)}. With a ${kLuckyCardExampleBonus}X bonus you get ${luckyCardGrouped(bonus)}.';
}

/// The title over the table.
String luckyCardTableTitle() => 'WHAT A STAKE OF $kLuckyCardExampleStake WINS';

/// The table: the bonus label and what the example stake wins with it, N then 2X to 10X.
List<({String bonus, int win})> luckyCardPayoutTable() => [
      for (var bonus = 1; bonus <= 10; bonus++)
        (bonus: luckyCardBonusLabel(bonus), win: luckyCardPayoutFor(kLuckyCardExampleStake, bonus)),
    ];

/// The sentence about the smallest and the largest stake.
String luckyCardLimitsText() =>
    'The smallest stake on a card, $kLuckyCardMinStake, wins ${luckyCardGrouped(luckyCardPayoutFor(kLuckyCardMinStake, 1))}. '
    'The largest, ${luckyCardGrouped(kLuckyCardMaxStake)}, wins ${luckyCardGrouped(luckyCardPayoutFor(kLuckyCardMaxStake, 1))} '
    'before the bonus, and the bonus multiplies it.';
