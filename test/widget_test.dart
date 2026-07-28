import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:best_smart_game/main.dart';

void main() {
  testWidgets('BSG App Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(const BsgApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
