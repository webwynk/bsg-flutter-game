// Where everything on the Lucky 16 Card screen goes, worked out from the size of the
// screen alone. Pure arithmetic: no widget, no image, no state, so it is tested
// directly at every device shape.
//
// Copied from lib/widgets/lucky_card/lucky_card_layout.dart (Lucky Card) and cut down to the
// PHONE arrangement, which is all Lucky 16 Card has so far (phone phase 1, 2026-10-28). The
// header, the body's padding and the bet panel's width are Lucky Card's phone numbers,
// unchanged. Only the board is new: the approved phone mockup
// (reference-design/lucky16/lucky16-phone.html) has five rows -- the four suit bars, then the
// Aces, Jacks, Queens and Kings -- each row of four cards with its rank selector at the right.
//
//   * The canvas takes the screen's shape, but only between 1.6 : 1 and 2.4 : 1. A squarer screen
//     gets a 1.6 : 1 canvas, centred; a wider one a 2.4 : 1 canvas. The background is painted over
//     the whole screen, so what is left over reads as background, not as bars.
//   * Every size is a share of the canvas's height or width held between a smallest and a largest
//     value in dp (see [_design]), the reference design's CSS `clamp(min, share, max)`.
//   * "Units" are a thousandth of the canvas height, turned into dp by [scale] (for the later
//     phases' wheel, reveal card and popups).
//
// The zones are the header bar, the grid (the four suit bars over the 16 cards), the rank column
// (the four selectors) and the bet panel; what goes inside each is decided by its widgets.
//
// TABLET MODE ([Lucky16Layout.tablet], tablet phase 1): Lucky Card's tablet arrangement with Lucky 16's
// board, as the approved mockup (reference-design/lucky16/lucky16-tablet.html) draws it. The canvas is the
// whole screen: the flat header, the board at the left with a separate bar for the five chips under it
// ([chipBar]), and at the right a taller bet panel whose three buttons are stacked. Every getter that
// differs in tablet mode says so; the phone's numbers are not touched. [Lucky16Layout.of] chooses by the
// screen's size ([isTabletScreen]).
//
// DESKTOP MODE ([Lucky16Layout.desktop], desktop phase 1): Lucky Card's desktop arrangement with Lucky
// 16's board, as the approved mockup (reference-design/lucky16/lucky16-desktop.html) draws it, on the whole
// screen: the flat header; at the left a column with the wheel, always on screen, and PLAY and WIN at its
// bottom, as wide as the board leaves room for (at least 34% of the width); at the right the board, flush
// with the column's left edge, under it a row of the ten newest results ([resultsBar]) and under that one
// bar holding the five chips and the three buttons in a row ([actionBar]). [Lucky16Layout.of] only makes it
// when told so (`desktopPlatform`); the real screen always tells it yes, so in the app it is chosen by
// screen size alone (at least 1280 x 720 dp), as Lucky Card's is.
//
// Belongs to Lucky 16 Card only.

import 'dart:math' as math;
import 'dart:ui';

/// No tap target is smaller than this, in dp (Lucky Card spec §12.1 and §12.2).
const double kLucky16MinTapDp = 48;

/// No text is smaller than this, in dp (Lucky Card spec §12.1).
const double kLucky16MinReadableDp = 11;

class Lucky16Layout {
  Lucky16Layout._({
    required this.screen,
    required this.canvasRect,
    required this.scale,
    this.isTablet = false,
    this.isDesktop = false,
  });

  // ── The rules ───────────────────────────────────────────────────────────

  static const double designHeight = 1000;
  static const double minRatio = 1.6;
  static const double maxRatio = 2.4;

  /// Rows in the grid: the suit bars, then Aces, Jacks, Queens and Kings.
  static const int gridRows = 5;

  /// Columns in the grid, one per suit.
  static const int gridColumns = 4;

  /// The layout for a screen of this size: the desktop arrangement when told the app may use it
  /// ([desktopPlatform]) and the screen is big enough ([isDesktopScreen]), else the tablet arrangement for
  /// a tablet-sized screen ([isTabletScreen]), else the phone one. This is the one place the choice is made.
  factory Lucky16Layout.of(Size screen, {bool desktopPlatform = false}) {
    if (desktopPlatform && isDesktopScreen(screen)) return Lucky16Layout.desktop(screen);
    return isTabletScreen(screen) ? Lucky16Layout.tablet(screen) : Lucky16Layout.phone(screen);
  }

  /// True for a screen big enough for the desktop arrangement: at least 1280 x 720 dp, Lucky Card's rule.
  static bool isDesktopScreen(Size screen) => screen.width >= desktopMinWidth && screen.height >= desktopMinHeight;
  static const double desktopMinWidth = 1280;
  static const double desktopMinHeight = 720;

  /// The desktop arrangement: the canvas is the whole screen, as on a tablet.
  factory Lucky16Layout.desktop(Size screen) {
    final w = math.max(screen.width, 1.0);
    final h = math.max(screen.height, 1.0);
    return Lucky16Layout._(
        screen: Size(w, h), canvasRect: Rect.fromLTWH(0, 0, w, h), scale: h / designHeight, isDesktop: true);
  }

  /// True for a screen big enough for the tablet arrangement: at least 600 dp on its shorter side and
  /// at least 800 dp on its longer side, Lucky Card's rule.
  static bool isTabletScreen(Size screen) =>
      math.min(screen.width, screen.height) >= tabletShortSide &&
      math.max(screen.width, screen.height) >= tabletLongSide;

  /// The sides from which a screen is a tablet, in dp.
  static const double tabletShortSide = 600;
  static const double tabletLongSide = 800;

  /// The tablet arrangement: the canvas is the whole screen, whatever its shape.
  factory Lucky16Layout.tablet(Size screen) {
    final w = math.max(screen.width, 1.0);
    final h = math.max(screen.height, 1.0);
    return Lucky16Layout._(
        screen: Size(w, h), canvasRect: Rect.fromLTWH(0, 0, w, h), scale: h / designHeight, isTablet: true);
  }

  /// The phone arrangement, whatever the screen's size (a squarer screen than 1.6 : 1 gets a
  /// centred 1.6 : 1 canvas, a wider one a 2.4 : 1 canvas).
  factory Lucky16Layout.phone(Size screen) {
    final w = math.max(screen.width, 1.0);
    final h = math.max(screen.height, 1.0);
    final ratio = w / h;

    final double canvasW;
    final double canvasH;
    if (ratio < minRatio) {
      canvasW = w;
      canvasH = w / minRatio;
    } else if (ratio > maxRatio) {
      canvasW = h * maxRatio;
      canvasH = h;
    } else {
      canvasW = w;
      canvasH = h;
    }

    return Lucky16Layout._(
      screen: Size(w, h),
      canvasRect: Rect.fromLTWH((w - canvasW) / 2, (h - canvasH) / 2, canvasW, canvasH),
      scale: canvasH / designHeight,
    );
  }

  // ── The result ──────────────────────────────────────────────────────────

  /// True in tablet mode ([Lucky16Layout.tablet]).
  final bool isTablet;

  /// True in desktop mode ([Lucky16Layout.desktop]).
  final bool isDesktop;

  /// The tablet and the desktop both draw their boxes larger, and lift the chip in hand.
  bool get _roomy => isTablet || isDesktop;

  /// The screen this was worked out for.
  final Size screen;

  /// Where the canvas sits on the screen, in dp.
  final Rect canvasRect;

  /// dp per unit.
  final double scale;

  /// The canvas as its own coordinate space: every rect below is in dp from the canvas's
  /// top-left corner.
  Size get canvasSize => canvasRect.size;

  /// Turns units into dp.
  double dp(double units) => units * scale;

  /// A text size from units, never below [minDp] (11 by default).
  double fontSize(double units, {double minDp = kLucky16MinReadableDp}) => math.max(units * scale, minDp);

  /// How many pixels wide to decode a picture shown [dp] wide, so it is never decoded larger
  /// than it is drawn.
  static int cacheWidth(double dp, double devicePixelRatio) => math.max((dp * devicePixelRatio).ceil(), 1);

  /// A size from the design: [share] of the canvas's height, never below [minDp] nor above [maxDp].
  double _design(double share, double minDp, double maxDp) =>
      (canvasSize.height * share).clamp(minDp, maxDp).toDouble();

  // ── The header (Lucky Card's phone header, unchanged) ───────────────────

  /// The zone the header sits in: exactly the header bar, flush with the top and both sides.
  Rect get topBar => designHeaderBar;

  /// The header bar's height: 13% of the height, 48 to 56 dp (the 48 dp floor is the tap rule).
  /// Tablet: 8.5% of the height, 56 to 84 dp.
  double get designHeaderHeight => isDesktop
      ? _design(0.08, 64, 100)
      : isTablet
          ? _design(0.085, 56, 84)
          : _design(0.13, kLucky16MinTapDp, 56);

  /// The header bar: flush with the top and both sides of the canvas.
  Rect get designHeaderBar => Rect.fromLTWH(0, 0, canvasSize.width, designHeaderHeight);

  /// A round button as it is DRAWN (9.5% of the height, 34 to 42 dp); its tap area is never
  /// smaller than 48 dp.
  double get designBallSize => isDesktop
      ? _design(0.062, 50, 80)
      : isTablet
          ? _design(0.068, 46, 68)
          : _design(0.095, 34, 42);
  double get designBallHit => math.max(designBallSize, kLucky16MinTapDp);

  /// The sunken pill holding the coin and the balance, and the coin inside it.
  double get designPillHeight => isDesktop
      ? _design(0.056, 46, 72)
      : isTablet
          ? _design(0.056, 38, 56)
          : _design(0.094, 32, 38);
  double get designCoinSize => isDesktop
      ? _design(0.042, 34, 56)
      : isTablet
          ? _design(0.044, 30, 44)
          : _design(0.072, 24, 30);

  /// The coin picture is decoded at the size it is drawn.
  int coinCacheWidth(double devicePixelRatio) => cacheWidth(designCoinSize, devicePixelRatio);

  /// The countdown's disc, across: 82% of 11.6% of the height (40 to 48 dp), as Lucky Card's.
  double get designCountdownSize =>
      countdownDiscShare *
      (isDesktop ? _design(0.066, 52, 84) : (isTablet ? _design(0.072, 48, 72) : _design(0.116, 40, 48)));
  static const double countdownDiscShare = 0.82;

  /// The gap between the header's pieces: 0.9% of the width, 5 to 8 dp.
  double get designHeaderGap => isDesktop
      ? (canvasSize.width * 0.01).clamp(12.0, 20.0).toDouble()
      : isTablet
          ? (canvasSize.width * 0.01).clamp(8.0, 14.0).toDouble()
          : (canvasSize.width * 0.009).clamp(5.0, 8.0).toDouble();

  /// The balance figure, the countdown's digits, and the line of words in the middle.
  double get designBalanceFont => isDesktop
      ? _design(0.029, 22, 38)
      : isTablet
          ? _design(0.032, 20, 32)
          : _design(0.05, 16, 21);
  double get designCountdownFont => isDesktop
      ? _design(0.026, 18, 34)
      : isTablet
          ? _design(0.028, 18, 28)
          : _design(0.05, 17, 21);
  double get designStatusFont => isDesktop
      ? _design(0.031, 22, 42)
      : isTablet
          ? _design(0.03, 18, 30)
          : (canvasSize.width * 0.02).clamp(13.0, 17.0).toDouble();

  // ── The body ────────────────────────────────────────────────────────────
  //
  // Lucky Card's phone body, unchanged: padded by 1% of the width (6 to 10 dp) on the left, right and
  // bottom, starting 6 dp under the header; the bet panel 38% of the width (244 to 360 dp) at the
  // right, 1.2% of the width (6 to 10 dp) from the board.

  // Tablet: padded 1.4% of the width (10 to 20 dp), 1.4% of the height (8 to 14 dp) under the header, the
  // panel 1.2% of the width (10 to 18 dp) from the board.
  double get designBodyPad => isDesktop
      ? (canvasSize.width * 0.014).clamp(14.0, 32.0).toDouble()
      : isTablet
          ? (canvasSize.width * 0.014).clamp(10.0, 20.0).toDouble()
          : (canvasSize.width * 0.01).clamp(6.0, 10.0).toDouble();
  double get designBodyGapX => isDesktop
      ? (canvasSize.width * 0.013).clamp(16.0, 32.0).toDouble()
      : isTablet
          ? (canvasSize.width * 0.012).clamp(10.0, 18.0).toDouble()
          : (canvasSize.width * 0.012).clamp(6.0, 10.0).toDouble();
  double get bodyGapY => isDesktop
      ? (canvasSize.height * 0.014).clamp(12.0, 22.0).toDouble()
      : isTablet
          ? (canvasSize.height * 0.014).clamp(8.0, 14.0).toDouble()
          : 6;

  /// The body: everything under the header, inside its padding.
  Rect get designBody => Rect.fromLTRB(
        designBodyPad,
        designHeaderBar.bottom + bodyGapY,
        canvasSize.width - designBodyPad,
        canvasSize.height - designBodyPad,
      );

  /// The bet panel's width: 38% of the width, 244 to 360 dp (Lucky Card's phone panel).
  /// Tablet: 29% of the width, 300 to 400 dp.
  double get designAsideWidth => isDesktop
      ? math.max(
          (canvasSize.width * 0.34).clamp(360.0, 780.0).toDouble(),
          designBody.width - designBodyGapX - _boardWidthForHeight(_boardHeightLeft),
        )
      : isTablet
          ? (canvasSize.width * 0.29).clamp(300.0, 400.0).toDouble()
          : (canvasSize.width * 0.38).clamp(244.0, 360.0).toDouble();

  /// The bet panel: the full height of the body, at the right.
  Rect get side => isDesktop
      ? Rect.fromLTRB(designBody.left, designBody.top, designBody.left + designAsideWidth, designBody.bottom)
      : Rect.fromLTRB(designBody.right - designAsideWidth, designBody.top, designBody.right, designBody.bottom);

  // ── The desktop's right column: the board, the results row and the bottom bar ──

  /// Desktop: the gap between the board, the results row and the bottom bar, 1.3% of the height (10 to 20
  /// dp).
  double get columnGap => _design(0.013, 10, 20);

  double get _actionBarHeight => _design(0.115, 92, 150);
  double get _resultsBarHeight => _design(0.058, 50, 76);

  /// Desktop: the height the body leaves the board, above the results row and the bottom bar.
  double get _boardHeightLeft =>
      math.max(designBody.height - _actionBarHeight - _resultsBarHeight - 2 * columnGap, 0.0);

  /// Desktop: what is right of the wheel's column, the full height of the body. [Rect.zero] elsewhere.
  Rect get rightColumn => isDesktop
      ? Rect.fromLTRB(side.right + designBodyGapX, designBody.top, designBody.right, designBody.bottom)
      : Rect.zero;

  /// Desktop: the bar holding the five chips and the three buttons, 11.5% of the height (92 to 150 dp)
  /// tall, at the right column's bottom. [Rect.zero] elsewhere.
  Rect get actionBar => isDesktop
      ? Rect.fromLTRB(rightColumn.left, rightColumn.bottom - _actionBarHeight, rightColumn.right, rightColumn.bottom)
      : Rect.zero;

  /// Desktop: the row of the ten newest results, 5.8% of the height (50 to 76 dp) tall, just above the
  /// bottom bar. [Rect.zero] elsewhere.
  Rect get resultsBar => isDesktop
      ? Rect.fromLTRB(
          rightColumn.left, actionBar.top - columnGap - _resultsBarHeight, rightColumn.right, actionBar.top - columnGap)
      : Rect.zero;

  /// What is left of the body for the board, before the board's own shape is fitted.
  Rect get designSection => isDesktop
      ? Rect.fromLTRB(rightColumn.left, rightColumn.top, rightColumn.right, resultsBar.top - columnGap)
      : Rect.fromLTRB(
          designBody.left,
          designBody.top,
          side.left - designBodyGapX,
          isTablet ? chipBar.top - bodyGapY : designBody.bottom,
        );

  // ── The board ───────────────────────────────────────────────────────────
  //
  // Every picture fills its cell, and every cell has its picture's own shape, so nothing is squeezed:
  //   * a card is 700 x 476;
  //   * a suit bar (1049 x 270) is as wide as a card, so 700 x 180.2 in the same parts;
  //   * a rank selector (640 x 687) is as tall as a card, so 443.4 x 476.
  // The gap between two cells is 1% of the board's width (Lucky Card's phone gap).

  /// The columns' and rows' shares of the board, in picture pixels (see above).
  static const double _cardW = 700;
  static const double _cardH = 476;
  static const double _barH = _cardW * 270 / 1049;
  static const double _selectorW = _cardH * 640 / 687;
  static const List<double> _columnParts = [_cardW, _cardW, _cardW, _cardW, _selectorW];
  static const List<double> _rowParts = [_barH, _cardH, _cardH, _cardH, _cardH];
  static final double _partsW = _columnParts.reduce((a, b) => a + b);
  static final double _partsH = _rowParts.reduce((a, b) => a + b);

  /// The gap between two cells, as a share of the board's width (tablet 0.9%).
  double get _gapShare => _roomy ? 0.009 : 0.01;

  /// The board: the largest grid of the pictures' own shapes (plus its gaps) that fits the section,
  /// centred in it. With the gap a share g of the width W, W = parts·u + 4gW, so W = parts·u / (1 - 4g),
  /// and the height is rows·u + 4gW.
  Rect get designBoard {
    final s = designSection;
    final widthPerPart = 1 / (1 - 4 * _gapShare);
    final heightPerPart = _partsH + 4 * _gapShare * _partsW * widthPerPart;
    final u = math.max(math.min(s.width / (_partsW * widthPerPart), s.height / heightPerPart), 0.0);
    final w = _partsW * u * widthPerPart;
    final h = heightPerPart * u;
    // Desktop: flush with the left edge of the right column, centred up and down.
    if (isDesktop) return Rect.fromLTWH(s.left, s.center.dy - h / 2, w, h);
    return Rect.fromCenter(center: s.center, width: w, height: h);
  }

  /// How wide the board is when [height] tall (its shape does not depend on the screen).
  double _boardWidthForHeight(double height) {
    final widthPerPart = 1 / (1 - 4 * _gapShare);
    final heightPerPart = _partsH + 4 * _gapShare * _partsW * widthPerPart;
    return height * _partsW * widthPerPart / heightPerPart;
  }

  /// The gap between two cells of the board.
  double get designBoardGap => designBoard.width * _gapShare;

  /// One cell of the board: [column] 0 to 4 (the four suits, then the rank selectors), [row] 0 to 4
  /// (the suit bars, then the ace, jack, queen and king rows).
  Rect _cell(int column, int row) {
    final board = designBoard;
    final gap = designBoardGap;
    final unitW = (board.width - 4 * gap) / _partsW;
    final unitH = (board.height - 4 * gap) / _partsH;
    var left = board.left + column * gap;
    for (var c = 0; c < column; c++) {
      left += _columnParts[c] * unitW;
    }
    var top = board.top + row * gap;
    for (var r = 0; r < row; r++) {
      top += _rowParts[r] * unitH;
    }
    return Rect.fromLTWH(left, top, _columnParts[column] * unitW, _rowParts[row] * unitH);
  }

  /// The grid: the four suit bars over the 16 cards.
  Rect get grid => Rect.fromLTRB(_cell(0, 0).left, _cell(0, 0).top, _cell(3, 4).right, _cell(3, 4).bottom);

  /// The column of the four rank selectors, level with the four rows of cards. It starts at the top
  /// of the suit bars' row (empty there), so the zone lines up with the grid.
  Rect get rankColumn => Rect.fromLTRB(_cell(4, 0).left, _cell(4, 0).top, _cell(4, 4).right, _cell(4, 4).bottom);

  /// One grid cell: [column] 0 to 3 (hearts, spades, diamonds, clubs), [row] 0 to 4 (the suit bar,
  /// then ace, jack, queen, king).
  Rect gridCell(int column, int row) {
    assert(column >= 0 && column < gridColumns && row >= 0 && row < gridRows);
    return _cell(column, row);
  }

  /// A suit's bar: its whole cell, which the bar picture fills.
  Rect suitHeader(int column) => gridCell(column, 0);

  /// A card: [column] is its suit, [rankRow] 0 to 3 (ace, jack, queen, king).
  Rect cardCell(int column, int rankRow) => gridCell(column, rankRow + 1);

  /// A rank selector, level with its row of cards.
  Rect rankSelector(int rankRow) {
    assert(rankRow >= 0 && rankRow < 4);
    return _cell(4, rankRow + 1);
  }

  /// The size of a card's cell, and so of its picture (700 : 476).
  Size get cardSize => _cell(0, 1).size;

  // ── The text on the board ───────────────────────────────────────────────
  //
  // Sized as a share of the board's own width, as Lucky Card's are, at the shares that give the
  // approved mockup's sizes (a card's stake 20% of the card's height, a suit bar's total half the
  // bar's height): the card plate 2.8%, a suit bar's name 2.1% (its total 1.3 times that), a rank
  // selector's name 2.1% (its total 1.1 times that). Never under 11 dp (the text widgets hold that).

  double get designCardFont => designBoard.width * 0.028;
  double get designBarFont => designBoard.width * 0.021;
  double get designBadgeFont => designBoard.width * 0.021;

  /// How wide to decode each board picture: exactly the width its cell draws it.
  int cardCacheWidth(double devicePixelRatio) => cacheWidth(_cell(0, 1).width, devicePixelRatio);
  int barCacheWidth(double devicePixelRatio) => cacheWidth(_cell(0, 0).width, devicePixelRatio);
  int selectorCacheWidth(double devicePixelRatio) => cacheWidth(_cell(4, 1).width, devicePixelRatio);

  // ── The bet panel (Lucky Card's phone panel, unchanged) ─────────────────
  //
  // A purple box with a gold border. Inside, from the top: PLAY and WIN side by side, the results
  // (the twelve latest rounds as history cards, four across and three down), the five chips in a row,
  // then, pushed to the bottom, the three buttons. Every number below is Lucky Card's phone value
  // (lucky_card_layout.dart), so the two panels are drawn alike.

  /// The panel's gold border and corner.
  static const double designPanelBorder = 2;
  static const double designPanelRadius = 18;

  /// The corner of the panel and the chip bar: 18 dp on a phone, 22 dp on a tablet.
  double get panelRadius => _roomy ? 22 : designPanelRadius;

  /// The padding inside the border, and the gap between the panel's rows.
  /// Tablet: 1.6% of the height (12 to 18 dp) and (10 to 16 dp); the panel holds only PLAY / WIN, the
  /// results and the three stacked buttons, the chips being in [chipBar].
  double get designPanelPad => isTablet ? _design(0.016, 12, 18) : _design(0.024, 7, 10);
  double get designPanelGap => isTablet ? _design(0.016, 10, 16) : _design(0.022, 6, 10);

  /// What is left inside the border and the padding: where the rows go.
  Rect get panelInner => side.deflate(designPanelBorder + designPanelPad);

  /// The gap between PLAY and WIN, and between the three buttons.
  double get cellGap => isDesktop ? 14 : (isTablet ? 10 : 7);

  /// PLAY / WIN: the label (held at the 11 dp floor) and the figure under it (6% of the height,
  /// 19 to 26 dp), whose lines are 1.2 and 1.1 times their sizes; the cell pads 5 dp above and below and
  /// 10 dp at the sides, with a 12 dp corner.
  /// Tablet: the label 1.5% of the height (held at 11 dp at least), the figure 4% (24 to 38 dp), the
  /// cell's padding 1.2% of the height (8 to 12 dp) above and below and 14 dp at the sides, a 14 dp corner.
  double get designTotalLabelFont => isDesktop
      ? _design(0.013, kLucky16MinReadableDp, 16)
      : isTablet
          ? math.max(_design(0.015, 10, 13), kLucky16MinReadableDp)
          : kLucky16MinReadableDp;
  double get designTotalValueFont => isDesktop
      ? _design(0.038, 28, 52)
      : isTablet
          ? _design(0.04, 24, 38)
          : _design(0.06, 19, 26);
  static const double designTotalLabelLine = 1.2;
  static const double designTotalValueLine = 1.1;
  double get totalPadY => isDesktop
      ? _design(0.011, 8, 16)
      : isTablet
          ? _design(0.012, 8, 12)
          : 5;
  double get totalPadX => isDesktop
      ? 18
      : isTablet
          ? 14
          : 10;
  double get totalCellRadius => isDesktop
      ? 16
      : isTablet
          ? 14
          : 12;
  double get designTotalHeight =>
      2 * totalPadY + designTotalLabelFont * designTotalLabelLine + designTotalValueFont * designTotalValueLine;

  double get _totalWidth => ((isDesktop ? wheelDiameter : panelInner.width) - cellGap) / 2;

  /// PLAY (what is on the board) and WIN (what the last round paid), side by side at the top.
  Rect get totalBetCell => isDesktop
      ? Rect.fromLTWH(wheelBox.left, side.bottom - designTotalHeight, _totalWidth, designTotalHeight)
      : Rect.fromLTWH(panelInner.left, panelInner.top, _totalWidth, designTotalHeight);
  Rect get winCell => isDesktop
      ? Rect.fromLTWH(
          wheelBox.left + _totalWidth + cellGap, side.bottom - designTotalHeight, _totalWidth, designTotalHeight)
      : Rect.fromLTWH(panelInner.left + _totalWidth + cellGap, panelInner.top, _totalWidth, designTotalHeight);

  /// The results box: the twelve latest rounds as cards, four across and three down, the newest first
  /// (top left). The box is padded 5 dp and its cards are 3 dp apart.
  /// Tablet: 1.4% of the height (10 to 14 dp) and 1% (6 to 10 dp).
  double get resultsPad => isDesktop
      ? _design(0.006, 5, 9)
      : isTablet
          ? _design(0.014, 10, 14)
          : 5;
  double get tileGap => isDesktop
      ? _design(0.006, 4, 8)
      : isTablet
          ? _design(0.01, 6, 10)
          : 3;

  /// Desktop: the ten newest in ONE ROW in [resultsBar], with 0.6% of the height (5 to 9 dp) of padding
  /// round them and (4 to 8 dp) between two.
  int get resultColumns => isDesktop ? 10 : 4;
  int get resultRows => isDesktop ? 1 : 3;
  int get resultCount => resultColumns * resultRows;

  /// A history-card frame picture (Lucky Card's, 604 x 686) is taller than wide by this much; a card is
  /// never drawn taller than its width times this.
  static const double historyCardAspect = 686 / 604;

  /// A history card's width: a quarter of what the box leaves after its padding and three gaps.
  double get designTileWidth => isDesktop
      ? (resultsBar.width - 2 * resultsPad - (resultColumns - 1) * tileGap) / resultColumns
      : (panelInner.width - 2 * resultsPad - (resultColumns - 1) * tileGap) / resultColumns;

  /// A history card's height: what the panel has left for three rows between PLAY / WIN above and the
  /// chips and buttons below, but no taller than the picture's own shape.
  double get designTileHeight {
    // Desktop: the row's own height, less its padding (never taller than the picture's shape).
    if (isDesktop) {
      return math.max(math.min(resultsBar.height - 2 * resultsPad, designTileWidth * historyCardAspect), 1.0);
    }
    final top = totalBetCell.bottom + designPanelGap;
    // A tablet's panel has no chips, and room to spare: its cards take the picture's own shape.
    final bottom =
        actionButton(0).top - designPanelGap - (isTablet ? 0 : designChipRowPadTop + kLucky16MinTapDp + designPanelGap);
    final perRow = (bottom - top - 2 * resultsPad - (resultRows - 1) * tileGap) / resultRows;
    return math.max(math.min(perRow, designTileWidth * historyCardAspect), 1.0);
  }

  /// The gold border of a history card's frame as drawn (at least 1.5 dp).
  double get tileBorder => math.max(1.5, designTileHeight * 0.026);

  /// The rank letter at the top left: 36% of the card's height, at least 11 dp.
  double get tileLetterFont => math.max(kLucky16MinReadableDp, designTileHeight * 0.36);

  /// The suit picture at the bottom middle: no wider than 46% of the card or taller than 52% (at least
  /// 12 dp).
  double get tileIconSize => math.max(12.0, math.min(designTileWidth * 0.46, designTileHeight * 0.52));

  /// The red bonus bubble at the top right: 48% of the card's height (18 to 30 dp), its text 55% of that
  /// and never under 11 dp.
  double get tileBubbleHeight => (designTileHeight * 0.48).clamp(18.0, 30.0).toDouble();
  double get tileBubbleFont => math.max(kLucky16MinReadableDp, tileBubbleHeight * 0.55);

  /// How wide the frame picture is decoded, so its border (18 of its 604 px) is exactly [tileBorder].
  int historyFrameCacheWidth(double devicePixelRatio) =>
      math.max((604 / 18 * tileBorder * devicePixelRatio).round(), 8);

  /// The results box, under PLAY / WIN.
  Rect get resultsPanel => isDesktop
      ? resultsBar
      : Rect.fromLTWH(
          panelInner.left,
          totalBetCell.bottom + designPanelGap,
          panelInner.width,
          2 * resultsPad + resultRows * designTileHeight + (resultRows - 1) * tileGap,
        );

  /// History card [index], 0 to 11: row by row from the top left, 0 the newest round.
  Rect resultTile(int index) {
    assert(index >= 0 && index < resultCount);
    final column = index % resultColumns;
    final row = index ~/ resultColumns;
    return Rect.fromLTWH(
      resultsPanel.left + resultsPad + column * (designTileWidth + tileGap),
      resultsPanel.top + resultsPad + row * (designTileHeight + tileGap),
      designTileWidth,
      designTileHeight,
    );
  }

  /// The chips: each drawn [designChipSize] across (12% of the height, no more than 5.6% of the width,
  /// 34 to 52 dp), spread along the row under the results. Each one's tap area is its fifth of the row
  /// (3 dp in from each end) by 48 dp tall: on the smallest phone about 44 dp across, Lucky Card's
  /// written exception to the 48 dp rule.
  static const int chipCount = 5;
  static const double designChipRowPadTop = 4;
  static const double designChipRowPadSide = 3;

  ///
  /// TABLET: the chips are in [chipBar], under the board, each 8.2% of the height across (50 to 80 dp)
  /// with 3% of the width (18 to 44 dp) between two, centred; a narrow bar draws them smaller. Each
  /// chip's tap area is its own slot by the chip and 16 dp, so the five slots touch and never overlap.
  ///
  /// DESKTOP: the chips are the left part of [actionBar], each 7.6% of the height across (58 to 100 dp) with
  /// 1% of the width (12 to 22 dp) between two; a narrow bar shrinks them so they take no more than 55% of
  /// its inside.
  double get designChipSize => isDesktop
      ? math.min(_design(0.076, 58, 100), _chipSlot - 4)
      : isTablet
          ? math.min(_design(0.082, 50, 80), _chipSlot - 4)
          : math.min(_design(0.12, 34, 52), canvasSize.width * 0.056).clamp(34.0, 52.0).toDouble();

  /// Tablet only: the bar under the board that holds the five chips, as wide as the board's column and
  /// 13% of the height (80 to 124 dp) tall, at the bottom of the body. [Rect.zero] on a phone.
  Rect get chipBar => isTablet
      ? Rect.fromLTRB(designBody.left, designBody.bottom - chipBarHeight, side.left - designBodyGapX, designBody.bottom)
      : Rect.zero;
  double get chipBarHeight => _design(0.13, 80, 124);

  /// Tablet: one chip's slot, the chip and a gap, never wider than a fifth of the bar (less 8 dp at each
  /// end).
  double get _chipSlot => isDesktop
      ? math.min(
          _design(0.076, 58, 100) + (canvasSize.width * 0.01).clamp(12.0, 22.0).toDouble(),
          math.max((actionBar.width - 2 * actionBarPad) * 0.55 / chipCount, 1.0),
        )
      : math.min(
          _design(0.082, 50, 80) + (canvasSize.width * 0.03).clamp(18.0, 44.0).toDouble(),
          math.max((chipBar.width - 16) / chipCount, 1.0),
        );

  /// Desktop: the bar's padding at its two ends (1.4% of the width, 16 to 28 dp) and the gap between the
  /// chips and the buttons (1.5% of the width, 16 to 32 dp).
  double get actionBarPad => (canvasSize.width * 0.014).clamp(16.0, 28.0).toDouble();
  double get actionBarGap => (canvasSize.width * 0.015).clamp(16.0, 32.0).toDouble();

  /// How big a chip is drawn, as a share of [designChipSize]: the chip in hand full size, the others
  /// 79% of it.
  /// Tablet: the others full size, the one in hand lifted 6% bigger.
  double get chipHandScale => _roomy ? 1.06 : 1.0;
  double get chipRestScale => _roomy ? 1.0 : 0.74 / 0.94;

  /// The row the five chips share.
  Rect get chipRail => isDesktop
      ? _desktopChipRail
      : isTablet
          ? Rect.fromCenter(
              center: chipBar.center,
              width: chipCount * _chipSlot,
              height: math.min(designChipSize + 16, chipBar.height),
            )
          : Rect.fromLTWH(
              panelInner.left,
              resultsPanel.bottom + designPanelGap,
              panelInner.width,
              designChipRowPadTop + kLucky16MinTapDp,
            );

  /// Desktop: the first chip's own left edge is [actionBarPad] in from the bar's left edge.
  Rect get _desktopChipRail {
    final lead = (_chipSlot - designChipSize) / 2;
    final height = math.min(designChipSize + 16, actionBar.height);
    return Rect.fromLTWH(
        actionBar.left + actionBarPad - lead, actionBar.center.dy - height / 2, chipCount * _chipSlot, height);
  }

  /// Chip [index] (0 is the 5 chip, 4 the 500 chip): its tap area.
  Rect chip(int index) {
    assert(index >= 0 && index < chipCount);
    if (_roomy) return Rect.fromLTWH(chipRail.left + index * _chipSlot, chipRail.top, _chipSlot, chipRail.height);
    final slot = (chipRail.width - 2 * designChipRowPadSide) / chipCount;
    return Rect.fromLTWH(chipRail.left + designChipRowPadSide + index * slot, chipRail.top + designChipRowPadTop, slot,
        kLucky16MinTapDp);
  }

  /// The three buttons, side by side along the bottom: 11.6% of the height (40 to 48 dp) tall, held at
  /// the 48 dp tap floor; the text 4.2% of the height (12 to 17 dp), no more than 1.95% of the width.
  static const int actionButtonCount = 3;

  ///
  /// TABLET: stacked, each the panel's full inner width, 7.4% of the height tall (46 to 70 dp, held at the
  /// 48 dp floor), 1.3% of the height (8 to 14 dp) apart, the last at the bottom of the panel; the text 3%
  /// of the height (18 to 28 dp).
  double get designButtonHeight => isDesktop
      ? math.max(_design(0.067, 54, 88), kLucky16MinTapDp)
      : math.max(isTablet ? _design(0.074, 46, 70) : _design(0.116, 40, 48), kLucky16MinTapDp);
  double get buttonGapY => _design(0.013, 8, 14);

  /// Desktop: the gap between two buttons in the row, 0.8% of the width (8 to 16 dp).
  double get buttonGapX => (canvasSize.width * 0.008).clamp(8.0, 16.0).toDouble();
  double get designButtonFont => isDesktop
      ? _design(0.022, 17, 30)
      : isTablet
          ? _design(0.03, 18, 28)
          : math.min(_design(0.042, 12, 17), canvasSize.width * 0.0195).clamp(12.0, 17.0).toDouble();
  double get buttonRadius => _roomy ? 16 : 14;

  /// Button [index], left to right: 0 Double (or Rebet), 1 Clear, 2 Remove.
  Rect actionButton(int index) {
    assert(index >= 0 && index < actionButtonCount);
    if (isDesktop) {
      // In a row in [actionBar], right of the chips, equal; the height is 6.7% of the screen's (54 to 88
      // dp), the text 2.2% (17 to 30 dp).
      final left = chipRail.right - (_chipSlot - designChipSize) / 2 + actionBarGap;
      final right = actionBar.right - actionBarPad;
      final width = (right - left - (actionButtonCount - 1) * buttonGapX) / actionButtonCount;
      return Rect.fromLTWH(
        left + index * (width + buttonGapX),
        actionBar.center.dy - designButtonHeight / 2,
        math.max(width, 1.0),
        designButtonHeight,
      );
    }
    if (isTablet) {
      final top = panelInner.bottom - actionButtonCount * designButtonHeight - (actionButtonCount - 1) * buttonGapY;
      return Rect.fromLTWH(
          panelInner.left, top + index * (designButtonHeight + buttonGapY), panelInner.width, designButtonHeight);
    }
    final width = (panelInner.width - (actionButtonCount - 1) * cellGap) / actionButtonCount;
    return Rect.fromLTWH(
        panelInner.left + index * (width + cellGap), panelInner.bottom - designButtonHeight, width, designButtonHeight);
  }

  // ── The wheel and the reveal (phone phase 4) ────────────────────────────
  //
  // While betting is closed the board's place (the grid and the rank column together) holds the wheel
  // at its left and, beside it, the big card of the reveal, as the approved mockup's ?state=spin draws
  // them. (Lucky Card puts its nearly square card in its rank column; Lucky 16's cards are wide, 700 x
  // 476, so the card gets the room right of the wheel instead.)

  /// The wheel's widget is this many diameters high: its pointer sits 6% above the wheel.
  static const double wheelHeightFactor = 1.06;

  /// The board's whole place, which the wheel and the card share while betting is closed.
  Rect get revealArea => designBoard;

  /// The wheel's diameter: as tall as the board allows (pointer included), but never more than 62% of
  /// the board's width, so the card beside it keeps its room.
  double get wheelDiameter => isDesktop
      ? math.max(math.min(side.width, (side.height - designTotalHeight - wheelGap) / wheelHeightFactor), 1.0)
      : math.max(math.min(revealArea.height / wheelHeightFactor, revealArea.width * 0.62), 1.0);

  /// Desktop: the gap between the wheel and PLAY / WIN, 2.8% of the height (20 to 36 dp).
  double get wheelGap => _design(0.028, 20, 36);

  /// The wheel widget's box, pointer included (desktop: centred across [side] and up and down in what is
  /// above PLAY / WIN): at the board's left (2% in), centred up and down.
  Rect get wheelBox => isDesktop
      ? Rect.fromLTWH(
          side.center.dx - wheelDiameter / 2,
          side.top +
              math.max((side.height - designTotalHeight - wheelGap - wheelDiameter * wheelHeightFactor) / 2, 0.0),
          wheelDiameter,
          wheelDiameter * wheelHeightFactor,
        )
      : Rect.fromLTWH(
          revealArea.left + revealArea.width * 0.02,
          revealArea.center.dy - wheelDiameter * wheelHeightFactor / 2,
          wheelDiameter,
          wheelDiameter * wheelHeightFactor,
        );

  /// The wheel's own centre.
  Offset get wheelCenter => Offset(wheelBox.center.dx, wheelBox.top + wheelDiameter * 0.06 + wheelDiameter / 2);

  /// The big card of the reveal, in the card picture's own shape (700 x 476): 1.6 times a board card's
  /// width, but no wider than 90% of what is right of the wheel, centred in that room.
  Rect get revealCard {
    final left = wheelBox.right;
    final room = revealArea.right - left;
    final width = math.max(math.min(cardSize.width * 1.6, room * 0.9), 1.0);
    final height = width * _cardH / _cardW;
    return Rect.fromCenter(center: Offset(left + room / 2, revealArea.center.dy), width: width, height: height);
  }

  /// The reveal card's picture is decoded at the width it is drawn.
  int revealCacheWidth(double devicePixelRatio) => cacheWidth(revealCard.width, devicePixelRatio);

  // ── The win popup (phone phase 5, Lucky Card's numbers) ─────────────────

  /// Width over height of Triple Chance's win-popup frame (823 x 455) and of its title picture
  /// (754 x 129), both used read-only.
  static const double winPopupAspect = 823 / 455;
  static const double winTextAspect = 754 / 129;

  /// The win popup, centred in the canvas: 64% of the canvas height, as wide as the frame picture
  /// needs, and never wider than 92% of the canvas.
  Rect get winPopup {
    var h = dp(640);
    var w = h * winPopupAspect;
    final maxW = canvasSize.width * 0.92;
    if (w > maxW) {
      w = maxW;
      h = w / winPopupAspect;
    }
    return Rect.fromCenter(center: canvasSize.center(Offset.zero), width: w, height: h);
  }

  /// The popup's frame is decoded at the width it is drawn.
  int winPopupCacheWidth(double devicePixelRatio) => cacheWidth(winPopup.width, devicePixelRatio);

  /// A chip is decoded at the size it is drawn; every suit icon at the size a history card draws it.
  int chipCacheWidth(double devicePixelRatio) => cacheWidth(designChipSize * 1.06, devicePixelRatio);
  int resultIconCacheWidth(double devicePixelRatio) => cacheWidth(tileIconSize, devicePixelRatio);

  /// [rect] (in canvas coordinates) as seen from inside [zone]: what a widget placed in a zone's
  /// builder needs.
  Rect within(Rect zone, Rect rect) => rect.shift(-zone.topLeft);

  /// Every zone, for tests and for drawing a map of the layout.
  Map<String, Rect> get zones => {
        'topBar': topBar,
        'grid': grid,
        'rankColumn': rankColumn,
        'side': side,
        if (isTablet) 'chipBar': chipBar,
        if (isDesktop) ...{'resultsBar': resultsBar, 'actionBar': actionBar},
      };
}
