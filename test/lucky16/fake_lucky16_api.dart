// A scripted stand-in for the database, for testing Lucky 16 Card logic offline.
//
// Later steps (the betting board, the countdown, the reveal) depend only on
// [Lucky16Api]; this fake lets them be tested, including a bet rejected as
// "round closed", without a network or a database.
//
// Copied from test/lucky_card/fake_lucky_card_api.dart; only the names changed.

import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/services/lucky16_api_service.dart';

class FakeLucky16Api implements Lucky16Api {
  /// Answers handed out, in order, by [getCurrentRound]; the last one repeats.
  final List<Lucky16RoundState?> rounds;

  /// Answers handed out, in order, by [placeBet]; the last one repeats.
  final List<Lucky16PlaceBetResult> betResults;

  Lucky16MyResult? myResult;
  List<Lucky16RecentRound> recent;

  FakeLucky16Api({
    this.rounds = const [],
    this.betResults = const [],
    this.myResult,
    this.recent = const [],
  });

  /// Every call in order, as text such as `placeBet(abc, j_hearts:50)`.
  final List<String> calls = [];

  int _roundIndex = 0;
  int _betIndex = 0;

  @override
  Lucky16Error? lastRoundError;

  @override
  Future<Lucky16RoundState?> getCurrentRound() async {
    calls.add('getCurrentRound()');
    if (rounds.isEmpty) {
      lastRoundError = Lucky16Error.offline;
      return null;
    }
    final round = rounds[_roundIndex < rounds.length ? _roundIndex++ : rounds.length - 1];
    lastRoundError = round == null ? Lucky16Error.offline : null;
    return round;
  }

  @override
  Future<Lucky16PlaceBetResult> placeBet({
    required String roundId,
    required Map<Lucky16Card, int> bets,
  }) async {
    final cards = bets.entries.map((e) => '${e.key.key}:${e.value}').join(',');
    calls.add('placeBet($roundId, $cards)');
    if (betResults.isEmpty) {
      return const Lucky16PlaceBetResult.failure(Lucky16Error.offline);
    }
    return betResults[_betIndex < betResults.length ? _betIndex++ : betResults.length - 1];
  }

  @override
  Future<Lucky16MyResult?> getMyRoundResult(String roundId) async {
    calls.add('getMyRoundResult($roundId)');
    return myResult;
  }

  @override
  Future<List<Lucky16RecentRound>> getRecentRounds({int limit = 10}) async {
    calls.add('getRecentRounds($limit)');
    return recent;
  }
}
