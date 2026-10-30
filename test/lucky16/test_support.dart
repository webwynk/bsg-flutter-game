// Shared helpers for the Lucky 16 Card unit tests.
//
// Copied from test/lucky_card/test_support.dart. The fixtures in
// test/lucky16/fixtures/ are ADAPTED from Lucky Card's real answers captured
// from the live database on 2026-10-06, not fresh captures: the lucky16_*
// functions answer with exactly the same JSON fields and raise the same error
// codes and messages (checked against their live definitions on 2026-10-28),
// so only the values that differ for Lucky 16 Card were changed. See
// test/lucky16/fixtures/README.md for each change.

import 'dart:convert';
import 'dart:io';

/// Reads and decodes a JSON fixture. `flutter test` runs from the package root.
dynamic loadFixture(String name) =>
    jsonDecode(File('test/lucky16/fixtures/$name').readAsStringSync());

/// A fixture that is a JSON object.
Map<String, dynamic> loadFixtureMap(String name) =>
    Map<String, dynamic>.from(loadFixture(name) as Map);
