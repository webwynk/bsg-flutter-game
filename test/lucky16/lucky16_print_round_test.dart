// Whole print rounds on the fake clock: the real provider and print controller,
// with the simulated server standing in for the ticket function, and a stand-in
// printer. A ticket is bought by placing the board on the simulated server, which
// is what the database's bet row ends up holding.
import 'package:best_smart_game/models/lucky16_board.dart';
import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/print_ticket/lucky16_print_controller.dart';
import 'package:best_smart_game/print_ticket/lucky16_print_service.dart';
import 'package:best_smart_game/print_ticket/lucky16_tickets.dart';
import 'package:best_smart_game/print_ticket/printer_readiness.dart';
import 'package:best_smart_game/print_ticket/ticket_model.dart';
import 'package:best_smart_game/print_ticket/ticket_renderer.dart';
import 'package:best_smart_game/providers/lucky16_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_rig.dart';
import 'sim_server.dart';

final Lucky16Card winner = SimulatedLucky16Server.winnerOf(cycle);
final int bonus = SimulatedLucky16Server.bonusOf(cycle);

Lucky16Ticket ticket(int no, Map<Lucky16Card, int> items, {String status = 'charged', int win = 0}) => Lucky16Ticket(
      id: 'id$no',
      code: 'LS-R01-000$no',
      number: no,
      roundId: 'round-$cycle',
      roundNumber: cycle,
      items: items,
      totalStake: items.values.fold(0, (a, b) => a + b),
      printStatus: status,
      reprintCount: 0,
      createdAt: DateTime(2026, 11, 1),
      win: win,
    );

class FakePrintApi implements Lucky16PrintApi {
  FakePrintApi(this.rig);

  final BetRig rig;
  Lucky16PrintState current = const Lucky16PrintState(printOn: true, activeNow: true, activeNext: true);
  final List<String> requests = [];
  final List<(String, String, bool)> marks = [];
  final List<Lucky16Ticket> sold = [];
  Lucky16PrintRefusal? refuseNext;
  int roundTotal = 0;

  @override
  Future<Lucky16PrintState> state() async => current;

  @override
  Future<Lucky16TicketSold> printTicket({
    required String roundId,
    required Map<Lucky16Card, int> bets,
    required String requestId,
  }) async {
    requests.add(requestId);
    final refuse = refuseNext;
    refuseNext = null;
    if (refuse != null) throw Lucky16PrintException(refuse);
    final total = bets.values.fold<int>(0, (a, b) => a + b);
    // The row holds every ticket so far: the simulated server replaces a board.
    final all = <Lucky16Card, int>{};
    for (final t in sold) {
      t.items.forEach((k, v) => all[k] = (all[k] ?? 0) + v);
    }
    bets.forEach((k, v) => all[k] = (all[k] ?? 0) + v);
    final placed = await rig.server.placeBet(roundId: roundId, bets: all);
    final t = ticket(sold.length + 1, bets);
    sold.add(t);
    roundTotal += total;
    return Lucky16TicketSold(t, roundTotal, placed.coinBalance, placed.ledgerVersion);
  }

  @override
  Future<List<Lucky16Ticket>> tickets({String? roundId, DateTime? since}) async => [
        for (final t in sold)
          Lucky16Ticket(
            id: t.id,
            code: t.code,
            number: t.number,
            roundId: t.roundId,
            roundNumber: t.roundNumber,
            items: t.items,
            totalStake: t.totalStake,
            printStatus: t.printStatus,
            reprintCount: t.reprintCount,
            createdAt: t.createdAt,
            win: (t.items[winner] ?? 0) * 14 * bonus,
          ),
      ];

  @override
  Future<void> mark(String ticketId, String status, {bool reprint = false}) async {
    marks.add((ticketId, status, reprint));
  }
}

class FakeRenderer implements TicketRenderer {
  final List<TicketContent> printed = [];
  bool fail = false;

  @override
  String get name => 'fake';

  @override
  Future<List<TicketPrinter>> listPrinters() async => const [];

  @override
  Future<TicketPrintResult> printTicket(TicketContent ticket, {required TicketPrinter? printer, required TicketPaper paper}) async {
    if (fail) return const TicketPrintResult(TicketPrintStatus.failed, 'no');
    printed.add(ticket);
    return const TicketPrintResult(TicketPrintStatus.sent, 'ok');
  }
}

class Print {
  Print(this.rig, {String statusJson = '{"found":true,"offline":false,"jobs":0,"oldest":0}', bool printerChosen = true}) {
    api = FakePrintApi(rig);
    controller = Lucky16PrintController(
      game: rig.provider,
      api: api,
      renderer: () async => renderer,
      status: PrinterStatusReader(run: (_) async => statusJson),
      settings: FakeSettings(printerChosen ? 'GOBBLER' : null),
      player: 'raj',
      sessionStart: () => null,
    );
    controller.attach();
  }

  final BetRig rig;
  late final FakePrintApi api;
  late final Lucky16PrintController controller;
  final FakeRenderer renderer = FakeRenderer();

  Future<void> press(WidgetTester tester) async {
    final done = controller.press();
    await rig.world.run(const Duration(seconds: 1));
    await done;
  }
}

class FakeSettings extends PrintSettingsStore {
  FakeSettings(this.chosen);

  final String? chosen;

  @override
  Future<String?> printer() async => chosen;

  @override
  Future<TicketPaper> paper() async => TicketPaper.mm80;
}

void main() {
  testWidgets('a look: grey with an empty board, green with chips, grey once betting closes', (tester) async {
    final rig = BetRig(tester);
    await rig.open();
    final print = Print(rig);
    await rig.world.run(const Duration(milliseconds: 100));
    expect(rig.provider.printMode, isTrue);
    expect(print.controller.showButtons, isTrue);
    expect(print.controller.look, Lucky16PrintLook.idle);
    rig.provider.selectChip(Lucky16Chip.ten);
    rig.provider.tapCard(winner);
    expect(print.controller.look, Lucky16PrintLook.ready);
    print.controller.dispose();
    rig.provider.leave();
    await rig.world.run(const Duration(seconds: 1));
  });

  testWidgets('a normal player: no buttons, and the bet is sent by itself as always', (tester) async {
    final rig = BetRig(tester);
    await rig.open();
    final print = Print(rig);
    print.api.current = const Lucky16PrintState();
    await print.controller.refresh();
    expect(rig.provider.printMode, isFalse);
    expect(print.controller.showButtons, isFalse);
    rig.betTenOnEveryCard();
    await rig.world.runUntil(87);
    expect(rig.provider.isBetSubmitted, isTrue);
    expect(rig.problems, isEmpty);
    print.controller.dispose();
    rig.provider.leave();
    await rig.world.run(const Duration(seconds: 1));
  });

  testWidgets('chips never printed: nothing is sent, they come back, and the player is told', (tester) async {
    final rig = BetRig(tester);
    await rig.open();
    rig.provider.setPrintMode(true);
    rig.betTenOnEveryCard();
    expect(rig.provider.balance, 840);
    await rig.world.runUntil(87);
    expect(rig.provider.balance, 1000);
    expect(rig.provider.isBoardEmpty, isTrue);
    expect(rig.provider.isBetSubmitted, isFalse);
    expect(rig.server.serverBalance, 1000);
    expect(rig.problems.single.kind, Lucky16ProblemKind.notPrinted);
    rig.provider.leave();
    await rig.world.run(const Duration(seconds: 1));
  });

  testWidgets('a printed round: board cleared, PLAY keeps the total, the win and balance arrive', (tester) async {
    final rig = BetRig(tester);
    await rig.open();
    final print = Print(rig);
    await rig.world.run(const Duration(milliseconds: 100));
    final p = rig.provider;
    p.selectChip(Lucky16Chip.ten);
    p.tapCard(winner);
    await print.press(tester);
    expect(print.api.requests, hasLength(1));
    expect(p.isBoardEmpty, isTrue);
    expect(p.total, 10);
    expect(p.balance, 990);
    expect(print.renderer.printed.single.code, 'LS-R01-0001');
    expect(print.renderer.printed.single.isCopy, isFalse);
    expect(print.api.marks.single, ('id1', 'printed', false));

    p.tapCard(winner);
    await print.press(tester);
    expect(p.total, 20);
    expect(p.balance, 980);

    await rig.world.runUntil(87);
    expect(rig.problems, isEmpty);
    expect(p.isBetSubmitted, isFalse);

    await landWheelAt(rig, 95);
    await rig.world.run(const Duration(seconds: 2));
    expect(p.lastOutcome?.payout, 20 * 14 * bonus);
    expect(p.lastOutcome?.stake, 20);
    expect(p.balance, 980 + 20 * 14 * bonus);
    expect(p.popup?.payout, 20 * 14 * bonus);
    expect(p.popupTickets, hasLength(2));
    expect(p.popupTickets.fold<int>(0, (s, t) => s + t.win), 20 * 14 * bonus);
    await rig.world.run(const Duration(seconds: 3));
    expect(p.total, 0);
    expect(p.popupTickets, isEmpty);
    print.controller.dispose();
    rig.provider.leave();
    await rig.world.run(const Duration(seconds: 1));
  });

  testWidgets('printer not ready: no server call, no charge, chips stay', (tester) async {
    final rig = BetRig(tester);
    await rig.open();
    final print = Print(rig, statusJson: '{"found":true,"offline":true,"jobs":0,"oldest":0}');
    await rig.world.run(const Duration(milliseconds: 100));
    rig.provider.selectChip(Lucky16Chip.ten);
    rig.provider.tapCard(winner);
    await print.press(tester);
    expect(print.api.requests, isEmpty);
    expect(rig.provider.total, 10);
    expect(rig.server.serverBalance, 1000);
    expect(print.controller.takeMessage(), contains('Printer not ready'));
    expect(print.controller.look, Lucky16PrintLook.ready);
    print.controller.dispose();
    rig.provider.leave();
    await rig.world.run(const Duration(seconds: 1));
  });

  testWidgets('a lost reply: the same board is the same press', (tester) async {
    final rig = BetRig(tester);
    await rig.open();
    final print = Print(rig);
    await rig.world.run(const Duration(milliseconds: 100));
    rig.provider.selectChip(Lucky16Chip.ten);
    rig.provider.tapCard(winner);
    print.api.refuseNext = Lucky16PrintRefusal.offline;
    await print.press(tester);
    expect(rig.provider.total, 10, reason: 'the chips stay');
    await print.press(tester);
    expect(print.api.requests, hasLength(2));
    expect(print.api.requests[0], print.api.requests[1]);
    print.controller.dispose();
    rig.provider.leave();
    await rig.world.run(const Duration(seconds: 1));
  });

  testWidgets('a final refusal leaves the chips and the next press is a new one', (tester) async {
    final rig = BetRig(tester);
    await rig.open();
    final print = Print(rig);
    await rig.world.run(const Duration(milliseconds: 100));
    rig.provider.selectChip(Lucky16Chip.ten);
    rig.provider.tapCard(winner);
    print.api.refuseNext = Lucky16PrintRefusal.insufficientCoins;
    await print.press(tester);
    expect(print.controller.takeMessage(), 'Not enough coins for this ticket.');
    await print.press(tester);
    expect(print.api.requests[0], isNot(print.api.requests[1]));
    print.controller.dispose();
    rig.provider.leave();
    await rig.world.run(const Duration(seconds: 1));
  });

  testWidgets('paper fails after charging: the ticket stays valid and prints later, not as a COPY', (tester) async {
    final rig = BetRig(tester);
    await rig.open();
    final print = Print(rig);
    await rig.world.run(const Duration(milliseconds: 100));
    rig.provider.selectChip(Lucky16Chip.ten);
    rig.provider.tapCard(winner);
    print.renderer.fail = true;
    await print.press(tester);
    expect(print.api.marks.single, ('id1', 'failed', false));
    expect(print.controller.takeMessage(), contains('paid and valid'));
    final failed = print.controller.tickets.single;
    expect(failed.wasPrinted, isFalse);

    print.renderer.fail = false;
    await print.controller.reprint(failed);
    expect(print.renderer.printed.single.isCopy, isFalse);
    final done = print.controller.tickets.single;
    expect(done.wasPrinted, isTrue);

    await print.controller.reprint(done);
    expect(print.renderer.printed.last.isCopy, isTrue);
    expect(print.api.marks.last, ('id1', 'printed', true));
    expect(print.api.requests, hasLength(1), reason: 'a reprint never charges');
    print.controller.dispose();
    rig.provider.leave();
    await rig.world.run(const Duration(seconds: 1));
  });
}
