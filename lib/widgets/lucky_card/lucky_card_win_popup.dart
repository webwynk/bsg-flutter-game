// The win popup: a blurred, dimmed backdrop with a framed card on top that says
// what the player won, and why: the amount, the winning card and its bonus.
//
// It looks like Triple Chance's, which cannot be imported (it reads Triple Chance's
// own provider), so it is rebuilt: the same frame and title pictures (read-only,
// both already bundled), an 80% dark backdrop blurred by 5, a green 3D amount box,
// a gold 20 dp frame border, an entrance of 0.5 to 1 scale over 400 ms with a 300 ms
// fade, no dismiss control, and the whole screen behind it blocked. The sizes come
// from the layout, so it fits every phone and tablet. Triple Chance's
// Single/Double/Triple breakdown is replaced by the winning card and its bonus
// (the user's decision of 2026-10-06, §17U).
//
// Belongs to Lucky Card only.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../print_ticket/lucky_card_tickets.dart';
import '../../providers/lucky_card_provider.dart';
import 'lucky_card_art.dart';
import 'lucky_card_layout.dart';
import 'lucky_card_top_bar.dart' show luckyCardGroupedBalance;

class LuckyCardWinPopup extends StatelessWidget {
  const LuckyCardWinPopup({
    super.key,
    required this.outcome,
    required this.layout,
    required this.art,
    this.tickets = const [],
  });

  final LuckyCardOutcome outcome;

  /// A print player's tickets in this round; empty for a normal bet.
  final List<LuckyCardTicket> tickets;
  final LuckyCardLayout layout;
  final LuckyCardArt art;

  /// What a screen reader announces.
  String get announcement {
    final card = outcome.winningCard;
    final bonus = outcome.bonusMultiplier > 1 ? ', ${outcome.bonusMultiplier}X' : '';
    return 'You won ${outcome.payout} coins. Winning card ${card.rank.label} of ${card.suit.label}$bonus';
  }

  @override
  Widget build(BuildContext context) {
    final rect = layout.winPopup.shift(layout.canvasRect.topLeft);
    return Semantics(
      liveRegion: true,
      label: announcement,
      excludeSemantics: true,
      // Everything behind the popup is blocked, as in Triple Chance.
      child: AbsorbPointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.80)),
            ),
            Positioned.fromRect(
              rect: rect,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                builder: (context, t, child) => Opacity(
                  opacity: math.min(1.0, t / 0.75),
                  child: Transform.scale(scale: 0.5 + 0.5 * Curves.easeOutCubic.transform(t), child: child),
                ),
                child: tickets.isEmpty
                    ? _Body(outcome: outcome, layout: layout, art: art, size: rect.size)
                    : _TicketBody(outcome: outcome, tickets: tickets, layout: layout, art: art, size: rect.size),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How many winning tickets the popup lists; the rest are counted, and all are in History.
const int kLuckyCardPopupTickets = 3;

/// The popup for a print player: the same frame, the total first, the winning card with its bonus,
/// then the tickets that won on it, in a fixed height.
class _TicketBody extends StatelessWidget {
  const _TicketBody({
    required this.outcome,
    required this.tickets,
    required this.layout,
    required this.art,
    required this.size,
  });

  final LuckyCardOutcome outcome;
  final List<LuckyCardTicket> tickets;
  final LuckyCardLayout layout;
  final LuckyCardArt art;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height;
    final winners = [for (final t in tickets) if (t.win > 0) t];
    final shown = winners.take(kLuckyCardPopupTickets).toList();
    final more = winners.length - shown.length;
    final play = tickets.fold<int>(0, (s, t) => s + t.totalStake);
    final line = h * 0.052;
    final card = outcome.winningCard;
    TextStyle style(double size, Color color, {FontWeight weight = FontWeight.w700}) =>
        TextStyle(fontFamily: 'Oswald', fontWeight: weight, fontSize: size, height: 1.1, color: color);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37), width: 3),
        gradient: const RadialGradient(colors: [Color(0xFF5A0508), Color(0xFF0C0000)]),
      ),
      padding: EdgeInsets.symmetric(horizontal: w * 0.07, vertical: h * 0.05),
      child: Column(
        children: [
          Text('YOU HAVE WON', maxLines: 1, style: style(h * 0.085, const Color(0xFFFFD700))),
          SizedBox(height: h * 0.02),
          Container(
            key: const ValueKey('win-popup-total'),
            width: w * 0.46,
            height: h * 0.16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(h * 0.08),
              gradient: const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF55FF55), Color(0xFF005500)]),
            ),
            child: Text(luckyCardGroupedBalance(outcome.payout), maxLines: 1, style: style(h * 0.11, Colors.white)),
          ),
          SizedBox(height: h * 0.025),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${card.rank.dbValue} of ${card.suit.label}', maxLines: 1, style: style(line * 1.3, Colors.white)),
              if (outcome.bonusMultiplier > 1) ...[
                SizedBox(width: w * 0.02),
                Text('${outcome.bonusMultiplier}X', style: style(line * 1.3, const Color(0xFFFFE14A))),
              ],
            ],
          ),
          SizedBox(height: h * 0.012),
          Row(
            children: [
              Expanded(flex: 2, child: Text('TICKET', maxLines: 1, style: style(line * 0.72, const Color(0xFFD4AF37)))),
              Expanded(child: Text('BET', maxLines: 1, textAlign: TextAlign.right, style: style(line * 0.72, const Color(0xFFD4AF37)))),
              Expanded(child: Text('WIN', maxLines: 1, textAlign: TextAlign.right, style: style(line * 0.72, const Color(0xFFD4AF37)))),
            ],
          ),
          for (final t in shown)
            Padding(
              padding: EdgeInsets.symmetric(vertical: h * 0.004),
              child: Row(
                key: ValueKey('win-ticket-${t.id}'),
                children: [
                  Expanded(flex: 2, child: Text(t.code, maxLines: 1, style: style(line, const Color(0xFFFFE58A)))),
                  Expanded(child: Text(luckyCardGroupedBalance(t.totalStake), maxLines: 1, textAlign: TextAlign.right, style: style(line, Colors.white))),
                  Expanded(child: Text(luckyCardGroupedBalance(t.win), maxLines: 1, textAlign: TextAlign.right, style: style(line, const Color(0xFF7CFF9A)))),
                ],
              ),
            ),
          if (more > 0)
            Text('and $more more ticket${more == 1 ? '' : 's'}',
                key: const ValueKey('win-more-tickets'), maxLines: 1, style: style(line * 0.85, const Color(0xFFF5E6C4))),
          const Spacer(),
          Text('Round total play ${luckyCardGroupedBalance(play)} - all tickets in History',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: style(line * 0.8, const Color(0xFFC9B58F), weight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.outcome, required this.layout, required this.art, required this.size});

  final LuckyCardOutcome outcome;
  final LuckyCardLayout layout;
  final LuckyCardArt art;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final titleW = w * 0.68;
    final titleH = titleW / LuckyCardLayout.winTextAspect;
    final boxW = w * 0.46;
    final boxH = h * 0.20;
    final cardSide = h * 0.30;
    final bonusSize = math.max(cardSide * 0.62, kLuckyCardMinReadableDp);
    final amountSize = math.max(boxH * 0.62, kLuckyCardMinReadableDp);

    // The card and, if there is a bonus, its multiplier beside it, centred together.
    final bonusLabel = '${outcome.bonusMultiplier}X';
    final bonusStyle = TextStyle(
      fontFamily: 'DMSans',
      fontWeight: FontWeight.w700,
      fontSize: bonusSize,
      height: 1.0,
      color: const Color(0xFFFFE14A),
      shadows: const [
        Shadow(color: Color(0xFFFFB800), blurRadius: 8),
        Shadow(color: Color(0x99000000), blurRadius: 2, offset: Offset(0, 1)),
      ],
    );
    final hasBonus = outcome.bonusMultiplier > 1;
    var bonusW = 0.0;
    if (hasBonus) {
      final probe = TextPainter(
        text: TextSpan(text: bonusLabel, style: bonusStyle),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      bonusW = probe.width;
      probe.dispose();
    }
    final gap = h * 0.05;
    final rowW = cardSide + (hasBonus ? gap + bonusW : 0);
    final rowLeft = (w - rowW) / 2;
    final rowTop = h * 0.60;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37), width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x66D4AF37), blurRadius: 40)],
        image: DecorationImage(
          image: art.image(LuckyCardArtKey.winPopup, cacheWidth: layout.winPopupCacheWidth(dpr)),
          fit: BoxFit.fill,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. The title.
          Positioned(
            left: (w - titleW) / 2,
            top: h * 0.07,
            width: titleW,
            height: titleH,
            child: Image(
              key: const ValueKey('win-title'),
              image: art.image(LuckyCardArtKey.winText, cacheWidth: LuckyCardLayout.cacheWidth(titleW, dpr)),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          ),
          // 2. The amount, in the green box.
          Positioned(
            left: (w - boxW) / 2,
            top: h * 0.34,
            width: boxW,
            height: boxH,
            child: DecoratedBox(
              key: const ValueKey('win-amount-box'),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF55FF55), Color(0xFF00AA00), Color(0xFF005500)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(boxH * 0.45),
                border: Border.all(color: const Color(0xFF99FF99), width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Center(
                child: OverflowBox(
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: Text(
                    '${outcome.payout}',
                    key: const ValueKey('win-amount'),
                    maxLines: 1,
                    softWrap: false,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: 'Oswald',
                      fontWeight: FontWeight.w700,
                      fontSize: amountSize,
                      height: 1.0,
                      letterSpacing: 2,
                      color: Colors.white,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 3. Why: the winning card and its bonus.
          Positioned(
            left: rowLeft,
            top: rowTop,
            width: cardSide,
            height: cardSide,
            child: Image(
              key: ValueKey('win-card-${outcome.winningCard.key}'),
              image: art.image(
                LuckyCardArtKey.card(outcome.winningCard),
                cacheWidth: LuckyCardLayout.cacheWidth(cardSide, dpr),
              ),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          ),
          if (hasBonus)
            Positioned(
              left: rowLeft + cardSide + gap,
              top: rowTop,
              height: cardSide,
              width: bonusW,
              child: Center(
                child: OverflowBox(
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: Text(
                    bonusLabel,
                    key: const ValueKey('win-bonus'),
                    maxLines: 1,
                    softWrap: false,
                    textScaler: TextScaler.noScaling,
                    style: bonusStyle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
