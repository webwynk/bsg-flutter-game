// The red count on the Tickets button.
import 'package:best_smart_game/widgets/common/ticket_count_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the number, then 500+', () {
    expect(ticketBubbleText(1), '1');
    expect(ticketBubbleText(499), '499');
    expect(ticketBubbleText(500), '500+');
    expect(ticketBubbleText(1200), '500+');
  });

  testWidgets('the biggest bubble does not change the button under it', (tester) async {
    Future<Size> button(int count) async {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            key: const ValueKey('button'),
            width: 100,
            height: 30,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.purple),
                Positioned(top: -8, right: -4, child: TicketCountBubble(count: count, fontSize: 9)),
              ],
            ),
          ),
        ),
      ));
      return tester.getSize(find.byKey(const ValueKey('button')));
    }

    final small = await button(1);
    final big = await button(5000);
    expect(big, small);
    expect(find.text('500+'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
