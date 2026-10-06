// The Lucky Card Info dialog: two tabs, RULES and PAYOUTS (spec §17W, §17Z).
//
//   LuckyCardInfoDialog.show(context, provider: provider)
//
//   * It closes by itself, with a fade, the moment betting closes, so the wheel, the card
//     and the win popup are never hidden behind it (Triple Chance keeps its dialog open).
//     Opened while betting is already closed, it closes again at once.
//   * RULES is a numbered list; PAYOUTS has the rule, a worked example, a table of what a
//     stake of 10 wins at N and at 2X to 10X, and the limits. Both scroll; each tab opens at
//     its top.
//   * The tabs and the close button are at least 48 dp each way; all text is at least 11 dp
//     and ignores the phone's font-size setting. The dialog's size follows the screen the
//     same way the game's canvas does, never the font size.
//   * The open sound and the tab click are hooks ([onOpen], [onTab]) for the screen
//     (App Step 8).
//
// The words are in lucky_card_info_text.dart.
//
// Belongs to Lucky Card only.

import 'package:flutter/material.dart';

import '../../providers/lucky_card_provider.dart';
import 'lucky_card_info_text.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_panel.dart';
import 'lucky_card_stake_text.dart';

enum LuckyCardInfoTab { rules, payouts }

class LuckyCardInfoDialog extends StatefulWidget {
  const LuckyCardInfoDialog({super.key, required this.provider, this.onTab, this.initialTab = LuckyCardInfoTab.rules});

  /// Watched so the dialog can close when betting closes.
  final LuckyCardProvider provider;

  /// A tab was chosen (the click sound).
  final void Function(LuckyCardInfoTab tab)? onTab;

  final LuckyCardInfoTab initialTab;

  /// How long the open and the close take.
  static const Duration transition = Duration(milliseconds: 220);

  /// How much of the canvas the dialog covers.
  static const double widthShare = 0.8;
  static const double heightShare = 0.92;

  /// Shows the dialog over the screen. Completes when it closes, for any reason.
  static Future<void> show(
    BuildContext context, {
    required LuckyCardProvider provider,
    VoidCallback? onOpen,
    void Function(LuckyCardInfoTab tab)? onTab,
  }) {
    onOpen?.call();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0xBF000000),
      transitionDuration: transition,
      pageBuilder: (_, __, ___) => LuckyCardInfoDialog(provider: provider, onTab: onTab),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }

  @override
  State<LuckyCardInfoDialog> createState() => _LuckyCardInfoDialogState();
}

class _LuckyCardInfoDialogState extends State<LuckyCardInfoDialog> {
  late LuckyCardInfoTab _tab = widget.initialTab;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_closeIfBettingClosed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _closeIfBettingClosed());
  }

  @override
  void didUpdateWidget(LuckyCardInfoDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      oldWidget.provider.removeListener(_closeIfBettingClosed);
      widget.provider.addListener(_closeIfBettingClosed);
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_closeIfBettingClosed);
    super.dispose();
  }

  void _closeIfBettingClosed() {
    if (!mounted || _closing || !widget.provider.isLocked) return;
    _closing = true;
    final route = ModalRoute.of(context);
    if (route == null) return;
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  void _choose(LuckyCardInfoTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    widget.onTab?.call(tab);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final layout = LuckyCardLayout.of(media.size);
    final canvas = layout.canvasRect;
    final width = canvas.width * LuckyCardInfoDialog.widthShare;
    final height = canvas.height * LuckyCardInfoDialog.heightShare;
    final header = layout.dp(134);

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'How to play',
        child: Center(
          child: SizedBox(
            key: const ValueKey('info-dialog'),
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
                          Expanded(child: _tabButton(layout, LuckyCardInfoTab.rules, kLuckyCardRulesTab, 'info-tab-rules')),
                          Expanded(child: _tabButton(layout, LuckyCardInfoTab.payouts, kLuckyCardPayoutsTab, 'info-tab-payouts')),
                          _closeButton(layout, header),
                        ],
                      ),
                    ),
                    Container(height: 1, color: kLuckyCardGold.withValues(alpha: 0.5)),
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey('info-body-${_tab.name}'),
                        child: _tab == LuckyCardInfoTab.rules ? _RulesBody(layout: layout) : _PayoutsBody(layout: layout),
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

  Widget _tabButton(LuckyCardLayout layout, LuckyCardInfoTab tab, String label, String key) {
    final selected = tab == _tab;
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: label,
      onTap: () => _choose(tab),
      child: GestureDetector(
        key: ValueKey(key),
        behavior: HitTestBehavior.opaque,
        onTap: () => _choose(tab),
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, c) => LuckyCardStakeText(
                label,
                maxWidth: c.maxWidth,
                preferredSize: layout.fontSize(46),
                color: selected ? kLuckyCardGoldBright : kLuckyCardCream.withValues(alpha: 0.65),
              ),
            ),
            if (selected)
              Positioned(
                left: layout.dp(30),
                right: layout.dp(30),
                bottom: 0,
                height: layout.dp(8).clamp(2.0, 4.0).toDouble(),
                child: const ColoredBox(color: kLuckyCardGoldBright),
              ),
          ],
        ),
      ),
    );
  }

  Widget _closeButton(LuckyCardLayout layout, double side) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Close',
      onTap: _close,
      child: GestureDetector(
        key: const ValueKey('info-close'),
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: SizedBox(
          width: side,
          height: side,
          child: Icon(Icons.close_rounded, size: layout.fontSize(60, minDp: 16), color: kLuckyCardCream),
        ),
      ),
    );
  }
}

TextStyle _bodyStyle(LuckyCardLayout layout, {Color color = kLuckyCardCream, FontWeight weight = FontWeight.w500}) =>
    TextStyle(
      fontFamily: 'DMSans',
      fontWeight: weight,
      fontSize: layout.fontSize(36),
      height: 1.3,
      color: color,
    );

class _Scroller extends StatelessWidget {
  const _Scroller({required this.layout, required this.children});

  final LuckyCardLayout layout;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        key: const ValueKey('info-scroll'),
        padding: EdgeInsets.symmetric(horizontal: layout.dp(36), vertical: layout.dp(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}

class _RulesBody extends StatelessWidget {
  const _RulesBody({required this.layout});

  final LuckyCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final lines = luckyCardRulesLines();
    final badge = layout.fontSize(44, minDp: 20);
    return _Scroller(
      layout: layout,
      children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: layout.dp(22)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: badge,
                  height: badge,
                  alignment: Alignment.center,
                  margin: EdgeInsets.only(right: layout.dp(22)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF8B0000),
                    border: Border.all(color: kLuckyCardGold, width: 1.2),
                  ),
                  child: Text(
                    '${i + 1}',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontFamily: 'Oswald', fontWeight: FontWeight.w500, fontSize: layout.fontSize(32), height: 1.0, color: kLuckyCardCream),
                  ),
                ),
                Expanded(
                  child: Text(lines[i], key: ValueKey('rule-$i'), textScaler: TextScaler.noScaling, style: _bodyStyle(layout)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PayoutsBody extends StatelessWidget {
  const _PayoutsBody({required this.layout});

  final LuckyCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final table = luckyCardPayoutTable();
    final gap = layout.dp(12);
    return _Scroller(
      layout: layout,
      children: [
        Text(luckyCardPayoutRule(), key: const ValueKey('payout-rule'), textScaler: TextScaler.noScaling, style: _bodyStyle(layout, color: kLuckyCardGoldBright)),
        SizedBox(height: layout.dp(22)),
        Text(luckyCardExampleText(), key: const ValueKey('payout-example'), textScaler: TextScaler.noScaling, style: _bodyStyle(layout)),
        SizedBox(height: layout.dp(30)),
        Text(luckyCardTableTitle(), key: const ValueKey('payout-table-title'), textScaler: TextScaler.noScaling, style: _bodyStyle(layout, color: kLuckyCardGold, weight: FontWeight.w700)),
        SizedBox(height: layout.dp(14)),
        LayoutBuilder(
          builder: (context, c) {
            // Five cells a row: the bonus above, what it wins below.
            const perRow = 5;
            final cell = (c.maxWidth - gap * (perRow - 1)) / perRow;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final row in table)
                  SizedBox(
                    key: ValueKey('payout-${row.bonus}'),
                    width: cell,
                    height: layout.dp(150),
                    child: LuckyCardPanel(
                      layout: layout,
                      radiusUnits: 14,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: layout.fontSize(34) * 1.1,
                            child: LuckyCardStakeText(row.bonus, maxWidth: cell, preferredSize: layout.fontSize(34), color: kLuckyCardGold),
                          ),
                          SizedBox(
                            height: layout.fontSize(40) * 1.1,
                            child: LuckyCardStakeText(luckyCardGrouped(row.win), maxWidth: cell, preferredSize: layout.fontSize(40)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        SizedBox(height: layout.dp(30)),
        Text(luckyCardLimitsText(), key: const ValueKey('payout-limits'), textScaler: TextScaler.noScaling, style: _bodyStyle(layout)),
      ],
    );
  }
}
