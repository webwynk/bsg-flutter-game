// What closing the Windows window does, row by row, for all four games.
//
// The Lucky Card, Lucky 16 and Spin2Win rows use each game's real Exit popup
// inside a stand-in page that leaves the same way the real screens do: PopScope
// blocks the back signal, the popup asks, and YES pops the screen. Triple
// Chance's popup is private to its screen, so its stand-in copies it: a general
// dialog that answers NO by itself after 5 seconds. The real screens themselves
// are checked by hand on the Windows app.
import 'package:best_smart_game/widgets/desktop_window/desktop_close_guard.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_exit_dialog.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_exit_dialog.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_exit_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Triple Chance popup's behaviour, including its 5-second NO.
Future<bool?> _tripleChanceExit(BuildContext context) {
  var isClosed = false;
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'ExitConfirmation',
    pageBuilder: (ctx, _, __) {
      Future.delayed(const Duration(seconds: 5), () {
        if (ctx.mounted && !isClosed && Navigator.of(ctx).canPop()) {
          isClosed = true;
          Navigator.of(ctx).pop(false);
        }
      });
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              key: const ValueKey('tc-no'),
              onPressed: () {
                isClosed = true;
                Navigator.of(ctx).pop(false);
              },
              child: const Text('NO'),
            ),
            TextButton(
              key: const ValueKey('tc-yes'),
              onPressed: () {
                isClosed = true;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('YES'),
            ),
          ],
        ),
      );
    },
  );
}

/// A game screen that leaves the way all four real ones do.
class _Game extends StatefulWidget {
  final Future<bool?> Function(BuildContext) ask;
  const _Game(this.ask);
  @override
  State<_Game> createState() => _GameState();
}

class _GameState extends State<_Game> {
  bool _allowPop = false;
  bool _asking = false;

  Future<void> _requestExit() async {
    if (_asking) return;
    _asking = true;
    final leave = await widget.ask(context);
    _asking = false;
    if (leave == true && mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        body: Center(child: TextButton(onPressed: _requestExit, child: const Text('GAME EXIT'))),
      ),
    );
  }
}

class _Rig {
  final key = GlobalKey<NavigatorState>();
  final log = <String>[];
  late final DesktopCloseController controller;
  Future<void> Function() session = () async {};
  bool overPopup = false;

  _Rig() {
    controller = DesktopCloseController(
      findNavigator: () => key.currentState,
      endSession: () async {
        log.add('session');
        await session();
      },
      closeOverPopup: () => overPopup,
      hideWindow: () async => log.add('hide'),
      destroyWindow: () async => log.add('destroy'),
    );
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [controller],
      home: const Scaffold(body: Text('LOBBY')),
    ));
  }

  Future<void> pushGame(WidgetTester tester, Future<bool?> Function(BuildContext) ask) async {
    key.currentState!.push(MaterialPageRoute<void>(builder: (_) => _Game(ask)));
    await tester.pumpAndSettle();
  }

  /// Asks to close, then lets the popup finish opening.
  Future<void> close(WidgetTester tester) async {
    controller.requestClose();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Runs past every delay, however long a popup's own countdown is.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }
}

const _closed = ['hide', 'session', 'destroy'];

void main() {
  group('login or lobby', () {
    testWidgets('closes at once, ending the session', (tester) async {
      final rig = _Rig();
      await rig.open(tester);
      await rig.controller.requestClose();
      expect(rig.log, _closed);
    });

    testWidgets('a failed logout still closes', (tester) async {
      final rig = _Rig()..session = () async => throw Exception('no network');
      await rig.open(tester);
      await rig.controller.requestClose();
      expect(rig.log, _closed);
    });

    testWidgets('a logout that never answers still closes after the wait', (tester) async {
      final rig = _Rig()..session = () => Future<void>.delayed(const Duration(minutes: 5));
      await rig.open(tester);
      rig.controller.requestClose();
      await tester.pump();
      expect(rig.log, ['hide', 'session']);
      await tester.pump(DesktopCloseController.sessionTimeout);
      await tester.pump();
      expect(rig.log, _closed);
      await tester.pump(const Duration(minutes: 5));
    });
  });

  group('other popups', () {
    testWidgets('one that can be closed closes alone; the next X closes the app', (tester) async {
      final rig = _Rig();
      await rig.open(tester);
      showDialog<void>(context: rig.key.currentContext!, builder: (_) => const Text('HISTORY'));
      await tester.pumpAndSettle();
      await rig.close(tester);
      await rig.settle(tester);
      expect(find.text('HISTORY'), findsNothing);
      expect(rig.log, isEmpty);
      await rig.controller.requestClose();
      expect(rig.log, _closed);
    });

    testWidgets('one over a game closes alone and the game stays', (tester) async {
      final rig = _Rig();
      await rig.open(tester);
      await rig.pushGame(tester, _tripleChanceExit);
      showDialog<void>(context: rig.key.currentContext!, builder: (_) => const Text('HISTORY'));
      await tester.pumpAndSettle();
      await rig.close(tester);
      await rig.settle(tester);
      expect(find.text('HISTORY'), findsNothing);
      expect(find.text('GAME EXIT'), findsOneWidget);
      expect(rig.log, isEmpty);
    });

    testWidgets('one that must be answered stays', (tester) async {
      final rig = _Rig();
      await rig.open(tester);
      showDialog<void>(
        context: rig.key.currentContext!,
        barrierDismissible: false,
        builder: (_) => const PopScope(canPop: false, child: Text('ACCOUNT BLOCKED')),
      );
      await tester.pumpAndSettle();
      await rig.close(tester);
      await rig.settle(tester);
      expect(find.text('ACCOUNT BLOCKED'), findsOneWidget);
      expect(rig.log, isEmpty);
    });
  });

  testWidgets('NO INTERNET popup: X closes the app straight through it', (tester) async {
    final rig = _Rig()..overPopup = true;
    await rig.open(tester);
    showDialog<void>(
      context: rig.key.currentContext!,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: Text('NO INTERNET')),
    );
    await tester.pumpAndSettle();
    await rig.controller.requestClose();
    expect(rig.log, _closed);
  });

  testWidgets('a forced logout during the Exit popup leaves X working', (tester) async {
    final rig = _Rig();
    await rig.open(tester);
    await rig.pushGame(tester, _tripleChanceExit);
    await rig.close(tester);
    rig.key.currentState!.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('LOGIN'))),
      (_) => false,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await rig.controller.requestClose();
    expect(rig.log, _closed);
  });

  final games = <(String, Future<bool?> Function(BuildContext), String, String)>[
    ('Triple Chance', _tripleChanceExit, 'tc-no', 'tc-yes'),
    ('Lucky Card', LuckyCardExitDialog.show, 'exit-no', 'exit-yes'),
    ('Lucky 16', Lucky16ExitDialog.show, 'exit-no', 'exit-yes'),
    ('Spin2Win', Spin2WinExitDialog.show, 'spin2win-exit-no', 'spin2win-exit-yes'),
  ];

  for (final (name, ask, no, yes) in games) {
    group(name, () {
      testWidgets('X, then NO: keeps playing and nothing closes', (tester) async {
        final rig = _Rig();
        await rig.open(tester);
        await rig.pushGame(tester, ask);
        await rig.close(tester);
        await tester.tap(find.byKey(ValueKey(no)));
        await rig.settle(tester);
        await tester.pump(const Duration(seconds: 6));
        expect(find.text('GAME EXIT'), findsOneWidget);
        expect(rig.log, isEmpty);
      });

      testWidgets('X, then YES: the game leaves, then the whole app closes', (tester) async {
        final rig = _Rig();
        await rig.open(tester);
        await rig.pushGame(tester, ask);
        await rig.close(tester);
        await tester.tap(find.byKey(ValueKey(yes)));
        await rig.settle(tester);
        await tester.pump(const Duration(seconds: 6));
        expect(find.text('GAME EXIT'), findsNothing);
        expect(rig.log, _closed);
      });

      testWidgets('the game\'s own EXIT, YES: back to the lobby, the app stays open', (tester) async {
        final rig = _Rig();
        await rig.open(tester);
        await rig.pushGame(tester, ask);
        await tester.tap(find.text('GAME EXIT'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byKey(ValueKey(yes)));
        await rig.settle(tester);
        await tester.pump(const Duration(seconds: 6));
        expect(find.text('LOBBY'), findsOneWidget);
        expect(rig.log, isEmpty);
      });

      testWidgets('X then NO, later the game\'s own EXIT and YES: the app stays open', (tester) async {
        final rig = _Rig();
        await rig.open(tester);
        await rig.pushGame(tester, ask);
        await rig.close(tester);
        await tester.tap(find.byKey(ValueKey(no)));
        await rig.settle(tester);
        await tester.tap(find.text('GAME EXIT'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byKey(ValueKey(yes)));
        await rig.settle(tester);
        await tester.pump(const Duration(seconds: 6));
        expect(find.text('LOBBY'), findsOneWidget);
        expect(rig.log, isEmpty);
      });

      testWidgets('pressing X twice does not answer the popup for the player', (tester) async {
        final rig = _Rig();
        await rig.open(tester);
        await rig.pushGame(tester, ask);
        await rig.close(tester);
        await rig.controller.requestClose();
        await rig.settle(tester);
        expect(find.byKey(ValueKey(yes)), findsOneWidget);
        await tester.tap(find.byKey(ValueKey(no)));
        await rig.settle(tester);
        await tester.pump(const Duration(seconds: 6));
      });
    });
  }

  group('Alt+F4', () {
    Future<void> openGuarded(WidgetTester tester, _Rig rig) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rig.key,
        navigatorObservers: [rig.controller],
        builder: (context, child) => DesktopCloseGuard(controller: rig.controller, child: child!),
        home: const Scaffold(body: Text('LOBBY')),
      ));
    }

    Future<void> altF4(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.f4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }

    testWidgets('in a game: shows the Exit popup and the app stays open', (tester) async {
      final rig = _Rig();
      await openGuarded(tester, rig);
      await rig.pushGame(tester, _tripleChanceExit);
      await altF4(tester);
      expect(find.byKey(const ValueKey('tc-yes')), findsOneWidget);
      expect(rig.log, isEmpty);
      await tester.tap(find.byKey(const ValueKey('tc-no')));
      await rig.settle(tester);
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('GAME EXIT'), findsOneWidget);
      expect(rig.log, isEmpty);
      await finish(tester);
    });

    testWidgets('in a game, then YES: the app closes', (tester) async {
      final rig = _Rig();
      await openGuarded(tester, rig);
      await rig.pushGame(tester, _tripleChanceExit);
      await altF4(tester);
      await tester.tap(find.byKey(const ValueKey('tc-yes')));
      await rig.settle(tester);
      await tester.pump(const Duration(seconds: 6));
      expect(rig.log, _closed);
      await finish(tester);
    });

    testWidgets('in the lobby: closes', (tester) async {
      final rig = _Rig();
      await openGuarded(tester, rig);
      await altF4(tester);
      expect(rig.log, _closed);
      await finish(tester);
    });

    testWidgets('F4 alone does nothing', (tester) async {
      final rig = _Rig();
      await openGuarded(tester, rig);
      await tester.sendKeyEvent(LogicalKeyboardKey.f4);
      await tester.pump();
      expect(rig.log, isEmpty);
      await finish(tester);
    });
  });

  testWidgets('Triple Chance popup left alone answers NO after 5 seconds: nothing closes', (tester) async {
    final rig = _Rig();
    await rig.open(tester);
    await rig.pushGame(tester, _tripleChanceExit);
    await rig.close(tester);
    await tester.pump(const Duration(seconds: 6));
    await rig.settle(tester);
    expect(find.text('GAME EXIT'), findsOneWidget);
    expect(rig.log, isEmpty);
  });
}
