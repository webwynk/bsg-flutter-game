import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/spin_result_model.dart';
import '../services/api_contract.dart';

/// The player's own betting history for the current session.
///
/// v2 reads `bets` joined to `rounds` directly. RLS restricts the rows to the
/// signed-in player, so no user filter has to be trusted from the client.
///
/// Issue #11 fix: loads every round played since login in one query instead
/// of paging 50 at a time. Previously the row list stopped at 50 while a
/// separate query summed the *whole* session for the totals footer, so a
/// session past 50 rounds showed a "TOTAL SESSION" figure that didn't match
/// what was actually visible above it. Now both the row list and the totals
/// come from the same single query, so they can never disagree.
class HistoryProvider extends ChangeNotifier {
  // Safety ceiling, not a real-world limit -- at this game's ~103-second
  // round cycle, 10000 rounds is roughly 12 days of uninterrupted play.
  static const int _maxRows = 10000;

  final List<SpinResult> _records = [];
  int _totalStake = 0;
  int _totalPayout = 0;
  bool _isLoading = false;
  String? _error;

  List<SpinResult> get records => List.unmodifiable(_records);
  int get totalStake => _totalStake;
  int get totalPayout => _totalPayout;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SupabaseClient get _db => Supabase.instance.client;

  /// Loads every round played since [since] (the current login's session
  /// start) in one request.
  Future<void> loadSession({DateTime? since}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // The embedded round gives the digits for display. `bets` has a real FK to
      // `rounds`, so this resolves reliably.
      //
      // Issue #85: single_bets/double_bets/triple_bets, round_number, and
      // is_settled used to be selected here too, but nothing in the mapping
      // below ever read them -- fetched every session load, then discarded.
      // Removed rather than left unused; the player-facing "Picks:" detail
      // they would have fed was a confirmed-unwanted feature, not a bug to fix.
      var query = _db.from(Tbl.bets).select(
            'id, round_id, '
            'total_stake, single_payout, double_payout, triple_payout, '
            'total_payout, created_at, '
            'rounds!inner ( red, green, black )',
          );

      if (since != null) {
        query = query.gte('created_at', since.toUtc().toIso8601String());
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(_maxRows);

      var stake = 0;
      var payout = 0;

      _records
        ..clear()
        ..addAll(rows.map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          final round = Map<String, dynamic>.from(row['rounds'] as Map);

          final rowStake = (row[Field.totalStake] as num?)?.toInt() ?? 0;
          final rowPayout = (row[Field.totalPayout] as num?)?.toInt() ?? 0;
          stake += rowStake;
          payout += rowPayout;

          // Payouts come from the server. v1 recomputed them client-side and
          // discarded the stored value, which meant the app and the dashboard
          // could disagree about the same hand.
          return SpinResult(
            id: row[Field.roundId]?.toString() ?? row['id'].toString(),
            red: (round[Field.red] as num?)?.toInt() ?? 0,
            green: (round[Field.green] as num?)?.toInt() ?? 0,
            black: (round[Field.black] as num?)?.toInt() ?? 0,
            mode: 'multiplayer',
            selections: const [],
            chipValue: 0,
            won: rowPayout > 0,
            deductedAmount: rowStake,
            winAmount: rowPayout,
            singleWinAmount: (row[Field.singlePayout] as num?)?.toInt() ?? 0,
            doubleWinAmount: (row[Field.doublePayout] as num?)?.toInt() ?? 0,
            tripleWinAmount: (row[Field.triplePayout] as num?)?.toInt() ?? 0,
            netChange: rowPayout - rowStake,
            createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
          );
        }));

      _totalStake = stake;
      _totalPayout = payout;
    } catch (e) {
      debugPrint('HistoryProvider.loadSession: $e');
      _error = 'Could not load history. Tap to retry.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearLocal() {
    _records.clear();
    _totalStake = 0;
    _totalPayout = 0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
