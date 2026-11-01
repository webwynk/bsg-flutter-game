// The Print press and a print-only round. The server, the printer and Windows are
// stand-ins; the provider and controller are the real ones.
import 'dart:io';

import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/print_ticket/lucky16_print_controller.dart';
import 'package:best_smart_game/print_ticket/lucky16_print_service.dart';
import 'package:best_smart_game/print_ticket/lucky16_tickets.dart';
import 'package:best_smart_game/print_ticket/printer_readiness.dart';
import 'package:best_smart_game/print_ticket/ticket_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Windows printer status', () {
    test('reads what Windows says', () {
      expect(PrinterStatusReader.parse('{"found":false}'), PrinterReadiness.notFound);
      expect(PrinterStatusReader.parse('{"found":true,"offline":true,"jobs":0,"oldest":0}'), PrinterReadiness.offline);
      expect(PrinterStatusReader.parse('{"found":true,"offline":false,"jobs":1,"oldest":60}'), PrinterReadiness.stuckQueue);
      expect(PrinterStatusReader.parse('{"found":true,"offline":false,"jobs":1,"oldest":5}'), PrinterReadiness.ready);
      expect(PrinterStatusReader.parse('{"found":true,"offline":false,"jobs":0,"oldest":0}'), PrinterReadiness.ready);
    });

    test('anything unreadable is not ready', () async {
      expect(PrinterStatusReader.parse('garbage'), PrinterReadiness.unknown);
      expect(PrinterStatusReader.parse(''), PrinterReadiness.unknown);
      final slow = PrinterStatusReader(
        run: (_) => Future.delayed(const Duration(seconds: 5), () => '{}'),
        limit: const Duration(milliseconds: 10),
      );
      expect(await slow.check('x'), PrinterReadiness.unknown);
      final broken = PrinterStatusReader(run: (_) async => throw Exception('no'));
      expect(await broken.check('x'), PrinterReadiness.unknown);
    });
  });

  group('tickets', () {
    final json = {
      'ticket_id': 't1',
      'ticket_code': 'LS-R01-0007',
      'ticket_no': 7,
      'round_id': 'r1',
      'round_number': 17345678,
      'items': {'a_hearts': 200, 'k_clubs': 35, 'j_spades': 35},
      'total_stake': 270,
      'print_status': 'printed',
      'reprint_count': 1,
      'created_at': '2026-11-01T10:00:00Z',
      'is_drawn': true,
      'win': 2800,
    };

    test('a ticket reads as the server sends it, with bets in board order', () {
      final t = Lucky16Ticket.fromJson(json);
      expect(t.code, 'LS-R01-0007');
      expect(t.win, 2800);
      expect(t.wasPrinted, isTrue);
      expect(t.betsText, 'Hearts A (200), Spades J, Clubs K (35)');
      final paper = t.content('raj');
      expect(paper.total, 270);
      expect(paper.gameTitle, 'LUCKY 16 CARD');
    });

    test('every refusal code has its own reason', () {
      expect(Lucky16PrintRefusal.fromCode('P0121'), Lucky16PrintRefusal.closed);
      expect(Lucky16PrintRefusal.fromCode('P0157'), Lucky16PrintRefusal.printOff);
      expect(Lucky16PrintRefusal.fromCode('P0158'), Lucky16PrintRefusal.notActive);
      expect(Lucky16PrintRefusal.fromCode('P0112'), Lucky16PrintRefusal.insufficientCoins);
      expect(Lucky16PrintRefusal.closed.mayHaveReachedServer, isFalse);
      expect(Lucky16PrintRefusal.offline.mayHaveReachedServer, isTrue);
    });

    test('a request id is a proper random id', () {
      final id = newPrintRequestId();
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id), isTrue);
      expect(newPrintRequestId(), isNot(id));
    });
  });

  group('printer settings', () {
    test('saved on this computer, 80 mm until chosen', () async {
      final dir = Directory.systemTemp.createTempSync('bsgprint');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = PrintSettingsStore(file: File('${dir.path}/x/settings.json'));
      expect(await store.printer(), isNull);
      expect(await store.paper(), TicketPaper.mm80);
      await store.save('GOBBLER', TicketPaper.mm58);
      expect(await store.printer(), 'GOBBLER');
      expect(await store.paper(), TicketPaper.mm58);
    });
  });

  test('card keys come back as cards', () {
    expect(Lucky16Card.fromKey('q_spades').suit, Lucky16Suit.spades);
  });

}
