// The Lucky Card History dialog: every round the player has bet on since logging in, newest
// first, with what they staked and what they won, and a popup with the details of one round.
//
//   LuckyCardHistoryDialog.show(context, provider: game, history: history, since: login)
//
//   * It looks like Triple Chance's HISTORY tab: NO., ROUND, PLAY and WIN columns, a green strip
//     on a winning line and a red one on a losing line, a "TOTAL SESSION" footer, and a tap on a
//     line opens a popup (Round, Winning card, Bonus, Total Bet, Total Win). A winning line with a
//     bonus carries a small "2X" to "10X" tag under its WIN amount.
//   * Each time it opens it asks [history] to read everything since [since], so the list is the
//     database's own. While the first read is on its way it says so; a failed first read says
//     "Could not load history. Tap to retry." with a RETRY button; a failed later read keeps the
//     earlier list and shows a line over it that retries when tapped; no rounds says so.
//   * Like the Info dialog, it closes by itself, with a fade, the moment betting closes, so the
//     wheel, the card and the win popup are never hidden behind it. The row popup closes with it.
//     Opened while betting is already closed, it closes again at once and reads nothing.
//   * Every tap target is at least 48 dp, all text is at least 11 dp and ignores the phone's
//     font-size setting, and the dialog's size follows the screen the same way the game's canvas
//     does. The winning card is written in words (the fonts have no suit symbols).
//   * The click sound for a line is a hook ([onRow]) for the screen.
//
// The words are in lucky_card_history_text.dart. Belongs to Lucky Card only.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/lucky_card_history_model.dart';
import '../../providers/lucky_card_history_provider.dart';
import '../../providers/lucky_card_provider.dart';
import 'lucky_card_history_text.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_panel.dart';
import 'lucky_card_stake_text.dart';

/// The red strip of a losing line, as Triple Chance's.
const Color _kLossStrip = Color(0xFF8B0000);

/// Closes the dialog or popup that uses it, with the same fade as any other close, the moment
/// the game locks betting. Used by the dialog and by its row popup, so each takes itself off
/// the screen even when the other is on top of it. [bettingProvider] is the game provider.
mixin _ClosesWhenBettingCloses<T extends StatefulWidget> on State<T> {
  LuckyCardProvider get bettingProvider;

  LuckyCardProvider? _watched;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _watched = bettingProvider..addListener(_closeIfBettingClosed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _closeIfBettingClosed());
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_watched != bettingProvider) {
      _watched?.removeListener(_closeIfBettingClosed);
      _watched = bettingProvider..addListener(_closeIfBettingClosed);
    }
  }

  @override
  void dispose() {
    _watched?.removeListener(_closeIfBettingClosed);
    super.dispose();
  }

  void _closeIfBettingClosed() {
    if (!mounted || _closing || !bettingProvider.isLocked) return;
    _closing = true;
    final route = ModalRoute.of(context);
    if (route == null) return;
    // Another route (the row popup) may be on top: take this one out from underneath.
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  /// Closes by hand. Two quick activations close once, never the game screen behind.
  void closeByHand() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }
}

/// The open and close transition of the dialog and of its popup.
const Duration _kTransition = Duration(milliseconds: 220);

Widget _fadeAndScale(BuildContext context, Animation<double> animation, Widget child) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
  return FadeTransition(
    opacity: curved,
    child: ScaleTransition(scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved), child: child),
  );
}

class LuckyCardHistoryDialog extends StatefulWidget {
  const LuckyCardHistoryDialog({
    super.key,
    required this.provider,
    required this.history,
    required this.since,
    this.onRow,
  });

  /// The game provider, watched so the dialog can close when betting closes.
  final LuckyCardProvider provider;

  /// Where the lines come from; asked to read each time the dialog opens.
  final LuckyCardHistoryProvider history;

  /// The start of this login: only rounds bet on since then are listed.
  final DateTime? since;

  /// A line was tapped (the click sound).
  final VoidCallback? onRow;

  /// How much of the canvas the dialog covers, the same as the Info dialog.
  static const double widthShare = 0.8;
  static const double heightShare = 0.92;

  /// Shows the dialog over the screen. Completes when it closes, for any reason.
  static Future<void> show(
    BuildContext context, {
    required LuckyCardProvider provider,
    required LuckyCardHistoryProvider history,
    required DateTime? since,
    VoidCallback? onOpen,
    VoidCallback? onRow,
  }) {
    onOpen?.call();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0xBF000000),
      transitionDuration: _kTransition,
      pageBuilder: (_, __, ___) =>
          LuckyCardHistoryDialog(provider: provider, history: history, since: since, onRow: onRow),
      transitionBuilder: (context, animation, _, child) => _fadeAndScale(context, animation, child),
    );
  }

  @override
  State<LuckyCardHistoryDialog> createState() => _LuckyCardHistoryDialogState();
}

class _LuckyCardHistoryDialogState extends State<LuckyCardHistoryDialog>
    with _ClosesWhenBettingCloses<LuckyCardHistoryDialog> {
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
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x99000000),
      transitionDuration: _kTransition,
      pageBuilder: (_, __, ___) => _LuckyCardHistoryDetail(provider: widget.provider, entry: entry, serial: serial),
      transitionBuilder: (context, animation, _, child) => _fadeAndScale(context, animation, child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = LuckyCardLayout.of(media.size);
    final canvas = layout.canvasRect;
    final width = canvas.width * LuckyCardHistoryDialog.widthShare;
    final height = canvas.height * LuckyCardHistoryDialog.heightShare;
    final header = math.max(layout.dp(134), kLuckyCardMinTapDp);

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
            width: width,
            height: height,
            child: Material(
              type: MaterialType.transparency,
              child: LuckyCardPanel(
                layout: layout,
                radiusUnits: 28,
                child: Column(
                  children: [
                    SizedBox(
                      height: header,
                      child: Row(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, c) => LuckyCardStakeText(
                                kLuckyCardHistoryTitle,
                                maxWidth: c.maxWidth,
                                preferredSize: layout.fontSize(46),
                                color: kLuckyCardGoldBright,
                              ),
                            ),
                          ),
                          _closeButton(layout, header),
                        ],
                      ),
                    ),
                    Container(height: 1, color: kLuckyCardGold.withValues(alpha: 0.5)),
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

  Widget _closeButton(LuckyCardLayout layout, double side) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Close',
      onTap: closeByHand,
      child: GestureDetector(
        key: const ValueKey('history-close'),
        behavior: HitTestBehavior.opaque,
        onTap: closeByHand,
        child: SizedBox(
          width: side,
          height: side,
          child: Icon(Icons.close_rounded, size: layout.fontSize(60, minDp: 16), color: kLuckyCardCream),
        ),
      ),
    );
  }

  /// What fills the dialog under its title: the table, or the one thing to say instead.
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
    return _table(layout, records);
  }

  /// One short thing to say in the middle of the dialog: loading, an error with RETRY, or empty.
  Widget _message(LuckyCardLayout layout, {required String key, required String text, bool spinner = false, bool retry = false}) {
    final style = _bodyStyle(layout, color: kLuckyCardCream.withValues(alpha: 0.8));
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
            child: Text(text, key: ValueKey(key), textAlign: TextAlign.center, textScaler: TextScaler.noScaling, style: style),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: kLuckyCardMinTapDp * 2, minHeight: kLuckyCardMinTapDp),
          child: LuckyCardPanel(
            layout: layout,
            radiusUnits: 24,
            padding: EdgeInsets.symmetric(horizontal: layout.dp(40)),
            child: Center(
              widthFactor: 1,
              child: Text(kLuckyCardHistoryRetry, textScaler: TextScaler.noScaling, style: _cellStyle(layout, kLuckyCardGoldBright)),
            ),
          ),
        ),
      ),
    );
  }

  /// Column shares of the table, left to right: NO., ROUND, PLAY, WIN.
  static const List<int> _flex = [10, 28, 22, 22];

  Widget _table(LuckyCardLayout layout, List<LuckyCardHistoryEntry> records) {
    final history = widget.history;
    final headHeight = math.max(layout.dp(84), 30.0);
    final footHeight = math.max(layout.dp(100), 34.0);
    final stale = history.error != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(layout.dp(28), layout.dp(20), layout.dp(28), layout.dp(24)),
      child: Column(
        children: [
          SizedBox(
            height: headHeight,
            child: Row(
              children: [
                SizedBox(width: _stripWidth(layout)),
                for (var i = 0; i < 4; i++)
                  Expanded(
                    flex: _flex[i],
                    child: LayoutBuilder(
                      builder: (context, c) => LuckyCardStakeText(
                        const [
                          kLuckyCardHistoryNoHeader,
                          kLuckyCardHistoryRoundHeader,
                          kLuckyCardHistoryPlayHeader,
                          kLuckyCardHistoryWinHeader,
                        ][i],
                        maxWidth: c.maxWidth,
                        preferredSize: layout.fontSize(32),
                        color: kLuckyCardGold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: kLuckyCardGold.withValues(alpha: 0.5)),
          if (stale)
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
                    child: Text(
                      kLuckyCardHistoryStale,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: _bodyStyle(layout, color: kLuckyCardAlert),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Scrollbar(
              child: ListView.builder(
                key: const ValueKey('history-list'),
                padding: EdgeInsets.zero,
                itemCount: records.length,
                itemBuilder: (context, i) => _HistoryRow(
                  key: ValueKey('history-row-$i'),
                  layout: layout,
                  entry: records[i],
                  serial: i + 1,
                  flex: _flex,
                  onTap: () => _openDetail(records[i], i + 1),
                ),
              ),
            ),
          ),
          Container(height: 1, color: kLuckyCardGold.withValues(alpha: 0.5)),
          SizedBox(
            height: footHeight,
            child: Row(
              children: [
                SizedBox(width: _stripWidth(layout)),
                Expanded(
                  flex: _flex[0] + _flex[1],
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: layout.dp(24)),
                      child: Text(
                        kLuckyCardHistoryTotalLabel,
                        textScaler: TextScaler.noScaling,
                        style: _cellStyle(layout, kLuckyCardGold),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: _flex[2],
                  child: LayoutBuilder(
                    builder: (context, c) => LuckyCardStakeText(
                      key: const ValueKey('history-total-play'),
                      luckyCardGrouped(history.totalStake),
                      maxWidth: c.maxWidth,
                      preferredSize: layout.fontSize(36),
                      color: kLuckyCardGoldBright,
                    ),
                  ),
                ),
                Expanded(
                  flex: _flex[3],
                  child: LayoutBuilder(
                    builder: (context, c) => LuckyCardStakeText(
                      key: const ValueKey('history-total-win'),
                      history.totalPayout > 0 ? '+${luckyCardGrouped(history.totalPayout)}' : '0',
                      maxWidth: c.maxWidth,
                      preferredSize: layout.fontSize(36),
                      color: history.totalPayout > 0 ? kLuckyCardWin : kLuckyCardCream.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _stripWidth(LuckyCardLayout layout) => math.max(layout.dp(10), 3.0);

TextStyle _bodyStyle(LuckyCardLayout layout, {Color color = kLuckyCardCream, FontWeight weight = FontWeight.w500}) =>
    TextStyle(fontFamily: 'DMSans', fontWeight: weight, fontSize: layout.fontSize(36), height: 1.3, color: color);

TextStyle _cellStyle(LuckyCardLayout layout, Color color) => TextStyle(
      fontFamily: 'Oswald',
      fontWeight: FontWeight.w500,
      fontSize: layout.fontSize(34),
      height: 1.0,
      color: color,
    );

/// One line of the table: a strip (green for a win, red for a loss), then NO., ROUND, PLAY, WIN.
/// The whole line is the tap area, at least 48 dp tall.
class _HistoryRow extends StatefulWidget {
  const _HistoryRow({
    super.key,
    required this.layout,
    required this.entry,
    required this.serial,
    required this.flex,
    required this.onTap,
  });

  final LuckyCardLayout layout;
  final LuckyCardHistoryEntry entry;
  final int serial;
  final List<int> flex;
  final VoidCallback onTap;

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (_pressed != pressed && mounted) setState(() => _pressed = pressed);
  }

  Widget _cell(int index, String text, {Color color = kLuckyCardCream, String tag = ''}) {
    final layout = widget.layout;
    return Expanded(
      flex: widget.flex[index],
      child: LayoutBuilder(
        builder: (context, c) {
          final main = LuckyCardStakeText(text, maxWidth: c.maxWidth, preferredSize: layout.fontSize(36), color: color);
          if (tag.isEmpty) return main;
          // A winning line with a bonus: the amount, and the small bonus under it.
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: layout.fontSize(36) * 1.1, child: main),
              SizedBox(
                height: layout.fontSize(30) * 1.1,
                child: LuckyCardStakeText(tag, maxWidth: c.maxWidth, preferredSize: layout.fontSize(30), color: kLuckyCardGold),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final e = widget.entry;
    final height = math.max(layout.dp(120), kLuckyCardMinTapDp);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: luckyCardHistoryRowSemantics(e, widget.serial),
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: _pressed
                ? kLuckyCardGold.withValues(alpha: 0.12)
                : (widget.serial.isEven ? const Color(0x33000000) : Colors.transparent),
            border: Border(bottom: BorderSide(color: kLuckyCardCream.withValues(alpha: 0.1))),
          ),
          child: Row(
            children: [
              Container(
                key: ValueKey('history-strip-${widget.serial - 1}'),
                width: _stripWidth(layout),
                color: e.won ? kLuckyCardWin : _kLossStrip,
              ),
              _cell(0, '${widget.serial}', color: kLuckyCardCream.withValues(alpha: 0.65)),
              _cell(1, '${e.roundNumber}'),
              _cell(2, luckyCardHistoryPlayText(e), color: kLuckyCardGoldBright),
              _cell(
                3,
                luckyCardHistoryWinText(e),
                color: e.won ? kLuckyCardWin : kLuckyCardCream.withValues(alpha: 0.5),
                tag: e.won ? luckyCardHistoryBonusTag(e) : '',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The popup with the details of one line. It closes by itself when betting closes, even
/// though the History dialog is under it.
class _LuckyCardHistoryDetail extends StatefulWidget {
  const _LuckyCardHistoryDetail({required this.provider, required this.entry, required this.serial});

  final LuckyCardProvider provider;
  final LuckyCardHistoryEntry entry;
  final int serial;

  @override
  State<_LuckyCardHistoryDetail> createState() => _LuckyCardHistoryDetailState();
}

class _LuckyCardHistoryDetailState extends State<_LuckyCardHistoryDetail>
    with _ClosesWhenBettingCloses<_LuckyCardHistoryDetail> {
  @override
  LuckyCardProvider get bettingProvider => widget.provider;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = LuckyCardLayout.of(media.size);
    final canvas = layout.canvasRect;
    final e = widget.entry;
    final side = math.max(layout.dp(134), kLuckyCardMinTapDp);
    final headline = luckyCardHistoryHeadline(e);
    final lines = luckyCardHistoryDetailLines(e);
    final accent = e.won ? kLuckyCardWin : kLuckyCardAlert;

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
              child: LuckyCardPanel(
                layout: layout,
                radiusUnits: 28,
                highlighted: e.won,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: side,
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: layout.dp(36)),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: layout.dp(24), vertical: layout.dp(8)),
                                  decoration: BoxDecoration(color: kLuckyCardGold, borderRadius: BorderRadius.circular(layout.dp(14))),
                                  child: Text(
                                    luckyCardHistoryDetailBadge(widget.serial),
                                    key: const ValueKey('history-detail-badge'),
                                    textScaler: TextScaler.noScaling,
                                    style: _cellStyle(layout, const Color(0xFF1A0505)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            excludeSemantics: true,
                            label: 'Close',
                            onTap: closeByHand,
                            child: GestureDetector(
                              key: const ValueKey('history-detail-close'),
                              behavior: HitTestBehavior.opaque,
                              onTap: closeByHand,
                              child: SizedBox(
                                width: side,
                                height: side,
                                child: Icon(Icons.close_rounded, size: layout.fontSize(60, minDp: 16), color: kLuckyCardCream),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: kLuckyCardGold.withValues(alpha: 0.5)),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: layout.dp(36), vertical: layout.dp(24)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(vertical: layout.dp(18)),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(layout.dp(14)),
                                border: Border.all(color: accent.withValues(alpha: 0.5)),
                              ),
                              child: Center(
                                child: Text(
                                  headline,
                                  key: const ValueKey('history-detail-headline'),
                                  textScaler: TextScaler.noScaling,
                                  style: _cellStyle(layout, accent).copyWith(fontSize: layout.fontSize(42)),
                                ),
                              ),
                            ),
                            SizedBox(height: layout.dp(16)),
                            for (final line in lines)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: layout.dp(8)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.$1,
                                      textScaler: TextScaler.noScaling,
                                      style: _bodyStyle(layout, color: kLuckyCardCream.withValues(alpha: 0.7)),
                                    ),
                                    SizedBox(width: layout.dp(24)),
                                    Expanded(
                                      child: Text(
                                        line.$2,
                                        key: ValueKey('history-detail-${line.$1}'),
                                        textAlign: TextAlign.right,
                                        textScaler: TextScaler.noScaling,
                                        style: _bodyStyle(layout, color: kLuckyCardCream, weight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
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
      ),
    );
  }
}
