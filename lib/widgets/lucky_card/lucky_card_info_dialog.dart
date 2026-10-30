// The Lucky Card Info popup, "HOW TO PLAY": two tabs, RULES and PAYOUTS, in the design Hasan approved
// for Lucky 16 Card (lucky_card_popup_kit.dart), with Lucky Card's own rules and numbers.
//
//   LuckyCardInfoDialog.show(context, provider: provider)
//
// How it behaves did not change with the new design:
//   * it closes by itself, with a fade, the moment betting closes, so the wheel, the card and the win
//     popup are never hidden behind it (Triple Chance keeps its dialog open); opened while betting is
//     already closed, it closes at once;
//   * a tap outside closes it; both tabs scroll and each opens at its top;
//   * the tabs and the close button answer over at least 48 dp; all text is at least 11 dp and ignores
//     the phone's font-size setting; its size follows the screen, never the font size;
//   * the open sound and the tab click are hooks ([onOpen], [onTab]) for the screen.
//
// RULES is six rule cards in two columns and a full-width card of the four buttons. PAYOUTS is the
// formula and a worked example, the table of what a stake of 10 wins at N and 2X to 10X, and the limits.
// The words are in lucky_card_info_text.dart.
//
// Belongs to Lucky Card only.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/lucky_card_board.dart';
import '../../models/lucky_card_models.dart';
import '../../providers/lucky_card_provider.dart';
import 'lucky_card_art.dart';
import 'lucky_card_info_text.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_panel.dart';
import 'lucky_card_popup_kit.dart';

enum LuckyCardInfoTab { rules, payouts }

class LuckyCardInfoDialog extends StatefulWidget {
  const LuckyCardInfoDialog({
    super.key,
    required this.provider,
    this.art = const AssetLuckyCardArt(),
    this.onTab,
    this.initialTab = LuckyCardInfoTab.rules,
  });

  /// Watched so the popup can close when betting closes.
  final LuckyCardProvider provider;
  final LuckyCardArt art;

  /// A tab was chosen (the click sound).
  final void Function(LuckyCardInfoTab tab)? onTab;
  final LuckyCardInfoTab initialTab;

  /// How much of the canvas the popup covers.
  static const double widthShare = 0.8;
  static const double heightShare = 0.92;

  /// Shows the popup over the screen. Completes when it closes, for any reason.
  static Future<void> show(
    BuildContext context, {
    required LuckyCardProvider provider,
    LuckyCardArt art = const AssetLuckyCardArt(),
    VoidCallback? onOpen,
    void Function(LuckyCardInfoTab tab)? onTab,
    LuckyCardInfoTab initialTab = LuckyCardInfoTab.rules,
  }) {
    onOpen?.call();
    return showLuckyCardPopup<void>(
      context,
      builder: (_) => LuckyCardInfoDialog(provider: provider, art: art, onTab: onTab, initialTab: initialTab),
    );
  }

  @override
  State<LuckyCardInfoDialog> createState() => _LuckyCardInfoDialogState();
}

class _LuckyCardInfoDialogState extends State<LuckyCardInfoDialog> with LuckyCardClosesWhenBettingCloses<LuckyCardInfoDialog> {
  late LuckyCardInfoTab _tab = widget.initialTab;

  @override
  LuckyCardProvider get bettingProvider => widget.provider;

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
            width: canvas.width * LuckyCardInfoDialog.widthShare,
            height: canvas.height * LuckyCardInfoDialog.heightShare,
            child: Material(
              type: MaterialType.transparency,
              child: LuckyCardPopupFrame(
                layout: layout,
                child: Column(
                  children: [
                    LuckyCardPopupHeader(
                      layout: layout,
                      title: kLuckyCardInfoTitle,
                      close: LuckyCardCloseButton(key: const ValueKey('info-close'), layout: layout, onTap: closeByHand),
                    ),
                    _tabs(layout),
                    SizedBox(height: layout.dp(12)),
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey('info-body-${_tab.name}'),
                        child: _Scroller(
                          layout: layout,
                          children: _tab == LuckyCardInfoTab.rules
                              ? [_RulesBody(layout: layout)]
                              : [_PayoutsBody(layout: layout, art: widget.art)],
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

  /// The pill switch under the header. The drawn pills are low; each tab answers over its half of a row
  /// 48 dp tall, so the tap rule is kept without the switch taking that height on a small phone.
  Widget _tabs(LuckyCardLayout layout) {
    // The drawn switch (a line of text, the pill's padding, the switch's padding and its 1 dp edge) outgrows
    // the 48 dp row on a tablet: the row then follows it, so the pills are never cut.
    final drawn = layout.fontSize(34) * 1.1 + 2 * layout.dp(12) + 2 * layout.dp(8) + 2;
    return SizedBox(
      height: math.max(drawn, kLuckyCardMinTapDp),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Only drawn: the tap areas below answer the finger and the screen reader.
          ExcludeSemantics(
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.all(layout.dp(8)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.black.withValues(alpha: 0.45),
                  border: Border.all(color: kLuckyCardGold.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tabPill(layout, LuckyCardInfoTab.rules, kLuckyCardRulesTab),
                    SizedBox(width: layout.dp(8)),
                    _tabPill(layout, LuckyCardInfoTab.payouts, kLuckyCardPayoutsTab),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                Expanded(child: _tabArea(LuckyCardInfoTab.rules, kLuckyCardRulesTab, 'info-tab-rules')),
                Expanded(child: _tabArea(LuckyCardInfoTab.payouts, kLuckyCardPayoutsTab, 'info-tab-payouts')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A tab's tap area.
  Widget _tabArea(LuckyCardInfoTab tab, String label, String key) => Semantics(
        button: true,
        selected: tab == _tab,
        excludeSemantics: true,
        label: label,
        onTap: () => _choose(tab),
        child: GestureDetector(
          key: ValueKey(key),
          behavior: HitTestBehavior.opaque,
          onTap: () => _choose(tab),
        ),
      );

  /// A tab as drawn: gold when chosen.
  Widget _tabPill(LuckyCardLayout layout, LuckyCardInfoTab tab, String label) {
    final selected = tab == _tab;
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: layout.dp(56), vertical: layout.dp(12)),
      decoration: selected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: kLuckyCardGoldFace,
                stops: kLuckyCardGoldFaceStops,
              ),
              boxShadow: [
                BoxShadow(color: const Color(0xFF7A5A0E), offset: Offset(0, layout.dp(4))),
                BoxShadow(color: kLuckyCardGoldBright.withValues(alpha: 0.35), blurRadius: layout.dp(18)),
              ],
            )
          : null,
      child: luckyCardPopupText(
        label,
        layout,
        weight: FontWeight.w600,
        units: 34,
        spacing: 0.16,
        color: selected ? kLuckyCardPopupInk : kLuckyCardCream.withValues(alpha: 0.65),
      ),
    );
  }
}

class _Scroller extends StatelessWidget {
  const _Scroller({required this.layout, required this.children});

  final LuckyCardLayout layout;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        key: const ValueKey('info-scroll'),
        padding: EdgeInsets.fromLTRB(layout.dp(36), 0, layout.dp(36), layout.dp(30)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

/// A body line in DM Sans.
Text _body(
  String text,
  LuckyCardLayout layout, {
  Key? key,
  double units = 29,
  double alpha = 1,
  TextAlign? align,
}) =>
    luckyCardPopupText(
      text,
      layout,
      key: key,
      family: 'DMSans',
      weight: FontWeight.w500,
      units: units,
      color: kLuckyCardCream.withValues(alpha: alpha),
      height: 1.35,
      maxLines: null,
      align: align,
    );

/// One rule: the numbered badge, then the heading over the body.
class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.layout, required this.number, required this.heading, required this.body});

  final LuckyCardLayout layout;
  final int number;
  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    final badge = math.max(layout.dp(58), 24.0);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: layout.dp(22), vertical: layout.dp(18)),
      decoration: luckyCardPopupCard(layout),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: badge,
            height: badge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xFFD4232B), Color(0xFF8B0000), Color(0xFF4A0000)]),
              border: Border.all(color: kLuckyCardGold, width: math.max(layout.dp(3), 1.2)),
            ),
            child: luckyCardPopupText(
              '$number',
              layout,
              weight: FontWeight.w700,
              units: 30,
              color: const Color(0xFFFFF6DA),
            ),
          ),
          SizedBox(width: layout.dp(18)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                luckyCardPopupText(
                  heading,
                  layout,
                  weight: FontWeight.w600,
                  units: 33,
                  color: kLuckyCardGoldBright,
                  maxLines: null,
                ),
                SizedBox(height: layout.dp(4)),
                _body(body, layout, key: ValueKey('rule-${number - 1}')),
              ],
            ),
          ),
        ],
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
    final gap = layout.dp(14);
    Widget pair(int left) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final i in [left, left + 1]) ...[
                if (i != left) SizedBox(width: gap),
                Expanded(
                  child: _RuleCard(layout: layout, number: i + 1, heading: lines[i].heading, body: lines[i].body),
                ),
              ],
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i += 2) ...[pair(i), SizedBox(height: gap)],
        _buttonsCard(),
      ],
    );
  }

  /// The seventh rule, across the whole width: the four buttons.
  Widget _buttonsCard() {
    return Container(
      key: const ValueKey('rule-6'),
      padding: EdgeInsets.symmetric(horizontal: layout.dp(22), vertical: layout.dp(18)),
      decoration: luckyCardPopupCard(layout),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          luckyCardPopupText(
            '7  $kLuckyCardButtonsHeading',
            layout,
            weight: FontWeight.w600,
            units: 33,
            color: kLuckyCardGoldBright,
          ),
          SizedBox(height: layout.dp(10)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < kLuckyCardButtonLines.length; i++) ...[
                if (i > 0) SizedBox(width: layout.dp(14)),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(vertical: layout.dp(5)),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(layout.dp(12)),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF6B1620), kLuckyCardPopupInk],
                          ),
                          border: Border.all(color: kLuckyCardGold),
                        ),
                        child: luckyCardPopupText(
                          kLuckyCardButtonLines[i].label,
                          layout,
                          weight: FontWeight.w700,
                          units: 26,
                        ),
                      ),
                      SizedBox(height: layout.dp(6)),
                      _body(kLuckyCardButtonLines[i].body, layout, units: 26, align: TextAlign.center),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A small heading over a block.
Widget _kicker(String text, LuckyCardLayout layout) => luckyCardPopupText(
      text,
      layout,
      units: 25,
      spacing: 0.2,
      color: kLuckyCardCream.withValues(alpha: 0.75),
      maxLines: null,
    );

class _PayoutsBody extends StatelessWidget {
  const _PayoutsBody({required this.layout, required this.art});

  final LuckyCardLayout layout;
  final LuckyCardArt art;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(horizontal: layout.dp(24), vertical: layout.dp(22));
    final card = luckyCardPopupCard(layout, radius: 20, borderAlpha: 0.3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  padding: padding,
                  decoration: card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kicker(kLuckyCardPayoutKicker, layout),
                      SizedBox(height: layout.dp(12)),
                      _formula(),
                      SizedBox(height: layout.dp(14)),
                      _example(context),
                      SizedBox(height: layout.dp(12)),
                      _body(luckyCardExampleText(), layout,
                          key: const ValueKey('payout-example'), units: 27, alpha: 0.85),
                    ],
                  ),
                ),
              ),
              SizedBox(width: layout.dp(20)),
              Expanded(
                flex: 6,
                child: Container(
                  padding: padding,
                  decoration: card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _kicker(luckyCardTableTitle(), layout),
                      SizedBox(height: layout.dp(12)),
                      _table(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: layout.dp(16)),
        _body(luckyCardLimitsText(), layout,
            key: const ValueKey('payout-limits'), units: 27, alpha: 0.8, align: TextAlign.center),
      ],
    );
  }

  /// [STAKE] x [14] x [BONUS].
  Widget _formula() {
    Widget box(String text, {bool gold = false}) => Container(
          padding: EdgeInsets.symmetric(horizontal: layout.dp(16), vertical: layout.dp(5)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(layout.dp(12)),
            color: gold ? null : Colors.black.withValues(alpha: 0.35),
            gradient: gold
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: kLuckyCardGoldFace,
                    stops: kLuckyCardGoldFaceStops,
                  )
                : null,
            border: Border.all(color: kLuckyCardGold.withValues(alpha: 0.45)),
          ),
          child: luckyCardPopupText(
            text,
            layout,
            weight: FontWeight.w700,
            units: 40,
            color: gold ? kLuckyCardPopupInk : kLuckyCardCream,
          ),
        );
    Widget times() => Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.dp(8)),
          child: luckyCardPopupText('x', layout, weight: FontWeight.w700, units: 40, color: kLuckyCardGold),
        );
    return FittedBox(
      key: const ValueKey('payout-formula'),
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [box('STAKE'), times(), box('$kLuckyCardPayoutMultiplier', gold: true), times(), box('BONUS')],
      ),
    );
  }

  /// The example in pictures: the card with its chip, what it pays, the bonus, what that makes.
  Widget _example(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final chip = math.max(layout.dp(46), 20.0);
    Widget arrow() => Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.dp(9)),
          child: Icon(Icons.arrow_forward_rounded, size: layout.fontSize(30, minDp: 12), color: kLuckyCardGold),
        );
    final plain = luckyCardPayoutFor(kLuckyCardExampleStake, 1);
    final bonus = luckyCardPayoutFor(kLuckyCardExampleStake, kLuckyCardExampleBonus);
    return FittedBox(
      key: const ValueKey('payout-example-row'),
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              LuckyCardMiniCard(
                layout: layout,
                art: art,
                card: const LuckyCard(LuckyCardRank.queen, LuckyCardSuit.spades),
                width: 66,
                height: 92,
              ),
              Positioned(
                right: -chip * 0.4,
                bottom: -chip * 0.2,
                child: Image(
                  image:
                      art.image(LuckyCardArtKey.chip(LuckyCardChip.ten), cacheWidth: LuckyCardLayout.cacheWidth(chip, dpr)),
                  width: chip,
                  height: chip,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
          SizedBox(width: chip * 0.3),
          arrow(),
          luckyCardPopupText(luckyCardGrouped(plain), layout, weight: FontWeight.w700, units: 40),
          arrow(),
          LuckyCardBonusPill(layout: layout, bonus: kLuckyCardExampleBonus, units: 34),
          arrow(),
          LuckyCardGoldText(luckyCardGrouped(bonus), layout: layout, units: 52, spacing: 0.02, drop: 2),
        ],
      ),
    );
  }

  /// Five tiles across, two down; 10X is lit.
  Widget _table() {
    final rows = luckyCardPayoutTable();
    final gap = layout.dp(12);
    Widget tile(({String bonus, int win}) row) {
      final top = row.bonus == '10X';
      return Container(
        key: ValueKey('payout-${row.bonus}'),
        padding: EdgeInsets.symmetric(vertical: layout.dp(10), horizontal: layout.dp(2)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(layout.dp(14)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: top ? const [Color(0xFF7A5A0E), Color(0xFF3A2604)] : const [Color(0xFF4A0F16), Color(0xFF22050A)],
          ),
          border: top
              ? Border.all(color: kLuckyCardGoldBright, width: math.max(layout.dp(3), 1.2))
              : Border.all(color: kLuckyCardGold.withValues(alpha: 0.45)),
          boxShadow:
              top ? [BoxShadow(color: kLuckyCardGoldBright.withValues(alpha: 0.4), blurRadius: layout.dp(18))] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            luckyCardPopupText(row.bonus, layout, weight: FontWeight.w700, units: 38, color: kLuckyCardGoldBright),
            SizedBox(height: layout.dp(3)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: luckyCardPopupText(luckyCardGrouped(row.win), layout, units: 31),
            ),
          ],
        ),
      );
    }

    Widget line(int from) => Row(
          children: [
            for (var i = from; i < from + 5; i++) ...[
              if (i != from) SizedBox(width: gap),
              Expanded(child: tile(rows[i])),
            ],
          ],
        );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [line(0), SizedBox(height: gap), line(5)],
    );
  }
}
