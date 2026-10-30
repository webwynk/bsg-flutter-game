// The words of the Lucky 16 Card Info popup: the RULES tab and the PAYOUTS tab.
//
// Written as plain functions, not as fixed strings, so that every number in them is read from the
// game's own rules (the smallest and largest stake, the lock mark, the chips, the payout multiplier)
// and cannot drift from the game. The shape is Lucky Card's lucky_card_info_text.dart; the wording is
// Lucky 16 Card's own, from the approved popup design.
//
// [lucky16PayoutFor] only fills in this table of examples. The money itself is never worked out on the
// phone: a real win is the server's payout (`lucky16_settle_round`).
//
// Plain letters only: the fonts have no card-suit symbols, so suits are written as words.
//
// Belongs to Lucky 16 Card only.

import '../../models/lucky16_board.dart';
import '../../models/lucky16_models.dart';
import '../../services/lucky16_round_clock.dart';
import 'lucky16_panel.dart';

/// A winning card pays this many times the chips on it, before the bonus (the server's rule).
const int kLucky16PayoutMultiplier = 14;

/// The stake used in the payout example and the table.
const int kLucky16ExampleStake = 10;

/// The bonus used in the payout example.
const int kLucky16ExampleBonus = 4;

/// What a stake would pay, for the Info popup's examples: stake x 14 x the bonus (1 is "N", no bonus).
int lucky16PayoutFor(int stake, int bonus) => stake * kLucky16PayoutMultiplier * (bonus < 1 ? 1 : bonus);

/// The popup's title and the titles of the two tabs.
const String kLucky16InfoTitle = 'HOW TO PLAY';
const String kLucky16RulesTab = 'RULES';
const String kLucky16PayoutsTab = 'PAYOUTS';

/// "5, 10, 50, 100 or 500".
String lucky16ChipList() {
  final amounts = [for (final c in Lucky16Chip.values) '${c.amount}'];
  return '${amounts.sublist(0, amounts.length - 1).join(', ')} or ${amounts.last}';
}

/// The six rule cards of the RULES tab, heading then body, in order.
List<({String heading, String body})> lucky16RulesLines() => [
      (
        heading: 'PICK A CHIP',
        body: 'Choose ${lucky16ChipList()}, then tap a card to put the chip on it.',
      ),
      (
        heading: 'BET A SUIT OR A RANK',
        body: 'A suit bar puts the chip on that suit\'s 4 cards. A, J, Q or K puts it on that rank\'s 4 cards.',
      ),
      (
        heading: '${Lucky16Card.all.length} CARDS',
        body: 'The Ace, Jack, Queen and King of each suit. Chips add up, from $kLucky16MinStake to '
            '${lucky16Grouped(kLucky16MaxStake)} on each card.',
      ),
      (
        heading: 'BETTING CLOSES AT $kLucky16LockCountdown',
        body: 'When the countdown reaches $kLucky16LockCountdown, betting closes and the wheel spins.',
      ),
      (
        heading: 'THE WHEEL PICKS',
        body: 'One winning card and a bonus: N (no bonus) or 2X up to 10X.',
      ),
      (
        heading: 'ONLY THE WINNER PAYS',
        body: 'The winning card pays $kLucky16PayoutMultiplier times its chips, times the bonus. Other chips are lost.',
      ),
    ];

/// The heading of the seventh rule card, and its four buttons: the label and one line on what it does.
const String kLucky16ButtonsHeading = 'THE BUTTONS';
const List<({String label, String body})> kLucky16ButtonLines = [
  (label: 'DOUBLE', body: 'Doubles every chip'),
  (label: 'REBET', body: 'Repeats your last bet'),
  (label: 'CLEAR', body: 'Gives every chip back'),
  (label: 'REMOVE', body: 'Then tap a card to take its chips back'),
];

/// The small heading over the formula.
const String kLucky16PayoutKicker = 'HOW A WIN IS PAID';

/// The worked example.
String lucky16ExampleText() {
  final plain = lucky16PayoutFor(kLucky16ExampleStake, 1);
  final bonus = lucky16PayoutFor(kLucky16ExampleStake, kLucky16ExampleBonus);
  return 'Example: you put $kLucky16ExampleStake on the Ace of Spades. If it wins you get '
      '${lucky16Grouped(plain)}. With a ${kLucky16ExampleBonus}X bonus you get ${lucky16Grouped(bonus)}.';
}

/// The title over the table.
String lucky16TableTitle() => 'WHAT A STAKE OF $kLucky16ExampleStake WINS';

/// The table: the bonus label and what the example stake wins with it, N then 2X to 10X.
List<({String bonus, int win})> lucky16PayoutTable() => [
      for (var bonus = 1; bonus <= 10; bonus++)
        (bonus: lucky16BonusLabel(bonus), win: lucky16PayoutFor(kLucky16ExampleStake, bonus)),
    ];

/// The sentence about the smallest and the largest stake.
String lucky16LimitsText() =>
    'The smallest stake on a card, $kLucky16MinStake, wins ${lucky16Grouped(lucky16PayoutFor(kLucky16MinStake, 1))}. '
    'The largest, ${lucky16Grouped(kLucky16MaxStake)}, wins ${lucky16Grouped(lucky16PayoutFor(kLucky16MaxStake, 1))} '
    'before the bonus, and the bonus multiplies it.';
