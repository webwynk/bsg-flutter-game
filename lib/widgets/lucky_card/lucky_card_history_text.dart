// The words of the Lucky Card History dialog and of its row popup.
//
// Written as plain functions and constants, not buried in the widgets, so that every
// number is formatted in one place the same way the game screen's own readouts format it
// (the WIN figure is [luckyCardWinText], the grouped numbers are [luckyCardGrouped]) and so
// the wording can be tested without drawing anything.
//
// Plain letters only: the fonts have no card-suit symbols, so the winning card is written
// as words ("Queen of Spades"), never as "Q" followed by a suit symbol. A test checks that
// every word here is plain ASCII.
//
// Belongs to Lucky Card only.

import '../../models/lucky_card_history_model.dart';
import '../../models/lucky_card_models.dart';
import 'lucky_card_panel.dart';
import 'lucky_card_readouts.dart';

/// The dialog's title.
const String kLuckyCardHistoryTitle = 'HISTORY';

/// The four column headings: the number of the line, the round, what was staked, what was won.
const String kLuckyCardHistoryNoHeader = 'NO.';
const String kLuckyCardHistoryRoundHeader = 'ROUND';
const String kLuckyCardHistoryPlayHeader = 'PLAY';
const String kLuckyCardHistoryWinHeader = 'WIN';

/// The footer label: the sum of every line since login.
const String kLuckyCardHistoryTotalLabel = 'TOTAL SESSION';

/// Shown while the first read is on its way.
const String kLuckyCardHistoryLoading = 'Loading session history...';

/// Shown when the player has not played a round since logging in.
const String kLuckyCardHistoryEmpty = 'No rounds in this session yet';

/// The button under a failed first read.
const String kLuckyCardHistoryRetry = 'RETRY';

/// The line over the table when a later read failed but an earlier list is still shown.
const String kLuckyCardHistoryStale = 'Could not refresh the history. Tap to retry.';

/// What the screen reader says for the dialog and its close button.
const String kLuckyCardHistorySemanticsLabel = 'Game history';

/// The row popup's heading badge: the line's number in the table.
String luckyCardHistoryDetailBadge(int serial) => 'NO. $serial';

/// The PLAY cell: what the player staked in that round.
String luckyCardHistoryPlayText(LuckyCardHistoryEntry e) => luckyCardGrouped(e.stake);

/// The WIN cell: "+2,500" for a win, "0" for a loss, as the game screen's WIN readout writes it.
String luckyCardHistoryWinText(LuckyCardHistoryEntry e) => luckyCardWinText(e.payout);

/// The small tag under a WIN amount: "2X" to "10X". Empty for a round with no bonus, which
/// is shown as a single line, as Triple Chance does.
String luckyCardHistoryBonusTag(LuckyCardHistoryEntry e) =>
    e.bonusMultiplier > 1 ? luckyCardBonusLabel(e.bonusMultiplier) : '';

/// A card in words, for example "Queen of Spades".
String luckyCardCardWords(LuckyCard card) => '${card.rank.label} of ${card.suit.label}';

/// The popup's headline: "WIN +2,400,000 coins" or "NO WIN".
String luckyCardHistoryHeadline(LuckyCardHistoryEntry e) =>
    e.won ? 'WIN ${luckyCardWinText(e.payout)} coins' : 'NO WIN';

/// The popup's detail lines, label then value, in the order they are shown.
List<(String, String)> luckyCardHistoryDetailLines(LuckyCardHistoryEntry e) => [
      ('Round', '${e.roundNumber}'),
      ('Winning card', luckyCardCardWords(e.winningCard)),
      ('Bonus', luckyCardBonusLabel(e.bonusMultiplier)),
      ('Total Bet', '${luckyCardGrouped(e.stake)} coins'),
      ('Total Win', '${luckyCardGrouped(e.payout)} coins'),
    ];

/// What a screen reader says for one table line.
String luckyCardHistoryRowSemantics(LuckyCardHistoryEntry e, int serial) =>
    'Line $serial, round ${e.roundNumber}, played ${luckyCardGrouped(e.stake)}, '
    '${e.won ? 'won ${luckyCardGrouped(e.payout)}' : 'no win'}. Tap for details.';
