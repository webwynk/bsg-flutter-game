// A scripted stand-in for the database, for testing Lucky Card logic offline.
//
// Later steps (the betting board, the countdown, the reveal) depend only on
// [LuckyCardApi]; this fake lets them be tested, including a bet rejected as
// "round closed", without a network or a database.

import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/services/lucky_card_api_service.dart';

class FakeLuckyCardApi implements LuckyCardApi {
  /// Answers handed out, in order, by [getCurrentRound]; the last one repeats.
  final List<LuckyCardRoundState?> rounds;

  /// Answers handed out, in order, by [placeBet]; the last one repeats.
  final List<LuckyCardPlaceBetResult> betResults;

  LuckyCardMyResult? myResult;
  List<LuckyCardRecentRound> recent;

  FakeLuckyCardApi({
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
  LuckyCardError? lastRoundError;

  @override
  Future<LuckyCardRoundState?> getCurrentRound() async {
    calls.add('getCurrentRound()');
    if (rounds.isEmpty) {
      lastRoundError = LuckyCardError.offline;
      return null;
    }
    final round = rounds[_roundIndex < rounds.length ? _roundIndex++ : rounds.length - 1];
    lastRoundError = round == null ? LuckyCardError.offline : null;
    return round;
  }

  @override
  Future<LuckyCardPlaceBetResult> placeBet({
    required String roundId,
    required Map<LuckyCard, int> bets,
  }) async {
    final cards = bets.entries.map((e) => '${e.key.key}:${e.value}').join(',');
    calls.add('placeBet($roundId, $cards)');
    if (betResults.isEmpty) {
      return const LuckyCardPlaceBetResult.failure(LuckyCardError.offline);
    }
    return betResults[_betIndex < betResults.length ? _betIndex++ : betResults.length - 1];
  }

  @override
  Future<LuckyCardMyResult?> getMyRoundResult(String roundId) async {
    calls.add('getMyRoundResult($roundId)');
    return myResult;
  }

  @override
  Future<List<LuckyCardRecentRound>> getRecentRounds({int limit = 10}) async {
    calls.add('getRecentRounds($limit)');
    return recent;
  }
}
