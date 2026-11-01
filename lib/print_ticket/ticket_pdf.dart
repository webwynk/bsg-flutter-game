import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'ticket_model.dart';
import 'ticket_renderer.dart';

/// The fonts embedded in every ticket, so it prints the same on any computer.
class TicketFonts {
  final pw.Font regular;
  final pw.Font bold;

  const TicketFonts({required this.regular, required this.bold});

  static Future<TicketFonts> load() async => TicketFonts(
        regular: pw.Font.ttf(await rootBundle.load('assets/fonts/DMSans-Regular.ttf')),
        bold: pw.Font.ttf(await rootBundle.load('assets/fonts/DMSans-Bold.ttf')),
      );
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 31-10-2026 05:42 PM, or the shorter 31-10-26 05:42P for narrow paper.
String ticketTime(DateTime t, TicketPaper paper) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final clock = '${_two(hour)}:${_two(t.minute)}';
  if (paper == TicketPaper.mm58) {
    return '${_two(t.day)}-${_two(t.month)}-${_two(t.year % 100)} $clock${t.hour < 12 ? 'A' : 'P'}';
  }
  return '${_two(t.day)}-${_two(t.month)}-${t.year} $clock ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// Space kept clear inside the printable width, on each side. The print head is
/// already centred on the paper, so this adds to the paper's own 4 or 5 mm edge.
const double ticketSideMarginMm = 1;

/// The roll page: as wide as the print head reaches and as long as the ticket
/// needs. It must not be the paper width, or the right side gets cut off.
PdfPageFormat ticketPageFormat(TicketPaper paper) => PdfPageFormat(
      paper.printableMm * PdfPageFormat.mm,
      double.infinity,
      marginLeft: ticketSideMarginMm * PdfPageFormat.mm,
      marginRight: ticketSideMarginMm * PdfPageFormat.mm,
      marginTop: 3 * PdfPageFormat.mm,
      marginBottom: 6 * PdfPageFormat.mm,
    );

/// The width text may use, in PDF points.
double ticketContentWidth(TicketPaper paper) =>
    (paper.printableMm - 2 * ticketSideMarginMm) * PdfPageFormat.mm;

/// Sizes of the lines that can not wrap, so a test can prove they fit.
double ticketTitleSize(TicketPaper paper) => paper == TicketPaper.mm58 ? 10 : 12;
double ticketCodeSize(TicketPaper paper) => paper == TicketPaper.mm58 ? 13 : 16;
double ticketTotalSize(TicketPaper paper) => paper == TicketPaper.mm58 ? 12 : 14;
const double ticketLetterSpacing = 0.8;

/// Longer than this is past what the printer driver's default page holds, so the
/// real height has to be sent with the print.
const double kTicketDefaultPageMm = 280;

/// The most a Windows paper length can say: 3276 mm, written in tenths of a mm.
const double kTicketLongestMm = 3270;

/// The page to ask the printer for. A normal ticket keeps the roll page, so the
/// driver's own setting decides, as it always has. A longer one sends its real
/// height, or Windows cuts it at the driver's default page.
PdfPageFormat ticketPrintFormat(TicketPaper paper, double contentHeight) {
  final roll = ticketPageFormat(paper);
  if (contentHeight <= kTicketDefaultPageMm * PdfPageFormat.mm) return roll;
  final longest = kTicketLongestMm * PdfPageFormat.mm;
  return roll.copyWith(height: contentHeight > longest ? longest : contentHeight);
}

/// A drawn ticket and the height it came to, in PDF points.
class TicketPdf {
  final Uint8List bytes;
  final double height;

  const TicketPdf(this.bytes, this.height);
}

/// Draws [ticket] as a PDF for [paper]. Black on white only, for a thermal head.
Future<Uint8List> buildTicketPdf(TicketContent ticket, TicketPaper paper, TicketFonts fonts) async =>
    (await measureTicketPdf(ticket, paper, fonts)).bytes;

/// Draws [ticket] and reads its real height back from the finished page.
Future<TicketPdf> measureTicketPdf(TicketContent ticket, TicketPaper paper, TicketFonts fonts) async {
  final narrow = paper == TicketPaper.mm58;
  final body = narrow ? 8.5 : 10.0;

  pw.TextStyle style(double size, {bool bold = false, double spacing = 0}) => pw.TextStyle(
        font: bold ? fonts.bold : fonts.regular,
        fontSize: size,
        letterSpacing: spacing,
        color: PdfColors.black,
      );

  pw.Widget dash() => pw.Divider(
        height: 8,
        thickness: 1,
        color: PdfColors.black,
        borderStyle: pw.BorderStyle.dashed,
      );

  pw.Widget centred(String text, pw.TextStyle s) => pw.Center(child: pw.Text(text, style: s));

  // A label and its value. The value takes the room left and wraps, so a long
  // username can never run off the paper.
  pw.Widget info(String label, String value) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: style(body)),
          pw.SizedBox(width: 6),
          pw.Expanded(child: pw.Text(value, textAlign: pw.TextAlign.right, style: style(body, bold: true))),
        ],
      );

  // A bet line. The bets take the room left and wrap; the amount stays whole.
  pw.Widget row(String left, String right, {pw.TextStyle? leftStyle, pw.TextStyle? rightStyle}) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Text(left, style: leftStyle ?? style(body))),
          pw.SizedBox(width: 6),
          pw.Text(right, style: rightStyle ?? style(body, bold: true)),
        ],
      );

  final doc = pw.Document(title: ticket.code);
  doc.addPage(pw.Page(
    pageFormat: ticketPageFormat(paper),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        centred(ticket.gameTitle, style(ticketTitleSize(paper), bold: true, spacing: ticketLetterSpacing)),
        if (ticket.isCopy)
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.5)),
            child: centred('*** COPY ***', style(narrow ? 11 : 12, bold: true, spacing: 3)),
          )
        else
          dash(),
        if (ticket.idLine != null)
          pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            child: pw.Text(ticket.idLine!, style: style(body, bold: true)),
          )
        else ...[
          centred('TICKET', style(narrow ? 7.5 : 8.5)),
          // Shrinks rather than clips if a code ever grows past the line.
          pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            child: pw.Text(ticket.code, style: style(ticketCodeSize(paper), bold: true, spacing: ticketLetterSpacing)),
          ),
          dash(),
          info('Player', ticket.player),
          info('Round', ticket.roundId ?? '${ticket.roundNumber}'),
        ],
        info('Time', ticketTime(ticket.printedAt, paper)),
        if (ticket.copyAt != null) info('Copy', ticketTime(ticket.copyAt!, paper)),
        dash(),
        for (final group in ticket.groups) ...[
          if (group.heading != null) pw.Text(group.heading!, style: style(body, bold: true)),
          if (group.flow != null)
            pw.Text(group.flow!, style: style(body))
          else
            for (final line in group.lines) row(line.text, '${line.amount}'),
          if (group != ticket.groups.last) pw.SizedBox(height: 3),
        ],
        dash(),
        row(
          'TOTAL',
          ticketAmount(ticket.total),
          leftStyle: style(ticketTotalSize(paper), bold: true),
          rightStyle: style(ticketTotalSize(paper), bold: true),
        ),
        dash(),
        centred(ticket.isCopy ? 'Copy. Not charged again.' : 'Keep this ticket', style(narrow ? 7.5 : 8.5)),
        pw.SizedBox(height: 4),
        centred('*For Amusement Only*', style(narrow ? 8.5 : 10, bold: true)),
      ],
    ),
  ));
  final bytes = await doc.save();
  return TicketPdf(bytes, doc.document.pdfPageList.pages.first.pageFormat.height);
}

/// Prints through the Windows printer driver, using the `printing` package.
class PdfTicketRenderer implements TicketRenderer {
  final TicketFonts fonts;

  PdfTicketRenderer(this.fonts);

  @override
  String get name => 'PDF through the Windows driver';

  @override
  Future<List<TicketPrinter>> listPrinters() async {
    final printers = await Printing.listPrinters();
    return [
      for (final p in printers)
        TicketPrinter(name: p.name, isDefault: p.isDefault, isAvailable: p.isAvailable),
    ];
  }

  @override
  Future<TicketPrintResult> printTicket(
    TicketContent ticket, {
    required TicketPrinter? printer,
    required TicketPaper paper,
  }) async {
    if (printer == null) {
      return const TicketPrintResult(TicketPrintStatus.noPrinter, 'No printer found. Connect the printer and refresh.');
    }
    if (!printer.isAvailable) {
      return TicketPrintResult(TicketPrintStatus.notReady, 'Printer not ready: ${printer.name}');
    }
    try {
      final pdf = await measureTicketPdf(ticket, paper, fonts);
      final printed = await Printing.directPrintPdf(
        printer: Printer(url: printer.name, name: printer.name),
        name: ticket.code,
        format: ticketPrintFormat(paper, pdf.height),
        dynamicLayout: false,
        onLayout: (_) async => pdf.bytes,
      );
      return printed
          ? TicketPrintResult(TicketPrintStatus.sent, 'Sent to ${printer.name}. Check the paper came out.')
          : const TicketPrintResult(TicketPrintStatus.failed, 'The print was cancelled.');
    } catch (e) {
      return TicketPrintResult(TicketPrintStatus.failed, 'Could not print: $e');
    }
  }
}
