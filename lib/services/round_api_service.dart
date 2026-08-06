import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants.dart'; // BUG-12: single source of truth
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents the current global round state received from the server.
class GlobalRoundState {
  final String roundId;
  final int roundNumber;
  final String status; // 'betting' | 'spinning' | 'complete'
  final DateTime scheduledAt;
  final int secondsRemaining;
  final int? red;
  final int? green;
  final int? black;

  const GlobalRoundState({
    required this.roundId,
    required this.roundNumber,
    required this.status,
    required this.scheduledAt,
    required this.secondsRemaining,
    this.red,
    this.green,
    this.black,
  });

  bool get isComplete => status == 'complete';
  bool get isBetting => status == 'betting';
  bool get isSpinning => status == 'spinning';

  factory GlobalRoundState.fromJson(Map<String, dynamic> json) {
    return GlobalRoundState(
      roundId:          json['round_id'] as String,
      roundNumber:      json['round_number'] as int,
      status:           json['status'] as String,
      scheduledAt:      DateTime.parse(json['scheduled_at'] as String),
      secondsRemaining: json['seconds_remaining'] as int,
      red:              json['red'] as int?,
      green:            json['green'] as int?,
      black:            json['black'] as int?,
    );
  }
}

/// Result of submitting bets to the server for a round.
class SubmitBetResult {
  final bool success;
  final int? balanceAfter;
  final String? error;
  /// M-5: `profiles.ledger_version` after the stake was deducted. Lets the
  /// client discard any heartbeat that was issued before this write.
  final int? ledgerVersion;

  const SubmitBetResult({
    required this.success,
    this.balanceAfter,
    this.error,
    this.ledgerVersion,
  });
}

/// Server-confirmed result for a player's round bet.
class PlayerRoundResult {
  final bool placedBet;
  final int winAmount;
  final int singleWin;
  final int doubleWin;
  final int tripleWin;
  final int totalStake;
  final bool isResolved;
  final int balance;
  /// M-5: `profiles.ledger_version` read after settlement.
  final int ledgerVersion;

  const PlayerRoundResult({
    required this.placedBet,
    required this.winAmount,
    required this.singleWin,
    required this.doubleWin,
    required this.tripleWin,
    required this.totalStake,
    required this.isResolved,
    required this.balance,
    this.ledgerVersion = 0,
  });

  factory PlayerRoundResult.fromJson(Map<String, dynamic> json) {
    return PlayerRoundResult(
      placedBet:  json['placed_bet'] as bool? ?? false,
      winAmount:  (json['win_amount'] as num?)?.toInt() ?? 0,
      singleWin:  (json['single_win'] as num?)?.toInt() ?? 0,
      doubleWin:  (json['double_win'] as num?)?.toInt() ?? 0,
      tripleWin:  (json['triple_win'] as num?)?.toInt() ?? 0,
      totalStake: (json['total_stake'] as num?)?.toInt() ?? 0,
      isResolved: json['is_resolved'] as bool? ?? false,
      balance:    (json['balance'] as num?)?.toInt() ?? 0,
      ledgerVersion: (json['ledger_version'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Service that communicates with the Supabase backend for global game rounds.
class RoundApiService {
  static final RoundApiService _instance = RoundApiService._internal();
  factory RoundApiService() => _instance;
  RoundApiService._internal();

  Map<String, String> get _headers => {
    'apikey': kSupabaseAnonKey,
    'Authorization': 'Bearer $kSupabaseAnonKey',
    'Content-Type': 'application/json',
    'Connection': 'keep-alive',
  };

  Map<String, String> _authHeaders(String token) => {
    'apikey': kSupabaseAnonKey,
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Connection': 'keep-alive',
  };

  /// M-3 FIX: single mapping from a `submit_round_bet` failure to a sentinel the
  /// UI can act on. Previously P0007 (below min) and P0008 (exceeds max) had no
  /// mapping at all, and the insufficient-funds branch matched on the string
  /// 'Insufficient balance' while the RPC actually raises 'INSUFFICIENT_COINS'
  /// — so that branch never fired either.
  ///
  /// Codes come from submit_round_bet:
  ///   P0001 INSUFFICIENT_COINS · P0002 round not found · P0003 window closed
  ///   P0004 player not found   · P0006 unauthenticated · P0007 below min
  ///   P0008 exceeds max        · P0009 round resolved  · P0010 bet settled
  static String? _mapSubmitError(String raw) {
    if (raw.contains('P0001') || raw.contains('INSUFFICIENT_COINS')) {
      return 'INSUFFICIENT_COINS';
    }
    if (raw.contains('P0007') || raw.contains('Below min')) return 'BELOW_MIN';
    if (raw.contains('P0008') || raw.contains('Exceeds max')) return 'EXCEEDS_MAX';
    if (raw.contains('P0009') || raw.contains('Round already resolved') ||
        raw.contains('P0010') || raw.contains('Bet already settled') ||
        raw.contains('P0003') || raw.contains('Betting window closed')) {
      return 'ROUND_CLOSED';
    }
    if (raw.contains('P0006') || raw.contains('Unauthenticated')) {
      return 'UNAUTHENTICATED';
    }
    if (raw.contains('P0002') || raw.contains('P0004')) return 'ROUND_CLOSED';
    return null;
  }

  /// Executes an HTTP POST with automatic retries on transient network failures.
  Future<http.Response> _postWithRetry(
    Uri url, {
    required Map<String, String> headers,
    Object? body,
    Duration timeout = const Duration(seconds: 5),
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final res = await http.post(url, headers: headers, body: body).timeout(timeout);
        return res;
      } catch (e) {
        if (attempt == maxRetries) rethrow;
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    throw Exception('HTTP retries exhausted');
  }

  /// Fetches the current active round from the server.
  Future<GlobalRoundState?> getCurrentRound() async {
    try {
      final res = await _postWithRetry(
        Uri.parse('$kSupabaseUrl/rest/v1/rpc/get_current_round'),
        headers: _headers,
        timeout: const Duration(seconds: 5),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data.containsKey('error')) {
          debugPrint('RoundApiService: no active round: ${data['error']}');
          return null;
        }
        return GlobalRoundState.fromJson(data as Map<String, dynamic>);
      }
      debugPrint('RoundApiService.getCurrentRound: HTTP ${res.statusCode} — ${res.body}');
    } catch (e) {
      debugPrint('RoundApiService.getCurrentRound: offline or error: $e');
    }
    return null;
  }

  /// Submits the player's bets for the current round.
  Future<SubmitBetResult> submitBet({
    required String roundId,
    required Map<String, int> singleBets,
    required Map<String, int> doubleBets,
    required Map<String, int> tripleBets,
    required int totalStake,
    required String token,
  }) async {
    // 1. Ensure active Supabase Auth Session
    if (token.isNotEmpty) {
      try {
        if (Supabase.instance.client.auth.currentSession == null) {
          await Supabase.instance.client.auth.setSession(token);
        }
      } catch (_) {}
    }

    // 2. Primary Attempt: Official Supabase Flutter SDK
    try {
      final res = await Supabase.instance.client.rpc(
        'submit_round_bet',
        params: {
          'p_round_id':    roundId,
          'p_single_bets': singleBets,
          'p_double_bets': doubleBets,
          'p_triple_bets': tripleBets,
          'p_total_stake': totalStake,
        },
      ).timeout(const Duration(seconds: 6));

      if (res is Map<String, dynamic>) {
        return SubmitBetResult(
          success:       res['success'] as bool? ?? true,
          balanceAfter:  (res['balance_after'] as num?)?.toInt(),
          ledgerVersion: (res['ledger_version'] as num?)?.toInt(),
        );
      }
    } catch (e) {
      final mapped = _mapSubmitError(e.toString());
      if (mapped != null) {
        debugPrint('RoundApiService.submitBet rejected by server: $mapped');
        return SubmitBetResult(success: false, error: mapped);
      }
      debugPrint('RoundApiService.submitBet via Supabase SDK error: $e');
    }

    // 2. Fallback Attempt: Direct Raw HTTP with Retry
    try {
      final res = await _postWithRetry(
        Uri.parse('$kSupabaseUrl/rest/v1/rpc/submit_round_bet'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'p_round_id':    roundId,
          'p_single_bets': singleBets,
          'p_double_bets': doubleBets,
          'p_triple_bets': tripleBets,
          'p_total_stake': totalStake,
        }),
        timeout: const Duration(seconds: 6),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return SubmitBetResult(
          success:       data['success'] as bool? ?? true,
          balanceAfter:  (data['balance_after'] as num?)?.toInt(),
          ledgerVersion: (data['ledger_version'] as num?)?.toInt(),
        );
      }

      try {
        final err = jsonDecode(res.body);
        final msg = err['message'] ?? err['hint'] ?? 'Server error';
        final code = err['code'] ?? '';
        final mapped = _mapSubmitError('$code $msg');
        if (mapped != null) {
          return SubmitBetResult(success: false, error: mapped);
        }
        return SubmitBetResult(success: false, error: msg.toString());
      } catch (_) {}

      return SubmitBetResult(success: false, error: 'HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('RoundApiService.submitBet error: $e');
      return SubmitBetResult(success: false, error: 'OFFLINE');
    }
  }

  /// BUG-11 FIX: Fetches server-resolved win amount and updated profile balance for a round.
  Future<PlayerRoundResult?> getMyRoundResult({
    required String roundId,
    required String token,
  }) async {
    // 1. Primary Attempt: Official Supabase Flutter SDK
    try {
      final res = await Supabase.instance.client.rpc(
        // M-5: _v2 wraps get_my_round_result and adds ledger_version, so the
        // settled balance can be applied with a version the client can anchor
        // to. The inner function (which performs settlement) is untouched.
        'get_my_round_result_v2',
        params: {'p_round_id': roundId},
      ).timeout(const Duration(seconds: 5));

      if (res is Map<String, dynamic>) {
        return PlayerRoundResult.fromJson(res);
      }
    } catch (e) {
      debugPrint('RoundApiService.getMyRoundResult via Supabase SDK error: $e');
    }

    // 2. Fallback Attempt: Direct Raw HTTP with Retry
    try {
      final res = await _postWithRetry(
        Uri.parse('$kSupabaseUrl/rest/v1/rpc/get_my_round_result_v2'),
        headers: _authHeaders(token),
        body: jsonEncode({'p_round_id': roundId}),
        timeout: const Duration(seconds: 5),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return PlayerRoundResult.fromJson(data);
      }
    } catch (e) {
      debugPrint('RoundApiService.getMyRoundResult fallback error: $e');
    }
    return null;
  }

  /// Polls the server for the current round state.
  Future<GlobalRoundState?> pollRoundResult(String roundId) async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/triple_chance_rounds?id=eq.$roundId&select=*'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (list.isEmpty) return null;
        final row = list.first as Map<String, dynamic>;
        final scheduledAt = DateTime.parse(row['scheduled_at'] as String);
        final secsRemaining =
            scheduledAt.difference(DateTime.now()).inSeconds.clamp(0, 60);
        return GlobalRoundState(
          roundId:          row['id'] as String,
          roundNumber:      (row['round_number'] as int?) ?? 0,
          status:           row['status'] as String,
          scheduledAt:      scheduledAt,
          secondsRemaining: secsRemaining,
          red:              row['red'] as int?,
          green:            row['green'] as int?,
          black:            row['black'] as int?,
        );
      }
    } catch (e) {
      debugPrint('RoundApiService.pollRoundResult error: $e');
    }
    return null;
  }

  /// Fetches recent global round results for the History Grid.
  Future<List<Map<String, dynamic>>> getRecentRounds({int limit = 10}) async {
    try {
      final res = await _postWithRetry(
        Uri.parse('$kSupabaseUrl/rest/v1/rpc/get_recent_rounds'),
        headers: _headers,
        body: jsonEncode({'p_limit': limit}),
        timeout: const Duration(seconds: 5),
      );

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      // Fallback: Query triple_chance_rounds REST endpoint directly if RPC fails
      final fallbackRes = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/triple_chance_rounds?status=eq.complete&order=round_number.desc&limit=$limit'),
        headers: {
          ..._headers,
          'Range-Unit': 'items',
          'Range': '0-999999',
        },
      ).timeout(const Duration(seconds: 5));

      if (fallbackRes.statusCode == 200) {
        final list = jsonDecode(fallbackRes.body) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('RoundApiService.getRecentRounds error: $e');
    }
    return [];
  }
}
