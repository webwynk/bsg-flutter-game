import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../providers/lucky16_provider.dart';
import 'print_settings_store.dart';
import 'lucky16_tickets.dart';
import 'printer_readiness.dart';
import 'ticket_renderer.dart';

enum Lucky16PrintLook { ready, idle, printing }

/// A random id for one press of Print.
String newPrintRequestId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Everything behind the Print and Tickets buttons, for the Windows app only.
/// The printer is checked first, so nothing is charged for a printer that can not
/// print; the server then charges, and only then does the ticket go to paper.
class Lucky16PrintController extends ChangeNotifier {
  final Lucky16Provider game;
  final Lucky16PrintApi api;
  final Future<TicketRenderer> Function() renderer;
  final PrinterStatusReader status;
  final PrintSettingsStore settings;
  final String player;
  final DateTime? Function() sessionStart;

  Lucky16PrintController({
    required this.game,
    required this.api,
    required this.renderer,
    required this.status,
    required this.settings,
    required this.player,
    required this.sessionStart,
  });

  Lucky16PrintState _state = const Lucky16PrintState();
  bool _printing = false;
  bool _disposed = false;
  String? _message;
  List<Lucky16Ticket> _tickets = const [];
  int _lastCountdown = 0;
  String? _sentRequest;
  String? _sentRound;

  Lucky16PrintState get state => _state;
  bool get printing => _printing;
  List<Lucky16Ticket> get tickets => _tickets;

  /// The latest thing the player must be told; read once with [takeMessage].
  String? takeMessage() {
    final m = _message;
    _message = null;
    return m;
  }

  /// Print is used in this round, so the board plays by Print's rules.
  bool get active => _state.activeNow;

  /// The buttons stay for a round that was just turned off and holds tickets.
  bool get showButtons => active || _tickets.isNotEmpty;

  Lucky16PrintLook get look {
    if (_printing) return Lucky16PrintLook.printing;
    final open = active && _state.printOn && !game.isLocked && !game.isSequenceRunning;
    return open && !game.isBoardEmpty ? Lucky16PrintLook.ready : Lucky16PrintLook.idle;
  }

  void attach() {
    game.addListener(_onGame);
    game.ticketsForRound = (roundId) => api.tickets(roundId: roundId);
    unawaited(refresh());
    unawaited(reloadTickets());
  }

  void _onGame() {
    final now = game.countdown;
    // A new round has begun: Print may have changed for it.
    if (now > _lastCountdown + 30) {
      unawaited(refresh());
      // A ticket's win is known only once its round is drawn.
      unawaited(reloadTickets());
    }
    _lastCountdown = now;
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final next = await api.state();
      if (_disposed) return;
      _state = next;
      game.setPrintMode(next.activeNow);
      notifyListeners();
    } catch (e) {
      debugPrint('Lucky16PrintController.refresh: $e');
    }
  }

  Future<void> reloadTickets() async {
    try {
      final list = await api.tickets(since: sessionStart()).timeout(const Duration(seconds: 3));
      if (_disposed) return;
      _tickets = list;
      notifyListeners();
    } catch (e) {
      debugPrint('Lucky16PrintController.reloadTickets: $e');
    }
  }

  Future<TicketPrinter?> _printer() async {
    final name = await settings.printer();
    if (name == null) return null;
    return TicketPrinter(name: name);
  }

  void _say(String message) {
    _message = message;
    notifyListeners();
  }

  /// One press of Print. A second press while one is running is ignored.
  Future<void> press() async {
    if (look != Lucky16PrintLook.ready) return;
    _printing = true;
    notifyListeners();
    try {
      final printer = await _printer();
      if (printer == null) {
        _say('Choose a printer in Printer settings. No coins were taken.');
        return;
      }
      final ready = await status.check(printer.name);
      if (ready != PrinterReadiness.ready) {
        _say(printerProblem(ready, printer.name));
        return;
      }
      final round = await game.sync.roundForBet();
      if (round == null || round.isDrawn) {
        _say(Lucky16PrintRefusal.closed.message);
        return;
      }
      final bets = game.boardForPrint();
      if (bets.isEmpty) return;

      // The same press on the same round reuses the same request ID, so the
      // server can not charge twice even if the board is edited after a lost reply.
      if (_sentRound != round.roundId) {
        _sentRound = round.roundId;
        _sentRequest = newPrintRequestId();
      }
      final Lucky16TicketSold sold;
      try {
        sold = await api.printTicket(roundId: round.roundId, bets: bets, requestId: _sentRequest!);
      } on Lucky16PrintException catch (e) {
        if (!e.reason.mayHaveReachedServer) {
          _sentRound = null;
          _sentRequest = null;
        }
        _say(e.reason.message);
        return;
      }
      _sentRound = null;
      _sentRequest = null;
      game.ticketSold(
        roundId: sold.ticket.roundId,
        roundTotal: sold.roundTotal,
        balance: sold.coinBalance,
        ledgerVersion: sold.ledgerVersion,
      );
      _tickets = [sold.ticket, ..._tickets];
      notifyListeners();
      await _toPaper(sold.ticket, printer, copy: false);
    } finally {
      _printing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// A ticket that is already paid for goes to paper. It stays valid whatever
  /// happens here, and can be printed again from the Tickets list.
  Future<void> _toPaper(Lucky16Ticket ticket, TicketPrinter printer, {required bool copy}) async {
    final paper = await settings.paper();
    var content = ticket.content(player);
    if (copy) content = content.asCopy(DateTime.now());
    final result = await (await renderer()).printTicket(content, printer: printer, paper: paper);
    final status = result.ok ? 'printed' : 'failed';
    try {
      await api.mark(ticket.id, status, reprint: copy);
    } catch (e) {
      debugPrint('Lucky16PrintController.mark: $e');
    }
    final updated = ticket.marked(
      ticket.printStatus == 'printed' ? 'printed' : status,
      reprints: ticket.reprintCount + (copy ? 1 : 0),
    );
    _tickets = [for (final t in _tickets) t.id == ticket.id ? updated : t];
    if (!result.ok) {
      _say('Ticket ${ticket.code} is paid and valid but did not print. Print it from Tickets.');
    }
    notifyListeners();
  }

  /// REPRINT in the Tickets list. Marked COPY only if it reached paper before.
  Future<void> reprint(Lucky16Ticket ticket) async {
    if (_printing) return;
    _printing = true;
    notifyListeners();
    try {
      final printer = await _printer();
      if (printer == null) {
        _say('Choose a printer in Printer settings.');
        return;
      }
      final ready = await status.check(printer.name);
      if (ready != PrinterReadiness.ready) {
        _say(printerProblem(ready, printer.name).replaceAll(' No coins were taken.', ''));
        return;
      }
      await _toPaper(ticket, printer, copy: ticket.wasPrinted);
    } finally {
      _printing = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    game.removeListener(_onGame);
    game.ticketsForRound = null;
    super.dispose();
  }
}
