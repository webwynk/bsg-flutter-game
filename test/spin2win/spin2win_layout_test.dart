// Spin2Win screens, Phase 7: the tablet and desktop boards (lib/widgets/spin2win/spin2win_layout.dart).
//
// Checks which board each screen gets, that the tablet and desktop boards put the wheel's hub
// exactly where the reference design does (its coin-burst centre), that every screen shape draws
// without overflowing, that taps still land on the enlarged buttons, and that popups and the coin
// burst are enlarged as the design enlarges them.

import 'package:best_smart_game/models/spin2win_board.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_coin_burst.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_dialog_frame.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_frame.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  Size screen, {
  Spin2WinFrameActions actions = const Spin2WinFrameActions(),
  Widget? overlay,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Spin2WinViewport(
        overlay: overlay,
        child: Spin2WinFrame(data: Spin2WinFrameData.sample, actions: actions, animate: false),
      ),
    ),
  ));
}

void main() {
  group('each screen gets the board the design draws for it', () {
    test('phones get the phone board, tablets the tablet board, wide big screens the desktop board', () {
      expect(Spin2WinLayout.forScreen(const Size(844, 390)), Spin2WinLayout.phone);
      expect(Spin2WinLayout.forScreen(const Size(915, 412)), Spin2WinLayout.phone);
      expect(Spin2WinLayout.forScreen(const Size(1100, 599)), Spin2WinLayout.phone);
      expect(Spin2WinLayout.forScreen(const Size(1180, 820)), Spin2WinLayout.tablet);
      expect(Spin2WinLayout.forScreen(const Size(1024, 768)), Spin2WinLayout.tablet);
      expect(Spin2WinLayout.forScreen(const Size(1366, 1024)), Spin2WinLayout.tablet);
      expect(Spin2WinLayout.forScreen(const Size(1920, 1080)), Spin2WinLayout.desktop);
      expect(Spin2WinLayout.forScreen(const Size(1440, 900)), Spin2WinLayout.desktop);
      expect(Spin2WinLayout.forScreen(const Size(2560, 1080)), Spin2WinLayout.desktop);
    });

    test("each board is laid out at its design height, as wide as the screen's shape allows", () {
      expect(Spin2WinLayout.tablet.designSizeFor(const Size(1180, 820)), const Size(1180, 820));
      expect(Spin2WinLayout.desktop.designSizeFor(const Size(1920, 1080)), const Size(1920, 1080));
      expect(Spin2WinLayout.tablet.designSizeFor(const Size(1024, 768)), const Size(1120, 820));
      expect(Spin2WinLayout.desktop.designSizeFor(const Size(2560, 1080)), const Size(2100, 1080));
      expect(Spin2WinViewport.designSizeFor(const Size(1920, 1080)), const Size(1920, 1080));
    });

    test("the wheel's hub is where the design's coins burst from on every board", () {
      expect(Spin2WinLayout.phone.hubCentre, kSpin2WinHubCentre);
      // The design's coin flash: 105 dp at (243.5, 360.5) on the tablet, 140 dp at (336, 475) on
      // the desktop.
      expect((Spin2WinLayout.tablet.hubCentre - const Offset(296, 413)).distance, lessThan(0.5));
      expect((Spin2WinLayout.desktop.hubCentre - const Offset(406, 545)).distance, lessThan(0.5));
    });
  });

  group('the tablet and desktop frames', () {
    for (final screen in const [
      Size(1180, 820),
      Size(1024, 768),
      Size(1366, 1024),
      Size(1920, 1080),
      Size(1440, 900),
      Size(2560, 1080),
    ]) {
      testWidgets('draw every piece without overflowing at ${screen.width.toInt()} x ${screen.height.toInt()}',
          (tester) async {
        await _pump(tester, screen);
        expect(tester.takeException(), isNull);
        for (var n = 0; n <= 9; n++) {
          expect(find.byKey(ValueKey('spin2win-card-$n')), findsOneWidget);
        }
        expect(find.byKey(const ValueKey('spin2win-timer')), findsOneWidget);
        expect(find.byKey(const ValueKey('spin2win-dome')), findsOneWidget);
        expect(find.text('HISTORY'), findsOneWidget);
      });
    }

    testWidgets("the tablet's wheel and panel sit where the design puts them", (tester) async {
      await _pump(tester, const Size(1180, 820));
      final hub = tester.getCenter(find.byKey(const ValueKey('spin2win-dome')));
      expect((hub - Spin2WinLayout.tablet.hubCentre).distance, lessThan(6), reason: 'hub at $hub');
      // The design's 126 dp card, enlarged 1.15 (sizes on screen, after enlarging).
      expect(tester.getRect(find.byKey(const ValueKey('spin2win-card-0'))).height, closeTo(126 * 1.15, 1));
      expect(tester.getRect(find.byKey(const ValueKey('spin2win-timer'))).width, closeTo(124 * 1.15, 1));
    });

    testWidgets("the desktop's wheel and panel sit where the design puts them", (tester) async {
      await _pump(tester, const Size(1920, 1080));
      final hub = tester.getCenter(find.byKey(const ValueKey('spin2win-dome')));
      expect((hub - Spin2WinLayout.desktop.hubCentre).distance, lessThan(8), reason: 'hub at $hub');
      expect(tester.getRect(find.byKey(const ValueKey('spin2win-card-0'))).height, closeTo(104 * 1.6, 1));
    });

    testWidgets('taps land on the enlarged cards, chips and buttons', (tester) async {
      final numbers = <int>[];
      final chips = <Spin2WinChip>[];
      var odd = 0;
      var records = 0;
      await _pump(
        tester,
        const Size(1180, 820),
        actions: Spin2WinFrameActions(
          onNumber: numbers.add,
          onChip: chips.add,
          onOdd: () => odd++,
          onRecords: () => records++,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('spin2win-card-7')));
      await tester.tap(find.byKey(const ValueKey('spin2win-chip-100')));
      await tester.tap(find.byKey(const ValueKey('spin2win-odd')));
      await tester.tap(find.byKey(const ValueKey('spin2win-records')));
      expect(numbers, [7]);
      expect(chips, [Spin2WinChip.hundred]);
      expect(odd, 1);
      expect(records, 1);
    });
  });

  group('popups and the coin burst are enlarged as the design enlarges them', () {
    testWidgets('a dialog is drawn 1.45 times its size on the tablet and 1.9 on the desktop', (tester) async {
      for (final (screen, zoom) in const [(Size(844, 390), 1.0), (Size(1180, 820), 1.45), (Size(1920, 1080), 1.9)]) {
        tester.view.physicalSize = screen;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const MaterialApp(
          home: Spin2WinDialogPage(child: SizedBox(key: ValueKey('box'), width: 100, height: 100)),
        ));
        expect(tester.getRect(find.byKey(const ValueKey('box'))).width, closeTo(100 * zoom, 0.5), reason: '$screen');
      }
      tester.view.reset();
    });

    testWidgets("the coins burst from the tablet's hub, 1.5 times bigger", (tester) async {
      await _pump(tester, const Size(1180, 820),
          overlay: const Spin2WinAtHub(child: SizedBox.expand(key: ValueKey('burst'))));
      final transform = tester.widget<Transform>(
        find.descendant(of: find.byType(Spin2WinAtHub), matching: find.byType(Transform)).first,
      );
      final moved = MatrixUtils.transformPoint(transform.transform, kSpin2WinHubCentre);
      expect((moved - Spin2WinLayout.tablet.hubCentre).distance, lessThan(0.01));
      expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.5, 0.001));
    });

    testWidgets('on the phone the coin burst is drawn as it is', (tester) async {
      await _pump(tester, const Size(844, 390), overlay: const Spin2WinAtHub(child: SizedBox.expand()));
      expect(find.descendant(of: find.byType(Spin2WinAtHub), matching: find.byType(Transform)), findsNothing);
    });
  });
}
