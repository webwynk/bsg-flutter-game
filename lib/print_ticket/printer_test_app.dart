import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'ticket_model.dart';
import 'ticket_pdf.dart';
import 'ticket_renderer.dart';

/// The printer test tool. Opened only by starting the Windows app with
/// --printer-test (see main.dart); no player can reach it, and it uses no
/// account, game or database. It lists printers, previews the sample tickets,
/// saves them as PDF files and makes a test print.
class PrinterTestApp extends StatelessWidget {
  const PrinterTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BSG printer test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'DMSans'),
      home: const PrinterTestScreen(),
    );
  }
}

class PrinterTestScreen extends StatefulWidget {
  /// Replaces the renderer in tests.
  final Future<TicketRenderer> Function()? rendererFactory;

  const PrinterTestScreen({super.key, this.rendererFactory});

  @override
  State<PrinterTestScreen> createState() => _PrinterTestScreenState();
}

class _PrinterTestScreenState extends State<PrinterTestScreen> {
  TicketFonts? _fonts;
  TicketRenderer? _renderer;
  List<TicketPrinter> _printers = const [];
  TicketPrinter? _printer;
  TicketPaper _paper = TicketPaper.mm80;
  int _sample = 0;
  String? _message;
  bool _good = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (widget.rendererFactory != null) {
      _renderer = await widget.rendererFactory!();
    } else {
      final fonts = await TicketFonts.load();
      _fonts = fonts;
      _renderer = PdfTicketRenderer(fonts);
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    try {
      final printers = await _renderer!.listPrinters();
      if (!mounted) return;
      setState(() {
        _printers = printers;
        _printer = printers.where((p) => p.name == _printer?.name).firstOrNull ??
            printers.where((p) => p.isDefault).firstOrNull ??
            printers.firstOrNull;
        if (printers.isEmpty) _show('No printer found. Connect the printer and refresh.', false);
      });
    } catch (e) {
      if (mounted) setState(() => _show('Could not list printers: $e', false));
    }
  }

  void _show(String message, bool good) {
    _message = message;
    _good = good;
  }

  Future<void> _testPrint() async {
    setState(() => _busy = true);
    final result = await _renderer!.printTicket(SampleTickets.all[_sample].$2, printer: _printer, paper: _paper);
    if (mounted) {
      setState(() {
        _busy = false;
        _show(result.message, result.ok);
      });
    }
  }

  /// Saves every sample at both widths, for looking at without a printer.
  Future<void> _savePdfs() async {
    setState(() => _busy = true);
    try {
      final app = File(Platform.resolvedExecutable).parent;
      final folder = await Directory('${app.path}/printer_test_pdfs').create(recursive: true);
      for (final (name, ticket) in SampleTickets.all) {
        for (final paper in TicketPaper.values) {
          final file = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
          await File('${folder.path}/${file}_${paper.widthMm.toInt()}mm.pdf')
              .writeAsBytes(await buildTicketPdf(ticket, paper, _fonts!));
        }
      }
      if (mounted) setState(() => _show('Saved to ${folder.path}', true));
    } catch (e) {
      if (mounted) setState(() => _show('Could not save: $e', false));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final fonts = _fonts;
    return Scaffold(
      backgroundColor: const Color(0xFF1A0306),
      body: Row(
        children: [
          SizedBox(
            width: 360,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                children: [
                  const Text('PRINTER TEST',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFFFFD700))),
                  const SizedBox(height: 18),
                  const Text('PRINTER', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                  DropdownButton<TicketPrinter>(
                    isExpanded: true,
                    value: _printer,
                    hint: const Text('No printer found'),
                    items: [
                      for (final p in _printers)
                        DropdownMenuItem(
                          value: p,
                          child: Text('${p.name}${p.isAvailable ? '' : ' (not ready)'}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (p) => setState(() => _printer = p),
                  ),
                  TextButton(onPressed: _busy ? null : _refresh, child: const Text('REFRESH PRINTERS')),
                  const SizedBox(height: 10),
                  const Text('PAPER WIDTH', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                  const SizedBox(height: 6),
                  SegmentedButton<TicketPaper>(
                    segments: [
                      for (final p in TicketPaper.values) ButtonSegment(value: p, label: Text(p.label)),
                    ],
                    selected: {_paper},
                    onSelectionChanged: (s) => setState(() => _paper = s.first),
                  ),
                  const SizedBox(height: 14),
                  const Text('SAMPLE TICKET', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                  for (var i = 0; i < SampleTickets.all.length; i++)
                    ListTile(
                      dense: true,
                      selected: i == _sample,
                      title: Text(SampleTickets.all[i].$1),
                      onTap: () => setState(() => _sample = i),
                    ),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: _busy ? null : _testPrint, child: const Text('TEST PRINT')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _busy || fonts == null ? null : _savePdfs, child: const Text('SAVE ALL AS PDF')),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _message!,
                      key: const ValueKey('printer-test-message'),
                      style: TextStyle(color: _good ? const Color(0xFF88FFB0) : const Color(0xFFFF9999)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: fonts == null
                ? const SizedBox.shrink()
                : PdfPreview(
                    key: ValueKey('${_sample}_${_paper.name}'),
                    allowPrinting: false,
                    allowSharing: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    useActions: false,
                    initialPageFormat: ticketPageFormat(_paper),
                    pdfFileName: 'ticket.pdf',
                    build: (_) => buildTicketPdf(SampleTickets.all[_sample].$2, _paper, fonts),
                  ),
          ),
        ],
      ),
    );
  }
}
