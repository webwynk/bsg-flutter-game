import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:best_smart_game/widgets/dialogs/action_dialog.dart';

/// Issue #14: proves the SERVER ERROR popup actually renders with the
/// correct, honest content, and behaves like the app's other dialogs
/// (auto-dismiss, tap-to-dismiss) -- using the exact same showActionDialog
/// call _showServerErrorDialog makes in game_screen.dart, without needing a
/// live device or a real broken round to trigger it.
void main() {
  testWidgets('SERVER ERROR dialog shows the correct honest message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showActionDialog(
                context,
                icon: Icons.sync_problem_rounded,
                title: 'SERVER ERROR',
                message:
                    "This round is taking longer than expected to resolve. Your balance will update automatically once it's ready.",
                barrierDismissible: true,
                autoDismissAfter: const Duration(seconds: 5),
              ),
              child: const Text('Trigger'),
            );
          },
        ),
      ),
    );

    // Not showing yet.
    expect(find.text('SERVER ERROR'), findsNothing);

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    // Showing now, with the exact honest wording -- critically, does NOT
    // claim coins were refunded.
    expect(find.text('SERVER ERROR'), findsOneWidget);
    expect(
      find.text(
        "This round is taking longer than expected to resolve. Your balance will update automatically once it's ready.",
      ),
      findsOneWidget,
    );
    expect(find.textContaining('refund', findRichText: true), findsNothing);
    expect(find.textContaining('returned', findRichText: true), findsNothing);
    expect(find.byIcon(Icons.sync_problem_rounded), findsOneWidget);

    // Auto-dismisses on its own after 5s, same as the app's other dialogs.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('SERVER ERROR'), findsNothing);
  });

  testWidgets('SERVER ERROR dialog is dismissible by tapping OK', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showActionDialog(
                context,
                icon: Icons.sync_problem_rounded,
                title: 'SERVER ERROR',
                message: 'test message',
                barrierDismissible: true,
              ),
              child: const Text('Trigger'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();
    expect(find.text('SERVER ERROR'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('SERVER ERROR'), findsNothing);
  });
}
