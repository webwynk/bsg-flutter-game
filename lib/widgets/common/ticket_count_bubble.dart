import 'package:flutter/material.dart';

/// The most the bubble spells out. The server's list also stops at 500.
const int kTicketBubbleMax = 500;

/// What the bubble says for [count] tickets: the number, or 500+ from there on.
String ticketBubbleText(int count) => count >= kTicketBubbleMax ? '$kTicketBubbleMax+' : '$count';

/// The small red bubble on the corner of the Tickets button, in all four games.
/// It draws over the button, so a big number never moves or stretches anything.
class TicketCountBubble extends StatelessWidget {
  const TicketCountBubble({super.key, required this.count, required this.fontSize});

  final int count;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        key: const ValueKey('ticket-count-bubble'),
        constraints: BoxConstraints(minWidth: fontSize * 1.7),
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.4, vertical: fontSize * 0.12),
        decoration: BoxDecoration(
          color: const Color(0xFFD90429),
          borderRadius: BorderRadius.circular(fontSize),
        ),
        child: Text(
          ticketBubbleText(count),
          maxLines: 1,
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            height: 1.2,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
