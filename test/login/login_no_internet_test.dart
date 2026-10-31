// The real login call with no server to reach. It must say so, and never say
// "wrong password". The test Supabase address has nothing listening on it, so
// the connection is refused the way it is with Wi-Fi off.
import 'dart:io';

import 'package:best_smart_game/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'login_test_harness.dart';

void main() {
  setUpAll(setUpLoginTests);

  test('no connection gives the connection message, not wrong password', () async {
    // Flutter's test system fakes every web call; this test needs the real one.
    final fakeWeb = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = fakeWeb);

    final outcome = await ApiService().login('player01', 'secret1');

    expect(outcome.success, isFalse);
    expect(outcome.error, 'Connection error. Please check your network connection.');
    expect(outcome.attemptsRemaining, isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
