import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lucky16_models.dart';
import 'lucky16_tickets.dart';
import 'ticket_model.dart';

typedef Lucky16PrintRpc = Future<dynamic> Function(String function, Map<String, dynamic>? params);

Future<dynamic> _supabaseRpc(String function, Map<String, dynamic>? params) =>
    Supabase.instance.client.rpc(function, params: params);

class SupabaseLucky16PrintApi implements Lucky16PrintApi {
  final Lucky16PrintRpc _rpc;

  SupabaseLucky16PrintApi({Lucky16PrintRpc? rpc}) : _rpc = rpc ?? _supabaseRpc;

  @override
  Future<Lucky16PrintState> state() async =>
      Lucky16PrintState.fromJson(Map<String, dynamic>.from(await _rpc('lucky16_print_state', null) as Map));

  @override
  Future<Lucky16TicketSold> printTicket({
    required String roundId,
    required Map<Lucky16Card, int> bets,
    required String requestId,
  }) async {
    try {
      final res = await _rpc('lucky16_print_ticket', {
        'p_round_id': roundId,
        'p_bets': {for (final e in bets.entries) e.key.key: e.value},
        'p_request_id': requestId,
      });
      final j = Map<String, dynamic>.from(res as Map);
      return Lucky16TicketSold(
        Lucky16Ticket.fromJson(j),
        (j['round_total'] as num).toInt(),
        (j['coin_balance'] as num).toInt(),
        (j['ledger_version'] as num).toInt(),
      );
    } on PostgrestException catch (e) {
      debugPrint('lucky16_print_ticket refused: ${e.code}');
      // A code from the database is its final answer. Anything else may be a
      // reply that was lost on the way back.
      final code = e.code ?? '';
      throw Lucky16PrintException(
          code.startsWith('P0') ? Lucky16PrintRefusal.fromCode(code) : Lucky16PrintRefusal.offline);
    } on SocketException {
      throw const Lucky16PrintException(Lucky16PrintRefusal.offline);
    } on AuthException {
      throw const Lucky16PrintException(Lucky16PrintRefusal.offline);
    } on Lucky16PrintException {
      rethrow;
    } catch (e) {
      debugPrint('lucky16_print_ticket failed: $e');
      throw const Lucky16PrintException(Lucky16PrintRefusal.offline);
    }
  }

  @override
  Future<List<Lucky16Ticket>> tickets({String? roundId, DateTime? since}) async {
    final res = await _rpc('lucky16_my_tickets', {
      'p_round_id': roundId,
      'p_since': since?.toUtc().toIso8601String(),
    });
    return [for (final row in res as List) Lucky16Ticket.fromJson(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<void> mark(String ticketId, String status, {bool reprint = false}) async {
    await _rpc('print_mark_ticket', {'p_ticket_id': ticketId, 'p_status': status, 'p_reprint': reprint});
  }
}

/// The printer and paper chosen on this computer.
class PrintSettingsStore {
  /// The settings file; replaced in tests.
  final File file;

  PrintSettingsStore({File? file})
      : file = file ?? File('${Platform.environment['APPDATA'] ?? '.'}\\BSG\\print_settings.json');

  Future<Map<String, dynamic>> _read() async {
    try {
      return Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map);
    } catch (_) {
      return const {};
    }
  }

  Future<String?> printer() async => (await _read())['printer'] as String?;

  Future<TicketPaper> paper() async {
    final saved = (await _read())['paper'];
    return TicketPaper.values.firstWhere((p) => p.name == saved, orElse: () => TicketPaper.mm80);
  }

  Future<void> save(String printer, TicketPaper paper) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({'printer': printer, 'paper': paper.name}));
  }
}
