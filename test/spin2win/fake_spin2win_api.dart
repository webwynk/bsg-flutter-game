// A scripted stand-in for the database, for testing Spin2Win logic offline.
//
// Later steps (the betting board, the countdown, the reveal) depend only on
// [Spin2WinApi]; this fake lets them be tested, including a bet rejected as
// "round closed", without a network or a database.

import 'package:best_smart_game/models/spin2win_models.dart';
import 'package:best_smart_game/services/spin2win_api_service.dart';

class FakeSpin2WinApi implements Spin2WinApi {
  /// Answers handed out, in order, by [getCurrentRound]; the last one repeats.
  final List<Spin2WinRoundState?> rounds;

  /// Answers handed out, in order, by [placeBet]; the last one repeats.
  final List<Spin2WinPlaceBetResult> betResults;

  Spin2WinMyResult? myResult;
  List<Spin2WinRecentRound> recent;

  FakeSpin2WinApi({
    this.rounds = const [],
    this.betResults = const [],
    this.myResult,
    this.recent = const [],
  });

  /// Every call in order, as text such as `placeBet(abc, n7:50)`.
  final List<String> calls = [];

  int _roundIndex = 0;
  int _betIndex = 0;

  @override
  Spin2WinError? lastRoundError;

  @override
  Future<Spin2WinRoundState?> getCurrentRound() async {
    calls.add('getCurrentRound()');
    if (rounds.isEmpty) {
      lastRoundError = Spin2WinError.offline;
      return null;
    }
    final round = rounds[_roundIndex < rounds.length ? _roundIndex++ : rounds.length - 1];
    lastRoundError = round == null ? Spin2WinError.offline : null;
    return round;
  }

  @override
  Future<Spin2WinPlaceBetResult> placeBet({
    required String roundId,
    required Map<int, int> bets,
  }) async {
    final numbers = bets.entries.map((e) => '${spin2WinKey(e.key)}:${e.value}').join(',');
    calls.add('placeBet($roundId, $numbers)');
    if (betResults.isEmpty) {
      return const Spin2WinPlaceBetResult.failure(Spin2WinError.offline);
    }
    return betResults[_betIndex < betResults.length ? _betIndex++ : betResults.length - 1];
  }

  @override
  Future<Spin2WinMyResult?> getMyRoundResult(String roundId) async {
    calls.add('getMyRoundResult($roundId)');
    return myResult;
  }

  @override
  Future<List<Spin2WinRecentRound>> getRecentRounds({int limit = 10}) async {
    calls.add('getRecentRounds($limit)');
    return recent;
  }
}
