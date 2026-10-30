// The words of the Lucky 16 Card History popup and of its round detail popup.
//
// Copied from lib/widgets/lucky_card/lucky_card_history_text.dart (Lucky Card), with the headings of the
// new design Hasan approved: the three stat boxes replace Lucky Card's TOTAL SESSION footer, and a
// RESULT column is added. The loading, empty and error words are Lucky Card's.
//
// Plain letters only: the fonts have no card-suit symbols, so a winning card is written as words
// ("Queen of Spades").
//
// Belongs to Lucky 16 Card only.

import '../../models/lucky16_history_model.dart';
import '../../models/lucky16_models.dart';
import 'lucky16_panel.dart';
import 'lucky16_readouts.dart';

/// The popup's title.
const String kLucky16HistoryTitle = 'HISTORY';

/// The three stat boxes.
const String kLucky16HistoryRoundsStat = 'ROUNDS';
const String kLucky16HistoryPlayStat = 'TOTAL PLAY';
const String kLucky16HistoryWinStat = 'TOTAL WIN';

/// The column headings.
const String kLucky16HistoryNoHeader = 'NO.';
const String kLucky16HistoryRoundHeader = 'ROUND';
const String kLucky16HistoryResultHeader = 'RESULT';
const String kLucky16HistoryPlayHeader = 'PLAY';
const String kLucky16HistoryWinHeader = 'WIN';

/// The line at the foot of the list.
const String kLucky16HistoryHint = 'This session, newest first. Tap a round for details.';

/// Shown while the first read is on its way.
const String kLucky16HistoryLoading = 'Loading session history...';

/// Shown when the player has not played a round since logging in.
const String kLucky16HistoryEmpty = 'No rounds in this session yet';

/// The button under a failed first read.
const String kLucky16HistoryRetry = 'RETRY';

/// The line over the list when a later read failed but an earlier list is still shown.
const String kLucky16HistoryStale = 'Could not refresh the history. Tap to retry.';

/// What the screen reader says for the popup.
const String kLucky16HistorySemanticsLabel = 'Game history';

/// The round detail's badge: the line's number in the list.
String lucky16HistoryDetailBadge(int serial) => 'NO. $serial';

/// The PLAY cell: what the player staked in that round.
String lucky16HistoryPlayText(Lucky16HistoryEntry e) => lucky16Grouped(e.stake);

/// The WIN cell: "+2,500" for a win, "0" for a loss, as the game screen's WIN box writes it.
String lucky16HistoryWinText(Lucky16HistoryEntry e) => lucky16WinText(e.payout);

/// A card in words, for example "Queen of Spades".
String lucky16CardWords(Lucky16Card card) => '${card.rank.label} of ${card.suit.label}';

/// The round detail's four facts, label then value, in the order they are shown.
List<(String, String)> lucky16HistoryDetailLines(Lucky16HistoryEntry e) => [
      ('ROUND', '${e.roundNumber}'),
      ('WINNING CARD', lucky16CardWords(e.winningCard)),
      ('BONUS', lucky16BonusLabel(e.bonusMultiplier)),
      ('TOTAL BET', '${lucky16Grouped(e.stake)} coins'),
    ];

/// What a screen reader says for one line of the list.
String lucky16HistoryRowSemantics(Lucky16HistoryEntry e, int serial) =>
    'Line $serial, round ${e.roundNumber}, played ${lucky16Grouped(e.stake)}, '
    '${e.won ? 'won ${lucky16Grouped(e.payout)}' : 'no win'}. Tap for details.';
