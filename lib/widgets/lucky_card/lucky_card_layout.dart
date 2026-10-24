// Where everything on the Lucky Card screen goes, worked out from the size of the
// screen alone. Pure arithmetic: no widget, no image, no state, so it is tested
// directly at every device shape.
//
// The screen follows the reference design (`reference-design/royal-cards-standalone/`, the phone
// files), decided 2026-10-23 and built slice by slice: the header, the card board, then the bet
// panel at the right. Its rules, kept from the earlier design (spec §17M, Option B, a flexible
// canvas, and §12.2, very responsive on every phone and tablet):
//
//   * The canvas takes the screen's shape, but only between 1.6 : 1 and 2.4 : 1. A squarer screen
//     (a 4:3 tablet) gets a 1.6 : 1 canvas, centred; a wider one a 2.4 : 1 canvas. The background
//     is painted over the whole screen, so what is left over reads as background, not as bars.
//   * Every size is the design's own CSS `clamp(min, share, max)`: a share of the canvas's height
//     or width held between a smallest and a largest value in dp (see [_design]), so nothing is
//     a fixed number of pixels. A few smallest values are raised for the readable-text and
//     tap-target rules (spec §12.1), each written next to the number it changes.
//   * The wheel, the reveal card and the win popup (not in the design) are still laid out in
//     "units", a thousandth of the canvas height, turned into dp by [scale].
//
// The zones are the header bar, the grid (the four suit bars over the 12 cards), the rank column
// and the bet panel; what goes inside each is decided by its widgets from the rects below.
//
// TABLET MODE (spec §17BN, decided 2026-10-23, switched on in step T4): [LuckyCardLayout.tablet]
// arranges the same pieces the way the reference design's six tablet files do, the canvas being the
// whole screen: the flat header bar, the board at the left with a separate bar for the five chips
// under it ([chipBar]), and at the right a taller bet panel whose three buttons are stacked. Every
// getter below that differs in tablet mode says so; the phone's numbers are not touched.
// [LuckyCardLayout.of] chooses by the screen's size (see [isTabletScreen]); [LuckyCardLayout.phone]
// always makes the phone arrangement.
//
// DESKTOP MODE (spec §17BP, decided 2026-10-24, built in steps D1 to D5): [LuckyCardLayout.desktop]
// follows the reference design's seven desktop files, on the whole screen, with the user's changes of
// 2026-10-24: the flat header; at the left a column with the wheel, always on screen, PLAY and WIN at its
// bottom (on the same line as the bottom bar's bottom edge) and the column as wide as the board leaves
// room for (at least 34% of the width), so the wheel is as big as the height allows; at the right the
// board, flush with the column's left edge, under it a row of the ten newest history cards
// ([resultsBar]) and under that one bar holding the five chips and the three buttons in a row
// ([actionBar]). [LuckyCardLayout.of] only makes it when told so (`desktopPlatform`); the real Lucky
// Card screen always tells it yes, so in the app it is chosen by screen size alone (>= 1280 x 720 dp),
// like Triple Chance. Without the flag (a test) the screen asks the platform ([luckyCardRunsOnDesktop]).
//
// Belongs to Lucky Card only.

import 'dart:math' as math;
import 'dart:ui';

/// No tap target is smaller than this, in dp (spec §12.1 and §12.2).
const double kLuckyCardMinTapDp = 48;

/// No text is smaller than this, in dp (spec §12.1, the Q38 rule).
const double kLuckyCardMinReadableDp = 11;

class LuckyCardLayout {
  LuckyCardLayout._({
    required this.screen,
    required this.canvasRect,
    required this.scale,
    this.isTablet = false,
    this.isDesktop = false,
  });

  // ── The rules, in units ─────────────────────────────────────────────────

  static const double designHeight = 1000;
  static const double minRatio = 1.6;
  static const double maxRatio = 2.4;

  /// Rows in the grid: the suit header, then Jacks, Queens and Kings.
  static const int gridRows = 4;

  /// Columns in the grid, one per suit.
  static const int gridColumns = 4;

  /// Works out the layout for a screen of this size: the desktop arrangement when the app runs on a
  /// desktop platform ([desktopPlatform]) and the screen is big enough ([isDesktopScreen]), else the
  /// tablet arrangement for a tablet-sized screen ([isTabletScreen]), else the phone one. This is the
  /// one place the choice is made.
  factory LuckyCardLayout.of(Size screen, {bool desktopPlatform = false}) {
    if (desktopPlatform && isDesktopScreen(screen)) return LuckyCardLayout.desktop(screen);
    return isTabletScreen(screen) ? LuckyCardLayout.tablet(screen) : LuckyCardLayout.phone(screen);
  }

  /// True for a screen big enough for the desktop arrangement: at least 1280 x 720 dp, the smallest
  /// of the reference's seven desktop files (spec §17BP). Whether the app runs on a desktop platform
  /// is a separate question, answered by the caller.
  static bool isDesktopScreen(Size screen) => screen.width >= desktopMinWidth && screen.height >= desktopMinHeight;

  /// True for a screen big enough for the tablet arrangement: at least 600 dp on its shorter side
  /// (Android's own rule; the biggest phone design is 430 dp, the smallest tablet one 600) and at
  /// least 800 dp on its longer side (so an odd near-square screen, which the tablet arrangement's
  /// chip bar cannot fit, stays on the phone arrangement).
  static bool isTabletScreen(Size screen) =>
      math.min(screen.width, screen.height) >= tabletShortSide && math.max(screen.width, screen.height) >= tabletLongSide;

  /// The phone arrangement, whatever the screen's size (a squarer screen than 1.6 : 1 gets a
  /// centred 1.6 : 1 canvas, a wider one a 2.4 : 1 canvas).
  factory LuckyCardLayout.phone(Size screen) {
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
    final scale = canvasH / designHeight;

    return LuckyCardLayout._(
      screen: Size(w, h),
      canvasRect: Rect.fromLTWH((w - canvasW) / 2, (h - canvasH) / 2, canvasW, canvasH),
      scale: scale,
    );
  }

  /// The tablet arrangement (spec §17BN): the canvas is the whole screen, whatever its shape, so the
  /// reference design's own proportions are followed instead of being held to 1.6 : 1 to 2.4 : 1.
  factory LuckyCardLayout.tablet(Size screen) {
    final w = math.max(screen.width, 1.0);
    final h = math.max(screen.height, 1.0);
    return LuckyCardLayout._(
      screen: Size(w, h),
      canvasRect: Rect.fromLTWH(0, 0, w, h),
      scale: h / designHeight,
      isTablet: true,
    );
  }

  /// The desktop arrangement (spec §17BP): the canvas is the whole screen, as on a tablet.
  factory LuckyCardLayout.desktop(Size screen) {
    final w = math.max(screen.width, 1.0);
    final h = math.max(screen.height, 1.0);
    return LuckyCardLayout._(
      screen: Size(w, h),
      canvasRect: Rect.fromLTWH(0, 0, w, h),
      scale: h / designHeight,
      isDesktop: true,
    );
  }

  /// The sides from which a screen is a tablet, in dp (see [isTabletScreen], spec §17BN).
  static const double tabletShortSide = 600;
  static const double tabletLongSide = 800;

  /// The smallest screen that gets the desktop arrangement (the reference's 1280 x 720 file).
  static const double desktopMinWidth = 1280;
  static const double desktopMinHeight = 720;

  // ── The result ──────────────────────────────────────────────────────────

  /// True in tablet mode ([LuckyCardLayout.tablet]).
  final bool isTablet;

  /// True in desktop mode ([LuckyCardLayout.desktop]).
  final bool isDesktop;

  /// The tablet and the desktop both draw their boxes the reference design's way (larger, with the
  /// board's text sized from its width at the tablet files' shares, the chip in hand lifted).
  bool get _roomy => isTablet || isDesktop;

  /// The screen this was worked out for.
  final Size screen;

  /// Where the canvas sits on the screen, in dp.
  final Rect canvasRect;

  /// dp per unit.
  final double scale;


  /// The canvas as its own coordinate space: every rect below is in dp from the
  /// canvas's top-left corner.
  Size get canvasSize => canvasRect.size;

  /// The share of the screen's area the canvas covers (1.0 on a phone).
  double get usedShare => canvasRect.width * canvasRect.height / (screen.width * screen.height);

  /// Turns units into dp.
  double dp(double units) => units * scale;

  /// A text size from units, never below [minDp] (11 by default).
  double fontSize(double units, {double minDp = kLuckyCardMinReadableDp}) =>
      math.max(units * scale, minDp);

  /// How many pixels wide to decode a picture shown [dp] wide, so it is never
  /// decoded larger than it is drawn.
  static int cacheWidth(double dp, double devicePixelRatio) =>
      math.max((dp * devicePixelRatio).ceil(), 1);

  /// The zone the header sits in: exactly the header bar ([designHeaderBar]), flush with the
  /// top and both sides of the canvas.
  Rect get topBar => designHeaderBar;

  // ── The body, from the reference design ─────────────────────────────────
  //
  // Under the header the design has one row: the betting board at the left and the bet
  // panel at the right. Every proportion here was read out of the phone files of
  // `reference-design/royal-cards-standalone/` (the same in all seven):
  //
  //   * the body is padded by 1% of the width (6 to 10 dp) on the left, right and bottom,
  //     and starts 6 dp under the header;
  //   * the panel is 38% of the width (244 to 360 dp) and the gap between the board and it
  //     is 1.2% of the width (6 to 10 dp);
  //   * the board is the largest box of shape 1.48 : 1 that fits what is left, centred;
  //   * inside it, a grid of 5 columns (four cards of 458 parts, then the rank badge of 481)
  //     and 4 rows (the suit bars of 157 parts, then three rows of cards of 464 parts), with
  //     a gap of 1% of the board's width between every two.
  //
  // The cards, bars and badges are drawn filling their cells (the design's own
  // `object-fit: fill`): the cells have the same shape as the pictures (458 : 464 against the
  // cards' 549 : 556, 458 : 157 against the bars' 821 : 281, 481 : 464 against the badges'
  // 878 : 846), so nothing is squeezed.

  /// The padding round the body, and the gap between the board and the panel.
  /// Tablet: 1.4% of the width (10 to 20 dp) and 1.2% of the width (10 to 18 dp).
  /// Desktop: 1.4% of the width (14 to 32 dp) and 1.3% of the width (16 to 32 dp).
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

  /// The gap between the header and the body (phone).
  static const double designBodyGapY = 6;

  /// The gap between the header and the body, and, in tablet mode, between the board and the chip
  /// bar: 6 dp on a phone; on a tablet 1.4% of the height (8 to 14 dp).
  /// Desktop: 1.4% of the height (12 to 22 dp).
  double get bodyGapY => isDesktop
      ? (canvasSize.height * 0.014).clamp(12.0, 22.0).toDouble()
      : isTablet
          ? (canvasSize.height * 0.014).clamp(8.0, 14.0).toDouble()
          : designBodyGapY;

  /// The body: everything under the header, inside its padding.
  Rect get designBody => Rect.fromLTRB(
        designBodyPad,
        designHeaderBar.bottom + bodyGapY,
        canvasSize.width - designBodyPad,
        canvasSize.height - designBodyPad,
      );

  /// The bet panel's width. Tablet: 29% of the width, 300 to 400 dp.
  /// Desktop: the wheel's column: what the board leaves, but never less than the reference's 34% of
  /// the width (360 to 780 dp). The board is as wide as the height under the header allows (1.48 times
  /// the height left above the results row), so on a screen wider than that the extra width goes to
  /// the wheel's column and the wheel can grow until its height is used.
  double get designAsideWidth => isDesktop
      ? math.max(
          (canvasSize.width * 0.34).clamp(360.0, 780.0).toDouble(),
          designBody.width - designBodyGapX - math.max(designBody.height - _actionBarHeight - _resultsBarHeight - 2 * columnGap, 0.0) * 1.48,
        )
      : isTablet
          ? (canvasSize.width * 0.29).clamp(300.0, 400.0).toDouble()
          : (canvasSize.width * 0.38).clamp(244.0, 360.0).toDouble();

  /// The side column: the full height of the body. On a phone and a tablet it is the bet panel, at
  /// the right. On the desktop it is the wheel's column, at the LEFT (the wheel with PLAY and WIN
  /// under it).
  Rect get side => isDesktop
      ? Rect.fromLTRB(designBody.left, designBody.top, designBody.left + designAsideWidth, designBody.bottom)
      : Rect.fromLTRB(designBody.right - designAsideWidth, designBody.top, designBody.right, designBody.bottom);

  // ── The desktop's right column: the board, the results row and the bottom bar ──

  /// Desktop: the gap between the board, the results row and the bottom bar, 1.3% of the height
  /// (10 to 20 dp).
  double get columnGap => _design(0.013, 10, 20);

  /// Desktop: what is right of the wheel's column, the full height of the body.
  Rect get rightColumn => isDesktop
      ? Rect.fromLTRB(side.right + designBodyGapX, designBody.top, designBody.right, designBody.bottom)
      : Rect.zero;

  double get _actionBarHeight => _design(0.115, 92, 150);
  double get _resultsBarHeight => _design(0.058, 50, 76);

  /// Desktop: the bottom bar holding the five chips and the three buttons, 11.5% of the height (92 to
  /// 150 dp) tall, as wide as the right column, at its bottom. [Rect.zero] elsewhere.
  Rect get actionBar => isDesktop
      ? Rect.fromLTRB(rightColumn.left, rightColumn.bottom - _actionBarHeight, rightColumn.right, rightColumn.bottom)
      : Rect.zero;

  /// Desktop: the row of the ten newest history cards, 5.8% of the height (50 to 76 dp) tall, just
  /// above the bottom bar. [Rect.zero] elsewhere.
  Rect get resultsBar => isDesktop
      ? Rect.fromLTRB(rightColumn.left, actionBar.top - columnGap - _resultsBarHeight, rightColumn.right, actionBar.top - columnGap)
      : Rect.zero;

  /// Tablet only: the bar under the board that holds the five chips (the reference design's
  /// purple bar). It is as wide as the column the board is in and [chipBarHeight] tall, at the
  /// bottom of the body. On a phone there is no such bar and this is [Rect.zero] (the chips are in
  /// the bet panel).
  Rect get chipBar => isTablet
      ? Rect.fromLTRB(designBody.left, designBody.bottom - chipBarHeight, side.left - designBodyGapX, designBody.bottom)
      : Rect.zero;

  /// The chip bar's height: 13% of the height, 80 to 124 dp (tablet).
  double get chipBarHeight => _design(0.13, 80, 124);

  /// What is left of the body for the board, before the board's own shape is fitted. In tablet mode
  /// the chip bar and the gap above it are taken off the bottom.
  Rect get designSection => Rect.fromLTRB(
        designBody.left,
        designBody.top,
        side.left - designBodyGapX,
        isTablet ? chipBar.top - bodyGapY : designBody.bottom,
      );

  Rect get _section => isDesktop
      ? Rect.fromLTRB(rightColumn.left, rightColumn.top, rightColumn.right, resultsBar.top - columnGap)
      : designSection;

  /// The board: the largest box of shape 1.48 : 1 that fits the section, centred in it.
  ///
  /// Desktop: flush with the left edge of the right column (the user's change, 2026-10-24), centred up
  /// and down.
  Rect get designBoard {
    final s = _section;
    final w = math.max(math.min(s.width, s.height * 1.48), 0.0);
    final h = math.max(math.min(s.height, s.width * 0.675), 0.0);
    if (isDesktop) return Rect.fromLTWH(s.left, s.center.dy - h / 2, w, h);
    return Rect.fromCenter(center: s.center, width: w, height: h);
  }

  /// The gap between two cells of the board: 1% of the board's width (tablet 0.9%).
  double get designBoardGap => designBoard.width * (_roomy ? 0.009 : 0.01);

  /// The columns' and rows' shares of the board, in the design's own "fr" parts.
  static const List<double> _columnParts = [458, 458, 458, 458, 481];
  static const List<double> _rowParts = [157, 464, 464, 464];

  /// One cell of the board: [column] 0 to 4 (the four suits, then the rank badges), [row] 0 to 3
  /// (the suit bars, then the jack, queen and king rows).
  Rect _cell(int column, int row) {
    final board = designBoard;
    final gap = designBoardGap;
    final unitW = (board.width - 4 * gap) / 2313;
    final unitH = (board.height - 3 * gap) / 1549;
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

  /// The grid: the four suit bars over the 12 cards.
  Rect get grid => Rect.fromLTRB(_cell(0, 0).left, _cell(0, 0).top, _cell(3, 3).right, _cell(3, 3).bottom);

  /// The column of the three rank badges, level with the grid.
  Rect get rankColumn => Rect.fromLTRB(_cell(4, 0).left, _cell(4, 0).top, _cell(4, 3).right, _cell(4, 3).bottom);

  /// One grid cell: [column] 0 to 3 (hearts, spades, diamonds, clubs), [row] 0 to
  /// 3 (the suit bar, then jack, queen, king).
  Rect gridCell(int column, int row) {
    assert(column >= 0 && column < gridColumns && row >= 0 && row < gridRows);
    return _cell(column, row);
  }

  /// The tap area of a suit's bar: its whole cell, which the bar picture fills.
  Rect suitHeader(int column) => gridCell(column, 0);

  /// The tap area of a card: [column] is its suit, [rankRow] 0 to 2 (jack, queen,
  /// king). The card picture fills it.
  Rect cardCell(int column, int rankRow) => gridCell(column, rankRow + 1);

  /// The tap area of a rank badge, level with its row of cards. The badge picture fills it.
  Rect rankSelector(int rankRow) => _cell(4, rankRow + 1);

  /// The size of a card's cell, and so of its picture. Not square: 458 parts wide by 464 high
  /// (a card is 549 x 556).
  Size get cardSize => _cell(0, 1).size;

  // ── The text on the board ───────────────────────────────────────────────
  //
  // The design sizes its board text as a share of the board's own width (CSS `cqw`):
  // the card plate's words 3.4%, a suit bar's name 2.1%, a rank badge's name 2.4%.

  // Tablet: 3.2%, 1.9% and 2.1% (the tablet files' own shares).
  double get designCardFont => designBoard.width * (_roomy ? 0.032 : 0.034);
  double get designBarFont => designBoard.width * (_roomy ? 0.019 : 0.021);
  double get designBadgeFont => designBoard.width * (_roomy ? 0.021 : 0.024);

  /// A picture is drawn this share of the width of the cell it sits in (the reveal card).
  static const double _pictureShare = 0.96;

  /// How wide to decode each picture: exactly the width its cell draws it.
  int cardCacheWidth(double devicePixelRatio) => cacheWidth(_cell(0, 1).width, devicePixelRatio);
  int barCacheWidth(double devicePixelRatio) => cacheWidth(_cell(0, 0).width, devicePixelRatio);
  int selectorCacheWidth(double devicePixelRatio) => cacheWidth(_cell(4, 1).width, devicePixelRatio);

  // ── The header, from the reference design ───────────────────────────────
  //
  // Every size in the design is a share of the screen's SHORT side with its own smallest
  // and largest value in dp; only the outer padding comes from the width. The shares were
  // read from all seven phone files of `reference-design/royal-cards-standalone/`, where
  // they are identical, so the header is followed by measurement rather than by eye.
  //
  // The header is a row, as the design's is, so the balance pill can be exactly as wide as
  // the figure inside it needs; the widget lays that row out. What is fixed here is the bar
  // it goes in and the size of each piece. The bar always fits inside the [topBar] zone, so
  // the board below it is not moved by the header.

  /// A size from the design: [share] of the canvas's height, never below [minDp] nor above
  /// [maxDp]. These are the design's own CSS `clamp(min, share, max)` values.
  double _design(double share, double minDp, double maxDp) =>
      (canvasSize.height * share).clamp(minDp, maxDp).toDouble();

  /// The height of the header bar itself.
  ///
  /// The design's own smallest value is 46 dp, under the 48 dp spec §12.1 requires for a tap
  /// target; a hit area cannot safely grow past the bar's own height without overflowing the
  /// fixed-height row it sits in, so the floor here is raised to 48 instead (never shorter
  /// than the design asks, only ever possibly a touch taller on the smallest phones). The
  /// [topBar] zone is exactly this bar, so nothing else is pushed by the raised floor.
  ///
  /// Tablet: 8.5% of the height, 56 to 84 dp (the tablet files' own).
  ///
  /// Desktop: 8% of the height, 64 to 100 dp.
  double get designHeaderHeight => isDesktop
      ? _design(0.08, 64, 100)
      : isTablet
          ? _design(0.085, 56, 84)
          : _design(0.13, kLuckyCardMinTapDp, 56);

  /// A round button as it is DRAWN. Its tap area, [designBallHit], is never smaller than
  /// 48 dp (spec §12.1) and, because of [designHeaderHeight]'s own floor above, never taller
  /// than the bar it sits in either.
  ///
  /// Shrunk from the design's own 0.11 share after the user saw the buttons crowding the
  /// header on a narrow phone (2026-10-23): a smaller ball leaves the gaps the design drew
  /// between the pieces, instead of eating into them.
  ///
  /// Tablet: 6.8% of the height, 46 to 68 dp (the tablet files' own); the tap area is still held
  /// at 48 dp.
  ///
  /// Desktop: 6.2% of the height, 50 to 80 dp.
  double get designBallSize => isDesktop
      ? _design(0.062, 50, 80)
      : isTablet
          ? _design(0.068, 46, 68)
          : _design(0.095, 34, 42);
  double get designBallHit => math.max(designBallSize, kLuckyCardMinTapDp);

  /// The sunken pill holding the coin and the balance, and the coin inside it.
  /// Tablet: 5.6% and 4.4% of the height.
  /// Desktop: 5.6% (46 to 72 dp) and 4.2% (34 to 56 dp) of the height.
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

  /// The countdown's disc, across. The disc used to sit inside a gold ring and be [countdownDiscShare]
  /// of it; the ring was removed (the user, 2026-10-24) and the disc keeps exactly the size it had.
  /// Phone: 11.6% of the height, 40 to 48 dp, times the share. Tablet: 7.2%, 48 to 72. Desktop: 6.6%,
  /// 52 to 84 (the desktop files put the countdown in the wheel's hub, so they give no size; the user
  /// kept it in the header, 2026-10-24, so this is the tablet's scaled to the taller bar).
  double get designCountdownSize =>
      countdownDiscShare *
      (isDesktop
          ? _design(0.066, 52, 84)
          : isTablet
              ? _design(0.072, 48, 72)
              : _design(0.116, 40, 48));

  /// How much of the old ring's size the disc was: 82%.
  static const double countdownDiscShare = 0.82;

  /// The gap between the header's pieces, and the padding inside its two ends.
  /// Tablet: 1% of the width (8 to 14 dp) and 0.6% of the width (5 to 8 dp).
  /// Desktop: 1% of the width (12 to 20 dp) and 0.6% of the width (6 to 12 dp).
  double get designHeaderGap => isDesktop
      ? (canvasSize.width * 0.01).clamp(12.0, 20.0).toDouble()
      : isTablet
          ? (canvasSize.width * 0.01).clamp(8.0, 14.0).toDouble()
          : (canvasSize.width * 0.009).clamp(5.0, 8.0).toDouble();

  /// The balance figure, the countdown's own digits, and the line of words in the middle.
  /// Tablet: 3.2% (20 to 32 dp) for the balance, 3% (18 to 30) for the words; the countdown's digits
  /// (the tablet files do not size them separately from the ring) are 2.8% (18 to 28), so they fit
  /// the disc.
  /// Desktop: the balance 2.9% (22 to 38 dp), the digits 2.6% (18 to 34), the words 3.1% (22 to 42).
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

  /// The header bar: flush with the top and both sides of the canvas (the user asked,
  /// 2026-10-23, to drop the design's own margin there), [designHeaderHeight] tall.
  Rect get designHeaderBar => Rect.fromLTWH(0, 0, canvasSize.width, designHeaderHeight);

  // ── The bet panel, from the reference design ────────────────────────────
  //
  // The panel (the design's `<aside>`) is a purple box with a gold border. Inside, from the top:
  // PLAY and WIN side by side, the results (the twelve latest rounds as history cards, four across
  // and three down), the five chips in a row, then, pushed to the bottom, the three buttons. Every
  // size is the design's own `clamp(min, share, max)` (shares of the canvas height, see [_design]),
  // except where a floor had to be raised for the readable-text and tap-target rules (spec §12.1),
  // and the results, which are the user's own layout (spec §17BO): the design shows one row of nine.
  // (The tablet puts the chips in their own bar and stacks the buttons; the desktop has no panel.)

  /// The gold border, the padding inside it and the gap between the panel's rows.
  ///
  /// Tablet: the panel is the tablet files' own, 1.6% of the height (12 to 18 dp) of padding and
  /// (10 to 16 dp) between its rows, and holds only PLAY / WIN, the results and the three stacked
  /// buttons: the chips are in [chipBar].
  static const double designPanelBorder = 2;
  double get designPanelPad => isTablet ? _design(0.016, 12, 18) : _design(0.024, 7, 10);
  double get designPanelGap => isTablet ? _design(0.016, 10, 16) : _design(0.022, 6, 10);
  static const double designPanelRadius = 18;

  /// The panel's (and the chip bar's) corner radius: 18 dp on a phone, 22 dp on a tablet (the
  /// tablet files').
  double get panelRadius => _roomy ? 22 : designPanelRadius;

  /// What is left inside the border and the padding: where the four rows go.
  Rect get panelInner => side.deflate(designPanelBorder + designPanelPad);

  /// The gap between PLAY and WIN, and (phone) between the three buttons: 7 dp (tablet 10 dp).
  static const double designCellGap = 7;
  /// Desktop: 14 dp.
  double get cellGap => isDesktop ? 14 : (isTablet ? 10 : designCellGap);

  /// The label over a total (the design's 9 to 10 dp, raised to the 11 dp floor) and the
  /// figure under it, whose line is 1.1 times its size; the cell pads 5 dp above and below.
  /// Tablet: the label 1.5% of the height (10 to 13 dp, held at 11), the figure 4% (24 to 38 dp),
  /// the cell's padding 1.2% of the height (8 to 12 dp) above and below.
  ///
  /// Desktop: the label 1.3% of the height (11 to 16 dp), the figure 3.8% (28 to 52 dp), the cell's
  /// padding 1.1% of the height (8 to 16 dp) above and below and 18 dp at the sides, a 16 dp corner.
  double get designTotalLabelFont => isDesktop
      ? _design(0.013, kLuckyCardMinReadableDp, 16)
      : isTablet
          ? math.max(_design(0.015, 10, 13), kLuckyCardMinReadableDp)
          : kLuckyCardMinReadableDp;
  double get designTotalValueFont => isDesktop
      ? _design(0.038, 28, 52)
      : isTablet
          ? _design(0.04, 24, 38)
          : _design(0.06, 19, 26);
  static const double designTotalLabelLine = 1.2;
  static const double designTotalValueLine = 1.1;
  double get totalPadY => isDesktop ? _design(0.011, 8, 16) : (isTablet ? _design(0.012, 8, 12) : 5);

  /// The sides of a PLAY / WIN cell: 10 dp on a phone, 14 dp on a tablet; its corner 12 / 14 dp.
  double get totalPadX => isDesktop ? 18 : (isTablet ? 14 : 10);
  double get totalCellRadius => isDesktop ? 16 : (isTablet ? 14 : 12);
  double get designTotalHeight =>
      2 * totalPadY + designTotalLabelFont * designTotalLabelLine + designTotalValueFont * designTotalValueLine;

  double get _totalWidth => ((isDesktop ? wheelDiameter : panelInner.width) - cellGap) / 2;

  /// PLAY (what is on the board) and WIN (what the last round paid), side by side: at the top of the
  /// bet panel on a phone and a tablet; on the desktop at the BOTTOM of the wheel's column, as wide as
  /// the wheel and with their bottom edge on the line of the bottom bar's bottom edge.
  Rect get totalBetCell => isDesktop
      ? Rect.fromLTWH(wheelBox.left, side.bottom - designTotalHeight, _totalWidth, designTotalHeight)
      : Rect.fromLTWH(panelInner.left, panelInner.top, _totalWidth, designTotalHeight);
  Rect get winCell => isDesktop
      ? Rect.fromLTWH(wheelBox.left + _totalWidth + cellGap, side.bottom - designTotalHeight, _totalWidth, designTotalHeight)
      : Rect.fromLTWH(panelInner.left + _totalWidth + cellGap, panelInner.top, _totalWidth, designTotalHeight);

  /// The results box: the twelve latest rounds as cards, four across and three down, the newest
  /// first (top left) (the user's decision of 2026-10-24, spec §17BO, replacing the ten tiles in two
  /// rows of five). The phone pads the box 5 dp and puts its cards 3 dp apart.
  static const double designResultsPad = 5;
  static const double designTileGap = 3;
  static const int designResultColumns = 4;
  static const int designResultRows = 3;
  static const int designResultTiles = designResultColumns * designResultRows;

  /// The padding of the results box and the gap between its cards: 5 and 3 dp on a phone. Tablet:
  /// 1.4% of the height (10 to 14 dp) and 1% (6 to 10 dp).
  ///
  /// Desktop: the ten newest cards are in ONE ROW ([resultColumns] 10, [resultRows] 1) in [resultsBar]
  /// (the user's change from twelve, 2026-10-24), with 0.6% of the height (5 to 9 dp) of padding round
  /// them and (4 to 8 dp) between two.
  double get resultsPad => isDesktop ? _design(0.006, 5, 9) : (isTablet ? _design(0.014, 10, 14) : designResultsPad);
  double get tileGap => isDesktop ? _design(0.006, 4, 8) : (isTablet ? _design(0.01, 6, 10) : designTileGap);

  /// How many history cards are across, and down: 4 and 3, or on the desktop 10 and 1.
  int get resultColumns => isDesktop ? 10 : designResultColumns;
  int get resultRows => isDesktop ? 1 : designResultRows;

  /// How many history cards are shown: 12 on a phone and a tablet, 10 on the desktop.
  int get resultCount => resultColumns * resultRows;

  /// The picture of a history card is 604 x 686 (the user's two pictures, spec §17BO): taller than
  /// wide by this much. A card is never drawn taller than its width times this.
  static const double historyCardAspect = 686 / 604;

  /// A history card's width: a quarter of what the box leaves after its padding and three gaps.
  double get designTileWidth => isDesktop
      ? (resultsBar.width - 2 * resultsPad - (resultColumns - 1) * tileGap) / resultColumns
      : (panelInner.width - 2 * resultsPad - (designResultColumns - 1) * tileGap) / designResultColumns;

  /// A history card's height: what the panel has left for three rows, but no taller than the
  /// picture's own shape. On a phone the box shares the panel with the chips (which come right
  /// after it) and the buttons; it gets what is left, so the cards are wide (about 49 x 31 dp on
  /// the smallest phone). On a tablet the panel has no chips and room to spare, so the cards are
  /// the picture's own portrait shape (about 58 x 66 dp at 1024 x 600).
  double get designTileHeight {
    // Desktop: the row's own height, less its padding (never taller than the picture's shape).
    if (isDesktop) return math.max(math.min(resultsBar.height - 2 * resultsPad, designTileWidth * historyCardAspect), 1.0);
    final top = totalBetCell.bottom + designPanelGap;
    final bottom = actionButton(0).top -
        designPanelGap -
        (isTablet ? 0 : designChipRowPadTop + kLuckyCardMinTapDp + designPanelGap);
    final perRow = (bottom - top - 2 * resultsPad - (designResultRows - 1) * tileGap) / designResultRows;
    return math.max(math.min(perRow, designTileWidth * historyCardAspect), 1.0);
  }

  // What is drawn on a history card, all worked out from the card's own size (no text under 11 dp).

  /// The gold border of the frame as drawn: the picture's own 3% of its width at the card's size,
  /// held at 1.5 dp so it never thins to a hair.
  double get tileBorder => math.max(1.5, designTileHeight * 0.026);

  /// The rank letter at the top left: 36% of the card's height, at least 11 dp.
  double get tileLetterFont => math.max(kLuckyCardMinReadableDp, designTileHeight * 0.36);

  /// The suit picture at the bottom middle: no wider than 46% of the card or taller than 52% of it
  /// (at least 12 dp).
  double get tileIconSize => math.max(12.0, math.min(designTileWidth * 0.46, designTileHeight * 0.52));

  /// The red bubble at the top right: 48% of the card's height (18 to 30 dp), its text 55% of that
  /// and never under 11 dp. A long bonus ("10X") widens the bubble instead of shrinking the text.
  double get tileBubbleHeight => (designTileHeight * 0.48).clamp(18.0, 30.0).toDouble();
  double get tileBubbleFont => math.max(kLuckyCardMinReadableDp, tileBubbleHeight * 0.55);

  /// How wide the frame picture is decoded: so that its border is exactly [tileBorder] when it is
  /// drawn (the picture's border is 18 of its 604 px).
  int historyFrameCacheWidth(double devicePixelRatio) =>
      math.max((604 / 18 * tileBorder * devicePixelRatio).round(), 8);

  Rect get resultsPanel => isDesktop
      ? resultsBar
      : Rect.fromLTWH(
          panelInner.left,
          totalBetCell.bottom + designPanelGap,
          panelInner.width,
          2 * resultsPad + designResultRows * designTileHeight + (designResultRows - 1) * tileGap,
        );

  /// History card [index], 0 to [resultCount] - 1: row by row from the top left, 0 the newest round.
  Rect resultTile(int index) {
    assert(index >= 0 && index < resultCount);
    final width = designTileWidth;
    final height = designTileHeight;
    final column = index % resultColumns;
    final row = index ~/ resultColumns;
    return Rect.fromLTWH(
      resultsPanel.left + resultsPad + column * (width + tileGap),
      resultsPanel.top + resultsPad + row * (height + tileGap),
      width,
      height,
    );
  }

  /// The chips: the design draws each [designChipSize] across (12% of the height, no more than
  /// 5.6% of the width, 34 to 52 dp), spread along the row. Each one's tap area is its fifth
  /// of the row (3 dp in from each end) by 48 dp tall; on the smallest phone that is about
  /// 44 dp across, a written exception to the 48 dp rule (the user, 2026-10-23).
  static const int chipCount = 5;
  static const double designChipRowPadTop = 4;
  static const double designChipRowPadSide = 3;
  ///
  /// TABLET: the chips are in [chipBar], under the board. Each is drawn 8.2% of the height across
  /// (50 to 80 dp, the tablet files' own) with 3% of the width (18 to 44 dp) between two, centred in
  /// the bar; if the bar is too narrow for that the chips are drawn smaller. Each chip's tap area is
  /// its own slot (the chip and one gap) by the chip and 16 dp (room for the gold ring and the lift
  /// of the chosen chip), so the five slots touch and never overlap.
  ///
  /// DESKTOP: the chips are the left part of [actionBar], from its padding in; each is drawn 7.6% of
  /// the height across (58 to 100 dp) with 1% of the width (12 to 22 dp) between two; if the bar is too
  /// narrow for chips and buttons they shrink so the chips take no more than 55% of its inside.
  double get designChipSize {
    if (isDesktop) return math.min(_design(0.076, 58, 100), _chipSlot - 4);
    if (!isTablet) return math.min(_design(0.12, 34, 52), canvasSize.width * 0.056).clamp(34.0, 52.0).toDouble();
    return math.min(_design(0.082, 50, 80), _chipSlot - 4);
  }

  /// How big a chip is drawn, as a share of [designChipSize]: the chip in hand and the others. A
  /// phone draws the one in hand full size and the others 79% of it (they would not fit side by side
  /// otherwise); a tablet draws the others full size and lifts the one in hand 6% bigger (the tablet
  /// files' own), both inside their slot.
  double get chipHandScale => _roomy ? 1.06 : 1.0;
  double get chipRestScale => _roomy ? 1.0 : 0.74 / 0.94;

  /// Tablet: the gap between two chips, 3% of the width (18 to 44 dp).
  /// Desktop: 1% of the width (12 to 22 dp).
  double get chipGap => isDesktop
      ? (canvasSize.width * 0.01).clamp(12.0, 22.0).toDouble()
      : (canvasSize.width * 0.03).clamp(18.0, 44.0).toDouble();

  /// Desktop: the bar's padding at its two ends (1.4% of the width, 16 to 28 dp) and the gap between
  /// the chips and the buttons (1.5% of the width, 16 to 32 dp).
  double get actionBarPad => (canvasSize.width * 0.014).clamp(16.0, 28.0).toDouble();
  double get actionBarGap => (canvasSize.width * 0.015).clamp(16.0, 32.0).toDouble();

  /// Tablet: one chip's slot, the chip and a gap, never wider than a fifth of the bar (less 8 dp
  /// at each end).
  double get _chipSlot => isDesktop
      ? math.min(_design(0.076, 58, 100) + chipGap, math.max((actionBar.width - 2 * actionBarPad) * 0.55 / chipCount, 1.0))
      : math.min(_design(0.082, 50, 80) + chipGap, math.max((chipBar.width - 16) / chipCount, 1.0));

  /// The row the five chips share.
  Rect get chipRail {
    if (isDesktop) {
      // The first chip's own left edge is [actionBarPad] in from the bar's left edge.
      final lead = (_chipSlot - designChipSize) / 2;
      final height = math.min(designChipSize + 16, actionBar.height);
      return Rect.fromLTWH(actionBar.left + actionBarPad - lead, actionBar.center.dy - height / 2, chipCount * _chipSlot, height);
    }
    if (!isTablet) {
      return Rect.fromLTWH(
        panelInner.left,
        resultsPanel.bottom + designPanelGap,
        panelInner.width,
        designChipRowPadTop + kLuckyCardMinTapDp,
      );
    }
    return Rect.fromCenter(
      center: chipBar.center,
      width: chipCount * _chipSlot,
      height: math.min(designChipSize + 16, chipBar.height),
    );
  }

  /// Chip [index] (0 is the 5 chip, 4 the 500 chip): its tap area.
  Rect chip(int index) {
    assert(index >= 0 && index < chipCount);
    if (_roomy) {
      return Rect.fromLTWH(chipRail.left + index * _chipSlot, chipRail.top, _chipSlot, chipRail.height);
    }
    final slot = (chipRail.width - 2 * designChipRowPadSide) / chipCount;
    return Rect.fromLTWH(
      chipRail.left + designChipRowPadSide + index * slot,
      chipRail.top + designChipRowPadTop,
      slot,
      kLuckyCardMinTapDp,
    );
  }

  /// The three buttons: side by side along the bottom on a phone, the design's 40 to 48 dp tall,
  /// held at the 48 dp tap floor.
  ///
  /// TABLET: stacked, each the panel's full inner width, 7.4% of the height tall (46 to 70 dp,
  /// held at the 48 dp floor), 1.3% of the height (8 to 14 dp) apart, the last at the bottom of
  /// the panel; the text 3% of the height (18 to 28 dp).
  static const int actionButtonCount = 3;
  ///
  /// DESKTOP: in a row in [actionBar], right of the chips, equal, 0.8% of the width (8 to 16 dp) apart,
  /// 6.7% of the height tall (54 to 88 dp), the text 2.2% (17 to 30 dp).
  double get designButtonHeight => isDesktop
      ? math.max(_design(0.067, 54, 88), kLuckyCardMinTapDp)
      : isTablet
          ? math.max(_design(0.074, 46, 70), kLuckyCardMinTapDp)
          : math.max(_design(0.116, 40, 48), kLuckyCardMinTapDp);
  double get designButtonFont => isDesktop
      ? _design(0.022, 17, 30)
      : isTablet
          ? _design(0.03, 18, 28)
          : math.min(_design(0.042, 12, 17), canvasSize.width * 0.0195).clamp(12.0, 17.0).toDouble();

  /// The corner of a button: 14 dp on a phone, 16 dp on a tablet and on the desktop.
  double get buttonRadius => _roomy ? 16 : 14;

  /// Desktop: the gap between two buttons in the row.
  double get buttonGapX => (canvasSize.width * 0.008).clamp(8.0, 16.0).toDouble();

  /// The gap between two stacked buttons (tablet only): 1.3% of the height, 8 to 14 dp.
  double get buttonGapY => _design(0.013, 8, 14);

  /// Button [index]: phone, left to right; tablet, top to bottom. 0 Double (Rebet), 1 Clear, 2 Remove.
  Rect actionButton(int index) {
    assert(index >= 0 && index < actionButtonCount);
    if (isDesktop) {
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
      return Rect.fromLTWH(panelInner.left, top + index * (designButtonHeight + buttonGapY), panelInner.width, designButtonHeight);
    }
    final width = (panelInner.width - (actionButtonCount - 1) * designCellGap) / actionButtonCount;
    return Rect.fromLTWH(
      panelInner.left + index * (width + designCellGap),
      panelInner.bottom - designButtonHeight,
      width,
      designButtonHeight,
    );
  }

  /// [rect] (in canvas coordinates) as seen from inside [zone]: what a widget placed
  /// in a zone's builder needs.
  Rect within(Rect zone, Rect rect) => rect.shift(-zone.topLeft);

  /// A chip is decoded at the size it is drawn, the largest it ever is (raised 6%).
  int chipCacheWidth(double devicePixelRatio) => cacheWidth(designChipSize * 1.06, devicePixelRatio);

  /// Every suit icon is decoded once, at the size it is drawn in a result card.
  int resultIconCacheWidth(double devicePixelRatio) => cacheWidth(tileIconSize, devicePixelRatio);

  // ── The wheel ───────────────────────────────────────────────────────────

  /// The wheel is as tall as its pointer needs: its widget is this many diameters
  /// high (the pointer sits 6% above the wheel).
  static const double wheelHeightFactor = 1.06;

  /// The wheel's diameter: the largest that fits the grid zone, which the wheel
  /// replaces at the lock (spec §7.3), pointer included.
  ///
  /// DESKTOP: the wheel has its own place in [side], above PLAY and WIN (which are at the column's
  /// bottom): the largest that fits the column's width, or its height less the two cells and the gap
  /// (the pointer included).
  double get wheelDiameter => isDesktop
      ? math.max(math.min(side.width, (side.height - designTotalHeight - wheelGap) / wheelHeightFactor), 1.0)
      : math.min(grid.width, grid.height / wheelHeightFactor);

  /// Desktop: the gap between the wheel and PLAY / WIN, 2.8% of the height (20 to 36 dp).
  double get wheelGap => _design(0.028, 20, 36);

  /// The wheel widget's box, pointer included, centred in the grid zone (desktop: centred across
  /// [side] and up and down in what is above PLAY / WIN).
  Rect get wheelBox => isDesktop
      ? Rect.fromLTWH(
          side.center.dx - wheelDiameter / 2,
          side.top + math.max((side.height - designTotalHeight - wheelGap - wheelDiameter * wheelHeightFactor) / 2, 0.0),
          wheelDiameter,
          wheelDiameter * wheelHeightFactor,
        )
      : Rect.fromCenter(
          center: grid.center,
          width: wheelDiameter,
          height: wheelDiameter * wheelHeightFactor,
        );

  // ── The reveal ──────────────────────────────────────────────────────────

  /// Width over height of Triple Chance's win-popup frame (823 x 455) and of its
  /// title picture (754 x 129), both used read-only.
  static const double winPopupAspect = 823 / 455;
  static const double winTextAspect = 754 / 129;

  /// The big card of the reveal, centred in the rank column, which it replaces
  /// while the wheel turns (spec §7.3).
  Rect get revealCard {
    final side = math.min(rankColumn.width * _pictureShare, rankColumn.height);
    return Rect.fromCenter(center: rankColumn.center, width: side, height: side);
  }

  /// The wheel's own centre: where the coins burst from.
  Offset get wheelCenter {
    final d = wheelDiameter;
    return Offset(wheelBox.center.dx, wheelBox.top + d * 0.06 + d / 2);
  }

  /// The win popup, centred in the canvas: 64% of the canvas height, as wide as the
  /// frame picture needs, and never wider than 92% of the canvas.
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

  /// How wide to decode the pictures: each at exactly the width it is drawn.
  int revealCacheWidth(double devicePixelRatio) => cacheWidth(revealCard.width, devicePixelRatio);
  int winPopupCacheWidth(double devicePixelRatio) => cacheWidth(winPopup.width, devicePixelRatio);

  /// Every zone, for tests and for drawing a map of the layout. In tablet mode the chip bar is one too;
  /// on the desktop `side` is the wheel's column and there are the results row and the bottom bar.
  Map<String, Rect> get zones => {
        'topBar': topBar,
        'grid': grid,
        'rankColumn': rankColumn,
        'side': side,
        if (isTablet) 'chipBar': chipBar,
        if (isDesktop) ...{'resultsBar': resultsBar, 'actionBar': actionBar},
      };
}
