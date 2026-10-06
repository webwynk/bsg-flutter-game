// Tests for lucky_card_shortcuts.dart, lucky_card_tap_target.dart and
// lucky_card_board_view.dart: the 4 suit headers, the 3 rank selectors and the
// whole board assembled, at every device of the matrix, with the real number font.
// (The 12 cards have their own tests in lucky_card_cards_test.dart.)

import 'dart:ui' as ui;

import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_board_snapshot.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_board_view.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_canvas.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_cards.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

LuckyCard c(LuckyCardRank r, LuckyCardSuit s) => LuckyCard(r, s);

/// Aisha's board after the spec's §3.2 example: 10 chip on the Hearts bar, then 5
/// chip on the J selector. Hearts 35, the other bars 5, J 30, Q 10, K 10, total 50.
LuckyCardBoardSnapshot example({bool isLocked = false}) => LuckyCardBoardSnapshot.fromStakes(
      {
        c(LuckyCardRank.jack, LuckyCardSuit.hearts): 15,
        c(LuckyCardRank.jack, LuckyCardSuit.spades): 5,
        c(LuckyCardRank.jack, LuckyCardSuit.diamonds): 5,
        c(LuckyCardRank.jack, LuckyCardSuit.clubs): 5,
        c(LuckyCardRank.queen, LuckyCardSuit.hearts): 10,
        c(LuckyCardRank.king, LuckyCardSuit.hearts): 10,
      },
      isLocked: isLocked,
      activeChip: LuckyCardChip.five,
    );

/// The largest board there is: 50,000 on every card. Suit totals 150,000, rank
/// totals 200,000.
LuckyCardBoardSnapshot biggest() => LuckyCardBoardSnapshot.fromStakes({for (final card in LuckyCard.all) card: 50000});

Finder suit(LuckyCardSuit s) => find.byKey(ValueKey('suit-${s.dbValue}'));
Finder rank(LuckyCardRank r) => find.byKey(ValueKey('rank-${r.dbValue}'));
Finder card(LuckyCard cd) => find.byKey(ValueKey(cd.key));

List<Text> textsIn(WidgetTester tester, Finder of) =>
    tester.widgetList<Text>(find.descendant(of: of, matching: find.byType(Text))).toList();

Widget board(
  LuckyCardBoardSnapshot snapshot, {
  LuckyCardArt art = const FileLuckyCardArt(),
  LuckyCardCardTap? onTapCard,
  LuckyCardSuitTap? onTapSuit,
  LuckyCardRankTap? onTapRank,
  LuckyCardBoardRefused? onRefused,
}) {
  final zones = LuckyCardBoardZones(
    art: art,
    snapshot: snapshot,
    onTapCard: onTapCard ?? (_) => const LuckyCardBoardResult(),
    onTapSuit: onTapSuit ?? (_) => const LuckyCardBoardResult(),
    onTapRank: onTapRank ?? (_) => const LuckyCardBoardResult(),
    onRefused: onRefused,
  );
  return LuckyCardCanvas(grid: zones.grid, rankColumn: zones.rankColumn);
}

class RecordingArt extends LuckyCardArt {
  RecordingArt(this.inner);

  final LuckyCardArt inner;
  final Set<(String, int)> requests = {};

  @override
  ImageProvider image(LuckyCardArtKey key, {required int cacheWidth}) {
    requests.add((key.assetPath, cacheWidth));
    return inner.image(key, cacheWidth: cacheWidth);
  }
}

void main() {
  setUpAll(loadLuckyCardFonts);

  group('every device of the matrix: the spec example (hearts 35, other bars 5, J 30, Q 10, K 10)', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()})', (tester) async {
        await pumpAtSize(tester, d.size, board(example()));
        expect(tester.takeException(), isNull, reason: 'no overflow');
        final layout = LuckyCardLayout.of(d.size);
        final origin = layout.canvasRect.topLeft;

        // The four suit headers: name, then total (blank when nothing is on the suit).
        const wantSuit = {
          LuckyCardSuit.hearts: '35',
          LuckyCardSuit.spades: '5',
          LuckyCardSuit.diamonds: '5',
          LuckyCardSuit.clubs: '5',
        };
        for (final s in LuckyCardSuit.values) {
          final texts = textsIn(tester, suit(s));
          expect(texts.map((t) => t.data), [s.label, wantSuit[s]], reason: s.dbValue);
          for (final t in texts) {
            expect(t.style!.fontSize, greaterThanOrEqualTo(kLuckyCardMinReadableDp - 0.001), reason: '${s.dbValue} ${t.data}');
          }
          final rect = tester.getRect(suit(s));
          expect(rect.shift(-origin).left, closeTo(layout.suitHeader(s.index).left, 0.01));
          expect(rect.width, greaterThanOrEqualTo(kLuckyCardMinTapDp));
          expect(rect.height, greaterThanOrEqualTo(kLuckyCardMinTapDp));

          // The name sits above the bar and is centred on it; the total sits on the panel.
          final bar = layout.suitBar(s.index).shift(origin);
          final name = tester.getRect(find.descendant(of: suit(s), matching: find.text(s.label)));
          expect(name.center.dx, closeTo(bar.center.dx, 0.6), reason: '${s.dbValue} name centred on its bar');
          expect(name.bottom, lessThanOrEqualTo(bar.top + 1), reason: '${s.dbValue} name above the bar');
          final panel = LuckyCardSlots.suitPanel.within(bar);
          final total = tester.getRect(find.descendant(of: suit(s), matching: find.text(wantSuit[s]!)));
          expect(total.center.dx, closeTo(panel.center.dx, 0.6), reason: '${s.dbValue} total on the panel');
          expect(total.center.dy, closeTo(panel.center.dy, 0.6), reason: '${s.dbValue} total on the panel');
        }

        // The three rank selectors: name, then total on the cream disc.
        const wantRank = {LuckyCardRank.jack: '30', LuckyCardRank.queen: '10', LuckyCardRank.king: '10'};
        for (final r in LuckyCardRank.values) {
          final texts = textsIn(tester, rank(r));
          expect(texts.map((t) => t.data), [luckyCardRankName(r), wantRank[r]], reason: r.dbValue);
          for (final t in texts) {
            expect(t.style!.fontSize, greaterThanOrEqualTo(kLuckyCardMinReadableDp - 0.001), reason: '${r.dbValue} ${t.data}');
          }
          final rect = tester.getRect(rank(r));
          expect(rect.width, greaterThanOrEqualTo(kLuckyCardMinTapDp));
          expect(rect.height, greaterThanOrEqualTo(kLuckyCardMinTapDp));
          final disc = LuckyCardSlots.rankDisc.within(layout.rankPicture(r.index).shift(origin));
          final total = tester.getRect(find.descendant(of: rank(r), matching: find.text(wantRank[r]!)));
          expect(total.center.dx, closeTo(disc.center.dx, 0.6), reason: '${r.dbValue} total on the disc');
          expect(total.center.dy, closeTo(disc.center.dy, 0.6), reason: '${r.dbValue} total on the disc');
        }

        // The 12 cards carry the example's amounts.
        expect(find.text('15'), findsOneWidget);
        expect(find.text('Play'), findsNWidgets(6));
      });
    }
  });

  group('the 19 tap targets never overlap and are all at least 48 dp', () {
    for (final d in kDeviceMatrix) {
      testWidgets(d.name, (tester) async {
        await pumpAtSize(tester, d.size, board(example()));
        final targets = <String, Rect>{
          for (final s in LuckyCardSuit.values) 'suit ${s.dbValue}': tester.getRect(suit(s)),
          for (final r in LuckyCardRank.values) 'rank ${r.dbValue}': tester.getRect(rank(r)),
          for (final cd in LuckyCard.all) cd.key: tester.getRect(card(cd)),
        };
        expect(targets.length, 19);
        final names = targets.keys.toList();
        for (final n in names) {
          expect(targets[n]!.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: n);
          expect(targets[n]!.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: n);
        }
        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            final x = targets[names[i]]!.intersect(targets[names[j]]!);
            expect(x.width > 0.01 && x.height > 0.01, isFalse, reason: '${names[i]} overlaps ${names[j]}');
          }
        }
      });
    }
  });

  group('the largest numbers fit', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name}: 150000 on every suit bar and 200K on every rank disc', (tester) async {
        await pumpAtSize(tester, d.size, board(biggest()));
        expect(tester.takeException(), isNull);
        final layout = LuckyCardLayout.of(d.size);
        final origin = layout.canvasRect.topLeft;
        for (final s in LuckyCardSuit.values) {
          final panel = LuckyCardSlots.suitPanel.within(layout.suitBar(s.index).shift(origin));
          final total = tester.getRect(find.descendant(of: suit(s), matching: find.text('150000')));
          expect(total.width, lessThanOrEqualTo(panel.width), reason: '${s.dbValue}: 150000 inside its panel');
        }
        for (final r in LuckyCardRank.values) {
          final disc = LuckyCardSlots.rankDisc.within(layout.rankPicture(r.index).shift(origin));
          final total = tester.getRect(find.descendant(of: rank(r), matching: find.text('200K')));
          expect(total.width, lessThanOrEqualTo(disc.width), reason: '${r.dbValue}: 200K inside its disc');
        }
        expect(find.text('50000'), findsNWidgets(12));
      });
    }
  });

  group('colours', () {
    testWidgets('the total on a red bar panel is light, the total on the cream disc is dark', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), board(example()));
      final onBar = tester.widget<Text>(find.descendant(of: suit(LuckyCardSuit.hearts), matching: find.text('35')));
      final onDisc = tester.widget<Text>(find.descendant(of: rank(LuckyCardRank.jack), matching: find.text('30')));
      expect(onBar.style!.color!.computeLuminance(), greaterThan(0.6));
      expect(onDisc.style!.color!.computeLuminance(), lessThan(0.15));
    });
  });

  group('blank at 0', () {
    testWidgets('an empty board: bars and selectors show only their names; the 12 cards say "Play"', (tester) async {
      await pumpAtSize(tester, const Size(844, 390), board(LuckyCardBoardSnapshot.empty()));
      for (final s in LuckyCardSuit.values) {
        expect(textsIn(tester, suit(s)).map((t) => t.data), [s.label]);
      }
      for (final r in LuckyCardRank.values) {
        expect(textsIn(tester, rank(r)).map((t) => t.data), [luckyCardRankName(r)]);
      }
      expect(find.text('Play'), findsNWidgets(12));
    });

    testWidgets('a rank disc says 99999 in full and 100K from 100,000, rounded down', (tester) async {
      LuckyCardBoardSnapshot rankTotal(int perCard) =>
          LuckyCardBoardSnapshot.fromStakes({for (final cd in LuckyCard.ofRank(LuckyCardRank.jack)) cd: perCard});
      await pumpAtSize(tester, const Size(844, 390), board(rankTotal(24999))); // 4 x 24,999 = 99,996
      expect(textsIn(tester, rank(LuckyCardRank.jack)).map((t) => t.data), ['Jacks', '99996']);
      await pumpAtSize(tester, const Size(844, 390), board(rankTotal(25000))); // 100,000
      expect(textsIn(tester, rank(LuckyCardRank.jack)).map((t) => t.data), ['Jacks', '100K']);
      await pumpAtSize(tester, const Size(844, 390), board(rankTotal(25999))); // 103,996
      expect(textsIn(tester, rank(LuckyCardRank.jack)).map((t) => t.data), ['Jacks', '103K']);
    });
  });

  group('a tap', () {
    testWidgets('on a suit header calls the handler with that suit, even in the margin of the header', (tester) async {
      final taps = <LuckyCardSuit>[];
      await pumpAtSize(tester, const Size(915, 412), board(example(), onTapSuit: (s) {
        taps.add(s);
        return const LuckyCardBoardResult();
      }));
      await tester.tap(suit(LuckyCardSuit.hearts));
      final rect = tester.getRect(suit(LuckyCardSuit.clubs));
      await tester.tapAt(rect.topLeft + const Offset(1, 1));
      expect(taps, [LuckyCardSuit.hearts, LuckyCardSuit.clubs]);
    });

    testWidgets('on a rank selector calls the handler with that rank, even in the margin of its row', (tester) async {
      final taps = <LuckyCardRank>[];
      await pumpAtSize(tester, const Size(915, 412), board(example(), onTapRank: (r) {
        taps.add(r);
        return const LuckyCardBoardResult();
      }));
      await tester.tap(rank(LuckyCardRank.queen));
      final rect = tester.getRect(rank(LuckyCardRank.king));
      await tester.tapAt(rect.bottomRight - const Offset(1, 1));
      expect(taps, [LuckyCardRank.queen, LuckyCardRank.king]);
    });

    testWidgets('that changes cards pulses the header or selector, and a refused one flashes it and says which and why', (tester) async {
      final refusals = <(LuckyCardBoardTarget, Set<LuckyCardBoardIssue>)>[];
      await pumpAtSize(
        tester,
        const Size(844, 390),
        board(
          example(),
          onTapSuit: (s) => s == LuckyCardSuit.clubs
              ? const LuckyCardBoardResult(issues: {LuckyCardBoardIssue.locked})
              : LuckyCardBoardResult(coinsSpent: 15, changed: LuckyCard.ofSuit(s)),
          onTapRank: (r) => const LuckyCardBoardResult(issues: {LuckyCardBoardIssue.notEnoughCoins}),
          onTapCard: (cd) => LuckyCardBoardResult(changed: [cd], issues: {LuckyCardBoardIssue.cardAtMaximum}),
          onRefused: (t, i) => refusals.add((t, i)),
        ),
      );
      double scale(Finder of) => tester.widget<ScaleTransition>(find.descendant(of: of, matching: find.byType(ScaleTransition))).scale.value;

      await tester.tap(suit(LuckyCardSuit.spades));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(scale(suit(LuckyCardSuit.spades)), greaterThan(1.05), reason: 'pulse');
      expect(find.descendant(of: suit(LuckyCardSuit.spades), matching: find.byType(ColorFiltered)), findsNothing);
      expect(refusals, isEmpty);

      await tester.tap(rank(LuckyCardRank.king));
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.descendant(of: rank(LuckyCardRank.king), matching: find.byType(ColorFiltered)), findsOneWidget, reason: 'flash');
      expect(scale(rank(LuckyCardRank.king)), 1.0, reason: 'nothing changed: no pulse');
      expect(refusals.single.$1, const LuckyCardRankTarget(LuckyCardRank.king));
      expect(refusals.single.$2, {LuckyCardBoardIssue.notEnoughCoins});

      await tester.tap(suit(LuckyCardSuit.clubs));
      expect(refusals.last.$1, const LuckyCardSuitTarget(LuckyCardSuit.clubs), reason: 'a refused suit header says which suit');
      expect(refusals.last.$2, {LuckyCardBoardIssue.locked});

      await tester.tap(card(c(LuckyCardRank.queen, LuckyCardSuit.clubs)));
      expect(refusals.last.$1, LuckyCardCardTarget(c(LuckyCardRank.queen, LuckyCardSuit.clubs)));
      expect(refusals.last.$2, {LuckyCardBoardIssue.cardAtMaximum});
    });

    testWidgets('on a locked board does nothing anywhere, and all 19 pieces are dimmed', (tester) async {
      var calls = 0;
      LuckyCardBoardResult count() {
        calls++;
        return const LuckyCardBoardResult();
      }

      await pumpAtSize(
        tester,
        const Size(844, 390),
        board(example(isLocked: true), onTapCard: (_) => count(), onTapSuit: (_) => count(), onTapRank: (_) => count(), onRefused: (t, i) => calls += 100),
      );
      expect(find.byType(Opacity), findsNWidgets(19));
      for (final s in LuckyCardSuit.values) {
        await tester.tap(suit(s));
      }
      for (final r in LuckyCardRank.values) {
        await tester.tap(rank(r));
      }
      for (final cd in LuckyCard.all) {
        await tester.tap(card(cd));
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, 0);
    });
  });

  group('for a screen reader', () {
    testWidgets('each header and selector says what it covers and what is on it', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), board(example()));
      expect(tester.getSemantics(suit(LuckyCardSuit.hearts)).label, 'Hearts, 3 cards, 35 coins');
      expect(tester.getSemantics(suit(LuckyCardSuit.clubs)).label, 'Clubs, 3 cards, 5 coins');
      expect(tester.getSemantics(rank(LuckyCardRank.jack)).label, 'Jacks, 4 cards, 30 coins');
      expect(tester.getSemantics(rank(LuckyCardRank.king)).label, 'Kings, 4 cards, 10 coins');
      await pumpAtSize(tester, const Size(844, 390), board(LuckyCardBoardSnapshot.empty()));
      expect(tester.getSemantics(suit(LuckyCardSuit.spades)).label, 'Spades, 3 cards, no coins');
      expect(tester.getSemantics(rank(LuckyCardRank.queen)).label, 'Queens, 4 cards, no coins');
      expect(tester.getSemantics(rank(LuckyCardRank.queen)).flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('a locked header is disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAtSize(tester, const Size(844, 390), board(example(isLocked: true)));
      expect(tester.getSemantics(suit(LuckyCardSuit.hearts)).flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(tester.getSemantics(rank(LuckyCardRank.jack)).getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });
  });

  group("the phone's font-size setting", () {
    testWidgets('changes nothing on the headers and selectors: names and numbers keep their size', (tester) async {
      Future<List<Size>> sizes(double scale) async {
        await pumpAtSize(tester, const Size(844, 390), board(example()), textScale: scale);
        expect(tester.takeException(), isNull, reason: 'scale $scale');
        return [
          for (final s in LuckyCardSuit.values) ...textsIn(tester, suit(s)).map((t) => tester.getSize(find.text(t.data!, skipOffstage: false).first)),
          for (final r in LuckyCardRank.values) ...textsIn(tester, rank(r)).map((t) => tester.getSize(find.descendant(of: rank(r), matching: find.text(t.data!)))),
        ];
      }

      final a = await sizes(0.5);
      final b = await sizes(1);
      final c3 = await sizes(3);
      expect(a, b);
      expect(b, c3);
    });
  });

  group('picture pre-loading asks for exactly what the widgets draw', () {
    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets('${d.name}: the 19 pictures, at the same widths', (tester) async {
        final loaded = (await tester.runAsync(PreloadedLuckyCardArt.load))!;

        final drawn = RecordingArt(loaded);
        await pumpAtSize(tester, d.size, board(example(), art: drawn), devicePixelRatio: 2);
        expect(tester.takeException(), isNull);

        final preloaded = RecordingArt(loaded);
        final layout = LuckyCardLayout.of(d.size);
        final context = tester.element(find.byType(LuckyCardCanvas));
        await tester.runAsync(() => precacheLuckyCardBoard(context, layout, preloaded));

        expect(preloaded.requests.length, 19, reason: '12 cards, 4 bars, 3 selectors');
        expect(preloaded.requests, drawn.requests, reason: 'the same pictures at the same widths the widgets use');
      });
    }
  });

  group('a picture to look at, with the real artwork', () {
    Widget scene(LuckyCardBoardSnapshot s, LuckyCardArt art) => board(s, art: art);

    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets("the spec's example, ${d.name} ${d.width.toInt()}x${d.height.toInt()}", (tester) async {
        final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
        await pumpAtSize(tester, d.size, scene(example(), art));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/board_example_${d.width.toInt()}x${d.height.toInt()}.png'));
      });
    }

    testWidgets('the largest numbers, small phone 640x360', (tester) async {
      final art = (await tester.runAsync(PreloadedLuckyCardArt.load))!;
      await pumpAtSize(tester, const Size(640, 360), scene(biggest(), art));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/board_biggest_640x360.png'));
    });
  });
}
