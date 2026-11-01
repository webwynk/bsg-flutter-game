import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';
import '../services/round_sync_service.dart';
import 'print_settings_store.dart';
import 'tc_tickets.dart';
import 'printer_readiness.dart';
import 'ticket_renderer.dart';

enum TcPrintLook { ready, idle, printing }

/// A random id for one press of Print.
String newTcRequestId() {
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
class TcPrintController extends ChangeNotifier {
  final GameProvider game;
  final AuthProvider auth;
  final TcPrintApi api;
  final Future<TicketRenderer> Function() renderer;
  final PrinterStatusReader status;
  final PrintSettingsStore settings;
  final String player;
  final DateTime? Function() sessionStart;

  TcPrintController({
    required this.game,
    required this.auth,
    required this.api,
    required this.renderer,
    required this.status,
    required this.settings,
    required this.player,
    required this.sessionStart,
  });

  TcPrintState _state = const TcPrintState();
  bool _printing = false;
  bool _disposed = false;
  String? _message;
  List<TcTicket> _tickets = const [];
  int _lastCountdown = 0;
  String? _sentRequest;
  String? _sentBoard;

  TcPrintState get state => _state;
  bool get printing => _printing;
  List<TcTicket> get tickets => _tickets;

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

  TcPrintLook get look {
    if (_printing) return TcPrintLook.printing;
    final open = active && _state.printOn && game.countdown > 5 && !game.isSpinning;
    return open && !game.board.isEmpty ? TcPrintLook.ready : TcPrintLook.idle;
  }

  void attach() {
    game.addListener(_onGame);
    game.ticketsForRound = (roundId) => api.tickets(roundId: roundId);
    game.reloadPrintTickets = reloadTickets;
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
      debugPrint('TcPrintController.refresh: $e');
    }
  }

  Future<void> reloadTickets() async {
    try {
      final list = await api.tickets(since: sessionStart()).timeout(const Duration(seconds: 3));
      if (_disposed) return;
      _tickets = list;
      game.setPrintTickets(list);
      notifyListeners();
    } catch (e) {
      debugPrint('TcPrintController.reloadTickets: $e');
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
    if (look != TcPrintLook.ready) return;
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
      final round = RoundSyncService().currentRound;
      if (round == null || !round.acceptsBets) {
        _say(TcPrintRefusal.closed.message);
        return;
      }
      final bets = game.boardForPrint();

      // The same board pressed again after a lost reply is the same press, so
      // the server can not charge it twice.
      final board = bets.toString();
      if (_sentBoard != board) {
        _sentBoard = board;
        _sentRequest = newTcRequestId();
      }
      final TcTicketSold sold;
      try {
        sold = await api.printTicket(roundId: round.roundId, bets: bets, requestId: _sentRequest!);
      } on TcPrintException catch (e) {
        if (!e.reason.mayHaveReachedServer) {
          _sentBoard = null;
          _sentRequest = null;
        }
        _say(e.reason.message);
        return;
      }
      _sentBoard = null;
      _sentRequest = null;
      game.ticketSold(
        auth,
        roundId: sold.ticket.roundId,
        roundTotal: sold.roundTotal,
        balance: sold.coinBalance,
        ledgerVersion: sold.ledgerVersion,
      );
      _tickets = [sold.ticket, ..._tickets];
      game.setPrintTickets(_tickets);
      notifyListeners();
      await _toPaper(sold.ticket, printer, copy: false);
    } finally {
      _printing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// A ticket that is already paid for goes to paper. It stays valid whatever
  /// happens here, and can be printed again from the Tickets list.
  Future<void> _toPaper(TcTicket ticket, TicketPrinter printer, {required bool copy}) async {
    final paper = await settings.paper();
    var content = ticket.content(player);
    if (copy) content = content.asCopy(DateTime.now());
    final result = await (await renderer()).printTicket(content, printer: printer, paper: paper);
    final status = result.ok ? 'printed' : 'failed';
    try {
      await api.mark(ticket.id, status, reprint: copy);
    } catch (e) {
      debugPrint('TcPrintController.mark: $e');
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
  Future<void> reprint(TcTicket ticket) async {
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
    game.reloadPrintTickets = null;
    game.leavePrint();
    super.dispose();
  }
}
