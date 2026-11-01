import 'ticket_model.dart';

/// A printer as the renderer sees it.
class TicketPrinter {
  /// The name Windows knows the printer by.
  final String name;
  final bool isDefault;
  final bool isAvailable;

  const TicketPrinter({required this.name, this.isDefault = false, this.isAvailable = true});
}

enum TicketPrintStatus { sent, noPrinter, notReady, failed }

/// How a print went. [TicketPrintStatus.sent] means handed to Windows; it can
/// not say that paper came out.
class TicketPrintResult {
  final TicketPrintStatus status;
  final String message;

  const TicketPrintResult(this.status, this.message);

  bool get ok => status == TicketPrintStatus.sent;
}

/// One way of getting a ticket onto paper. The test screen, and later the Print
/// button, talk only to this, so an ESC/POS renderer can sit beside the PDF one.
abstract class TicketRenderer {
  String get name;

  Future<List<TicketPrinter>> listPrinters();

  /// Prints with no Windows print window. Never throws: every failure comes
  /// back as a result with a message to show.
  Future<TicketPrintResult> printTicket(
    TicketContent ticket, {
    required TicketPrinter? printer,
    required TicketPaper paper,
  });
}
