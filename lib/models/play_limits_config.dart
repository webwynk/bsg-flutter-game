import 'bet_model.dart'; // To get BoardType

enum BetRejectReason { none, cellMaxExceeded, insufficientBalance }

class BetRejection {
  final BetRejectReason reason;
  final BoardType? board;
  final String? cellKey;
  final int? cap;

  const BetRejection(this.reason, {this.board, this.cellKey, this.cap});
  static const ok = BetRejection(BetRejectReason.none);
}

class PlayLimits {
  final int min;
  final int max;

  PlayLimits({required this.min, required this.max});

  factory PlayLimits.fromJson(Map<String, dynamic> j) =>
      PlayLimits(min: j['min'] as int, max: j['max'] as int);
}

class PlayLimitsConfig {
  final Map<BoardType, PlayLimits> byBoard;

  PlayLimitsConfig(this.byBoard);

  /// Hardcoded safe defaults — identical to the API fallback values.
  /// Used immediately at GameProvider construction so caps are NEVER null.
  factory PlayLimitsConfig.fallback() => PlayLimitsConfig({
        BoardType.single: PlayLimits(min: 2, max: 10000),
        BoardType.double_: PlayLimits(min: 2, max: 1000),
        BoardType.triple: PlayLimits(min: 2, max: 100),
      });

  factory PlayLimitsConfig.fromJson(Map<String, dynamic> j) => PlayLimitsConfig({
        BoardType.single: PlayLimits.fromJson(j['single']),
        BoardType.double_: PlayLimits.fromJson(j['double']),
        BoardType.triple: PlayLimits.fromJson(j['triple']),
      });

  PlayLimits limitsFor(BoardType t) => byBoard[t]!;
}
