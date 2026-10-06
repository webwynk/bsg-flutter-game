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

/// The Info button works only while betting is open and nothing is playing.
bool luckyCardInfoEnabledOf(LuckyCardProvider provider) => !provider.isLocked && !provider.isSequenceRunning;

/// What the top bar shows.
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

/// The top bar, linked to the provider. The three callbacks and [soundOn] come from
/// the screen.
class LuckyCardTopBarBinding extends StatelessWidget {
  const LuckyCardTopBarBinding({
    super.key,
    required this.provider,
    required this.layout,
    required this.soundOn,
    this.onExit,
    this.onToggleSound,
    this.onInfo,
  });

  final LuckyCardProvider provider;
  final LuckyCardLayout layout;
  final bool soundOn;
  final VoidCallback? onExit;
  final VoidCallback? onToggleSound;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return LuckyCardSelector<LuckyCardTopBarSnapshot>(
      provider: provider,
      select: LuckyCardTopBarSnapshot.of,
      builder: (context, s) => LuckyCardTopBar(
        layout: layout,
        balance: s.balance,
        countdown: s.countdown,
        soundOn: soundOn,
        infoEnabled: s.infoEnabled,
        onExit: onExit,
        onToggleSound: onToggleSound,
        onInfo: onInfo,
      ),
    );
  }
}

/// The status strip, linked to the provider and to the one-line [notice] (App Step 8c).
class LuckyCardStatusBinding extends StatelessWidget {
  const LuckyCardStatusBinding({super.key, required this.provider, required this.layout, this.notice});

  final LuckyCardProvider provider;
  final LuckyCardLayout layout;
  final LuckyCardNotice? notice;

  @override
  Widget build(BuildContext context) {
    return LuckyCardSelector<LuckyCardStatusMode>(
      provider: provider,
      select: luckyCardStatusModeOf,
      builder: (context, mode) {
        final notice = this.notice;
        if (notice == null) return LuckyCardStatusStrip(layout: layout, mode: mode);
        return ListenableBuilder(
          listenable: notice,
          builder: (context, _) =>
              LuckyCardStatusStrip(layout: layout, mode: mode, notice: notice.text, noticeImportant: notice.important),
        );
      },
    );
  }
}

/// PLAY, WIN, the limits and the results, placed in the side zone.
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
          rect: inSide(layout.limitsPanel),
          child: LuckyCardLimitsPanel(key: const ValueKey('limits'), layout: layout),
        ),
        Positioned.fromRect(
          rect: inSide(layout.playCell),
          child: LuckyCardSelector<int>(
            provider: provider,
            select: (p) => p.total,
            builder: (context, play) => LuckyCardAmountCell(key: const ValueKey('play'), layout: layout, label: 'PLAY', value: luckyCardGrouped(play)),
          ),
        ),
        Positioned.fromRect(
          rect: inSide(layout.winCell),
          child: LuckyCardSelector<int>(
            provider: provider,
            select: (p) => p.lastOutcome?.payout ?? 0,
            builder: (context, win) => LuckyCardAmountCell(
              key: const ValueKey('win'),
              layout: layout,
              label: 'WIN',
              value: luckyCardWinText(win),
              valueColor: win > 0 ? kLuckyCardWin : kLuckyCardCream,
              highlighted: win > 0,
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
