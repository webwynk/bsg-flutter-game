/// Chip denominations available in the tray.
enum ChipValue { two, five, ten, fifty, hundred }

extension ChipValueX on ChipValue {
  int get amount => switch (this) {
        ChipValue.two     => 2,
        ChipValue.five    => 5,
        ChipValue.ten     => 10,
        ChipValue.fifty   => 50,
        ChipValue.hundred => 100,
      };

  /// Attempt to construct a [ChipValue] from its integer denomination.
  /// Returns null if [v] does not match any known chip.
  static ChipValue? fromAmount(int v) {
    for (final c in ChipValue.values) {
      if (c.amount == v) return c;
    }
    return null;
  }
}

/// Which board the bet was placed on.
enum BoardType { single, double_, triple }

/// Records a single chip-placement action (used for REMOVE / undo).
class BetAction {
  final BoardType board;
  final String cellKey; // e.g. "0", "12", "033"
  final int amount;     // chip value at time of placement

  const BetAction({
    required this.board,
    required this.cellKey,
    required this.amount,
  });
}

/// Holds the current staked amounts across all three boards.
class BetBoardState {
  /// SINGLE board: "0".."9" → staked amount
  final Map<String, int> single = {};

  /// DOUBLE board: "00".."99" → staked amount
  final Map<String, int> double_ = {};

  /// TRIPLE board: "000".."999" → staked amount
  final Map<String, int> triple = {};

  Map<String, int> boardFor(BoardType t) => switch (t) {
        BoardType.single  => single,
        BoardType.double_ => double_,
        BoardType.triple  => triple,
      };

  /// Sum of all stakes across every board.
  int get total =>
      single.values.fold<int>(0, (a, b) => a + b) +
      double_.values.fold<int>(0, (a, b) => a + b) +
      triple.values.fold<int>(0, (a, b) => a + b);

  int get singleTotal => single.values.fold<int>(0, (a, b) => a + b);
  int get doubleTotal => double_.values.fold<int>(0, (a, b) => a + b);
  int get tripleTotal => triple.values.fold<int>(0, (a, b) => a + b);

  bool get isEmpty =>
      single.isEmpty && double_.isEmpty && triple.isEmpty;

  void clearAll() {
    single.clear();
    double_.clear();
    triple.clear();
  }
}

