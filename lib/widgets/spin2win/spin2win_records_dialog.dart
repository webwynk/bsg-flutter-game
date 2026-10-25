// The Spin2Win "MY RECORDS" dialog, opened by the trophy button, as the reference design's
// "Records popup" draws it (560 x 320 dp): a gold-framed blue card with the trophy and the title,
// two tabs, HISTORY and PAYOUT, and the red close button.
//
//   Spin2WinRecordsDialog.show(context, provider: game, history: history, since: login)
//
//   * HISTORY: every round the player bet on since logging in, newest first (NO., ROUND ID, PLAY,
//     WIN, WIN NO., BONUS, RESULT), with TOTAL PLAY and TOTAL WIN under it. Read from the database
//     each time the dialog opens ([Spin2WinHistoryProvider.loadSession]), so it is always the
//     server's own list, as in Triple Chance and Lucky Card. While the first read is on its way it
//     says so; a failed read says "Could not load history. Tap to retry."; no rounds says so.
//   * PAYOUT: what one chip on a single number wins, for the chip in hand (Hasan's rule,
//     2026-10-24: the 10 chip shows 90 / 180 / 270 / 360 for N / 2x / 3x / 4x), and the play
//     limits (5 to 10,000 on a number). With no chip in hand it shows the 10 chip, as the design.
//     It follows the chip in hand while open.
//   * Like Lucky Card's History dialog it closes by itself the moment betting closes, so the
//     wheel and the win popup are never hidden behind it; the trophy does nothing while betting is
//     closed (the screen checks).
//
// Belongs to Spin2Win only.

import 'package:flutter/material.dart';

import '../../models/spin2win_board.dart';
import '../../models/spin2win_history_model.dart';
import '../../models/spin2win_models.dart';
import '../../providers/spin2win_history_provider.dart';
import '../../providers/spin2win_provider.dart';
import 'spin2win_bet_panel.dart';
import 'spin2win_dialog_frame.dart';
import 'spin2win_icons.dart';
import 'spin2win_palette.dart';

enum Spin2WinRecordsTab { history, payout }

/// What the empty list and the first read say.
const String kSpin2WinRecordsEmpty = 'No rounds played yet.';
const String kSpin2WinRecordsLoading = 'Loading history...';

/// The chip the Payout tab shows when none is in hand (the design's own example).
const Spin2WinChip kSpin2WinPayoutDefaultChip = Spin2WinChip.ten;

/// The round's id as the table writes it ("R-1082451").
String spin2WinRoundIdText(int roundNumber) => 'R-$roundNumber';

class Spin2WinRecordsDialog extends StatefulWidget {
  const Spin2WinRecordsDialog({
    super.key,
    required this.provider,
    required this.history,
    required this.since,
    this.chipImage = spin2WinAssetChipImage,
    this.initialTab = Spin2WinRecordsTab.history,
    this.load = true,
  });

  final Spin2WinProvider provider;
  final Spin2WinHistoryProvider history;

  /// The start of this login: the list holds the rounds played since then.
  final DateTime? since;
  final ImageProvider Function(Spin2WinChip chip) chipImage;
  final Spin2WinRecordsTab initialTab;

  /// Whether to read the list when it opens (a screenshot test hands in a list already read).
  final bool load;

  static const Size size = Size(560, 320);

  static Future<void> show(
    BuildContext context, {
    required Spin2WinProvider provider,
    required Spin2WinHistoryProvider history,
    required DateTime? since,
    ImageProvider Function(Spin2WinChip chip) chipImage = spin2WinAssetChipImage,
  }) {
    return spin2WinShowDialog<void>(
      context,
      label: 'My records',
      barrierDismissible: true,
      builder: (_) => Spin2WinRecordsDialog(provider: provider, history: history, since: since, chipImage: chipImage),
    );
  }

  @override
  State<Spin2WinRecordsDialog> createState() => _Spin2WinRecordsDialogState();
}

class _Spin2WinRecordsDialogState extends State<Spin2WinRecordsDialog> {
  late Spin2WinRecordsTab _tab = widget.initialTab;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_closeIfBettingClosed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _closeIfBettingClosed();
      if (!_closing && widget.load) widget.history.loadSession(since: widget.since);
    });
  }

  @override
  void dispose() {
    widget.provider.removeListener(_closeIfBettingClosed);
    super.dispose();
  }

  void _closeIfBettingClosed() {
    if (widget.provider.isLocked) _close();
  }

  /// Closes once, however many times it is asked (never the game screen behind).
  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'My records',
      child: Spin2WinDialogCard(
        key: const ValueKey('spin2win-records-dialog'),
        width: Spin2WinRecordsDialog.size.width,
        height: Spin2WinRecordsDialog.size.height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 34, child: _header()),
            const SizedBox(height: 10),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([widget.history, widget.provider]),
                builder: (context, _) => _tab == Spin2WinRecordsTab.history
                    ? _HistoryTab(history: widget.history, since: widget.since)
                    : _PayoutTab(
                        chip: widget.provider.activeChip ?? kSpin2WinPayoutDefaultChip, chipImage: widget.chipImage),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const CustomPaint(size: Size(30, 30), painter: Spin2WinTrophyPainter()),
        const SizedBox(width: 10),
        const Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Spin2WinOutlinedText(
              'MY RECORDS',
              size: 20,
              height: 1,
              letterSpacing: 1.5,
              strokeWidth: 4,
              stroke: Color(0xE63A1F96),
              shadows: [Shadow(color: Color(0x59000000), offset: Offset(0, 3))],
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: kS2wNavyWell,
            boxShadow: const [BoxShadow(color: Color(0xB3000000), blurRadius: 5, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              _tabButton('HISTORY', Spin2WinRecordsTab.history),
              const SizedBox(width: 8),
              _tabButton('PAYOUT', Spin2WinRecordsTab.payout),
            ],
          ),
        ),
        const SizedBox(width: 2),
        Spin2WinCloseButton(key: const ValueKey('spin2win-records-close'), onTap: _close),
      ],
    );
  }

  Widget _tabButton(String label, Spin2WinRecordsTab tab) {
    final on = _tab == tab;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('spin2win-records-tab-${tab.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tab = tab),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: on
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xFFFFF0C0), width: 2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFE07A), Color(0xFFFF9A1F), Color(0xFFE05A00)],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF6B2A00), offset: Offset(0, 3)),
                    BoxShadow(color: Color(0x80FF9A1F), blurRadius: 12),
                  ],
                )
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0x00000000), width: 2)),
          child: on
              ? Spin2WinOutlinedText(label,
                  size: 13,
                  height: 1,
                  letterSpacing: 1.2,
                  strokeWidth: 2.5,
                  stroke: const Color(0xE66B2A00),
                  shadows: const [],
                  centreCaps: true)
              : Spin2WinCapsCentred(
                  size: 13,
                  child: Text(label,
                      style: const TextStyle(fontSize: 13, height: 1, letterSpacing: 1.2, color: Color(0xFF9FB3DA))),
                ),
        ),
      ),
    );
  }
}

// ── HISTORY ──────────────────────────────────────────────────────────────────────────────────

/// The table's column widths (the design's grid: 36, 1.4fr, 1fr, 1fr, 62, 56, 70).
const List<int> _kFlex = [0, 14, 10, 10, 0, 0, 0];
const List<double> _kFixed = [36, 0, 0, 0, 62, 56, 70];

const TextStyle _kDigits =
    TextStyle(fontFamily: kSpin2WinDigitsFont, fontWeight: FontWeight.w600, fontSize: 13, height: 1);

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.history, required this.since});

  final Spin2WinHistoryProvider history;

  /// The start of this login (a retry reads from the same moment as the first read).
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xBF061030),
              border: Border.all(color: const Color(0x5900E5FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _headRow(),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: _Total(
                  key: const ValueKey('spin2win-records-total-play'),
                  label: 'TOTAL PLAY',
                  amount: history.totalStake,
                  accent: kS2wCyan,
                  labelColor: const Color(0xFFB4C3E3),
                  amountColors: const [Color(0xFFFFFFFF), Color(0xFFCFE9FF)],
                  icon: const Spin2WinCoinStackPainter(),
                  iconSize: const Size(19, 17.6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Total(
                  key: const ValueKey('spin2win-records-total-win'),
                  label: 'TOTAL WIN',
                  amount: history.totalPayout,
                  accent: kS2wGold,
                  labelColor: const Color(0xFFFFE08A),
                  amountColors: const [Color(0xFFFFF4C2), Color(0xFFFFB52E)],
                  icon: const Spin2WinTrophyPainter(),
                  iconSize: const Size(19, 19),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headRow() {
    const style = TextStyle(fontSize: 10, height: 1, letterSpacing: 1.2, color: kS2wGold);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1F3F86), Color(0xFF13306A)]),
        border: Border(bottom: BorderSide(color: Color(0x73FFD45A))),
      ),
      // Every heading's capitals sit in the middle of the bar (Hasan's phone test, 2026-10-25).
      child: _cells(const [
        Spin2WinCapsCentred(size: 10, child: Text('NO.', style: style)),
        Spin2WinCapsCentred(size: 10, child: Text('ROUND ID', style: style)),
        Spin2WinCapsCentred(size: 10, child: Text('PLAY', style: style, textAlign: TextAlign.right)),
        Spin2WinCapsCentred(size: 10, child: Text('WIN', style: style, textAlign: TextAlign.right)),
        Spin2WinCapsCentred(size: 10, child: Text('WIN NO.', style: style, textAlign: TextAlign.center)),
        Spin2WinCapsCentred(size: 10, child: Text('BONUS', style: style, textAlign: TextAlign.center)),
        Spin2WinCapsCentred(size: 10, child: Text('RESULT', style: style, textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _body() {
    final records = history.records;
    final error = history.error;
    if (records.isEmpty) {
      if (history.isLoading) return const _Note(text: kSpin2WinRecordsLoading, spinner: true);
      if (error != null) return _Note(key: const ValueKey('spin2win-records-error'), text: error, onTap: _retry);
      return const _Note(key: ValueKey('spin2win-records-empty'), text: kSpin2WinRecordsEmpty);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A failed later read keeps the list it had and offers a retry over it.
        if (error != null)
          GestureDetector(
            key: const ValueKey('spin2win-records-error'),
            onTap: _retry,
            child: Container(
              height: 24,
              alignment: Alignment.center,
              color: const Color(0x99C8102E),
              child: Text(error, style: const TextStyle(fontSize: 11, height: 1, color: Color(0xFFFFFFFF))),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: records.length,
            itemExtent: 30,
            itemBuilder: (context, i) => _row(i, records[i]),
          ),
        ),
      ],
    );
  }

  void _retry() => history.loadSession(since: since);

  Widget _row(int i, Spin2WinHistoryEntry r) {
    final won = r.won;
    return Container(
      key: ValueKey('spin2win-records-row-$i'),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: i.isOdd ? const Color(0x09FFFFFF) : null,
        border: const Border(bottom: BorderSide(color: Color(0x0FFFFFFF))),
      ),
      // The numbers' digits sit in the middle of the row, level with the middle of the badges
      // (each badge is lifted 1 dp so the badge and its 2 dp shadow are centred together).
      child: _cells([
        _digits(Text('${i + 1}', style: _kDigits.copyWith(color: const Color(0xFF9FB3DA)))),
        _digits(Text(spin2WinRoundIdText(r.roundNumber),
            style: _kDigits.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.5, color: const Color(0xFFDCE6FA)))),
        _digits(Text(spin2WinAmountText(r.stake),
            textAlign: TextAlign.right, style: _kDigits.copyWith(color: const Color(0xFFFFFFFF)))),
        _digits(Text(spin2WinAmountText(r.payout),
            textAlign: TextAlign.right,
            style: _kDigits.copyWith(fontWeight: FontWeight.w700, color: won ? kS2wGold : const Color(0xFF6C7FA8)))),
        _badge(_NumberChip(r.winningNumber)),
        _badge(_BonusPill(r.bonusMultiplier)),
        _badge(_ResultBadge(won)),
      ]),
    );
  }

  static Widget _digits(Text text) => Spin2WinCapsCentred(size: _kDigits.fontSize!, digitsFont: true, child: text);

  static Widget _badge(Widget badge) => Center(child: Transform.translate(offset: const Offset(0, -1), child: badge));

  static Widget _cells(List<Widget> cells) {
    return Row(
      children: [
        for (var i = 0; i < cells.length; i++)
          if (_kFlex[i] > 0)
            Expanded(flex: _kFlex[i], child: cells[i])
          else
            SizedBox(width: _kFixed[i], child: cells[i]),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.text, this.spinner = false, this.onTap});

  final String text;
  final bool spinner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner) ...[
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kS2wGold)),
              const SizedBox(width: 10),
            ],
            Text(text, style: const TextStyle(fontSize: 14, height: 1, letterSpacing: 0.5, color: Color(0xFF9FB3DA))),
          ],
        ),
      ),
    );
  }
}

/// The winning number in its colour (24 x 22).
class _NumberChip extends StatelessWidget {
  const _NumberChip(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final s = spin2WinShades(number);
    return Container(
      width: 24,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: s.edge, width: 1.5),
        gradient:
            LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [s.light, s.mid, s.dark]),
        boxShadow: const [BoxShadow(color: Color(0x73000000), offset: Offset(0, 2))],
      ),
      child:
          Spin2WinOutlinedText('$number', size: 13, height: 1, strokeWidth: 2.5, shadows: const [], centreCaps: true),
    );
  }
}

/// The bonus as the design's small pill (the popup's `BON` colours: N steel, 2x cyan, 3x green,
/// 4x blue).
class _BonusPill extends StatelessWidget {
  const _BonusPill(this.multiplier, {this.height = 18, this.fontSize = 11});

  final int multiplier;
  final double height;
  final double fontSize;

  static (Color, Color) _colors(int m) => switch (m) {
        2 => (const Color(0xFF6FF3FF), const Color(0xFF0077A8)),
        3 => (const Color(0xFF7DFFAE), const Color(0xFF0A9A45)),
        4 => (const Color(0xFF6FB0FF), const Color(0xFF0A4FC4)),
        _ => (const Color(0xFFC7D3EE), const Color(0xFF5A6A8E)),
      };

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = _colors(multiplier);
    final n = multiplier <= 1;
    return Container(
      constraints: BoxConstraints(minWidth: height * 34 / 18),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: const Color(0xD9FFFFFF), width: 1.5),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
        boxShadow: [
          const BoxShadow(color: Color(0x73000000), offset: Offset(0, 2)),
          if (!n) BoxShadow(color: top, blurRadius: 8),
        ],
      ),
      child: Spin2WinOutlinedText(
        spin2WinBonusText(multiplier),
        size: fontSize,
        height: 1,
        strokeWidth: 2,
        color: n ? const Color(0xFFE3E9F7) : const Color(0xFFFFFFFF),
        stroke: const Color(0x99100A28),
        shadows: const [],
        centreCaps: true,
      ),
    );
  }
}

/// WIN in green or LOSE in red.
class _ResultBadge extends StatelessWidget {
  const _ResultBadge(this.won);

  final bool won;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: won ? const Color(0xFFC8FFDD) : const Color(0xFFFFC2CC), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: won ? const [Color(0xFF7DFFAE), Color(0xFF0A9A45)] : const [Color(0xFFFF7A8E), Color(0xFFC8102E)],
        ),
        boxShadow: [
          BoxShadow(color: won ? const Color(0xFF04461F) : const Color(0xFF5E0716), offset: const Offset(0, 2))
        ],
      ),
      child: Spin2WinOutlinedText(won ? 'WIN' : 'LOSE',
          size: 11,
          height: 1,
          letterSpacing: 1,
          strokeWidth: 2,
          stroke: const Color(0x8C100A28),
          shadows: const [],
          centreCaps: true),
    );
  }
}

/// TOTAL PLAY or TOTAL WIN under the history (redesigned at Hasan's request, 2026-10-25): a dark
/// glass bar with a thin glowing edge in its colour, a round icon (coins for play, the trophy for
/// win), the label, and the amount in a soft gradient on the right.
class _Total extends StatelessWidget {
  const _Total({
    super.key,
    required this.label,
    required this.amount,
    required this.accent,
    required this.labelColor,
    required this.amountColors,
    required this.icon,
    required this.iconSize,
  });

  final String label;
  final int amount;
  final Color accent;
  final Color labelColor;
  final List<Color> amountColors;
  final CustomPainter icon;
  final Size iconSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight;
      final disc = h - 10;
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(h / 2),
          border: Border.all(color: accent.withValues(alpha: 0.75), width: 1.5),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [accent.withValues(alpha: 0.24), const Color(0xFF0E2350), const Color(0xFF0A1838)],
            stops: const [0, 0.45, 1],
          ),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.28), blurRadius: 12),
            const BoxShadow(color: Color(0x80000000), offset: Offset(0, 3), blurRadius: 6),
          ],
        ),
        child: Stack(
          children: [
            // A soft shine across the top half.
            Positioned(
              left: h / 3,
              right: h / 3,
              top: 1,
              height: h / 2 - 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(h / 2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x1FFFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 4, right: h / 2.4),
              child: Row(
                children: [
                  Container(
                    width: disc,
                    height: disc,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.9), width: 1.5),
                      gradient: const RadialGradient(
                        center: Alignment(-0.3, -0.4),
                        colors: [Color(0xFF2A4C93), Color(0xFF0B1A3C)],
                      ),
                      boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 6)],
                    ),
                    child: CustomPaint(size: iconSize * (disc / 30), painter: icon),
                  ),
                  const SizedBox(width: 10),
                  Spin2WinCapsCentred(
                    size: 11,
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            height: 1,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w800,
                            color: labelColor)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Spin2WinCapsCentred(
                          size: 22,
                          digitsFont: true,
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (r) => LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: amountColors,
                            ).createShader(r),
                            child: Text(
                              spin2WinAmountText(amount),
                              style: const TextStyle(
                                fontFamily: kSpin2WinDigitsFont,
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                                height: 1,
                                letterSpacing: 0.5,
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── PAYOUT ───────────────────────────────────────────────────────────────────────────────────

class _PayoutTab extends StatelessWidget {
  const _PayoutTab({required this.chip, required this.chipImage});

  final Spin2WinChip chip;
  final ImageProvider Function(Spin2WinChip chip) chipImage;

  @override
  Widget build(BuildContext context) {
    final amount = chip.amount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 13,
          child: _Box(
            edge: const Color(0xB3FF35C7),
            tint: const Color(0x2EFF35C7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: Image(
                        key: const ValueKey('spin2win-payout-chip'),
                        image: chipImage(chip),
                        // A picture that cannot be loaded leaves its place empty.
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SINGLES PLAY',
                              style: TextStyle(fontSize: 16, height: 1, letterSpacing: 1, color: Color(0xFFFF8AE2))),
                          const SizedBox(height: 6),
                          Text(
                            'Play ${spin2WinAmountText(amount)} ${amount == 1 ? 'chip' : 'chips'} on a single number and win:',
                            key: const ValueKey('spin2win-payout-text'),
                            style: const TextStyle(
                                fontSize: 13, height: 1.2, fontWeight: FontWeight.w600, color: Color(0xFFDCE6FA)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var m = 1; m <= 4; m++) ...[
                      if (m > 1) const SizedBox(width: 8),
                      Expanded(child: _PayoutPill(bonus: m, amount: spin2WinPayout(amount, m))),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          flex: 9,
          child: _Box(
            edge: const Color(0xB300E5FF),
            tint: const Color(0x2400E5FF),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PLAY LIMITS',
                          style: TextStyle(fontSize: 16, height: 1, letterSpacing: 1, color: Color(0xFF6FF3FF))),
                      SizedBox(height: 6),
                      Text('Each number takes between these amounts.',
                          style: TextStyle(
                              fontSize: 13, height: 1.2, fontWeight: FontWeight.w600, color: Color(0xFFDCE6FA))),
                    ],
                  ),
                ),
                _Limit(
                  key: const ValueKey('spin2win-payout-min'),
                  label: 'MIN',
                  amount: kSpin2WinMinStake,
                  colors: const [Color(0xFF7DFFAE), Color(0xFF19D96B), Color(0xFF0A9A45)],
                  edge: const Color(0xFFC8FFDD),
                  under: const Color(0xFF04461F),
                  labelColor: const Color(0xFF04461F),
                ),
                const SizedBox(width: 10),
                _Limit(
                  key: const ValueKey('spin2win-payout-max'),
                  label: 'MAX',
                  amount: kSpin2WinMaxStake,
                  colors: const [Color(0xFFB98BFF), Color(0xFF853BFF), Color(0xFF5A1FC2)],
                  edge: const Color(0xFFE0CCFF),
                  under: const Color(0xFF2A0C5E),
                  labelColor: const Color(0xFFE0CCFF),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.edge, required this.tint, required this.child});

  final Color edge;
  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: edge, width: 2),
        gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [tint, const Color(0xCC061030)]),
      ),
      child: child,
    );
  }
}

/// One bonus and what the chip wins with it: the bonus pill, then the amount on gold.
class _PayoutPill extends StatelessWidget {
  const _PayoutPill({required this.bonus, required this.amount});

  final int bonus;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('spin2win-payout-$bonus'),
      height: 36,
      padding: const EdgeInsets.only(left: 5, right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFF0C0), width: 2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE07A), Color(0xFFFFB52E), Color(0xFFD98300)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFF663C00), offset: Offset(0, 4)),
          BoxShadow(color: Color(0x5CFFB52E), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          _BonusPill(bonus, height: 22, fontSize: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: _OswaldOutlined(spin2WinAmountText(amount), size: 18, stroke: const Color(0xFF7A4500)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Limit extends StatelessWidget {
  const _Limit({
    super.key,
    required this.label,
    required this.amount,
    required this.colors,
    required this.edge,
    required this.under,
    required this.labelColor,
  });

  final String label;
  final int amount;
  final List<Color> colors;
  final Color edge;
  final Color under;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: edge, width: 2),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
        boxShadow: [BoxShadow(color: under, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, height: 1, letterSpacing: 1.5, color: labelColor)),
          const SizedBox(height: 3),
          _OswaldOutlined(spin2WinAmountText(amount), size: 22, stroke: under.withValues(alpha: 0.9)),
        ],
      ),
    );
  }
}

/// White Oswald figures with a dark outline under them (`-webkit-text-stroke` with
/// `paint-order: stroke fill`), centred in their box (see [Spin2WinCapsCentred]).
class _OswaldOutlined extends StatelessWidget {
  const _OswaldOutlined(this.text, {required this.size, required this.stroke});

  final String text;
  final double size;
  final Color stroke;

  @override
  Widget build(BuildContext context) {
    TextStyle style(Paint? fg) => TextStyle(
          fontFamily: kSpin2WinDigitsFont,
          fontWeight: FontWeight.w700,
          fontSize: size,
          height: 1,
          color: fg == null ? const Color(0xFFFFFFFF) : null,
          foreground: fg,
        );
    return Spin2WinCapsCentred(
      size: size,
      digitsFont: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            text,
            maxLines: 1,
            style: style(Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeJoin = StrokeJoin.round
              ..color = stroke),
          ),
          Text(text, maxLines: 1, style: style(null)),
        ],
      ),
    );
  }
}
