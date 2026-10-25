// The whole Spin2Win screen, laid out as the reference design's boards: the top bar, then the wheel
// at the left and the betting panel at the right, then the history strip along the bottom. The
// phone board (844 x 390 dp) draws them as they are; the tablet and desktop boards (Phase 7,
// spin2win_layout.dart) enlarge them as the design does. [Spin2WinViewport] picks the board and
// scales it to the real screen.
//
//   * [Spin2WinFrameData] is everything the screen shows, as plain values, so the frame can be
//     drawn (and tested) with sample numbers; spin2win_frame_binding.dart makes it from the
//     provider.
//   * Each board is laid out at its design height and between its narrowest and widest: on a
//     longer screen the betting panel and the bars grow wider; the wheel keeps its size.
//
// Belongs to Spin2Win only.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../models/spin2win_board.dart';
import 'spin2win_bet_panel.dart';
import 'spin2win_layout.dart';
import 'spin2win_history_strip.dart';
import 'spin2win_no_more_bets.dart';
import 'spin2win_palette.dart';
import 'spin2win_top_bar.dart';
import 'spin2win_wheel.dart';

/// Everything the screen shows.
class Spin2WinFrameData {
  const Spin2WinFrameData({
    required this.balance,
    required this.play,
    required this.win,
    required this.muted,
    required this.stakes,
    required this.selectedChip,
    required this.countdown,
    required this.rebetMode,
    required this.wheelAngle,
    required this.dome,
    required this.history,
    this.isLocked = false,
    this.hasBets = false,
    this.canAffordRebet = false,
    this.winningNumber,
    this.winKey,
    this.noMoreBets = false,
  });

  final int balance;
  final int play;
  final int win;
  final bool muted;
  final Map<int, int> stakes;
  final Spin2WinChip? selectedChip;
  final int countdown;
  final bool rebetMode;
  final double wheelAngle;
  final Spin2WinDome dome;
  final List<Spin2WinHistoryTile> history;

  /// Betting is closed: the panel is dimmed and ignores taps.
  final bool isLocked;

  /// Some number holds coins (DOUBLE, CLEAR and REMOVE work).
  final bool hasBets;

  /// The balance covers the saved bet (REBET works).
  final bool canAffordRebet;

  /// The number the wheel stopped on, while the result is shown (its card is ringed in gold).
  final int? winningNumber;

  /// The winning round just paid in (the coin box and the WIN figure bump when it changes).
  final Object? winKey;

  /// From the lock mark until the wheel starts: the NO MORE BETS sign is over the panel.
  final bool noMoreBets;

  /// The design's own sample: 1,250 coins, the 5 chip in hand, 90 seconds, nothing on the board,
  /// the last result 1 with no bonus, and its ten history tiles.
  static const Spin2WinFrameData sample = Spin2WinFrameData(
    balance: 1250,
    play: 0,
    win: 0,
    muted: false,
    stakes: {},
    selectedChip: Spin2WinChip.five,
    countdown: 90,
    rebetMode: false,
    wheelAngle: 0,
    dome: Spin2WinDomeLanded(1, 1),
    history: [
      Spin2WinHistoryTile(number: 1, bonusMultiplier: 1),
      Spin2WinHistoryTile(number: 8, bonusMultiplier: 3),
      Spin2WinHistoryTile(number: 2, bonusMultiplier: 1),
      Spin2WinHistoryTile(number: 5, bonusMultiplier: 1),
      Spin2WinHistoryTile(number: 7, bonusMultiplier: 4),
      Spin2WinHistoryTile(number: 8, bonusMultiplier: 1),
      Spin2WinHistoryTile(number: 6, bonusMultiplier: 2),
      Spin2WinHistoryTile(number: 5, bonusMultiplier: 1),
      Spin2WinHistoryTile(number: 4, bonusMultiplier: 1),
      Spin2WinHistoryTile(number: 9, bonusMultiplier: 3),
    ],
  );
}

/// The taps the frame hands on. Every one is optional, so the frame can be drawn unwired.
class Spin2WinFrameActions {
  const Spin2WinFrameActions({
    this.onExit,
    this.onRecords,
    this.onSound,
    this.onNumber,
    this.onChip,
    this.onOdd,
    this.onEven,
    this.onDoubleOrRebet,
    this.onRemove,
    this.onClear,
  });

  final VoidCallback? onExit;
  final VoidCallback? onRecords;
  final VoidCallback? onSound;
  final ValueChanged<int>? onNumber;
  final ValueChanged<Spin2WinChip>? onChip;
  final VoidCallback? onOdd;
  final VoidCallback? onEven;
  final VoidCallback? onDoubleOrRebet;
  final VoidCallback? onRemove;
  final VoidCallback? onClear;
}

class Spin2WinFrame extends StatelessWidget {
  const Spin2WinFrame({
    super.key,
    required this.data,
    this.actions = const Spin2WinFrameActions(),
    this.chipImage = spin2WinAssetChipImage,
    this.wheel,
    this.animate = true,
  });

  final Spin2WinFrameData data;

  /// Whether the signs move (a screenshot test holds them still).
  final bool animate;

  /// The wheel to draw in the wheel's column; null draws [data]'s wheel standing still.
  final Widget? wheel;
  final Spin2WinFrameActions actions;
  final ImageProvider Function(Spin2WinChip chip) chipImage;

  @override
  Widget build(BuildContext context) {
    final board = Spin2WinLayoutScope.of(context);
    return DefaultTextStyle(
      style: const TextStyle(fontFamily: kSpin2WinFont, fontWeight: FontWeight.w900, color: Color(0xFFFFFFFF)),
      child: board.isLarge ? _large(board) : _phone(),
    );
  }

  /// The phone board: the wheel's 316 dp column at the left, the panel taking the rest.
  Widget _phone() {
    return Padding(
      padding: Spin2WinLayout.phone.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: Spin2WinLayout.barHeight, child: _topBar(Spin2WinLayout.phone)),
          SizedBox(height: Spin2WinLayout.phone.gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: Spin2WinWheel.columnWidth,
                  child: _wheel(),
                ),
                SizedBox(width: Spin2WinLayout.phone.bodyGap),
                Expanded(child: _panel(Spin2WinPanelMetrics.phone)),
              ],
            ),
          ),
          SizedBox(height: Spin2WinLayout.phone.gap),
          Spin2WinHistoryStrip(tiles: data.history),
        ],
      ),
    );
  }

  /// The tablet and desktop boards: the same pieces enlarged as the design enlarges them, the wheel
  /// in its 280 x 300 box in the middle of the body's height, and the taller panel.
  Widget _large(Spin2WinLayout board) {
    const box = Spin2WinLayout.largeWheelBox;
    const shift = Spin2WinLayout.largeWheelShift;
    return Padding(
      padding: board.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: Spin2WinLayout.barHeight * board.barZoom,
            child: Spin2WinZoom(zoom: board.barZoom, child: _topBar(board)),
          ),
          SizedBox(height: board.gap),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: box.width * board.wheelZoom,
                  height: box.height * board.wheelZoom,
                  child: Spin2WinZoom(
                    zoom: board.wheelZoom,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: shift.dx,
                          top: shift.dy,
                          width: Spin2WinWheel.columnWidth,
                          height: box.height - shift.dy,
                          child: _wheel(),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: board.bodyGap),
                Expanded(
                  child: SizedBox(
                    height: double.infinity,
                    child: Spin2WinZoom(zoom: board.panelZoom, child: _panel(board.panel)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: board.gap),
          SizedBox(
            height: Spin2WinLayout.historyHeight * board.barZoom,
            child: Spin2WinZoom(zoom: board.barZoom, child: Spin2WinHistoryStrip(tiles: data.history)),
          ),
        ],
      ),
    );
  }

  Widget _topBar(Spin2WinLayout board) => Spin2WinTopBar(
        balance: data.balance,
        play: data.play,
        win: data.win,
        muted: data.muted,
        winKey: data.winKey,
        sidePadding: board.barSidePadding,
        onExit: actions.onExit,
        onRecords: actions.onRecords,
        onSound: actions.onSound,
      );

  Widget _wheel() => wheel ?? Spin2WinWheel(angle: data.wheelAngle, dome: data.dome);

  /// The betting panel, with the NO MORE BETS sign over it from the lock mark until the spin.
  Widget _panel(Spin2WinPanelMetrics metrics) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Spin2WinBetPanel(
            stakes: data.stakes,
            selectedChip: data.selectedChip,
            countdown: data.countdown,
            rebetMode: data.rebetMode,
            isLocked: data.isLocked,
            hasBets: data.hasBets,
            canAffordRebet: data.canAffordRebet,
            winningNumber: data.winningNumber,
            chipImage: chipImage,
            metrics: metrics,
            onNumber: actions.onNumber,
            onChip: actions.onChip,
            onOdd: actions.onOdd,
            onEven: actions.onEven,
            onDoubleOrRebet: actions.onDoubleOrRebet,
            onRemove: actions.onRemove,
            onClear: actions.onClear,
          ),
        ),
        if (data.noMoreBets) Center(child: Spin2WinNoMoreBets(animate: animate)),
      ],
    );
  }
}

/// Fits the design-sized [child] to the real screen: the background over the whole screen, and
/// inside the safe area (top and bottom only; the sides are edge to edge) the board [Spin2WinLayout.forScreen] picks (phone, tablet or desktop), laid
/// out at its design height and as wide as the screen's shape allows (between the board's
/// `minWidth` and `maxWidth`), then scaled to fit. A squarer screen than that allows gets the
/// design centred with background above and below; a longer one gets it centred with background
/// at the sides. The board is handed down in a [Spin2WinLayoutScope].
///
/// Inside, the phone's font-size setting has no effect, so "large font" cannot push the layout out
/// of shape.
class Spin2WinViewport extends StatelessWidget {
  const Spin2WinViewport({super.key, required this.child, this.overlay});

  final Widget child;

  /// Drawn over the design, at the same scale (coins, popups: later phases).
  final Widget? overlay;

  /// The phone board's design height and widths.
  static const double designHeight = 390;
  static const double minWidth = 760;
  static const double maxWidth = 940;

  /// The design-space size the child is laid out at for a [screen] of this size.
  static Size designSizeFor(Size screen) => Spin2WinLayout.forScreen(screen).designSizeFor(screen);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: kS2wBackground),
        // Edge to edge from side to side, as Lucky Card is: a phone's camera cut-out at the side
        // falls in the board's own margin (the EXIT button is 40 dp in) instead of leaving a blank
        // strip down one side.
        child: SafeArea(
          left: false,
          right: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screen = constraints.biggest;
              final board = Spin2WinLayout.forScreen(screen);
              final design = board.designSizeFor(screen);
              final scale = math.min(screen.width / design.width, screen.height / design.height);
              return Center(
                child: SizedBox(
                  width: design.width * scale,
                  height: design.height * scale,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox.fromSize(
                      size: design,
                      child: Spin2WinLayoutScope(
                        board: board,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(child: child),
                            if (overlay != null) Positioned.fill(child: overlay!),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
