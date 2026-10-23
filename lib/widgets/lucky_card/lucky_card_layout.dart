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
  });

  // ── The rules, in units ─────────────────────────────────────────────────

  static const double designHeight = 1000;
  static const double minRatio = 1.6;
  static const double maxRatio = 2.4;

  /// Rows in the grid: the suit header, then Jacks, Queens and Kings.
  static const int gridRows = 4;

  /// Columns in the grid, one per suit.
  static const int gridColumns = 4;

  /// Works out the layout for a screen of this size.
  factory LuckyCardLayout.of(Size screen) {
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

  // ── The result ──────────────────────────────────────────────────────────

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
  double get designBodyPad => (canvasSize.width * 0.01).clamp(6.0, 10.0).toDouble();
  double get designBodyGapX => (canvasSize.width * 0.012).clamp(6.0, 10.0).toDouble();

  /// The gap between the header and the body.
  static const double designBodyGapY = 6;

  /// The body: everything under the header, inside its padding.
  Rect get designBody => Rect.fromLTRB(
        designBodyPad,
        designHeaderBar.bottom + designBodyGapY,
        canvasSize.width - designBodyPad,
        canvasSize.height - designBodyPad,
      );

  /// The bet panel's width.
  double get designAsideWidth => (canvasSize.width * 0.38).clamp(244.0, 360.0).toDouble();

  /// The side column (the bet panel): the full height of the body, at its right.
  Rect get side => Rect.fromLTRB(designBody.right - designAsideWidth, designBody.top, designBody.right, designBody.bottom);

  /// What is left of the body for the board, before the board's own shape is fitted.
  Rect get designSection => Rect.fromLTRB(designBody.left, designBody.top, side.left - designBodyGapX, designBody.bottom);

  /// The board: the largest box of shape 1.48 : 1 that fits the section, centred in it.
  Rect get designBoard {
    final s = designSection;
    final w = math.max(math.min(s.width, s.height * 1.48), 0.0);
    final h = math.max(math.min(s.height, s.width * 0.675), 0.0);
    return Rect.fromCenter(center: s.center, width: w, height: h);
  }

  /// The gap between two cells of the board.
  double get designBoardGap => designBoard.width * 0.01;

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

  /// The empty cell at the top of the rank column, level with the suit bars.
  Rect get rankHeaderSlot => _cell(4, 0);

  /// Where each picture is drawn. The design draws every picture filling its cell, so these
  /// are the cells themselves (the old layout fitted a smaller picture inside a bigger cell).
  Rect cardImage(int column, int rankRow) => cardCell(column, rankRow);
  Rect suitBar(int column) => suitHeader(column);
  Rect rankPicture(int rankRow) => rankSelector(rankRow);

  /// The size of a card's cell, and so of its picture. Not square: 458 parts wide by 464 high
  /// (a card is 549 x 556).
  Size get cardSize => _cell(0, 1).size;

  // ── The text on the board ───────────────────────────────────────────────
  //
  // The design sizes its board text as a share of the board's own width (CSS `cqw`):
  // the card plate's words 3.4%, a suit bar's name 2.1%, a rank badge's name 2.4%.

  double get designCardFont => designBoard.width * 0.034;
  double get designBarFont => designBoard.width * 0.021;
  double get designBadgeFont => designBoard.width * 0.024;

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
  double get designHeaderHeight => _design(0.13, kLuckyCardMinTapDp, 56);

  /// A round button as it is DRAWN. Its tap area, [designBallHit], is never smaller than
  /// 48 dp (spec §12.1) and, because of [designHeaderHeight]'s own floor above, never taller
  /// than the bar it sits in either.
  ///
  /// Shrunk from the design's own 0.11 share after the user saw the buttons crowding the
  /// header on a narrow phone (2026-10-23): a smaller ball leaves the gaps the design drew
  /// between the pieces, instead of eating into them.
  double get designBallSize => _design(0.095, 34, 42);
  double get designBallHit => math.max(designBallSize, kLuckyCardMinTapDp);

  /// The sunken pill holding the coin and the balance, and the coin inside it.
  double get designPillHeight => _design(0.094, 32, 38);
  double get designCoinSize => _design(0.072, 24, 30);

  /// The coin picture is decoded at the size it is drawn.
  int coinCacheWidth(double devicePixelRatio) => cacheWidth(designCoinSize, devicePixelRatio);

  /// The countdown's ring.
  double get designCountdownSize => _design(0.116, 40, 48);

  /// The gap between the header's pieces, and the padding inside its two ends.
  double get designHeaderGap => (canvasSize.width * 0.009).clamp(5.0, 8.0).toDouble();
  double get designHeaderPad => 4;

  /// The balance figure, the countdown's own digits, and the line of words in the middle.
  double get designBalanceFont => _design(0.05, 16, 21);
  double get designCountdownFont => _design(0.05, 17, 21);
  double get designStatusFont => (canvasSize.width * 0.02).clamp(13.0, 17.0).toDouble();

  /// The header bar: flush with the top and both sides of the canvas (the user asked,
  /// 2026-10-23, to drop the design's own margin there), [designHeaderHeight] tall.
  Rect get designHeaderBar => Rect.fromLTWH(0, 0, canvasSize.width, designHeaderHeight);

  // ── The bet panel, from the reference design ────────────────────────────
  //
  // The panel (the design's `<aside>`) is a purple box with a gold border. Inside, from the top:
  // PLAY and WIN side by side, the results (the ten latest rounds in two rows of five), the five
  // chips in a row, then, pushed to the bottom, the three buttons. Every size is the design's own
  // `clamp(min, share, max)` (shares of the canvas height, see [_design]), except where a floor
  // had to be raised for the readable-text and tap-target rules (spec §12.1), and the results,
  // which are the user's own layout (2026-10-23): the design shows one row of nine.

  /// The gold border, the padding inside it and the gap between the panel's rows.
  static const double designPanelBorder = 2;
  double get designPanelPad => _design(0.024, 7, 10);
  double get designPanelGap => _design(0.022, 6, 10);
  static const double designPanelRadius = 18;

  /// What is left inside the border and the padding: where the four rows go.
  Rect get panelInner => side.deflate(designPanelBorder + designPanelPad);

  /// The gap between TOTAL BET and WIN, and between the three buttons.
  static const double designCellGap = 7;

  /// The label over a total (the design's 9 to 10 dp, raised to the 11 dp floor) and the
  /// figure under it, whose line is 1.1 times its size; the cell pads 5 dp above and below.
  double get designTotalLabelFont => kLuckyCardMinReadableDp;
  double get designTotalValueFont => _design(0.06, 19, 26);
  static const double designTotalLabelLine = 1.2;
  static const double designTotalValueLine = 1.1;
  double get designTotalHeight => 10 + designTotalLabelFont * designTotalLabelLine + designTotalValueFont * designTotalValueLine;

  double get _totalWidth => (panelInner.width - designCellGap) / 2;

  /// PLAY (what is on the board) and WIN (what the last round paid), side by side.
  Rect get totalBetCell => Rect.fromLTWH(panelInner.left, panelInner.top, _totalWidth, designTotalHeight);
  Rect get winCell => Rect.fromLTWH(panelInner.left + _totalWidth + designCellGap, panelInner.top, _totalWidth, designTotalHeight);

  /// The results box: the ten latest rounds in two rows of five, the newest first (top left),
  /// inside a padding of 7 dp and 4 dp apart (the user's decision of 2026-10-23, replacing the
  /// design's LAST RESULT line over a single row of nine).
  static const double designResultsPad = 7;
  static const double designTileGap = 4;
  static const int designResultColumns = 5;
  static const int designResultRows = 2;
  static const int designResultTiles = designResultColumns * designResultRows;

  /// A result card: tall enough for the rank letter and the suit picture side by side, and the
  /// bonus under them, each at least 11 dp.
  double get designTileHeight => _design(0.1, 36, 44);

  /// The text and picture in a result card: the rank letter and the suit picture side by side,
  /// then the bonus under them.
  static const double designTileLetterFont = 14;
  static const double designTileIcon = 14;
  static const double designTileBonusFont = 12;

  Rect get resultsPanel => Rect.fromLTWH(
        panelInner.left,
        totalBetCell.bottom + designPanelGap,
        panelInner.width,
        2 * designResultsPad + designResultRows * designTileHeight + (designResultRows - 1) * designTileGap,
      );

  /// Result card [index], 0 to 9: row by row from the top left, 0 the newest round.
  Rect resultTile(int index) {
    assert(index >= 0 && index < designResultTiles);
    final width = (resultsPanel.width - 2 * designResultsPad - (designResultColumns - 1) * designTileGap) / designResultColumns;
    final column = index % designResultColumns;
    final row = index ~/ designResultColumns;
    return Rect.fromLTWH(
      resultsPanel.left + designResultsPad + column * (width + designTileGap),
      resultsPanel.top + designResultsPad + row * (designTileHeight + designTileGap),
      width,
      designTileHeight,
    );
  }

  /// The chips: the design draws each [designChipSize] across (12% of the height, no more than
  /// 5.6% of the width, 34 to 52 dp), spread along the row. Each one's tap area is its fifth
  /// of the row (3 dp in from each end) by 48 dp tall; on the smallest phone that is about
  /// 44 dp across, a written exception to the 48 dp rule (the user, 2026-10-23).
  static const int chipCount = 5;
  static const double designChipRowPadTop = 4;
  static const double designChipRowPadSide = 3;
  double get designChipSize => math.min(_design(0.12, 34, 52), canvasSize.width * 0.056).clamp(34.0, 52.0).toDouble();

  /// The row the five chips share.
  Rect get chipRail => Rect.fromLTWH(
        panelInner.left,
        resultsPanel.bottom + designPanelGap,
        panelInner.width,
        designChipRowPadTop + kLuckyCardMinTapDp,
      );

  /// Chip [index] (0 is the 5 chip, 4 the 500 chip): its tap area.
  Rect chip(int index) {
    assert(index >= 0 && index < chipCount);
    final slot = (chipRail.width - 2 * designChipRowPadSide) / chipCount;
    return Rect.fromLTWH(
      chipRail.left + designChipRowPadSide + index * slot,
      chipRail.top + designChipRowPadTop,
      slot,
      kLuckyCardMinTapDp,
    );
  }

  /// The three buttons, side by side along the bottom: the design's 40 to 48 dp tall, held at
  /// the 48 dp tap floor.
  static const int actionButtonCount = 3;
  double get designButtonHeight => math.max(_design(0.116, 40, 48), kLuckyCardMinTapDp);
  double get designButtonFont => math.min(_design(0.042, 12, 17), canvasSize.width * 0.0195).clamp(12.0, 17.0).toDouble();

  /// Button [index], left to right: 0 Double (Rebet), 1 Clear, 2 Remove.
  Rect actionButton(int index) {
    assert(index >= 0 && index < actionButtonCount);
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
  int resultIconCacheWidth(double devicePixelRatio) => cacheWidth(designTileIcon, devicePixelRatio);

  // ── The wheel ───────────────────────────────────────────────────────────

  /// The wheel is as tall as its pointer needs: its widget is this many diameters
  /// high (the pointer sits 6% above the wheel).
  static const double wheelHeightFactor = 1.06;

  /// The wheel's diameter: the largest that fits the grid zone, which the wheel
  /// replaces at the lock (spec §7.3), pointer included.
  double get wheelDiameter => math.min(grid.width, grid.height / wheelHeightFactor);

  /// The wheel widget's box, pointer included, centred in the grid zone.
  Rect get wheelBox => Rect.fromCenter(
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

  /// Every zone, for tests and for drawing a map of the layout.
  Map<String, Rect> get zones => {
        'topBar': topBar,
        'grid': grid,
        'rankColumn': rankColumn,
        'side': side,
      };
}
