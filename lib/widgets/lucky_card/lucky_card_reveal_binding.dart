// Connects the reveal to the Lucky Card provider: the big flipping card (placed in
// the rank column's zone) and the coins and win popup (a full-screen overlay).
// They only play what the provider holds; nothing here decides or times anything.
//
//   LuckyCardCanvas(
//     grid:       (context, layout) => LuckyCardWheelBinding(provider: p, layout: layout),
//     rankColumn: (context, layout) => LuckyCardRevealColumn(provider: p, layout: layout, art: art),
//     overlay:    (context, layout) => LuckyCardRevealOverlay(provider: p, layout: layout, art: art),
//   )
//
// THE COLUMN starts shuffling when the provider's stage becomes spinning (one
// shuffle per round, also for a screen that opens mid-spin) and settles on the
// winner when the provider reveals it (`cardRevealed`): never before the hub shows
// the card. A screen that opens after the reveal shows the winner at once.
//
// THE OVERLAY mounts Triple Chance's coin fountain (imported unchanged, read-only)
// while the provider's `showCoinFx` is true, bursting from the wheel's centre, and
// the win popup while the provider's `popup` is set. A loser or a spectator has
// neither, so they see nothing here.
//
// Belongs to Lucky Card only.

import 'package:flutter/material.dart';

import '../../models/lucky_card_models.dart';
import '../../providers/lucky_card_provider.dart';
import '../overlays/coin_fountain.dart';
import 'lucky_card_art.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_reveal_card.dart';
import 'lucky_card_win_popup.dart';

/// What a screen reader announces when the winner is shown.
String luckyCardWinnerAnnouncement(LuckyCard card, int bonus) =>
    'Winning card: ${card.rank.label} of ${card.suit.label}${bonus > 1 ? ', ${bonus}X' : ''}';

class LuckyCardRevealColumn extends StatefulWidget {
  const LuckyCardRevealColumn({
    super.key,
    required this.provider,
    required this.layout,
    required this.art,
    this.onFlip,
    this.onCardRevealed,
  });

  final LuckyCardProvider provider;
  final LuckyCardLayout layout;
  final LuckyCardArt art;

  /// A face flips over (the tick of the shuffle).
  final VoidCallback? onFlip;

  /// The winner is shown: the card has settled.
  final VoidCallback? onCardRevealed;

  @override
  State<LuckyCardRevealColumn> createState() => _LuckyCardRevealColumnState();
}

class _LuckyCardRevealColumnState extends State<LuckyCardRevealColumn> {
  final GlobalKey<LuckyCardRevealCardState> _card = GlobalKey<LuckyCardRevealCardState>();

  /// The round the shuffle last ran for, and the one that last settled.
  String? _spunRoundId;
  String? _settledRoundId;
  String? _announcement;

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_follow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
  }

  @override
  void didUpdateWidget(LuckyCardRevealColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      oldWidget.provider.removeListener(_follow);
      widget.provider.addListener(_follow);
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_follow);
    super.dispose();
  }

  void _follow() {
    if (!mounted) return;
    final provider = widget.provider;
    final target = provider.spinTarget;
    final card = _card.currentState;
    if (target == null || card == null) return;

    if (provider.stage == LuckyCardStage.spinning && _spunRoundId != target.roundId) {
      _spunRoundId = target.roundId;
      card.spin(winner: target.winningCard, roundNumber: target.roundNumber);
    }
    if (provider.cardRevealed && _settledRoundId != target.roundId) {
      _settledRoundId = target.roundId;
      if (_spunRoundId == target.roundId) {
        card.settle(target.winningCard);
      } else {
        // This screen did not see the shuffle: show the winner, without one.
        _spunRoundId = target.roundId;
        card.showWinner(target.winningCard);
      }
      setState(() => _announcement = luckyCardWinnerAnnouncement(target.winningCard, target.bonusMultiplier));
      widget.onCardRevealed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuckyCardRevealCard(
      key: _card,
      layout: widget.layout,
      art: widget.art,
      onFlip: widget.onFlip,
      semanticsLabel: _announcement,
    );
  }
}

class LuckyCardRevealOverlay extends StatefulWidget {
  const LuckyCardRevealOverlay({
    super.key,
    required this.provider,
    required this.layout,
    required this.art,
    this.onCoinsStart,
    this.onPopupOpen,
  });

  final LuckyCardProvider provider;
  final LuckyCardLayout layout;
  final LuckyCardArt art;

  /// The coins start to fly.
  final VoidCallback? onCoinsStart;

  /// The win popup opens.
  final VoidCallback? onPopupOpen;

  /// How many coins a second, as in Triple Chance's big-win effect.
  static const double coinsPerSecond = 60;

  @override
  State<LuckyCardRevealOverlay> createState() => _LuckyCardRevealOverlayState();
}

class _LuckyCardRevealOverlayState extends State<LuckyCardRevealOverlay> {
  bool _coinsWere = false;
  bool _popupWas = false;

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_notice);
    _coinsWere = widget.provider.showCoinFx;
    _popupWas = widget.provider.popup != null;
  }

  @override
  void didUpdateWidget(LuckyCardRevealOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      oldWidget.provider.removeListener(_notice);
      widget.provider.addListener(_notice);
      _coinsWere = widget.provider.showCoinFx;
      _popupWas = widget.provider.popup != null;
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_notice);
    super.dispose();
  }

  /// Tells the screen the moment the coins or the popup begin.
  void _notice() {
    final coins = widget.provider.showCoinFx;
    final popup = widget.provider.popup != null;
    if (coins && !_coinsWere) widget.onCoinsStart?.call();
    if (popup && !_popupWas) widget.onPopupOpen?.call();
    _coinsWere = coins;
    _popupWas = popup;
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final screen = layout.screen;
    final center = layout.wheelCenter + layout.canvasRect.topLeft;
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final popup = widget.provider.popup;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (widget.provider.showCoinFx)
              IgnorePointer(
                child: CoinFountain(
                  key: const ValueKey('coin-fountain'),
                  autoPlay: true,
                  coinsPerSecond: LuckyCardRevealOverlay.coinsPerSecond,
                  originFraction: Offset(center.dx / screen.width, center.dy / screen.height),
                ),
              ),
            if (popup != null)
              LuckyCardWinPopup(
                key: const ValueKey('win-popup'),
                outcome: popup,
                layout: layout,
                art: widget.art,
              ),
          ],
        );
      },
    );
  }
}

/// Loads the twelve card faces (at the width the reveal draws them) and the two
/// win-popup pictures into the image cache, so nothing pops in when the screen
/// opens.
Future<void> precacheLuckyCardReveal(BuildContext context, LuckyCardLayout layout, LuckyCardArt art) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return Future.wait([
    for (final card in LuckyCard.all)
      precacheImage(art.image(LuckyCardArtKey.card(card), cacheWidth: layout.revealCacheWidth(dpr)), context),
    precacheImage(art.image(LuckyCardArtKey.winPopup, cacheWidth: layout.winPopupCacheWidth(dpr)), context),
  ]);
}
