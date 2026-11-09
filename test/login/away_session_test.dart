// The wrong "opened on another device" message after being away (B-5;
// docs/loadtest/AWAY_MESSAGE_PLAN_2026-11-09.md), on a fake clock with a stand-in server.
//
// Before the fix (recorded 2026-11-09): freeing the seat for being away left the heartbeat running,
// the server then answered "session_displaced", and the player was logged out with "Your account
// was opened on another device" before the "YOU WERE AWAY" popup could show. After: once the seat
// is given up, the heartbeat stops asking and ignores a reply already on its way.
//
// The real session rules, read from the live database on 2026-11-09: session_logout deletes the
// player's seat; session_heartbeat answers 'session_displaced' when the seat is missing OR held
// by another token (it has no time limit), and otherwise refreshes it.

import 'dart:async';

import 'package:best_smart_game/models/user_model.dart';
import 'package:best_smart_game/providers/auth_provider.dart';
import 'package:best_smart_game/services/api_contract.dart';
import 'package:best_smart_game/utils/away_clock.dart';
import 'package:flutter_test/flutter_test.dart';
// Reached through supabase_flutter: AuthProvider's constructor listens to the Supabase client,
// so it must exist. Nothing here reaches a real server.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The server's view of this player's seat.
class SeatServer {
  bool seatHeld = true;
  bool blocked = false;
  int heartbeats = 0;

  /// When set, the next heartbeat waits for this before answering (a reply still on its way).
  Completer<void>? holdNextHeartbeat;

  Future<Map<String, dynamic>?> heartbeat(String token) async {
    heartbeats++;
    final hold = holdNextHeartbeat;
    holdNextHeartbeat = null;
    if (hold != null) await hold.future;
    if (blocked) return {Field.allowed: false, Field.reason: ReasonCode.accountBlocked};
    if (!seatHeld) return {Field.allowed: false, Field.reason: ReasonCode.sessionDisplaced};
    return {Field.allowed: true, Field.coinBalance: 1000, Field.ledgerVersion: 1};
  }

  Future<void> releaseSeat() async => seatHeld = false;

  Future<void> logout() async => seatHeld = false;
}

const String anotherDevice = 'Your account was opened on another device.';

({AuthProvider auth, SeatServer server}) signedIn() {
  final server = SeatServer();
  final auth = AuthProvider()
    ..configureForTest(
      heartbeat: server.heartbeat,
      releaseSeat: server.releaseSeat,
      logout: server.logout,
      signedIn: const UserModel(id: 'u1', username: 'raj', coinBalance: 1000, token: 't1'),
    );
  return (auth: auth, server: server);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      // ignore: deprecated_member_use
      anonKey: 'test-key-not-real',
    );
  });

  testWidgets('playing normally: the heartbeat keeps the session', (tester) async {
    final s = signedIn();
    await tester.pump(const Duration(seconds: 46));
    expect(s.server.heartbeats, 3);
    expect(s.auth.isLoggedIn, isTrue);
    expect(s.auth.forcedLogout, isFalse);
    s.auth.dispose();
  });

  testWidgets('away 20 s frees the seat: the heartbeat stops asking, so no "opened on another device" '
      '(before the fix: logged out with that message)', (tester) async {
    final s = signedIn();
    await tester.pump(const Duration(seconds: 20)); // the app went to the background; 20 s pass
    await s.auth.releaseSessionSlot(); // what main.dart's away guard does at 20 s
    final asked = s.server.heartbeats;
    await tester.pump(const Duration(seconds: 61)); // a long call
    expect(s.server.heartbeats, asked, reason: 'no heartbeat while the seat is given up');
    expect(s.auth.isLoggedIn, isTrue, reason: 'still signed in, so the "YOU WERE AWAY" popup runs on return');
    expect(s.auth.forcedLogout, isFalse);
    s.auth.dispose();
  });

  testWidgets('after the away logout, a new sign-in starts the heartbeat normally again', (tester) async {
    final s = signedIn();
    await s.auth.releaseSessionSlot();
    await s.auth.logout(); // "YOU WERE AWAY" -> OK
    s.server.seatHeld = true;
    s.auth.configureForTest(
      heartbeat: s.server.heartbeat,
      releaseSeat: s.server.releaseSeat,
      logout: s.server.logout,
      signedIn: const UserModel(id: 'u1', username: 'raj', coinBalance: 1000, token: 't2'),
    );
    final before = s.server.heartbeats;
    await tester.pump(const Duration(seconds: 16));
    expect(s.server.heartbeats, before + 1);
    expect(s.auth.forcedLogout, isFalse);
    s.auth.dispose();
  });

  testWidgets('a heartbeat already on its way when the seat is freed: its "displaced" is ignored '
      '(before the fix: logged out with "opened on another device")', (tester) async {
    final s = signedIn();
    final hold = Completer<void>();
    s.server.holdNextHeartbeat = hold;
    await tester.pump(const Duration(seconds: 15)); // a heartbeat leaves, its reply is delayed
    await s.auth.releaseSessionSlot();
    hold.complete();
    await tester.pump();
    expect(s.auth.forcedLogout, isFalse);
    expect(s.auth.isLoggedIn, isTrue);
    s.auth.dispose();
  });

  testWidgets('another device really takes the seat while playing: "opened on another device"', (tester) async {
    final s = signedIn();
    await tester.pump(const Duration(seconds: 10));
    s.server.seatHeld = false; // someone logged in elsewhere
    await tester.pump(const Duration(seconds: 6));
    expect(s.auth.forcedLogout, isTrue);
    expect(s.auth.forcedLogoutReason, anotherDevice);
    s.auth.dispose();
  });

  testWidgets('a blocked account is told so', (tester) async {
    final s = signedIn();
    s.server.blocked = true;
    await tester.pump(const Duration(seconds: 16));
    expect(s.auth.forcedLogout, isTrue);
    expect(s.auth.forcedLogoutReason, contains('blocked'));
    s.auth.dispose();
  });

  group('the real time away (AwayClock)', () {
    late DateTime clock;
    late FakeStopwatch watch;
    AwayClock away() => AwayClock(now: () => clock, stopwatch: () => watch = FakeStopwatch());

    setUp(() => clock = DateTime.utc(2026, 11, 9, 10));

    test('phone asleep 5 minutes: the stopwatch stood still, the clock did not -> away', () {
      final a = away()..markLeft();
      clock = clock.add(const Duration(minutes: 5));
      watch.elapsedValue = const Duration(seconds: 1);
      expect(a.awayFor, const Duration(minutes: 5));
      expect(a.awayAtLeast(const Duration(seconds: 20)), isTrue);
    });

    test('the phone clock moved back 2 minutes while away: the stopwatch still counts -> away', () {
      final a = away()..markLeft();
      clock = clock.subtract(const Duration(minutes: 2));
      watch.elapsedValue = const Duration(seconds: 25);
      expect(a.awayAtLeast(const Duration(seconds: 20)), isTrue);
    });

    test('back after 10 seconds: not away', () {
      final a = away()..markLeft();
      clock = clock.add(const Duration(seconds: 10));
      watch.elapsedValue = const Duration(seconds: 10);
      expect(a.awayAtLeast(const Duration(seconds: 20)), isFalse);
    });

    test('never left (or already cleared): not away', () {
      final a = away();
      expect(a.awayFor, isNull);
      expect(a.awayAtLeast(Duration.zero), isFalse);
      a.markLeft();
      a.clear();
      expect(a.awayAtLeast(Duration.zero), isFalse);
    });
  });
}

/// A stopwatch whose elapsed time the test sets.
class FakeStopwatch implements Stopwatch {
  Duration elapsedValue = Duration.zero;

  @override
  Duration get elapsed => elapsedValue;

  @override
  void start() {}

  @override
  void stop() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
