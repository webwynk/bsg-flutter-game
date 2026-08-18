class SpinResult {
  final String id;
  final int red;
  final int green;
  final int black;
  final String mode;
  final List<String> selections;
  final int chipValue;
  final bool won;
  final int deductedAmount;
  final int winAmount;
  // Per-board win breakdown (for display on individual tab badges)
  final int singleWinAmount;
  final int doubleWinAmount;
  final int tripleWinAmount;
  final int netChange;
  final DateTime createdAt;

  const SpinResult({
    required this.id,
    required this.red,
    required this.green,
    required this.black,
    required this.mode,
    required this.selections,
    required this.chipValue,
    required this.won,
    required this.deductedAmount,
    required this.winAmount,
    this.singleWinAmount = 0,
    this.doubleWinAmount = 0,
    this.tripleWinAmount = 0,
    required this.netChange,
    required this.createdAt,
  });

  String get resultString => '$red$green$black';

  /// A human-readable label showing which boards contributed wins.
  /// If multiple boards won, they are joined with " + ".
  /// Falls back to the stored mode name if no per-board data is available.
  String get modeLabel {
    final parts = <String>[];
    if (singleWinAmount > 0) parts.add('SINGLE');
    if (doubleWinAmount > 0) parts.add('DOUBLE');
    if (tripleWinAmount > 0) parts.add('TRIPLE');
    if (parts.isEmpty) return mode.toUpperCase();
    return parts.join(' + ');
  }
}
