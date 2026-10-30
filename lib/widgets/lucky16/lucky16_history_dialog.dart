// The Lucky 16 Card History popup: every round the player has bet on since logging in, newest first,
// and a popup with the details of one round, in the new design Hasan approved (lucky16_popup_kit.dart).
//
//   Lucky16HistoryDialog.show(context, provider: game, history: history, since: login, art: art)
//
// It behaves exactly as Lucky Card's history dialog (lucky_card_history_dialog.dart):
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
// New in this design: three stat boxes over the list (ROUNDS, TOTAL PLAY, TOTAL WIN) in place of
// Lucky Card's TOTAL SESSION footer, a RESULT column with the winning card and the bonus, each round
// as a card with a green or red strip, and a round detail with the winning card's picture.
//
// The words are in lucky16_history_text.dart. Belongs to Lucky 16 Card only.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/lucky16_history_model.dart';
import '../../providers/lucky16_history_provider.dart';
import '../../providers/lucky16_provider.dart';
import 'lucky16_art.dart';
import 'lucky16_history_text.dart';
import 'lucky16_layout.dart';
import 'lucky16_panel.dart';
import 'lucky16_popup_kit.dart';

/// The barrier behind the round detail, over the list: Lucky Card's.
const Color _kDetailBarrier = Color(0x99000000);

/// The columns' shares, left to right: NO., ROUND, RESULT, PLAY, WIN.
const List<int> _kColumns = [8, 20, 24, 20, 24];

class Lucky16HistoryDialog extends StatefulWidget {
  const Lucky16HistoryDialog({
    super.key,
    required this.provider,
    required this.history,
    required this.since,
    required this.art,
    this.onRow,
  });

  /// The game provider, watched so the popup can close when betting closes.
  final Lucky16Provider provider;

  /// Where the lines come from; asked to read each time the popup opens.
  final Lucky16HistoryProvider history;

  /// The start of this login: only rounds bet on since then are listed.
  final DateTime? since;
  final Lucky16Art art;

  /// A line was tapped (the click sound).
  final VoidCallback? onRow;

  /// How much of the canvas the popup covers, the same as the Info popup.
  static const double widthShare = 0.8;
  static const double heightShare = 0.92;

  /// Shows the popup over the screen. Completes when it closes, for any reason.
  static Future<void> show(
    BuildContext context, {
    required Lucky16Provider provider,
    required Lucky16HistoryProvider history,
    required DateTime? since,
    required Lucky16Art art,
    VoidCallback? onOpen,
    VoidCallback? onRow,
  }) {
    onOpen?.call();
    return showLucky16Popup<void>(
      context,
      builder: (_) => Lucky16HistoryDialog(provider: provider, history: history, since: since, art: art, onRow: onRow),
    );
  }

  @override
  State<Lucky16HistoryDialog> createState() => _Lucky16HistoryDialogState();
}

class _Lucky16HistoryDialogState extends State<Lucky16HistoryDialog>
    with Lucky16ClosesWhenBettingCloses<Lucky16HistoryDialog> {
  @override
  Lucky16Provider get bettingProvider => widget.provider;

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

  void _openDetail(Lucky16HistoryEntry entry, int serial) {
    widget.onRow?.call();
    showLucky16Popup<void>(
      context,
      barrierColor: _kDetailBarrier,
      builder: (_) => _Lucky16HistoryDetail(provider: widget.provider, entry: entry, serial: serial, art: widget.art),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = Lucky16Layout.of(media.size);
    final canvas = layout.canvasRect;
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: kLucky16HistorySemanticsLabel,
        child: Center(
          child: SizedBox(
            key: const ValueKey('history-dialog'),
            width: canvas.width * Lucky16HistoryDialog.widthShare,
            height: canvas.height * Lucky16HistoryDialog.heightShare,
            child: Material(
              type: MaterialType.transparency,
              child: Lucky16PopupFrame(
                layout: layout,
                child: Column(
                  children: [
                    Lucky16PopupHeader(
                      layout: layout,
                      title: kLucky16HistoryTitle,
                      close:
                          Lucky16CloseButton(key: const ValueKey('history-close'), layout: layout, onTap: closeByHand),
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
  Widget _body(Lucky16Layout layout) {
    final history = widget.history;
    final records = history.records;
    if (records.isEmpty) {
      final error = history.error;
      if (error != null) {
        return _message(layout, key: 'history-error', text: error, retry: true);
      }
      if (history.isLoading || !_readAsked) {
        return _message(layout, key: 'history-loading', text: kLucky16HistoryLoading, spinner: true);
      }
      return _message(layout, key: 'history-empty', text: kLucky16HistoryEmpty);
    }
    return _list(layout, records);
  }

  /// One short thing to say in the middle of the popup: loading, an error with RETRY, or empty.
  Widget _message(Lucky16Layout layout,
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
                child: const CircularProgressIndicator(strokeWidth: 3, color: kLucky16Gold),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: layout.dp(36)),
            child: lucky16PopupText(
              text,
              layout,
              key: ValueKey(key),
              family: 'DMSans',
              units: 36,
              height: 1.3,
              maxLines: null,
              align: TextAlign.center,
              color: kLucky16Cream.withValues(alpha: 0.8),
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

  Widget _retryButton(Lucky16Layout layout) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: kLucky16HistoryRetry,
      onTap: _read,
      child: GestureDetector(
        key: const ValueKey('history-retry'),
        behavior: HitTestBehavior.opaque,
        onTap: _read,
        child: Container(
          constraints: const BoxConstraints(minWidth: kLucky16MinTapDp * 2, minHeight: kLucky16MinTapDp),
          padding: EdgeInsets.symmetric(horizontal: layout.dp(40)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: kLucky16GoldFace,
              stops: kLucky16GoldFaceStops,
            ),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: lucky16PopupText(
              kLucky16HistoryRetry,
              layout,
              weight: FontWeight.w700,
              units: 34,
              spacing: 0.1,
              color: kLucky16PopupInk,
            ),
          ),
        ),
      ),
    );
  }

  /// One stat box: the label at the left, the figure at the right.
  Widget _stat(Lucky16Layout layout, String key, String label, String value, Color color) {
    return Expanded(
      child: Container(
        key: ValueKey(key),
        padding: EdgeInsets.symmetric(horizontal: layout.dp(18), vertical: layout.dp(10)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(layout.dp(16)),
          color: Colors.black.withValues(alpha: 0.38),
          border: Border.all(color: kLucky16Gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            lucky16PopupText(label, layout,
                units: 24, spacing: layout.isTablet ? 0.06 : 0.16, color: kLucky16Cream.withValues(alpha: 0.7)),
            SizedBox(width: layout.dp(8)),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: lucky16PopupText(value, layout, weight: FontWeight.w700, units: 40, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The list: the stat boxes, the headings, the rounds and the hint at the foot.
  Widget _list(Lucky16Layout layout, List<Lucky16HistoryEntry> records) {
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
              color: kLucky16Gold,
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
              _stat(layout, 'history-stat-rounds', kLucky16HistoryRoundsStat, '${records.length}', kLucky16Cream),
              SizedBox(width: layout.dp(14)),
              _stat(layout, 'history-total-play', kLucky16HistoryPlayStat, lucky16Grouped(history.totalStake),
                  kLucky16Cream),
              SizedBox(width: layout.dp(14)),
              _stat(layout, 'history-total-win', kLucky16HistoryWinStat, lucky16Grouped(history.totalPayout),
                  kLucky16GoldBright),
            ],
          ),
        ),
        if (history.error != null)
          Semantics(
            button: true,
            excludeSemantics: true,
            label: kLucky16HistoryStale,
            onTap: _read,
            child: GestureDetector(
              key: const ValueKey('history-stale'),
              behavior: HitTestBehavior.opaque,
              onTap: _read,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kLucky16MinTapDp),
                child: Center(
                  child: lucky16PopupText(
                    kLucky16HistoryStale,
                    layout,
                    family: 'DMSans',
                    units: 28,
                    color: kLucky16Alert,
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
              heading(0, kLucky16HistoryNoHeader),
              heading(1, kLucky16HistoryRoundHeader),
              heading(2, kLucky16HistoryResultHeader),
              heading(3, kLucky16HistoryPlayHeader, align: TextAlign.right),
              heading(4, kLucky16HistoryWinHeader, align: TextAlign.right),
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
              itemBuilder: (context, i) => _Lucky16HistoryRow(
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
          child: lucky16PopupText(
            kLucky16HistoryHint,
            layout,
            family: 'DMSans',
            units: 24,
            align: TextAlign.center,
            color: kLucky16Cream.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// One round in the list, a card: a strip (green for a win, red for a loss), then NO., ROUND, RESULT,
/// PLAY and WIN. The whole card is the tap area, at least 48 dp tall.
class _Lucky16HistoryRow extends StatelessWidget {
  const _Lucky16HistoryRow({
    super.key,
    required this.layout,
    required this.art,
    required this.entry,
    required this.serial,
    required this.onTap,
  });

  final Lucky16Layout layout;
  final Lucky16Art art;
  final Lucky16HistoryEntry entry;
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
      label: lucky16HistoryRowSemantics(e, serial),
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: math.max(layout.dp(112), kLucky16MinTapDp)),
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
              color: won ? const Color(0x737CE08A) : kLucky16Gold.withValues(alpha: 0.22),
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
                      color: won ? null : kLucky16LossRed,
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
                            lucky16PopupText('$serial', layout,
                                weight: FontWeight.w600, units: 30, color: kLucky16Cream.withValues(alpha: 0.7)),
                          ),
                          cell(1, lucky16PopupText('${e.roundNumber}', layout, units: 32)),
                          cell(
                            2,
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Lucky16MiniCard(layout: layout, art: art, card: e.winningCard),
                                SizedBox(width: layout.dp(12)),
                                Lucky16BonusPill(layout: layout, bonus: e.bonusMultiplier),
                              ],
                            ),
                          ),
                          cell(
                            3,
                            lucky16PopupText(lucky16HistoryPlayText(e), layout, weight: FontWeight.w600, units: 34),
                            align: Alignment.centerRight,
                          ),
                          cell(
                            4,
                            lucky16PopupText(
                              lucky16HistoryWinText(e),
                              layout,
                              weight: FontWeight.w700,
                              units: 38,
                              color: won ? kLucky16Win : kLucky16Cream.withValues(alpha: 0.45),
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
class _Lucky16HistoryDetail extends StatefulWidget {
  const _Lucky16HistoryDetail({required this.provider, required this.entry, required this.serial, required this.art});

  final Lucky16Provider provider;
  final Lucky16HistoryEntry entry;
  final int serial;
  final Lucky16Art art;

  @override
  State<_Lucky16HistoryDetail> createState() => _Lucky16HistoryDetailState();
}

class _Lucky16HistoryDetailState extends State<_Lucky16HistoryDetail>
    with Lucky16ClosesWhenBettingCloses<_Lucky16HistoryDetail> {
  @override
  Lucky16Provider get bettingProvider => widget.provider;

  /// The winning card's picture with its gold ring and the bonus pill on its corner. The picture is
  /// the Lucky 16 card's own wide shape (700 x 476).
  Widget _heroCard(Lucky16Layout layout, double dpr) {
    final e = widget.entry;
    final height = math.max(layout.dp(120), 56.0);
    final width = height * 700 / 476;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(layout.dp(10)),
            border: Border.all(color: kLucky16GoldBright, width: math.max(layout.dp(4), 1.5)),
          ),
          child: Image(
            key: ValueKey('history-detail-card-${e.winningCard.key}'),
            image:
                widget.art.image(Lucky16ArtKey.card(e.winningCard), cacheWidth: Lucky16Layout.cacheWidth(width, dpr)),
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
          child: Lucky16BonusPill(
              key: const ValueKey('history-detail-bonus'), layout: layout, bonus: e.bonusMultiplier, units: 30),
        ),
      ],
    );
  }

  /// The big line beside the card: WIN over +560 COINS, or NO WIN.
  Widget _heroText(Lucky16Layout layout) {
    final e = widget.entry;
    if (!e.won) {
      return lucky16PopupText(
        'NO WIN',
        layout,
        key: const ValueKey('history-detail-headline'),
        weight: FontWeight.w700,
        units: 72,
        color: kLucky16Alert,
      );
    }
    return Column(
      key: const ValueKey('history-detail-headline'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        lucky16PopupText('WIN', layout, weight: FontWeight.w600, units: 30, spacing: 0.2, color: kLucky16Win),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              lucky16PopupText(
                '+${lucky16Grouped(e.payout)}',
                layout,
                key: const ValueKey('history-detail-amount'),
                weight: FontWeight.w700,
                units: 88,
                color: kLucky16Win,
                shadows: [Shadow(color: kLucky16Win.withValues(alpha: 0.6), blurRadius: layout.dp(18))],
              ),
              SizedBox(width: layout.dp(10)),
              lucky16PopupText('COINS', layout, units: 35, color: kLucky16Cream.withValues(alpha: 0.75)),
            ],
          ),
        ),
      ],
    );
  }

  /// One of the four facts.
  Widget _fact(Lucky16Layout layout, (String, String) line) {
    final bonus = line.$1 == 'BONUS';
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: layout.dp(18), vertical: layout.dp(12)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(layout.dp(14)),
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: kLucky16Gold.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            lucky16PopupText(line.$1, layout, units: 23, color: kLucky16Cream.withValues(alpha: 0.65)),
            SizedBox(height: layout.dp(3)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: lucky16PopupText(
                line.$2,
                layout,
                key: ValueKey('history-detail-${line.$1}'),
                weight: FontWeight.w600,
                units: 34,
                color: bonus ? kLucky16GoldBright : kLucky16Cream,
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
    final layout = Lucky16Layout.of(media.size);
    final canvas = layout.canvasRect;
    final dpr = media.devicePixelRatio;
    final e = widget.entry;
    final won = e.won;
    final lines = lucky16HistoryDetailLines(e);
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
              child: Lucky16PopupFrame(
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
                                colors: kLucky16GoldFace,
                                stops: kLucky16GoldFaceStops,
                              ),
                            ),
                            child: lucky16PopupText(
                              lucky16HistoryDetailBadge(widget.serial),
                              layout,
                              key: const ValueKey('history-detail-badge'),
                              weight: FontWeight.w700,
                              units: 30,
                              color: const Color(0xFF1A0505),
                            ),
                          ),
                          const Spacer(),
                          Lucky16CloseButton(
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
                                  color: won ? const Color(0x8C7CE08A) : kLucky16Alert.withValues(alpha: 0.55),
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
