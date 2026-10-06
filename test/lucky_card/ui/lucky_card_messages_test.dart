// Tests for lucky_card_messages.dart (the refusal lines, the problem dialogs, the notice) and for
// the status strip showing a notice (lucky_card_status_strip.dart, lucky_card_readouts_binding.dart).

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_messages.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_panel.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_readouts_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_status_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

Set<LuckyCardBoardIssue> only(LuckyCardBoardIssue i) => {i};

Widget strip(LuckyCardStatusMode mode, {String? notice, bool important = false}) => LuckyCardCanvas(
      status: (context, layout) => LuckyCardStatusStrip(layout: layout, mode: mode, notice: notice, noticeImportant: important),
    );

String stripText(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byType(LuckyCardStatusStrip), matching: find.byType(Text))).data!;

Color stripColor(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byType(LuckyCardStatusStrip), matching: find.byType(Text))).style!.color!;

void main() {
  setUpAll(loadLuckyCardFonts);

  group('the refusal lines (pure)', () {
    test('each reason that deserves a line has Triple Chance\'s plain style and the right number', () {
      expect(luckyCardRefusalLine(only(LuckyCardBoardIssue.notEnoughCoins)), 'NOT ENOUGH COINS');
      expect(luckyCardRefusalLine(only(LuckyCardBoardIssue.cardAtMaximum)), 'CARD AT 50,000 LIMIT');
      expect(luckyCardRefusalLine(only(LuckyCardBoardIssue.noChipSelected)), 'PICK A CHIP FIRST');
      expect(luckyCardRefusalLine(only(LuckyCardBoardIssue.nothingToRemove)), 'NOTHING TO TAKE BACK');
    });

    test('the limit in the line is the game\'s own limit', () {
      expect(luckyCardRefusalLine(only(LuckyCardBoardIssue.cardAtMaximum)), contains(luckyCardGrouped(kLuckyCardMaxStake)));
    });

    test('every other reason is silent', () {
      for (final i in [LuckyCardBoardIssue.locked, LuckyCardBoardIssue.chipIsSelected, LuckyCardBoardIssue.nothingToDo, LuckyCardBoardIssue.boardNotEmpty]) {
        expect(luckyCardRefusalLine(only(i)), isNull, reason: i.name);
      }
      expect(luckyCardRefusalLine({}), isNull);
    });

    test('with several reasons at once the most useful wins', () {
      expect(luckyCardRefusalLine({LuckyCardBoardIssue.cardAtMaximum, LuckyCardBoardIssue.notEnoughCoins}), 'NOT ENOUGH COINS');
      expect(luckyCardRefusalLine({LuckyCardBoardIssue.nothingToRemove, LuckyCardBoardIssue.cardAtMaximum}), 'CARD AT 50,000 LIMIT');
      expect(luckyCardRefusalLine({LuckyCardBoardIssue.locked, LuckyCardBoardIssue.noChipSelected}), 'PICK A CHIP FIRST');
      expect(luckyCardRefusalLine({LuckyCardBoardIssue.locked, LuckyCardBoardIssue.nothingToRemove}), 'NOTHING TO TAKE BACK');
    });

    test('the times are 2 and 6 seconds', () {
      expect(kLuckyCardRefusalLineTime, const Duration(seconds: 2));
      expect(kLuckyCardBalanceLineTime, const Duration(seconds: 6));
      expect(kLuckyCardBalanceLine, 'BALANCE NOT CONFIRMED - IT WILL UPDATE NEXT ROUND');
    });
  });

  group('the problem dialogs (pure), in Triple Chance\'s words', () {
    LuckyCardProblemDialog bet(LuckyCardError e) => luckyCardProblemDialog(LuckyCardProblem(LuckyCardProblemKind.betRejected, e));

    test('a rejected bet: the title and message by reason, none ends the session, all close by themselves after 5 seconds', () {
      final cases = {
        LuckyCardError.insufficientCoins: ('INSUFFICIENT COINS', 'You did not have enough coins for this bet when the round closed. Your coins have been returned.'),
        LuckyCardError.roundClosed: ('ROUND CLOSED', 'Betting for that round closed before your bet arrived. Your coins have been returned — please try the next round.'),
        LuckyCardError.notAPlayer: ('ACCOUNT NOT ELIGIBLE', 'This account cannot place bets. Please contact your agent or support.'),
        LuckyCardError.unknown: ('BET NOT PLACED', 'Something went wrong on our end and your bet could not be placed. Your coins have been returned — please try the next round.'),
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
      for (final e in [LuckyCardError.belowMin, LuckyCardError.exceedsMax, LuckyCardError.emptyBet, LuckyCardError.badBet]) {
        final d = bet(e);
        expect(d.title, 'BET NOT PLACED', reason: e.name);
        expect(d.message, 'Your bet could not be sent to the server. Your coins have been returned — please try the next round.');
        expect(d.endsSession, isFalse);
      }
    });

    test('a round that never resolved claims no refund', () {
      final d = luckyCardProblemDialog(const LuckyCardProblem.unresolved());
      expect(d.title, 'SERVER ERROR');
      expect(d.message, 'This round is taking longer than expected to resolve. Your balance will update automatically once it\'s ready.');
      expect(d.message.toLowerCase().contains('returned'), isFalse, reason: 'the stake was really taken');
      expect(d.endsSession, isFalse);
      expect(d.autoDismiss, const Duration(seconds: 5));
    });

    test('a lost connection and a blocked account end the session and cannot be skipped', () {
      for (final e in [LuckyCardError.offline, LuckyCardError.unauthenticated]) {
        final d = luckyCardProblemDialog(LuckyCardProblem(LuckyCardProblemKind.connectionProblem, e));
        expect(d.title, 'CONNECTION LOST', reason: e.name);
        expect(d.message, 'Could not stay connected to the server. For your safety you will be logged out — please sign back in once reconnected.');
        expect(d.endsSession, isTrue);
        expect(d.autoDismiss, isNull);
      }
      final blocked = luckyCardProblemDialog(const LuckyCardProblem(LuckyCardProblemKind.connectionProblem, LuckyCardError.accountBlocked));
      expect(blocked.title, 'ACCOUNT BLOCKED');
      expect(blocked.message, 'Your account has been blocked. Please contact your agent. You will be logged out.');
      expect(blocked.endsSession, isTrue);
      expect(blocked.autoDismiss, isNull);
    });

    test('the sync\'s connection reasons choose the same two dialogs', () {
      expect(luckyCardDialogForConnection(LuckyCardError.offline).title, 'CONNECTION LOST');
      expect(luckyCardDialogForConnection(LuckyCardError.unauthenticated).title, 'CONNECTION LOST');
      expect(luckyCardDialogForConnection(LuckyCardError.unknown).title, 'CONNECTION LOST');
      expect(luckyCardDialogForConnection(LuckyCardError.accountBlocked).title, 'ACCOUNT BLOCKED');
    });

    test('the icons tell the kinds apart', () {
      final icons = {
        bet(LuckyCardError.roundClosed).icon,
        luckyCardProblemDialog(const LuckyCardProblem.unresolved()).icon,
        luckyCardConnectionLostDialog.icon,
        luckyCardBlockedDialog.icon,
      };
      expect(icons.length, 4);
    });
  });

  group('the notice', () {
    testWidgets('shows a line, tells its listeners, and goes by itself after its time', (tester) async {
      final notice = LuckyCardNotice();
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
      final notice = LuckyCardNotice();
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
      final notice = LuckyCardNotice();
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
      final notice = LuckyCardNotice();
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

  group('the status strip with a notice', () {
    testWidgets('betting open: the notice replaces the words, in amber; without it the words are back', (tester) async {
      await pumpAtSize(tester, phone, strip(LuckyCardStatusMode.placeChips, notice: 'NOT ENOUGH COINS'));
      expect(stripText(tester), 'NOT ENOUGH COINS');
      expect(stripColor(tester), LuckyCardStatusStrip.noticeColor);
      await pumpAtSize(tester, phone, strip(LuckyCardStatusMode.placeChips));
      expect(stripText(tester), 'PLACE YOUR CHIPS');
      expect(stripColor(tester), kLuckyCardCream);
    });

    testWidgets('betting closed: an ordinary notice is not shown, the words stay', (tester) async {
      for (final mode in [LuckyCardStatusMode.noMoreFlashing, LuckyCardStatusMode.noMoreSteady]) {
        await pumpAtSize(tester, phone, strip(mode, notice: 'NOT ENOUGH COINS'));
        expect(stripText(tester), 'NO MORE PLAY', reason: '$mode');
        expect(stripColor(tester), kLuckyCardAlert);
      }
    });

    testWidgets('betting closed: an important notice is shown', (tester) async {
      await pumpAtSize(tester, phone, strip(LuckyCardStatusMode.noMoreSteady, notice: kLuckyCardBalanceLine, important: true));
      expect(stripText(tester), kLuckyCardBalanceLine);
      expect(stripColor(tester), LuckyCardStatusStrip.noticeColor);
    });

    testWidgets('a screen reader hears the notice', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, phone, strip(LuckyCardStatusMode.placeChips, notice: 'CARD AT 50,000 LIMIT'));
      expect(find.bySemanticsLabel('CARD AT 50,000 LIMIT'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the longest line still fits the strip on the smallest phone, at 11 dp or more', (tester) async {
      await pumpAtSize(tester, const Size(640, 360), strip(LuckyCardStatusMode.noMoreSteady, notice: kLuckyCardBalanceLine, important: true));
      expect(tester.takeException(), isNull);
      final t = tester.widget<Text>(find.descendant(of: find.byType(LuckyCardStatusStrip), matching: find.byType(Text)));
      expect(t.style!.fontSize, greaterThanOrEqualTo(kLuckyCardMinReadableDp));
      final box = tester.getRect(find.byType(LuckyCardStatusStrip));
      final text = tester.getRect(find.descendant(of: find.byType(LuckyCardStatusStrip), matching: find.byType(Text)));
      expect(text.left, greaterThanOrEqualTo(box.left - 0.5));
      expect(text.right, lessThanOrEqualTo(box.right + 0.5));
    });

    testWidgets('the binding follows the notice as it comes and goes, and not the other way', (tester) async {
      final rig = BetRig(tester);
      final notice = LuckyCardNotice();
      await pumpAtSize(
        tester,
        phone,
        LuckyCardCanvas(status: (context, layout) => LuckyCardStatusBinding(provider: rig.provider, layout: layout, notice: notice)),
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

    testWidgets('while betting is closed the binding shows an important notice and hides an ordinary one', (tester) async {
      final rig = BetRig(tester);
      final notice = LuckyCardNotice();
      await pumpAtSize(
        tester,
        phone,
        LuckyCardCanvas(status: (context, layout) => LuckyCardStatusBinding(provider: rig.provider, layout: layout, notice: notice)),
      );
      await rig.open();
      await rig.world.runUntil(87.0);
      await tester.pump();
      expect(rig.provider.isLocked, isTrue);
      expect(stripText(tester), 'NO MORE PLAY');

      notice.show('NOT ENOUGH COINS');
      await tester.pump();
      expect(stripText(tester), 'NO MORE PLAY', reason: 'an ordinary line waits for betting to open');

      notice.show(kLuckyCardBalanceLine, duration: kLuckyCardBalanceLineTime, important: true);
      await tester.pump();
      expect(stripText(tester), kLuckyCardBalanceLine, reason: 'an important one does not');
      notice.dispose();
      await rig.finish();
    });

    testWidgets('without a notice the binding is what it was', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, LuckyCardCanvas(status: (context, layout) => LuckyCardStatusBinding(provider: rig.provider, layout: layout)));
      await rig.open();
      expect(stripText(tester), 'PLACE YOUR CHIPS');
      await rig.finish();
    });
  });
}
