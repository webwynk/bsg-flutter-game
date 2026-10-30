// Tests for lucky16_messages.dart (the refusal lines, the problem dialogs, the notice) and for
// the header showing a notice in place of its status words (lucky16_top_bar.dart's
// Lucky16StatusLine, lucky16_top_bar_binding.dart's lucky16HeaderStatus/Lucky16TopBarBinding). Copied from
// test/lucky_card/ui/lucky_card_messages_test.dart (Lucky Card), with Lucky 16 Card's limit.

import 'package:best_smart_game/models/lucky16_board.dart';
import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/providers/lucky16_provider.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_canvas.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_layout.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_messages.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_palette.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_panel.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_top_bar_binding.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

Set<Lucky16BoardIssue> only(Lucky16BoardIssue i) => {i};

/// Just the header, built exactly as Lucky16TopBarBinding derives it from a mode and a
/// notice (lucky16HeaderStatus), but without a provider: the plain values this file tests.
Widget strip(Lucky16StatusMode mode, {String? notice, bool important = false}) {
  final status = lucky16HeaderStatus(mode, notice: notice, noticeImportant: important);
  return Lucky16Canvas(
    topBar: (context, layout) => Lucky16TopBar(
      layout: layout,
      art: const FileLucky16Art(),
      balance: 0,
      countdown: 47,
      soundOn: true,
      infoEnabled: true,
      statusWidget: Lucky16StatusLine(
        key: const ValueKey('top-status'),
        text: status.text,
        size: layout.designStatusFont,
        color: status.color,
        flashing: status.isFlashing,
      ),
    ),
  );
}

Finder get _statusLine => find.byKey(const ValueKey('top-status'));

String stripText(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: _statusLine, matching: find.byType(Text))).data!;

Color stripColor(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: _statusLine, matching: find.byType(Text))).style!.color!;

void main() {
  setUpAll(loadLucky16Fonts);

  group('the refusal lines (pure)', () {
    test('each reason that deserves a line has Triple Chance\'s plain style and the right number', () {
      expect(lucky16RefusalLine(only(Lucky16BoardIssue.notEnoughCoins)), 'NOT ENOUGH COINS');
      expect(lucky16RefusalLine(only(Lucky16BoardIssue.noChipSelected)), 'PICK A CHIP FIRST');
      expect(lucky16RefusalLine(only(Lucky16BoardIssue.nothingToRemove)), 'NOTHING TO TAKE BACK');
    });

    test('a card at its largest stake has no header line: it gets the snackbar (the user, 2026-10-23)', () {
      expect(lucky16RefusalLine(only(Lucky16BoardIssue.cardAtMaximum)), isNull);
      expect(lucky16RefusalIsLimit(only(Lucky16BoardIssue.cardAtMaximum)), isTrue);
      expect(lucky16RefusalIsLimit({Lucky16BoardIssue.nothingToRemove, Lucky16BoardIssue.cardAtMaximum}), isTrue);
      expect(lucky16RefusalIsLimit({Lucky16BoardIssue.cardAtMaximum, Lucky16BoardIssue.notEnoughCoins}), isFalse,
          reason: 'not enough coins is the more useful thing to say');
      expect(lucky16RefusalIsLimit(only(Lucky16BoardIssue.notEnoughCoins)), isFalse);
      expect(lucky16RefusalIsLimit({}), isFalse);
    });

    testWidgets('the limit snackbar reads CARD PLAY LIMIT REACHED and the game\'s own maximum, for 3 seconds',
        (tester) async {
      expect(kLucky16LimitSnackBarTime, const Duration(seconds: 3));
      final bar = lucky16LimitSnackBar();
      expect(bar.duration, kLucky16LimitSnackBarTime);
      expect(bar.behavior, SnackBarBehavior.fixed);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(bar), child: const Text('go')))),
      ));
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('CARD PLAY LIMIT REACHED'), findsOneWidget);
      expect(find.text('Max ${lucky16Grouped(kLucky16MaxStake)} / card'), findsOneWidget);
      expect(find.text('Max 10,000 / card'), findsOneWidget);
      for (final t
          in tester.widgetList<Text>(find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)))) {
        expect(t.style!.fontSize, greaterThanOrEqualTo(11), reason: t.data);
      }
    });

    test('every other reason is silent', () {
      for (final i in [
        Lucky16BoardIssue.locked,
        Lucky16BoardIssue.chipIsSelected,
        Lucky16BoardIssue.nothingToDo,
        Lucky16BoardIssue.boardNotEmpty
      ]) {
        expect(lucky16RefusalLine(only(i)), isNull, reason: i.name);
      }
      expect(lucky16RefusalLine({}), isNull);
    });

    test('with several reasons at once the most useful wins', () {
      expect(
          lucky16RefusalLine({Lucky16BoardIssue.cardAtMaximum, Lucky16BoardIssue.notEnoughCoins}), 'NOT ENOUGH COINS');
      expect(lucky16RefusalLine({Lucky16BoardIssue.nothingToRemove, Lucky16BoardIssue.cardAtMaximum}),
          'NOTHING TO TAKE BACK',
          reason: 'the header line only; the screen shows the limit snackbar first (lucky16RefusalIsLimit)');
      expect(lucky16RefusalLine({Lucky16BoardIssue.locked, Lucky16BoardIssue.noChipSelected}), 'PICK A CHIP FIRST');
      expect(lucky16RefusalLine({Lucky16BoardIssue.locked, Lucky16BoardIssue.nothingToRemove}), 'NOTHING TO TAKE BACK');
    });

    test('the times are 2 and 6 seconds', () {
      expect(kLucky16RefusalLineTime, const Duration(seconds: 2));
      expect(kLucky16BalanceLineTime, const Duration(seconds: 6));
      expect(kLucky16BalanceLine, 'BALANCE NOT CONFIRMED - IT WILL UPDATE NEXT ROUND');
    });
  });

  group('the problem dialogs (pure), in Triple Chance\'s words', () {
    Lucky16ProblemDialog bet(Lucky16Error e) => lucky16ProblemDialog(Lucky16Problem(Lucky16ProblemKind.betRejected, e));

    test(
        'a rejected bet: the title and message by reason, none ends the session, all close by themselves after 5 seconds',
        () {
      final cases = {
        Lucky16Error.insufficientCoins: (
          'INSUFFICIENT COINS',
          'You did not have enough coins for this bet when the round closed. Your coins have been returned.'
        ),
        Lucky16Error.roundClosed: (
          'ROUND CLOSED',
          'Betting for that round closed before your bet arrived. Your coins have been returned — please try the next round.'
        ),
        Lucky16Error.notAPlayer: (
          'ACCOUNT NOT ELIGIBLE',
          'This account cannot place bets. Please contact your agent or support.'
        ),
        Lucky16Error.unknown: (
          'BET NOT PLACED',
          'Something went wrong on our end and your bet could not be placed. Your coins have been returned — please try the next round.'
        ),
      };
      for (final e in cases.entries) {
        final d = bet(e.key);
        expect(d.title, e.value.$1, reason: e.key.name);
        expect(d.message, e.value.$2, reason: e.key.name);
        expect(d.endsSession, isFalse);
        expect(d.autoDismiss, const Duration(seconds: 5));
      }
    });

    test('every other reason gets the plain "bet not placed" words', () {
      for (final e in [Lucky16Error.belowMin, Lucky16Error.exceedsMax, Lucky16Error.emptyBet, Lucky16Error.badBet]) {
        final d = bet(e);
        expect(d.title, 'BET NOT PLACED', reason: e.name);
        expect(d.message,
            'Your bet could not be sent to the server. Your coins have been returned — please try the next round.');
        expect(d.endsSession, isFalse);
      }
    });

    test('a round that never resolved claims no refund', () {
      final d = lucky16ProblemDialog(const Lucky16Problem.unresolved());
      expect(d.title, 'SERVER ERROR');
      expect(d.message,
          'This round is taking longer than expected to resolve. Your balance will update automatically once it\'s ready.');
      expect(d.message.toLowerCase().contains('returned'), isFalse, reason: 'the stake was really taken');
      expect(d.endsSession, isFalse);
      expect(d.autoDismiss, const Duration(seconds: 5));
    });

    test('a lost connection and a blocked account end the session and cannot be skipped', () {
      for (final e in [Lucky16Error.offline, Lucky16Error.unauthenticated]) {
        final d = lucky16ProblemDialog(Lucky16Problem(Lucky16ProblemKind.connectionProblem, e));
        expect(d.title, 'CONNECTION LOST', reason: e.name);
        expect(d.message,
            'Could not stay connected to the server. For your safety you will be logged out — please sign back in once reconnected.');
        expect(d.endsSession, isTrue);
        expect(d.autoDismiss, isNull);
      }
      final blocked =
          lucky16ProblemDialog(const Lucky16Problem(Lucky16ProblemKind.connectionProblem, Lucky16Error.accountBlocked));
      expect(blocked.title, 'ACCOUNT BLOCKED');
      expect(blocked.message, 'Your account has been blocked. Please contact your agent. You will be logged out.');
      expect(blocked.endsSession, isTrue);
      expect(blocked.autoDismiss, isNull);
    });

    test('the sync\'s connection reasons choose the same two dialogs', () {
      expect(lucky16DialogForConnection(Lucky16Error.offline).title, 'CONNECTION LOST');
      expect(lucky16DialogForConnection(Lucky16Error.unauthenticated).title, 'CONNECTION LOST');
      expect(lucky16DialogForConnection(Lucky16Error.unknown).title, 'CONNECTION LOST');
      expect(lucky16DialogForConnection(Lucky16Error.accountBlocked).title, 'ACCOUNT BLOCKED');
    });

    test('the icons tell the kinds apart', () {
      final icons = {
        bet(Lucky16Error.roundClosed).icon,
        lucky16ProblemDialog(const Lucky16Problem.unresolved()).icon,
        lucky16ConnectionLostDialog.icon,
        lucky16BlockedDialog.icon,
      };
      expect(icons.length, 4);
    });
  });

  group('the notice', () {
    testWidgets('shows a line, tells its listeners, and goes by itself after its time', (tester) async {
      final notice = Lucky16Notice();
      var told = 0;
      notice.addListener(() => told++);
      expect(notice.text, isNull);
      notice.show('NOT ENOUGH COINS');
      expect(notice.text, 'NOT ENOUGH COINS');
      expect(notice.important, isFalse);
      expect(told, 1);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(notice.text, 'NOT ENOUGH COINS');
      await tester.pump(const Duration(milliseconds: 200));
      expect(notice.text, isNull);
      expect(told, 2);
      notice.dispose();
    });

    testWidgets('a new line replaces the old and restarts the time', (tester) async {
      final notice = Lucky16Notice();
      notice.show('ONE');
      await tester.pump(const Duration(milliseconds: 1500));
      notice.show('TWO');
      await tester.pump(const Duration(milliseconds: 1500));
      expect(notice.text, 'TWO', reason: 'the second line has its own full time');
      await tester.pump(const Duration(milliseconds: 600));
      expect(notice.text, isNull);
      notice.dispose();
    });

    testWidgets('an important line, a longer time, and clear() at once', (tester) async {
      final notice = Lucky16Notice();
      notice.show('WARNING', duration: const Duration(seconds: 6), important: true);
      expect(notice.important, isTrue);
      await tester.pump(const Duration(seconds: 5));
      expect(notice.text, 'WARNING');
      notice.clear();
      expect(notice.text, isNull);
      expect(notice.important, isFalse);
      await tester.pump(const Duration(seconds: 3));
      notice.dispose();
    });

    testWidgets('clearing nothing tells nobody, and a disposed notice does not fire its timer', (tester) async {
      final notice = Lucky16Notice();
      var told = 0;
      notice.addListener(() => told++);
      notice.clear();
      expect(told, 0);
      notice.show('ONE');
      notice.dispose();
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  });

  group('the header\'s status words with a notice', () {
    testWidgets('betting open: the notice replaces the words, in amber; without it the words are back', (tester) async {
      await pumpAtSize(tester, phone, strip(Lucky16StatusMode.placeChips, notice: 'NOT ENOUGH COINS'));
      expect(stripText(tester), 'NOT ENOUGH COINS');
      expect(stripColor(tester), kLucky16NoticeText);
      await pumpAtSize(tester, phone, strip(Lucky16StatusMode.placeChips));
      expect(stripText(tester), 'PLACE YOUR CHIPS');
      expect(stripColor(tester), kLucky16StatusText);
    });

    testWidgets('betting closed: an ordinary notice is not shown, the words stay', (tester) async {
      for (final mode in [Lucky16StatusMode.noMoreFlashing, Lucky16StatusMode.noMoreSteady]) {
        await pumpAtSize(tester, phone, strip(mode, notice: 'NOT ENOUGH COINS'));
        expect(stripText(tester), 'NO MORE PLAY', reason: '$mode');
        expect(stripColor(tester), kLucky16AlertText);
      }
    });

    testWidgets('betting closed: an important notice is shown', (tester) async {
      await pumpAtSize(
          tester, phone, strip(Lucky16StatusMode.noMoreSteady, notice: kLucky16BalanceLine, important: true));
      expect(stripText(tester), kLucky16BalanceLine);
      expect(stripColor(tester), kLucky16NoticeText);
    });

    testWidgets('a screen reader hears the notice', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, phone, strip(Lucky16StatusMode.placeChips, notice: 'CARD AT 10,000 LIMIT'));
      expect(find.bySemanticsLabel('CARD AT 10,000 LIMIT'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the longest line still fits the header on the smallest phone, at 11 dp or more', (tester) async {
      await pumpAtSize(tester, const Size(640, 360),
          strip(Lucky16StatusMode.noMoreSteady, notice: kLucky16BalanceLine, important: true));
      expect(tester.takeException(), isNull);
      final t = tester.widget<Text>(find.descendant(of: _statusLine, matching: find.byType(Text)));
      expect(t.style!.fontSize, greaterThanOrEqualTo(kLucky16MinReadableDp));
      final box = tester.getRect(_statusLine);
      final text = tester.getRect(find.descendant(of: _statusLine, matching: find.byType(Text)));
      expect(text.left, greaterThanOrEqualTo(box.left - 0.5));
      expect(text.right, lessThanOrEqualTo(box.right + 0.5));
    });

    testWidgets('the binding follows the notice as it comes and goes, and not the other way', (tester) async {
      final rig = BetRig(tester);
      final notice = Lucky16Notice();
      await pumpAtSize(
        tester,
        phone,
        Lucky16Canvas(
          topBar: (context, layout) => Lucky16TopBarBinding(
              provider: rig.provider, layout: layout, art: const FileLucky16Art(), soundOn: true, notice: notice),
        ),
      );
      await rig.open();
      expect(stripText(tester), 'PLACE YOUR CHIPS');
      notice.show('NOT ENOUGH COINS');
      await tester.pump();
      expect(stripText(tester), 'NOT ENOUGH COINS');
      await tester.pump(const Duration(milliseconds: 2100));
      expect(stripText(tester), 'PLACE YOUR CHIPS');
      notice.dispose();
      await rig.finish();
    });

    testWidgets('while betting is closed the binding shows an important notice and hides an ordinary one',
        (tester) async {
      final rig = BetRig(tester);
      final notice = Lucky16Notice();
      await pumpAtSize(
        tester,
        phone,
        Lucky16Canvas(
          topBar: (context, layout) => Lucky16TopBarBinding(
              provider: rig.provider, layout: layout, art: const FileLucky16Art(), soundOn: true, notice: notice),
        ),
      );
      await rig.open();
      await rig.world.runUntil(87.0);
      await tester.pump();
      expect(rig.provider.isLocked, isTrue);
      expect(stripText(tester), 'NO MORE PLAY');

      notice.show('NOT ENOUGH COINS');
      await tester.pump();
      expect(stripText(tester), 'NO MORE PLAY', reason: 'an ordinary line waits for betting to open');

      notice.show(kLucky16BalanceLine, duration: kLucky16BalanceLineTime, important: true);
      await tester.pump();
      expect(stripText(tester), kLucky16BalanceLine, reason: 'an important one does not');
      notice.dispose();
      await rig.finish();
    });

    testWidgets('without a notice the binding is what it was', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(
        tester,
        phone,
        Lucky16Canvas(
            topBar: (context, layout) => Lucky16TopBarBinding(
                provider: rig.provider, layout: layout, art: const FileLucky16Art(), soundOn: true)),
      );
      await rig.open();
      expect(stripText(tester), 'PLACE YOUR CHIPS');
      await rig.finish();
    });
  });
}
