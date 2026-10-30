// The Lucky Card History popup: every round the player has bet on since logging in, newest first, and a
// popup with the details of one round, in the design Hasan approved for Lucky 16 Card
// (lucky_card_popup_kit.dart), with Lucky Card's own data.
//
//   LuckyCardHistoryDialog.show(context, provider: game, history: history, since: login)
//
// How it behaves did not change with the new design:
//   * each time it opens it asks [history] to read everything since [since], so the list is the
//     database's own. While the first read is on its way it says so; a failed first read says "Could
//     not load history. Tap to retry." with a RETRY button; a failed later read keeps the earlier list
//     and shows a line over it that retries when tapped; no rounds says so;
//   * it closes by itself, with a fade, the moment betting closes, and the round detail closes with
//     it. Opened while betting is already closed, it closes again at once and reads nothing;
//   * a tap outside closes either popup; every tap target is at least 48 dp; all text is at least 11
//     dp and ignores the phone's font-size setting;
//   * the click sound for a line is a hook ([onRow]) for the screen.
//
// The look: three stat boxes over the list (ROUNDS, TOTAL PLAY, TOTAL WIN), a RESULT column with the
// winning card and the bonus, each round as a card with a green or red strip, and a round detail with
// the winning card's picture.
//
// The words are in lucky_card_history_text.dart. Belongs to Lucky Card only.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/lucky_card_history_model.dart';
import '../../providers/lucky_card_history_provider.dart';
import '../../providers/lucky_card_provider.dart';
import 'lucky_card_art.dart';
import 'lucky_card_history_text.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_panel.dart';
import 'lucky_card_popup_kit.dart';

/// The barrier behind the round detail, over the list.
const Color _kDetailBarrier = Color(0x99000000);

/// The columns' shares, left to right: NO., ROUND, RESULT, PLAY, WIN.
const List<int> _kColumns = [8, 20, 24, 20, 24];

class LuckyCardHistoryDialog extends StatefulWidget {
  const LuckyCardHistoryDialog({
    super.key,
    required this.provider,
    required this.history,
    required this.since,
    this.art = const AssetLuckyCardArt(),
    this.onRow,
  });

  /// The game provider, watched so the popup can close when betting closes.
  final LuckyCardProvider provider;

  /// Where the lines come from; asked to read each time the popup opens.
  final LuckyCardHistoryProvider history;

  /// The start of this login: only rounds bet on since then are listed.
  final DateTime? since;
  final LuckyCardArt art;

  /// A line was tapped (the click sound).
  final VoidCallback? onRow;

  /// How much of the canvas the popup covers, the same as the Info popup.
  static const double widthShare = 0.8;
  static const double heightShare = 0.92;

  /// Shows the popup over the screen. Completes when it closes, for any reason.
  static Future<void> show(
    BuildContext context, {
    required LuckyCardProvider provider,
    required LuckyCardHistoryProvider history,
    required DateTime? since,
    LuckyCardArt art = const AssetLuckyCardArt(),
    VoidCallback? onOpen,
    VoidCallback? onRow,
  }) {
    onOpen?.call();
    return showLuckyCardPopup<void>(
      context,
      builder: (_) => LuckyCardHistoryDialog(provider: provider, history: history, since: since, art: art, onRow: onRow),
    );
  }

  @override
  State<LuckyCardHistoryDialog> createState() => _LuckyCardHistoryDialogState();
}

class _LuckyCardHistoryDialogState extends State<LuckyCardHistoryDialog>
    with LuckyCardClosesWhenBettingCloses<LuckyCardHistoryDialog> {
  @override
  LuckyCardProvider get bettingProvider => widget.provider;

  /// False until the read has been asked for, so the first frame says "loading", not "empty".
  bool _readAsked = false;

  @override
  void initState() {
    super.initState();
    // After the first frame, never during the build, because reading notifies its listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.provider.isLocked) return;
      _read();
    });
  }

  void _read() {
    _readAsked = true;
    widget.history.loadSession(since: widget.since);
  }

  void _openDetail(LuckyCardHistoryEntry entry, int serial) {
    widget.onRow?.call();
    showLuckyCardPopup<void>(
      context,
      barrierColor: _kDetailBarrier,
      builder: (_) => _LuckyCardHistoryDetail(provider: widget.provider, entry: entry, serial: serial, art: widget.art),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = LuckyCardLayout.of(media.size);
    final canvas = layout.canvasRect;
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: kLuckyCardHistorySemanticsLabel,
        child: Center(
          child: SizedBox(
            key: const ValueKey('history-dialog'),
            width: canvas.width * LuckyCardHistoryDialog.widthShare,
            height: canvas.height * LuckyCardHistoryDialog.heightShare,
            child: Material(
              type: MaterialType.transparency,
              child: LuckyCardPopupFrame(
                layout: layout,
                child: Column(
                  children: [
                    LuckyCardPopupHeader(
                      layout: layout,
                      title: kLuckyCardHistoryTitle,
                      close:
                          LuckyCardCloseButton(key: const ValueKey('history-close'), layout: layout, onTap: closeByHand),
                    ),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: widget.history,
                        builder: (context, _) => _body(layout),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// What fills the popup under its title: the list, or the one thing to say instead.
  Widget _body(LuckyCardLayout layout) {
    final history = widget.history;
    final records = history.records;
    if (records.isEmpty) {
      final error = history.error;
      if (error != null) {
        return _message(layout, key: 'history-error', text: error, retry: true);
      }
      if (history.isLoading || !_readAsked) {
        return _message(layout, key: 'history-loading', text: kLuckyCardHistoryLoading, spinner: true);
      }
      return _message(layout, key: 'history-empty', text: kLuckyCardHistoryEmpty);
    }
    return _list(layout, records);
  }

  /// One short thing to say in the middle of the popup: loading, an error with RETRY, or empty.
  Widget _message(LuckyCardLayout layout,
      {required String key, required String text, bool spinner = false, bool retry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinner)
            Padding(
              padding: EdgeInsets.only(bottom: layout.dp(24)),
              child: SizedBox(
                width: layout.fontSize(60, minDp: 28),
                height: layout.fontSize(60, minDp: 28),
                child: const CircularProgressIndicator(strokeWidth: 3, color: kLuckyCardGold),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: layout.dp(36)),
            child: luckyCardPopupText(
              text,
              layout,
              key: ValueKey(key),
              family: 'DMSans',
              units: 36,
              height: 1.3,
              maxLines: null,
              align: TextAlign.center,
              color: kLuckyCardCream.withValues(alpha: 0.8),
            ),
          ),
          if (retry)
            Padding(
              padding: EdgeInsets.only(top: layout.dp(24)),
              child: _retryButton(layout),
            ),
        ],
      ),
    );
  }

  Widget _retryButton(LuckyCardLayout layout) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: kLuckyCardHistoryRetry,
      onTap: _read,
      child: GestureDetector(
        key: const ValueKey('history-retry'),
        behavior: HitTestBehavior.opaque,
        onTap: _read,
        child: Container(
          constraints: const BoxConstraints(minWidth: kLuckyCardMinTapDp * 2, minHeight: kLuckyCardMinTapDp),
          padding: EdgeInsets.symmetric(horizontal: layout.dp(40)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: kLuckyCardGoldFace,
              stops: kLuckyCardGoldFaceStops,
            ),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: luckyCardPopupText(
              kLuckyCardHistoryRetry,
              layout,
              weight: FontWeight.w700,
              units: 34,
              spacing: 0.1,
              color: kLuckyCardPopupInk,
            ),
          ),
        ),
      ),
    );
  }

  /// One stat box: the label at the left, the figure at the right.
  Widget _stat(LuckyCardLayout layout, String key, String label, String value, Color color) {
    return Expanded(
      child: Container(
        key: ValueKey(key),
        padding: EdgeInsets.symmetric(horizontal: layout.dp(18), vertical: layout.dp(10)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(layout.dp(16)),
          color: Colors.black.withValues(alpha: 0.38),
          border: Border.all(color: kLuckyCardGold.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            luckyCardPopupText(label, layout,
                units: 24, spacing: layout.isTablet ? 0.06 : 0.16, color: kLuckyCardCream.withValues(alpha: 0.7)),
            SizedBox(width: layout.dp(8)),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: luckyCardPopupText(value, layout, weight: FontWeight.w700, units: 40, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The list: the stat boxes, the headings, the rounds and the hint at the foot.
  Widget _list(LuckyCardLayout layout, List<LuckyCardHistoryEntry> records) {
    final history = widget.history;
    final side = layout.dp(30);
    Widget heading(int column, String text, {TextAlign align = TextAlign.left}) => Expanded(
          flex: _kColumns[column],
          child: Text(
            text,
            maxLines: 1,
            textAlign: align,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Oswald',
              fontWeight: FontWeight.w600,
              fontSize: layout.fontSize(26),
              letterSpacing: layout.fontSize(26) * 0.16,
              color: kLuckyCardGold,
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: Row(
            children: [
              _stat(layout, 'history-stat-rounds', kLuckyCardHistoryRoundsStat, '${records.length}', kLuckyCardCream),
              SizedBox(width: layout.dp(14)),
              _stat(layout, 'history-total-play', kLuckyCardHistoryPlayStat, luckyCardGrouped(history.totalStake),
                  kLuckyCardCream),
              SizedBox(width: layout.dp(14)),
              _stat(layout, 'history-total-win', kLuckyCardHistoryWinStat, luckyCardGrouped(history.totalPayout),
                  kLuckyCardGoldBright),
            ],
          ),
        ),
        if (history.error != null)
          Semantics(
            button: true,
            excludeSemantics: true,
            label: kLuckyCardHistoryStale,
            onTap: _read,
            child: GestureDetector(
              key: const ValueKey('history-stale'),
              behavior: HitTestBehavior.opaque,
              onTap: _read,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kLuckyCardMinTapDp),
                child: Center(
                  child: luckyCardPopupText(
                    kLuckyCardHistoryStale,
                    layout,
                    family: 'DMSans',
                    units: 28,
                    color: kLuckyCardAlert,
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              side + math.max(layout.dp(10), 3.0) + layout.dp(22), layout.dp(12), side + layout.dp(22), layout.dp(6)),
          child: Row(
            children: [
              heading(0, kLuckyCardHistoryNoHeader),
              heading(1, kLuckyCardHistoryRoundHeader),
              heading(2, kLuckyCardHistoryResultHeader),
              heading(3, kLuckyCardHistoryPlayHeader, align: TextAlign.right),
              heading(4, kLuckyCardHistoryWinHeader, align: TextAlign.right),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            child: ListView.separated(
              key: const ValueKey('history-list'),
              padding: EdgeInsets.symmetric(horizontal: side),
              itemCount: records.length,
              separatorBuilder: (_, __) => SizedBox(height: layout.dp(10)),
              itemBuilder: (context, i) => _LuckyCardHistoryRow(
                key: ValueKey('history-row-$i'),
                layout: layout,
                art: widget.art,
                entry: records[i],
                serial: i + 1,
                onTap: () => _openDetail(records[i], i + 1),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: layout.dp(8)),
          child: luckyCardPopupText(
            kLuckyCardHistoryHint,
            layout,
            family: 'DMSans',
            units: 24,
            align: TextAlign.center,
            color: kLuckyCardCream.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// One round in the list, a card: a strip (green for a win, red for a loss), then NO., ROUND, RESULT,
/// PLAY and WIN. The whole card is the tap area, at least 48 dp tall.
class _LuckyCardHistoryRow extends StatelessWidget {
  const _LuckyCardHistoryRow({
    super.key,
    required this.layout,
    required this.art,
    required this.entry,
    required this.serial,
    required this.onTap,
  });

  final LuckyCardLayout layout;
  final LuckyCardArt art;
  final LuckyCardHistoryEntry entry;
  final int serial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final won = e.won;
    final radius = BorderRadius.circular(layout.dp(16));
    final strip = math.max(layout.dp(10), 3.0);
    Widget cell(int column, Widget child, {Alignment align = Alignment.centerLeft}) => Expanded(
          flex: _kColumns[column],
          child: Align(alignment: align, child: FittedBox(fit: BoxFit.scaleDown, alignment: align, child: child)),
        );
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: luckyCardHistoryRowSemantics(e, serial),
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: math.max(layout.dp(112), kLuckyCardMinTapDp)),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: won
                  ? const [Color(0x333CAA50), Color(0x003CAA50)]
                  : [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.02)],
            ),
            border: Border.all(
              color: won ? const Color(0x737CE08A) : kLuckyCardGold.withValues(alpha: 0.22),
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: ValueKey('history-strip-${serial - 1}'),
                    width: strip,
                    decoration: BoxDecoration(
                      color: won ? null : kLuckyCardLossRed,
                      gradient: won
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF9CFFA8), Color(0xFF2FB24A)],
                            )
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: layout.dp(22), vertical: layout.dp(10)),
                      child: Row(
                        children: [
                          cell(
                            0,
                            luckyCardPopupText('$serial', layout,
                                weight: FontWeight.w600, units: 30, color: kLuckyCardCream.withValues(alpha: 0.7)),
                          ),
                          cell(1, luckyCardPopupText('${e.roundNumber}', layout, units: 32)),
                          cell(
                            2,
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LuckyCardMiniCard(layout: layout, art: art, card: e.winningCard),
                                SizedBox(width: layout.dp(12)),
                                LuckyCardBonusPill(layout: layout, bonus: e.bonusMultiplier),
                              ],
                            ),
                          ),
                          cell(
                            3,
                            luckyCardPopupText(luckyCardHistoryPlayText(e), layout, weight: FontWeight.w600, units: 34),
                            align: Alignment.centerRight,
                          ),
                          cell(
                            4,
                            luckyCardPopupText(
                              luckyCardHistoryWinText(e),
                              layout,
                              weight: FontWeight.w700,
                              units: 38,
                              color: won ? kLuckyCardWin : kLuckyCardCream.withValues(alpha: 0.45),
                            ),
                            align: Alignment.centerRight,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The popup with the details of one round. It closes by itself when betting closes, even though the
/// History popup is under it.
class _LuckyCardHistoryDetail extends StatefulWidget {
  const _LuckyCardHistoryDetail({required this.provider, required this.entry, required this.serial, required this.art});

  final LuckyCardProvider provider;
  final LuckyCardHistoryEntry entry;
  final int serial;
  final LuckyCardArt art;

  @override
  State<_LuckyCardHistoryDetail> createState() => _LuckyCardHistoryDetailState();
}

class _LuckyCardHistoryDetailState extends State<_LuckyCardHistoryDetail>
    with LuckyCardClosesWhenBettingCloses<_LuckyCardHistoryDetail> {
  @override
  LuckyCardProvider get bettingProvider => widget.provider;

  /// The winning card's picture with its gold ring and the bonus pill on its corner. The picture is
  /// Lucky Card's own near-square shape (549 x 556).
  Widget _heroCard(LuckyCardLayout layout, double dpr) {
    final e = widget.entry;
    final height = math.max(layout.dp(120), 56.0);
    final width = height * 549 / 556;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(layout.dp(10)),
            border: Border.all(color: kLuckyCardGoldBright, width: math.max(layout.dp(4), 1.5)),
          ),
          child: Image(
            key: ValueKey('history-detail-card-${e.winningCard.key}'),
            image:
                widget.art.image(LuckyCardArtKey.card(e.winningCard), cacheWidth: LuckyCardLayout.cacheWidth(width, dpr)),
            width: width,
            height: height,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),
        ),
        Positioned(
          right: -layout.dp(14),
          top: -layout.dp(14),
          // The dark backing keeps the outlined N readable over the card's white corner.
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(layout.dp(40)),
              color: const Color(0xF2140208),
            ),
            child: LuckyCardBonusPill(
                key: const ValueKey('history-detail-bonus'), layout: layout, bonus: e.bonusMultiplier, units: 30),
          ),
        ),
      ],
    );
  }

  /// The big line beside the card: WIN over +560 COINS, or NO WIN.
  Widget _heroText(LuckyCardLayout layout) {
    final e = widget.entry;
    if (!e.won) {
      return luckyCardPopupText(
        'NO WIN',
        layout,
        key: const ValueKey('history-detail-headline'),
        weight: FontWeight.w700,
        units: 72,
        color: kLuckyCardAlert,
      );
    }
    return Column(
      key: const ValueKey('history-detail-headline'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        luckyCardPopupText('WIN', layout, weight: FontWeight.w600, units: 30, spacing: 0.2, color: kLuckyCardWin),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              luckyCardPopupText(
                '+${luckyCardGrouped(e.payout)}',
                layout,
                key: const ValueKey('history-detail-amount'),
                weight: FontWeight.w700,
                units: 88,
                color: kLuckyCardWin,
                shadows: [Shadow(color: kLuckyCardWin.withValues(alpha: 0.6), blurRadius: layout.dp(18))],
              ),
              SizedBox(width: layout.dp(10)),
              luckyCardPopupText('COINS', layout, units: 35, color: kLuckyCardCream.withValues(alpha: 0.75)),
            ],
          ),
        ),
      ],
    );
  }

  /// One of the four facts.
  Widget _fact(LuckyCardLayout layout, (String, String) line) {
    final bonus = line.$1 == 'BONUS';
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: layout.dp(18), vertical: layout.dp(12)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(layout.dp(14)),
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: kLuckyCardGold.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            luckyCardPopupText(line.$1, layout, units: 23, color: kLuckyCardCream.withValues(alpha: 0.65)),
            SizedBox(height: layout.dp(3)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: luckyCardPopupText(
                line.$2,
                layout,
                key: ValueKey('history-detail-${line.$1}'),
                weight: FontWeight.w600,
                units: 34,
                color: bonus ? kLuckyCardGoldBright : kLuckyCardCream,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = LuckyCardLayout.of(media.size);
    final canvas = layout.canvasRect;
    final dpr = media.devicePixelRatio;
    final e = widget.entry;
    final won = e.won;
    final lines = luckyCardHistoryDetailLines(e);
    final gap = layout.dp(14);
    final tint = won ? const Color(0xFF3CAA50) : const Color(0xFFAA3C3C);

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Round ${e.roundNumber} details',
        child: Center(
          child: ConstrainedBox(
            key: const ValueKey('history-detail'),
            // A fixed share of the canvas wide, as tall as its lines need up to the canvas's height.
            constraints: BoxConstraints(
              minWidth: canvas.width * 0.56,
              maxWidth: canvas.width * 0.56,
              maxHeight: canvas.height * 0.92,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: LuckyCardPopupFrame(
                layout: layout,
                glow: won ? 2 : 1,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(layout.dp(30), layout.dp(12), layout.dp(18), layout.dp(26)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: layout.dp(24), vertical: layout.dp(6)),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: kLuckyCardGoldFace,
                                stops: kLuckyCardGoldFaceStops,
                              ),
                            ),
                            child: luckyCardPopupText(
                              luckyCardHistoryDetailBadge(widget.serial),
                              layout,
                              key: const ValueKey('history-detail-badge'),
                              weight: FontWeight.w700,
                              units: 30,
                              color: const Color(0xFF1A0505),
                            ),
                          ),
                          const Spacer(),
                          LuckyCardCloseButton(
                            key: const ValueKey('history-detail-close'),
                            layout: layout,
                            units: 84,
                            onTap: closeByHand,
                          ),
                        ],
                      ),
                      SizedBox(height: gap),
                      Padding(
                        padding: EdgeInsets.only(right: layout.dp(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              key: const ValueKey('history-detail-hero'),
                              padding: EdgeInsets.symmetric(horizontal: layout.dp(28), vertical: layout.dp(20)),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(layout.dp(20)),
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [tint.withValues(alpha: 0.28), tint.withValues(alpha: 0.06)],
                                ),
                                border: Border.all(
                                  color: won ? const Color(0x8C7CE08A) : kLuckyCardAlert.withValues(alpha: 0.55),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _heroCard(layout, dpr),
                                  SizedBox(width: layout.dp(36)),
                                  Expanded(child: _heroText(layout)),
                                ],
                              ),
                            ),
                            SizedBox(height: gap),
                            for (var i = 0; i < lines.length; i += 2) ...[
                              if (i > 0) SizedBox(height: gap),
                              Row(
                                children: [
                                  _fact(layout, lines[i]),
                                  SizedBox(width: gap),
                                  _fact(layout, lines[i + 1]),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
