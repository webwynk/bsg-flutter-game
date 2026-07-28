import 'package:flutter/foundation.dart';
import '../models/spin_result_model.dart';
import '../services/api_service.dart';

class HistoryProvider extends ChangeNotifier {
  final List<SpinResult> _records = [];
  int _page = 1;
  final int _pageSize = 100;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _error;

  int _totalPlay = 0;
  int _totalWin = 0;
  int _totalRecords = 0;

  List<SpinResult> get records => List.unmodifiable(_records);
  int get page => _page;
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalPlay => _totalPlay;
  int get totalWin => _totalWin;
  int get totalRecords => _totalRecords;

  Future<void> loadFirstPage(String token, {String? userId, DateTime? since}) async {
    _records.clear();
    _page = 1;
    _hasMore = true;
    _totalPlay = 0;
    _totalWin = 0;
    _totalRecords = 0;
    _error = null;
    await loadPage(token, 1, userId: userId, since: since);
  }

  Future<void> loadPage(String token, int pageNum, {String? userId, DateTime? since}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService().getGameHistory(
        token,
        userId: userId,
        page: pageNum,
        pageSize: _pageSize,
        since: since,
      );

      final list = (res['records'] as List)
          .map((e) => SpinResult.fromJson(e as Map<String, dynamic>))
          .toList();

      _records.clear();
      
      // Update page records
      _records.addAll(list);
      _totalPlay = res['totalPlayAllTime'] as int? ?? 0;
      _totalWin = res['totalWinAllTime'] as int? ?? 0;
      _totalRecords = res['totalRecords'] as int? ?? 0;
      _page = pageNum;
      
      _hasMore = (_page * _pageSize) < _totalRecords;
    } catch (e) {
      _error = 'Could not load history. Tap to retry.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearLocal() {
    _records.clear();
    _page = 1;
    _hasMore = true;
    _totalPlay = 0;
    _totalWin = 0;
    _totalRecords = 0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
