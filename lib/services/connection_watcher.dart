import 'dart:async';
import 'dart:io';
import '../constants.dart';

/// True when the Supabase server answers at all. Any answer counts, even an
/// error, because this only asks whether the server can be reached.
Future<bool> serverReachable() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client.getUrl(Uri.parse('$kSupabaseUrl/auth/v1/health'));
    request.headers.set('apikey', kSupabaseAnonKey);
    final response = await request.close().timeout(const Duration(seconds: 3));
    await response.drain<void>();
    return true;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

/// Watches the connection from the lobby. It checks every [interval], only
/// while [isActive] says the lobby is on show, so it stops while a game is open.
///
/// Two failures in a row call [onLost], so a short blip shows nothing. The next
/// success calls [onBack], which is told whether the outage lasted [longOutage]
/// or more: by then the server has given the player's seat away.
class ConnectionWatcher {
  static const interval = Duration(seconds: 5);
  static const failuresToReport = 2;
  static const longOutage = Duration(seconds: 30);

  final Future<bool> Function() ping;
  final bool Function() isActive;
  final void Function() onLost;
  final void Function(bool wasLongOutage) onBack;

  /// Where the time comes from; tests pass their own.
  final DateTime Function() now;

  ConnectionWatcher({
    required this.ping,
    required this.isActive,
    required this.onLost,
    required this.onBack,
    this.now = DateTime.now,
  });

  Timer? _timer;
  bool _checking = false;
  bool _lost = false;
  int _failures = 0;
  DateTime? _firstFailure;

  void start() => _timer ??= Timer.periodic(interval, (_) => _check());

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    if (_checking) return;
    if (!isActive()) {
      _failures = 0;
      _firstFailure = null;
      return;
    }
    _checking = true;
    final reachable = await ping();
    _checking = false;
    if (_timer == null || !isActive()) return;

    if (reachable) {
      final wasLost = _lost;
      final wasLong = wasLost && now().difference(_firstFailure!) >= longOutage;
      _lost = false;
      _failures = 0;
      _firstFailure = null;
      if (wasLost) onBack(wasLong);
      return;
    }
    _failures++;
    _firstFailure ??= now();
    if (!_lost && _failures >= failuresToReport) {
      _lost = true;
      onLost();
    }
  }
}
