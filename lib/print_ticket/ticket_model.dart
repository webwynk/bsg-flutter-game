/// One group of lines on a paper ticket. Triple Chance has one per board
/// (SINGLE, DOUBLE, TRIPLE); Spin2Win has one (NUMBERS); the card games have one
/// with no heading.
class TicketGroup {
  final String? heading;
  final List<TicketLine> lines;

  /// The bets as printed, in place of [lines] and with no line amounts. [lines]
  /// still give the ticket's total.
  final String? flow;

  const TicketGroup({this.heading, required this.lines, this.flow});
}

/// A Triple Chance board on paper, in the order given: each chip amount once,
/// smallest first, after the numbers on it: "2, 6, 700 (5) | 40, 60, 70 (500)".
String ticketFlow(List<(String, int)> bets) {
  final byAmount = <int, List<String>>{};
  for (final (name, amount) in bets) {
    byAmount.putIfAbsent(amount, () => []).add(name);
  }
  final amounts = byAmount.keys.toList()..sort();
  return [for (final a in amounts) '${byAmount[a]!.join(', ')} (${ticketAmount(a)})'].join(' | ');
}

/// A coin amount with a comma every three digits.
String ticketAmount(int value) {
  final digits = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// A printed line: the compact bets on the left, their total on the right.
class TicketLine {
  final String text;
  final int amount;

  const TicketLine(this.text, this.amount);

  /// Builds the compact line from bets in the order given: bets next to each
  /// other with the same amount share it, as in "5, 9 (10), 6 (50)". The amount
  /// on the right is the sum of them all.
  factory TicketLine.compact(List<(String, int)> bets) {
    final parts = <String>[];
    var i = 0;
    while (i < bets.length) {
      final amount = bets[i].$2;
      final same = <String>[];
      while (i < bets.length && bets[i].$2 == amount) {
        same.add(bets[i].$1);
        i++;
      }
      parts.add('${same.join(', ')} (${ticketAmount(amount)})');
    }
    return TicketLine(parts.join(', '), bets.fold(0, (sum, bet) => sum + bet.$2));
  }
}

/// Everything printed on one ticket. Holds text only, so a PDF or an ESC/POS
/// renderer can each draw it. [copyAt] is set on a reprint.
class TicketContent {
  final String gameTitle;
  final String code;
  final String player;
  final int roundNumber;
  final DateTime printedAt;
  final DateTime? copyAt;
  final List<TicketGroup> groups;

  /// The round as printed, such as LS-17345678.
  final String? roundId;

  /// Ticket id, round id and player id on one line, in place of their own lines.
  final String? idLine;

  const TicketContent({
    required this.gameTitle,
    required this.code,
    required this.player,
    required this.roundNumber,
    required this.printedAt,
    required this.groups,
    this.copyAt,
    this.roundId,
    this.idLine,
  });

  bool get isCopy => copyAt != null;

  int get total =>
      groups.fold(0, (sum, group) => sum + group.lines.fold(0, (s, line) => s + line.amount));

  /// The same ticket marked as a reprint.
  TicketContent asCopy(DateTime at) => TicketContent(
        gameTitle: gameTitle,
        code: code,
        player: player,
        roundNumber: roundNumber,
        printedAt: printedAt,
        groups: groups,
        roundId: roundId,
        idLine: idLine,
        copyAt: at,
      );
}

/// A paper roll the ticket can be drawn for. [printableMm] is how wide the print
/// head reaches, which is narrower than the paper: the 80 mm Gobbler's driver
/// reports 72 mm (576 dots at 203 dpi), centred on the paper, and anything wider
/// is cut off on the right. 48 mm is the usual figure for 58 mm paper; it has not
/// been measured on a real 58 mm printer.
enum TicketPaper {
  mm58('58 mm', 58, 48),
  mm80('80 mm', 80, 72);

  final String label;
  final double widthMm;
  final double printableMm;

  const TicketPaper(this.label, this.widthMm, this.printableMm);
}

/// The approved sample tickets, for the printer test only. No real bets.
class SampleTickets {
  static final _time = DateTime(2026, 10, 31, 17, 42);

  static final lucky16 = TicketContent(
    gameTitle: 'LUCKY 16 CARD',
    code: 'LS-R01-0007',
    player: 'raj',
    roundNumber: 17345678,
    printedAt: _time,
    groups: [
      TicketGroup(lines: [
        TicketLine.compact(const [('Hearts A', 200)]),
        TicketLine.compact(const [('Clubs K', 35), ('Spades J', 35)]),
      ]),
    ],
  );

  static final luckyCard = TicketContent(
    gameTitle: 'LUCKY CARD',
    code: 'LC-R01-0003',
    player: 'raj',
    roundNumber: 17345679,
    printedAt: _time.add(const Duration(minutes: 2)),
    groups: [
      TicketGroup(lines: [
        TicketLine.compact(const [('Hearts J', 200)]),
        TicketLine.compact(const [('Clubs K', 50), ('Diamonds Q', 100)]),
      ]),
    ],
  );

  static final spin2win = TicketContent(
    gameTitle: 'SPIN2WIN',
    code: 'SW-R01-0002',
    player: 'raj',
    roundNumber: 17345680,
    printedAt: _time.add(const Duration(minutes: 4)),
    groups: [
      TicketGroup(heading: 'NUMBERS', lines: [
        TicketLine.compact(const [('7', 20), ('3', 20), ('0', 10)]),
      ]),
    ],
  );

  static final tripleChance = TicketContent(
    gameTitle: 'TRIPLE CHANCE',
    code: 'TC-R01-0005',
    player: 'raj',
    roundNumber: 17345681,
    printedAt: _time.add(const Duration(minutes: 6)),
    groups: [
      TicketGroup(heading: 'SINGLE', lines: [
        TicketLine.compact(const [('5', 10), ('9', 10), ('6', 50)]),
      ]),
      TicketGroup(heading: 'DOUBLE', lines: [
        TicketLine.compact(const [('20', 10), ('50', 10), ('60', 10)]),
      ]),
      TicketGroup(heading: 'TRIPLE', lines: [
        TicketLine.compact(const [('123', 5), ('045', 5)]),
      ]),
    ],
  );

  static final copy = lucky16.asCopy(_time.add(const Duration(minutes: 8)));

  /// The sample name and ticket, in the order shown in the test tool.
  static final all = <(String, TicketContent)>[
    ('Lucky 16 Card', lucky16),
    ('Lucky Card', luckyCard),
    ('Spin2Win', spin2win),
    ('Triple Chance', tripleChance),
    ('Reprint (COPY)', copy),
  ];
}
