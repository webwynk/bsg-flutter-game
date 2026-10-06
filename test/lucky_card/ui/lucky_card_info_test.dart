// Tests for the Lucky Card Info dialog (lucky_card_info_text.dart, lucky_card_info_dialog.dart):
// the words and numbers (pure), then the dialog on every device of the matrix, driven by the
// real provider on the simulated server and the fake clock for the "closes by itself when
// betting closes" rule.

import 'dart:ui' as ui;

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/services/lucky_card_round_clock.dart';
import 'package:best_smart_game/services/lucky_card_round_sync.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_info_dialog.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_info_text.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_panel.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_readouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_wallet.dart';
import '../provider_rig.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

class Log {
  final List<String> events = [];
}

/// A provider that can say whether anything is still listening to it.
class ProbeProvider extends LuckyCardProvider {
  ProbeProvider(BetRig rig)
      : super(
          api: rig.server,
          wallet: FakeWallet(1000),
          sync: LuckyCardRoundSync(api: rig.server, now: () => rig.world.deviceNow),
          now: () => rig.world.deviceNow,
        );

  bool get listenedTo => hasListeners;
}

/// A screen with one button that opens the dialog, as the real screen's Info button will.
Widget host(LuckyCardProvider provider, {Log? log}) => ColoredBox(
      color: const Color(0xFF1A0505),
      child: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            key: const ValueKey('open'),
            onPressed: () => LuckyCardInfoDialog.show(
              context,
              provider: provider,
              onOpen: () => log?.events.add('open'),
              onTab: (t) => log?.events.add('tab ${t.name}'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

Finder key(String k) => find.byKey(ValueKey(k));
Finder get dialog => key('info-dialog');

Future<void> open(WidgetTester tester) async {
  await tester.tap(key('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

List<Text> textsOfDialog(WidgetTester tester) =>
    tester.widgetList<Text>(find.descendant(of: dialog, matching: find.byType(Text))).toList();

double smallestText(WidgetTester tester) {
  var smallest = double.infinity;
  for (final t in textsOfDialog(tester)) {
    final size = t.style?.fontSize;
    expect(size, isNotNull, reason: '"${t.data}" sets its own size');
    if (size! < smallest) smallest = size;
  }
  return smallest;
}

void main() {
  setUpAll(() async {
    await loadLuckyCardFonts();
    await loadLuckyCardIcons();
  });

  group('the words and numbers (pure)', () {
    test('a winning stake pays 10 times, times the bonus; no bonus counts as 1', () {
      expect(luckyCardPayoutFor(10, 1), 100);
      expect(luckyCardPayoutFor(10, 4), 400);
      expect(luckyCardPayoutFor(5, 1), 50);
      expect(luckyCardPayoutFor(50000, 1), 500000);
      expect(luckyCardPayoutFor(50000, 10), 5000000);
      expect(luckyCardPayoutFor(10, 0), 100, reason: 'a zero bonus is no bonus');
    });

    test('the payout multiplier is the one the limits panel shows', () {
      expect(LuckyCardLimits.minOut, LuckyCardLimits.minIn * kLuckyCardPayoutMultiplier);
      expect(LuckyCardLimits.maxOut, LuckyCardLimits.maxIn * kLuckyCardPayoutMultiplier);
      expect(LuckyCardLimits.minIn, kLuckyCardMinStake);
      expect(LuckyCardLimits.maxIn, kLuckyCardMaxStake);
    });

    test('the table runs N then 2X to 10X, each worth the stake times 10 times the bonus', () {
      final table = luckyCardPayoutTable();
      expect([for (final r in table) r.bonus], ['N', '2X', '3X', '4X', '5X', '6X', '7X', '8X', '9X', '10X']);
      expect([for (final r in table) r.win], [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]);
    });

    test('the chips are listed as the rail has them', () {
      expect(luckyCardChipList(), '5, 10, 50, 100 or 500');
    });

    test('the rules: seven lines, each carrying the real numbers', () {
      final lines = luckyCardRulesLines();
      expect(lines.length, 7);
      expect(lines[0], contains('5, 10, 50, 100 or 500'));
      expect(lines[1], allOf(contains('Hearts'), contains('3 cards'), contains('4 cards'), contains('Jacks')));
      expect(lines[2], allOf(contains('12 cards'), contains('from 5 up to 50,000')));
      expect(lines[3], contains('countdown reaches $kLuckyCardLockCountdown'));
      expect(lines[3], contains('countdown reaches 5'));
      expect(lines[4], allOf(contains('one winning card'), contains('2X up to 10X')));
      expect(lines[5], contains('Chips on the other cards are lost'));
      expect(lines[6], allOf(contains('DOUBLE'), contains('REBET'), contains('CLEAR'), contains('REMOVE')));
    });

    test('the payout rule, the example and the limits say the right figures', () {
      expect(luckyCardPayoutRule(), 'A winning card pays 10 times the chips on it, multiplied by the bonus.');
      expect(luckyCardExampleText(), 'Example: you put 10 on the Queen of Spades. If it wins you get 100. With a 4X bonus you get 400.');
      expect(luckyCardTableTitle(), 'What a stake of 10 wins');
      expect(
        luckyCardLimitsText(),
        'The smallest stake on a card, 5, wins 50. The largest, 50,000, wins 500,000 before the bonus; the bonus is added on top.',
      );
    });

    test('every word is plain letters: the fonts have no card-suit symbols', () {
      final all = [
        ...luckyCardRulesLines(),
        luckyCardPayoutRule(),
        luckyCardExampleText(),
        luckyCardTableTitle(),
        luckyCardLimitsText(),
        kLuckyCardRulesTab,
        kLuckyCardPayoutsTab,
      ];
      for (final s in all) {
        expect(s.codeUnits.every((c) => c < 128), isTrue, reason: s);
      }
    });
  });

  group('the dialog opens, shows its tabs, and closes', () {
    testWidgets('it opens on RULES with the open hook called once, and the rules are on screen', (tester) async {
      final rig = BetRig(tester);
      final log = Log();
      await pumpAtSize(tester, phone, host(rig.provider, log: log));
      expect(dialog, findsNothing);
      await open(tester);
      expect(dialog, findsOneWidget);
      expect(log.events, ['open']);
      final lines = luckyCardRulesLines();
      for (var i = 0; i < lines.length; i++) {
        expect(tester.widget<Text>(key('rule-$i')).data, lines[i]);
      }
      expect(key('payout-rule'), findsNothing);
      await rig.finish();
    });

    testWidgets('the PAYOUTS tab shows the rule, the example, the table and the limits; the tab hook is told', (tester) async {
      final rig = BetRig(tester);
      final log = Log();
      await pumpAtSize(tester, phone, host(rig.provider, log: log));
      await open(tester);
      await tester.tap(key('info-tab-payouts'));
      await settle(tester);
      expect(tester.widget<Text>(key('payout-rule')).data, luckyCardPayoutRule());
      expect(tester.widget<Text>(key('payout-example')).data, luckyCardExampleText());
      expect(tester.widget<Text>(key('payout-table-title')).data, luckyCardTableTitle());
      expect(tester.widget<Text>(key('payout-limits')).data, luckyCardLimitsText());
      for (final row in luckyCardPayoutTable()) {
        final cell = key('payout-${row.bonus}');
        expect(cell, findsOneWidget);
        expect([for (final t in tester.widgetList<Text>(find.descendant(of: cell, matching: find.byType(Text)))) t.data], [row.bonus, luckyCardGrouped(row.win)]);
      }
      expect(key('rule-0'), findsNothing);
      expect(log.events, ['open', 'tab payouts']);

      await tester.tap(key('info-tab-payouts'));
      await settle(tester);
      expect(log.events.length, 2, reason: 'choosing the tab already shown says nothing');
      await tester.tap(key('info-tab-rules'));
      await settle(tester);
      expect(key('rule-0'), findsOneWidget);
      expect(log.events.last, 'tab rules');
      await rig.finish();
    });

    testWidgets('each tab opens at its top, even after the other was scrolled', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, const Size(640, 360), host(rig.provider));
      await open(tester);
      final scrollable = find.descendant(of: key('info-scroll'), matching: find.byType(Scrollable));
      double offset() => tester.state<ScrollableState>(scrollable).position.pixels;

      // RULES is a line too long for the smallest phone: scroll it to its last line.
      await tester.ensureVisible(key('rule-6'));
      await tester.pump();
      expect(offset(), greaterThan(0), reason: 'the rules scroll on the smallest phone');

      await tester.tap(key('info-tab-payouts'));
      await settle(tester);
      expect(offset(), 0, reason: 'payouts opens at its top');
      await tester.tap(key('info-tab-rules'));
      await settle(tester);
      expect(offset(), 0, reason: 'and the rules open at their top again, not where they were left');
      await rig.finish();
    });

    testWidgets('the close button, and a tap outside, close it', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider));
      await open(tester);
      await tester.tap(key('info-close'));
      await settle(tester);
      expect(dialog, findsNothing);

      await open(tester);
      await tester.tapAt(const Offset(4, 4));
      await settle(tester);
      expect(dialog, findsNothing);

      await open(tester);
      expect(dialog, findsOneWidget, reason: 'it can be opened again');
      await rig.finish();
    });

    testWidgets('two quick activations of close close the dialog once, not the game screen behind it', (tester) async {
      final rig = BetRig(tester);
      // The game screen is a page pushed over another (the lobby), as in the real app: a stray
      // second pop would take the player out of the game.
      await pumpAtSize(
        tester,
        phone,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('lobby-go'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(body: host(rig.provider)))),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(key('lobby-go'));
      await settle(tester);
      expect(key('open'), findsOneWidget, reason: 'the game screen is on top of the lobby');

      // A screen reader can send a second activation before the screen has updated.
      final handle = tester.ensureSemantics();
      await open(tester);
      final close = find.semantics.byPredicate((n) => n.label == 'Close' && n.getSemanticsData().flagsCollection.isButton);
      tester.semantics.performAction(close, ui.SemanticsAction.tap);
      tester.semantics.performAction(close, ui.SemanticsAction.tap);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(dialog, findsNothing);
      expect(key('open'), findsOneWidget, reason: 'still in the game after two activations');
      expect(key('lobby-go'), findsNothing, reason: 'the lobby is still covered');
      handle.dispose();
      await rig.finish();
    });

    testWidgets('the chosen tab is bright with a line under it; the other is dim with no line', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider));
      await open(tester);
      Color colorOf(String tab) => tester.widget<Text>(find.descendant(of: key(tab), matching: find.byType(Text))).style!.color!;
      bool hasLine(String tab) => find.descendant(of: key(tab), matching: find.byType(ColoredBox)).evaluate().isNotEmpty;
      expect(colorOf('info-tab-rules'), kLuckyCardGoldBright);
      expect(colorOf('info-tab-payouts'), isNot(kLuckyCardGoldBright));
      expect(hasLine('info-tab-rules'), isTrue);
      expect(hasLine('info-tab-payouts'), isFalse);
      await tester.tap(key('info-tab-payouts'));
      await settle(tester);
      expect(colorOf('info-tab-payouts'), kLuckyCardGoldBright);
      expect(colorOf('info-tab-rules'), isNot(kLuckyCardGoldBright));
      expect(hasLine('info-tab-payouts'), isTrue);
      expect(hasLine('info-tab-rules'), isFalse);
      await rig.finish();
    });

    testWidgets('the rules are numbered 1 to 7 in order', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider));
      await open(tester);
      final numbers = [
        for (final t in textsOfDialog(tester))
          if (RegExp(r'^[0-9]$').hasMatch(t.data ?? '')) t.data,
      ];
      expect(numbers, ['1', '2', '3', '4', '5', '6', '7']);
      await rig.finish();
    });

    testWidgets('a tap inside the dialog does not close it', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider));
      await open(tester);
      await tester.tap(key('rule-2'));
      await settle(tester);
      expect(dialog, findsOneWidget);
      await rig.finish();
    });

    testWidgets('it stays open while betting is open, however long the player reads', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider));
      await rig.open();
      await open(tester);
      await rig.world.runUntil(60.0);
      expect(rig.provider.isLocked, isFalse);
      expect(dialog, findsOneWidget);
      await rig.world.runUntil(80.0);
      expect(dialog, findsOneWidget);
      await rig.finish();
    });
  });

  group('it closes by itself when betting closes', () {
    testWidgets('open at second 70, it fades away at the lock, before the wheel starts', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider));
      await rig.open();
      await rig.world.runUntil(70.0);
      await open(tester);
      expect(dialog, findsOneWidget);
      await tester.tap(key('info-tab-payouts'));
      await settle(tester);

      var guard = 0;
      while (!rig.provider.isLocked && ++guard < 800) {
        await rig.world.run(const Duration(milliseconds: 50));
      }
      expect(rig.provider.isLocked, isTrue);
      await rig.world.run(const Duration(milliseconds: 500));
      expect(dialog, findsNothing, reason: 'closed at the lock');
      expect(rig.provider.stage, LuckyCardStage.none, reason: 'before the wheel has started');
      await rig.finish();
    });

    testWidgets('opened after the lock, it closes again at once', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider));
      await rig.open();
      await rig.world.runUntil(86.0);
      expect(rig.provider.isLocked, isTrue);
      await open(tester);
      await settle(tester);
      expect(dialog, findsNothing);
      await rig.finish();
    });

    testWidgets('the wheel and the result sequence run on, uncovered', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider));
      await rig.open();
      rig.betTenOnEveryCard();
      await rig.world.runUntil(80.0);
      await open(tester);
      await rig.world.runUntil(92.0);
      expect(dialog, findsNothing);
      expect(rig.provider.stage, LuckyCardStage.spinning);
      await rig.finish();
    });

    testWidgets('closing by hand, then the lock, does not close anything twice or throw', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider));
      await rig.open();
      await rig.world.runUntil(70.0);
      await open(tester);
      await tester.tap(key('info-close'));
      await settle(tester);
      await rig.world.runUntil(88.0);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('open')), findsOneWidget, reason: 'the screen behind is still there');
      await rig.finish();
    });

    testWidgets('it stops listening once it is closed, by hand or by the lock', (tester) async {
      final rig = BetRig(tester);
      final probe = ProbeProvider(rig);
      await pumpAtSize(tester, phone, host(probe));
      expect(probe.listenedTo, isFalse);
      await open(tester);
      expect(probe.listenedTo, isTrue);
      await tester.tap(key('info-close'));
      await settle(tester);
      expect(probe.listenedTo, isFalse);
      probe.dispose();
      await rig.finish();
    });
  });

  group('every device of the matrix', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): the dialog fits the screen, 48 dp buttons, 11 dp text, every line reachable', (tester) async {
        final rig = BetRig(tester);
        await pumpAtSize(tester, d.size, host(rig.provider));
        await open(tester);
        final l = LuckyCardLayout.of(d.size);

        for (final tab in ['info-tab-rules', 'info-tab-payouts']) {
          await tester.tap(key(tab));
          await settle(tester);
          expect(tester.takeException(), isNull, reason: '$tab on ${d.name}');

          final box = tester.getRect(dialog);
          final screen = Offset.zero & d.size;
          expect(screen.contains(box.topLeft) && screen.contains(box.bottomRight), isTrue, reason: 'inside the screen: $box');
          expect(box.center.dx, closeTo(l.canvasRect.center.dx, 0.5));
          expect(box.center.dy, closeTo(l.canvasRect.center.dy, 0.5));
          expect(box.width, closeTo(l.canvasRect.width * LuckyCardInfoDialog.widthShare, 0.5));

          for (final k in ['info-tab-rules', 'info-tab-payouts', 'info-close']) {
            final r = tester.getRect(key(k));
            expect(r.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: '$k width on ${d.name}');
            expect(r.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: '$k height on ${d.name}');
            expect(box.contains(r.topLeft) && box.contains(r.bottomRight - const Offset(0.01, 0.01)), isTrue, reason: '$k inside the dialog');
          }
          expect(smallestText(tester), greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: '$tab on ${d.name}');
        }

        // The last line of each tab can be scrolled into view, inside the dialog.
        Future<void> reach(String k) async {
          await tester.ensureVisible(key(k));
          await tester.pump();
          final r = tester.getRect(key(k));
          final box = tester.getRect(dialog);
          expect(r.bottom, lessThanOrEqualTo(box.bottom + 0.5), reason: '$k reachable on ${d.name}');
          expect(r.top, greaterThanOrEqualTo(box.top), reason: '$k reachable on ${d.name}');
        }

        await tester.tap(key('info-tab-rules'));
        await settle(tester);
        await reach('rule-6');
        await tester.tap(key('info-tab-payouts'));
        await settle(tester);
        await reach('payout-limits');
        await reach('payout-10X');
        await rig.finish();
      });
    }

    testWidgets('every table cell holds its two numbers on the smallest phone', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, const Size(640, 360), host(rig.provider));
      await open(tester);
      await tester.tap(key('info-tab-payouts'));
      await settle(tester);
      await tester.ensureVisible(key('payout-10X'));
      await tester.pump();
      for (final row in luckyCardPayoutTable()) {
        final cell = tester.getRect(key('payout-${row.bonus}'));
        for (final t in find.descendant(of: key('payout-${row.bonus}'), matching: find.byType(Text)).evaluate()) {
          final r = tester.getRect(find.byWidget(t.widget));
          expect(r.left, greaterThanOrEqualTo(cell.left - 0.5), reason: '${(t.widget as Text).data} in ${row.bonus}');
          expect(r.right, lessThanOrEqualTo(cell.right + 0.5), reason: '${(t.widget as Text).data} in ${row.bonus}');
        }
      }
      await rig.finish();
    });
  });

  group('the phone\'s font-size setting changes nothing', () {
    testWidgets('at 3 times the text every size and the dialog\'s box stay the same', (tester) async {
      const size = Size(640, 360);
      final rig = BetRig(tester);
      await pumpAtSize(tester, size, host(rig.provider));
      await open(tester);
      final box = tester.getRect(dialog);
      final sizes = [for (final t in textsOfDialog(tester)) '${t.data}:${t.style!.fontSize}'];

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpAtSize(tester, size, host(rig.provider), textScale: 3);
      await open(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(dialog), box);
      expect([for (final t in textsOfDialog(tester)) '${t.data}:${t.style!.fontSize}'], sizes);
      for (final t in textsOfDialog(tester)) {
        expect(t.textScaler, TextScaler.noScaling, reason: '"${t.data}"');
      }
      await rig.finish();
    });
  });

  group('a screen reader', () {
    testWidgets('hears the dialog, both tabs with the chosen one marked, and the close button', (tester) async {
      final handle = tester.ensureSemantics();
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, host(rig.provider));
      await open(tester);
      expect(find.bySemanticsLabel('How to play'), findsWidgets);
      expect(find.bySemanticsLabel('Close'), findsWidgets);
      final rules = tester.getSemantics(find.bySemanticsLabel('RULES'));
      final payouts = tester.getSemantics(find.bySemanticsLabel('PAYOUTS'));
      expect(rules.getSemanticsData().flagsCollection.isSelected, ui.Tristate.isTrue);
      expect(payouts.getSemanticsData().flagsCollection.isSelected, ui.Tristate.isFalse);
      expect(rules.getSemanticsData().flagsCollection.isButton, isTrue);
      await tester.tap(key('info-tab-payouts'));
      await settle(tester);
      expect(tester.getSemantics(find.bySemanticsLabel('PAYOUTS')).getSemanticsData().flagsCollection.isSelected, ui.Tristate.isTrue);
      handle.dispose();
      await rig.finish();
    });
  });

  group('a picture to look at', () {
    Future<void> shoot(WidgetTester tester, Device d, String tab, String name) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, d.size, host(rig.provider));
      await open(tester);
      if (tab == 'payouts') {
        await tester.tap(key('info-tab-payouts'));
        await settle(tester);
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${d.width.toInt()}x${d.height.toInt()}.png'));
      await rig.finish();
    }

    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets('RULES: ${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) => shoot(tester, d, 'rules', 'info_rules'));
      testWidgets('PAYOUTS: ${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) => shoot(tester, d, 'payouts', 'info_payouts'));
    }
  });
}
