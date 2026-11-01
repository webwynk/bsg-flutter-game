import '../utils/round_id.dart';
import 'ticket_model.dart';

/// One printed Spin2Win ticket, as the server holds it.
class Spin2WinTicket {
  final String id;
  final String code;
  final int number;
  final String roundId;
  final int roundNumber;
  final Map<int, int> items;
  final int totalStake;
  final String printStatus;
  final int reprintCount;
  final DateTime createdAt;
  final bool isDrawn;
  final int win;

  const Spin2WinTicket({
    required this.id,
    required this.code,
    required this.number,
    required this.roundId,
    required this.roundNumber,
    required this.items,
    required this.totalStake,
    required this.printStatus,
    required this.reprintCount,
    required this.createdAt,
    this.isDrawn = false,
    this.win = 0,
  });

  /// A ticket that reached paper at least once is reprinted as a COPY.
  bool get wasPrinted => printStatus == 'printed';

  factory Spin2WinTicket.fromJson(Map<String, dynamic> j) {
    final raw = Map<String, dynamic>.from(j['items'] as Map);
    return Spin2WinTicket(
      id: j['ticket_id'] as String,
      code: j['ticket_code'] as String,
      number: (j['ticket_no'] as num).toInt(),
      roundId: j['round_id'] as String,
      roundNumber: (j['round_number'] as num).toInt(),
      items: {for (final e in raw.entries) int.parse(e.key.substring(1)): (e.value as num).toInt()},
      totalStake: (j['total_stake'] as num).toInt(),
      printStatus: j['print_status'] as String,
      reprintCount: (j['reprint_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      isDrawn: j['is_drawn'] == true,
      win: (j['win'] as num?)?.toInt() ?? 0,
    );
  }

  /// The compact bet words, in number order, as the Tickets list shows them.
  List<TicketLine> get lines {
    final bets = [
      for (var n = 0; n <= 9; n++)
        if ((items[n] ?? 0) > 0) ('$n', items[n]!),
    ];
    final out = <TicketLine>[];
    var i = 0;
    while (i < bets.length) {
      final start = i;
      while (i < bets.length && bets[i].$2 == bets[start].$2) {
        i++;
      }
      out.add(TicketLine.compact(bets.sublist(start, i)));
    }
    return out;
  }

  /// The bets on paper, each with its own amount, smallest amount first, then
  /// by number: "0 (10), 3 (20), 7 (20)".
  String get flow {
    final numbers = items.keys.where((n) => items[n]! > 0).toList()
      ..sort((a, b) {
        final byAmount = items[a]!.compareTo(items[b]!);
        return byAmount != 0 ? byAmount : a.compareTo(b);
      });
    return [for (final n in numbers) '$n (${ticketAmount(items[n]!)})'].join(', ');
  }

  String get betsText => lines.map((l) => l.text).join(', ');

  TicketContent content(String player) => TicketContent(
        gameTitle: 'SPIN2WIN',
        code: code,
        player: player,
        roundNumber: roundNumber,
        roundId: GameRound.spin2win.id(roundNumber),
        idLine: '$code | ${GameRound.spin2win.id(roundNumber)} | ${code.split('-')[1]}',
        printedAt: createdAt,
        groups: [TicketGroup(heading: 'NUMBERS', lines: lines, flow: flow)],
      );

  Spin2WinTicket marked(String status, {int? reprints}) => Spin2WinTicket(
        id: id,
        code: code,
        number: number,
        roundId: roundId,
        roundNumber: roundNumber,
        items: items,
        totalStake: totalStake,
        printStatus: status,
        reprintCount: reprints ?? reprintCount,
        createdAt: createdAt,
        isDrawn: isDrawn,
        win: win,
      );
}

/// What the server answered to one Print press.
class Spin2WinTicketSold {
  final Spin2WinTicket ticket;
  final int roundTotal;
  final int coinBalance;
  final int ledgerVersion;

  const Spin2WinTicketSold(this.ticket, this.roundTotal, this.coinBalance, this.ledgerVersion);
}

/// Why the server refused a ticket.
enum Spin2WinPrintRefusal {
  offline,
  closed,
  printOff,
  notActive,
  insufficientCoins,
  accountBlocked,
  overLimit,
  other;

  String get message => switch (this) {
        offline => 'Could not reach the server. No ticket was made. Press Print again.',
        closed => 'Betting has closed. No ticket was made.',
        printOff => 'Printing is off right now. No coins were taken.',
        notActive => 'Print is not on for this account in this round.',
        insufficientCoins => 'Not enough coins for this ticket.',
        accountBlocked => 'This account is blocked.',
        overLimit => 'Each number on a ticket must be 5 to 10,000.',
        other => 'The ticket could not be made. No coins were taken.',
      };

  /// May be a lost reply: the same press is sent again, never a new one.
  bool get mayHaveReachedServer => this == offline;

  static Spin2WinPrintRefusal fromCode(String? code) => switch (code) {
        'P0120' || 'P0121' => closed,
        'P0157' => printOff,
        'P0158' => notActive,
        'P0112' => insufficientCoins,
        'P0113' => accountBlocked,
        'P0123' || 'P0124' => overLimit,
        _ => other,
      };
}

class Spin2WinPrintException implements Exception {
  final Spin2WinPrintRefusal reason;
  const Spin2WinPrintException(this.reason);
}

/// May this player print now.
class Spin2WinPrintState {
  final bool printOn;
  final bool activeNow;
  final bool activeNext;

  const Spin2WinPrintState({this.printOn = false, this.activeNow = false, this.activeNext = false});

  factory Spin2WinPrintState.fromJson(Map<String, dynamic> j) => Spin2WinPrintState(
        printOn: j['print_on'] == true,
        activeNow: j['active_now'] == true,
        activeNext: j['active_next'] == true,
      );
}

/// The server calls behind the Print button.
abstract class Spin2WinPrintApi {
  Future<Spin2WinPrintState> state();
  Future<Spin2WinTicketSold> printTicket({
    required String roundId,
    required Map<int, int> bets,
    required String requestId,
  });
  Future<List<Spin2WinTicket>> tickets({String? roundId, DateTime? since});
  Future<void> mark(String ticketId, String status, {bool reprint = false});
}
