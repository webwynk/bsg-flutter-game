// The Tickets list and Printer settings popups of Lucky Card, in the approved design: dark red
// with a gold edge, three stat boxes, one row per ticket with REPRINT. The list is this session's;
// older tickets are in History.
//
// Belongs to Lucky Card only.

import 'package:flutter/material.dart';

import '../../print_ticket/lucky_card_print_controller.dart';
import '../../print_ticket/print_settings_store.dart';
import '../../print_ticket/lucky_card_tickets.dart';
import '../../print_ticket/printer_readiness.dart';
import '../../print_ticket/ticket_model.dart';
import '../../print_ticket/ticket_renderer.dart';
import '../../utils/round_id.dart';
import 'lucky_card_top_bar.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldBright = Color(0xFFFFD700);
const Color _kCream = Color(0xFFF5E6C4);
const Color _kMuted = Color(0xFFC9B58F);

BoxDecoration _frame() => BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _kGold, width: 1.5),
      gradient: const LinearGradient(colors: [Color(0xFF2A0800), Color(0xFF0C0000)]),
    );

String _clock(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

class _Scaled extends StatelessWidget {
  const _Scaled({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Center(
      child: FittedBox(
        child: SizedBox(
          width: width * size.width / 1920 < size.width ? width : 1920,
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

Widget _header(BuildContext context, String title, String? line, {Widget? action}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x59D4AF37)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontFamily: 'DMSans',
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: 1.4,
                        color: _kGoldBright)),
                if (line != null)
                  Text(line,
                      style: const TextStyle(
                          fontFamily: 'DMSans', fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xB3FFFFFF))),
              ],
            ),
          ),
          if (action != null) ...[action, const SizedBox(width: 14)],
          IconButton(
            key: const ValueKey('print-popup-close'),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: _kGoldBright),
          ),
        ],
      ),
    );

Widget _stat(String label, String value, List<Color> colors) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontFamily: 'DMSans',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1,
                    color: Colors.white)),
            Text(value,
                maxLines: 1,
                style: const TextStyle(
                    fontFamily: 'Oswald', fontWeight: FontWeight.w700, fontSize: 32, color: Colors.white)),
          ],
        ),
      ),
    );

class LuckyCardTicketsDialog extends StatelessWidget {
  const LuckyCardTicketsDialog({
    super.key,
    required this.controller,
    required this.renderer,
    required this.settings,
    required this.status,
  });

  final LuckyCardPrintController controller;
  final Future<TicketRenderer> Function() renderer;
  final PrintSettingsStore settings;
  final PrinterStatusReader status;

  static Future<void> show(
    BuildContext context, {
    required LuckyCardPrintController controller,
    required Future<TicketRenderer> Function() renderer,
    required PrintSettingsStore settings,
    required PrinterStatusReader status,
  }) {
    controller.reloadTickets();
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0xD1000000),
      builder: (_) => LuckyCardTicketsDialog(controller: controller, renderer: renderer, settings: settings, status: status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 1920 / MediaQuery.sizeOf(context).width;
    return _Scaled(
      width: 1400,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final tickets = controller.tickets;
          final play = tickets.fold<int>(0, (s, t) => s + t.totalStake);
          return Container(
            constraints: BoxConstraints(maxHeight: height * 0.86),
            decoration: _frame(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(
                  context,
                  'TICKETS · LUCKY CARD',
                  'This session only. @${controller.player}',
                  action: TextButton.icon(
                    key: const ValueKey('printer-settings'),
                    onPressed: () => LuckyCardPrinterDialog.show(context, renderer: renderer, settings: settings, status: status),
                    icon: const Icon(Icons.print, color: _kGoldBright),
                    label: const Text('PRINTER', style: TextStyle(fontFamily: 'Oswald', fontSize: 18, color: _kGoldBright)),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _stat('TICKETS', '${tickets.length}', const [Color(0xFF4F8DFF), Color(0xFF1A44B8)]),
                            const SizedBox(width: 16),
                            _stat('TOTAL PLAY', luckyCardGroupedBalance(play),
                                const [Color(0xFFFFB347), Color(0xFFA84A05)]),
                            const SizedBox(width: 16),
                            _stat('LAST TICKET', tickets.isEmpty ? '-' : tickets.first.code,
                                const [Color(0xFF4FDC7A), Color(0xFF158A3C)]),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: tickets.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) => _TicketRow(ticket: tickets[i], controller: controller),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Reprint prints the same ticket marked COPY. No coins are taken. This list clears when you leave the game; older tickets are in History.',
                          style: TextStyle(fontFamily: 'DMSans', fontWeight: FontWeight.w500, fontSize: 15, color: _kMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.controller});

  final LuckyCardTicket ticket;
  final LuckyCardPrintController controller;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(fontFamily: 'DMSans', fontWeight: FontWeight.w500, fontSize: 16, color: _kCream);
    final failed = !ticket.wasPrinted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0x0DFFFFFF),
        border: Border.all(color: const Color(0x33D4AF37)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 230,
            child: Text(ticket.code,
                style: const TextStyle(fontFamily: 'Oswald', fontWeight: FontWeight.w700, fontSize: 22, color: Color(0xFFFFE58A))),
          ),
          SizedBox(width: 130, child: Text(GameRound.luckyCard.id(ticket.roundNumber), style: body)),
          SizedBox(width: 110, child: Text(_clock(ticket.createdAt), style: body)),
          Expanded(child: Text(ticket.betsText, maxLines: 2, overflow: TextOverflow.ellipsis, style: body)),
          SizedBox(
            width: 100,
            child: Text(luckyCardGroupedBalance(ticket.totalStake),
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'Oswald', fontWeight: FontWeight.w700, fontSize: 22, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            height: 44,
            child: FilledButton(
              key: ValueKey('reprint-${ticket.id}'),
              style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: const Color(0xFF2A0408)),
              onPressed: controller.printing ? null : () => controller.reprint(ticket),
              child: Text(failed ? 'PRINT' : 'REPRINT',
                  style: const TextStyle(fontFamily: 'Oswald', fontWeight: FontWeight.w700, fontSize: 17)),
            ),
          ),
        ],
      ),
    );
  }
}

class LuckyCardPrinterDialog extends StatefulWidget {
  const LuckyCardPrinterDialog({super.key, required this.renderer, required this.settings, required this.status});

  final Future<TicketRenderer> Function() renderer;
  final PrintSettingsStore settings;
  final PrinterStatusReader status;

  static Future<void> show(
    BuildContext context, {
    required Future<TicketRenderer> Function() renderer,
    required PrintSettingsStore settings,
    required PrinterStatusReader status,
  }) =>
      showDialog<void>(
        context: context,
        barrierColor: const Color(0xD1000000),
        builder: (_) => LuckyCardPrinterDialog(renderer: renderer, settings: settings, status: status),
      );

  @override
  State<LuckyCardPrinterDialog> createState() => _LuckyCardPrinterDialogState();
}

class _LuckyCardPrinterDialogState extends State<LuckyCardPrinterDialog> {
  List<TicketPrinter> _printers = const [];
  String? _chosen;
  TicketPaper _paper = TicketPaper.mm80;
  PrinterReadiness? _ready;
  String? _note;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await widget.settings.printer();
    final paper = await widget.settings.paper();
    final printers = await (await widget.renderer()).listPrinters();
    if (!mounted) return;
    setState(() {
      _printers = printers;
      _paper = paper;
      _chosen = saved ??
          (printers.isEmpty
              ? null
              : printers.firstWhere((p) => p.isDefault, orElse: () => printers.first).name);
    });
    await _check();
  }

  Future<void> _check() async {
    final name = _chosen;
    if (name == null) return;
    final ready = await widget.status.check(name);
    if (mounted) setState(() => _ready = ready);
  }

  Future<void> _test() async {
    final name = _chosen;
    if (name == null) return;
    await _check();
    if (_ready != PrinterReadiness.ready) {
      setState(() => _note = printerProblem(_ready!, name).replaceAll(' No coins were taken.', ''));
      return;
    }
    final result = await (await widget.renderer())
        .printTicket(SampleTickets.luckyCard, printer: TicketPrinter(name: name), paper: _paper);
    if (mounted) setState(() => _note = result.message);
  }

  Future<void> _save() async {
    final name = _chosen;
    if (name == null) return;
    await widget.settings.save(name, _paper);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
        fontFamily: 'DMSans', fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.3, color: _kGold);
    final ready = _ready == PrinterReadiness.ready;
    return _Scaled(
      width: 800,
      child: Container(
        decoration: _frame(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, 'PRINTER SETTINGS', null),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 26, 30, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('PRINTER', style: label),
                  const SizedBox(height: 8),
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0800),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF4A1500)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              key: const ValueKey('printer-choice'),
                              value: _chosen,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1A0800),
                              iconEnabledColor: _kGold,
                              style: const TextStyle(fontFamily: 'DMSans', fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white),
                              items: [for (final p in _printers) DropdownMenuItem(value: p.name, child: Text(p.name))],
                              onChanged: (v) {
                                setState(() {
                                  _chosen = v;
                                  _ready = null;
                                });
                                _check();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(_ready == null ? '' : (ready ? 'Ready' : 'Not ready'),
                            style: TextStyle(
                                fontFamily: 'DMSans',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: ready ? const Color(0xFF4DFF8A) : const Color(0xFFFF7A7A))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('PAPER WIDTH', style: label),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final paper in TicketPaper.values) ...[
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: FilledButton(
                              key: ValueKey('paper-${paper.name}'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _paper == paper ? _kGold : const Color(0xFF1A0800),
                                foregroundColor: _paper == paper ? const Color(0xFF2A0408) : _kMuted,
                              ),
                              onPressed: () => setState(() => _paper = paper),
                              child: Text(paper.label,
                                  style: const TextStyle(fontFamily: 'Oswald', fontWeight: FontWeight.w700, fontSize: 22)),
                            ),
                          ),
                        ),
                        if (paper != TicketPaper.values.last) const SizedBox(width: 14),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 58,
                          child: FilledButton(
                            key: const ValueKey('printer-test'),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1AA3FF), foregroundColor: Colors.white),
                            onPressed: _chosen == null ? null : _test,
                            child: const Text('TEST PRINT', style: TextStyle(fontFamily: 'Oswald', fontWeight: FontWeight.w700, fontSize: 20)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 58,
                          child: FilledButton(
                            key: const ValueKey('printer-save'),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00AA00), foregroundColor: Colors.white),
                            onPressed: _chosen == null ? null : _save,
                            child: const Text('SAVE', style: TextStyle(fontFamily: 'Oswald', fontWeight: FontWeight.w700, fontSize: 20)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _note ??
                        'Tickets print straight to this printer, with no Windows print window. The choice is remembered on this computer. If the printer is off or unplugged, Print shows "Printer not ready" and no coins are taken.',
                    style: const TextStyle(fontFamily: 'DMSans', fontWeight: FontWeight.w500, fontSize: 15, height: 1.5, color: _kMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
