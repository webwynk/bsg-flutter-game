// The Print and Tickets buttons in the Spin2Win top bar, for the Windows app and a player who
// plays with printed tickets. Print is green while there are chips to print and betting is open,
// grey otherwise, gold while printing.
//
// Belongs to Spin2Win only.

import 'package:flutter/material.dart';

import '../common/ticket_count_bubble.dart';
import '../../print_ticket/spin2win_print_controller.dart';

class Spin2WinPrintBar extends StatelessWidget {
  const Spin2WinPrintBar({super.key, required this.controller, required this.onTickets});

  final Spin2WinPrintController controller;
  final VoidCallback onTickets;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.showButtons) return const SizedBox.shrink();
        final look = controller.look;
        return LayoutBuilder(
          builder: (context, box) {
            final font = box.maxHeight * 0.44;
            return Row(
              children: [
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    fit: StackFit.expand,
                    children: [
                      _PrintButton(
                    key: const ValueKey('print-tickets'),
                    label: 'TICKETS',
                    fontSize: font,
                    colors: const [Color(0xFFB65CFF), Color(0xFF7B2FD6), Color(0xFF4F1596)],
                    onTap: onTickets,
                  ),
                      if (controller.tickets.isNotEmpty)
                        Positioned(
                          top: -font * 0.55,
                          right: -font * 0.3,
                          child: TicketCountBubble(count: controller.tickets.length, fontSize: font * 0.62),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: box.maxWidth * 0.03),
                Expanded(
                  child: _PrintButton(
                    key: const ValueKey('print-press'),
                    label: look == Spin2WinPrintLook.printing ? 'PRINTING' : 'PRINT',
                    fontSize: font,
                    colors: switch (look) {
                      Spin2WinPrintLook.ready => const [Color(0xFF55FF55), Color(0xFF00AA00), Color(0xFF005500)],
                      Spin2WinPrintLook.printing => const [Color(0xFFFFE066), Color(0xFFD4AF37), Color(0xFF8B6914)],
                      Spin2WinPrintLook.idle => const [Color(0xFF8A8A8A), Color(0xFF5C5C5C), Color(0xFF3A3A3A)],
                    },
                    onTap: look == Spin2WinPrintLook.ready ? controller.press : null,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PrintButton extends StatelessWidget {
  const _PrintButton({
    super.key,
    required this.label,
    required this.fontSize,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final double fontSize;
  final List<Color> colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(fontSize * 0.5),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
              border: Border.all(color: const Color(0x66FFFFFF)),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: fontSize * 0.5),
                  child: Text(
                    label,
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: 'Oswald',
                      fontWeight: FontWeight.w700,
                      fontSize: fontSize,
                      letterSpacing: fontSize * 0.05,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
