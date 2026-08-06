import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  DateTime? _sessionStartAt;
  bool _loading = false;
  String? _error;
  Timer? _heartbeatTimer;

  // M-5: `profiles.ledger_version` is bumped by the database on every balance
  // change and returned by submit_round_bet, update_user_heartbeat and
  // get_my_round_result_v2. Ordering balance updates by it replaces the old
  // holdHeartbeatBalance()/suspendHeartbeatPolling() locks, whose many early
  // returns could leak and freeze the displayed balance for the whole process.
  int _ledgerVersion = 0;

  int get ledgerVersion => _ledgerVersion;

  /// Applies a server-sourced balance only if it is at least as fresh as what
  /// has already been applied. Older in-flight responses are discarded.
  void updateBalanceWithVersion(int newBalance, int version) {
    if (version >= _ledgerVersion) {
      _ledgerVersion = version;
      updateBalance(newBalance);
    }
  }

  /// Applies a locally predicted balance (the win shown the instant the wheel
  /// stops) and claims the next ledger slot, so a heartbeat issued before the
  /// prediction cannot roll it back. Only valid when the database is known to
  /// be incrementing too — i.e. an actual win payout.
  void applyOptimisticBalance(int newBalance) {
    _ledgerVersion += 1;
    updateBalance(newBalance);
  }

  /// Applies a settled, authoritative balance and re-anchors the local version
  /// to the server's. Used after get_my_round_result_v2, which is the final
  /// word on a round, so it must win even if an optimistic bump ran ahead.
  void syncAuthoritativeBalance(int newBalance, int version) {
    _ledgerVersion = version;
    updateBalance(newBalance);
  }

  UserModel? get user    => _user;
  DateTime? get sessionStartAt => _sessionStartAt;
  bool get isLoggedIn    => _user != null;
  bool get isLoading     => _loading;
  String? get error      => _error;
  int get balance        => _user?.balance ?? 0;
  String get username    => _user?.username ?? '';
  String get agentName   => _user?.agentName ?? 'N/A';
  String get token       => _user?.token ?? '';

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService().login(username.trim(), password.trim());
      final userData = Map<String, dynamic>.from(res['user'] as Map);
      userData['token'] = res['token'];
      _user = UserModel.fromJson(userData);
      _ledgerVersion = 0;   // M-5: unknown at login; accept the first heartbeat.

      final sessionStartStr = res['sessionStartAt'] ?? res['session_start_at'];
      _sessionStartAt = sessionStartStr != null 
          ? DateTime.tryParse(sessionStartStr.toString()) 
          : null;
      _sessionStartAt ??= DateTime.now().toUtc();

      await AuthService().saveSession(_user!, _sessionStartAt!);
      _startHeartbeatTimer();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    if (_user == null) return;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (_user != null && token.isNotEmpty) {
        final res = await ApiService().updateHeartbeat(token, _user!.id);
        if (res != null) {
          if (res['allowed'] == false) {
            final reason = res['reason']?.toString();
            final msg = reason == 'account_blocked'
                ? 'Account is blocked. Please contact your Agent.'
                : 'Account logged in on another device.';
            await logout();
            setError(msg);
          } else if (res['allowed'] == true && res.containsKey('balance') && res['balance'] != null) {
            // M-5: apply only if this response is at least as fresh as what we
            // already have. `uncommittedStake` is still subtracted because
            // chips placed on the board are deducted locally and do not reach
            // the database until submit_round_bet runs at the close of betting.
            final liveBal = (res['balance'] as num).toInt();
            final version = (res['ledger_version'] as num?)?.toInt() ?? 0;
            final uncommittedStake = _uncommittedBetGetter?.call() ?? 0;
            updateBalanceWithVersion(
              (liveBal - uncommittedStake).clamp(0, 99999999),
              version,
            );
          }
        }
      }
    });
  }

  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  int? Function()? _uncommittedBetGetter;
  void setUncommittedBetGetter(int? Function()? getter) {
    _uncommittedBetGetter = getter;
  }

  Future<bool> tryAutoLogin() async {
    try {
      final saved = await AuthService().loadSession();
      if (saved != null) {
        final (user, sessionStartAt) = saved;
        _user = user;
        _sessionStartAt = sessionStartAt;
        if (user.token != null && user.token!.isNotEmpty) {
          try {
            await Supabase.instance.client.auth.setSession(user.token!);
          } catch (e) {
            debugPrint('AuthProvider.tryAutoLogin setSession error: $e');
          }
        }
        _startHeartbeatTimer();
        notifyListeners();

        // FIX #4: Fetch fresh live balance from DB after restoring session.
        // The saved token may be stale (e.g. player won and balance changed since last save).
        if (user.token != null && user.token!.isNotEmpty) {
          try {
            final fresh = await ApiService().fetchProfile(user.token!, user.id);
            if (fresh != null) {
              final freshBal = (fresh['balance'] as num?)?.toInt();
              if (freshBal != null) updateBalance(freshBal);
            }
          } catch (e) {
            debugPrint('AuthProvider.tryAutoLogin freshBalance error: $e');
          }
        }

        return true;
      }
    } catch (e) {
      debugPrint('AuthProvider.tryAutoLogin error: $e');
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  void updateBalance(int newBalance) {
    if (_user == null) return;
    _user = _user!.copyWith(balance: newBalance);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setError(String err) {
    _error = err;
    notifyListeners();
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await ApiService().changePassword(
        token: token,
        username: username,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _loading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _stopHeartbeatTimer();
    if (_user != null) {
      try {
        await ApiService().clearSessionRemote(token, _user!.id);
        await ApiService().logout(token);
      } catch (_) {}
    }
    await AuthService().clearSession();
    _user = null;
    _sessionStartAt = null;
    _error = null;
    notifyListeners();
  }
}
