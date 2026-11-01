import '../utils/round_id.dart';
import 'ticket_model.dart';

/// The three boards, in print order.
const List<String> kTcBoards = ['single', 'double', 'triple'];

/// One printed Triple Chance ticket, as the server holds it.
class TcTicket {
  final String id;
  final String code;
  final int number;
  final String roundId;
  final int roundNumber;
  final Map<String, Map<String, int>> items;
  final int totalStake;
  final String printStatus;
  final int reprintCount;
  final DateTime createdAt;
  final bool isDrawn;
  final int win;
  final int singleWin;
  final int doubleWin;
  final int tripleWin;
  final int? red;
  final int? green;
  final int? black;

  const TcTicket({
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
    this.singleWin = 0,
    this.doubleWin = 0,
    this.tripleWin = 0,
    this.red,
    this.green,
    this.black,
  });

  /// A ticket that reached paper at least once is reprinted as a COPY.
  bool get wasPrinted => printStatus == 'printed';

  factory TcTicket.fromJson(Map<String, dynamic> j) {
    final raw = Map<String, dynamic>.from(j['items'] as Map);
    Map<String, int> board(String name) => {
          for (final e in Map<String, dynamic>.from(raw[name] as Map? ?? const {}).entries) e.key: (e.value as num).toInt(),
        };
    return TcTicket(
      id: j['ticket_id'] as String,
      code: j['ticket_code'] as String,
      number: (j['ticket_no'] as num).toInt(),
      roundId: j['round_id'] as String,
      roundNumber: (j['round_number'] as num).toInt(),
      items: {for (final name in kTcBoards) name: board(name)},
      totalStake: (j['total_stake'] as num).toInt(),
      printStatus: j['print_status'] as String,
      reprintCount: (j['reprint_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      isDrawn: j['is_drawn'] == true,
      win: (j['win'] as num?)?.toInt() ?? 0,
      singleWin: (j['single_win'] as num?)?.toInt() ?? 0,
      doubleWin: (j['double_win'] as num?)?.toInt() ?? 0,
      tripleWin: (j['triple_win'] as num?)?.toInt() ?? 0,
      red: (j['red'] as num?)?.toInt(),
      green: (j['green'] as num?)?.toInt(),
      black: (j['black'] as num?)?.toInt(),
    );
  }

  /// The compact bet words, in board order, as the Tickets list shows them.
  List<TicketLine> linesOf(String boardName) {
    final board = items[boardName] ?? const {};
    final keys = board.keys.toList()..sort();
    final bets = [for (final k in keys) (k, board[k]!)];
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

  /// A board on paper: "2, 6, 700 (5) | 40, 60, 70 (500)".
  String flowOf(String boardName) {
    final board = items[boardName] ?? const {};
    final keys = board.keys.toList()..sort();
    return ticketFlow([for (final k in keys) (k, board[k]!)]);
  }

  String get betsText => [
        for (final name in kTcBoards)
          if (items[name]?.isNotEmpty ?? false)
            '${name[0].toUpperCase()} ${linesOf(name).map((l) => l.text).join(', ')}',
      ].join('  ');

  TicketContent content(String player) => TicketContent(
        gameTitle: 'TRIPLE CHANCE',
        code: code,
        player: player,
        roundNumber: roundNumber,
        roundId: GameRound.tripleChance.id(roundNumber),
        idLine: '$code | ${GameRound.tripleChance.id(roundNumber)} | ${code.split('-')[1]}',
        printedAt: createdAt,
        groups: [
          for (final name in kTcBoards)
            if (items[name]?.isNotEmpty ?? false)
              TicketGroup(heading: name.toUpperCase(), lines: linesOf(name), flow: flowOf(name)),
        ],
      );

  TcTicket marked(String status, {int? reprints}) => TcTicket(
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
        singleWin: singleWin,
        doubleWin: doubleWin,
        tripleWin: tripleWin,
        red: red,
        green: green,
        black: black,
      );
}

/// What the server answered to one Print press.
class TcTicketSold {
  final TcTicket ticket;
  final int roundTotal;
  final int coinBalance;
  final int ledgerVersion;

  const TcTicketSold(this.ticket, this.roundTotal, this.coinBalance, this.ledgerVersion);
}

/// Why the server refused a ticket.
enum TcPrintRefusal {
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
        overLimit => 'A number on this ticket is below the minimum or above the limit.',
        other => 'The ticket could not be made. No coins were taken.',
      };

  /// May be a lost reply: the same press is sent again, never a new one.
  bool get mayHaveReachedServer => this == offline;

  static TcPrintRefusal fromCode(String? code) => switch (code) {
        'P0120' || 'P0121' => closed,
        'P0157' => printOff,
        'P0158' => notActive,
        'P0112' => insufficientCoins,
        'P0113' => accountBlocked,
        'P0123' || 'P0124' => overLimit,
        _ => other,
      };
}

class TcPrintException implements Exception {
  final TcPrintRefusal reason;
  const TcPrintException(this.reason);
}

/// May this player print now.
class TcPrintState {
  final bool printOn;
  final bool activeNow;
  final bool activeNext;

  const TcPrintState({this.printOn = false, this.activeNow = false, this.activeNext = false});

  factory TcPrintState.fromJson(Map<String, dynamic> j) => TcPrintState(
        printOn: j['print_on'] == true,
        activeNow: j['active_now'] == true,
        activeNext: j['active_next'] == true,
      );
}

/// The server calls behind the Print button.
abstract class TcPrintApi {
  Future<TcPrintState> state();
  Future<TcTicketSold> printTicket({
    required String roundId,
    required Map<String, Map<String, int>> bets,
    required String requestId,
  });
  Future<List<TcTicket>> tickets({String? roundId, DateTime? since});
  Future<void> mark(String ticketId, String status, {bool reprint = false});
}
