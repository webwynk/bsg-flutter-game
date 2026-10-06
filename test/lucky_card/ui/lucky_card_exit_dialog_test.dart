// Tests for the exit confirmation (lucky_card_exit_dialog.dart): the words, the answers, the
// 5-second cancel, the 48 dp buttons on every device, and the guard against answering twice.

import 'dart:ui' as ui;

import 'package:best_smart_game/widgets/lucky_card/lucky_card_exit_dialog.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

const Size phone = Size(844, 390);

/// What the dialog answered, for every time it was opened.
class Answers {
  final List<bool?> given = [];
  int opens = 0;
}

/// A lobby page with a button that pushes a "game" page; the game page has a button that
/// asks the question. The game page sits over the lobby, as in the real app.
Widget app(Answers answers) => Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const ValueKey('lobby-go'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      key: const ValueKey('ask'),
                      onPressed: () async => answers.given.add(await LuckyCardExitDialog.show(context, onOpen: () => answers.opens++)),
                      child: const Text('ask'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child: const Text('lobby'),
        ),
      ),
    );

Finder key(String k) => find.byKey(ValueKey(k));
Finder get dialog => key('exit-dialog');

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<Answers> ready(WidgetTester tester, {Size size = phone, double textScale = 1}) async {
  final answers = Answers();
  await pumpAtSize(tester, size, app(answers), textScale: textScale);
  await tester.tap(key('lobby-go'));
  await settle(tester);
  return answers;
}

Future<void> ask(WidgetTester tester) async {
  await tester.tap(key('ask'));
  await settle(tester);
}

Color faceTop(WidgetTester tester, String k) {
  final box = tester
      .widgetList<DecoratedBox>(find.descendant(of: key(k), matching: find.byType(DecoratedBox)))
      .map((d) => d.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((d) => d.gradient is LinearGradient);
  return (box.gradient as LinearGradient).colors.first;
}

void main() {
  setUpAll(() async {
    await loadLuckyCardFonts();
    await loadLuckyCardIcons();
  });

  test('the words are Triple Chance\'s', () {
    expect(kLuckyCardExitTitle, 'EXIT GAME');
    expect(kLuckyCardExitMessage, 'Do you want to exit?');
    expect(kLuckyCardExitNo, 'NO');
    expect(kLuckyCardExitYes, 'YES');
    expect(LuckyCardExitDialog.autoCancel, const Duration(seconds: 5));
  });

  group('asking', () {
    testWidgets('it shows the title, the question, NO and YES, and calls the open hook once', (tester) async {
      final answers = await ready(tester);
      await ask(tester);
      expect(dialog, findsOneWidget);
      expect(answers.opens, 1);
      expect(find.descendant(of: dialog, matching: find.text('EXIT GAME')), findsOneWidget);
      expect(tester.widget<Text>(key('exit-message')).data, 'Do you want to exit?');
      expect(find.descendant(of: key('exit-no'), matching: find.text('NO')), findsOneWidget);
      expect(find.descendant(of: key('exit-yes'), matching: find.text('YES')), findsOneWidget);
    });

    testWidgets('NO is green and YES is red', (tester) async {
      await ready(tester);
      await ask(tester);
      expect(faceTop(tester, 'exit-no'), const Color(0xFF55FF55));
      expect(faceTop(tester, 'exit-yes'), const Color(0xFFFF5555));
    });

    testWidgets('NO answers false, YES answers true, each once', (tester) async {
      final answers = await ready(tester);
      await ask(tester);
      await tester.tap(key('exit-no'));
      await settle(tester);
      expect(answers.given, [false]);
      expect(dialog, findsNothing);

      await ask(tester);
      await tester.tap(key('exit-yes'));
      await settle(tester);
      expect(answers.given, [false, true]);
    });

    testWidgets('it cancels itself after 5 seconds with "stay", and not before', (tester) async {
      final answers = await ready(tester);
      await ask(tester);
      await tester.pump(const Duration(milliseconds: 4500));
      expect(dialog, findsOneWidget, reason: 'still asking at 4.5 s');
      expect(answers.given, isEmpty);
      await tester.pump(const Duration(milliseconds: 800));
      await settle(tester);
      expect(dialog, findsNothing);
      expect(answers.given, [false]);
    });

    testWidgets('an answer stops the clock: nothing happens when the 5 seconds would have run out', (tester) async {
      final answers = await ready(tester);
      await ask(tester);
      await tester.tap(key('exit-yes'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 6));
      expect(answers.given, [true]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap outside does not close it', (tester) async {
      final answers = await ready(tester);
      await ask(tester);
      await tester.tapAt(const Offset(4, 4));
      await settle(tester);
      expect(dialog, findsOneWidget);
      expect(answers.given, isEmpty);
    });

    testWidgets('the back gesture closes it without an answer', (tester) async {
      final answers = await ready(tester);
      await ask(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(dialog, findsNothing);
      expect(answers.given, [null]);
    });

    testWidgets('two quick activations answer once and do not take the player out of the game page', (tester) async {
      final answers = await ready(tester);
      final handle = tester.ensureSemantics();
      await ask(tester);
      final yes = find.semantics.byPredicate((n) => n.label == 'YES');
      tester.semantics.performAction(yes, ui.SemanticsAction.tap);
      tester.semantics.performAction(yes, ui.SemanticsAction.tap);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(answers.given, [true], reason: 'one answer');
      expect(key('ask'), findsOneWidget, reason: 'the game page is still there');
      expect(key('lobby-go'), findsNothing, reason: 'the lobby is still covered');
      handle.dispose();
    });
  });

  group('every device of the matrix', () {
    for (final d in kDeviceMatrix) {
      testWidgets('${d.name} (${d.width.toInt()} x ${d.height.toInt()}): inside the screen, 48 dp buttons, 11 dp text', (tester) async {
        await ready(tester, size: d.size);
        await ask(tester);
        final l = LuckyCardLayout.of(d.size);
        final box = tester.getRect(dialog);
        expect(tester.takeException(), isNull);
        expect((Offset.zero & d.size).contains(box.topLeft) && (Offset.zero & d.size).contains(box.bottomRight), isTrue);
        expect(box.center.dx, closeTo(l.canvasRect.center.dx, 0.5));
        expect(box.center.dy, closeTo(l.canvasRect.center.dy, 0.5));
        expect(box.width, closeTo(l.canvasRect.width * LuckyCardExitDialog.widthShare, 0.5));
        for (final k in ['exit-no', 'exit-yes']) {
          final r = tester.getRect(key(k));
          expect(r.width, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: '$k width on ${d.name}');
          expect(r.height, greaterThanOrEqualTo(kLuckyCardMinTapDp), reason: '$k height on ${d.name}');
          expect(box.contains(r.topLeft) && box.contains(r.bottomRight - const Offset(0.01, 0.01)), isTrue, reason: '$k inside the dialog');
        }
        for (final t in tester.widgetList<Text>(find.descendant(of: dialog, matching: find.byType(Text)))) {
          expect(t.style!.fontSize, greaterThanOrEqualTo(kLuckyCardMinReadableDp), reason: '"${t.data}"');
        }
      });
    }

    testWidgets('a tap anywhere in a button counts, even at its corner', (tester) async {
      final answers = await ready(tester);
      await ask(tester);
      final no = tester.getRect(key('exit-no'));
      await tester.tapAt(no.topLeft + const Offset(1, 1));
      await settle(tester);
      expect(answers.given, [false]);
      await ask(tester);
      final yes = tester.getRect(key('exit-yes'));
      await tester.tapAt(yes.bottomRight - const Offset(1, 1));
      await settle(tester);
      expect(answers.given, [false, true]);
    });
  });

  group('the phone\'s font-size setting changes nothing', () {
    testWidgets('at 3 times the text every size and the dialog\'s box stay the same', (tester) async {
      await ready(tester, size: const Size(640, 360));
      await ask(tester);
      final box = tester.getRect(dialog);
      final sizes = [for (final t in tester.widgetList<Text>(find.descendant(of: dialog, matching: find.byType(Text)))) '${t.data}:${t.style!.fontSize}'];

      await tester.pumpWidget(const SizedBox.shrink());
      await ready(tester, size: const Size(640, 360), textScale: 3);
      await ask(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(dialog), box);
      expect([for (final t in tester.widgetList<Text>(find.descendant(of: dialog, matching: find.byType(Text)))) '${t.data}:${t.style!.fontSize}'], sizes);
      for (final t in tester.widgetList<Text>(find.descendant(of: dialog, matching: find.byType(Text)))) {
        expect(t.textScaler, TextScaler.noScaling);
      }
    });
  });

  group('a screen reader', () {
    testWidgets('hears the question and both answers', (tester) async {
      final handle = tester.ensureSemantics();
      await ready(tester);
      await ask(tester);
      expect(find.bySemanticsLabel('EXIT GAME'), findsWidgets);
      expect(find.bySemanticsLabel('NO'), findsOneWidget);
      expect(find.bySemanticsLabel('YES'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('YES')).getSemanticsData().flagsCollection.isButton, isTrue);
      handle.dispose();
    });
  });

  group('a picture to look at', () {
    for (final d in const [Device('small phone', 640, 360), Device('large phone', 915, 412), Device('small tablet', 1024, 768)]) {
      testWidgets('${d.name} ${d.width.toInt()}x${d.height.toInt()}', (tester) async {
        await ready(tester, size: d.size);
        await ask(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/exit_dialog_${d.width.toInt()}x${d.height.toInt()}.png'));
      });
    }
  });
}
