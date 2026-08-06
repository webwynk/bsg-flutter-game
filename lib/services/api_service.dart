import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';          // BUG-12: single source of truth
import '../models/spin_result_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ── AUTH ────────────────────────────────────────────────────────

  /// Tries to log in using Supabase Auth.
  Future<Map<String, dynamic>> login(String username, String password) async {
    final cleanUsername = username.trim();
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty) throw 'Please enter your username';
    if (cleanPassword.isEmpty) throw 'Please enter your password';

    final email = cleanUsername.contains('@') ? cleanUsername : '${cleanUsername.toLowerCase()}@bestsmartgame.com';

    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password'),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': cleanPassword,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>? ?? {};
        final meta = user['user_metadata'] as Map<String, dynamic>? ?? {};
        final tokenStr = data['access_token'] as String? ?? '';
        final userIdStr = user['id'] as String? ?? '';

        // Authenticate official Supabase Flutter SDK client instance
        if (tokenStr.isNotEmpty) {
          try {
            await Supabase.instance.client.auth.setSession(tokenStr);
          } catch (e) {
            debugPrint('ApiService.login setSession error: $e');
          }
        }

        // Account Status Check
        if (meta['status'] == 'Blocked') {
          throw 'Account is blocked. Please contact your Agent.';
        }

        // Single Session Active Check (Option A)
        if (userIdStr.isNotEmpty && tokenStr.isNotEmpty) {
          try {
            final sessionRes = await http.post(
              Uri.parse('$kSupabaseUrl/rest/v1/rpc/check_and_update_login_session'),
              headers: {
                'apikey': kSupabaseAnonKey,
                'Authorization': 'Bearer $tokenStr',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'p_user_id': userIdStr,
                'p_session_token': tokenStr,
              }),
            ).timeout(const Duration(seconds: 5));

            if (sessionRes.statusCode == 200) {
              final sessionData = jsonDecode(sessionRes.body);
              final allowed = sessionData is Map ? sessionData['allowed'] : null;
              if (allowed == false) {
                final errMsg = (sessionData['error'] ?? 'Account is already logged in on another device').toString();
                throw errMsg;
              }
            } else {
              throw 'Failed to establish single-device session. Please try again.';
            }
          } catch (e) {
            if (e is String) rethrow;
            throw 'Network timeout while verifying session. Please try again.';
          }
        }

        // BUG-05 FIX: Fetch live balance from profiles table (not stale auth metadata)
        int liveBalance = (meta['balance'] as num?)?.toInt() ?? 0;
        if (userIdStr.isNotEmpty && tokenStr.isNotEmpty) {
          try {
            final profileRes = await http.get(
              Uri.parse('$kSupabaseUrl/rest/v1/profiles?id=eq.$userIdStr&select=balance,is_active,username'),
              headers: {
                'apikey': kSupabaseAnonKey,
                'Authorization': 'Bearer $tokenStr',
              },
            ).timeout(const Duration(seconds: 4));
            if (profileRes.statusCode == 200) {
              final profileList = jsonDecode(profileRes.body) as List;
              if (profileList.isNotEmpty) {
                final profile = profileList.first as Map<String, dynamic>;
                if (profile['is_active'] == false) {
                  throw 'Account is blocked. Please contact your Agent.';
                }
                liveBalance = (profile['balance'] as num?)?.toInt() ?? liveBalance;
              }
            }
          } catch (e) {
            if (e is String) rethrow;
            debugPrint('ApiService.login: profiles fetch failed: $e');
          }
        }

        return {
          'token': data['access_token'],
          'user': {
            'id': user['id'],
            'username': meta['username'] ?? cleanUsername,
            'name': meta['full_name'] ?? cleanUsername,
            'agent_id': meta['agent_id'],
            'balance': liveBalance,
            'agentName': 'Agent',
            'status': meta['status'] ?? 'Active',
          },
          'sessionStartAt': DateTime.now().toUtc().toIso8601String(),
        };
      } else {
        try {
          final errBody = jsonDecode(res.body) as Map<String, dynamic>;
          final msg = errBody['error_description'] ?? errBody['msg'] ?? errBody['message'] ?? 'Wrong username or password';
          throw msg.toString();
        } catch (e) {
          if (e is String) rethrow;
          throw 'Wrong username or password';
        }
      }
    } catch (e) {
      if (e is String) rethrow;
      throw 'Connection error. Please check your network connection.';
    }
  }

  /// Sends a heartbeat request to update user's last_seen_at & verify active single session.
  Future<Map<String, dynamic>?> updateHeartbeat(String token, String userId) async {
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/rpc/update_user_heartbeat'),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'p_user_id': userId,
          'p_session_token': token,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Fetches fresh profile data (balance, username, is_active) from the live DB.
  /// Used on auto-login restore to ensure the displayed balance is up-to-date.
  Future<Map<String, dynamic>?> fetchProfile(String token, String userId) async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/profiles?id=eq.$userId&select=balance,username,is_active'),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (list.isNotEmpty) return list.first as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Clears user's active session timestamp on logout.
  Future<void> clearSessionRemote(String token, String userId) async {
    try {
      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/rpc/clear_user_session'),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'p_user_id': userId}),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// Sends a logout request to the server API.
  Future<void> logout(String token) async {
    try {
      await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/logout'),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Silent ignore on offline/timeout
    }
  }

  // ── GAME LIMITS ──────────────────────────────────────────────────
  /// BUG-07 FIX: Fetch play limits from server (get_play_limits RPC).
  /// Falls back to hardcoded defaults if server is unreachable.
  Future<Map<String, dynamic>> fetchPlayLimits() async {
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/rpc/get_play_limits'),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          return {
            'single': {
              'min': (data['single']?['min'] as num?)?.toInt() ?? 2,
              'max': (data['single']?['max'] as num?)?.toInt() ?? 10000,
            },
            'double': {
              'min': (data['double']?['min'] as num?)?.toInt() ?? 2,
              'max': (data['double']?['max'] as num?)?.toInt() ?? 1000,
            },
            'triple': {
              'min': (data['triple']?['min'] as num?)?.toInt() ?? 2,
              'max': (data['triple']?['max'] as num?)?.toInt() ?? 100,
            },
          };
        }
      }
    } catch (e) {
      debugPrint('ApiService.fetchPlayLimits: using defaults. Error: $e');
    }
    // Hardcoded safe defaults as fallback
    return {
      'single': {'min': 2, 'max': 10000},
      'double': {'min': 2, 'max': 1000},
      'triple': {'min': 2, 'max': 100},
    };
  }

  // ── USER DATA ────────────────────────────────────────────────────

  /// BUG-05 FIX: Fetches the live balance from profiles table (not stale auth metadata).
  /// Always returns the authoritative value from public.profiles.balance.
  Future<Map<String, dynamic>> getProfile(String token, {String? userId}) async {
    try {
      final endpoint = (userId != null && userId.isNotEmpty)
          ? 'profiles?id=eq.$userId&select=id,username,balance,is_active'
          : 'profiles?select=id,username,balance,is_active';
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/$endpoint'),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (list.isNotEmpty) {
          final profile = list.first as Map<String, dynamic>;
          if (profile['is_active'] == false) {
            throw 'Account is blocked.';
          }
          return {
            'id':       profile['id'],
            'username': profile['username'] ?? 'player',
            'balance':  (profile['balance'] as num?)?.toInt() ?? 0,
            'status':   profile['is_active'] == true ? 'Active' : 'Blocked',
          };
        }
      }
    } catch (e) {
      if (e is String) rethrow;
      debugPrint('ApiService.getProfile error: $e');
    }
    throw 'Failed to load profile';
  }

  // ── GAME HISTORY ─────────────────────────────────────────────────

  /// Fetches game history from server (triple_chance_bets joined with triple_chance_rounds).
  /// Returns the player's own betting history from the database.
  Future<Map<String, dynamic>> getGameHistory(
    String token, {
    String? userId,
    required int page,
    required int pageSize,
    DateTime? since,
  }) async {
    try {
      final userFilter = (userId != null && userId.isNotEmpty) ? '&user_id=eq.$userId' : '';
      final sinceFilter = (since != null) ? '&created_at=gte.${since.toUtc().toIso8601String()}' : '';
      final res = await http.get(
        Uri.parse(
          '$kSupabaseUrl/rest/v1/triple_chance_bets'
          '?select=id,round_id,total_stake,win_amount,single_win,double_win,triple_win,'
          'single_bets,double_bets,triple_bets,is_resolved,created_at,'
          'triple_chance_rounds!left(round_number,red,green,black)'
          '$userFilter'
          '$sinceFilter'
          '&order=created_at.desc'
          '&limit=$pageSize&offset=${(page - 1) * pageSize}',
        ),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Authorization': 'Bearer $token',
          'Connection': 'keep-alive',
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        final spins = list.map((e) {
          final row = e as Map<String, dynamic>;
          final round = row['triple_chance_rounds'] as Map<String, dynamic>? ?? {};

          final redNum   = (round['red'] as num?)?.toInt();
          final greenNum = (round['green'] as num?)?.toInt();
          final blackNum = (round['black'] as num?)?.toInt();

          int winAmt = (row['win_amount'] as num?)?.toInt() ?? 0;
          int singleWin = (row['single_win'] as num?)?.toInt() ?? 0;
          int doubleWin = (row['double_win'] as num?)?.toInt() ?? 0;
          int tripleWin = (row['triple_win'] as num?)?.toInt() ?? 0;

          if (redNum != null && greenNum != null && blackNum != null) {
            final sMap = (row['single_bets'] as Map<String, dynamic>?) ?? {};
            final dMap = (row['double_bets'] as Map<String, dynamic>?) ?? {};
            final tMap = (row['triple_bets'] as Map<String, dynamic>?) ?? {};

            final sKey = '$blackNum';
            final dKey = '$greenNum$blackNum';
            final tKey = '$redNum$greenNum$blackNum';

            final sBet = (sMap[sKey] as num?)?.toInt() ?? 0;
            final dBet = (dMap[dKey] as num?)?.toInt() ?? (dMap[dKey.padLeft(2, '0')] as num?)?.toInt() ?? 0;
            final tBet = (tMap[tKey] as num?)?.toInt() ?? (tMap[tKey.padLeft(3, '0')] as num?)?.toInt() ?? 0;

            singleWin = sBet * 9;
            doubleWin = dBet * 90;
            tripleWin = tBet * 900;
            winAmt = singleWin + doubleWin + tripleWin;
          }

          final stakeAmt = (row['total_stake'] as num?)?.toInt() ?? 0;
          final unifiedRoundId = (row['round_id'] as String?) ?? (row['id'] as String?) ?? '';
          return SpinResult(
            id:              unifiedRoundId,
            red:             redNum ?? 0,
            green:           greenNum ?? 0,
            black:           blackNum ?? 0,
            mode:            'multiplayer',
            selections:      const [],
            chipValue:       0,
            won:             winAmt > 0,
            deductedAmount:  stakeAmt,
            winAmount:       winAmt,
            singleWinAmount: singleWin,
            doubleWinAmount: doubleWin,
            tripleWinAmount: tripleWin,
            netChange:       winAmt - stakeAmt,
            createdAt:       DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
          );
        }).toList();

        int totalPlay = 0;
        int totalWin  = 0;
        for (final s in spins) {
          totalPlay += s.deductedAmount;
          totalWin  += s.winAmount;
        }

        return {
          'records':         spins.map((e) => e.toJson()).toList(),
          'page':            page,
          'pageSize':        pageSize,
          'totalRecords':    spins.length,
          'totalPlayAllTime': totalPlay,
          'totalWinAllTime': totalWin,
        };
      }
    } catch (e) {
      debugPrint('ApiService.getGameHistory error: $e');
    }

    return {
      'records':         [],
      'page':            page,
      'pageSize':        pageSize,
      'totalRecords':    0,
      'totalPlayAllTime': 0,
      'totalWinAllTime': 0,
    };
  }

  /// Fetches coin transactions history (deposits & withdrawals) from the server.
  Future<List<Transaction>> getTransactions(String token, {int page = 1, int pageSize = 20}) async {
    try {
      final res = await http.get(
        Uri.parse(
          '$kSupabaseUrl/rest/v1/transactions'
          '?select=id,type,amount,balance_after,created_at,game_name'
          '&type=in.(agent_topup,agent_deduct,win_payout,bet_stake)'
          '&order=created_at.desc'
          '&limit=$pageSize&offset=${(page - 1) * pageSize}',
        ),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((e) {
          final row = e as Map<String, dynamic>;
          final typeStr = row['type'] as String? ?? 'agent_topup';
          final isCredit = typeStr == 'agent_topup' || typeStr == 'win_payout';
          final rawAmt = (row['amount'] as num?)?.abs().toInt() ?? 0;
          final signedAmt = isCredit ? rawAmt : -rawAmt;
          return Transaction(
            id:           row['id']?.toString() ?? '',
            amount:       signedAmt,
            type:         typeStr,
            balanceAfter: (row['balance_after'] as num?)?.toInt() ?? 0,
            note:         isCredit ? 'Coins Added' : 'Coins Deducted',
            createdAt:    DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('ApiService.getTransactions error: $e');
    }
    return [];
  }

  /// Changes the authenticated player's password via Supabase Auth.
  Future<bool> changePassword({
    required String token,
    required String username,
    required String currentPassword,
    required String newPassword,
  }) async {
    final cleanCurrent = currentPassword.trim();
    final cleanNew = newPassword.trim();

    if (cleanCurrent.isEmpty) throw 'Please enter your current password';
    if (cleanNew.isEmpty) throw 'Please enter a new password';
    if (cleanNew.length < 6) throw 'New password must be at least 6 characters';
    if (cleanCurrent == cleanNew) throw 'New password must be different from current password';

    final email = username.contains('@') ? username : '${username.toLowerCase()}@bestsmartgame.com';

    // 1. Verify current password by attempting authentication
    try {
      final verifyRes = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password'),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': cleanCurrent,
        }),
      ).timeout(const Duration(seconds: 6));

      if (verifyRes.statusCode != 200) {
        throw 'Current password is incorrect';
      }
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to verify current password. Please try again.';
    }

    // 2. Update user password via Supabase Auth API
    try {
      final updateRes = await http.put(
        Uri.parse('$kSupabaseUrl/auth/v1/user'),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'password': cleanNew,
        }),
      ).timeout(const Duration(seconds: 8));

      if (updateRes.statusCode == 200) {
        try {
          await Supabase.instance.client.auth.updateUser(UserAttributes(password: cleanNew));
        } catch (_) {}
        return true;
      }

      final errJson = jsonDecode(updateRes.body);
      final msg = errJson['msg'] ?? errJson['error_description'] ?? errJson['message'] ?? 'Failed to update password';
      throw msg.toString();
    } catch (e) {
      if (e is String) rethrow;
      throw 'Network error while updating password. Please try again.';
    }
  }
}
