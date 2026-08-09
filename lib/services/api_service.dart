import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_contract.dart';

/// Outcome of a login attempt.
class LoginOutcome {
  final bool success;

  /// Populated on success. Mirrors the `session_login` payload.
  final Map<String, dynamic>? profile;

  /// Message to show the player when [success] is false.
  final String? error;

  /// True when the refusal was because another device holds the session,
  /// so the UI can offer to retry rather than treating it as bad credentials.
  final bool sessionHeldElsewhere;

  /// Seconds until the other device's session goes stale and can be taken over.
  final int secondsUntilFree;

  /// True when a player's account is blocked -- either just now, by hitting
  /// 5 failed attempts, or already blocked beforehand (by an agent, or by an
  /// earlier lockout). The UI shows the same blocked-account popup either way.
  final bool accountBlocked;

  /// Set only on a wrong password against a real player account (not staff,
  /// not a non-existent username). Null when not applicable.
  final int? attemptsRemaining;

  const LoginOutcome({
    required this.success,
    this.profile,
    this.error,
    this.sessionHeldElsewhere = false,
    this.secondsUntilFree = 0,
    this.accountBlocked = false,
    this.attemptsRemaining,
  });
}

/// Authentication and profile access.
///
/// v2 talks to Supabase Auth plus the session RPCs. There is no longer a
/// duplicate `/api/auth/login` implementation in the dashboard to drift from
/// (audit finding M-6).
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  SupabaseClient get _db => Supabase.instance.client;

  /// Identity convention, enforced in the database by a CHECK constraint:
  ///   email = lower(username) || '@bestsmartgame.com'
  /// Deriving it here cannot drift from the account, because the database
  /// refuses to store a profile whose email does not match its username.
  static String emailFor(String username) {
    final u = username.trim().toLowerCase();
    return u.contains('@') ? u : '$u@bestsmartgame.com';
  }

  /// Signs in, then claims the single-device session.
  ///
  /// Q6: if another device is still heartbeating, the login is **refused** and
  /// the first device keeps playing. v1 always allowed the second login and
  /// silently displaced the first, so the "already logged in" message could
  /// never appear.
  Future<LoginOutcome> login(String username, String password) async {
    final user = username.trim();
    final pass = password.trim();

    if (user.isEmpty) return const LoginOutcome(success: false, error: 'Please enter your username');
    if (pass.isEmpty) return const LoginOutcome(success: false, error: 'Please enter your password');

    // ── 0. Failed-login lockout: verify + count, BEFORE any Supabase Auth
    // call exists to spoof. attempt_player_login does the real password
    // check itself and returns success:true as a deliberate pass-through for
    // a non-existent username or a non-player (staff) account -- those cases
    // fall through to the normal signInWithPassword flow below completely
    // unchanged, so their existing messages stay exactly as they were before
    // this feature existed. A transport hiccup here also falls through
    // rather than blocking login on this feature's own availability.
    try {
      final res = await _db.rpc(Rpc.attemptPlayerLogin, params: {
        RpcParam.username: user,
        RpcParam.password: pass,
      });
      final data = Map<String, dynamic>.from(res as Map);

      if (data[Field.success] != true) {
        final reason = data[Field.reason]?.toString();
        if (reason == ReasonCode.accountBlocked || data[Field.locked] == true) {
          return const LoginOutcome(
            success: false,
            accountBlocked: true,
            error: 'You are temporarily blocked. Please contact your agent.',
          );
        }
        // invalid_credentials: a real player account, confirmed wrong password.
        final remaining = (data[Field.attemptsRemaining] as num?)?.toInt();
        return LoginOutcome(
          success: false,
          attemptsRemaining: remaining,
          error: remaining != null
              ? 'Wrong username or password. $remaining attempt${remaining == 1 ? '' : 's'} left.'
              : 'Wrong username or password',
        );
      }
      // success:true -- either a genuinely correct player password, or the
      // deliberate pass-through for a non-existent/staff account. Either way,
      // continue to the real Supabase Auth sign-in below, exactly as before.
    } catch (e) {
      debugPrint('ApiService.login attempt_player_login failed (continuing): $e');
    }

    // ── 1. Authenticate ──────────────────────────────────────────────────────
    late final AuthResponse auth;
    try {
      auth = await _db.auth.signInWithPassword(email: emailFor(user), password: pass);
    } on AuthException catch (e) {
      debugPrint('ApiService.login auth failed: ${e.message}');
      return const LoginOutcome(success: false, error: 'Wrong username or password');
    } catch (e) {
      debugPrint('ApiService.login transport error: $e');
      return const LoginOutcome(
        success: false,
        error: 'Connection error. Please check your network connection.',
      );
    }

    final session = auth.session;
    if (session == null || auth.user == null) {
      return const LoginOutcome(success: false, error: 'Wrong username or password');
    }

    // ── 2. Claim the single-device session ───────────────────────────────────
    // session_login also returns the profile, so no extra round trip is needed
    // and there is no window in which the balance could be read from a stale
    // source.
    try {
      final res = await _db.rpc(Rpc.sessionLogin, params: {
        RpcParam.sessionToken: session.accessToken,
      });
      final data = Map<String, dynamic>.from(res as Map);

      if (data[Field.allowed] != true) {
        final reason = data[Field.reason]?.toString();
        await _db.auth.signOut();

        if (reason == ReasonCode.accountBlocked) {
          return const LoginOutcome(
            success: false,
            error: 'Account is blocked. Please contact your Agent.',
          );
        }
        if (reason == ReasonCode.sessionActiveElsewhere) {
          final secs = (data[Field.secondsUntilFree] as num?)?.toInt() ?? 0;
          return LoginOutcome(
            success: false,
            sessionHeldElsewhere: true,
            secondsUntilFree: secs,
            error: 'This account is already playing on another device.',
          );
        }
        return const LoginOutcome(success: false, error: 'Could not start a session. Please try again.');
      }

      // Only players may use the game app. Agents and the superadmin belong in
      // the web dashboard.
      final role = data[Field.role]?.toString();
      if (role != 'player') {
        await _db.auth.signOut();
        return const LoginOutcome(
          success: false,
          error: 'This is a staff account. Please sign in on the web dashboard.',
        );
      }

      return LoginOutcome(
        success: true,
        profile: {...data, 'token': session.accessToken},
      );
    } catch (e) {
      debugPrint('ApiService.login session_login failed: $e');
      try {
        await _db.auth.signOut();
      } catch (_) {}
      return const LoginOutcome(
        success: false,
        error: 'Could not verify your session. Please try again.',
      );
    }
  }

  /// Keeps the session alive and returns the authoritative balance.
  ///
  /// Returns null on a transport error so the caller can tell "no answer" from
  /// a definitive refusal.
  Future<Map<String, dynamic>?> heartbeat(String sessionToken) async {
    try {
      final res = await _db.rpc(Rpc.sessionHeartbeat, params: {
        RpcParam.sessionToken: sessionToken,
      });
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('ApiService.heartbeat: $e');
      return null;
    }
  }

  /// Releases the single-device session, then signs out of Supabase.
  ///
  /// Order matters: session_logout needs a valid auth.uid(), so it must run
  /// before signOut. v1 also never called signOut at all, leaving the SDK
  /// holding a live session after "logout".
  Future<void> logout() async {
    try {
      await _db.rpc(Rpc.sessionLogout);
    } catch (e) {
      debugPrint('ApiService.logout session_logout: $e');
    }
    try {
      await _db.auth.signOut();
    } catch (e) {
      debugPrint('ApiService.logout signOut: $e');
    }
  }

  /// The player's own profile row. RLS restricts this to their own record.
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      final rows = await _db
          .from(Tbl.profiles)
          .select('id, username, coin_balance, ledger_version, is_active')
          .eq('id', userId)
          .limit(1);
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (e) {
      debugPrint('ApiService.fetchProfile: $e');
    }
    return null;
  }

  /// Changes the player's password after re-verifying the current one.
  Future<bool> changePassword({
    required String username,
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = currentPassword.trim();
    final next = newPassword.trim();

    if (current.isEmpty) throw 'Please enter your current password';
    if (next.isEmpty) throw 'Please enter a new password';
    if (next.length < 6) throw 'New password must be at least 6 characters';
    if (current == next) throw 'New password must be different from current password';

    // Re-authenticate to prove the current password. Supabase has no
    // "verify password" call, so a sign-in is the check.
    try {
      await _db.auth.signInWithPassword(email: emailFor(username), password: current);
    } on AuthException {
      throw 'Current password is incorrect';
    } catch (_) {
      throw 'Could not verify your current password. Please try again.';
    }

    try {
      await _db.auth.updateUser(UserAttributes(password: next));
      return true;
    } catch (e) {
      debugPrint('ApiService.changePassword: $e');
      throw 'Could not update your password. Please try again.';
    }
  }
}
