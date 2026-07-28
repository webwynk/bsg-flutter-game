import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static const _keyToken    = 'bsg_auth_token';
  static const _keyUser     = 'bsg_auth_user';
  static const _keySession  = 'bsg_session_start_at';

  Future<void> saveSession(UserModel user, DateTime sessionStartAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, user.token ?? '');
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    await prefs.setString(_keySession, sessionStartAt.toIso8601String());
    await prefs.remove('bsg_local_game_history');
  }

  Future<(UserModel, DateTime)?> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyToken);
      final userJson = prefs.getString(_keyUser);
      final sessionStr = prefs.getString(_keySession);
      if (token == null || token.isEmpty || userJson == null || sessionStr == null) return null;
      final map = jsonDecode(userJson) as Map<String, dynamic>;
      final user = UserModel.fromJson({...map, 'token': token});
      final sessionStartAt = DateTime.parse(sessionStr);
      return (user, sessionStartAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keySession);
    await prefs.remove('bsg_local_game_history');
  }

  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    return token != null && token.isNotEmpty;
  }
}
