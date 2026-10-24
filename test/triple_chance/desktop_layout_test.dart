// Layout tests for the Triple Chance desktop screen.
//
// They build the real desktop layout with the real providers and check where
// the parts are (top bar, wheel, the three boards, chip tray, four buttons,
// results table, PLAY / WIN box), that the layout scales and centres in any
// window, that touches reach the boards, that the win popup and coin fountain
// follow the layout, and that the screen-size rule picks the desktop layout
// ahead of the tablet one. No images are compared; every check is a position,
// a size or a value.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
// Reached through supabase_flutter, which the app depends on; the test only
// needs its in-memory stand-in so the Supabase client can start.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:best_smart_game/models/spin_result_model.dart';
import 'package:best_smart_game/providers/auth_provider.dart';
import 'package:best_smart_game/providers/game_provider.dart';
import 'package:best_smart_game/utils/device_type.dart';
import 'package:best_smart_game/widgets/controls/exit_corner_button.dart';
import 'package:best_smart_game/widgets/desktop/desktop_coin_fountain.dart';
import 'package:best_smart_game/widgets/desktop/desktop_doubles_board.dart';
import 'package:best_smart_game/widgets/desktop/desktop_game_layout.dart';
import 'package:best_smart_game/widgets/desktop/desktop_result_overlay.dart';
import 'package:best_smart_game/widgets/desktop/desktop_results_table.dart';
import 'package:best_smart_game/widgets/desktop/desktop_singles_board.dart';
import 'package:best_smart_game/widgets/desktop/desktop_stats_box.dart';
import 'package:best_smart_game/widgets/desktop/desktop_top_bar.dart';
import 'package:best_smart_game/widgets/desktop/desktop_triples_board.dart';
import 'package:best_smart_game/widgets/panels/grid_cells.dart';
import 'package:best_smart_game/widgets/tablet/tablet_chip_row.dart';
import 'package:best_smart_game/widgets/wheel/wheel_widget.dart';

// The window sizes the layout is checked at: the design size itself, a common
// laptop, a full-HD monitor, and a wide window (side bars each side).
const _design = Size(1280, 720);
const _laptop = Size(1366, 768);
const _fullHd = Size(1920, 1080);
const _wideWindow = Size(1600, 720);

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
  }
  await loader.load();
}

void _noop() {}

/// The real game with a few values fixed, so the table, the PLAY / WIN box and
/// the win popup can be checked without playing a round.
class _FixedGame extends GameProvider {
  final List<SpinResult> _hist;
  final SpinResult? _last;
  final int _bet;
  _FixedGame({List<SpinResult> history = const [], SpinResult? last, int bet = 0})
      : _hist = history,
        _last = last,
        _bet = bet;

  @override
  List<SpinResult> get globalHistory => _hist;
  @override
  SpinResult? get lastResult => _last;
  @override
  SpinResult? get lastWinBoxResult => _last;
  @override
  int get totalBet => _bet;
}

SpinResult _draw(String id, int r, int g, int b, {int win = 0}) => SpinResult(
      id: id,
      red: r,
      green: g,
      black: b,
      mode: 'global',
      selections: const [],
      chipValue: 10,
      won: win > 0,
      deductedAmount: 0,
      winAmount: win,
      tripleWinAmount: win,
      netChange: win,
      createdAt: DateTime(2026),
    );

Widget _app(Widget body, {GameProvider? game}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<GameProvider>(create: (_) => game ?? GameProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Colors.black, body: body),
      ),
    );

Future<void> _setScreen(WidgetTester tester, Size size) async {
  await tester.runAsync(() async {
    await _loadFont('Oswald', [
      'assets/fonts/Oswald-Regular.ttf',
      'assets/fonts/Oswald-Medium.ttf',
      'assets/fonts/Oswald-SemiBold.ttf',
      'assets/fonts/Oswald-Bold.ttf',
    ]);
    await _loadFont('DMSans', [
      'assets/fonts/DMSans-Regular.ttf',
      'assets/fonts/DMSans-Medium.ttf',
      'assets/fonts/DMSans-Bold.ttf',
      'assets/fonts/DMSans-ExtraBold.ttf',
      'assets/fonts/DMSans-Black.ttf',
    ]);
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Where a design-space rectangle (1280 x 720) lands on a window of [size].
Rect _onScreen(Size size, double left, double top, double width, double height) {
  final s = DesktopGameLayout.scaleFor(size);
  final ox = (size.width - 1280 * s) / 2;
  final oy = (size.height - 720 * s) / 2;
  return Rect.fromLTWH(ox + left * s, oy + top * s, width * s, height * s);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // A throwaway local address and key: the providers expect the Supabase
    // client to exist; nothing here talks to a real server.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      // ignore: deprecated_member_use
      anonKey: 'test-key-not-real',
    );
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('which windows get the desktop layout', () {
    test('windows at least 1280 x 720 do, including big tablets and emulators', () {
      expect(isDesktopScreen(_design), isTrue);
      expect(isDesktopScreen(_laptop), isTrue);
      expect(isDesktopScreen(_fullHd), isTrue);
      expect(isDesktopScreen(const Size(2560, 1440)), isTrue);
      expect(isDesktopScreen(const Size(1280, 800)), isTrue); // a big tablet
      // ...and such a tablet is also tablet-sized: the game screen checks the
      // desktop rule first, so it gets the desktop layout.
      expect(isTabletScreen(const Size(1280, 800)), isTrue);
    });

    test('anything smaller keeps the tablet or phone layout', () {
      expect(isDesktopScreen(const Size(1279, 720)), isFalse);
      expect(isDesktopScreen(const Size(1280, 719)), isFalse);
      expect(isDesktopScreen(const Size(1024, 768)), isFalse);
      expect(isDesktopScreen(const Size(844, 390)), isFalse);
      expect(isDesktopScreen(const Size(800, 1280)), isFalse); // portrait tablet
    });
  });

  group('desktop layout numbers', () {
    test('the layout is scaled to fit the whole window', () {
      expect(DesktopGameLayout.scaleFor(_design), 1.0);
      expect(DesktopGameLayout.scaleFor(_fullHd), 1.5);
      expect(DesktopGameLayout.scaleFor(_wideWindow), 1.0); // height limits it
      expect(DesktopGameLayout.scaleFor(const Size(1280, 1000)), 1.0); // width limits it
    });

    test('the wheel centre follows the scaled, centred layout', () {
      var f = DesktopGameLayout.wheelCenterFraction(_design);
      expect(f.dx, closeTo(635 / 1280, 1e-9));
      expect(f.dy, closeTo(288 / 720, 1e-9));
      f = DesktopGameLayout.wheelCenterFraction(_fullHd);
      expect(f.dx, closeTo(635 / 1280, 1e-9));
      expect(f.dy, closeTo(288 / 720, 1e-9));
      f = DesktopGameLayout.wheelCenterFraction(_wideWindow); // 160 px bars each side
      expect(f.dx, closeTo((160 + 635) / 1600, 1e-9));
      f = DesktopGameLayout.wheelCenterFraction(const Size(1280, 1000)); // 140 px bars top and bottom
      expect(f.dy, closeTo((140 + 288) / 1000, 1e-9));
    });

    test('win effects grow with the layout', () {
      expect(DesktopGameLayout.overlayScale(_design), 1.5);
      expect(DesktopGameLayout.overlayScale(_fullHd), closeTo(2.25, 1e-9));
    });
  });

  for (final size in [_design, _laptop, _fullHd, _wideWindow]) {
    final label = '${size.width.toInt()} x ${size.height.toInt()}';

    testWidgets('desktop layout at $label puts every part in its place', (tester) async {
      await _setScreen(tester, size);
      await tester.pumpWidget(_app(const DesktopGameLayout(onSpin: _noop)));
      await tester.pump(const Duration(milliseconds: 500));
      final s = DesktopGameLayout.scaleFor(size);
      final window = Offset.zero & size;

      // The layout fills the window.
      expect(tester.getRect(find.byType(DesktopGameLayout)), window);

      // Boards: where the design puts them, on the left and right of the wheel.
      final doubles = tester.getRect(find.byType(DesktopDoublesBoard));
      final triples = tester.getRect(find.byType(DesktopTriplesBoard));
      final singles = tester.getRect(find.byType(DesktopSinglesBoard));
      expect(doubles.left, closeTo(_onScreen(size, 10, 74, 380, 0).left, 1));
      expect(doubles.width, closeTo(380 * s, 1));
      expect(doubles.top, closeTo(_onScreen(size, 10, 74, 380, 0).top, 1));
      expect(triples.left, closeTo(_onScreen(size, 890, 74, 380, 0).left, 1));
      expect(triples.width, closeTo(380 * s, 1));
      expect(singles.left, closeTo(_onScreen(size, 430, 508, 410, 0).left, 1));
      expect(singles.width, closeTo(410 * s, 1));

      // All three boards are complete: 100 doubles, 100 triples (one page) and
      // 10 singles, ten page tabs on the Triples board.
      Finder cellsIn(Type board) => find.descendant(of: find.byType(board), matching: find.byType(NumberCell));
      expect(cellsIn(DesktopDoublesBoard), findsNWidgets(100));
      expect(cellsIn(DesktopTriplesBoard), findsNWidgets(100));
      expect(cellsIn(DesktopSinglesBoard), findsNWidgets(10));
      for (final t in ['000', '100', '200', '300', '400', '500', '600', '700', '800', '900']) {
        expect(find.descendant(of: find.byType(DesktopTriplesBoard), matching: find.text(t)), findsWidgets, reason: 'tab $t');
      }

      // The wheel sits at its design spot, drawn 440 design units wide.
      final wheel = tester.getRect(find.byType(WheelWidget));
      final wheelSpot = _onScreen(size, 635 - 220, 288 - 220, 440, 440);
      expect(wheel.center.dx, closeTo(wheelSpot.center.dx, 2));
      expect(wheel.center.dy, closeTo(wheelSpot.center.dy, 2));
      expect(wheel.width, closeTo(440 * s, 2));
      // ...between the two big boards, above the Singles row.
      expect(wheel.left, greaterThanOrEqualTo(doubles.right - 1));
      expect(wheel.right, lessThanOrEqualTo(triples.left + 1));
      expect(wheel.bottom, lessThanOrEqualTo(singles.top + 1));

      // Top bar: exit key at the left, coins, countdown, status, info icon at the right.
      final top = _onScreen(size, 0, 0, 1280, 64);
      final exit = tester.getRect(find.byType(ExitCornerButton));
      expect(exit.left, lessThan(top.left + 60 * s));
      expect(exit.bottom, lessThan(top.bottom));
      final bar = find.byType(DesktopTopBar);
      final status = tester.getRect(find.descendant(of: bar, matching: find.text('Place your chips')));
      final seconds = tester.getRect(find.descendant(of: bar, matching: find.textContaining('SECONDS')));
      final info = tester.getRect(find.descendant(of: bar, matching: find.text('i')));
      expect(seconds.center.dx, lessThan(status.center.dx));
      expect(status.center.dx, lessThan(info.center.dx));
      expect(info.right, lessThanOrEqualTo(top.right));
      expect(find.descendant(of: bar, matching: find.text('90')), findsOneWidget);
      // INFO is only that icon: there is no INFO button among the action buttons.
      expect(find.text('INFO'), findsNothing);

      // Chips: five in one row, none overlapping, inside the tray at the bottom middle.
      final chips = find.descendant(of: find.byType(TabletChipRow), matching: find.byType(AnimatedContainer));
      expect(chips, findsNWidgets(5));
      final chipRects = [for (var i = 0; i < 5; i++) tester.getRect(chips.at(i))];
      for (var i = 1; i < 5; i++) {
        expect((chipRects[i].center.dy - chipRects[0].center.dy).abs(), lessThan(3 * s));
        expect(chipRects[i].left, greaterThanOrEqualTo(chipRects[i - 1].right - 0.5));
      }
      final tray = _onScreen(size, 450, 614, 370, 92);
      expect(chipRects.first.left, greaterThanOrEqualTo(tray.left - 1));
      expect(chipRects.last.right, lessThanOrEqualTo(tray.right + 1));
      expect(chipRects.first.top, greaterThanOrEqualTo(singles.bottom - 1));

      // Buttons: a 2 x 2 block at the bottom right, DOUBLE UP and REPEAT above CLEAR and REMOVE.
      Rect button(String t) => tester.getRect(find.text(t));
      final dbl = button('DOUBLE UP'), repeat = button('REPEAT'), clear = button('CLEAR'), remove = button('REMOVE');
      expect((dbl.center.dy - repeat.center.dy).abs(), lessThan(1));
      expect((clear.center.dy - remove.center.dy).abs(), lessThan(1));
      expect(repeat.center.dx, greaterThan(dbl.center.dx));
      expect(remove.center.dx, greaterThan(clear.center.dx));
      expect((dbl.center.dx - clear.center.dx).abs(), lessThan(1));
      expect(clear.center.dy, greaterThan(dbl.center.dy));
      expect(dbl.left, greaterThan(chipRects.last.right));
      expect(dbl.top, greaterThan(triples.bottom));

      // Results table and PLAY / WIN box: bottom left, under the Doubles board.
      final table = tester.getRect(find.byType(DesktopResultsTable));
      final stats = tester.getRect(find.byType(DesktopStatsBox));
      expect(table.left, closeTo(doubles.left, 1));
      expect(table.width, closeTo(doubles.width, 1));
      expect(table.top, greaterThan(doubles.bottom));
      expect(stats.top, greaterThan(table.bottom));
      expect(stats.bottom, lessThanOrEqualTo(window.bottom));
      for (final t in ['TRIPLE', 'DOUBLE', 'SINGLE']) {
        expect(find.descendant(of: find.byType(DesktopResultsTable), matching: find.text(t)), findsOneWidget);
      }
      expect(find.descendant(of: find.byType(DesktopStatsBox), matching: find.text('PLAY')), findsOneWidget);
      expect(find.descendant(of: find.byType(DesktopStatsBox), matching: find.text('WIN')), findsOneWidget);

      // Nothing overlaps anything else, and nothing leaves the window.
      final blocks = {
        'doubles': doubles,
        'triples': triples,
        'singles': singles,
        'table': table,
        'stats': stats,
        'tray': tester.getRect(find.byType(TabletChipRow)),
        'buttons': dbl.expandToInclude(repeat).expandToInclude(clear).expandToInclude(remove),
      };
      final names = blocks.keys.toList();
      for (var i = 0; i < names.length; i++) {
        expect(window.contains(blocks[names[i]]!.topLeft) && window.contains(blocks[names[i]]!.bottomRight), isTrue, reason: '${names[i]} inside the window');
        for (var j = i + 1; j < names.length; j++) {
          expect(blocks[names[i]]!.overlaps(blocks[names[j]]!), isFalse, reason: '${names[i]} overlaps ${names[j]}');
        }
      }

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tapping a page tab shows that hundred of the Triples board', (tester) async {
    await _setScreen(tester, _design);
    await tester.pumpWidget(_app(const DesktopGameLayout(onSpin: _noop)));
    await tester.pump(const Duration(milliseconds: 500));
    final game = Provider.of<GameProvider>(tester.element(find.byType(DesktopGameLayout)), listen: false);
    Finder inTriples(String t) => find.descendant(of: find.byType(DesktopTriplesBoard), matching: find.text(t));

    expect(game.triplePage, 0);
    expect(inTriples('099'), findsOneWidget);
    await tester.tap(inTriples('300').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.triplePage, 3);
    expect(inTriples('300'), findsNWidgets(2)); // the tab and the first cell
    expect(inTriples('399'), findsOneWidget);
    expect(inTriples('099'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('taps on the boards reach the game, scaled and unscaled', (tester) async {
    for (final size in [_design, _fullHd]) {
      await _setScreen(tester, size);
      await tester.pumpWidget(_app(const DesktopGameLayout(onSpin: _noop)));
      await tester.pump(const Duration(milliseconds: 500));
      final game = Provider.of<GameProvider>(tester.element(find.byType(DesktopGameLayout)), listen: false);
      Finder cells(Type board) => find.descendant(of: find.byType(board), matching: find.byType(NumberCell));

      // With no coins the game refuses a stake with its own message; getting
      // that message means the tap landed on the cell and made the bet call.
      for (final board in [DesktopDoublesBoard, DesktopTriplesBoard, DesktopSinglesBoard]) {
        game.clearError();
        await tester.tapAt(tester.getRect(cells(board).at(7)).center);
        await tester.pump(const Duration(milliseconds: 200));
        expect(game.error, 'INSUFFICIENT_COINS', reason: '$board at ${size.width.toInt()}');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the wheel keeps its state when the window is resized', (tester) async {
    await _setScreen(tester, _design);
    final wheelKey = GlobalKey();
    await tester.pumpWidget(_app(DesktopGameLayout(onSpin: _noop, wheelKey: wheelKey)));
    await tester.pump(const Duration(milliseconds: 500));
    final before = wheelKey.currentState;
    expect(before, isNotNull);

    tester.view.physicalSize = _fullHd;
    await tester.pump(const Duration(milliseconds: 300));
    expect(wheelKey.currentState, same(before));
    expect(tester.getRect(find.byType(WheelWidget)).width, closeTo(440 * 1.5, 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the results table shows the last six draws, newest first', (tester) async {
    await _setScreen(tester, _design);
    final game = _FixedGame(
      history: [
        _draw('a', 7, 3, 9),
        _draw('b', 0, 4, 2),
        _draw('c', 1, 1, 1),
        _draw('d', 9, 8, 7),
        _draw('e', 5, 0, 6),
        _draw('f', 2, 2, 4),
        _draw('g', 3, 3, 3), // the 7th: not shown
      ],
      last: _draw('a', 7, 3, 9, win: 1250),
      bet: 340,
    );
    await tester.pumpWidget(_app(const DesktopGameLayout(onSpin: _noop), game: game));
    await tester.pump(const Duration(milliseconds: 500));
    Finder inTable(String t) => find.descendant(of: find.byType(DesktopResultsTable), matching: find.text(t));

    // Triple = red + green + black, Double = green + black, Single = black.
    for (final t in ['739', '39', '9', '042', '42', '2', '111', '987', '506', '224']) {
      expect(inTable(t), findsWidgets, reason: t);
    }
    expect(inTable('333'), findsNothing);
    expect(tester.getRect(inTable('739')).left, lessThan(tester.getRect(inTable('042')).left));
    expect(tester.getRect(inTable('042')).left, lessThan(tester.getRect(inTable('111')).left));

    // PLAY and WIN, from the left of their halves.
    final box = tester.getRect(find.byType(DesktopStatsBox));
    final play = tester.getRect(find.descendant(of: find.byType(DesktopStatsBox), matching: find.text('340')));
    final win = tester.getRect(find.descendant(of: find.byType(DesktopStatsBox), matching: find.text('+1250')));
    expect(play.left, lessThan(box.left + 120));
    expect(win.left, greaterThan(box.center.dx));
    expect(win.left, lessThan(box.center.dx + 120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no draws yet the table shows dashes and WIN is +0', (tester) async {
    await _setScreen(tester, _design);
    await tester.pumpWidget(_app(const DesktopGameLayout(onSpin: _noop), game: _FixedGame(history: [_draw('a', 6, 1, 8)])));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.descendant(of: find.byType(DesktopResultsTable), matching: find.text('618')), findsOneWidget);
    expect(find.descendant(of: find.byType(DesktopResultsTable), matching: find.text('-')), findsNWidgets(15));
    expect(find.descendant(of: find.byType(DesktopStatsBox), matching: find.text('+0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the win popup is centred on the window and grows with the layout', (tester) async {
    final amountHeights = <double>[];
    for (final size in [_design, _fullHd, _wideWindow]) {
      await _setScreen(tester, size);
      final game = _FixedGame(last: _draw('a', 7, 3, 9, win: 4500));
      await tester.pumpWidget(_app(const DesktopResultOverlay(), game: game));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      final amount = find.descendant(of: find.byType(DesktopResultOverlay), matching: find.text('4500')).first;
      final r = tester.getRect(amount);
      expect((r.center.dx - size.width / 2).abs(), lessThan(size.width * 0.02), reason: 'centred at ${size.width.toInt()}');
      expect((r.center.dy - size.height / 2).abs(), lessThan(size.height * 0.15));
      amountHeights.add(r.height);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    // 1920 x 1080 enlarges the layout 1.5 times more than 1280 x 720 does, and the popup with it.
    expect(amountHeights[1] / amountHeights[0], closeTo(1.5, 0.05));
    // 1600 x 720 is limited by its height: the same size as 1280 x 720.
    expect(amountHeights[2] / amountHeights[0], closeTo(1.0, 0.05));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the coin fountain plays and ends without leaving a ticker running', (tester) async {
    await _setScreen(tester, _wideWindow);
    await tester.pumpWidget(_app(const Stack(children: [
      DesktopCoinFountain(),
    ])));
    // Mid-pour, then well past the end of the pour and the flight.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 8));
    // Unmounting (as the game screen does when showCoinFx ends) disposes it
    // cleanly: a ticker left running would fail the test at its end.
    await tester.pumpWidget(_app(const SizedBox.shrink()));
    expect(tester.takeException(), isNull);
  });
}
