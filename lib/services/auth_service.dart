import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Local session persistence.
///
/// S-1 NOTE — v1 stored the raw JWT twice: base64-encoded under
/// `bsg_auth_token`, and again in plaintext inside the serialised user object.
/// base64 is an encoding, not encryption, so both were trivially readable.
///
/// v2 does not persist the token at all. The Supabase SDK already manages its
/// own session storage and refresh, so keeping a second copy added risk without
/// adding capability. What is stored here is only the non-sensitive profile
/// needed to render the UI before the SDK finishes restoring.
class AuthService {
  static const _keyUser = 'bsg_auth_user';
  static const _keySessionStart = 'bsg_session_start_at';

  /// F-10: the drawn-numbers cache. Cleared on every session boundary so a
  /// previous player's rounds cannot reappear under "this session" — v1 wrote
  /// this key but never removed it, and cleared an unrelated key instead.
  static const keyDrawnNumbers = 'bsg_drawn_numbers_history';

  Future<void> saveSession(UserModel user, DateTime sessionStartAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    await prefs.setString(_keySessionStart, sessionStartAt.toIso8601String());
    // A new session starts with a clean history strip.
    await prefs.remove(keyDrawnNumbers);
  }

  Future<(UserModel, DateTime)?> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_keyUser);
      final startedAt = prefs.getString(_keySessionStart);
      if (userJson == null || startedAt == null) return null;

      final user = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      return (user, DateTime.parse(startedAt));
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
    await prefs.remove(_keySessionStart);
    await prefs.remove(keyDrawnNumbers);
  }
}
