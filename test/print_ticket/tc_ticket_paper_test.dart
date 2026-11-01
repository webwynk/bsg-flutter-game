// The compact paper ticket, for all four games.
import 'dart:io';

import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/print_ticket/lucky16_tickets.dart';
import 'package:best_smart_game/print_ticket/lucky_card_tickets.dart';
import 'package:best_smart_game/print_ticket/spin2win_tickets.dart';
import 'package:best_smart_game/print_ticket/tc_tickets.dart';
import 'package:best_smart_game/print_ticket/ticket_model.dart';
import 'package:best_smart_game/print_ticket/ticket_pdf.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

TcTicket ticket(Map<String, Map<String, int>> items) => TcTicket(
      id: 't',
      code: 'TC-P17-0003',
      number: 3,
      roundId: 'r',
      roundNumber: 17413022,
      items: items,
      totalStake: items.values.expand((b) => b.values).fold(0, (a, b) => a + b),
      printStatus: 'charged',
      reprintCount: 0,
      createdAt: DateTime(2026, 11, 1, 20, 30),
    );

void main() {
  test('each chip amount prints once, split by a bar', () {
    final t = ticket(const {
      'single': {'0': 10, '1': 10, '9': 50},
      'double': {'12': 100, '05': 100},
      'triple': {},
    });
    expect(t.flowOf('single'), '0, 1 (10) | 9 (50)');
    expect(t.flowOf('double'), '05, 12 (100)');
    expect(t.flowOf('triple'), '');
  });

  test('ids sit on one line and the total still adds up', () {
    final paper = ticket(const {
      'single': {'0': 10, '9': 50},
      'double': {},
      'triple': {},
    }).content('player99');
    expect(paper.idLine, 'TC-P17-0003 | TC-17413022 | P17');
    expect(paper.total, 60);
    expect(paper.groups.map((g) => g.heading), ['SINGLE']);
    expect(paper.groups.single.flow, '0 (10) | 9 (50)');
  });

  test('a copy keeps the one line', () {
    final paper = ticket(const {
      'single': {'0': 10},
      'double': {},
      'triple': {},
    }).content('player99').asCopy(DateTime(2026, 11, 1, 21));
    expect(paper.idLine, 'TC-P17-0003 | TC-17413022 | P17');
    expect(paper.isCopy, isTrue);
  });

  test('a very big ticket still makes one long page, on both papers', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    pw.Font font(String f) => pw.Font.ttf(ByteData.view(File('assets/fonts/DMSans-$f.ttf').readAsBytesSync().buffer));
    final fonts = TicketFonts(regular: font('Regular'), bold: font('Bold'));
    final big = ticket({
      'single': {for (var i = 0; i < 10; i++) '$i': 10},
      'double': {for (var i = 0; i < 100; i++) i.toString().padLeft(2, '0'): i.isEven ? 10 : 20},
      'triple': {for (var i = 0; i < 1000; i += 3) i.toString().padLeft(3, '0'): 5},
    }).content('player99');
    for (final paper in TicketPaper.values) {
      final bytes = await buildTicketPdf(big, paper, fonts);
      expect(bytes, isNotEmpty);
    }
    final dir = Directory('../docs/print_phase3');
    if (Platform.environment.containsKey('BSG_PICTURES')) {
      final sample = ticket({
        'single': {for (var i = 0; i < 8; i++) '$i': 10, '9': 50},
        'double': {for (var i = 0; i < 30; i++) i.toString().padLeft(2, '0'): 10, '45': 50, '67': 50},
        'triple': const {'123': 5, '456': 5, '789': 5, '045': 5, '112': 5, '908': 5, '334': 10},
      }).content('player99');
      await File('${dir.path}/tc_compact_ticket_80mm.pdf').writeAsBytes(await buildTicketPdf(sample, TicketPaper.mm80, fonts));
    }
  });

  test('amounts over 999 have commas, on the line and in the total', () {
    final t = ticket(const {
      'single': {'0': 1000},
      'double': {},
      'triple': {},
    });
    expect(t.flowOf('single'), '0 (1,000)');
    expect(t.content('p').total, 1000);
    expect(ticketAmount(1000), '1,000');
  });

  test('each card has its own amount, smallest first, then suit, then rank', () {
    final t = LuckyCardTicket(
      id: 't', code: 'LC-P17-0001', number: 1, roundId: 'r', roundNumber: 1,
      items: {
        const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.clubs): 5,
        const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts): 5,
        const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.spades): 1000,
      },
      totalStake: 1010, printStatus: 'charged', reprintCount: 0, createdAt: DateTime(2026, 11, 1),
    );
    expect(t.flow, 'Hearts J (5), Clubs J (5), Spades J (1,000)');
  });

  test('the other three games print the same way', () {
    final ls = Lucky16Ticket(
      id: 't', code: 'LS-P17-0007', number: 7, roundId: 'r', roundNumber: 17413022,
      items: {
        const Lucky16Card(Lucky16Rank.ace, Lucky16Suit.hearts): 10,
        const Lucky16Card(Lucky16Rank.king, Lucky16Suit.clubs): 10,
        const Lucky16Card(Lucky16Rank.jack, Lucky16Suit.spades): 50,
      },
      totalStake: 70, printStatus: 'charged', reprintCount: 0, createdAt: DateTime(2026, 11, 1),
    ).content('player99');
    expect(ls.idLine, 'LS-P17-0007 | LS-17413022 | P17');
    expect(ls.groups.single.flow, 'Hearts A (10), Clubs K (10), Spades J (50)');
    expect(ls.total, 70);

    final lc = LuckyCardTicket(
      id: 't', code: 'LC-P17-0001', number: 1, roundId: 'r', roundNumber: 17413022,
      items: {const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts): 200},
      totalStake: 200, printStatus: 'charged', reprintCount: 0, createdAt: DateTime(2026, 11, 1),
    ).content('player99');
    expect(lc.idLine, 'LC-P17-0001 | LC-17413022 | P17');
    expect(lc.groups.single.flow, 'Hearts J (200)');

    final sw = Spin2WinTicket(
      id: 't', code: 'SW-P17-0002', number: 2, roundId: 'r', roundNumber: 17935360,
      items: const {3: 10, 7: 10, 0: 20},
      totalStake: 40, printStatus: 'charged', reprintCount: 0, createdAt: DateTime(2026, 11, 1),
    ).content('player99').asCopy(DateTime(2026, 11, 1, 21));
    expect(sw.idLine, 'SW-P17-0002 | SW-17935360 | P17');
    expect(sw.groups.single.flow, '3 (10), 7 (10), 0 (20)');
    expect(sw.groups.single.heading, 'NUMBERS');
    expect(sw.isCopy, isTrue);
    expect(sw.total, 40);
  });

  test('every game, both papers, normal and COPY, and very long tickets', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    pw.Font font(String f) => pw.Font.ttf(ByteData.view(File('assets/fonts/DMSans-$f.ttf').readAsBytesSync().buffer));
    final fonts = TicketFonts(regular: font('Regular'), bold: font('Bold'));
    final when = DateTime(2026, 11, 1, 20, 30);
    final games = <String, TicketContent>{
      'lucky16': Lucky16Ticket(
        id: 't', code: 'LS-P17-0007', number: 7, roundId: 'r', roundNumber: 17413022,
        items: {for (final (i, c) in Lucky16Card.all.indexed) c: i.isEven ? 10 : 50},
        totalStake: 480, printStatus: 'charged', reprintCount: 0, createdAt: when,
      ).content('player99'),
      'luckycard': LuckyCardTicket(
        id: 't', code: 'LC-P17-0001', number: 1, roundId: 'r', roundNumber: 17413022,
        items: {for (final (i, c) in LuckyCard.all.indexed) c: i.isEven ? 10 : 50},
        totalStake: 360, printStatus: 'charged', reprintCount: 0, createdAt: when,
      ).content('player99'),
      'spin2win': Spin2WinTicket(
        id: 't', code: 'SW-P17-0002', number: 2, roundId: 'r', roundNumber: 17935360,
        items: {for (var i = 0; i < 10; i++) i: i.isEven ? 10 : 50},
        totalStake: 300, printStatus: 'charged', reprintCount: 0, createdAt: when,
      ).content('player99'),
      'triplechance': ticket({
        'single': {for (var i = 0; i < 10; i++) '$i': i.isEven ? 10 : 50},
        'double': {for (var i = 0; i < 100; i++) i.toString().padLeft(2, '0'): i.isEven ? 10 : 20},
        'triple': {for (var i = 0; i < 1000; i += 3) i.toString().padLeft(3, '0'): 5},
      }).content('player99'),
    };
    final save = Platform.environment.containsKey('BSG_PICTURES');
    for (final entry in games.entries) {
      expect(entry.value.groups.every((g) => g.flow != null), isTrue, reason: entry.key);
      expect(entry.value.idLine, isNotNull, reason: entry.key);
      for (final paper in TicketPaper.values) {
        for (final copy in [false, true]) {
          final content = copy ? entry.value.asCopy(when.add(const Duration(minutes: 8))) : entry.value;
          expect(content.idLine, entry.value.idLine);
          final bytes = await buildTicketPdf(content, paper, fonts);
          expect(bytes, isNotEmpty);
          if (save) {
            final mark = copy ? '_copy' : '';
            await File('../docs/print_phase3/ticket_${entry.key}_${paper.name}$mark.pdf').writeAsBytes(bytes);
          }
        }
      }
    }
  });

  test('every number on the board sends its real height to the printer', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    pw.Font font(String f) => pw.Font.ttf(ByteData.view(File('assets/fonts/DMSans-$f.ttf').readAsBytesSync().buffer));
    final fonts = TicketFonts(regular: font('Regular'), bold: font('Bold'));
    const chips = [2, 5, 10, 50, 100];
    final all = ticket({
      'single': {for (var i = 0; i < 10; i++) '$i': chips[i % 5]},
      'double': {for (var i = 0; i < 100; i++) i.toString().padLeft(2, '0'): chips[i % 5]},
      'triple': {for (var i = 0; i < 1000; i++) i.toString().padLeft(3, '0'): chips[i % 5]},
    }).content('player99');
    final save = Platform.environment.containsKey('BSG_PICTURES');
    for (final paper in TicketPaper.values) {
      for (final copy in [false, true]) {
        final content = copy ? all.asCopy(DateTime(2026, 11, 1, 21)) : all;
        final pdf = await measureTicketPdf(content, paper, fonts);
        expect(pdf.height, greaterThan(kTicketDefaultPageMm * PdfPageFormat.mm), reason: paper.name);
        final format = ticketPrintFormat(paper, pdf.height);
        expect(format.height, pdf.height, reason: 'the printer is told the real height');
        expect(format.width, ticketPageFormat(paper).width);
        // ignore: avoid_print
        print('${paper.name} copy=$copy: ${(pdf.height / PdfPageFormat.mm).round()} mm');
        if (save) {
          await File('../docs/print_phase3/ticket_triplechance_all_${paper.name}${copy ? '_copy' : ''}.pdf').writeAsBytes(pdf.bytes);
        }
      }
    }
  });

  test('a normal ticket keeps the roll page, and the longest is capped', () {
    expect(ticketPrintFormat(TicketPaper.mm80, 200 * PdfPageFormat.mm).height, double.infinity);
    expect(ticketPrintFormat(TicketPaper.mm80, 4000 * PdfPageFormat.mm).height, kTicketLongestMm * PdfPageFormat.mm);
  });
}
