// Connects the board to the Lucky 16 Card provider.
//
// It listens to the provider, makes a snapshot of the board, and redraws only when
// the snapshot changes: the provider also notifies once a second for the countdown,
// and that must not redraw 24 pieces with pictures. It passes the player's taps to
// the provider (`tapCard`, `tapSuit`, `tapRank`), which moves the coins, and hands
// the screen what it needs to place the board:
//
//   Lucky16BoardBinding(
//     provider: provider,
//     art: const AssetLucky16Art(),
//     builder: (context, zones) => Lucky16Canvas(grid: zones.grid, rankColumn: zones.rankColumn, ...),
//   )
//
// Copied from lib/widgets/lucky_card/lucky_card_board_binding.dart (Lucky Card); the names changed, and the
// counts are Lucky 16 Card's (16 cards, 4 on a suit bar, 4 rank selectors A, J, Q, K).
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky16_board.dart';
import '../../models/lucky16_models.dart';
import '../../providers/lucky16_provider.dart';
import 'lucky16_art.dart';
import 'lucky16_board_snapshot.dart';
import 'lucky16_board_view.dart';

/// The board as the provider holds it right now.
Lucky16BoardSnapshot lucky16SnapshotOf(Lucky16Provider provider) => Lucky16BoardSnapshot.fromStakes(
      {for (final card in Lucky16Card.all) card: provider.stakeOn(card)},
      isLocked: provider.isLocked,
      activeChip: provider.activeChip,
    );

class Lucky16BoardBinding extends StatefulWidget {
  const Lucky16BoardBinding({
    super.key,
    required this.provider,
    required this.art,
    required this.builder,
    this.onRefused,
    this.onTapped,
  });

  final Lucky16Provider provider;
  final Lucky16Art art;

  /// Builds the screen around the board; [zones] has the grid and the rank column.
  final Widget Function(BuildContext context, Lucky16BoardZones zones) builder;

  /// Told when any tap on the board was refused, and why.
  final Lucky16BoardRefused? onRefused;

  /// Told of every tap on a card, a suit bar or a rank selector: what was tapped
  /// ([Lucky16CardTarget], [Lucky16SuitTarget] or [Lucky16RankTarget]) and what the board
  /// did. The screen makes the tap's sound and the light haptic when it changed anything: the
  /// number-select sound for a single card, the chip click for a bar.
  final void Function(Lucky16BoardTarget target, Lucky16BoardResult result)? onTapped;

  @override
  State<Lucky16BoardBinding> createState() => _Lucky16BoardBindingState();
}

class _Lucky16BoardBindingState extends State<Lucky16BoardBinding> {
  late Lucky16BoardSnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = lucky16SnapshotOf(widget.provider);
    widget.provider.addListener(_onProviderChanged);
  }

  @override
  void didUpdateWidget(Lucky16BoardBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      oldWidget.provider.removeListener(_onProviderChanged);
      widget.provider.addListener(_onProviderChanged);
      _snapshot = lucky16SnapshotOf(widget.provider);
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  Lucky16BoardResult _told(Lucky16BoardTarget target, Lucky16BoardResult result) {
    widget.onTapped?.call(target, result);
    return result;
  }

  void _onProviderChanged() {
    final next = lucky16SnapshotOf(widget.provider);
    if (next != _snapshot) setState(() => _snapshot = next);
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    return widget.builder(
      context,
      Lucky16BoardZones(
        art: widget.art,
        snapshot: _snapshot,
        onTapCard: (card) => _told(Lucky16CardTarget(card), provider.tapCard(card)),
        onTapSuit: (suit) => _told(Lucky16SuitTarget(suit), provider.tapSuit(suit)),
        onTapRank: (rank) => _told(Lucky16RankTarget(rank), provider.tapRank(rank)),
        onRefused: widget.onRefused,
      ),
    );
  }
}
