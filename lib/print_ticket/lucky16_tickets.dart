import '../models/lucky16_models.dart';
import '../utils/round_id.dart';
import 'ticket_model.dart';

/// One printed Lucky 16 Card ticket, as the server holds it.
class Lucky16Ticket {
  final String id;
  final String code;
  final int number;
  final String roundId;
  final int roundNumber;
  final Map<Lucky16Card, int> items;
  final int totalStake;
  final String printStatus;
  final int reprintCount;
  final DateTime createdAt;
  final bool isDrawn;
  final int win;

  const Lucky16Ticket({
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

  factory Lucky16Ticket.fromJson(Map<String, dynamic> j) {
    final raw = Map<String, dynamic>.from(j['items'] as Map);
    return Lucky16Ticket(
      id: j['ticket_id'] as String,
      code: j['ticket_code'] as String,
      number: (j['ticket_no'] as num).toInt(),
      roundId: j['round_id'] as String,
      roundNumber: (j['round_number'] as num).toInt(),
      items: {for (final e in raw.entries) Lucky16Card.fromKey(e.key): (e.value as num).toInt()},
      totalStake: (j['total_stake'] as num).toInt(),
      printStatus: j['print_status'] as String,
      reprintCount: (j['reprint_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      isDrawn: j['is_drawn'] == true,
      win: (j['win'] as num?)?.toInt() ?? 0,
    );
  }

  /// The compact bet words, in board order, as the Tickets list shows them.
  List<TicketLine> get lines {
    final bets = [
      for (final card in Lucky16Card.all)
        if ((items[card] ?? 0) > 0) ('${card.suit.label} ${card.rank.dbValue}', items[card]!),
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

  /// The bets on paper, each with its own amount: smallest amount first, then
  /// spades, hearts, diamonds, clubs, then rank: "Spades J (35), Hearts A (200)".
  /// Wraps by itself.
  String get flow {
    const suits = [Lucky16Suit.spades, Lucky16Suit.hearts, Lucky16Suit.diamonds, Lucky16Suit.clubs];
    final cards = items.keys.toList()
      ..sort((a, b) {
        final byAmount = items[a]!.compareTo(items[b]!);
        if (byAmount != 0) return byAmount;
        final bySuit = suits.indexOf(a.suit).compareTo(suits.indexOf(b.suit));
        return bySuit != 0 ? bySuit : a.rank.index.compareTo(b.rank.index);
      });
    return [
      for (final card in cards)
        if (items[card]! > 0) '${card.suit.label} ${card.rank.dbValue} (${ticketAmount(items[card]!)})',
    ].join(', ');
  }

  String get betsText => lines.map((l) => l.text).join(', ');

  TicketContent content(String player) => TicketContent(
        gameTitle: 'LUCKY 16 CARD',
        code: code,
        player: player,
        roundNumber: roundNumber,
        roundId: GameRound.lucky16.id(roundNumber),
        idLine: '$code | ${GameRound.lucky16.id(roundNumber)} | ${code.split('-')[1]}',
        printedAt: createdAt,
        groups: [TicketGroup(lines: lines, flow: flow)],
      );

  Lucky16Ticket marked(String status, {int? reprints}) => Lucky16Ticket(
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
class Lucky16TicketSold {
  final Lucky16Ticket ticket;
  final int roundTotal;
  final int coinBalance;
  final int ledgerVersion;

  const Lucky16TicketSold(this.ticket, this.roundTotal, this.coinBalance, this.ledgerVersion);
}

/// Why the server refused a ticket.
enum Lucky16PrintRefusal {
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
        overLimit => 'Each card on a ticket must be 5 to 10,000.',
        other => 'The ticket could not be made. No coins were taken.',
      };

  /// May be a lost reply: the same press is sent again, never a new one.
  bool get mayHaveReachedServer => this == offline;

  static Lucky16PrintRefusal fromCode(String? code) => switch (code) {
        'P0120' || 'P0121' => closed,
        'P0157' => printOff,
        'P0158' => notActive,
        'P0112' => insufficientCoins,
        'P0113' => accountBlocked,
        'P0123' || 'P0124' => overLimit,
        _ => other,
      };
}

class Lucky16PrintException implements Exception {
  final Lucky16PrintRefusal reason;
  const Lucky16PrintException(this.reason);
}

/// May this player print now.
class Lucky16PrintState {
  final bool printOn;
  final bool activeNow;
  final bool activeNext;

  const Lucky16PrintState({this.printOn = false, this.activeNow = false, this.activeNext = false});

  factory Lucky16PrintState.fromJson(Map<String, dynamic> j) => Lucky16PrintState(
        printOn: j['print_on'] == true,
        activeNow: j['active_now'] == true,
        activeNext: j['active_next'] == true,
      );
}

/// The server calls behind the Print button.
abstract class Lucky16PrintApi {
  Future<Lucky16PrintState> state();
  Future<Lucky16TicketSold> printTicket({
    required String roundId,
    required Map<Lucky16Card, int> bets,
    required String requestId,
  });
  Future<List<Lucky16Ticket>> tickets({String? roundId, DateTime? since});
  Future<void> mark(String ticketId, String status, {bool reprint = false});
}
