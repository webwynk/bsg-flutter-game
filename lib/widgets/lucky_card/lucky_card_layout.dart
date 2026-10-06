// Where everything on the Lucky Card screen goes, worked out from the size of the
// screen alone. Pure arithmetic: no widget, no image, no state, so it is tested
// directly at every device shape.
//
// The rules are those decided on 2026-10-06 (spec §17M, Option B, a flexible
// canvas, and §12.2, very responsive on every phone and tablet):
//
//   * The design is 1000 units high. A "unit" is a thousandth of the canvas
//     height; every size below is written in units and turned into dp by the
//     scale, so nothing is a fixed number of pixels.
//   * The canvas takes the screen's shape, but only between 1.6 : 1 and 2.4 : 1.
//     A squarer screen (a 4:3 tablet) gets a 1.6 : 1 canvas, centred; a wider one
//     a 2.4 : 1 canvas. The background is painted over the whole screen, so what
//     is left over reads as background, not as bars.
//   * Inside the canvas the zones keep one structure. Extra width goes first to
//     the cells (up to 230 units wide), then to the side column (up to 880), and
//     the rest to the outer margins, which keeps the content centred.
//
// The zones follow the diagram of spec §7.3. This file fixes the three zones the
// board needs (the grid, the rank column, the status strip) and the two it
// leaves room for (the top bar and the side column); what goes inside the last
// two is decided in App Step 7.
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
    required double canvasWidthUnits,
    required double boardLeftUnits,
    required double cellWidthUnits,
    required double sideWidthUnits,
  })  : _canvasWidthUnits = canvasWidthUnits,
        _boardLeft = boardLeftUnits,
        _cellW = cellWidthUnits,
        _sideW = sideWidthUnits;

  // ── The rules, in units ─────────────────────────────────────────────────

  static const double designHeight = 1000;
  static const double minRatio = 1.6;
  static const double maxRatio = 2.4;

  static const double _margin = 20;
  static const double _gap = 20;
  // 134 units is 48 dp on the shortest phone (360 dp tall): the top bar holds
  // buttons whose tap area must be 48 dp, and a tap area cannot reach outside its
  // parent (App Step 7a, spec §17W).
  static const double _topBarH = 134;
  static const double _statusH = 70;
  static const double _rankW = 260;
  static const double _cellMinW = 170;
  static const double _cellMaxW = 230;
  // 560 = the chip rail (134) + its gap (8) + three 134-unit buttons side by side
  // with two gaps of 8 (418): every button is 48 dp wide on the smallest phone.
  static const double _sideMinW = 560;
  static const double _sideMaxW = 880;

  /// Rows in the grid: the suit header, then Jacks, Queens and Kings.
  static const int gridRows = 4;

  /// Columns in the grid, one per suit.
  static const int gridColumns = 4;

  static const double _mainTop = _topBarH + _margin;
  static const double _mainBottom = designHeight - _margin;
  static const double _gridH = _mainBottom - _mainTop - _statusH - _gap;
  static const double _rowPitch = _gridH / gridRows;

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
    final wu = canvasW / scale;

    final availW = wu - 2 * _margin - 2 * _gap;
    final cellW = ((availW - _rankW - _sideMinW) / 4).clamp(_cellMinW, _cellMaxW).toDouble();
    final boardW = gridColumns * cellW;
    final sideW = (availW - boardW - _rankW).clamp(_sideMinW, _sideMaxW).toDouble();
    final contentW = boardW + _rankW + sideW + 2 * _gap;
    final left = (wu - contentW) / 2;

    return LuckyCardLayout._(
      screen: Size(w, h),
      canvasRect: Rect.fromLTWH((w - canvasW) / 2, (h - canvasH) / 2, canvasW, canvasH),
      scale: scale,
      canvasWidthUnits: wu,
      boardLeftUnits: left,
      cellWidthUnits: cellW,
      sideWidthUnits: sideW,
    );
  }

  // ── The result ──────────────────────────────────────────────────────────

  /// The screen this was worked out for.
  final Size screen;

  /// Where the canvas sits on the screen, in dp.
  final Rect canvasRect;

  /// dp per unit.
  final double scale;

  final double _canvasWidthUnits;
  final double _boardLeft;
  final double _cellW;
  final double _sideW;

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

  Rect _r(double l, double t, double w, double h) => Rect.fromLTWH(l * scale, t * scale, w * scale, h * scale);

  double get _rankLeft => _boardLeft + gridColumns * _cellW + _gap;
  double get _sideLeft => _rankLeft + _rankW + _gap;

  /// The top bar: the whole width, 134 units high (exit, balance, the countdown,
  /// sound, info).
  Rect get topBar => _r(0, 0, _canvasWidthUnits, _topBarH);

  /// The grid: the suit headers and the 12 cards.
  Rect get grid => _r(_boardLeft, _mainTop, gridColumns * _cellW, _gridH);

  /// The column of the three rank selectors, level with the grid.
  Rect get rankColumn => _r(_rankLeft, _mainTop, _rankW, _gridH);

  /// The status strip under the grid and the rank column ("PLACE YOUR CHIPS").
  Rect get status => _r(_boardLeft, _mainTop + _gridH + _gap, gridColumns * _cellW + _gap + _rankW, _statusH);

  /// The side column, the full height of the main area (play and win, limits,
  /// results, chips, controls, countdown).
  Rect get side => _r(_sideLeft, _mainTop, _sideW, _mainBottom - _mainTop);

  /// One grid cell: [column] 0 to 3 (hearts, spades, diamonds, clubs), [row] 0 to
  /// 3 (the suit header, then jack, queen, king).
  Rect gridCell(int column, int row) {
    assert(column >= 0 && column < gridColumns && row >= 0 && row < gridRows);
    return _r(_boardLeft + column * _cellW, _mainTop + row * _rowPitch, _cellW, _rowPitch);
  }

  /// The tap area of a suit's header: its name and its bar.
  Rect suitHeader(int column) => gridCell(column, 0);

  /// The tap area of a card: [column] is its suit, [rankRow] 0 to 2 (jack, queen,
  /// king).
  Rect cardCell(int column, int rankRow) => gridCell(column, rankRow + 1);

  /// The side of the square a card picture is drawn in, centred in its cell.
  double get cardSide => dp(math.min(_cellW, _rowPitch));

  /// The square a card picture is drawn in.
  Rect cardImage(int column, int rankRow) =>
      Rect.fromCenter(center: cardCell(column, rankRow).center, width: cardSide, height: cardSide);

  /// The tap area of a rank selector, level with its row of cards.
  Rect rankSelector(int rankRow) => _r(_rankLeft, _mainTop + (rankRow + 1) * _rowPitch, _rankW, _rowPitch);

  /// The empty slot at the top of the rank column, level with the suit headers.
  Rect get rankHeaderSlot => _r(_rankLeft, _mainTop, _rankW, _rowPitch);

  // ── The names and pictures of the suit headers and rank selectors ───────

  /// Width over height of the suit-bar picture (the supplied file, 1232 x 508).
  static const double barAspect = 1232 / 508;

  /// Width over height of the rank-selector picture (952 x 497).
  static const double selectorAspect = 952 / 497;

  /// A picture is drawn this share of the width of the cell it sits in.
  static const double _pictureShare = 0.96;

  /// The size of the suit and rank names above the bars and selectors.
  static const double _labelUnits = 34;
  static const double _labelGapUnits = 6;

  double get labelFontSize => fontSize(_labelUnits);

  /// One name above one picture, the pair centred up and down in [cell].
  ({Rect label, Rect picture}) _stacked(Rect cell, double aspect) {
    final labelH = labelFontSize * 1.2;
    // On a screen smaller than the supported minimum the pair may not fit the
    // cell's height: the picture then shrinks, keeping its shape.
    final room = math.max(cell.height - labelH - dp(_labelGapUnits), 0.0);
    final pictureH = math.min(cell.width * _pictureShare / aspect, room);
    final width = pictureH * aspect;
    final total = labelH + dp(_labelGapUnits) + pictureH;
    final top = cell.top + math.max((cell.height - total) / 2, 0);
    return (
      label: Rect.fromLTWH(cell.left, top, cell.width, labelH),
      picture: Rect.fromLTWH(cell.center.dx - width / 2, top + labelH + dp(_labelGapUnits), width, pictureH),
    );
  }

  /// The name above a suit's bar ("Hearts"), inside its header.
  Rect suitLabel(int column) => _stacked(suitHeader(column), barAspect).label;

  /// The suit's bar picture, inside its header.
  Rect suitBar(int column) => _stacked(suitHeader(column), barAspect).picture;

  /// The name above a rank's selector ("Jacks"), inside its row.
  Rect rankLabel(int rankRow) => _stacked(rankSelector(rankRow), selectorAspect).label;

  /// The rank's selector picture, inside its row.
  Rect rankPicture(int rankRow) => _stacked(rankSelector(rankRow), selectorAspect).picture;

  // ── The top bar's pieces ────────────────────────────────────────────────

  /// A top-bar button is drawn this size and has a tap area as tall as the bar.
  static const double _barButton = 100;
  static const double _barHit = 134;

  double get _wu => _canvasWidthUnits;

  /// The tap areas: each is the full height of the bar and 134 units wide (48 dp
  /// on the shortest phone). Exit is at the left, sound and info at the right.
  Rect get exitHit => _r(_margin, 0, _barHit, _topBarH);
  Rect get infoHit => _r(_wu - _margin - _barHit, 0, _barHit, _topBarH);
  Rect get soundHit => _r(_wu - _margin - 2 * _barHit - 6, 0, _barHit, _topBarH);

  Rect _drawn(Rect hit) => Rect.fromCenter(center: hit.center, width: dp(_barButton), height: dp(_barButton));

  /// The buttons as drawn, centred in their tap areas.
  Rect get exitButton => _drawn(exitHit);
  Rect get soundButton => _drawn(soundHit);
  Rect get infoButton => _drawn(infoHit);

  /// The balance, to the right of the exit button.
  Rect get balanceBox => _r(_margin + _barHit + 16, (_topBarH - 100) / 2, 380, 100);

  /// The countdown, in the middle of the bar.
  Rect get countdownBox => _r(_wu / 2 - 180, (_topBarH - 118) / 2, 360, 118);

  // ── The side column ─────────────────────────────────────────────────────
  //
  // At the left, the chip rail: five chips of 134 units (48 dp on the shortest
  // phone) one above the other, spread over the column's whole height. Beside it,
  // from the top: PLAY and WIN side by side, the limits, the results (the latest
  // and the nine before it), and at the bottom the three buttons side by side.
  // Three buttons stacked would take 422 of the 826 units; side by side they take
  // 134 and leave the results room to be read.

  static const double _railW = 134;
  static const double _railGap = 8;
  static const double _chipSize = 134;
  static const double _playH = 100;
  static const double _limitsH = 92;
  static const double _blockGap = 10;
  static const double _buttonH = 134;
  static const double _buttonGap = 8;
  static const double _resultPad = 6;
  static const double _resultCurrentH = 110;
  static const double _resultGap = 6;

  /// Chips in the rail, and buttons under the results.
  static const int chipCount = 5;
  static const int actionButtonCount = 3;

  /// The gap between two chips: they fill the column from top to bottom.
  static const double _chipGap = (_mainBottom - _mainTop - chipCount * _chipSize) / (chipCount - 1);

  double get _rightX => _sideLeft + _railW + _railGap;
  double get _rightW => _sideW - _railW - _railGap;
  double get _resultsTop => _mainTop + _playH + _blockGap + _limitsH + _blockGap;
  static const double _buttonsTop = _mainBottom - _buttonH;

  /// The whole chip rail.
  Rect get chipRail => _r(_sideLeft, _mainTop, _railW, _mainBottom - _mainTop);

  /// Chip [index] (0 is the 5 chip, 4 the 500 chip); its tap area is its own square.
  Rect chip(int index) {
    assert(index >= 0 && index < chipCount);
    return _r(_sideLeft, _mainTop + index * (_chipSize + _chipGap), _chipSize, _chipSize);
  }

  /// PLAY (the stake) and WIN (the last payout), side by side.
  Rect get playCell => _r(_rightX, _mainTop, (_rightW - 8) / 2, _playH);
  Rect get winCell => _r(_rightX + (_rightW - 8) / 2 + 8, _mainTop, (_rightW - 8) / 2, _playH);

  /// The MIN and MAX limits.
  Rect get limitsPanel => _r(_rightX, _mainTop + _playH + _blockGap, _rightW, _limitsH);

  double get _resultsH => _buttonsTop - _blockGap - _resultsTop;

  /// The results: the latest on top, the nine before it in a 3 x 3 grid.
  Rect get resultsPanel => _r(_rightX, _resultsTop, _rightW, _resultsH);
  Rect get resultCurrent => _r(_rightX + _resultPad, _resultsTop + _resultPad, _rightW - 2 * _resultPad, _resultCurrentH);

  /// Tile [index] of the 3 x 3 grid, 0 to 8, left to right and top to bottom.
  Rect resultTile(int index) {
    assert(index >= 0 && index < 9);
    final gridTop = _resultsTop + _resultPad + _resultCurrentH + _resultGap;
    final gridH = _resultsH - 2 * _resultPad - _resultCurrentH - _resultGap;
    final tileH = (gridH - 2 * _resultGap) / 3;
    final tileW = (_rightW - 2 * _resultPad - 2 * _resultGap) / 3;
    final row = index ~/ 3, col = index % 3;
    return _r(
      _rightX + _resultPad + col * (tileW + _resultGap),
      gridTop + row * (tileH + _resultGap),
      tileW,
      tileH,
    );
  }

  /// Button [index], left to right: 0 Double (Rebet), 1 Clear, 2 Remove.
  Rect actionButton(int index) {
    assert(index >= 0 && index < actionButtonCount);
    final w = (_rightW - (actionButtonCount - 1) * _buttonGap) / actionButtonCount;
    return _r(_rightX + index * (w + _buttonGap), _buttonsTop, w, _buttonH);
  }

  /// [rect] (in canvas coordinates) as seen from inside [zone]: what a widget placed
  /// in a zone's builder needs.
  Rect within(Rect zone, Rect rect) => rect.shift(-zone.topLeft);

  /// The suit icon in the latest result, and in a tile of the grid (square sides, dp).
  double get resultCurrentIcon => resultCurrent.height * 0.72;
  double get resultTileIcon => math.min(resultTile(0).height * 0.46, resultTile(0).width * 0.42);

  /// A chip is decoded at the width of its tap area, the largest it is drawn.
  int chipCacheWidth(double devicePixelRatio) => cacheWidth(chip(0).width, devicePixelRatio);

  /// Every suit icon is decoded once, at the larger of the two sizes.
  int resultIconCacheWidth(double devicePixelRatio) => cacheWidth(resultCurrentIcon, devicePixelRatio);

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
  int cardCacheWidth(double devicePixelRatio) => cacheWidth(cardSide, devicePixelRatio);
  int barCacheWidth(double devicePixelRatio) => cacheWidth(suitBar(0).width, devicePixelRatio);
  int selectorCacheWidth(double devicePixelRatio) => cacheWidth(rankPicture(0).width, devicePixelRatio);
  int revealCacheWidth(double devicePixelRatio) => cacheWidth(revealCard.width, devicePixelRatio);
  int winPopupCacheWidth(double devicePixelRatio) => cacheWidth(winPopup.width, devicePixelRatio);

  /// Every zone, for tests and for drawing a map of the layout.
  Map<String, Rect> get zones => {
        'topBar': topBar,
        'grid': grid,
        'rankColumn': rankColumn,
        'status': status,
        'side': side,
      };
}
