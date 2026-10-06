// Tests for lucky_card_readouts_binding.dart: the top bar, the status strip and the
// side column's readouts driven by the REAL Lucky Card provider, on the simulated
// server and the fake clock. Aisha bets, the countdown runs, betting closes, the
// wheel turns, the card is shown, she wins, and the next round opens: at every
// moment the screen must say what the provider holds, and no more often than needed.

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/services/lucky_card_round_sync.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_panel.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_readouts.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_readouts_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_status_strip.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_wheel_binding.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_wallet.dart';
import '../provider_rig.dart';
import '../sim_server.dart';
import 'ui_harness.dart';

const Size phone = Size(844, 390);

final LuckyCard winner = SimulatedLuckyCardServer.winnerOf(cycle);
final int bonus = SimulatedLuckyCardServer.bonusOf(cycle);

class Presses {
  int exit = 0, sound = 0, info = 0;
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

Widget scene(
  LuckyCardProvider provider, {
  Presses? presses,
  bool soundOn = true,
  LuckyCardArt art = const FileLuckyCardArt(),
}) =>
    LuckyCardCanvas(
      // The real wheel, so the card lands and is revealed when it does on a phone.
      grid: (context, layout) => LuckyCardWheelBinding(provider: provider, layout: layout),
      topBar: (context, layout) => LuckyCardTopBarBinding(
        provider: provider,
        layout: layout,
        soundOn: soundOn,
        onExit: presses == null ? null : () => presses.exit++,
        onToggleSound: presses == null ? null : () => presses.sound++,
        onInfo: presses == null ? null : () => presses.info++,
      ),
      status: (context, layout) => LuckyCardStatusBinding(provider: provider, layout: layout),
      side: (context, layout) => LuckyCardSideReadouts(provider: provider, layout: layout, art: art),
    );

Finder key(String k) => find.byKey(ValueKey(k));

List<String> textsIn(WidgetTester tester, String k) => [
      for (final t in tester.widgetList<Text>(find.descendant(of: key(k), matching: find.byType(Text)))) t.data!,
    ];

String balanceText(WidgetTester tester) => textsIn(tester, 'top-balance').single;
String countdownText(WidgetTester tester) => textsIn(tester, 'top-countdown').single;
String playText(WidgetTester tester) => textsIn(tester, 'play').last;
String winText(WidgetTester tester) => textsIn(tester, 'win').last;
String statusText(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byType(LuckyCardStatusStrip), matching: find.byType(Text))).data!;

/// True while the Info button is dimmed (disabled).
bool infoDimmed(WidgetTester tester) =>
    find.descendant(of: key('top-info'), matching: find.byType(Opacity)).evaluate().isNotEmpty;

double statusOpacity(WidgetTester tester) => tester
    .widget<Opacity>(find.descendant(of: find.byType(LuckyCardStatusStrip), matching: find.byType(Opacity)).last)
    .opacity;

/// What the results panel shows, latest first: "Q4X" style (rank then bonus label).
List<String> resultsShown(WidgetTester tester) => [
      for (final k in ['result-latest', for (var i = 0; i < 9; i++) 'result-$i']) textsIn(tester, k).join(),
    ];

/// What the provider's history says the panel must show.
List<String> resultsExpected(LuckyCardProvider p) => [
      for (var i = 0; i < 10; i++)
        i < p.history.length
            ? '${p.history[i].winningCard.rank.dbValue}${luckyCardBonusLabel(p.history[i].bonusMultiplier)}'
            : '',
    ];

void main() {
  setUpAll(() async {
    await loadLuckyCardFonts();
    await loadLuckyCardIcons();
  });

  group('Aisha plays a whole round and wins', () {
    testWidgets('every readout says what the provider holds, from the first bet to the next round', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider, presses: Presses()));
      await rig.open();
      final p = rig.provider;

      // The table is open. The words, the balance, the countdown and the history.
      expect(statusText(tester), 'PLACE YOUR CHIPS');
      expect(balanceText(tester), '1,000');
      expect(countdownText(tester), luckyCardCountdownText(p.countdown));
      expect(p.countdown, inInclusiveRange(40, 50), reason: 'the rig starts 40 s into the round');
      expect(infoDimmed(tester), isFalse, reason: 'Info works while betting is open');
      expect(playText(tester), '0');
      expect(winText(tester), '0');
      expect(resultsShown(tester), resultsExpected(p), reason: 'the strip is the provider\'s history');
      final before = resultsShown(tester);

      // She puts 10 on every card: a stake of 120 leaves her balance.
      rig.betTenOnEveryCard();
      await tester.pump();
      expect(playText(tester), '120');
      expect(balanceText(tester), '880');

      // The countdown ticks once a second.
      final c0 = countdownText(tester);
      await rig.world.run(const Duration(seconds: 3));
      expect(countdownText(tester), isNot(c0));
      expect(countdownText(tester), luckyCardCountdownText(p.countdown));

      // Betting is open to the last moment before the lock.
      await rig.world.runUntil(84.0);
      expect(p.isLocked, isFalse);
      expect(statusText(tester), 'PLACE YOUR CHIPS');
      expect(infoDimmed(tester), isFalse);

      // The very moment of the lock: Info is dimmed at once, not at the next tick.
      var guard = 0;
      while (!p.isLocked && ++guard < 400) {
        await rig.world.run(const Duration(milliseconds: 50));
      }
      expect(p.isLocked, isTrue);
      expect(infoDimmed(tester), isTrue, reason: 'dimmed as soon as betting closes');
      expect(statusText(tester), 'NO MORE PLAY');

      // The lock at 5: the words change, flash, and Info is dimmed.
      await rig.world.runUntil(86.0);
      expect(p.isLocked, isTrue);
      expect(p.countdown, inInclusiveRange(1, 5));
      expect(statusText(tester), 'NO MORE PLAY');
      expect(infoDimmed(tester), isTrue);
      final seen = <double>{};
      for (var i = 0; i < 8; i++) {
        seen.add(double.parse(statusOpacity(tester).toStringAsFixed(2)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(seen.length, greaterThan(3), reason: 'the words flash from 5 to 1');
      expect(playText(tester), '120', reason: 'the stake stays on the screen while the round plays');

      // From 0 on: the same words, steady (no flash), through the wheel and the reveal.
      await rig.world.runUntil(90.6);
      expect(p.countdown, 0);
      expect(countdownText(tester), '00');
      expect(statusText(tester), 'NO MORE PLAY');
      for (var i = 0; i < 6; i++) {
        expect(statusOpacity(tester), 1.0, reason: 'steady at 00');
        await tester.pump(const Duration(milliseconds: 150));
      }
      await rig.world.runUntil(92.0);
      expect(p.stage, LuckyCardStage.spinning);
      expect(statusText(tester), 'NO MORE PLAY');
      expect(statusOpacity(tester), 1.0, reason: 'steady while the wheel turns');
      expect(resultsShown(tester), before, reason: 'the winner is not in the strip before the wheel lands');
      expect(winText(tester), '0');
      expect(balanceText(tester), '880', reason: 'the balance does not move before the card is shown');

      // The suit rim lands: the card is revealed and the numbers arrive together.
      await rig.world.runUntil(98.0);
      expect(p.cardRevealed, isTrue);
      final payout = 10 * 10 * bonus;
      expect(winText(tester), '+$payout');
      final winCell = tester.widget<LuckyCardAmountCell>(key('win'));
      expect(winCell.highlighted, isTrue, reason: 'a win lights its cell');
      expect(winCell.valueColor, kLuckyCardWin);
      expect(balanceText(tester), luckyCardGrouped(880 + payout));
      expect(resultsShown(tester).first, '${winner.rank.dbValue}${luckyCardBonusLabel(bonus)}', reason: 'the latest tile is the winner');
      expect(resultsShown(tester), resultsExpected(p));
      expect(resultsShown(tester).sublist(1), before.sublist(0, 9), reason: 'the others moved one place down');
      expect(playText(tester), '120', reason: 'the board stays until the round ends');

      // The round ends. Between its end and the next round the table is still closed,
      // with nothing playing: the words stay, and they do not flash.
      var wait = 0;
      while (p.isSequenceRunning && ++wait < 600) {
        await rig.world.run(const Duration(milliseconds: 50));
      }
      expect(p.isSequenceRunning, isFalse);
      expect(p.isLocked, isTrue, reason: 'still closed until the next round begins');
      expect(p.stage, LuckyCardStage.none);
      expect(statusText(tester), 'NO MORE PLAY');
      expect(luckyCardStatusModeOf(p), LuckyCardStatusMode.noMoreSteady, reason: 'closed, nothing playing, not the last seconds');
      for (var i = 0; i < 4; i++) {
        expect(statusOpacity(tester), 1.0, reason: 'steady between rounds');
        await tester.pump(const Duration(milliseconds: 150));
      }

      // The board is cleared; the win stays until she touches the board.
      await rig.runIntoNextCycle(2);
      expect(p.stage, LuckyCardStage.none);
      expect(playText(tester), '0');
      expect(winText(tester), '+$payout');

      // The next round is open: the words come back, Info works.
      await rig.world.runUntil(8);
      expect(p.isLocked, isFalse);
      expect(statusText(tester), 'PLACE YOUR CHIPS');
      expect(infoDimmed(tester), isFalse);
      expect(winText(tester), '+$payout', reason: 'still there');

      // She puts a chip down: the old win goes.
      p.selectChip(LuckyCardChip.five);
      p.tapCard(winner);
      await tester.pump();
      expect(winText(tester), '0');
      expect(playText(tester), '5');
      await rig.finish();
    });

    testWidgets('a loser: WIN stays 0, the winner still arrives in the strip', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider));
      await rig.open();
      final p = rig.provider;
      // 10 on one card that is not the winner.
      final other = LuckyCard.all.firstWhere((c) => c != winner);
      p.selectChip(LuckyCardChip.ten);
      p.tapCard(other);
      await tester.pump();
      expect(playText(tester), '10');

      await rig.world.runUntil(98.0);
      expect(p.cardRevealed, isTrue);
      expect(winText(tester), '0');
      expect(balanceText(tester), '990');
      expect(resultsShown(tester).first, '${winner.rank.dbValue}${luckyCardBonusLabel(bonus)}');
      await rig.finish();
    });

    testWidgets('a spectator with no chips sees the same strip and the same words', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider));
      await rig.open();
      final p = rig.provider;
      await rig.world.runUntil(86.0);
      expect(statusText(tester), 'NO MORE PLAY');
      await rig.world.runUntil(98.0);
      expect(winText(tester), '0');
      expect(playText(tester), '0');
      expect(balanceText(tester), '1,000');
      expect(resultsShown(tester).first, '${winner.rank.dbValue}${luckyCardBonusLabel(bonus)}');
      expect(resultsShown(tester), resultsExpected(p));
      await rig.finish();
    });
  });

  group('the snapshots that decide a redraw', () {
    LuckyCardRecentRound r(String id, int bonus) => LuckyCardRecentRound(
          roundId: id,
          roundNumber: 1,
          winningCard: winner,
          bonusMultiplier: bonus,
          scheduledAt: DateTime.utc(2026, 10, 6),
        );

    test('the top bar changes when the balance, the countdown or Info changes, and only then', () {
      const base = LuckyCardTopBarSnapshot(balance: 100, countdown: 40, infoEnabled: true);
      expect(base, const LuckyCardTopBarSnapshot(balance: 100, countdown: 40, infoEnabled: true));
      expect(base == const LuckyCardTopBarSnapshot(balance: 101, countdown: 40, infoEnabled: true), isFalse);
      expect(base == const LuckyCardTopBarSnapshot(balance: 100, countdown: 39, infoEnabled: true), isFalse);
      expect(base == const LuckyCardTopBarSnapshot(balance: 100, countdown: 40, infoEnabled: false), isFalse);
    });

    test('the results change when a round is added or a bonus differs, and not otherwise', () {
      final a = LuckyCardResultsSnapshot([r('x', 4), r('y', 1)]);
      expect(a, LuckyCardResultsSnapshot([r('x', 4), r('y', 1)]));
      expect(a == LuckyCardResultsSnapshot([r('z', 4), r('y', 1)]), isFalse, reason: 'another round with the same bonus');
      expect(a == LuckyCardResultsSnapshot([r('x', 5), r('y', 1)]), isFalse, reason: 'the same round, another bonus');
      expect(a == LuckyCardResultsSnapshot([r('x', 4)]), isFalse, reason: 'fewer rounds');
      expect(a == LuckyCardResultsSnapshot([r('x', 4), r('y', 1), r('w', 1)]), isFalse, reason: 'more rounds');
    });
  });

  group('the status words, from the provider state', () {
    testWidgets('betting open, the last seconds, the draw and the sequence', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider));
      await rig.open();
      final p = rig.provider;
      expect(luckyCardStatusModeOf(p), LuckyCardStatusMode.placeChips);
      await rig.world.runUntil(86.0);
      expect(luckyCardStatusModeOf(p), LuckyCardStatusMode.noMoreFlashing);
      await rig.world.runUntil(90.6);
      expect(luckyCardStatusModeOf(p), LuckyCardStatusMode.noMoreSteady, reason: 'at 00');
      await rig.world.runUntil(92.0);
      expect(luckyCardStatusModeOf(p), LuckyCardStatusMode.noMoreSteady, reason: 'spinning');
      await rig.world.runUntil(98.0);
      expect(luckyCardStatusModeOf(p), LuckyCardStatusMode.noMoreSteady, reason: 'revealing');
      await rig.finish();
    });
  });

  group('the binding places every piece where the layout says', () {
    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets(d.name, (tester) async {
        final rig = BetRig(tester);
        await pumpAtSize(tester, d.size, scene(rig.provider));
        await rig.open();
        final l = LuckyCardLayout.of(d.size);
        final expected = {
          'top-balance': l.balanceBox,
          'top-countdown': l.countdownBox,
          'top-exit': l.exitHit,
          'top-sound': l.soundHit,
          'top-info': l.infoHit,
          'play': l.playCell,
          'win': l.winCell,
          'limits': l.limitsPanel,
          'result-latest': l.resultCurrent,
          for (var i = 0; i < 9; i++) 'result-$i': l.resultTile(i),
        };
        for (final e in expected.entries) {
          final got = tester.getRect(key(e.key));
          final want = e.value.shift(l.canvasRect.topLeft);
          expect(got.left, closeTo(want.left, 0.01), reason: '${e.key} left');
          expect(got.top, closeTo(want.top, 0.01), reason: '${e.key} top');
          expect(got.width, closeTo(want.width, 0.01), reason: '${e.key} width');
          expect(got.height, closeTo(want.height, 0.01), reason: '${e.key} height');
        }
        final strip = tester.getRect(find.byType(LuckyCardStatusStrip));
        expect(strip.topLeft, l.status.shift(l.canvasRect.topLeft).topLeft);
        expect(strip.size, l.status.size);
        await rig.finish();
      });
    }
  });

  group('it redraws only what changed', () {
    testWidgets('a tick of the countdown redraws the top bar and nothing else', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider));
      await rig.open();
      Widget? widgetOf(String k) => tester.widget(key(k));
      final play = widgetOf('play');
      final win = widgetOf('win');
      final results = widgetOf('result-latest');
      final strip = tester.widget(find.byType(LuckyCardStatusStrip));
      final countdown = widgetOf('top-countdown');

      await rig.world.run(const Duration(seconds: 3));
      expect(identical(widgetOf('top-countdown'), countdown), isFalse, reason: 'the countdown moved');
      expect(identical(widgetOf('play'), play), isTrue, reason: 'PLAY did not');
      expect(identical(widgetOf('win'), win), isTrue, reason: 'WIN did not');
      expect(identical(widgetOf('result-latest'), results), isTrue, reason: 'the results did not');
      expect(identical(tester.widget(find.byType(LuckyCardStatusStrip)), strip), isTrue, reason: 'the words did not');
      await rig.finish();
    });

    testWidgets('a chip redraws PLAY and the balance, not the results, the words or WIN', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider));
      await rig.open();
      final play = tester.widget(key('play'));
      final win = tester.widget(key('win'));
      final results = tester.widget(key('result-latest'));
      final strip = tester.widget(find.byType(LuckyCardStatusStrip));
      final balance = tester.widget(key('top-balance'));

      rig.provider.selectChip(LuckyCardChip.fifty);
      rig.provider.tapCard(winner);
      await tester.pump();
      expect(identical(tester.widget(key('play')), play), isFalse);
      expect(identical(tester.widget(key('top-balance')), balance), isFalse);
      expect(identical(tester.widget(key('win')), win), isTrue);
      expect(identical(tester.widget(key('result-latest')), results), isTrue);
      expect(identical(tester.widget(find.byType(LuckyCardStatusStrip)), strip), isTrue);
      await rig.finish();
    });
  });

  group('the buttons of the top bar reach the screen', () {
    testWidgets('Exit, Sound and Info call their callbacks; Info does not while betting is closed', (tester) async {
      final rig = BetRig(tester);
      final presses = Presses();
      await pumpAtSize(tester, phone, scene(rig.provider, presses: presses));
      await rig.open();

      await tester.tap(key('top-exit'));
      await tester.tap(key('top-sound'));
      await tester.tap(key('top-info'));
      await tester.pump();
      expect([presses.exit, presses.sound, presses.info], [1, 1, 1]);

      await rig.world.runUntil(86.0);
      await tester.tap(key('top-info'));
      await tester.tap(key('top-exit'));
      await tester.pump();
      expect([presses.exit, presses.sound, presses.info], [2, 1, 1], reason: 'Info ignored the tap at the lock; Exit did not');

      await rig.runIntoNextCycle(8);
      await tester.tap(key('top-info'));
      await tester.pump();
      expect(presses.info, 2, reason: 'Info works again in the next round');
      await rig.finish();
    });

    testWidgets('the sound button follows the screen\'s own setting', (tester) async {
      final rig = BetRig(tester);
      await pumpAtSize(tester, phone, scene(rig.provider, soundOn: false));
      await rig.open();
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      await pumpAtSize(tester, phone, scene(rig.provider, soundOn: true));
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      await rig.finish();
    });
  });

  group('listeners', () {
    testWidgets('everything stops listening when the screen goes away', (tester) async {
      final rig = BetRig(tester);
      final probe = ProbeProvider(rig);
      await pumpAtSize(tester, phone, scene(probe));
      expect(probe.listenedTo, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(probe.listenedTo, isFalse, reason: 'no listener is left behind');
      probe.dispose();
      await rig.finish();
    });

    testWidgets('given another provider, every readout follows the new one and lets go of the old', (tester) async {
      final rig = BetRig(tester);
      final a = ProbeProvider(rig);
      final b = ProbeProvider(rig);
      b.selectChip(LuckyCardChip.fifty);
      b.tapCard(winner);

      await pumpAtSize(tester, phone, scene(a));
      expect(playText(tester), '0');
      expect(balanceText(tester), '1,000');

      await pumpAtSize(tester, phone, scene(b));
      expect(playText(tester), '50', reason: 'PLAY shows the new provider at once');
      expect(balanceText(tester), '950');
      expect(a.listenedTo, isFalse);
      expect(b.listenedTo, isTrue);

      b.tapCard(winner);
      await tester.pump();
      expect(playText(tester), '100', reason: 'and keeps following it');
      a.dispose();
      b.dispose();
      await rig.finish();
    });
  });

  group('every device', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name}: the live screen builds with no overflow, 11 dp text and 48 dp buttons', (tester) async {
        final rig = BetRig(tester);
        await pumpAtSize(tester, d.size, scene(rig.provider, presses: Presses()));
        await rig.open();
        rig.betTenOnEveryCard();
        await rig.world.runUntil(98.0);
        expect(tester.takeException(), isNull);
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          expect(t.style!.fontSize, greaterThanOrEqualTo(11), reason: '"${t.data}"');
        }
        for (final k in ['top-exit', 'top-sound', 'top-info']) {
          final size = tester.getSize(find.descendant(of: key(k), matching: find.byType(GestureDetector)).first);
          expect(size.width, greaterThanOrEqualTo(48), reason: k);
          expect(size.height, greaterThanOrEqualTo(48), reason: k);
        }
        await rig.finish();
      });
    }
  });
}
