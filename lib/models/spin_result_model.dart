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

  factory SpinResult.fromJson(Map<String, dynamic> json) => SpinResult(
    id:             json['id']?.toString() ?? '',
    red:            (json['red'] as num?)?.toInt() ?? 0,
    green:          (json['green'] as num?)?.toInt() ?? 0,
    black:          (json['black'] as num?)?.toInt() ?? 0,
    mode:           json['mode']?.toString() ?? 'single',
    selections:     List<String>.from(json['selections'] ?? []),
    chipValue:      (json['chip_value'] as num?)?.toInt() ?? 0,
    won:            json['won'] as bool? ?? false,
    deductedAmount: (json['deducted_amount'] as num?)?.toInt() ?? 0,
    winAmount:      (json['win_amount'] as num?)?.toInt() ?? 0,
    singleWinAmount: (json['single_win_amount'] as num?)?.toInt() ?? 0,
    doubleWinAmount: (json['double_win_amount'] as num?)?.toInt() ?? 0,
    tripleWinAmount: (json['triple_win_amount'] as num?)?.toInt() ?? 0,
    netChange:      (json['net_change'] as num?)?.toInt() ?? 0,
    createdAt:      json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'red': red,
    'green': green,
    'black': black,
    'mode': mode,
    'selections': selections,
    'chip_value': chipValue,
    'won': won,
    'deducted_amount': deductedAmount,
    'win_amount': winAmount,
    'single_win_amount': singleWinAmount,
    'double_win_amount': doubleWinAmount,
    'triple_win_amount': tripleWinAmount,
    'net_change': netChange,
    'created_at': createdAt.toIso8601String(),
  };
}

class Transaction {
  final String id;
  final int amount;
  final String type;
  final int balanceAfter;
  final String? note;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.balanceAfter,
    this.note,
    required this.createdAt,
  });

  bool get isCredit => amount > 0;

  String get typeLabel {
    switch (type) {
      case 'admin_topup':  return 'Admin Top-up';
      case 'agent_topup':  return 'Agent Top-up';
      case 'game_bet':     return 'Game Bet';
      case 'game_win':     return 'Game Win';
      default:             return type;
    }
  }

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id:           json['id']?.toString() ?? '',
    amount:       (json['amount'] as num?)?.toInt() ?? 0,
    type:         json['type']?.toString() ?? '',
    balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
    note:         json['note']?.toString(),
    createdAt:    json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );
}
