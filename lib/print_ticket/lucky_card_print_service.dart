import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lucky_card_models.dart';
import 'lucky_card_tickets.dart';

typedef LuckyCardPrintRpc = Future<dynamic> Function(String function, Map<String, dynamic>? params);

Future<dynamic> _supabaseRpc(String function, Map<String, dynamic>? params) =>
    Supabase.instance.client.rpc(function, params: params);

class SupabaseLuckyCardPrintApi implements LuckyCardPrintApi {
  final LuckyCardPrintRpc _rpc;

  SupabaseLuckyCardPrintApi({LuckyCardPrintRpc? rpc}) : _rpc = rpc ?? _supabaseRpc;

  @override
  Future<LuckyCardPrintState> state() async =>
      LuckyCardPrintState.fromJson(Map<String, dynamic>.from(await _rpc('lucky_card_print_state', null) as Map));

  @override
  Future<LuckyCardTicketSold> printTicket({
    required String roundId,
    required Map<LuckyCard, int> bets,
    required String requestId,
  }) async {
    try {
      final res = await _rpc('lucky_card_print_ticket', {
        'p_round_id': roundId,
        'p_bets': {for (final e in bets.entries) e.key.key: e.value},
        'p_request_id': requestId,
      });
      final j = Map<String, dynamic>.from(res as Map);
      return LuckyCardTicketSold(
        LuckyCardTicket.fromJson(j),
        (j['round_total'] as num).toInt(),
        (j['coin_balance'] as num).toInt(),
        (j['ledger_version'] as num).toInt(),
      );
    } on PostgrestException catch (e) {
      debugPrint('lucky_card_print_ticket refused: ${e.code}');
      // A code from the database is its final answer. Anything else may be a
      // reply that was lost on the way back.
      final code = e.code ?? '';
      throw LuckyCardPrintException(
          code.startsWith('P0') ? LuckyCardPrintRefusal.fromCode(code) : LuckyCardPrintRefusal.offline);
    } on SocketException {
      throw const LuckyCardPrintException(LuckyCardPrintRefusal.offline);
    } on AuthException {
      throw const LuckyCardPrintException(LuckyCardPrintRefusal.offline);
    } on LuckyCardPrintException {
      rethrow;
    } catch (e) {
      debugPrint('lucky_card_print_ticket failed: $e');
      throw const LuckyCardPrintException(LuckyCardPrintRefusal.offline);
    }
  }

  @override
  Future<List<LuckyCardTicket>> tickets({String? roundId, DateTime? since}) async {
    final res = await _rpc('lucky_card_my_tickets', {
      'p_round_id': roundId,
      'p_since': since?.toUtc().toIso8601String(),
    });
    return [for (final row in res as List) LuckyCardTicket.fromJson(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<void> mark(String ticketId, String status, {bool reprint = false}) async {
    await _rpc('print_mark_ticket', {'p_ticket_id': ticketId, 'p_status': status, 'p_reprint': reprint});
  }
}
