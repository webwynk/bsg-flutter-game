// Connects the bet panel's readouts -- PLAY, WIN and the twelve latest results -- to the Lucky 16
// Card provider.
//
// Copied from the side-column half of lib/widgets/lucky_card/lucky_card_readouts_binding.dart (Lucky
// Card), phone arrangement only; the header half is in lucky16_top_bar_binding.dart. Each piece reads
// only what it shows into a small value and redraws only when that value changes: a tick of the
// countdown redraws none of them, and the results are redrawn only when a round is added.
//
//   * PLAY is what is on the board this round ([Lucky16Provider.total]).
//   * WIN is what the last round paid ([Lucky16Provider.lastOutcome]), "+560" for a win, "0" otherwise.
//   * The results are the provider's history, newest first, as history cards.
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky16_models.dart';
import '../../providers/lucky16_provider.dart';
import 'lucky16_art.dart';
import 'lucky16_layout.dart';
import 'lucky16_palette.dart';
import 'lucky16_panel.dart';
import 'lucky16_readouts.dart';
import 'lucky16_top_bar_binding.dart';

/// What the results panel shows: the finished rounds, newest first. Two snapshots are equal when they
/// hold the same rounds with the same bonuses.
@immutable
class Lucky16ResultsSnapshot {
  const Lucky16ResultsSnapshot(this.history);

  factory Lucky16ResultsSnapshot.of(Lucky16Provider p) => Lucky16ResultsSnapshot(p.history);

  final List<Lucky16RecentRound> history;

  @override
  bool operator ==(Object other) {
    if (other is! Lucky16ResultsSnapshot || other.history.length != history.length) return false;
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

/// PLAY, WIN and the results, placed in the bet panel's zone. On the desktop that zone is the wheel's
/// column and holds only PLAY and WIN: the results are a row of their own ([Lucky16ResultsBarBinding]).
class Lucky16SideReadouts extends StatelessWidget {
  const Lucky16SideReadouts({super.key, required this.provider, required this.layout, required this.art});

  final Lucky16Provider provider;
  final Lucky16Layout layout;
  final Lucky16Art art;

  @override
  Widget build(BuildContext context) {
    final side = layout.side;
    Rect inSide(Rect r) => layout.within(side, r);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: inSide(layout.totalBetCell),
          child: Lucky16Selector<int>(
            provider: provider,
            select: (p) => p.total,
            builder: (context, total) => Lucky16TotalCell(
              key: const ValueKey('total-bet'),
              layout: layout,
              label: 'Play',
              value: lucky16Grouped(total),
              fill: kLucky16TotalBetFill,
              labelColor: kLucky16TotalBetLabel,
              under: kLucky16TotalBetUnder,
            ),
          ),
        ),
        Positioned.fromRect(
          rect: inSide(layout.winCell),
          child: Lucky16Selector<int>(
            provider: provider,
            select: (p) => p.lastOutcome?.payout ?? 0,
            builder: (context, win) => Lucky16TotalCell(
              key: const ValueKey('win'),
              layout: layout,
              label: 'Win',
              value: lucky16WinText(win),
              fill: kLucky16WinFill,
              labelColor: kLucky16WinLabel,
              under: kLucky16WinUnder,
            ),
          ),
        ),
        if (!layout.isDesktop)
          Positioned.fromRect(
            rect: inSide(layout.resultsPanel),
            child: Lucky16ResultsBarBinding(provider: provider, layout: layout, art: art),
          ),
      ],
    );
  }
}

/// The history cards, linked to the provider: the results box of the bet panel.
class Lucky16ResultsBarBinding extends StatelessWidget {
  const Lucky16ResultsBarBinding({super.key, required this.provider, required this.layout, required this.art});

  final Lucky16Provider provider;
  final Lucky16Layout layout;
  final Lucky16Art art;

  @override
  Widget build(BuildContext context) {
    return Lucky16Selector<Lucky16ResultsSnapshot>(
      provider: provider,
      select: Lucky16ResultsSnapshot.of,
      builder: (context, s) => Lucky16ResultsPanel(layout: layout, art: art, history: s.history),
    );
  }
}
