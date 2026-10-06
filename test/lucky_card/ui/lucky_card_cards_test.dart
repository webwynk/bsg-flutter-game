// Tests for lib/widgets/lucky_card/lucky_card_cards.dart: the 12 cards at every
// device of the matrix, what a tap does, the pulse and the flash, the locked look,
// the screen-reader labels, and a picture of the board with the real artwork.

import 'dart:ui' as ui;

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_board_snapshot.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_cards.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

final LuckyCard jh = LuckyCard.all[0]; // J of hearts
final LuckyCard qs = LuckyCard.all[5]; // Q of spades
final LuckyCard kc = LuckyCard.all[11]; // K of clubs

Finder cell(LuckyCard c) => find.byKey(ValueKey(c.key));
Finder textIn(LuckyCard c) => find.descendant(of: cell(c), matching: find.byType(Text));

/// Aisha's board: 10 on most cards, J of hearts at 15, K of clubs at 50000, three
/// cards still empty.
LuckyCardBoardSnapshot aisha({bool isLocked = false}) => LuckyCardBoardSnapshot.fromStakes(
      {
        for (final c in LuckyCard.all) c: 10,
        jh: 15,
        kc: 50000,
        qs: 0,
        LuckyCard.all[6]: 0,
        LuckyCard.all[10]: 0,
      },
      isLocked: isLocked,
      activeChip: LuckyCardChip.ten,
    );

Widget board(
  LuckyCardBoardSnapshot snapshot, {
  LuckyCardCardTap? onTap,
  LuckyCardRefusedTap? onRefused,
  LuckyCardArt art = const FileLuckyCardArt(),
}) =>
    LuckyCardCanvas(
      grid: (context, layout) => LuckyCardCardLayer(
        layout: layout,
        art: art,
        snapshot: snapshot,
        onTapCard: onTap ?? (_) => const LuckyCardBoardResult(),
        onRefused: onRefused,
      ),
    );

LuckyCardBoardResult changed(LuckyCard c) => LuckyCardBoardResult(coinsSpent: 10, changed: [c]);
LuckyCardBoardResult refused(Set<LuckyCardBoardIssue> issues) => LuckyCardBoardResult(issues: issues);

void main() {
  setUpAll(loadLuckyCardFonts);

  group('every device of the matrix', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): 12 cards, each at least 48 dp to tap, text at least 11 dp, centred on the ribbon, no overflow', (tester) async {
        await pumpAtSize(tester, d.size, board(aisha()));
        expect(tester.takeException(), isNull);
        final layout = LuckyCardLayout.of(d.size);
        final snapshot = aisha();

        for (final c in LuckyCard.all) {
          final rect = tester.getRect(cell(c));
          expect(rect.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: '${c.key} tap width');
          expect(rect.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: '${c.key} tap height');

          // Where the layout says this card is.
          final want = layout.cardCell(c.suit.index, c.rank.index).shift(layout.canvasRect.topLeft);
          expect(rect.left, closeTo(want.left, 0.01), reason: c.key);
          expect(rect.top, closeTo(want.top, 0.01), reason: c.key);

          final label = snapshot.stakeOn(c) == 0 ? 'Play' : '${snapshot.stakeOn(c)}';
          final text = tester.widget<Text>(textIn(c));
          expect(text.data, label, reason: c.key);
          expect(text.style!.fontSize, greaterThanOrEqualTo(kLuckyCardMinReadableDp - 0.001), reason: '${c.key} text size');

          // Centred on the ribbon of the card picture.
          final picture = layout.cardImage(c.suit.index, c.rank.index).shift(layout.canvasRect.topLeft);
          final ribbon = LuckyCardSlots.cardRibbon.within(picture);
          expect(tester.getCenter(textIn(c)).dx, closeTo(ribbon.center.dx, 0.6), reason: '${c.key} text across');
          expect(tester.getCenter(textIn(c)).dy, closeTo(ribbon.center.dy, 0.6), reason: '${c.key} text down');
        }
        expect(find.text('Play'), findsNWidgets(3));
        expect(find.text('50000'), findsOneWidget);
        expect(find.text('15'), findsOneWidget);
      });
    }
  });

  group('pictures', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name}: every card picture is decoded no wider than it is drawn, and drawn at the card size the layout gives', (tester) async {
        await pumpAtSize(tester, d.size, board(aisha()), devicePixelRatio: 2);
        final layout = LuckyCardLayout.of(d.size);
        for (final c in LuckyCard.all) {
          final image = tester.widget<Image>(find.descendant(of: cell(c), matching: find.byType(Image)));
          expect(image.width, closeTo(layout.cardSide, 0.001), reason: c.key);
          expect(image.height, closeTo(layout.cardSide, 0.001), reason: c.key);
          final provider = image.image as ResizeImage;
          expect(provider.width, LuckyCardLayout.cacheWidth(layout.cardSide, 2), reason: c.key);
        }
      });
    }
  });

  group('the phone font-size setting', () {
    testWidgets('has no effect on the numbers on the cards', (tester) async {
      Future<List<double>> sizes(double scale) async {
        await pumpAtSize(tester, const Size(844, 390), board(aisha()), textScale: scale);
        expect(tester.takeException(), isNull);
        return [for (final c in LuckyCard.all) tester.getSize(textIn(c)).width];
      }

      final a = await sizes(0.5);
      final b = await sizes(1);
      final c = await sizes(3);
      expect(a, b);
      expect(b, c);
    });
  });

  group('a tap', () {
    testWidgets('calls the handler once with that card, anywhere in its cell, even beside the picture', (tester) async {
      final tapped = <LuckyCard>[];
      await pumpAtSize(tester, const Size(915, 412), board(aisha(), onTap: (c) {
        tapped.add(c);
        return const LuckyCardBoardResult();
      }));
      await tester.tap(cell(jh));
      expect(tapped, [jh]);

      final rect = tester.getRect(cell(qs));
      final layout = LuckyCardLayout.of(const Size(915, 412));
      expect(rect.width, greaterThan(layout.cardSide), reason: 'the cell is wider than the picture here');
      await tester.tapAt(rect.centerLeft + const Offset(2, 0));
      expect(tapped, [jh, qs], reason: 'a tap in the margin of the cell still counts');
    });

    testWidgets('that changes a card pulses it, and nothing is reported as refused', (tester) async {
      final refusals = <Set<LuckyCardBoardIssue>>[];
      await pumpAtSize(tester, const Size(844, 390), board(aisha(), onTap: changed, onRefused: (c, i) => refusals.add(i)));
      double scale() => tester.widget<ScaleTransition>(find.descendant(of: cell(jh), matching: find.byType(ScaleTransition))).scale.value;
      expect(scale(), 1.0);
      await tester.tap(cell(jh));
      await tester.pump(); // the animation starts counting at this frame
      await tester.pump(const Duration(milliseconds: 90));
      expect(scale(), greaterThan(1.05), reason: 'at the peak of the pulse');
      await tester.pump(const Duration(milliseconds: 300));
      expect(scale(), 1.0, reason: 'back to normal');
      expect(refusals, isEmpty);
      expect(find.byType(ColorFiltered), findsNothing);
    });

    testWidgets('that is refused flashes the card red, reports why, and does not pulse', (tester) async {
      final refusals = <(LuckyCard, Set<LuckyCardBoardIssue>)>[];
      await pumpAtSize(
        tester,
        const Size(844, 390),
        board(aisha(), onTap: (_) => refused({LuckyCardBoardIssue.notEnoughCoins}), onRefused: (c, i) => refusals.add((c, i))),
      );
      await tester.tap(cell(kc));
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.descendant(of: cell(kc), matching: find.byType(ColorFiltered)), findsOneWidget, reason: 'the flash');
      expect(refusals.single.$1, kc);
      expect(refusals.single.$2, {LuckyCardBoardIssue.notEnoughCoins});
      double scale() => tester.widget<ScaleTransition>(find.descendant(of: cell(kc), matching: find.byType(ScaleTransition))).scale.value;
      expect(scale(), 1.0, reason: 'nothing changed, so no pulse');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ColorFiltered), findsNothing, reason: 'the flash has faded');
    });

    testWidgets('that is only partly done both pulses and flashes', (tester) async {
      final refusals = <Set<LuckyCardBoardIssue>>[];
      await pumpAtSize(
        tester,
        const Size(844, 390),
        board(aisha(),
            onTap: (c) => LuckyCardBoardResult(changed: [c], issues: {LuckyCardBoardIssue.cardAtMaximum}),
            onRefused: (c, i) => refusals.add(i)),
      );
      await tester.tap(cell(jh));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.descendant(of: cell(jh), matching: find.byType(ColorFiltered)), findsOneWidget);
      expect(tester.widget<ScaleTransition>(find.descendant(of: cell(jh), matching: find.byType(ScaleTransition))).scale.value, greaterThan(1.0));
      expect(refusals.single, {LuckyCardBoardIssue.cardAtMaximum});
    });

    testWidgets('with animations switched off (an accessibility setting) nothing moves or flashes, but the reason is still reported', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final refusals = <Set<LuckyCardBoardIssue>>[];
      await pumpAtSize(
        tester,
        const Size(844, 390),
        board(aisha(), onTap: (_) => refused({LuckyCardBoardIssue.locked}), onRefused: (c, i) => refusals.add(i)),
      );
      await tester.tap(cell(jh));
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(ColorFiltered), findsNothing);
      expect(refusals.single, {LuckyCardBoardIssue.locked});
    });
  });

  group('the locked look', () {
    testWidgets('a locked board is dimmed, ignores taps and says nothing', (tester) async {
      var taps = 0;
      var refusals = 0;
      await pumpAtSize(tester, const Size(844, 390), board(aisha(isLocked: true), onTap: (_) {
        taps++;
        return const LuckyCardBoardResult();
      }, onRefused: (c, i) => refusals++));
      expect(find.descendant(of: cell(jh), matching: find.byType(Opacity)), findsOneWidget);
      expect(tester.widget<Opacity>(find.descendant(of: cell(jh), matching: find.byType(Opacity))).opacity, closeTo(0.55, 1e-9));
      await tester.tap(cell(jh));
      await tester.pump(const Duration(milliseconds: 50));
      expect(taps, 0);
      expect(refusals, 0);
      expect(find.byType(ColorFiltered), findsNothing);
    });

    testWidgets('an unlocked board is not dimmed', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), board(aisha()));
      expect(find.descendant(of: cell(jh), matching: find.byType(Opacity)), findsNothing);
    });

    testWidgets('locking and unlocking while the board stays on screen works', (tester) async {
      var taps = 0;
      LuckyCardBoardResult counting(LuckyCard _) {
        taps++;
        return const LuckyCardBoardResult();
      }

      await pumpAtSize(tester, const Size(844, 390), board(aisha(isLocked: true), onTap: counting));
      await tester.tap(cell(jh));
      expect(taps, 0);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: board(aisha(), onTap: counting))));
      await tester.tap(cell(jh));
      expect(taps, 1);
    });
  });

  group('the numbers follow the board', () {
    testWidgets('"Play" becomes the amount and back, and a large amount still shows in full', (tester) async {
      await pumpAtSize(tester, const Size(640, 360), board(LuckyCardBoardSnapshot.empty()));
      expect(find.text('Play'), findsNWidgets(12));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: board(LuckyCardBoardSnapshot.fromStakes({qs: 50000})))));
      expect(find.text('Play'), findsNWidgets(11));
      expect(textIn(qs), findsOneWidget);
      expect(tester.widget<Text>(textIn(qs)).data, '50000');
      expect(tester.widget<Text>(textIn(qs)).style!.fontSize, greaterThanOrEqualTo(10.99));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: board(LuckyCardBoardSnapshot.empty()))));
      expect(find.text('Play'), findsNWidgets(12));
    });

    testWidgets('an empty card reads dimmer than a card with coins', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), board(aisha()));
      final empty = tester.widget<Text>(textIn(qs)).style!.color!;
      final full = tester.widget<Text>(textIn(jh)).style!.color!;
      expect(empty.a, lessThan(full.a));
    });
  });

  group('for a screen reader', () {
    testWidgets('each card says what it is and what is on it, and can be activated', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpAtSize(tester, const Size(844, 390), board(aisha(), onTap: (_) {
        taps++;
        return const LuckyCardBoardResult();
      }));
      expect(tester.getSemantics(cell(jh)).label, 'Jack of Hearts, 15 coins');
      expect(tester.getSemantics(cell(qs)).label, 'Queen of Spades, no coins');
      expect(tester.getSemantics(cell(kc)).label, 'King of Clubs, 50000 coins');
      expect(tester.getSemantics(cell(jh)).flagsCollection.isButton, isTrue);
      expect(tester.getSemantics(cell(jh)).flagsCollection.isEnabled, ui.Tristate.isTrue);
      tester.semantics.tap(find.semantics.byLabel('Jack of Hearts, 15 coins'));
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('a locked card says it is not enabled and cannot be activated', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), board(aisha(isLocked: true)));
      expect(tester.getSemantics(cell(jh)).flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(tester.getSemantics(cell(jh)).getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });
  });

  group('a picture to look at, with the real artwork', () {
    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets('${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) async {
        final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
        await pumpAtSize(tester, d.size, board(aisha(), art: art));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cards_${d.width.toInt()}x${d.height.toInt()}.png'),
        );
      });
    }
  });
}
