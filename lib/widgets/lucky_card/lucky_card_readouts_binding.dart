// Connects the top bar, the status strip and the side column's readouts to the
// Lucky Card provider.
//
// The provider notifies for every chip, every second of the countdown and every step
// of a result. Each binding here reads only what its piece shows into a small value,
// and redraws only when that value changes: the countdown's tick redraws the top bar
// and nothing else; the results are redrawn only when a round is added.
//
//   LuckyCardCanvas(
//     topBar: (context, layout) => LuckyCardTopBarBinding(provider: p, layout: layout, soundOn: ..., onExit: ..., onInfo: ...),
//     status: (context, layout) => LuckyCardStatusBinding(provider: p, layout: layout),
//     side:   (context, layout) => Stack(children: [
//       LuckyCardSideReadouts(provider: p, layout: layout, art: art),
//       ...the chip rail and the buttons (App Step 7b)...
//     ]),
//   )
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky_card_models.dart';
import '../../providers/lucky_card_provider.dart';
import 'lucky_card_art.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_messages.dart';
import 'lucky_card_palette.dart';
import 'lucky_card_panel.dart';
import 'lucky_card_readouts.dart';
import 'lucky_card_status_strip.dart';
import 'lucky_card_top_bar.dart';

/// Which words the status strip shows right now.
LuckyCardStatusMode luckyCardStatusModeOf(LuckyCardProvider provider) {
  if (provider.isSequenceRunning || provider.stage != LuckyCardStage.none) {
    return LuckyCardStatusMode.noMoreSteady;
  }
  if (!provider.isLocked) return LuckyCardStatusMode.placeChips;
  return luckyCardCountdownUrgent(provider.countdown)
      ? LuckyCardStatusMode.noMoreFlashing
      : LuckyCardStatusMode.noMoreSteady;
}

/// The Info and History buttons work only while betting is open and nothing is playing.
bool luckyCardInfoEnabledOf(LuckyCardProvider provider) => !provider.isLocked && !provider.isSequenceRunning;

/// The words in the middle of the header, and whether they are a warning (drawn in red).
///
/// This is exactly the rule the strip under the board used before the header took the job
/// over (the reference design has no such strip): a refusal line is shown while betting is
/// open, a line about the balance is important enough to be shown even once it has closed,
/// and otherwise the round's own status is shown.
({String text, Color color, bool isFlashing}) luckyCardHeaderStatus({
  required LuckyCardStatusMode mode,
  String? notice,
  bool noticeImportant = false,
}) {
  final closed = mode != LuckyCardStatusMode.placeChips;
  final showNotice = notice != null && (!closed || noticeImportant);
  return (
    text: showNotice ? notice : luckyCardStatusText(mode),
    // A refusal or balance notice is amber, "no more play" is red, otherwise the bar's own
    // cream -- the same three-way distinction the strip under the board used to draw, colour
    // for colour the same meaning.
    color: showNotice ? kDesignNoticeText : (closed ? kDesignAlertText : kDesignStatusText),
    // The last five seconds fade the line in and out, whatever it says, as the strip did.
    isFlashing: mode == LuckyCardStatusMode.noMoreFlashing,
  );
}

/// What the top bar shows, apart from its status words (kept out of this snapshot
/// deliberately: see [_LuckyCardHeaderStatusSlot]).
@immutable
class LuckyCardTopBarSnapshot {
  const LuckyCardTopBarSnapshot({required this.balance, required this.countdown, required this.infoEnabled});

  factory LuckyCardTopBarSnapshot.of(LuckyCardProvider p) => LuckyCardTopBarSnapshot(
        balance: p.balance,
        countdown: p.countdown,
        infoEnabled: luckyCardInfoEnabledOf(p),
      );

  final int balance;
  final int countdown;
  final bool infoEnabled;

  @override
  bool operator ==(Object other) =>
      other is LuckyCardTopBarSnapshot &&
      other.balance == balance &&
      other.countdown == countdown &&
      other.infoEnabled == infoEnabled;

  @override
  int get hashCode => Object.hash(balance, countdown, infoEnabled);
}

/// What the results panel shows: the finished rounds, newest first. Two snapshots
/// are equal when they hold the same rounds with the same bonuses.
@immutable
class LuckyCardResultsSnapshot {
  const LuckyCardResultsSnapshot(this.history);

  factory LuckyCardResultsSnapshot.of(LuckyCardProvider p) => LuckyCardResultsSnapshot(p.history);

  final List<LuckyCardRecentRound> history;

  @override
  bool operator ==(Object other) {
    if (other is! LuckyCardResultsSnapshot || other.history.length != history.length) return false;
    for (var i = 0; i < history.length; i++) {
      if (other.history[i].roundId != history[i].roundId ||
          other.history[i].bonusMultiplier != history[i].bonusMultiplier) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(history.length, history.isEmpty ? null : history.first.roundId);
}

/// Listens to [provider], reduces it to a [T] with [select], and rebuilds only when
/// the [T] changes.
class LuckyCardSelector<T> extends StatefulWidget {
  const LuckyCardSelector({super.key, required this.provider, required this.select, required this.builder});

  final LuckyCardProvider provider;
  final T Function(LuckyCardProvider provider) select;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<LuckyCardSelector<T>> createState() => _LuckyCardSelectorState<T>();
}

class _LuckyCardSelectorState<T> extends State<LuckyCardSelector<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.select(widget.provider);
    widget.provider.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(LuckyCardSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      oldWidget.provider.removeListener(_onChanged);
      widget.provider.addListener(_onChanged);
    }
    _value = widget.select(widget.provider);
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final next = widget.select(widget.provider);
    if (next != _value) setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}

/// The top bar, linked to the provider. The four callbacks and [soundOn] come from
/// the screen.
class LuckyCardTopBarBinding extends StatelessWidget {
  const LuckyCardTopBarBinding({
    super.key,
    required this.provider,
    required this.layout,
    required this.art,
    required this.soundOn,
    this.bleed = EdgeInsets.zero,
    this.onExit,
    this.onToggleSound,
    this.onInfo,
    this.onHistory,
    this.notice,
  });

  final LuckyCardProvider provider;
  final LuckyCardLayout layout;
  final LuckyCardArt art;
  final bool soundOn;

  /// The phone's safe-area insets, which the bar's paint reaches into (see [LuckyCardTopBar.bleed]).
  final EdgeInsets bleed;
  final VoidCallback? onExit;
  final VoidCallback? onToggleSound;
  final VoidCallback? onInfo;
  final VoidCallback? onHistory;

  /// The one-line refusal or warning (App Step 8c). The design has no strip under the board,
  /// so the header shows these in place of the round's status for as long as they last.
  final LuckyCardNotice? notice;

  @override
  Widget build(BuildContext context) {
    // Built once here, not inside the selector's own builder below: its Element then
    // persists across every balance/countdown-driven rebuild of this whole header, so a chip
    // placed or the countdown ticking does not touch it, exactly as the separate strip under
    // the board never used to either (see _LuckyCardHeaderStatusSlot).
    final statusWidget = _LuckyCardHeaderStatusSlot(provider: provider, layout: layout, notice: notice);
    return LuckyCardSelector<LuckyCardTopBarSnapshot>(
      provider: provider,
      select: LuckyCardTopBarSnapshot.of,
      builder: (context, s) => LuckyCardTopBar(
        layout: layout,
        art: art,
        bleed: bleed,
        balance: s.balance,
        countdown: s.countdown,
        soundOn: soundOn,
        infoEnabled: s.infoEnabled,
        statusWidget: statusWidget,
        onExit: onExit,
        onToggleSound: onToggleSound,
        onInfo: onInfo,
        onHistory: onHistory,
      ),
    );
  }
}

/// The header's status words, read and redrawn independently of everything else in the bar:
/// the round's own status mode, or a refusal/balance notice while one is showing. Its own
/// [LuckyCardSelector] means a chip placed (which only moves the balance) leaves this exact
/// widget instance untouched, the same discipline the old separate strip under the board had.
class _LuckyCardHeaderStatusSlot extends StatelessWidget {
  const _LuckyCardHeaderStatusSlot({required this.provider, required this.layout, this.notice});

  final LuckyCardProvider provider;
  final LuckyCardLayout layout;
  final LuckyCardNotice? notice;

  @override
  Widget build(BuildContext context) {
    return LuckyCardSelector<LuckyCardStatusMode>(
      provider: provider,
      select: luckyCardStatusModeOf,
      builder: (context, mode) {
        Widget line(({String text, Color color, bool isFlashing}) status) => LuckyCardStatusLine(
              key: const ValueKey('top-status'),
              text: status.text,
              size: layout.designStatusFont,
              color: status.color,
              flashing: status.isFlashing,
            );
        final notice = this.notice;
        if (notice == null) return line(luckyCardHeaderStatus(mode: mode));
        return ListenableBuilder(
          listenable: notice,
          builder: (context, _) => line(luckyCardHeaderStatus(mode: mode, notice: notice.text, noticeImportant: notice.important)),
        );
      },
    );
  }
}

/// TOTAL BET, WIN and the results, placed in the side zone.
class LuckyCardSideReadouts extends StatelessWidget {
  const LuckyCardSideReadouts({super.key, required this.provider, required this.layout, required this.art});

  final LuckyCardProvider provider;
  final LuckyCardLayout layout;
  final LuckyCardArt art;

  @override
  Widget build(BuildContext context) {
    final side = layout.side;
    Rect inSide(Rect r) => layout.within(side, r);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: inSide(layout.totalBetCell),
          child: LuckyCardSelector<int>(
            provider: provider,
            select: (p) => p.total,
            builder: (context, total) => LuckyCardTotalCell(
              key: const ValueKey('total-bet'),
              layout: layout,
              label: 'Play',
              value: luckyCardGrouped(total),
              fill: kDesignTotalBetFill,
              labelColor: kDesignTotalBetLabel,
              under: kDesignTotalBetUnder,
            ),
          ),
        ),
        Positioned.fromRect(
          rect: inSide(layout.winCell),
          child: LuckyCardSelector<int>(
            provider: provider,
            select: (p) => p.lastOutcome?.payout ?? 0,
            builder: (context, win) => LuckyCardTotalCell(
              key: const ValueKey('win'),
              layout: layout,
              label: 'Win',
              value: luckyCardWinText(win),
              fill: kDesignWinFill,
              labelColor: kDesignWinLabel,
              under: kDesignWinUnder,
            ),
          ),
        ),
        Positioned.fromRect(
          rect: inSide(layout.resultsPanel),
          child: LuckyCardSelector<LuckyCardResultsSnapshot>(
            provider: provider,
            select: LuckyCardResultsSnapshot.of,
            builder: (context, s) => LuckyCardResultsPanel(layout: layout, art: art, history: s.history),
          ),
        ),
      ],
    );
  }
}
