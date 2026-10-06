// Shared helpers for the Lucky Card unit tests.
//
// The fixtures are real answers captured from the live database on 2026-10-06
// (see test/lucky_card/fixtures/), so a test that parses one proves the app
// understands what the database actually sends, not what someone assumed.

import 'dart:convert';
import 'dart:io';

/// Reads and decodes a JSON fixture. `flutter test` runs from the package root.
dynamic loadFixture(String name) =>
    jsonDecode(File('test/lucky_card/fixtures/$name').readAsStringSync());

/// A fixture that is a JSON object.
Map<String, dynamic> loadFixtureMap(String name) =>
    Map<String, dynamic>.from(loadFixture(name) as Map);
