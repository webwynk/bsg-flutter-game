// Spin2Win screens, Phase 3: the wheel spin (lib/widgets/spin2win/spin2win_wheel_spin.dart, and the
// wheel's still frame in spin2win_wheel.dart).
//
// The spin is checked on its own (4 seconds, lands on the number, shuffles the bonus, tells the game
// once), then on the whole screen over the simulated server, where nothing but the wheel itself
// reports the landing.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:best_smart_game/providers/spin2win_provider.dart';
import 'package:best_smart_game/screens/spin2win_screen.dart';
import 'package:best_smart_game/services/spin2win_sound.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_palette.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_wheel_spin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_alerts.dart';
import 'fake_sound.dart';
import 'provider_rig.dart';

/// The face's turn now, in degrees.
double _angleFromMatrix(WidgetTester tester) {
  final m = tester.widget<Transform>(find.byKey(const ValueKey('spin2win-wheel-face'))).transform;
  return math.atan2(m.entry(1, 0), m.entry(0, 0)) * 180 / math.pi;
}

/// Which number is under the pointer for a face turned [angle] degrees.
int _numberUnderPointer(double angle) {
  final k = ((-angle / 36).round() % 10 + 10) % 10;
  return kSpin2WinWheelOrder[k];
}

String _text(WidgetTester tester, String key) => tester
    .widgetList<Text>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text), matchRoot: true))
    .map((t) => t.data ?? '')
    .toSet()
    .join(' ');

/// A 1 x 1 transparent PNG, standing in for the chip pictures.
final Uint8List _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class _Host extends StatefulWidget {
  const _Host({required this.cue, required this.onLanded});

  final Spin2WinWheelCue cue;
  final VoidCallback onLanded;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Spin2WinWheelCue cue = widget.cue;

  void set(Spin2WinWheelCue next) => setState(() => cue = next);

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 316,
            height: 274,
            child: Spin2WinSpinningWheel(cue: cue, onLanded: widget.onLanded),
          ),
        ),
      );
}

void main() {
  group('where a spin ends', () {
    test('the winning number is under the pointer, after at least 6 whole turns', () {
      for (final from in [0.0, -36.0, 123.4, -1000.0, 7200.0]) {
        for (final n in kSpin2WinWheelOrder) {
          final end = spin2WinSpinEnd(from, n);
          expect(_numberUnderPointer(end), n, reason: 'from $from to $n');
          expect(end - from, greaterThanOrEqualTo(360.0 * 6 - 18));
          expect(end - from, lessThan(360.0 * 7 + 18));
        }
      }
    });

    test('standing still on a number never moves the wheel a whole turn', () {
      expect(spin2WinNearestAngle(0, 1), 0);
      expect(spin2WinNearestAngle(2160, 1), 2160);
      expect(spin2WinNearestAngle(2165, 2), 2124);
      expect(_numberUnderPointer(spin2WinNearestAngle(-500, 0)), 0);
    });
  });

  group('the smooth stop (Hasan, 2026-10-25: no crawl at the end, the number snaps in)', () {
    const distance = 2340.0; // 6 turns and a half
    double remainingAt(int ms) => distance * (1 - spin2WinSpinProgress(ms / 4000, distance));

    test('it starts at 0, ends exactly on the number at 4 s, and never turns backwards', () {
      expect(spin2WinSpinProgress(0, distance), 0);
      expect(spin2WinSpinProgress(1, distance), 1);
      var last = 0.0;
      for (var ms = 0; ms <= 4000; ms += 10) {
        final p = spin2WinSpinProgress(ms / 4000, distance);
        expect(p, greaterThanOrEqualTo(last));
        last = p;
      }
    });

    test('it is still turning at about 180 degrees a second when the number arrives', () {
      final speed = (remainingAt(3990) - remainingAt(4000)) / 0.01;
      expect(speed, closeTo(kSpin2WinArriveSpeed, 10));
    });

    test('the last segment takes about 0.2 s (the old ease took 1.1 s)', () {
      final lastSegmentFrom = List.generate(4001, (ms) => ms).firstWhere((ms) => remainingAt(ms) < 36);
      expect(4000 - lastSegmentFrom, inInclusiveRange(150, 260));
    });

    test('the snap goes a few degrees past the number and settles back within 0.35 s', () {
      final offsets = [for (var ms = 0; ms <= 350; ms += 5) spin2WinSettleOffset(ms / 1000)];
      expect(offsets.first, 0);
      expect(offsets.reduce(math.max), inInclusiveRange(2.0, 4.5));
      expect(spin2WinSettleOffset(0.35).abs(), lessThan(0.2));
    });
  });

  group('the spin', () {
    const resting = Spin2WinWheelCue(restNumber: 1);
    const spinning = Spin2WinWheelCue(restNumber: 1, spinKey: 'r-1', target: 7, targetBonus: 4);

    testWidgets('a result turns the wheel for 4 s, shuffling the bonus, then shows the number once', (tester) async {
      var landed = 0;
      await tester.pumpWidget(_Host(cue: resting, onLanded: () => landed++));
      expect(_text(tester, 'spin2win-dome-number'), '1');
      tester.state<_HostState>(find.byType(_Host)).set(spinning);
      await tester.pump();

      final bonuses = <String>{};
      final angles = <double>[];
      for (var ms = 0; ms < 3800; ms += 100) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('BONUS'), findsOneWidget, reason: 'at $ms ms');
        expect(find.byKey(const ValueKey('spin2win-dome-number')), findsNothing);
        bonuses.add(_text(tester, 'spin2win-dome-bonus'));
        angles.add(_angleFromMatrix(tester));
      }
      expect(landed, 0);
      expect(bonuses, containsAll(['N', '2x', '3x', '4x']));
      expect(angles.toSet().length, greaterThan(20), reason: 'the face keeps turning');

      await tester.pump(const Duration(milliseconds: 300));
      expect(landed, 1);
      expect(find.text('BONUS'), findsNothing);
      expect(_text(tester, 'spin2win-dome-number'), '7');
      expect(_text(tester, 'spin2win-dome'), contains('4x'));
      expect(_numberUnderPointer(_angleFromMatrix(tester)), 7);
      expect(find.byKey(const ValueKey('spin2win-wheel-highlight')), findsOneWidget);

      // Nothing more is reported however long the result stays.
      await tester.pump(const Duration(seconds: 3));
      expect(landed, 1);
      expect(_numberUnderPointer(_angleFromMatrix(tester)), 7);
    });

    testWidgets('when the round moves on, the highlight goes and the wheel stays on the number', (tester) async {
      var landed = 0;
      await tester.pumpWidget(_Host(cue: resting, onLanded: () => landed++));
      final host = tester.state<_HostState>(find.byType(_Host));
      host.set(spinning);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4100));
      host.set(const Spin2WinWheelCue(restNumber: 7, restBonus: 4));
      await tester.pump();
      expect(find.byKey(const ValueKey('spin2win-wheel-highlight')), findsNothing);
      expect(_text(tester, 'spin2win-dome-number'), '7');
      expect(_numberUnderPointer(_angleFromMatrix(tester)), 7);
      expect(landed, 1);
    });

    testWidgets('opened after the result was shown: no spin, the result straight away', (tester) async {
      var landed = 0;
      await tester.pumpWidget(_Host(
        cue: const Spin2WinWheelCue(restNumber: 1, spinKey: 'r-1', target: 3, targetBonus: 2, revealed: true),
        onLanded: () => landed++,
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('BONUS'), findsNothing);
      expect(_numberUnderPointer(_angleFromMatrix(tester)), 3);
      await tester.pump(const Duration(seconds: 5));
      expect(landed, 0);
      expect(_text(tester, 'spin2win-dome-number'), '3');
    });

    testWidgets('the game reveals while the wheel is still turning: it stops on the number at once', (tester) async {
      var landed = 0;
      await tester.pumpWidget(_Host(cue: resting, onLanded: () => landed++));
      final host = tester.state<_HostState>(find.byType(_Host));
      host.set(spinning);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      host.set(const Spin2WinWheelCue(restNumber: 1, spinKey: 'r-1', target: 7, targetBonus: 4, revealed: true));
      await tester.pump();
      expect(landed, 1);
      expect(_numberUnderPointer(_angleFromMatrix(tester)), 7);
      expect(_text(tester, 'spin2win-dome-number'), '7');
    });

    testWidgets('before any result the dome reads BONUS N', (tester) async {
      await tester.pumpWidget(_Host(cue: const Spin2WinWheelCue(), onLanded: () {}));
      expect(find.text('BONUS'), findsOneWidget);
      expect(_text(tester, 'spin2win-dome-bonus'), 'N');
      expect(_angleFromMatrix(tester), 0);
    });
  });

  testWidgets('on the screen the wheel alone lands the round: 7 with 4x, its card ringed in gold', (tester) async {
    final rig = BetRig(tester, startInto: 80);
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Spin2WinScreen(
        setup: Spin2WinScreenSetup(
          provider: rig.provider,
          setOrientation: false,
          precacheChips: false,
          alerts: FakeAlerts(),
          sound: Spin2WinSound(FakeSoundOutput()),
          chipImage: (_) => MemoryImage(_pixel),
          onProblem: (_) {},
        ),
      ),
    ));
    await rig.world.run(const Duration(seconds: 1));
    await tester.pump();

    // Just after the draw at 90 the wheel is turning and nothing is shown yet.
    await rig.world.runUntil(91.5);
    expect(rig.provider.stage, Spin2WinStage.spinning);
    expect(find.text('BONUS'), findsOneWidget);
    expect(find.byKey(const ValueKey('spin2win-card-win')), findsNothing);

    // About 4 s after the spin began the wheel has stopped and told the game.
    await rig.world.runUntil(95.0);
    expect(rig.provider.stage, Spin2WinStage.revealing);
    expect(rig.provider.numberRevealed, isTrue);
    expect(_text(tester, 'spin2win-dome-number'), '7');
    expect(find.byKey(const ValueKey('spin2win-card-win')), findsOneWidget);
    final ring = tester.getCenter(find.byKey(const ValueKey('spin2win-card-win')));
    final card7 = tester.getCenter(find.byKey(const ValueKey('spin2win-card-7')));
    expect((ring - card7).distance, lessThan(4));
    expect(_text(tester, 'spin2win-history-0'), '7 4x');

    // The next round: the ring goes, the wheel stays on 7.
    await rig.runIntoNextCycle(2);
    await tester.pump();
    expect(find.byKey(const ValueKey('spin2win-card-win')), findsNothing);
    expect(find.byKey(const ValueKey('spin2win-wheel-highlight')), findsNothing);
    expect(_text(tester, 'spin2win-dome-number'), '7');

    await tester.pumpWidget(const SizedBox());
    await rig.finish();
  });
}
