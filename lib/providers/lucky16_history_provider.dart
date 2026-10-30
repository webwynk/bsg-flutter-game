// The player's own Lucky 16 Card history for the current login, for the History dialog.
//
// Works the way Triple Chance's history does, with no state kept between visits: every
// time the dialog opens, [loadSession] asks the database for every round the player bet
// on since they logged in (`AuthProvider.sessionStartAt`), so leaving the game with EXIT
// and coming back shows the same list, and logging out and in again starts an empty one.
// The screen owns this object and drops it with the screen; nothing is registered in
// main.dart.
//
// The list and the TOTAL SESSION footer are both worked out from the same single read, so
// the footer can never disagree with the rows above it (Triple Chance's Issue #11).
//
// Copied from lib/providers/lucky_card_history_provider.dart (Lucky Card); only
// the names changed. Belongs to Lucky 16 Card only.

import 'package:flutter/foundation.dart';

import '../models/lucky16_history_model.dart';
import '../services/lucky16_history_service.dart';

class Lucky16HistoryProvider extends ChangeNotifier {
  Lucky16HistoryProvider({Lucky16HistoryService? service})
      : _service = service ?? Lucky16HistoryService();

  /// What the dialog shows when a read failed, as Triple Chance words it.
  static const String loadErrorText = 'Could not load history. Tap to retry.';

  final Lucky16HistoryService _service;

  List<Lucky16HistoryEntry> _records = const [];
  int _totalStake = 0;
  int _totalPayout = 0;
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  /// The rounds played since login, newest first.
  List<Lucky16HistoryEntry> get records => _records;

  /// The sum of every stake in [records] (the PLAY figure of the TOTAL SESSION footer).
  int get totalStake => _totalStake;

  /// The sum of every payout in [records] (the WIN figure of the footer).
  int get totalPayout => _totalPayout;

  bool get isLoading => _isLoading;

  /// [loadErrorText] after a failed read, `null` after a good one.
  String? get error => _error;

  /// Reads every round played since [since] (the start of this login). A second call
  /// while one is already reading does nothing. A failed read keeps what was shown
  /// before and sets [error]; it never clears the list into a false "no rounds yet".
  Future<void> loadSession({required DateTime? since}) async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final records = await _service.loadSession(since: since);
      var stake = 0;
      var payout = 0;
      for (final r in records) {
        stake += r.stake;
        payout += r.payout;
      }
      _records = List.unmodifiable(records);
      _totalStake = stake;
      _totalPayout = payout;
    } catch (e) {
      debugPrint('Lucky16HistoryProvider.loadSession: $e');
      _error = loadErrorText;
    } finally {
      _isLoading = false;
      // The screen can close while the read is still on its way.
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
