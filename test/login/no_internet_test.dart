// The lobby's connection watch and the NO INTERNET popup, on every device. The
// checks are scripted, so nothing here needs a real network.
import 'package:best_smart_game/screens/lobby_screen.dart';
import 'package:best_smart_game/services/connection_watcher.dart';
import 'package:best_smart_game/widgets/dialogs/no_internet_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'login_test_harness.dart';

const _step = ConnectionWatcher.interval;
const _popup = ValueKey('no-internet-popup');

/// A lobby whose connection check answers from [online], counting its calls.
class _Net {
  bool online = true;
  int checks = 0;

  Future<bool> check() async {
    checks++;
    return online;
  }
}

Future<void> _lobby(WidgetTester tester, FakeAuth auth, _Net net, {DateTime Function() clock = DateTime.now}) async {
  setScreen(tester, const Size(844, 390));
  await tester.pumpWidget(loginApp(auth, LobbyScreen(connectionCheck: net.check, clock: clock)));
  await decodeImages(tester);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// Lets [n] checks run.
Future<void> _checks(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(_step);
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(setUpLoginTests);

  group('the watcher', () {
    testWidgets('its numbers are the approved ones', (tester) async {
      expect(ConnectionWatcher.interval, const Duration(seconds: 5));
      expect(ConnectionWatcher.failuresToReport, 2);
      expect(ConnectionWatcher.longOutage, const Duration(seconds: 30));
    });

    testWidgets('it tells a long outage from a short one, using the clock', (tester) async {
      var clock = DateTime(2026);
      var online = false;
      final events = <String>[];
      final w = ConnectionWatcher(
        ping: () async => online,
        isActive: () => true,
        onLost: () => events.add('lost'),
        onBack: (long) => events.add('back $long'),
        now: () => clock,
      )..start();
      Future<void> tick() async {
        clock = clock.add(_step);
        await tester.pump(_step);
        await tester.pump();
      }

      await tick();
      expect(events, isEmpty);
      await tick();
      expect(events, ['lost']);
      online = true;
      await tick();
      expect(events, ['lost', 'back false']);
      online = false;
      await tick();
      await tick();
      expect(events.last, 'lost');
      clock = clock.add(ConnectionWatcher.longOutage);
      online = true;
      await tick();
      expect(events.last, 'back true');
      w.stop();
    });
  });

  group('lobby', () {
    testWidgets('one failed check shows nothing', (tester) async {
      final net = _Net()..online = false;
      await _lobby(tester, FakeAuth(), net);
      await _checks(tester, 1);
      expect(find.byKey(_popup), findsNothing);
    });

    testWidgets('a blip that recovers shows nothing', (tester) async {
      final net = _Net()..online = false;
      await _lobby(tester, FakeAuth(), net);
      await _checks(tester, 1);
      net.online = true;
      await _checks(tester, 1);
      net.online = false;
      await _checks(tester, 1);
      expect(find.byKey(_popup), findsNothing);
    });

    testWidgets('two failed checks show the popup, with no button', (tester) async {
      final net = _Net()..online = false;
      await _lobby(tester, FakeAuth(), net);
      await _checks(tester, 2);
      expect(find.text('NO INTERNET'), findsOneWidget);
      expect(find.text('Please check your connection. Reconnecting automatically...'), findsOneWidget);
      expect(find.text('OK'), findsNothing);
      expect(noInternetShowing.value, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it cannot be dismissed by tapping outside or back', (tester) async {
      final net = _Net()..online = false;
      await _lobby(tester, FakeAuth(), net);
      await _checks(tester, 2);
      await tester.tapAt(const Offset(4, 4));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_popup), findsOneWidget);
    });

    testWidgets('internet back soon: the popup goes and the player stays', (tester) async {
      final auth = FakeAuth();
      final net = _Net()..online = false;
      await _lobby(tester, auth, net);
      await _checks(tester, 2);
      net.online = true;
      await _checks(tester, 1);
      await tester.pumpAndSettle();
      expect(find.byKey(_popup), findsNothing);
      expect(noInternetShowing.value, isFalse);
      expect(auth.forcedLogout, isFalse);
    });

    testWidgets('the popup stays for as long as the internet is off', (tester) async {
      final net = _Net()..online = false;
      await _lobby(tester, FakeAuth(), net);
      await _checks(tester, 4);
      expect(find.byKey(_popup), findsOneWidget);
    });

    testWidgets('leaving the lobby stops the checks', (tester) async {
      final net = _Net();
      await _lobby(tester, FakeAuth(), net);
      await tester.pumpWidget(const SizedBox.shrink());
      final before = net.checks;
      await tester.pump(_step * 3);
      expect(net.checks, before);
      expect(noInternetShowing.value, isFalse);
    });

    testWidgets('a game or popup on top pauses the checks; coming back resumes them', (tester) async {
      final net = _Net();
      await _lobby(tester, FakeAuth(), net);
      Navigator.of(tester.element(find.byType(LobbyScreen)))
          .push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('GAME'))));
      await tester.pumpAndSettle();
      final before = net.checks;
      await _checks(tester, 3);
      expect(net.checks, before, reason: 'no checks while a game is open');
      expect(find.byKey(_popup), findsNothing);
      Navigator.of(tester.element(find.text('GAME'))).pop();
      await tester.pumpAndSettle();
      await _checks(tester, 1);
      expect(net.checks, before + 1);
    });
  });

  group('a long outage', () {
    testWidgets('over 30 seconds off: back to login with the message', (tester) async {
      final auth = FakeAuth();
      final net = _Net()..online = false;
      var clock = DateTime(2026);
      await _lobby(tester, auth, net, clock: () => clock);
      await _checks(tester, 2);
      clock = clock.add(const Duration(seconds: 31));
      net.online = true;
      await _checks(tester, 1);
      await tester.pumpAndSettle();
      expect(find.byKey(_popup), findsNothing);
      expect(auth.forcedLogout, isTrue);
      expect(auth.forcedLogoutReason, 'Your session has ended. Please log in again.');
    });
  });
}
