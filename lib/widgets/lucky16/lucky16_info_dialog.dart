// The Lucky 16 Card Info popup, "HOW TO PLAY": two tabs, RULES and PAYOUTS, in the new design Hasan
// approved (lucky16_popup_kit.dart).
//
//   Lucky16InfoDialog.show(context, provider: provider, art: art)
//
// It behaves exactly as Lucky Card's Info dialog (lucky_card_info_dialog.dart):
//   * it closes by itself, with a fade, the moment betting closes, so the wheel, the card and the win
//     popup are never hidden behind it; opened while betting is already closed, it closes at once;
//   * a tap outside closes it; both tabs scroll and each opens at its top;
//   * the tabs and the close button answer over at least 48 dp; all text is at least 11 dp and ignores
//     the phone's font-size setting; its size follows the screen, never the font size;
//   * the open sound and the tab click are hooks ([onOpen], [onTab]) for the screen.
//
// RULES is six rule cards in two columns and a full-width card of the four buttons. PAYOUTS is the
// formula and a worked example, the table of what a stake of 10 wins at N and 2X to 10X, and the limits.
// The words are in lucky16_info_text.dart.
//
// Belongs to Lucky 16 Card only.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/lucky16_board.dart';
import '../../models/lucky16_models.dart';
import '../../providers/lucky16_provider.dart';
import 'lucky16_art.dart';
import 'lucky16_info_text.dart';
import 'lucky16_layout.dart';
import 'lucky16_panel.dart';
import 'lucky16_popup_kit.dart';

enum Lucky16InfoTab { rules, payouts }

class Lucky16InfoDialog extends StatefulWidget {
  const Lucky16InfoDialog({
    super.key,
    required this.provider,
    required this.art,
    this.onTab,
    this.initialTab = Lucky16InfoTab.rules,
  });

  /// Watched so the popup can close when betting closes.
  final Lucky16Provider provider;
  final Lucky16Art art;

  /// A tab was chosen (the click sound).
  final void Function(Lucky16InfoTab tab)? onTab;
  final Lucky16InfoTab initialTab;

  /// How much of the canvas the popup covers.
  static const double widthShare = 0.8;
  static const double heightShare = 0.92;

  /// Shows the popup over the screen. Completes when it closes, for any reason.
  static Future<void> show(
    BuildContext context, {
    required Lucky16Provider provider,
    required Lucky16Art art,
    VoidCallback? onOpen,
    void Function(Lucky16InfoTab tab)? onTab,
    Lucky16InfoTab initialTab = Lucky16InfoTab.rules,
  }) {
    onOpen?.call();
    return showLucky16Popup<void>(
      context,
      builder: (_) => Lucky16InfoDialog(provider: provider, art: art, onTab: onTab, initialTab: initialTab),
    );
  }

  @override
  State<Lucky16InfoDialog> createState() => _Lucky16InfoDialogState();
}

class _Lucky16InfoDialogState extends State<Lucky16InfoDialog> with Lucky16ClosesWhenBettingCloses<Lucky16InfoDialog> {
  late Lucky16InfoTab _tab = widget.initialTab;

  @override
  Lucky16Provider get bettingProvider => widget.provider;

  void _choose(Lucky16InfoTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    widget.onTab?.call(tab);
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
        label: 'How to play',
        child: Center(
          child: SizedBox(
            key: const ValueKey('info-dialog'),
            width: canvas.width * Lucky16InfoDialog.widthShare,
            height: canvas.height * Lucky16InfoDialog.heightShare,
            child: Material(
              type: MaterialType.transparency,
              child: Lucky16PopupFrame(
                layout: layout,
                child: Column(
                  children: [
                    Lucky16PopupHeader(
                      layout: layout,
                      title: kLucky16InfoTitle,
                      close: Lucky16CloseButton(key: const ValueKey('info-close'), layout: layout, onTap: closeByHand),
                    ),
                    _tabs(layout),
                    SizedBox(height: layout.dp(12)),
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey('info-body-${_tab.name}'),
                        child: _Scroller(
                          layout: layout,
                          children: _tab == Lucky16InfoTab.rules
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
  Widget _tabs(Lucky16Layout layout) {
    // The drawn switch (a line of text, the pill's padding, the switch's padding and its 1 dp edge) outgrows
    // the 48 dp row on a tablet: the row then follows it, so the pills are never cut.
    final drawn = layout.fontSize(34) * 1.1 + 2 * layout.dp(12) + 2 * layout.dp(8) + 2;
    return SizedBox(
      height: math.max(drawn, kLucky16MinTapDp),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Container(
              padding: EdgeInsets.all(layout.dp(8)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.black.withValues(alpha: 0.45),
                border: Border.all(color: kLucky16Gold.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tabPill(layout, Lucky16InfoTab.rules, kLucky16RulesTab),
                  SizedBox(width: layout.dp(8)),
                  _tabPill(layout, Lucky16InfoTab.payouts, kLucky16PayoutsTab),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                Expanded(child: _tabArea(Lucky16InfoTab.rules, kLucky16RulesTab, 'info-tab-rules')),
                Expanded(child: _tabArea(Lucky16InfoTab.payouts, kLucky16PayoutsTab, 'info-tab-payouts')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A tab's tap area.
  Widget _tabArea(Lucky16InfoTab tab, String label, String key) => Semantics(
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
  Widget _tabPill(Lucky16Layout layout, Lucky16InfoTab tab, String label) {
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
                colors: kLucky16GoldFace,
                stops: kLucky16GoldFaceStops,
              ),
              boxShadow: [
                BoxShadow(color: const Color(0xFF7A5A0E), offset: Offset(0, layout.dp(4))),
                BoxShadow(color: kLucky16GoldBright.withValues(alpha: 0.35), blurRadius: layout.dp(18)),
              ],
            )
          : null,
      child: lucky16PopupText(
        label,
        layout,
        weight: FontWeight.w600,
        units: 34,
        spacing: 0.16,
        color: selected ? kLucky16PopupInk : kLucky16Cream.withValues(alpha: 0.65),
      ),
    );
  }
}

class _Scroller extends StatelessWidget {
  const _Scroller({required this.layout, required this.children});

  final Lucky16Layout layout;
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
  Lucky16Layout layout, {
  Key? key,
  double units = 29,
  double alpha = 1,
  TextAlign? align,
}) =>
    lucky16PopupText(
      text,
      layout,
      key: key,
      family: 'DMSans',
      weight: FontWeight.w500,
      units: units,
      color: kLucky16Cream.withValues(alpha: alpha),
      height: 1.35,
      maxLines: null,
      align: align,
    );

/// One rule: the numbered badge, then the heading over the body.
class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.layout, required this.number, required this.heading, required this.body});

  final Lucky16Layout layout;
  final int number;
  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    final badge = math.max(layout.dp(58), 24.0);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: layout.dp(22), vertical: layout.dp(18)),
      decoration: lucky16PopupCard(layout),
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
              border: Border.all(color: kLucky16Gold, width: math.max(layout.dp(3), 1.2)),
            ),
            child: lucky16PopupText(
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
                lucky16PopupText(
                  heading,
                  layout,
                  weight: FontWeight.w600,
                  units: 33,
                  color: kLucky16GoldBright,
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

  final Lucky16Layout layout;

  @override
  Widget build(BuildContext context) {
    final lines = lucky16RulesLines();
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
      decoration: lucky16PopupCard(layout),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          lucky16PopupText(
            '7  $kLucky16ButtonsHeading',
            layout,
            weight: FontWeight.w600,
            units: 33,
            color: kLucky16GoldBright,
          ),
          SizedBox(height: layout.dp(10)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < kLucky16ButtonLines.length; i++) ...[
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
                            colors: [Color(0xFF6B1620), kLucky16PopupInk],
                          ),
                          border: Border.all(color: kLucky16Gold),
                        ),
                        child: lucky16PopupText(
                          kLucky16ButtonLines[i].label,
                          layout,
                          weight: FontWeight.w700,
                          units: 26,
                        ),
                      ),
                      SizedBox(height: layout.dp(6)),
                      _body(kLucky16ButtonLines[i].body, layout, units: 26, align: TextAlign.center),
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
Widget _kicker(String text, Lucky16Layout layout) => lucky16PopupText(
      text,
      layout,
      units: 25,
      spacing: 0.2,
      color: kLucky16Cream.withValues(alpha: 0.75),
      maxLines: null,
    );

class _PayoutsBody extends StatelessWidget {
  const _PayoutsBody({required this.layout, required this.art});

  final Lucky16Layout layout;
  final Lucky16Art art;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(horizontal: layout.dp(24), vertical: layout.dp(22));
    final card = lucky16PopupCard(layout, radius: 20, borderAlpha: 0.3);
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
                      _kicker(kLucky16PayoutKicker, layout),
                      SizedBox(height: layout.dp(12)),
                      _formula(),
                      SizedBox(height: layout.dp(14)),
                      _example(context),
                      SizedBox(height: layout.dp(12)),
                      _body(lucky16ExampleText(), layout,
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
                      _kicker(lucky16TableTitle(), layout),
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
        _body(lucky16LimitsText(), layout,
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
                    colors: kLucky16GoldFace,
                    stops: kLucky16GoldFaceStops,
                  )
                : null,
            border: Border.all(color: kLucky16Gold.withValues(alpha: 0.45)),
          ),
          child: lucky16PopupText(
            text,
            layout,
            weight: FontWeight.w700,
            units: 40,
            color: gold ? kLucky16PopupInk : kLucky16Cream,
          ),
        );
    Widget times() => Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.dp(8)),
          child: lucky16PopupText('x', layout, weight: FontWeight.w700, units: 40, color: kLucky16Gold),
        );
    return FittedBox(
      key: const ValueKey('payout-formula'),
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [box('STAKE'), times(), box('$kLucky16PayoutMultiplier', gold: true), times(), box('BONUS')],
      ),
    );
  }

  /// The example in pictures: the card with its chip, what it pays, the bonus, what that makes.
  Widget _example(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final chip = math.max(layout.dp(46), 20.0);
    Widget arrow() => Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.dp(9)),
          child: Icon(Icons.arrow_forward_rounded, size: layout.fontSize(30, minDp: 12), color: kLucky16Gold),
        );
    final plain = lucky16PayoutFor(kLucky16ExampleStake, 1);
    final bonus = lucky16PayoutFor(kLucky16ExampleStake, kLucky16ExampleBonus);
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
              Lucky16MiniCard(
                layout: layout,
                art: art,
                card: const Lucky16Card(Lucky16Rank.ace, Lucky16Suit.spades),
                width: 66,
                height: 92,
              ),
              Positioned(
                right: -chip * 0.4,
                bottom: -chip * 0.2,
                child: Image(
                  image:
                      art.image(Lucky16ArtKey.chip(Lucky16Chip.ten), cacheWidth: Lucky16Layout.cacheWidth(chip, dpr)),
                  width: chip,
                  height: chip,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
          SizedBox(width: chip * 0.3),
          arrow(),
          lucky16PopupText(lucky16Grouped(plain), layout, weight: FontWeight.w700, units: 40),
          arrow(),
          Lucky16BonusPill(layout: layout, bonus: kLucky16ExampleBonus, units: 34),
          arrow(),
          Lucky16GoldText(lucky16Grouped(bonus), layout: layout, units: 52, spacing: 0.02, drop: 2),
        ],
      ),
    );
  }

  /// Five tiles across, two down; 10X is lit.
  Widget _table() {
    final rows = lucky16PayoutTable();
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
              ? Border.all(color: kLucky16GoldBright, width: math.max(layout.dp(3), 1.2))
              : Border.all(color: kLucky16Gold.withValues(alpha: 0.45)),
          boxShadow:
              top ? [BoxShadow(color: kLucky16GoldBright.withValues(alpha: 0.4), blurRadius: layout.dp(18))] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            lucky16PopupText(row.bonus, layout, weight: FontWeight.w700, units: 38, color: kLucky16GoldBright),
            SizedBox(height: layout.dp(3)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: lucky16PopupText(lucky16Grouped(row.win), layout, units: 31),
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
