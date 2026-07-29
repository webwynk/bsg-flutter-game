import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  DateTime? _sessionStartAt;
  bool _loading = false;
  String? _error;
  Timer? _heartbeatTimer;

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
            final liveBal = (res['balance'] as num).toInt();
            final uncommittedStake = _uncommittedBetGetter?.call() ?? 0;
            updateBalance((liveBal - uncommittedStake).clamp(0, 99999999));
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
