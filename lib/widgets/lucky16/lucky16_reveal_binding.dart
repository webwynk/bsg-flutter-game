// Connects the reveal to the Lucky 16 Card provider: the big card (phase 4) and the coins and win popup
// (phase 5, a full-screen overlay). They only play what the provider holds; nothing here decides or
// times anything.
//
// Copied from lib/widgets/lucky_card/lucky_card_reveal_binding.dart (Lucky Card); only the names changed.
//
//   Lucky16Canvas(
//     grid:       (context, layout) => Lucky16WheelBinding(provider: p, layout: layout),
//     rankColumn: (context, layout) => Lucky16RevealColumn(provider: p, layout: layout, art: art),
//     overlay:    (context, layout) => Lucky16RevealOverlay(provider: p, layout: layout, art: art),
//   )
//
// THE OVERLAY mounts Triple Chance's coin fountain (imported unchanged, read-only, as Lucky Card does)
// while the provider's `showCoinFx` is true, bursting from the wheel's centre, and the win popup while
// the provider's `popup` is set. The provider decides both exactly as Lucky Card's: the coins only for
// a win, from the reveal until the popup opens 1.5 s later; the popup for a win, with the server's
// payout, until the round ends 4 s after the reveal. A loser or a spectator has neither.
//
// The card is given the rank column's zone but stands right of the wheel ([Lucky16Layout.revealCard]),
// partly over the grid's part of the board, which is empty while the wheel is shown.
//
// It starts shuffling when the provider's stage becomes spinning (one shuffle per round, also for a
// screen that opens mid-spin) and settles on the winner when the provider reveals it (`cardRevealed`):
// never before the hub shows the card. A screen that opens after the reveal shows the winner at once.
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import '../../models/lucky16_models.dart';
import '../../providers/lucky16_provider.dart';
import '../overlays/coin_fountain.dart';
import 'lucky16_art.dart';
import 'lucky16_layout.dart';
import 'lucky16_reveal_card.dart';
import 'lucky16_win_popup.dart';

/// What a screen reader announces when the winner is shown.
String lucky16WinnerAnnouncement(Lucky16Card card, int bonus) =>
    'Winning card: ${card.rank.label} of ${card.suit.label}${bonus > 1 ? ', ${bonus}X' : ''}';

class Lucky16RevealColumn extends StatefulWidget {
  const Lucky16RevealColumn({
    super.key,
    required this.provider,
    required this.layout,
    required this.art,
    this.onFlip,
    this.onCardRevealed,
  });

  final Lucky16Provider provider;
  final Lucky16Layout layout;
  final Lucky16Art art;

  /// A face flips over (the tick of the shuffle, for a later phase's sound).
  final VoidCallback? onFlip;

  /// The winner is shown: the card has settled.
  final VoidCallback? onCardRevealed;

  @override
  State<Lucky16RevealColumn> createState() => _Lucky16RevealColumnState();
}

class _Lucky16RevealColumnState extends State<Lucky16RevealColumn> {
  final GlobalKey<Lucky16RevealCardState> _card = GlobalKey<Lucky16RevealCardState>();

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
  void didUpdateWidget(Lucky16RevealColumn oldWidget) {
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

    if (provider.stage == Lucky16Stage.spinning && _spunRoundId != target.roundId) {
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
      setState(() => _announcement = lucky16WinnerAnnouncement(target.winningCard, target.bonusMultiplier));
      widget.onCardRevealed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: layout.within(layout.rankColumn, layout.revealCard),
          child: Lucky16RevealCard(
            key: _card,
            layout: layout,
            art: widget.art,
            onFlip: widget.onFlip,
            semanticsLabel: _announcement,
          ),
        ),
      ],
    );
  }
}

class Lucky16RevealOverlay extends StatefulWidget {
  const Lucky16RevealOverlay({
    super.key,
    required this.provider,
    required this.layout,
    required this.art,
    this.onCoinsStart,
    this.onPopupOpen,
  });

  final Lucky16Provider provider;
  final Lucky16Layout layout;
  final Lucky16Art art;

  /// The coins start to fly (for a later phase's sound).
  final VoidCallback? onCoinsStart;

  /// The win popup opens (for a later phase's sound).
  final VoidCallback? onPopupOpen;

  /// How many coins a second, as in Triple Chance's and Lucky Card's big-win effect.
  static const double coinsPerSecond = 60;

  @override
  State<Lucky16RevealOverlay> createState() => _Lucky16RevealOverlayState();
}

class _Lucky16RevealOverlayState extends State<Lucky16RevealOverlay> {
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
  void didUpdateWidget(Lucky16RevealOverlay oldWidget) {
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
                  coinsPerSecond: Lucky16RevealOverlay.coinsPerSecond,
                  originFraction: Offset(center.dx / screen.width, center.dy / screen.height),
                ),
              ),
            if (popup != null)
              Lucky16WinPopup(key: const ValueKey('win-popup'), outcome: popup, layout: layout, art: widget.art),
          ],
        );
      },
    );
  }
}

/// Loads the sixteen card faces (at the width the reveal draws them) and the win popup's frame into the
/// image cache, so nothing pops in.
Future<void> precacheLucky16Reveal(BuildContext context, Lucky16Layout layout, Lucky16Art art) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return Future.wait([
    for (final card in Lucky16Card.all)
      precacheImage(art.image(Lucky16ArtKey.card(card), cacheWidth: layout.revealCacheWidth(dpr)), context),
    precacheImage(art.image(Lucky16ArtKey.winPopup, cacheWidth: layout.winPopupCacheWidth(dpr)), context),
  ]);
}
