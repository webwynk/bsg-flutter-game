import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'spin2win_tickets.dart';

typedef Spin2WinPrintRpc = Future<dynamic> Function(String function, Map<String, dynamic>? params);

Future<dynamic> _supabaseRpc(String function, Map<String, dynamic>? params) =>
    Supabase.instance.client.rpc(function, params: params);

class SupabaseSpin2WinPrintApi implements Spin2WinPrintApi {
  final Spin2WinPrintRpc _rpc;

  SupabaseSpin2WinPrintApi({Spin2WinPrintRpc? rpc}) : _rpc = rpc ?? _supabaseRpc;

  @override
  Future<Spin2WinPrintState> state() async =>
      Spin2WinPrintState.fromJson(Map<String, dynamic>.from(await _rpc('spin2win_print_state', null) as Map));

  @override
  Future<Spin2WinTicketSold> printTicket({
    required String roundId,
    required Map<int, int> bets,
    required String requestId,
  }) async {
    try {
      final res = await _rpc('spin2win_print_ticket', {
        'p_round_id': roundId,
        'p_bets': {for (final e in bets.entries) 'n${e.key}': e.value},
        'p_request_id': requestId,
      });
      final j = Map<String, dynamic>.from(res as Map);
      return Spin2WinTicketSold(
        Spin2WinTicket.fromJson(j),
        (j['round_total'] as num).toInt(),
        (j['coin_balance'] as num).toInt(),
        (j['ledger_version'] as num).toInt(),
      );
    } on PostgrestException catch (e) {
      debugPrint('spin2win_print_ticket refused: ${e.code}');
      // A code from the database is its final answer. Anything else may be a
      // reply that was lost on the way back.
      final code = e.code ?? '';
      throw Spin2WinPrintException(
          code.startsWith('P0') ? Spin2WinPrintRefusal.fromCode(code) : Spin2WinPrintRefusal.offline);
    } on SocketException {
      throw const Spin2WinPrintException(Spin2WinPrintRefusal.offline);
    } on AuthException {
      throw const Spin2WinPrintException(Spin2WinPrintRefusal.offline);
    } on Spin2WinPrintException {
      rethrow;
    } catch (e) {
      debugPrint('spin2win_print_ticket failed: $e');
      throw const Spin2WinPrintException(Spin2WinPrintRefusal.offline);
    }
  }

  @override
  Future<List<Spin2WinTicket>> tickets({String? roundId, DateTime? since}) async {
    final res = await _rpc('spin2win_my_tickets', {
      'p_round_id': roundId,
      'p_since': since?.toUtc().toIso8601String(),
    });
    return [for (final row in res as List) Spin2WinTicket.fromJson(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<void> mark(String ticketId, String status, {bool reprint = false}) async {
    await _rpc('print_mark_ticket', {'p_ticket_id': ticketId, 'p_status': status, 'p_reprint': reprint});
  }
}
