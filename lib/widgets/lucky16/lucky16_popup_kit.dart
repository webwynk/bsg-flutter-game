// The look every Lucky 16 Card popup shares (phone phase 6): the gold-rimmed frame, the dark red panel,
// the gold title, the header with the game's name and the close button, the small cards, and the
// mini playing card. This is the new design Hasan approved for Lucky 16 Card; it is not Lucky Card's
// look. How the popups BEHAVE (their open and close timing, what closes them) stays Lucky Card's, and
// is shared here too ([showLucky16Popup], [Lucky16ClosesWhenBettingCloses]).
//
// Every size is in units, a thousandth of the canvas height ([Lucky16Layout.dp]). All text is at least
// 11 dp, ignores the phone's font-size setting, and is in Oswald or DM Sans. Those fonts have no suit
// symbols, so a suit is always the suit picture.
//
// Belongs to Lucky 16 Card only.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/lucky16_models.dart';
import '../../providers/lucky16_provider.dart';
import 'lucky16_art.dart';
import 'lucky16_layout.dart';
import 'lucky16_panel.dart';

/// The popups' dark red and the darkest text colour, on gold.
const Color kLucky16PopupInk = Color(0xFF2A0609);
const Color kLucky16LossRed = Color(0xFF8B0000);

/// The gold gradient of an active tab, a pill or a big figure: pale gold, bright gold, deep gold.
const List<Color> kLucky16GoldFace = [Color(0xFFFFF0A8), Color(0xFFFFD84A), Color(0xFFC8961E)];
const List<double> kLucky16GoldFaceStops = [0.0, 0.4, 1.0];

/// The open and close transition of every popup, Lucky Card's: 220 ms, a fade and a scale from 0.94.
const Duration kLucky16PopupTransition = Duration(milliseconds: 220);

/// The dark barrier behind every popup, Lucky Card's.
const Color kLucky16PopupBarrier = Color(0xBF000000);

Widget _fadeAndScale(BuildContext context, Animation<double> animation, Widget child) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
  return FadeTransition(
    opacity: curved,
    child: ScaleTransition(scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved), child: child),
  );
}

/// Shows a popup the way Lucky Card shows its own: [barrierDismissible] says whether a tap outside
/// closes it. Completes when it closes, for any reason.
Future<T?> showLucky16Popup<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String barrierLabel = 'Close',
  Color barrierColor = kLucky16PopupBarrier,
}) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: barrierColor,
      transitionDuration: kLucky16PopupTransition,
      pageBuilder: (context, _, __) => builder(context),
      transitionBuilder: (context, animation, _, child) => _fadeAndScale(context, animation, child),
    );

/// Closes the popup that uses it, with the same fade as any other close, the moment the game locks
/// betting, so the wheel, the card and the win popup are never hidden behind it. Opened while betting
/// is already closed, it closes again at once. Copied from Lucky Card's history dialog.
mixin Lucky16ClosesWhenBettingCloses<T extends StatefulWidget> on State<T> {
  Lucky16Provider get bettingProvider;

  Lucky16Provider? _watched;
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
    // Another route (the round's detail popup) may be on top: take this one out from underneath.
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

/// One line of text in a popup: [units] tall (never under 11 dp), ignoring the phone's font setting.
/// [spacing] is the letter spacing as a share of the size.
Text lucky16PopupText(
  String text,
  Lucky16Layout layout, {
  Key? key,
  String family = 'Oswald',
  FontWeight weight = FontWeight.w500,
  required double units,
  Color color = kLucky16Cream,
  double spacing = 0,
  double height = 1.1,
  int? maxLines = 1,
  TextAlign? align,
  List<Shadow>? shadows,
}) {
  final size = layout.fontSize(units);
  return Text(
    text,
    key: key,
    maxLines: maxLines,
    softWrap: maxLines != 1,
    overflow: maxLines == 1 ? TextOverflow.visible : null,
    textAlign: align,
    textScaler: TextScaler.noScaling,
    style: TextStyle(
      fontFamily: family,
      fontWeight: weight,
      fontSize: size,
      height: height,
      letterSpacing: size * spacing,
      color: color,
      shadows: shadows,
    ),
  );
}

/// Text in the gold of a title or a big figure: the vertical gold gradient, with a dark shadow [drop]
/// units under it.
class Lucky16GoldText extends StatelessWidget {
  const Lucky16GoldText(
    this.text, {
    super.key,
    required this.layout,
    required this.units,
    this.spacing = 0.09,
    this.drop = 3,
    this.colors = const [Color(0xFFFFF6C8), Color(0xFFFFD84A), Color(0xFFC8961E)],
    this.stops = const [0.0, 0.45, 1.0],
  });

  final String text;
  final Lucky16Layout layout;
  final double units;
  final double spacing;
  final double drop;
  final List<Color> colors;
  final List<double> stops;

  @override
  Widget build(BuildContext context) {
    Text line(Color color) =>
        lucky16PopupText(text, layout, weight: FontWeight.w700, units: units, spacing: spacing, color: color);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.translate(offset: Offset(0, math.max(layout.dp(drop), 1.0)), child: line(const Color(0xB3000000))),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) =>
              LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: stops)
                  .createShader(bounds),
          child: line(const Color(0xFFFFFFFF)),
        ),
      ],
    );
  }
}

/// The common frame: an outer gold rim 5 units thick, 30 units round, with a warm glow, and inside it
/// the dark red panel, lit from the top. [glow] strengthens the gold glow (a winning round's detail).
class Lucky16PopupFrame extends StatelessWidget {
  const Lucky16PopupFrame({super.key, required this.layout, required this.child, this.glow = 1});

  final Lucky16Layout layout;
  final Widget child;
  final double glow;

  @override
  Widget build(BuildContext context) {
    final rim = math.max(layout.dp(5), 1.5);
    final radius = layout.dp(30);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        // 160 degrees: from the top, a little left, to the bottom, a little right.
        gradient: const LinearGradient(
          begin: Alignment(-0.34, -0.94),
          end: Alignment(0.34, 0.94),
          colors: [Color(0xFFFFF0A8), Color(0xFFD4AF37), Color(0xFF7A5A0E), Color(0xFFFFD84A), Color(0xFF8E6B14)],
          stops: [0.0, 0.22, 0.48, 0.72, 1.0],
        ),
        boxShadow: [
          BoxShadow(color: Color.fromRGBO(255, 200, 70, math.min(0.28 * glow, 0.9)), blurRadius: layout.dp(50)),
          BoxShadow(color: const Color(0xBF000000), offset: Offset(0, layout.dp(24)), blurRadius: layout.dp(70)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(rim),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(math.max(radius - rim, 0)),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.3,
                colors: [Color(0xFF6B1620), Color(0xFF2C070B), Color(0xFF140208)],
                stops: [0.0, 0.42, 1.0],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The round red close button: a [units] circle (never under 34 dp) with a gold ring, answering a tap
/// over at least 48 dp.
class Lucky16CloseButton extends StatelessWidget {
  const Lucky16CloseButton({
    super.key,
    required this.layout,
    required this.onTap,
    this.units = 92,
    this.label = 'Close',
  });

  final Lucky16Layout layout;
  final VoidCallback onTap;
  final double units;
  final String label;

  @override
  Widget build(BuildContext context) {
    final side = math.max(layout.dp(units), 34.0);
    final hit = math.max(side, kLucky16MinTapDp);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: hit,
          height: hit,
          child: Center(
            child: Container(
              width: side,
              height: side,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kLucky16GoldBright, width: math.max(layout.dp(4), 1.5)),
                gradient: const RadialGradient(
                  center: Alignment(-0.25, -0.35),
                  colors: [Color(0xFFFF7A6E), Color(0xFFC4141A), Color(0xFF5C0006)],
                  stops: [0.0, 0.45, 1.0],
                ),
                boxShadow: [BoxShadow(color: const Color(0xFF3A0003), offset: Offset(0, math.max(layout.dp(5), 1.5)))],
              ),
              child: Icon(Icons.close_rounded, size: side * 0.62, color: const Color(0xFFFFFFFF)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The header of a big popup, three columns: the game's small name at the left, the title in the
/// middle, the close button at the right.
class Lucky16PopupHeader extends StatelessWidget {
  const Lucky16PopupHeader({
    super.key,
    required this.layout,
    required this.title,
    required this.close,
  });

  final Lucky16Layout layout;
  final String title;

  /// The close button, built by the popup (it carries the popup's own key).
  final Widget close;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(layout.dp(36), layout.dp(12), layout.dp(20), layout.dp(6)),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: lucky16PopupText(
                'LUCKY 16 CARD',
                layout,
                units: 26,
                spacing: 0.2,
                color: kLucky16Cream.withValues(alpha: 0.72),
              ),
            ),
          ),
          Lucky16GoldText(title, layout: layout, units: 62),
          Expanded(child: Align(alignment: Alignment.centerRight, child: close)),
        ],
      ),
    );
  }
}

/// The soft card the popups' blocks sit on: a faint white wash and a thin gold line.
BoxDecoration lucky16PopupCard(
  Lucky16Layout layout, {
  double radius = 18,
  double borderAlpha = 0.28,
  double top = 0.07,
  double bottom = 0.02,
}) =>
    BoxDecoration(
      borderRadius: BorderRadius.circular(layout.dp(radius)),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: top), Colors.white.withValues(alpha: bottom)],
      ),
      border: Border.all(color: kLucky16Gold.withValues(alpha: borderAlpha)),
    );

/// The small gold (or, for N, outlined) pill with a round's bonus.
class Lucky16BonusPill extends StatelessWidget {
  const Lucky16BonusPill({super.key, required this.layout, required this.bonus, this.units = 24});

  final Lucky16Layout layout;

  /// 1 is "N", 2 to 10 are "2X" to "10X".
  final int bonus;
  final double units;

  @override
  Widget build(BuildContext context) {
    final none = bonus <= 1;
    final faded = kLucky16Cream.withValues(alpha: 0.55);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: layout.dp(14), vertical: layout.dp(3)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(layout.dp(40)),
        border: none ? Border.all(color: faded) : null,
        gradient: none
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: kLucky16GoldFace,
                stops: kLucky16GoldFaceStops,
              ),
      ),
      child: lucky16PopupText(
        lucky16BonusLabel(bonus),
        layout,
        weight: FontWeight.w700,
        units: units,
        color: none ? faded : kLucky16PopupInk,
      ),
    );
  }
}

/// A mini playing card: white, with the rank (red for hearts and diamonds, black for spades and clubs)
/// over the suit picture.
class Lucky16MiniCard extends StatelessWidget {
  const Lucky16MiniCard({
    super.key,
    required this.layout,
    required this.art,
    required this.card,
    this.width = 56,
    this.height = 76,
  });

  final Lucky16Layout layout;
  final Lucky16Art art;
  final Lucky16Card card;

  /// Its size, in units.
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final w = math.max(layout.dp(width), 24.0);
    final h = math.max(layout.dp(height), 32.0);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final icon = h * 0.42;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF6),
        borderRadius: BorderRadius.circular(layout.dp(8)),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.rank.dbValue,
            maxLines: 1,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Oswald',
              fontWeight: FontWeight.w700,
              fontSize: math.max(h * 0.42, kLucky16MinReadableDp),
              height: 1.0,
              color: card.suit.isRed ? const Color(0xFFD4141C) : const Color(0xFF1D1A17),
            ),
          ),
          Image(
            image: art.image(Lucky16ArtKey.suitIcon(card.suit), cacheWidth: Lucky16Layout.cacheWidth(icon, dpr)),
            width: icon,
            height: icon,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),
        ],
      ),
    );
  }
}
