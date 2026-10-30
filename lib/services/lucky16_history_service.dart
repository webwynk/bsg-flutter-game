// How the Lucky 16 Card app reads the player's own history from the database.
//
// Like Triple Chance's history, this reads the bets table joined to the rounds table
// directly (no function): row-level security shows a player only their own bets, and
// only rounds that are `settled`, so a round that is still running is left out by the
// inner join and a result is never visible before the wheel has landed. A round only
// turns `settled` after every bet in it has been scored, so a listed bet always has its
// final payout.
//
// [Lucky16HistoryService] is the real implementation over the signed-in Supabase
// client; tests hand in their own [Lucky16RowsQuery]. A failed read throws: the
// provider turns that into the "could not load" state, so an honest error is never
// mistaken for "no rounds played yet".
//
// Copied from lib/services/lucky_card_history_service.dart (Lucky Card); only the
// names changed: it reads lucky16_bets joined to lucky16_rounds. The row-level
// security it relies on (own bets only, settled rounds only) is the same on the
// lucky16 tables (lucky16_bets_select / lucky16_rounds_select, migration
// 20261028120000, checked live on 2026-10-28).
//
// Belongs to Lucky 16 Card only. It uses the shared Supabase client the app already
// initialised (`Supabase.instance.client`) and nothing else from Triple Chance or
// Lucky Card.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lucky16_history_model.dart';
import 'lucky16_api_contract.dart';

/// Reads up to [limit] rows of the player's bets, newest first, from [since] on (every
/// bet when [since] is null). The real version queries Supabase; tests pass a scripted
/// one. Each row is a map shaped as [Lucky16HistoryEntry.fromRow] expects.
typedef Lucky16RowsQuery = Future<List<dynamic>> Function(DateTime? since, int limit);

/// The columns read: this bet, and its round embedded under `lucky16_rounds`.
/// `!inner` drops a bet whose round the player may not see yet.
const String kLucky16HistorySelect =
    '${Lucky16Field.roundId}, ${Lucky16Field.totalStake}, ${Lucky16Field.totalPayout}, '
    '${Lucky16Field.createdAt}, '
    '${Lucky16Table.rounds}!inner ( ${Lucky16Field.roundNumber}, ${Lucky16Field.winningRank}, '
    '${Lucky16Field.winningSuit}, ${Lucky16Field.bonusMultiplier} )';

Future<List<dynamic>> _supabaseRows(DateTime? since, int limit) {
  var query = Supabase.instance.client.from(Lucky16Table.bets).select(kLucky16HistorySelect);
  if (since != null) {
    query = query.gte(Lucky16Field.createdAt, since.toUtc().toIso8601String());
  }
  return query.order(Lucky16Field.createdAt, ascending: false).limit(limit);
}

class Lucky16HistoryService {
  /// Pass [query] only in tests; by default every read goes through the app's
  /// authenticated Supabase client.
  Lucky16HistoryService({Lucky16RowsQuery? query}) : _query = query ?? _supabaseRows;

  final Lucky16RowsQuery _query;

  /// A safety ceiling, not a real-world limit: at one round every 103 seconds, 10000
  /// rounds is about 12 days of uninterrupted play.
  static const int maxRows = 10000;

  /// Every round the player bet on since [since] (the start of this login), newest
  /// first, settled rounds only.
  ///
  /// A null [since] means there is no login to measure from, so nothing is read and the
  /// list is empty: the history is "since you logged in", never the player's whole past.
  /// Throws when the read fails or a row cannot be understood.
  Future<List<Lucky16HistoryEntry>> loadSession({required DateTime? since}) async {
    if (since == null) return const [];
    final rows = await _query(since, maxRows);
    return [
      for (final row in rows)
        Lucky16HistoryEntry.fromRow(Map<String, dynamic>.from(row as Map)),
    ];
  }
}
