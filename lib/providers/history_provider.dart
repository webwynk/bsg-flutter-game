import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/spin_result_model.dart';
import '../services/api_contract.dart';

/// The player's own betting history for the current session.
///
/// v2 reads `bets` joined to `rounds` directly. RLS restricts the rows to the
/// signed-in player, so no user filter has to be trusted from the client.
///
/// F-3 FIX — v1 set `totalRecords` to the length of the page it had just
/// fetched, so `hasMore` was `page * 100 < <=100`, i.e. always false. Page 2 was
/// unreachable and the session totals silently capped at 100 rounds. This now
/// asks PostgREST for an exact count via `count: CountOption.exact`, and the
/// totals are computed from every row in the session rather than one page.
class HistoryProvider extends ChangeNotifier {
  static const int pageSize = 50;

  final List<SpinResult> _records = [];
  int _page = 1;
  int _totalRecords = 0;
  int _totalStake = 0;
  int _totalPayout = 0;
  bool _isLoading = false;
  String? _error;

  List<SpinResult> get records => List.unmodifiable(_records);
  int get page => _page;
  int get totalRecords => _totalRecords;
  int get totalStake => _totalStake;
  int get totalPayout => _totalPayout;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// True when more pages exist beyond the one currently held.
  bool get hasMore => _page * pageSize < _totalRecords;

  SupabaseClient get _db => Supabase.instance.client;

  Future<void> loadFirstPage({DateTime? since}) async {
    _records.clear();
    _page = 1;
    _totalRecords = 0;
    _totalStake = 0;
    _totalPayout = 0;
    _error = null;
    await loadPage(1, since: since);
  }

  Future<void> loadPage(int pageNum, {DateTime? since}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final from = (pageNum - 1) * pageSize;

      // The embedded round gives the digits for display. `bets` has a real FK to
      // `rounds`, so this resolves reliably.
      var query = _db.from(Tbl.bets).select(
            'id, round_id, single_bets, double_bets, triple_bets, '
            'total_stake, single_payout, double_payout, triple_payout, '
            'total_payout, is_settled, created_at, '
            'rounds!inner ( round_number, red, green, black )',
          );

      if (since != null) {
        query = query.gte('created_at', since.toUtc().toIso8601String());
      }

      final rows = await query
          .order('created_at', ascending: false)
          .range(from, from + pageSize - 1)
          .count(CountOption.exact);

      _records
        ..clear()
        ..addAll(rows.data.map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          final round = Map<String, dynamic>.from(row['rounds'] as Map);

          final stake = (row[Field.totalStake] as num?)?.toInt() ?? 0;
          final payout = (row[Field.totalPayout] as num?)?.toInt() ?? 0;

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
            won: payout > 0,
            deductedAmount: stake,
            winAmount: payout,
            singleWinAmount: (row[Field.singlePayout] as num?)?.toInt() ?? 0,
            doubleWinAmount: (row[Field.doublePayout] as num?)?.toInt() ?? 0,
            tripleWinAmount: (row[Field.triplePayout] as num?)?.toInt() ?? 0,
            netChange: payout - stake,
            createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
          );
        }));

      _totalRecords = rows.count;
      _page = pageNum;

      // Session totals span every round, not just this page.
      await _loadSessionTotals(since: since);
    } catch (e) {
      debugPrint('HistoryProvider.loadPage: $e');
      _error = 'Could not load history. Tap to retry.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sums stake and payout across the whole session, independent of paging.
  Future<void> _loadSessionTotals({DateTime? since}) async {
    try {
      var q = _db.from(Tbl.bets).select('total_stake, total_payout');
      if (since != null) {
        q = q.gte('created_at', since.toUtc().toIso8601String());
      }
      final rows = await q.limit(10000);

      var stake = 0;
      var payout = 0;
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw as Map);
        stake += (row[Field.totalStake] as num?)?.toInt() ?? 0;
        payout += (row[Field.totalPayout] as num?)?.toInt() ?? 0;
      }
      _totalStake = stake;
      _totalPayout = payout;
    } catch (e) {
      debugPrint('HistoryProvider._loadSessionTotals: $e');
    }
  }

  void clearLocal() {
    _records.clear();
    _page = 1;
    _totalRecords = 0;
    _totalStake = 0;
    _totalPayout = 0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
