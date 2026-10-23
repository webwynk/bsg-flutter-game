// How the Lucky Card app reads the player's own history from the database.
//
// Like Triple Chance's history, this reads the bets table joined to the rounds table
// directly (no function): row-level security shows a player only their own bets, and
// only rounds that are `settled`, so a round that is still running is left out by the
// inner join and a result is never visible before the wheel has landed. A round only
// turns `settled` after every bet in it has been scored, so a listed bet always has its
// final payout.
//
// [LuckyCardHistoryService] is the real implementation over the signed-in Supabase
// client; tests hand in their own [LuckyCardRowsQuery]. A failed read throws: the
// provider turns that into the "could not load" state, so an honest error is never
// mistaken for "no rounds played yet".
//
// Belongs to Lucky Card only. It uses the shared Supabase client the app already
// initialised (`Supabase.instance.client`) and nothing else from Triple Chance.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lucky_card_history_model.dart';
import 'lucky_card_api_contract.dart';

/// Reads up to [limit] rows of the player's bets, newest first, from [since] on (every
/// bet when [since] is null). The real version queries Supabase; tests pass a scripted
/// one. Each row is a map shaped as [LuckyCardHistoryEntry.fromRow] expects.
typedef LuckyCardRowsQuery = Future<List<dynamic>> Function(DateTime? since, int limit);

/// The columns read: this bet, and its round embedded under `lucky_card_rounds`.
/// `!inner` drops a bet whose round the player may not see yet.
const String kLuckyCardHistorySelect =
    '${LuckyCardField.roundId}, ${LuckyCardField.totalStake}, ${LuckyCardField.totalPayout}, '
    '${LuckyCardField.createdAt}, '
    '${LuckyCardTable.rounds}!inner ( ${LuckyCardField.roundNumber}, ${LuckyCardField.winningRank}, '
    '${LuckyCardField.winningSuit}, ${LuckyCardField.bonusMultiplier} )';

Future<List<dynamic>> _supabaseRows(DateTime? since, int limit) {
  var query = Supabase.instance.client.from(LuckyCardTable.bets).select(kLuckyCardHistorySelect);
  if (since != null) {
    query = query.gte(LuckyCardField.createdAt, since.toUtc().toIso8601String());
  }
  return query.order(LuckyCardField.createdAt, ascending: false).limit(limit);
}

class LuckyCardHistoryService {
  /// Pass [query] only in tests; by default every read goes through the app's
  /// authenticated Supabase client.
  LuckyCardHistoryService({LuckyCardRowsQuery? query}) : _query = query ?? _supabaseRows;

  final LuckyCardRowsQuery _query;

  /// A safety ceiling, not a real-world limit: at one round every 103 seconds, 10000
  /// rounds is about 12 days of uninterrupted play.
  static const int maxRows = 10000;

  /// Every round the player bet on since [since] (the start of this login), newest
  /// first, settled rounds only.
  ///
  /// A null [since] means there is no login to measure from, so nothing is read and the
  /// list is empty: the history is "since you logged in", never the player's whole past.
  /// Throws when the read fails or a row cannot be understood.
  Future<List<LuckyCardHistoryEntry>> loadSession({required DateTime? since}) async {
    if (since == null) return const [];
    final rows = await _query(since, maxRows);
    return [
      for (final row in rows)
        LuckyCardHistoryEntry.fromRow(Map<String, dynamic>.from(row as Map)),
    ];
  }
}
