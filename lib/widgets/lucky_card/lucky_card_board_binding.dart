// Connects the board to the Lucky Card provider.
//
// It listens to the provider, makes a snapshot of the board, and redraws only when
// the snapshot changes: the provider also notifies once a second for the countdown,
// and that must not redraw 19 pieces with pictures. It passes the player's taps to
// the provider (`tapCard`, `tapSuit`, `tapRank`), which moves the coins, and hands
// the screen what it needs to place the board:
//
//   LuckyCardBoardBinding(
//     provider: provider,
//     art: const AssetLuckyCardArt(),
//     builder: (context, zones) => LuckyCardCanvas(grid: zones.grid, rankColumn: zones.rankColumn, ...),
//   )
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky_card_board.dart';
import '../../models/lucky_card_models.dart';
import '../../providers/lucky_card_provider.dart';
import 'lucky_card_art.dart';
import 'lucky_card_board_snapshot.dart';
import 'lucky_card_board_view.dart';

/// The board as the provider holds it right now.
LuckyCardBoardSnapshot luckyCardSnapshotOf(LuckyCardProvider provider) =>
    LuckyCardBoardSnapshot.fromStakes(
      {for (final card in LuckyCard.all) card: provider.stakeOn(card)},
      isLocked: provider.isLocked,
      activeChip: provider.activeChip,
    );

class LuckyCardBoardBinding extends StatefulWidget {
  const LuckyCardBoardBinding({
    super.key,
    required this.provider,
    required this.art,
    required this.builder,
    this.onRefused,
    this.onTapped,
  });

  final LuckyCardProvider provider;
  final LuckyCardArt art;

  /// Builds the screen around the board; [zones] has the grid and the rank column.
  final Widget Function(BuildContext context, LuckyCardBoardZones zones) builder;

  /// Told when any tap on the board was refused, and why.
  final LuckyCardBoardRefused? onRefused;

  /// Told of every tap on a card, a suit bar or a rank selector, with what the board did
  /// (the chip click and the light haptic of App Step 8b are made when it changed anything).
  final void Function(LuckyCardBoardResult result)? onTapped;

  @override
  State<LuckyCardBoardBinding> createState() => _LuckyCardBoardBindingState();
}

class _LuckyCardBoardBindingState extends State<LuckyCardBoardBinding> {
  late LuckyCardBoardSnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = luckyCardSnapshotOf(widget.provider);
    widget.provider.addListener(_onProviderChanged);
  }

  @override
  void didUpdateWidget(LuckyCardBoardBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      oldWidget.provider.removeListener(_onProviderChanged);
      widget.provider.addListener(_onProviderChanged);
      _snapshot = luckyCardSnapshotOf(widget.provider);
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  LuckyCardBoardResult _told(LuckyCardBoardResult result) {
    widget.onTapped?.call(result);
    return result;
  }

  void _onProviderChanged() {
    final next = luckyCardSnapshotOf(widget.provider);
    if (next != _snapshot) setState(() => _snapshot = next);
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    return widget.builder(
      context,
      LuckyCardBoardZones(
        art: widget.art,
        snapshot: _snapshot,
        onTapCard: (card) => _told(provider.tapCard(card)),
        onTapSuit: (suit) => _told(provider.tapSuit(suit)),
        onTapRank: (rank) => _told(provider.tapRank(rank)),
        onRefused: widget.onRefused,
      ),
    );
  }
}
