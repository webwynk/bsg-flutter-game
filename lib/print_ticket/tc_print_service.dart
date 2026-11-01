import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tc_tickets.dart';

typedef TcPrintRpc = Future<dynamic> Function(String function, Map<String, dynamic>? params);

Future<dynamic> _supabaseRpc(String function, Map<String, dynamic>? params) =>
    Supabase.instance.client.rpc(function, params: params);

class SupabaseTcPrintApi implements TcPrintApi {
  final TcPrintRpc _rpc;

  SupabaseTcPrintApi({TcPrintRpc? rpc}) : _rpc = rpc ?? _supabaseRpc;

  @override
  Future<TcPrintState> state() async =>
      TcPrintState.fromJson(Map<String, dynamic>.from(await _rpc('tc_print_state', null) as Map));

  @override
  Future<TcTicketSold> printTicket({
    required String roundId,
    required Map<String, Map<String, int>> bets,
    required String requestId,
  }) async {
    try {
      final res = await _rpc('tc_print_ticket', {
        'p_round_id': roundId,
        'p_single_bets': bets['single'] ?? const {},
        'p_double_bets': bets['double'] ?? const {},
        'p_triple_bets': bets['triple'] ?? const {},
        'p_request_id': requestId,
      });
      final j = Map<String, dynamic>.from(res as Map);
      return TcTicketSold(
        TcTicket.fromJson(j),
        (j['round_total'] as num).toInt(),
        (j['coin_balance'] as num).toInt(),
        (j['ledger_version'] as num).toInt(),
      );
    } on PostgrestException catch (e) {
      debugPrint('tc_print_ticket refused: ${e.code}');
      // A code from the database is its final answer. Anything else may be a
      // reply that was lost on the way back.
      final code = e.code ?? '';
      throw TcPrintException(
          code.startsWith('P0') ? TcPrintRefusal.fromCode(code) : TcPrintRefusal.offline);
    } on SocketException {
      throw const TcPrintException(TcPrintRefusal.offline);
    } on AuthException {
      throw const TcPrintException(TcPrintRefusal.offline);
    } on TcPrintException {
      rethrow;
    } catch (e) {
      debugPrint('tc_print_ticket failed: $e');
      throw const TcPrintException(TcPrintRefusal.offline);
    }
  }

  @override
  Future<List<TcTicket>> tickets({String? roundId, DateTime? since}) async {
    final res = await _rpc('tc_my_tickets', {
      'p_round_id': roundId,
      'p_since': since?.toUtc().toIso8601String(),
    });
    return [for (final row in res as List) TcTicket.fromJson(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<void> mark(String ticketId, String status, {bool reprint = false}) async {
    await _rpc('print_mark_ticket', {'p_ticket_id': ticketId, 'p_status': status, 'p_reprint': reprint});
  }
}
