import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_contract.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

/// Owns the signed-in player and their coin balance.
///
/// BALANCE ORDERING (v2)
///   Every server response that carries a balance also carries
///   `ledger_version`, a counter the database bumps on each balance change.
///   Updates are applied only if their version is at least as fresh as what has
///   already been applied, so an in-flight heartbeat cannot roll back a newer
///   value.
///
///   v1 had no ordering and compensated with two global locks
///   (holdHeartbeatBalance / suspendHeartbeatPolling). Their release could be
///   skipped by an early return, which froze the displayed balance for the rest
///   of the process — audit findings F-2 and F-2b, and a direct cause of
///   "balance didn't update".
class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  DateTime? _sessionStartAt;
  bool _loading = false;
  String? _error;
  Timer? _heartbeatTimer;

  /// Set when the server ends this session (blocked, or displaced by another
  /// device). The root listener watches this to send the player back to login —
  /// v1 logged them out internally but left them on a live game screen
  /// (finding F-4).
  bool _forcedLogout = false;
  String? _forcedLogoutReason;

  int _ledgerVersion = 0;

  /// Stake sitting on the board that has not reached the database yet.
  /// Chips are deducted locally the moment they are placed, but nothing is
  /// written until place_bet runs at the close of betting, so the server's
  /// balance is higher than the displayed one until then.
  int? Function()? _uncommittedStakeGetter;

  /// Lets the heartbeat check whether a spin's result is currently being
  /// revealed, so a background check can't jump ahead of GameProvider's own
  /// staged balance reveal. Stateless -- read fresh every heartbeat tick, not
  /// a lock, so there's nothing to leak or forget to release; if it ever says
  /// "skip," the next tick 15 seconds later simply tries again.
  bool Function()? _isSpinningGetter;

  UserModel? get user => _user;
  DateTime? get sessionStartAt => _sessionStartAt;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _loading;
  String? get error => _error;
  int get coinBalance => _user?.coinBalance ?? 0;
  String get username => _user?.username ?? '';
  String get token => _user?.token ?? '';
  int get ledgerVersion => _ledgerVersion;
  bool get forcedLogout => _forcedLogout;
  String? get forcedLogoutReason => _forcedLogoutReason;

  void setUncommittedStakeGetter(int? Function()? getter) {
    _uncommittedStakeGetter = getter;
  }

  void setIsSpinningGetter(bool Function()? getter) {
    _isSpinningGetter = getter;
  }

  void clearForcedLogout() {
    _forcedLogout = false;
    _forcedLogoutReason = null;
  }

  // ── Balance updates ────────────────────────────────────────────────────────

  /// Applies a balance without touching the version. Used for purely local
  /// changes such as placing or removing a chip, which the server has not seen.
  void updateBalance(int newBalance) {
    if (_user == null) return;
    _user = _user!.copyWith(coinBalance: newBalance);
    notifyListeners();
  }

  /// Applies a server-sourced balance only if it is at least as fresh as what
  /// has already been applied. Older in-flight responses are discarded.
  void updateBalanceWithVersion(int newBalance, int version) {
    if (version >= _ledgerVersion) {
      _ledgerVersion = version;
      updateBalance(newBalance);
    }
  }

  /// Applies a settled, authoritative balance — the direct, final answer to
  /// something the app specifically asked about (place_bet's own response, or
  /// get_my_round_result once a round is confirmed settled).
  ///
  /// Issue #45 fix: only applied if `version` is at least as new as what's
  /// already stored. Without this, a delayed confirmation for an OLDER event
  /// (e.g. a big round still draining Issue #42's settlement batches) could
  /// arrive after a NEWER event already landed and silently overwrite it with
  /// stale data. Same guard updateBalanceWithVersion() already uses.
  void syncAuthoritativeBalance(int newBalance, int version) {
    if (version >= _ledgerVersion) {
      _ledgerVersion = version;
      updateBalance(newBalance);
    }
  }


  // ── Login / logout ─────────────────────────────────────────────────────────

  Future<LoginOutcome> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    final outcome = await ApiService().login(username, password);

    if (!outcome.success) {
      _error = outcome.error;
      _loading = false;
      notifyListeners();
      return outcome;
    }

    final profile = outcome.profile!;
    _user = UserModel.fromJson(profile);
    _ledgerVersion = (profile[Field.ledgerVersion] as num?)?.toInt() ?? 0;
    _sessionStartAt = DateTime.now().toUtc();
    _forcedLogout = false;
    _forcedLogoutReason = null;

    await AuthService().saveSession(_user!, _sessionStartAt!);
    _startHeartbeat();

    _loading = false;
    notifyListeners();
    return outcome;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    if (_user == null) return;

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final current = _user;
      if (current == null || current.token == null) return;

      final res = await ApiService().heartbeat(current.token!);
      if (res == null) return; // transport hiccup — keep the session

      if (res[Field.allowed] != true) {
        final reason = res[Field.reason]?.toString();
        final message = reason == ReasonCode.accountBlocked
            ? 'Your account has been blocked. Please contact your Agent.'
            : 'Your account was opened on another device.';
        await _endSession(forced: true, reason: message);
        return;
      }

      final balance = (res[Field.coinBalance] as num?)?.toInt();
      final version = (res[Field.ledgerVersion] as num?)?.toInt() ?? 0;
      if (balance == null) return;

      // A spin's result is actively being revealed -- don't let this
      // background check jump ahead of GameProvider's own staged reveal
      // timing. Harmless to skip: the next tick 15 seconds later just
      // tries again, same as if this one had never run.
      if (_isSpinningGetter?.call() == true) return;

      // Subtract chips already on the board: they are deducted locally but have
      // no counterpart in the database until betting closes.
      final uncommitted = _uncommittedStakeGetter?.call() ?? 0;
      updateBalanceWithVersion((balance - uncommitted).clamp(0, 1 << 62), version);
    });
  }

  Future<void> _endSession({required bool forced, String? reason}) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_user != null) {
      await ApiService().logout();
    }
    await AuthService().clearSession();

    _user = null;
    _sessionStartAt = null;
    _ledgerVersion = 0;
    _forcedLogout = forced;
    _forcedLogoutReason = reason;
    _error = forced ? reason : null;
    notifyListeners();
  }

  Future<void> logout() => _endSession(forced: false);

  /// Releases the single-device session slot without a full logout --
  /// called when the app has been backgrounded for a few seconds (see the
  /// lifecycle guard in main.dart), not on a deliberate player logout.
  /// Local state (saved credentials, heartbeat timer) is left running;
  /// [reclaimSessionAfterResume] handles what happens if the app comes back.
  Future<void> releaseSessionSlot() async {
    if (_user == null) return;
    await ApiService().releaseSessionSlot();
  }

  /// Called when the app resumes after [releaseSessionSlot] ran while
  /// backgrounded. Re-claims the slot exactly like a fresh login would --
  /// either silently succeeds (nobody else logged in while this device was
  /// away), or correctly force-logs-out this device if someone did, the
  /// same way a heartbeat-detected displacement already does today.
  Future<void> reclaimSessionAfterResume() async {
    final token = _user?.token;
    if (token == null) return;
    final data = await ApiService().reclaimSession(token);
    if (data == null) return; // transport hiccup -- the next heartbeat sorts it out
    if (data[Field.allowed] != true) {
      final reason = data[Field.reason]?.toString();
      final message = reason == ReasonCode.accountBlocked
          ? 'Your account has been blocked. Please contact your Agent.'
          : 'Your account was opened on another device.';
      await _endSession(forced: true, reason: message);
    }
  }

  // ── Misc ───────────────────────────────────────────────────────────────────

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
      final ok = await ApiService().changePassword(
        username: username,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _loading = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
