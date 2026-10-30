// Tests for the Lucky 16 Card betting board (phone phase 2): the four suit bars over the 16 cards
// and the four rank selectors, on the real screen (lib/screens/lucky16_screen.dart) over the
// simulated server, driven only through taps. The whole screen's golden pictures are drawn by
// lucky16_panel_test.dart (phase 2's board-only pictures stay in reference-design/lucky16/screenshots/phase2/
// as a record).

import 'package:best_smart_game/models/lucky16_board.dart';
import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_layout.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_tap_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../provider_rig.dart';
import 'lucky16_screen_test.dart' show art, key, openGame, phone, settle, textIn;
import 'ui_harness.dart';

const Lucky16Card aceHearts = Lucky16Card(Lucky16Rank.ace, Lucky16Suit.hearts);

Future<void> loadArt(WidgetTester tester) async => art = (await tester.runAsync(PreloadedLucky16Art.load))!;

/// [actual] is [expected] to within a hundredth of a dp on every edge.
void expectNear(Rect actual, Rect expected, [String? reason]) {
  for (final (a, e) in [
    (actual.left, expected.left),
    (actual.top, expected.top),
    (actual.right, expected.right),
    (actual.bottom, expected.bottom),
  ]) {
    expect(a, closeTo(e, 0.01), reason: reason);
  }
}

/// Taps the piece with key [k] and lets its pulse finish.
Future<void> tapPiece(WidgetTester tester, String k) async {
  await tester.tap(key(k));
  await settle(tester);
}

/// Runs the round on until betting has closed.
Future<void> runToLock(WidgetTester tester, BetRig rig) async {
  var guard = 0;
  while (!rig.provider.isLocked && ++guard < 2000) {
    await rig.world.run(const Duration(milliseconds: 500));
  }
  await settle(tester);
}

void main() {
  setUpAll(() async {
    await loadLucky16Fonts();
    await loadLucky16Icons();
  });

  testWidgets('every piece is where the layout says: 4 bars, 16 cards in rows A, J, Q, K, 4 selectors', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    final layout = Lucky16Layout.of(phone);
    for (final suit in Lucky16Suit.values) {
      expectNear(tester.getRect(key('suit-${suit.dbValue}')), layout.suitHeader(suit.index));
    }
    for (final card in Lucky16Card.all) {
      expectNear(tester.getRect(key(card.key)), layout.cardCell(card.suit.index, card.rank.index), card.key);
    }
    for (final rank in Lucky16Rank.values) {
      expectNear(tester.getRect(key('rank-${rank.dbValue}')), layout.rankSelector(rank.index));
    }
    // Empty: every card says Play, a bar its suit's name, a selector its rank's name.
    expect(textIn(tester, aceHearts.key), 'Play');
    expect(textIn(tester, 'suit-diamonds'), 'DIAMONDS');
    expect(textIn(tester, 'rank-A'), 'ACES');
    await rig.finish();
  });

  testWidgets('a card takes the chip in hand (5 until the chips exist), and its bar and selector add it up',
      (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    await tapPiece(tester, aceHearts.key);
    await tapPiece(tester, aceHearts.key);
    expect(rig.provider.stakeOn(aceHearts), 10);
    expect(textIn(tester, aceHearts.key), '10');
    expect(textIn(tester, 'suit-hearts'), '10');
    expect(textIn(tester, 'rank-A'), '10');
    expect(textIn(tester, 'top-balance'), '990');
    await rig.finish();
  });

  testWidgets('the Hearts bar puts the chip on its 4 cards, the A selector on the 4 aces', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    rig.provider.selectChip(Lucky16Chip.ten);
    await tapPiece(tester, 'suit-hearts');
    for (final card in Lucky16Card.ofSuit(Lucky16Suit.hearts)) {
      expect(rig.provider.stakeOn(card), 10, reason: card.key);
    }
    expect(textIn(tester, 'suit-hearts'), '40');
    await tapPiece(tester, 'rank-A');
    for (final card in Lucky16Card.ofRank(Lucky16Rank.ace)) {
      expect(textIn(tester, card.key), card == aceHearts ? '20' : '10', reason: card.key);
    }
    expect(textIn(tester, 'rank-A'), '50');
    expect(textIn(tester, 'suit-hearts'), '50');
    expect(textIn(tester, 'rank-K'), '10');
    expect(rig.provider.total, 80);
    await rig.finish();
  });

  testWidgets('a card stops at 10,000: the next chip is refused and the card flashes', (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester, startBalance: 50000);
    await openGame(tester, rig);
    rig.provider.selectChip(Lucky16Chip.fiveHundred);
    for (var i = 0; i < 20; i++) {
      await tapPiece(tester, aceHearts.key);
    }
    expect(rig.provider.stakeOn(aceHearts), kLucky16MaxStake);
    expect(textIn(tester, aceHearts.key), '10000', reason: 'written in full, never shortened');
    await tester.tap(key(aceHearts.key));
    await tester.pump();
    expect(rig.provider.stakeOn(aceHearts), kLucky16MaxStake);
    expect(find.descendant(of: key(aceHearts.key), matching: find.byType(ColorFiltered)), findsOneWidget,
        reason: 'the refusal flash');
    await settle(tester);
    // A bar over a full card places on the other three only.
    await tapPiece(tester, 'suit-hearts');
    expect(rig.provider.stakeOn(aceHearts), kLucky16MaxStake);
    expect(rig.provider.stakeOn(const Lucky16Card(Lucky16Rank.king, Lucky16Suit.hearts)), 500);
    await rig.finish();
  });

  testWidgets('a locked board piece is dimmed and ignores taps (the look the board keeps if it is ever shown locked)',
      (tester) async {
    var taps = 0;
    await pumpAtSize(
      tester,
      phone,
      Lucky16TapTarget(
        key: const ValueKey('piece'),
        size: const Size(100, 70),
        semanticsLabel: 'a card',
        isLocked: true,
        onTap: () {
          taps++;
          return const Lucky16BoardResult();
        },
        content: (context, tinted) => tinted(const ColoredBox(color: Color(0xFFAA0000))),
      ),
    );
    final dim = tester.widget<Opacity>(find.descendant(of: key('piece'), matching: find.byType(Opacity)).first);
    expect(dim.opacity, 0.55);
    await tester.tap(key('piece'));
    expect(taps, 0);
  });

  testWidgets('when betting closes the board fades out for the wheel (phase 4) and takes no more chips',
      (tester) async {
    await loadArt(tester);
    final rig = BetRig(tester);
    await openGame(tester, rig);
    await tapPiece(tester, aceHearts.key);
    var guard = 0;
    while (!rig.provider.isLocked && ++guard < 2000) {
      await rig.world.run(const Duration(milliseconds: 100));
    }
    await tester.pump();
    expect(rig.provider.isLocked, isTrue);
    // During its 220 ms fade the board is still on screen (with its last look, as Lucky Card's phone
    // board): a tap on it is refused by the locked board, and the shortcuts change nothing.
    final before = rig.provider.total;
    if (key(aceHearts.key).evaluate().isNotEmpty) await tester.tap(key(aceHearts.key));
    expect(rig.provider.tapSuit(Lucky16Suit.spades).changedAnything, isFalse);
    expect(rig.provider.tapRank(Lucky16Rank.queen).changedAnything, isFalse);
    expect(rig.provider.total, before);
    await settle(tester);
    expect(key(aceHearts.key), findsNothing, reason: 'the wheel has taken the board\'s place');
    await rig.finish();
  });
}
