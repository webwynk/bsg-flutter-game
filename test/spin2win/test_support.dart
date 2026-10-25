// Shared helpers for the Spin2Win unit tests.
//
// The fixtures (test/spin2win/fixtures/) are shaped exactly as the live Spin2Win
// functions build their answers (migration 20261024250000, applied 2026-10-24).
// Once the app has run against the live database they should be replaced with
// captured answers, as Lucky Card's were.

import 'dart:convert';
import 'dart:io';

/// Reads and decodes a JSON fixture. `flutter test` runs from the package root.
dynamic loadFixture(String name) =>
    jsonDecode(File('test/spin2win/fixtures/$name').readAsStringSync());

/// A fixture that is a JSON object.
Map<String, dynamic> loadFixtureMap(String name) =>
    Map<String, dynamic>.from(loadFixture(name) as Map);
