// Tests for lib/widgets/lucky_card/lucky_card_board_binding.dart: the board driven
// by the REAL Lucky Card provider, on the simulated server and the fake clock.
// What the player sees, taps and pays is checked end to end: the screen, the
// provider's board and the wallet must agree.

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/services/lucky_card_round_sync.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_board_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_board_view.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_wallet.dart';
import '../provider_rig.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

Finder suit(LuckyCardSuit s) => find.byKey(ValueKey('suit-${s.dbValue}'));
Finder rank(LuckyCardRank r) => find.byKey(ValueKey('rank-${r.dbValue}'));
Finder card(LuckyCard cd) => find.byKey(ValueKey(cd.key));

/// The numbers on a header or selector, without its name.
List<String> totalsOn(WidgetTester tester, Finder of, String name) => [
      for (final t in tester.widgetList<Text>(find.descendant(of: of, matching: find.byType(Text))))
        if (t.data != name) t.data!,
    ];

class Counter {
  int builds = 0;
}

Widget binding(
  LuckyCardProvider provider, {
  Counter? counter,
  LuckyCardBoardRefused? onRefused,
}) =>
    LuckyCardBoardBinding(
      provider: provider,
      art: const FileLuckyCardArt(),
      onRefused: onRefused,
      builder: (context, zones) {
        counter?.builds++;
        return LuckyCardCanvas(grid: zones.grid, rankColumn: zones.rankColumn);
      },
    );

void main() {
  setUpAll(loadLuckyCardFonts);

  group('the spec example, through the real provider', () {
    testWidgets('Aisha: the 10 chip on the Hearts bar, then the 5 chip on the J selector', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, binding(rig.provider));
      await rig.open();
      final p = rig.provider;

      // Step 1: the 10 chip on the Hearts bar puts 10 on J♥, Q♥ and K♥.
      p.selectChip(LuckyCardChip.ten);
      await tester.pump();
      await tester.tap(suit(LuckyCardSuit.hearts));
      await tester.pump();
      expect(p.total, 30);
      expect(rig.wallet.balance, 970, reason: 'the coins left her balance');
      expect(totalsOn(tester, suit(LuckyCardSuit.hearts), 'Hearts'), ['30']);
      expect(totalsOn(tester, suit(LuckyCardSuit.spades), 'Spades'), isEmpty, reason: 'blank at 0');
      for (final r in LuckyCardRank.values) {
        expect(totalsOn(tester, rank(r), luckyCardRankName(r)), ['10'], reason: r.dbValue);
      }

      // Step 2: the 5 chip on the J selector puts 5 on all four jacks.
      p.selectChip(LuckyCardChip.five);
      await tester.pump();
      await tester.tap(rank(LuckyCardRank.jack));
      await tester.pump();
      expect(p.total, 50);
      expect(rig.wallet.balance, 950);
      expect(totalsOn(tester, suit(LuckyCardSuit.hearts), 'Hearts'), ['35']);
      for (final s in [LuckyCardSuit.spades, LuckyCardSuit.diamonds, LuckyCardSuit.clubs]) {
        expect(totalsOn(tester, suit(s), s.label), ['5'], reason: s.dbValue);
      }
      expect(totalsOn(tester, rank(LuckyCardRank.jack), 'Jacks'), ['30']);
      expect(totalsOn(tester, rank(LuckyCardRank.queen), 'Queens'), ['10']);
      expect(totalsOn(tester, rank(LuckyCardRank.king), 'Kings'), ['10']);

      LuckyCard cd(LuckyCardRank r, LuckyCardSuit s) => LuckyCard(r, s);
      String onCard(LuckyCard c) => tester.widget<Text>(find.descendant(of: card(c), matching: find.byType(Text))).data!;
      expect(onCard(cd(LuckyCardRank.jack, LuckyCardSuit.hearts)), '15', reason: 'the chips stacked on J♥');
      expect(onCard(cd(LuckyCardRank.jack, LuckyCardSuit.spades)), '5');
      expect(onCard(cd(LuckyCardRank.queen, LuckyCardSuit.hearts)), '10');
      expect(onCard(cd(LuckyCardRank.queen, LuckyCardSuit.spades)), 'Play');
      expect(onCard(cd(LuckyCardRank.king, LuckyCardSuit.clubs)), 'Play');
      await rig.finish();
    });

    testWidgets('with no chip in hand a tap takes chips back, and the screen and the wallet follow', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, binding(rig.provider));
      await rig.open();
      final p = rig.provider;
      p.selectChip(LuckyCardChip.fifty);
      await tester.pump();
      await tester.tap(suit(LuckyCardSuit.hearts));
      await tester.pump();
      expect(p.total, 150);
      expect(rig.wallet.balance, 850);

      p.deselectChip();
      await tester.pump();
      await tester.tap(suit(LuckyCardSuit.hearts));
      await tester.pump();
      expect(p.total, 0);
      expect(rig.wallet.balance, 1000);
      expect(totalsOn(tester, suit(LuckyCardSuit.hearts), 'Hearts'), isEmpty);
      expect(find.text('Play'), findsNWidgets(12));
      await rig.finish();
    });
  });

  group('a tap the provider refuses', () {
    testWidgets('not enough coins: the piece flashes, the screen is told which and why, the wallet is untouched', (tester) async {
      final rig = BetRig(tester, startBalance: 100);
      final refusals = <(LuckyCardBoardTarget, Set<LuckyCardBoardIssue>)>[];
      await pumpAtSize(tester, phone, binding(rig.provider, onRefused: (t, i) => refusals.add((t, i))));
      await rig.open();
      rig.provider.selectChip(LuckyCardChip.fiveHundred);
      await tester.pump();

      await tester.tap(card(LuckyCard.all.first));
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.descendant(of: card(LuckyCard.all.first), matching: find.byType(ColorFiltered)), findsOneWidget);
      expect(refusals.single.$1, LuckyCardCardTarget(LuckyCard.all.first));
      expect(refusals.single.$2, {LuckyCardBoardIssue.notEnoughCoins});
      expect(rig.wallet.balance, 100);
      expect(rig.provider.total, 0);

      await tester.tap(rank(LuckyCardRank.king));
      expect(refusals.last.$1, const LuckyCardRankTarget(LuckyCardRank.king));
      expect(refusals.last.$2, contains(LuckyCardBoardIssue.notEnoughCoins));
      await rig.finish();
    });
  });

  group('the lock', () {
    testWidgets('at countdown 5 every piece is dimmed and taps do nothing; the next round unlocks them', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, binding(rig.provider));
      await rig.open();
      final p = rig.provider;
      p.selectChip(LuckyCardChip.ten);
      await tester.pump();
      expect(find.byType(Opacity), findsNothing);

      await rig.world.runUntil(86.0);
      await tester.pump();
      expect(p.isLocked, isTrue);
      expect(find.byType(Opacity), findsNWidgets(19));
      await tester.tap(suit(LuckyCardSuit.hearts));
      await tester.tap(rank(LuckyCardRank.jack));
      await tester.tap(card(LuckyCard.all.first));
      await tester.pump();
      expect(p.total, 0);
      expect(rig.wallet.balance, 1000);

      await rig.runIntoNextCycle(5.0);
      await tester.pump();
      expect(p.isLocked, isFalse);
      expect(find.byType(Opacity), findsNothing);
      await tester.tap(card(LuckyCard.all.first));
      await tester.pump();
      expect(p.total, 10);
      await rig.finish();
    });
  });

  group('redrawing', () {
    testWidgets('the countdown ticks every second but the board is not redrawn while nothing on it changes', (tester) async {
      final rig = BetRig(tester);
      final counter = Counter();
      await pumpAtSize(tester, phone, binding(rig.provider, counter: counter));
      await rig.open();
      await tester.pump();
      final before = counter.builds;
      var notifications = 0;
      rig.provider.addListener(() => notifications++);

      await rig.world.run(const Duration(seconds: 5));
      expect(notifications, greaterThanOrEqualTo(3), reason: 'the provider really did notify on the ticks');
      expect(counter.builds, before, reason: 'and the board was not rebuilt');

      rig.provider.selectChip(LuckyCardChip.five);
      rig.provider.tapCard(LuckyCard.all.first);
      await tester.pump();
      expect(counter.builds, before + 1, reason: 'a chip placed redraws it once');
      await rig.finish();
    });

    testWidgets('after the board is taken off the screen, the provider can change without a trace', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, binding(rig.provider));
      await rig.open();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      rig.provider.selectChip(LuckyCardChip.five);
      rig.provider.tapCard(LuckyCard.all.first);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await rig.finish();
    });

    testWidgets('given another provider it follows that one and lets go of the first', (tester) async {
      final rig = BetRig(tester);
      final other = LuckyCardProvider(
        api: rig.server,
        wallet: FakeWallet(500),
        sync: LuckyCardRoundSync(api: rig.server, now: () => rig.world.deviceNow),
      );
      await pumpAtSize(tester, phone, binding(rig.provider));
      await rig.open();
      rig.provider.selectChip(LuckyCardChip.ten);
      rig.provider.tapCard(LuckyCard.all.first);
      await tester.pump();
      expect(find.text('10'), findsWidgets);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: binding(other))));
      expect(find.text('Play'), findsNWidgets(12), reason: 'the second provider has an empty board');
      other.selectChip(LuckyCardChip.fifty);
      other.tapCard(LuckyCard.all.last);
      await tester.pump();
      expect(find.text('50'), findsWidgets);

      rig.provider.tapCard(LuckyCard.all[1]);
      await tester.pump();
      expect(find.text('50'), findsWidgets, reason: 'the first provider no longer drives the screen');
      expect(tester.takeException(), isNull);
      other.dispose();
      await rig.finish();
    });
  });
}
