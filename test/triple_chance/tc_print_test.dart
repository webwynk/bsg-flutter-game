// Print in Triple Chance: tickets, a printed round on the provider, and the win popup.
// Built on the desktop layout test's harness.
//
// They build the real desktop layout with the real providers and check where
// the parts are (top bar, wheel, the three boards, chip tray, four buttons,
// results table, PLAY / WIN box), that the layout scales and centres in any
// window, that touches reach the boards, that the win popup and coin fountain
// follow the layout, and that the screen-size rule picks the desktop layout
// ahead of the tablet one. No images are compared; every check is a position,
// a size or a value.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
// Reached through supabase_flutter, which the app depends on; the test only
// needs its in-memory stand-in so the Supabase client can start.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:best_smart_game/models/spin_result_model.dart';
import 'package:best_smart_game/providers/auth_provider.dart';
import 'package:best_smart_game/providers/game_provider.dart';
import 'package:best_smart_game/widgets/desktop/desktop_result_overlay.dart';
import 'package:best_smart_game/print_ticket/tc_tickets.dart';


Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
  }
  await loader.load();
}


/// The real game with a few values fixed, so the table, the PLAY / WIN box and
/// the win popup can be checked without playing a round.
class _FixedGame extends GameProvider {
  final List<SpinResult> _hist;
  final SpinResult? _last;
  final int _bet;
  _FixedGame({List<SpinResult> history = const [], SpinResult? last, int bet = 0})
      : _hist = history,
        _last = last,
        _bet = bet;

  @override
  List<SpinResult> get globalHistory => _hist;
  @override
  SpinResult? get lastResult => _last;
  @override
  SpinResult? get lastWinBoxResult => _last;
  @override
  int get totalBet => _bet;
  @override
  List<TcTicket> get popupTickets => _shown;
  List<TcTicket> _shown = const [];
}

SpinResult _draw(String id, int r, int g, int b, {int win = 0}) => SpinResult(
      id: id,
      red: r,
      green: g,
      black: b,
      mode: 'global',
      selections: const [],
      chipValue: 10,
      won: win > 0,
      deductedAmount: 0,
      winAmount: win,
      tripleWinAmount: win,
      netChange: win,
      createdAt: DateTime(2026),
    );

Widget _app(Widget body, {GameProvider? game}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<GameProvider>(create: (_) => game ?? GameProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Colors.black, body: body),
      ),
    );

Future<void> _setScreen(WidgetTester tester, Size size) async {
  await tester.runAsync(() async {
    await _loadFont('Oswald', [
      'assets/fonts/Oswald-Regular.ttf',
      'assets/fonts/Oswald-Medium.ttf',
      'assets/fonts/Oswald-SemiBold.ttf',
      'assets/fonts/Oswald-Bold.ttf',
    ]);
    await _loadFont('DMSans', [
      'assets/fonts/DMSans-Regular.ttf',
      'assets/fonts/DMSans-Medium.ttf',
      'assets/fonts/DMSans-Bold.ttf',
      'assets/fonts/DMSans-ExtraBold.ttf',
      'assets/fonts/DMSans-Black.ttf',
    ]);
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // A throwaway local address and key: the providers expect the Supabase
    // client to exist; nothing here talks to a real server.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      // ignore: deprecated_member_use
      anonKey: 'test-key-not-real',
    );
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  TcTicket ticket(int no, Map<String, Map<String, int>> items, {int single = 0, int double_ = 0, int triple = 0}) => TcTicket(
        id: 'id$no',
        code: 'TC-P17-${no.toString().padLeft(4, '0')}',
        number: no,
        roundId: 'r1',
        roundNumber: 1,
        items: items,
        totalStake: items.values.expand((b) => b.values).fold(0, (a, b) => a + b),
        printStatus: 'printed',
        reprintCount: 0,
        createdAt: DateTime(2026, 11, 1),
        win: single + double_ + triple,
        singleWin: single,
        doubleWin: double_,
        tripleWin: triple,
      );

  test('a ticket reads as the server sends it, one group per board', () {
    final t = TcTicket.fromJson(const {
      'ticket_id': 't1',
      'ticket_code': 'TC-P17-0005',
      'ticket_no': 5,
      'round_id': 'r1',
      'round_number': 7,
      'items': {
        'single': {'5': 10, '9': 10, '6': 50},
        'double': {'20': 10},
        'triple': <String, int>{},
      },
      'total_stake': 80,
      'print_status': 'printed',
      'created_at': '2026-11-01T10:00:00Z',
      'single_win': 90,
      'double_win': 900,
      'triple_win': 0,
      'win': 990,
      'red': 1,
      'green': 2,
      'black': 5,
    });
    final paper = t.content('raj');
    expect(paper.gameTitle, 'TRIPLE CHANCE');
    expect(paper.groups.map((g) => g.heading), ['SINGLE', 'DOUBLE']);
    expect(paper.total, 80);
    expect(t.linesOf('single').map((l) => l.text).join(', '), '5 (10), 6 (50), 9 (10)');
    expect(t.win, 990);
  });

  testWidgets('a sold ticket clears the board, keeps PLAY, and charges nothing twice', (tester) async {
    final game = GameProvider();
    final auth = AuthProvider();
    game.board.single['5'] = 100;
    game.ticketSold(auth, roundId: 'r1', roundTotal: 100, balance: 900, ledgerVersion: 2);
    expect(game.board.isEmpty, isTrue);
    expect(game.totalBet, 100);
    game.board.single['6'] = 50;
    expect(game.totalBet, 150);
    game.leavePrint();
    expect(game.totalBet, 50);
  });

  group('the win popup', () {
    Future<void> show(WidgetTester tester, List<TcTicket> tickets) async {
      await _setScreen(tester, const Size(1920, 1080));
      final r = _draw('a', 1, 2, 3, win: 9000);
      final game = _FixedGame(last: r).._shown = tickets;
      await tester.pumpWidget(_app(const DesktopResultOverlay(), game: game));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a normal bet keeps the Single, Double, Triple line', (tester) async {
      await show(tester, const []);
      expect(find.text('Single: 0', findRichText: true), findsOneWidget);
      expect(find.byKey(const ValueKey('tc-win-tickets')), findsNothing);
    });

    testWidgets('tickets show under each winning board with its number', (tester) async {
      await show(tester, [
        ticket(1, const {'single': {'3': 100}}, single: 900),
        ticket(2, const {'double': {'23': 50}}, double_: 4500),
        ticket(3, const {'triple': {'999': 5}}),
      ]);
      expect(find.text('SINGLE  3'), findsOneWidget);
      expect(find.text('DOUBLE  23'), findsOneWidget);
      expect(find.text('TRIPLE  123'), findsNothing);
      expect(find.text('TC-P17-0001'), findsOneWidget);
      expect(find.text('4,500'), findsOneWidget);
      expect(find.text('TC-P17-0003'), findsNothing);
      expect(find.text('Round total play 155 - all tickets in History'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('many tickets stay in a set height', (tester) async {
      await show(tester, [for (var i = 1; i <= 8; i++) ticket(i, const {'single': {'3': 100}}, single: 900)]);
      expect(find.text('TC-P17-0003'), findsOneWidget);
      expect(find.text('TC-P17-0004'), findsNothing);
      expect(find.text('and 5 more tickets'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
