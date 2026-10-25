// Spin2Win screens, Phase 5: MY RECORDS (History and the dynamic Payout tab), what goes wrong
// (Triple Chance's popups and bars), the NO MORE BETS sign and the exit question.
//
// The screen runs over the provider on the simulated server and a fake clock (provider_rig.dart).
// The popups are written down by [FakeAlerts] instead of drawing Triple Chance's shared ones.

import 'dart:io';

import 'package:best_smart_game/models/spin2win_board.dart';
import 'package:best_smart_game/models/spin2win_models.dart';
import 'package:best_smart_game/providers/spin2win_history_provider.dart';
import 'package:best_smart_game/providers/spin2win_provider.dart';
import 'package:best_smart_game/screens/spin2win_screen.dart';
import 'package:best_smart_game/services/spin2win_history_service.dart';
import 'package:best_smart_game/services/spin2win_sound.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_messages.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_records_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_alerts.dart';
import 'fake_sound.dart';
import 'provider_rig.dart';

final Uint8List _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

Map<String, dynamic> _row(int round, int stake, int payout, int number, int bonus) => {
      'round_id': 'id-$round',
      'total_stake': stake,
      'total_payout': payout,
      'created_at': '2026-10-25T10:00:00+00:00',
      'spin2win_rounds': {'round_number': round, 'winning_number': number, 'bonus_multiplier': bonus},
    };

class _Screen {
  _Screen(this.tester, this.rig, {List<dynamic>? rows, this.failRead = false}) : _rows = rows ?? const [];

  final WidgetTester tester;
  final BetRig rig;
  final List<dynamic> _rows;
  bool failRead;
  final FakeAlerts alerts = FakeAlerts();
  final List<DateTime?> reads = [];
  int sessionsEnded = 0;
  final GlobalKey<NavigatorState> nav = GlobalKey();

  late final Spin2WinHistoryProvider history = Spin2WinHistoryProvider(
    service: Spin2WinHistoryService(query: (since, limit) async {
      reads.add(since);
      if (failRead) throw StateError('offline');
      return _rows;
    }),
  );

  static final DateTime login = DateTime.utc(2026, 10, 25, 9);

  Spin2WinProvider get p => rig.provider;

  /// Opens the lobby stand-in, then the game over it.
  Future<void> open() async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: const Scaffold(body: Text('LOBBY'))));
    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => Spin2WinScreen(
        setup: Spin2WinScreenSetup(
          provider: rig.provider,
          setOrientation: false,
          precacheChips: false,
          chipImage: (_) => MemoryImage(_pixel),
          alerts: alerts,
          sound: Spin2WinSound(FakeSoundOutput()),
          history: history,
          sessionStart: () => login,
          endSession: () async => sessionsEnded++,
        ),
      ),
    ));
    await rig.world.run(const Duration(seconds: 1));
    await tester.pump();
  }

  Future<void> tap(String key) async {
    await tester.tap(find.byKey(ValueKey('spin2win-$key')), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  String text(String key) => tester
      .widgetList<Text>(find.descendant(of: find.byKey(ValueKey('spin2win-$key')), matching: find.byType(Text), matchRoot: true))
      .map((t) => t.data ?? '')
      .toSet()
      .join(' ');

  bool shows(String key) => find.byKey(ValueKey('spin2win-$key')).evaluate().isNotEmpty;

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
    history.dispose();
    await rig.finish();
  }
}

/// The game's own fonts (the test font draws every letter as a full square, far wider).
Future<void> _loadFonts() async {
  Future<ByteData> read(String name) async => ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync());
  await (FontLoader('DMSans')..addFont(read('DMSans-Black.ttf'))).load();
  await (FontLoader('Oswald')..addFont(read('Oswald-SemiBold.ttf'))).load();
}

void main() {
  setUpAll(_loadFonts);

  group('the words (Triple Chance\'s own)', () {
    test('each problem gets Triple Chance\'s title, and only the connection ones end the session', () {
      String title(Spin2WinProblem p) => spin2WinProblemDialog(p).title;
      const rejected = Spin2WinProblemKind.betRejected;
      expect(title(const Spin2WinProblem(rejected, Spin2WinError.roundClosed)), 'ROUND CLOSED');
      expect(title(const Spin2WinProblem(rejected, Spin2WinError.insufficientCoins)), 'INSUFFICIENT COINS');
      expect(title(const Spin2WinProblem(rejected, Spin2WinError.notAPlayer)), 'ACCOUNT NOT ELIGIBLE');
      expect(title(const Spin2WinProblem(rejected, Spin2WinError.unknown)), 'BET NOT PLACED');
      expect(title(const Spin2WinProblem(rejected, Spin2WinError.exceedsMax)), 'BET NOT PLACED');
      expect(spin2WinProblemDialog(const Spin2WinProblem(rejected, Spin2WinError.belowMin)).message,
          contains('could not be sent to the server'));
      expect(title(const Spin2WinProblem.unresolved()), 'SERVER ERROR');
      final lost = spin2WinProblemDialog(const Spin2WinProblem(Spin2WinProblemKind.connectionProblem, Spin2WinError.offline));
      final blocked =
          spin2WinProblemDialog(const Spin2WinProblem(Spin2WinProblemKind.connectionProblem, Spin2WinError.accountBlocked));
      expect([lost.title, lost.endsSession, lost.autoDismiss], ['CONNECTION LOST', true, null]);
      expect([blocked.title, blocked.endsSession], ['ACCOUNT BLOCKED', true]);
      expect(spin2WinProblemDialog(const Spin2WinProblem.unresolved()).autoDismiss, const Duration(seconds: 5));
    });

    test('the limit bar: PLAY LIMIT REACHED, Max 10,000 / number, only when coins did not run out', () {
      expect(kSpin2WinLimitTitle, 'PLAY LIMIT REACHED');
      expect(kSpin2WinLimitDetail, 'Max 10,000 / number');
      expect(spin2WinRefusalIsLimit({Spin2WinBoardIssue.numberAtMaximum}), isTrue);
      expect(spin2WinRefusalIsLimit({Spin2WinBoardIssue.numberAtMaximum, Spin2WinBoardIssue.notEnoughCoins}), isFalse);
      expect(spin2WinRefusalIsLimit({Spin2WinBoardIssue.noChipSelected}), isFalse);
      expect(kSpin2WinLimitSnackBarTime, const Duration(seconds: 3));
    });
  });

  testWidgets('not enough coins: Triple Chance\'s INSUFFICIENT COINS popup', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40, startBalance: 40));
    await s.open();
    await s.tap('chip-50');
    await s.tap('card-3');
    expect(s.alerts.insufficient, 1);
    expect(s.p.stakeOn(3), 0);
    await s.close();
  });

  testWidgets('a number at 10,000: the PLAY LIMIT REACHED bar for 3 s', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 30, startBalance: 20000));
    await s.open();
    s.p.selectChip(Spin2WinChip.fiveHundred);
    for (var i = 0; i < 20; i++) {
      s.p.tapNumber(4);
    }
    expect(s.p.stakeOn(4), 10000);
    await s.tap('card-4');
    expect(find.text('PLAY LIMIT REACHED'), findsOneWidget);
    expect(find.text('Max 10,000 / number'), findsOneWidget);
    expect(s.alerts.insufficient, 0);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('PLAY LIMIT REACHED'), findsNothing);
    await s.close();
  });

  testWidgets('a rejected bet and a round that never resolved: Triple Chance\'s popups', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40));
    await s.open();
    s.p.onProblem!(const Spin2WinProblem(Spin2WinProblemKind.betRejected, Spin2WinError.roundClosed));
    s.p.onProblem!(const Spin2WinProblem.unresolved());
    expect(s.alerts.problems.map((d) => d.title), ['ROUND CLOSED', 'SERVER ERROR']);
    expect(s.alerts.sessionEnds, [null, null]);
    s.p.onProblem!(const Spin2WinProblem(Spin2WinProblemKind.betRejected, Spin2WinError.insufficientCoins));
    expect(s.alerts.insufficient, 1);
    await s.close();
  });

  testWidgets('a blocked account: one popup that cannot be skipped; OK ends the session', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 40));
    await s.open();
    const blocked = Spin2WinProblem(Spin2WinProblemKind.connectionProblem, Spin2WinError.accountBlocked);
    s.p.onProblem!(blocked);
    s.p.onProblem!(blocked);
    expect(s.alerts.problems.map((d) => d.title), ['ACCOUNT BLOCKED']);
    s.alerts.sessionEnds.single!();
    await tester.pump();
    expect(s.sessionsEnded, 1);
    await s.close();
  });

  group('the exit question', () {
    testWidgets('EXIT asks; NO stays, YES goes back to the lobby', (tester) async {
      final s = _Screen(tester, BetRig(tester, startInto: 40));
      await s.open();
      await s.tap('exit');
      expect(find.text('EXIT GAME'), findsWidgets);
      expect(find.text('Do you want to exit?'), findsOneWidget);
      await s.tap('exit-no');
      expect(s.shows('exit-dialog'), isFalse);
      expect(s.shows('wheel-face'), isTrue);

      await s.tap('exit');
      await s.tap('exit-yes');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('LOBBY'), findsOneWidget);
      expect(s.shows('wheel-face'), isFalse);
      await s.close();
    });

    testWidgets('left alone it answers "stay" after 5 s; the back gesture asks too', (tester) async {
      final s = _Screen(tester, BetRig(tester, startInto: 40));
      await s.open();
      await s.tap('exit');
      await tester.pump(const Duration(seconds: 4));
      expect(s.shows('exit-dialog'), isTrue);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(s.shows('exit-dialog'), isFalse);
      expect(s.shows('wheel-face'), isTrue);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(s.shows('exit-dialog'), isTrue, reason: 'the back gesture asks first');
      expect(s.shows('wheel-face'), isTrue);
      await s.tap('exit-yes');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('LOBBY'), findsOneWidget);
      await s.close();
    });
  });

  group('MY RECORDS', () {
    final rows = [_row(1082451, 50, 900, 7, 2), _row(1082450, 100, 0, 3, 1), _row(1082449, 10, 90, 9, 1)];

    testWidgets('the trophy opens it: the rounds since login, newest first, with the totals', (tester) async {
      final s = _Screen(tester, BetRig(tester, startInto: 40), rows: rows);
      await s.open();
      await s.tap('records');
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.shows('records-dialog'), isTrue);
      expect(s.reads, [_Screen.login]);
      expect(s.text('records-row-0'), allOf(contains('R-1082451'), contains('900'), contains('7'), contains('2x'), contains('WIN')));
      expect(s.text('records-row-1'), allOf(contains('R-1082450'), contains('LOSE'), contains('N')));
      expect(s.text('records-row-2'), contains('R-1082449'));
      expect(s.text('records-total-play'), contains('160'));
      expect(s.text('records-total-win'), contains('990'));

      await s.tap('records-close');
      expect(s.shows('records-dialog'), isFalse);
      expect(s.shows('wheel-face'), isTrue, reason: 'the close button never closes the game too');
      await s.close();
    });

    testWidgets('no rounds says so; a failed read offers a retry', (tester) async {
      final s = _Screen(tester, BetRig(tester, startInto: 40), failRead: true);
      await s.open();
      await s.tap('records');
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.text('records-error'), Spin2WinHistoryProvider.loadErrorText);
      s.failRead = false;
      await s.tap('records-error');
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.reads.length, 2);
      expect(find.text(kSpin2WinRecordsEmpty), findsOneWidget);
      await s.close();
    });

    testWidgets('PAYOUT follows the chip in hand: 10 gives 90 / 180 / 270 / 360, 50 gives 450 to 1,800', (tester) async {
      final s = _Screen(tester, BetRig(tester, startInto: 40), rows: rows);
      await s.open();
      s.p.deselectChip();
      await s.tap('records');
      await s.tap('records-tab-payout');
      expect(s.text('payout-text'), contains('Play 10 chips'), reason: 'none in hand: the design\'s 10 chip');
      expect([for (var m = 1; m <= 4; m++) s.text('payout-$m')], ['N 90', '2x 180', '3x 270', '4x 360']);
      expect(s.text('payout-min'), contains('5'));
      expect(s.text('payout-max'), contains('10,000'));

      s.p.selectChip(Spin2WinChip.fifty);
      await tester.pump();
      expect(s.text('payout-text'), contains('Play 50 chips'));
      expect([for (var m = 1; m <= 4; m++) s.text('payout-$m')], ['N 450', '2x 900', '3x 1,350', '4x 1,800']);
      await s.close();
    });

    testWidgets('it closes by itself when betting closes, and the trophy does nothing then', (tester) async {
      final s = _Screen(tester, BetRig(tester, startInto: 80), rows: rows);
      await s.open();
      await s.tap('records');
      expect(s.shows('records-dialog'), isTrue);
      while (!s.p.isLocked) {
        await s.rig.world.run(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(s.shows('records-dialog'), isFalse);
      expect(s.shows('wheel-face'), isTrue);

      await s.tap('records');
      expect(s.shows('records-dialog'), isFalse);
      expect(s.reads.length, 1);
      await s.close();
    });
  });

  testWidgets('NO MORE BETS shows from 05 to 01, and goes when the wheel starts', (tester) async {
    final s = _Screen(tester, BetRig(tester, startInto: 80));
    await s.open();
    await s.rig.world.runUntil(84);
    expect(s.p.countdown, greaterThan(5));
    expect(s.shows('no-more-bets'), isFalse);
    // The board locks on the tick that reaches 05.
    while (!s.p.isLocked) {
      await s.rig.world.run(const Duration(milliseconds: 100));
    }
    await tester.pump();
    expect(s.p.countdown, lessThanOrEqualTo(5));
    expect(s.shows('no-more-bets'), isTrue);
    expect(s.text('no-more-bets'), 'NO MORE BETS');
    await s.rig.world.runUntil(89.5);
    expect(s.shows('no-more-bets'), isTrue);
    await s.rig.world.runUntil(91);
    expect(s.p.stage, isNot(Spin2WinStage.none));
    expect(s.shows('no-more-bets'), isFalse);
    await s.close();
  });
}
