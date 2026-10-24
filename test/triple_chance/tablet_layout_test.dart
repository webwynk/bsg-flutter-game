// Layout tests for the Triple Chance tablet screen.
//
// They build the real tablet layout with the real providers and check where
// the parts are (zones, wheel, status pill, exit key, chip row, 2 x 2 buttons,
// countdown box), that touches reach the scaled widgets, that the screen-size
// rule picks the right layout, and that the phone's right panel keeps its own
// arrangement. No images are compared; every check is a position or a size.
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
import 'package:best_smart_game/providers/auth_provider.dart';
import 'package:best_smart_game/providers/game_provider.dart';
import 'package:best_smart_game/utils/device_type.dart';
import 'package:best_smart_game/widgets/controls/exit_corner_button.dart';
import 'package:best_smart_game/widgets/controls/right_panel.dart';
import 'package:best_smart_game/widgets/tablet/scaled_box.dart';
import 'package:best_smart_game/widgets/tablet/tablet_chip_row.dart';
import 'package:best_smart_game/widgets/tablet/tablet_game_layout.dart';
import 'package:best_smart_game/widgets/tablet/tablet_right_panel.dart';
import 'package:best_smart_game/widgets/tablet/tablet_status_pill.dart';
import 'package:best_smart_game/widgets/wheel/wheel_widget.dart';

const _wide = Size(1280, 800); // 16:10
const _squarish = Size(1024, 768); // 4:3

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
  }
  await loader.load();
}

void _noop() {}

Widget _app(Widget body) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
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

  group('which screens get the tablet layout', () {
    test('phones do not', () {
      expect(isTabletScreen(const Size(844, 390)), isFalse);
      expect(isTabletScreen(const Size(932, 430)), isFalse);
      expect(isTabletScreen(const Size(640, 360)), isFalse);
      expect(isTabletScreen(const Size(390, 844)), isFalse);
    });

    test('tablets do, in either direction', () {
      expect(isTabletScreen(_wide), isTrue);
      expect(isTabletScreen(_squarish), isTrue);
      expect(isTabletScreen(const Size(800, 1280)), isTrue);
      expect(isTabletScreen(const Size(600, 800)), isTrue);
    });

    test('near misses do not', () {
      expect(isTabletScreen(const Size(599, 1000)), isFalse);
      expect(isTabletScreen(const Size(640, 640)), isFalse);
      expect(isTabletScreen(const Size(700, 799)), isFalse);
    });
  });

  group('tablet layout numbers', () {
    test('zone shares follow the screen shape', () {
      expect(TabletGameLayout.zoneFractions(_wide), (0.20, 0.30));
      expect(TabletGameLayout.zoneFractions(_squarish), (0.22, 0.32));
    });

    test('the wheel is centred between the zones on both shapes', () {
      expect(TabletGameLayout.wheelCenterX(_wide), closeTo(0.45, 1e-9));
      expect(TabletGameLayout.wheelCenterX(_squarish), closeTo(0.45, 1e-9));
    });

    test('win effects grow with the screen, from 1.0 up to 1.5', () {
      expect(TabletGameLayout.overlayScale(const Size(800, 600)), 1.0);
      expect(TabletGameLayout.overlayScale(_squarish), closeTo(1.213, 0.01));
      expect(TabletGameLayout.overlayScale(_wide), closeTo(1.5, 0.02));
      expect(TabletGameLayout.overlayScale(const Size(2560, 1440)), 1.5);
    });
  });

  testWidgets('ScaledBox draws bigger and touches land where they are drawn', (tester) async {
    var taps = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: ScaledBox(
          designWidth: 100,
          designHeight: 50,
          scale: 2,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ));
    expect(tester.getSize(find.byType(ScaledBox)), const Size(200, 100));
    await tester.tapAt(const Offset(190, 90)); // inside the drawn box, outside the design box
    expect(taps, 1);
    await tester.tapAt(const Offset(210, 90)); // outside the drawn box
    expect(taps, 1);
  });

  for (final size in [_wide, _squarish]) {
    final label = '${size.width.toInt()} x ${size.height.toInt()}';

    testWidgets('tablet layout at $label puts every part in its place', (tester) async {
      await _setScreen(tester, size);
      await tester.pumpWidget(_app(const TabletGameLayout(onSpin: _noop)));
      await tester.pump(const Duration(milliseconds: 500));

      final (lf, rf) = TabletGameLayout.zoneFractions(size);
      final leftEdge = size.width * lf;
      final rightEdge = size.width * (1 - rf);
      final centreX = size.width * TabletGameLayout.wheelCenterX(size);

      // The layout fills the screen.
      expect(tester.getRect(find.byType(TabletGameLayout)), Offset.zero & size);

      // Right panel: exactly the right zone.
      final panel = tester.getRect(find.byType(TabletRightPanel));
      expect(panel.left, closeTo(rightEdge, 1));
      expect(panel.right, closeTo(size.width, 1));
      expect(panel.height, closeTo(size.height, 1));

      // Left tabs: all three inside the left zone, side by side.
      final single = tester.getRect(find.text('SINGLE'));
      final double_ = tester.getRect(find.descendant(of: find.byType(TabletGameLayout), matching: find.text('DOUBLE')).first);
      final triple = tester.getRect(find.text('TRIPLE'));
      expect(single.center.dx < double_.center.dx && double_.center.dx < triple.center.dx, isTrue);
      expect(triple.right, lessThan(leftEdge + 1));

      // Wheel: centred between the zones, vertically centred, as big as the space allows.
      final wheel = tester.getRect(find.byType(WheelWidget));
      expect(wheel.center.dx, closeTo(centreX, 2));
      expect(wheel.center.dy, closeTo(size.height / 2, 2));
      expect(wheel.width, closeTo((rightEdge - leftEdge).clamp(0, size.height), 1));

      // Status pill: above the wheel, centred on it.
      final pill = tester.getRect(find.byType(TabletStatusPill));
      expect(pill.center.dx, closeTo(centreX, 2));
      expect(pill.bottom, lessThan(wheel.center.dy - wheel.height * 0.25));

      // Exit key: at the top-right corner of the wheel area.
      final exit = tester.getRect(find.byType(ExitCornerButton));
      expect(exit.right, lessThan(rightEdge));
      expect(exit.right, greaterThan(rightEdge - 80));
      expect(exit.top, lessThan(30));

      // Chips: five in one row, none overlapping, inside the right panel.
      final chips = find.descendant(of: find.byType(TabletChipRow), matching: find.byType(AnimatedContainer));
      expect(chips, findsNWidgets(5));
      final chipRects = [for (var i = 0; i < 5; i++) tester.getRect(chips.at(i))];
      for (var i = 1; i < 5; i++) {
        expect((chipRects[i].center.dy - chipRects[0].center.dy).abs(), lessThan(3));
        expect(chipRects[i].left, greaterThanOrEqualTo(chipRects[i - 1].right - 0.5));
      }
      expect(chipRects.first.left, greaterThanOrEqualTo(panel.left));
      expect(chipRects.last.right, lessThanOrEqualTo(panel.right));

      // Buttons: a 2 x 2 block, INFO and DOUBLE above CLEAR and REMOVE.
      Rect button(String t) => tester.getRect(find.descendant(of: find.byType(TabletRightPanel), matching: find.text(t)));
      final info = button('INFO'), dbl = button('DOUBLE'), clear = button('CLEAR'), remove = button('REMOVE');
      expect((info.center.dy - dbl.center.dy).abs(), lessThan(1));
      expect((clear.center.dy - remove.center.dy).abs(), lessThan(1));
      expect(dbl.center.dx, greaterThan(info.center.dx));
      expect(remove.center.dx, greaterThan(clear.center.dx));
      expect(clear.center.dy, greaterThan(info.center.dy));
      expect(info.center.dy, greaterThan(chipRects.first.bottom));

      // Countdown box: below the buttons, inside the screen, and tall.
      final countdown = tester.getRect(find.text('SECONDS LEFT'));
      expect(countdown.center.dy, greaterThan(remove.center.dy));
      expect(countdown.bottom, lessThanOrEqualTo(size.height));
      final number = tester.getRect(find.descendant(of: find.byType(TabletRightPanel), matching: find.text('90')).first);
      expect(number.height, greaterThan(40));

      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a tab at $label opens its grid through the scaled box', (tester) async {
      await _setScreen(tester, size);
      await tester.pumpWidget(_app(const TabletGameLayout(onSpin: _noop)));
      await tester.pump(const Duration(milliseconds: 500));
      final game = Provider.of<GameProvider>(tester.element(find.byType(TabletGameLayout)), listen: false);

      expect(game.isDrawerOpen, isFalse);
      await tester.tap(find.text('SINGLE'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(game.isDrawerOpen, isTrue);
      expect(game.mode, 'single');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the phone right panel keeps its stacked buttons', (tester) async {
    await _setScreen(tester, const Size(844, 390));
    await tester.pumpWidget(_app(Align(
      alignment: Alignment.centerRight,
      child: SizedBox(width: 844 * 0.28, height: 390, child: RightControlPanel(onSpin: _noop)),
    )));
    await tester.pump(const Duration(milliseconds: 400));

    final info = tester.getRect(find.text('INFO'));
    final dbl = tester.getRect(find.text('DOUBLE'));
    final clear = tester.getRect(find.text('CLEAR'));
    final remove = tester.getRect(find.text('REMOVE'));
    expect(info.center.dy < dbl.center.dy && dbl.center.dy < clear.center.dy && clear.center.dy < remove.center.dy, isTrue);
    expect((info.center.dx - remove.center.dx).abs(), lessThan(1));
    tester.takeException();
  });
}
