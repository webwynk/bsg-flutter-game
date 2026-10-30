// The words of the Lucky Card History popup and of its round detail popup.
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

/// The three stat boxes.
const String kLuckyCardHistoryRoundsStat = 'ROUNDS';
const String kLuckyCardHistoryPlayStat = 'TOTAL PLAY';
const String kLuckyCardHistoryWinStat = 'TOTAL WIN';

/// The column headings.
const String kLuckyCardHistoryNoHeader = 'NO.';
const String kLuckyCardHistoryRoundHeader = 'ROUND';
const String kLuckyCardHistoryResultHeader = 'RESULT';
const String kLuckyCardHistoryPlayHeader = 'PLAY';
const String kLuckyCardHistoryWinHeader = 'WIN';

/// The line at the foot of the list.
const String kLuckyCardHistoryHint = 'This session, newest first. Tap a round for details.';

/// Shown while the first read is on its way.
const String kLuckyCardHistoryLoading = 'Loading session history...';

/// Shown when the player has not played a round since logging in.
const String kLuckyCardHistoryEmpty = 'No rounds in this session yet';

/// The button under a failed first read.
const String kLuckyCardHistoryRetry = 'RETRY';

/// The line over the list when a later read failed but an earlier list is still shown.
const String kLuckyCardHistoryStale = 'Could not refresh the history. Tap to retry.';

/// What the screen reader says for the popup.
const String kLuckyCardHistorySemanticsLabel = 'Game history';

/// The round detail's badge: the line's number in the list.
String luckyCardHistoryDetailBadge(int serial) => 'NO. $serial';

/// The PLAY cell: what the player staked in that round.
String luckyCardHistoryPlayText(LuckyCardHistoryEntry e) => luckyCardGrouped(e.stake);

/// The WIN cell: "+2,500" for a win, "0" for a loss, as the game screen's WIN readout writes it.
String luckyCardHistoryWinText(LuckyCardHistoryEntry e) => luckyCardWinText(e.payout);

/// A card in words, for example "Queen of Spades".
String luckyCardCardWords(LuckyCard card) => '${card.rank.label} of ${card.suit.label}';

/// The round detail's four facts, label then value, in the order they are shown.
List<(String, String)> luckyCardHistoryDetailLines(LuckyCardHistoryEntry e) => [
      ('ROUND', '${e.roundNumber}'),
      ('WINNING CARD', luckyCardCardWords(e.winningCard)),
      ('BONUS', luckyCardBonusLabel(e.bonusMultiplier)),
      ('TOTAL BET', '${luckyCardGrouped(e.stake)} coins'),
    ];

/// What a screen reader says for one line of the list.
String luckyCardHistoryRowSemantics(LuckyCardHistoryEntry e, int serial) =>
    'Line $serial, round ${e.roundNumber}, played ${luckyCardGrouped(e.stake)}, '
    '${e.won ? 'won ${luckyCardGrouped(e.payout)}' : 'no win'}. Tap for details.';
