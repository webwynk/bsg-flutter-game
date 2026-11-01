// The print ticket pieces: the compact bet lines, the time format, the PDF for
// every sample at both paper widths, the renderer's refusals, and the test
// screen with no printer. Run with --dart-define=SAVE_TICKETS=true to also save
// the PDFs to reference-design/print_phase0/.
import 'dart:io';
import 'dart:typed_data';

import 'package:best_smart_game/print_ticket/printer_test_app.dart';
import 'package:best_smart_game/print_ticket/ticket_model.dart';
import 'package:best_smart_game/print_ticket/ticket_pdf.dart';
import 'package:best_smart_game/print_ticket/ticket_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

TicketFonts _fonts() {
  ByteData read(String f) => ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync());
  return TicketFonts(regular: pw.Font.ttf(read('DMSans-Regular.ttf')), bold: pw.Font.ttf(read('DMSans-Bold.ttf')));
}

/// A renderer with scripted printers.
class _FakeRenderer implements TicketRenderer {
  final List<TicketPrinter> printers;
  _FakeRenderer(this.printers);

  @override
  String get name => 'fake';

  @override
  Future<List<TicketPrinter>> listPrinters() async => printers;

  @override
  Future<TicketPrintResult> printTicket(TicketContent ticket,
          {required TicketPrinter? printer, required TicketPaper paper}) async =>
      PdfTicketRenderer(_fonts()).printTicket(ticket, printer: printer, paper: paper);
}

void main() {
  group('compact lines', () {
    test('neighbours with one amount share it, as approved', () {
      expect(TicketLine.compact(const [('5', 10), ('9', 10), ('6', 50)]).text, '5, 9 (10), 6 (50)');
      expect(TicketLine.compact(const [('20', 10), ('50', 10), ('60', 10)]).text, '20, 50, 60 (10)');
      expect(TicketLine.compact(const [('7', 20), ('3', 20), ('0', 10)]).text, '7, 3 (20), 0 (10)');
      expect(TicketLine.compact(const [('Clubs K', 35), ('Spades J', 35)]).text, 'Clubs K, Spades J (35)');
    });

    test('the line total adds every bet', () {
      expect(TicketLine.compact(const [('5', 10), ('9', 10), ('6', 50)]).amount, 70);
      expect(TicketLine.compact(const [('Clubs K', 35), ('Spades J', 35)]).amount, 70);
    });
  });

  test('sample totals match the approved design', () {
    expect(SampleTickets.lucky16.total, 270);
    expect(SampleTickets.luckyCard.total, 350);
    expect(SampleTickets.spin2win.total, 50);
    expect(SampleTickets.tripleChance.total, 110);
    expect(SampleTickets.copy.isCopy, isTrue);
    expect(SampleTickets.copy.code, SampleTickets.lucky16.code);
  });

  test('time format for each paper', () {
    final t = DateTime(2026, 10, 31, 17, 42);
    expect(ticketTime(t, TicketPaper.mm80), '31-10-2026 05:42 PM');
    expect(ticketTime(t, TicketPaper.mm58), '31-10-26 05:42P');
    expect(ticketTime(DateTime(2026, 1, 2, 0, 5), TicketPaper.mm80), '02-01-2026 12:05 AM');
  });

  group('nothing can run past the print head', () {
    double width(pw.Font font, String text, double size, double spacing) {
      final doc = PdfDocument();
      final metrics = font.getFont(pw.Context(document: doc)).stringMetrics(text, letterSpacing: spacing / size);
      return metrics.width * size;
    }

    test('the page is the printable width, not the paper width', () {
      expect(TicketPaper.mm80.printableMm, 72);
      expect(ticketPageFormat(TicketPaper.mm80).width, closeTo(72 * PdfPageFormat.mm, 0.01));
      expect(ticketPageFormat(TicketPaper.mm58).width, closeTo(48 * PdfPageFormat.mm, 0.01));
    });

    test('lines that can not wrap fit at their largest', () {
      final bold = _fonts().bold;
      for (final paper in TicketPaper.values) {
        final room = ticketContentWidth(paper);
        expect(width(bold, 'LUCKY 16 CARD', ticketTitleSize(paper), ticketLetterSpacing), lessThan(room));
        expect(width(bold, 'TRIPLE CHANCE', ticketTitleSize(paper), ticketLetterSpacing), lessThan(room));
        expect(width(bold, 'TC-R999-99999', ticketCodeSize(paper), ticketLetterSpacing), lessThan(room), reason: '$paper');
        expect(width(bold, 'TOTAL   99,999,999', ticketTotalSize(paper), 0), lessThan(room), reason: '$paper');
      }
    });

    test('a ticket with the longest values still builds', () async {
      final fonts = _fonts();
      final long = TicketContent(
        gameTitle: 'TRIPLE CHANCE',
        code: 'TC-Z1000-1000000',
        player: 'abcdefghijklmnopqrst',
        roundNumber: 99999999,
        printedAt: DateTime(2026, 12, 31, 23, 59),
        groups: [
          TicketGroup(heading: 'TRIPLE', lines: [
            TicketLine.compact([for (var i = 100; i < 200; i++) ('$i', i % 7 == 0 ? 5 : 10000)]),
          ]),
        ],
      );
      for (final paper in TicketPaper.values) {
        final bytes = await buildTicketPdf(long, paper, fonts);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        if (const bool.fromEnvironment('SAVE_TICKETS')) {
          File('reference-design/print_phase0/longest_values_${paper.widthMm.toInt()}mm.pdf').writeAsBytesSync(bytes);
        }
      }
    });
  });

  test('every sample builds a PDF at both widths', () async {
    final fonts = _fonts();
    final out = Directory('reference-design/print_phase0');
    const save = bool.fromEnvironment('SAVE_TICKETS');
    if (save) out.createSync(recursive: true);
    for (final (name, ticket) in SampleTickets.all) {
      for (final paper in TicketPaper.values) {
        final bytes = await buildTicketPdf(ticket, paper, fonts);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: name);
        if (save) {
          final file = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
          File('${out.path}/${file}_${paper.widthMm.toInt()}mm.pdf').writeAsBytesSync(bytes);
        }
      }
    }
  });

  group('refusals before anything is sent', () {
    test('no printer', () async {
      final r = await PdfTicketRenderer(_fonts())
          .printTicket(SampleTickets.lucky16, printer: null, paper: TicketPaper.mm80);
      expect(r.status, TicketPrintStatus.noPrinter);
      expect(r.message, 'No printer found. Connect the printer and refresh.');
    });

    test('printer not ready', () async {
      final r = await PdfTicketRenderer(_fonts()).printTicket(SampleTickets.lucky16,
          printer: const TicketPrinter(name: 'Gobbler', isAvailable: false), paper: TicketPaper.mm80);
      expect(r.status, TicketPrintStatus.notReady);
      expect(r.message, 'Printer not ready: Gobbler');
    });
  });

  testWidgets('with no printer, the screen says so and TEST PRINT explains', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: PrinterTestScreen(rendererFactory: () async => _FakeRenderer(const [])),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No printer found'), findsOneWidget);
    expect(find.text('No printer found. Connect the printer and refresh.'), findsOneWidget);
    await tester.tap(find.text('TEST PRINT'));
    await tester.pumpAndSettle();
    expect(find.text('No printer found. Connect the printer and refresh.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
