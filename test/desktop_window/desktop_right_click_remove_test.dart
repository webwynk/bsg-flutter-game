// End-to-end widget & provider verification for Windows desktop right-click
// chip removal across all four games (Triple Chance, Spin2Win, Lucky Card,
// Lucky 16), plus regression guards confirming Android / tablet / phone keep
// their REMOVE button and ignore secondary taps.

import 'dart:io';

// Reached through audioplayers, which the app depends on.
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:best_smart_game/models/bet_model.dart';
import 'package:best_smart_game/models/lucky16_board.dart';
import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/models/lucky_card_board.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/models/spin2win_board.dart';
import 'package:best_smart_game/models/user_model.dart';
import 'package:best_smart_game/providers/auth_provider.dart';
import 'package:best_smart_game/providers/game_provider.dart';
import 'package:best_smart_game/screens/lucky16_screen.dart';
import 'package:best_smart_game/screens/lucky_card_screen.dart';
import 'package:best_smart_game/screens/spin2win_screen.dart';
import 'package:best_smart_game/services/lucky16_sound.dart';
import 'package:best_smart_game/services/lucky_card_sound.dart';
import 'package:best_smart_game/services/round_sync_service.dart';
import 'package:best_smart_game/services/spin2win_sound.dart';
import 'package:best_smart_game/widgets/desktop/desktop_doubles_board.dart';
import 'package:best_smart_game/widgets/desktop/desktop_game_layout.dart';
import 'package:best_smart_game/widgets/desktop/desktop_singles_board.dart';
import 'package:best_smart_game/widgets/desktop/desktop_triples_board.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_layout.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_layout.dart';
import 'package:best_smart_game/widgets/panels/grid_cells.dart';
import 'package:best_smart_game/widgets/tablet/tablet_game_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
// Reached through supabase_flutter, which the app depends on; used in-memory only.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../lucky16/provider_rig.dart' as l16_rig;
import '../lucky16/ui/ui_harness.dart' as l16_ui;
import '../lucky_card/provider_rig.dart' as lc_rig;
import '../lucky_card/ui/ui_harness.dart' as lc_ui;
import '../spin2win/fake_alerts.dart';
import '../spin2win/fake_sound.dart';
import '../spin2win/provider_rig.dart' as s2w_rig;
import '../triple_chance/sim_tc_server.dart';

const Size _kDesktop1920 = Size(1920, 1080);
const Size _kDesktop1280 = Size(1280, 720);
const Size _kTablet1024 = Size(1024, 768);
const Size _kPhone844 = Size(844, 390);

final Uint8List _kTransparentPixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class _SilentAudio implements AudioplayersPlatformInterface {
  @override
  Stream<AudioEvent> getEventStream(String playerId) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _SilentGlobalAudio implements GlobalAudioplayersPlatformInterface {
  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _SilentLcSound implements LuckyCardSoundOutput {
  @override
  void buttonClick() {}
  @override
  void chipClick() {}
  @override
  void numberSelect() {}
  @override
  void ding() {}
  @override
  void wheelSpin() {}
  @override
  void notification() {}
  @override
  void win() {}
  @override
  void coin() {}
  @override
  void noMoreBets() {}
  @override
  void setInGame(bool inGame) {}
  @override
  void stopAll() {}
}

class _SilentL16Sound implements Lucky16SoundOutput {
  @override
  void buttonClick() {}
  @override
  void chipClick() {}
  @override
  void numberSelect() {}
  @override
  void ding() {}
  @override
  void wheelSpin() {}
  @override
  void notification() {}
  @override
  void win() {}
  @override
  void coin() {}
  @override
  void noMoreBets() {}
  @override
  void setInGame(bool inGame) {}
  @override
  void stopAll() {}
}

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(Future.value(ByteData.view(File(file).readAsBytesSync().buffer)));
  }
  await loader.load();
}

void _usePlatform(TargetPlatform? platform) {
  debugDefaultTargetPlatformOverride = platform;
}

void _testWithPlatform(
  String description,
  Future<void> Function(WidgetTester tester, void Function(VoidCallback) onFinally) body,
) {
  testWidgets(description, (tester) async {
    final cleanups = <VoidCallback>[];
    try {
      await body(tester, cleanups.add);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      for (final cleanup in cleanups.reversed) {
        cleanup();
      }
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _rightClick(WidgetTester tester, Finder target) async {
  await tester.tap(target, buttons: kSecondaryMouseButton, warnIfMissed: false);
  await tester.pump();
}

Future<void> _leftTap(WidgetTester tester, Finder target) async {
  await tester.tap(target, warnIfMissed: false);
  await tester.pump();
}

AuthProvider _signedInAuth(int balance, void Function(VoidCallback) onFinally) {
  final auth = AuthProvider();
  auth.configureForTest(
    heartbeat: (_) async => null,
    releaseSeat: () async {},
    logout: () async {},
    signedIn: UserModel(id: 'u1', username: 'player1', coinBalance: balance, token: 't1'),
  );
  onFinally(auth.dispose);
  return auth;
}

Widget _tripleChanceApp(Widget child, GameProvider game, AuthProvider auth) => MultiProvider(
      providers: [
        ChangeNotifierProvider<GameProvider>.value(value: game),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Colors.black, body: child),
      ),
    );

void _noop() {}

void main() {
  late lc_ui.PreloadedLuckyCardArt lcArt;
  late l16_ui.PreloadedLucky16Art l16Art;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AudioplayersPlatformInterface.instance = _SilentAudio();
    GlobalAudioplayersPlatformInterface.instance = _SilentGlobalAudio();
    await Supabase.initialize(
      url: 'http://localhost:54321',
      // ignore: deprecated_member_use
      anonKey: 'test-key-not-real',
    );
    GoogleFonts.config.allowRuntimeFetching = false;
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
    await lc_ui.loadLuckyCardIcons();
    lcArt = await lc_ui.PreloadedLuckyCardArt.load();
    l16Art = await l16_ui.PreloadedLucky16Art.load();
  });

  // ── 1. TRIPLE CHANCE ───────────────────────────────────────────────────────
  group('Triple Chance right-click remove (Windows only)', () {
    _testWithPlatform('Windows desktop hides REMOVE and expands CLEAR full width; non-Windows keeps REMOVE',
        (tester, onFinally) async {
      final game = GameProvider();
      onFinally(game.dispose);
      final auth = _signedInAuth(1000, onFinally);

      // Windows desktop layout.
      _usePlatform(TargetPlatform.windows);
      _setScreen(tester, _kDesktop1280);
      await tester.pumpWidget(_tripleChanceApp(const DesktopGameLayout(onSpin: _noop), game, auth));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('REMOVE'), findsNothing);
      expect(find.text('DOUBLE UP'), findsOneWidget);
      expect(find.text('REPEAT'), findsOneWidget);
      expect(find.text('CLEAR'), findsOneWidget);

      final dblRect = tester.getRect(find.text('DOUBLE UP'));
      final repeatRect = tester.getRect(find.text('REPEAT'));
      final clearRect = tester.getRect(find.text('CLEAR'));
      expect(clearRect.center.dx, closeTo((dblRect.center.dx + repeatRect.center.dx) / 2, 1.0));

      // Non-Windows desktop size keeps REMOVE (unmount first so const subtree rebuilds for Android).
      await tester.pumpWidget(const SizedBox.shrink());
      _usePlatform(TargetPlatform.android);
      await tester.pumpWidget(_tripleChanceApp(const DesktopGameLayout(onSpin: _noop), game, auth));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('REMOVE'), findsOneWidget);

      // Tablet layout on Android keeps REMOVE.
      await tester.pumpWidget(const SizedBox.shrink());
      _setScreen(tester, _kTablet1024);
      await tester.pumpWidget(_tripleChanceApp(const TabletGameLayout(onSpin: _noop), game, auth));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('REMOVE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final printMode in [false, true]) {
      _testWithPlatform('Windows right-click removes 1 chip on Singles, Doubles/Triples cells & arrows (printMode=$printMode)',
          (tester, onFinally) async {
        // Pin RoundSyncService to an open second (countdown=50) so live wall-clock
        // cycle locks never race this test regardless of what second it runs.
        final openNow = DateTime.fromMillisecondsSinceEpoch((17419200 * 103 + 40) * 1000, isUtc: true);
        RoundSyncService().configureForTest(
          api: SimulatedTcServer(now: () => openNow),
          now: () => openNow,
        );
        _usePlatform(TargetPlatform.windows);
        _setScreen(tester, _kDesktop1280);
        final game = GameProvider()..setPrintMode(printMode);
        onFinally(game.dispose);
        final auth = _signedInAuth(5000, onFinally);

        await tester.pumpWidget(_tripleChanceApp(const DesktopGameLayout(onSpin: _noop), game, auth));
        await tester.pump(const Duration(milliseconds: 500));

        // 1) Singles cell: place 10 + 50 on first cell, then right-click removes only 50 (LIFO) & keeps 50 selected.
        final singleCell = find.descendant(of: find.byType(DesktopSinglesBoard), matching: find.byType(NumberCell)).first;
        game.selectChip(ChipValue.ten);
        await _leftTap(tester, singleCell);
        game.selectChip(ChipValue.fifty);
        await _leftTap(tester, singleCell);
        expect(game.totalBet, 60);
        expect(auth.coinBalance, 4940);
        expect(game.activeChip, ChipValue.fifty);

        await _rightClick(tester, singleCell);
        expect(game.totalBet, 10, reason: 'removes newest 50 chip, keeps 10');
        expect(auth.coinBalance, 4990);
        expect(game.activeChip, ChipValue.fifty, reason: 'active chip stays in hand after right-click');

        // Re-tap with held 50 chip works immediately without re-picking chip.
        await _leftTap(tester, singleCell);
        expect(game.totalBet, 60);
        await _rightClick(tester, singleCell);
        await _rightClick(tester, singleCell);
        expect(game.totalBet, 0);
        expect(auth.coinBalance, 5000);

        // 2) Doubles cell + RowArrowButton + ColArrowButton.
        final doublesCell = find.descendant(of: find.byType(DesktopDoublesBoard), matching: find.byType(NumberCell)).first;
        final doublesRowArrow =
            find.descendant(of: find.byType(DesktopDoublesBoard), matching: find.byType(RowArrowButton)).first;
        final doublesColArrow =
            find.descendant(of: find.byType(DesktopDoublesBoard), matching: find.byType(ColArrowButton)).first;

        game.selectChip(ChipValue.ten);
        await _leftTap(tester, doublesCell);
        expect(game.board.double_.length, 1);
        expect(game.totalBet, 10);
        await _rightClick(tester, doublesCell);
        expect(game.totalBet, 0);

        // Row arrow twice: [10, 10] per cell (200 coins); double makes [20, 20] (400 coins);
        // one right-click removes 20 from each of those 10 cells -> 200 coins remaining.
        await _leftTap(tester, doublesRowArrow);
        expect(game.board.double_.length, 10);
        expect(game.totalBet, 100);
        await _leftTap(tester, doublesRowArrow);
        expect(game.totalBet, 200);
        await _leftTap(tester, find.text('DOUBLE UP'));
        expect(game.totalBet, 400);
        await _rightClick(tester, doublesRowArrow);
        expect(game.totalBet, 200);
        await _rightClick(tester, doublesRowArrow);
        expect(game.totalBet, 0);

        // Column arrow works the same way.
        await _leftTap(tester, doublesColArrow);
        expect(game.totalBet, 100);
        await _rightClick(tester, doublesColArrow);
        expect(game.totalBet, 0);
        expect(auth.coinBalance, 5000);
        expect(game.activeChip, ChipValue.ten);

        // 3) Triples cell + RowArrowButton + ColArrowButton.
        final triplesCell = find.descendant(of: find.byType(DesktopTriplesBoard), matching: find.byType(NumberCell)).first;
        final triplesRowArrow =
            find.descendant(of: find.byType(DesktopTriplesBoard), matching: find.byType(RowArrowButton)).first;
        final triplesColArrow =
            find.descendant(of: find.byType(DesktopTriplesBoard), matching: find.byType(ColArrowButton)).first;

        await _leftTap(tester, triplesCell);
        expect(game.totalBet, 10);
        await _rightClick(tester, triplesCell);
        expect(game.totalBet, 0);

        await _leftTap(tester, triplesRowArrow);
        expect(game.totalBet, 100);
        await _rightClick(tester, triplesRowArrow);
        expect(game.totalBet, 0);

        await _leftTap(tester, triplesColArrow);
        expect(game.totalBet, 100);
        await _rightClick(tester, triplesColArrow);
        expect(game.totalBet, 0);
        expect(auth.coinBalance, 5000);
        expect(tester.takeException(), isNull);
      });
    }

    _testWithPlatform('Non-Windows secondary tap does not remove chips, and locked round ignores right-click',
        (tester, onFinally) async {
      final openNow = DateTime.fromMillisecondsSinceEpoch((17419200 * 103 + 40) * 1000, isUtc: true);
      RoundSyncService().configureForTest(
        api: SimulatedTcServer(now: () => openNow),
        now: () => openNow,
      );
      // Android desktop-sized layout ignores secondary taps even with a bet on board.
      _usePlatform(TargetPlatform.android);
      _setScreen(tester, _kDesktop1280);
      final game = GameProvider();
      onFinally(game.dispose);
      final auth = _signedInAuth(1000, onFinally);
      await tester.pumpWidget(_tripleChanceApp(const DesktopGameLayout(onSpin: _noop), game, auth));
      await tester.pump(const Duration(milliseconds: 500));

      final singleCell = find.descendant(of: find.byType(DesktopSinglesBoard), matching: find.byType(NumberCell)).first;
      game.selectChip(ChipValue.ten);
      await _leftTap(tester, singleCell);
      expect(game.totalBet, 10);
      await _rightClick(tester, singleCell);
      expect(game.totalBet, 10, reason: 'non-Windows ignores secondary click');

      await tester.pumpWidget(const SizedBox.shrink());

      // Locked countdown (<= 5): Windows UI right-click refuses removal on an existing bet.
      _usePlatform(TargetPlatform.windows);
      final world = SimWorld(tester, cycleNumber: 17419200, startInto: 82);
      final server = SimulatedTcServer(now: () => world.serverNow);
      final sync = RoundSyncService();
      sync.configureForTest(api: server, now: () => world.deviceNow, elapsed: () => world.elapsed);
      final lockedGame = GameProvider();
      onFinally(lockedGame.dispose);
      final attached = sync.attach(lockedGame, auth);
      await world.run(const Duration(seconds: 1));
      await attached;

      await tester.pumpWidget(_tripleChanceApp(const DesktopGameLayout(onSpin: _noop), lockedGame, auth));
      await tester.pump(const Duration(milliseconds: 500));
      final lockedCell = find.descendant(of: find.byType(DesktopSinglesBoard), matching: find.byType(NumberCell)).first;
      lockedGame.selectChip(ChipValue.ten);
      await _leftTap(tester, lockedCell);
      expect(lockedGame.totalBet, 10);

      await world.runUntil(86);
      await tester.pump();
      expect(lockedGame.countdown, lessThanOrEqualTo(5));
      await _rightClick(tester, lockedCell);
      expect(lockedGame.totalBet, 10, reason: 'locked round refuses Windows right-click');

      await tester.pumpWidget(const SizedBox.shrink());
      sync.detach();
      await world.run(const Duration(seconds: 12));
    });
  });

  // ── 2. SPIN2WIN ────────────────────────────────────────────────────────────
  group('Spin2Win right-click remove (Windows only)', () {
    Future<void> openSpin2Win(WidgetTester tester, s2w_rig.BetRig rig, Size size) async {
      _setScreen(tester, size);
      await tester.pumpWidget(MaterialApp(
        home: Spin2WinScreen(
          setup: Spin2WinScreenSetup(
            provider: rig.provider,
            setOrientation: false,
            precacheChips: false,
            alerts: FakeAlerts(),
            sound: Spin2WinSound(FakeSoundOutput()),
            chipImage: (_) => MemoryImage(_kTransparentPixel),
            onRefused: (_) {},
            onProblem: (_) {},
          ),
        ),
      ));
      await rig.world.run(const Duration(seconds: 1));
      await tester.pump();
    }

    Future<void> closeSpin2Win(WidgetTester tester, s2w_rig.BetRig rig) async {
      await tester.pumpWidget(const SizedBox());
      await rig.finish();
    }

    _testWithPlatform('Windows hides spin2win-remove and expands DOUBLE + CLEAR; phone & tablet keep spin2win-remove',
        (tester, _) async {
      _usePlatform(TargetPlatform.windows);
      final winRig = s2w_rig.BetRig(tester);
      await openSpin2Win(tester, winRig, _kDesktop1920);
      expect(_key('spin2win-remove'), findsNothing);
      expect(_key('spin2win-double'), findsOneWidget);
      expect(_key('spin2win-clear'), findsOneWidget);
      final winDoubleW = tester.getSize(_key('spin2win-double')).width;
      final winClearW = tester.getSize(_key('spin2win-clear')).width;
      expect(winDoubleW, closeTo(winClearW, 1.0));
      expect(tester.takeException(), isNull);
      await closeSpin2Win(tester, winRig);

      // Android tablet (1024x768) & phone (844x390) keep spin2win-remove and 3-button narrower widths.
      _usePlatform(TargetPlatform.android);
      final tabRig = s2w_rig.BetRig(tester);
      await openSpin2Win(tester, tabRig, _kTablet1024);
      expect(_key('spin2win-remove'), findsOneWidget);
      expect(_key('spin2win-double'), findsOneWidget);
      expect(_key('spin2win-clear'), findsOneWidget);
      await closeSpin2Win(tester, tabRig);

      final phoneRig = s2w_rig.BetRig(tester);
      await openSpin2Win(tester, phoneRig, _kPhone844);
      expect(_key('spin2win-remove'), findsOneWidget);
      // Right-click on Android phone with held chip does nothing.
      await _leftTap(tester, _key('spin2win-chip-10'));
      await _leftTap(tester, _key('spin2win-card-4'));
      expect(phoneRig.provider.stakeOn(4), 10);
      await _rightClick(tester, _key('spin2win-card-4'));
      expect(phoneRig.provider.stakeOn(4), 10);
      await closeSpin2Win(tester, phoneRig);
    });

    for (final printMode in [false, true]) {
      _testWithPlatform('Windows right-click removes 1 chip on card, ODD, EVEN after DOUBLE, keeps chip (printMode=$printMode)',
          (tester, _) async {
        _usePlatform(TargetPlatform.windows);
        final rig = s2w_rig.BetRig(tester, startInto: 40, startBalance: 2000);
        rig.provider.setPrintMode(printMode);
        await openSpin2Win(tester, rig, _kDesktop1920);

        // Card 4: stack [10, 100] -> right-click pops 100 then 10; chip 100 stays held.
        await _leftTap(tester, _key('spin2win-chip-10'));
        await _leftTap(tester, _key('spin2win-card-4'));
        await _leftTap(tester, _key('spin2win-chip-100'));
        await _leftTap(tester, _key('spin2win-card-4'));
        expect(rig.provider.stakeOn(4), 110);
        expect(rig.provider.activeChip, Spin2WinChip.hundred);

        await _rightClick(tester, _key('spin2win-card-4'));
        expect(rig.provider.stakeOn(4), 10);
        expect(rig.provider.balance, 1990);
        expect(rig.provider.activeChip, Spin2WinChip.hundred);

        await _rightClick(tester, _key('spin2win-card-4'));
        expect(rig.provider.stakeOn(4), 0);
        expect(rig.provider.balance, 2000);

        // ODD twice + DOUBLE -> each odd card has [20, 20] -> one right-click removes 20 from each.
        await _leftTap(tester, _key('spin2win-chip-10'));
        await _leftTap(tester, _key('spin2win-odd'));
        await _leftTap(tester, _key('spin2win-odd'));
        await _leftTap(tester, _key('spin2win-double'));
        for (final n in [1, 3, 5, 7, 9]) {
          expect(rig.provider.stakeOn(n), 40);
        }
        await _rightClick(tester, _key('spin2win-odd'));
        for (final n in [1, 3, 5, 7, 9]) {
          expect(rig.provider.stakeOn(n), 20);
        }
        expect(rig.provider.activeChip, Spin2WinChip.ten);
        await _rightClick(tester, _key('spin2win-odd'));
        expect(rig.provider.isBoardEmpty, isTrue);

        // EVEN -> right-click removes 1 chip from each even card (0,2,4,6,8).
        await _leftTap(tester, _key('spin2win-even'));
        expect(rig.provider.total, 50);
        await _rightClick(tester, _key('spin2win-even'));
        expect(rig.provider.isBoardEmpty, isTrue);
        expect(rig.provider.balance, 2000);

        await closeSpin2Win(tester, rig);
      });
    }

    _testWithPlatform('Spin2Win refuses Windows right-click once round locks at 05s', (tester, _) async {
      _usePlatform(TargetPlatform.windows);
      final rig = s2w_rig.BetRig(tester, startInto: 80);
      await openSpin2Win(tester, rig, _kDesktop1920);
      await _leftTap(tester, _key('spin2win-chip-10'));
      await _leftTap(tester, _key('spin2win-card-5'));
      await rig.world.runUntil(85.5);
      await tester.pump();
      expect(rig.provider.isLocked, isTrue);
      await _rightClick(tester, _key('spin2win-card-5'));
      expect(rig.provider.stakeOn(5), 10);
      await closeSpin2Win(tester, rig);
    });
  });

  // ── 3. LUCKY CARD ──────────────────────────────────────────────────────────
  group('Lucky Card right-click remove (Windows only)', () {
    Future<void> openLuckyCard(
      WidgetTester tester,
      lc_rig.BetRig rig,
      Size size, {
      required bool desktopPlatform,
    }) async {
      _setScreen(tester, size);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LuckyCardScreen(
          setup: LuckyCardScreenSetup(
            provider: rig.provider,
            art: lcArt,
            setOrientation: false,
            sound: LuckyCardSound(_SilentLcSound()),
            desktopPlatform: desktopPlatform,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await rig.world.run(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> closeLuckyCard(WidgetTester tester, lc_rig.BetRig rig) async {
      await tester.pumpWidget(const SizedBox());
      await rig.finish();
    }

    _testWithPlatform('Windows hides button-remove and widens 2 buttons; Android tablet & phone keep button-remove',
        (tester, _) async {
      _usePlatform(TargetPlatform.windows);
      final winRig = lc_rig.BetRig(tester);
      await openLuckyCard(tester, winRig, _kDesktop1920, desktopPlatform: true);
      final l = LuckyCardLayout.desktop(_kDesktop1920);
      expect(_key('button-remove'), findsNothing);
      expect(_key('button-doubleBet'), findsOneWidget);
      expect(_key('button-clear'), findsOneWidget);
      expect(tester.getRect(_key('button-doubleBet')).width, closeTo(l.actionButton(0, count: 2).width, 0.5));
      expect(tester.getRect(_key('button-clear')).right, closeTo(l.actionButton(1, count: 2).right, 0.5));
      expect(tester.takeException(), isNull);
      await closeLuckyCard(tester, winRig);

      // Android even on 1920x1080 desktopPlatform=true keeps button-remove.
      _usePlatform(TargetPlatform.android);
      final androidDeskRig = lc_rig.BetRig(tester);
      await openLuckyCard(tester, androidDeskRig, _kDesktop1920, desktopPlatform: true);
      expect(_key('button-remove'), findsOneWidget);
      await closeLuckyCard(tester, androidDeskRig);

      // Phone stays unchanged with button-remove and ignores secondary click.
      final phoneRig = lc_rig.BetRig(tester);
      await openLuckyCard(tester, phoneRig, _kPhone844, desktopPlatform: false);
      expect(_key('button-remove'), findsOneWidget);
      await _leftTap(tester, _key('chip-10'));
      await _leftTap(tester, _key('j_hearts'));
      expect(phoneRig.provider.stakeOn(const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts)), 10);
      await _rightClick(tester, _key('j_hearts'));
      expect(phoneRig.provider.stakeOn(const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts)), 10);
      await closeLuckyCard(tester, phoneRig);
    });

    for (final printMode in [false, true]) {
      _testWithPlatform(
          'Windows right-click removes 1 chip on card, suit, rank after DOUBLE, keeps chip (printMode=$printMode)',
          (tester, _) async {
        _usePlatform(TargetPlatform.windows);
        final rig = lc_rig.BetRig(tester, startInto: 40, startBalance: 3000);
        rig.provider.setPrintMode(printMode);
        await openLuckyCard(tester, rig, _kDesktop1920, desktopPlatform: true);

        const jHearts = LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts);

        // Card: stack [10, 100] -> right-click removes 100 then 10; chip 100 stays in hand.
        await _leftTap(tester, _key('chip-10'));
        await _leftTap(tester, _key('j_hearts'));
        await _leftTap(tester, _key('chip-100'));
        await _leftTap(tester, _key('j_hearts'));
        expect(rig.provider.stakeOn(jHearts), 110);
        await _rightClick(tester, _key('j_hearts'));
        expect(rig.provider.stakeOn(jHearts), 10);
        expect(rig.provider.balance, 2990);
        expect(rig.provider.activeChip, LuckyCardChip.hundred);
        await _rightClick(tester, _key('j_hearts'));
        expect(rig.provider.stakeOn(jHearts), 0);

        // Suit bar twice + DOUBLE: [20, 20] on J/Q/K hearts -> one right-click removes 20 from each.
        await _leftTap(tester, _key('chip-10'));
        await _leftTap(tester, _key('suit-hearts'));
        await _leftTap(tester, _key('suit-hearts'));
        await _leftTap(tester, _key('button-doubleBet'));
        for (final c in LuckyCard.ofSuit(LuckyCardSuit.hearts)) {
          expect(rig.provider.stakeOn(c), 40);
        }
        await _rightClick(tester, _key('suit-hearts'));
        for (final c in LuckyCard.ofSuit(LuckyCardSuit.hearts)) {
          expect(rig.provider.stakeOn(c), 20);
        }
        await _rightClick(tester, _key('suit-hearts'));
        expect(rig.provider.isBoardEmpty, isTrue);

        // Rank selector: Q selector places on 4 Queens -> right-click removes from all 4 Queens.
        await _leftTap(tester, _key('rank-Q'));
        expect(rig.provider.total, 40);
        await _rightClick(tester, _key('rank-Q'));
        expect(rig.provider.isBoardEmpty, isTrue);
        expect(rig.provider.balance, 3000);
        expect(rig.provider.activeChip, LuckyCardChip.ten);

        await closeLuckyCard(tester, rig);
      });
    }

    _testWithPlatform('Lucky Card locks right-click at 05s and swaps Info dialog text to RIGHT-CLICK on Windows',
        (tester, _) async {
      // Windows Info dialog + lock behavior.
      _usePlatform(TargetPlatform.windows);
      final winRig = lc_rig.BetRig(tester, startInto: 75);
      await openLuckyCard(tester, winRig, _kDesktop1920, desktopPlatform: true);
      await _leftTap(tester, _key('chip-10'));
      await _leftTap(tester, _key('j_hearts'));
      await _leftTap(tester, _key('top-info'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.descendant(of: _key('info-dialog'), matching: find.text('RIGHT-CLICK')), findsOneWidget);
      expect(find.descendant(of: _key('info-dialog'), matching: find.text('REMOVE')), findsNothing);
      await _leftTap(tester, _key('info-close'));
      await tester.pump(const Duration(milliseconds: 400));

      // Wait until betting locks (~98s in 103s cycle).
      await winRig.world.runUntil(98.5);
      await tester.pump();
      expect(winRig.provider.isLocked, isTrue);
      await _rightClick(tester, _key('j_hearts'));
      expect(winRig.provider.stakeOn(const LuckyCard(LuckyCardRank.jack, LuckyCardSuit.hearts)), 10);
      await closeLuckyCard(tester, winRig);

      // Android Info dialog still says REMOVE.
      _usePlatform(TargetPlatform.android);
      final androidRig = lc_rig.BetRig(tester, startInto: 40);
      await openLuckyCard(tester, androidRig, _kTablet1024, desktopPlatform: false);
      await _leftTap(tester, _key('top-info'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.descendant(of: _key('info-dialog'), matching: find.text('REMOVE')), findsOneWidget);
      expect(find.descendant(of: _key('info-dialog'), matching: find.text('RIGHT-CLICK')), findsNothing);
      await closeLuckyCard(tester, androidRig);
    });
  });

  // ── 4. LUCKY 16 ────────────────────────────────────────────────────────────
  group('Lucky 16 right-click remove (Windows only)', () {
    Future<void> openLucky16(
      WidgetTester tester,
      l16_rig.BetRig rig,
      Size size, {
      required bool desktopPlatform,
    }) async {
      _setScreen(tester, size);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Lucky16Screen(
          setup: Lucky16ScreenSetup(
            provider: rig.provider,
            art: l16Art,
            setOrientation: false,
            sound: Lucky16Sound(_SilentL16Sound()),
            desktopPlatform: desktopPlatform,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await rig.world.run(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> closeLucky16(WidgetTester tester, l16_rig.BetRig rig) async {
      await tester.pumpWidget(const SizedBox());
      await rig.finish();
    }

    _testWithPlatform('Windows hides button-remove and widens 2 buttons; Android tablet & phone keep button-remove',
        (tester, _) async {
      _usePlatform(TargetPlatform.windows);
      final winRig = l16_rig.BetRig(tester);
      await openLucky16(tester, winRig, _kDesktop1920, desktopPlatform: true);
      final l = Lucky16Layout.desktop(_kDesktop1920);
      expect(_key('button-remove'), findsNothing);
      expect(_key('button-doubleBet'), findsOneWidget);
      expect(_key('button-clear'), findsOneWidget);
      expect(tester.getRect(_key('button-doubleBet')).width, closeTo(l.actionButton(0, count: 2).width, 0.5));
      expect(tester.getRect(_key('button-clear')).right, closeTo(l.actionButton(1, count: 2).right, 0.5));
      expect(tester.takeException(), isNull);
      await closeLucky16(tester, winRig);

      // Android keeps button-remove even at desktop screen size.
      _usePlatform(TargetPlatform.android);
      final androidDeskRig = l16_rig.BetRig(tester);
      await openLucky16(tester, androidDeskRig, _kDesktop1920, desktopPlatform: true);
      expect(_key('button-remove'), findsOneWidget);
      await closeLucky16(tester, androidDeskRig);

      // Android phone keeps button-remove and ignores secondary tap.
      final phoneRig = l16_rig.BetRig(tester);
      await openLucky16(tester, phoneRig, _kPhone844, desktopPlatform: false);
      expect(_key('button-remove'), findsOneWidget);
      await _leftTap(tester, _key('chip-10'));
      await _leftTap(tester, _key('a_hearts'));
      expect(phoneRig.provider.stakeOn(const Lucky16Card(Lucky16Rank.ace, Lucky16Suit.hearts)), 10);
      await _rightClick(tester, _key('a_hearts'));
      expect(phoneRig.provider.stakeOn(const Lucky16Card(Lucky16Rank.ace, Lucky16Suit.hearts)), 10);
      await closeLucky16(tester, phoneRig);
    });

    for (final printMode in [false, true]) {
      _testWithPlatform(
          'Windows right-click removes 1 chip on card, suit, rank (including A) after DOUBLE (printMode=$printMode)',
          (tester, _) async {
        _usePlatform(TargetPlatform.windows);
        final rig = l16_rig.BetRig(tester, startInto: 40, startBalance: 3000);
        rig.provider.setPrintMode(printMode);
        await openLucky16(tester, rig, _kDesktop1920, desktopPlatform: true);

        const aHearts = Lucky16Card(Lucky16Rank.ace, Lucky16Suit.hearts);

        // Card: stack [10, 100] -> right-click removes 100 then 10; chip 100 stays held.
        await _leftTap(tester, _key('chip-10'));
        await _leftTap(tester, _key('a_hearts'));
        await _leftTap(tester, _key('chip-100'));
        await _leftTap(tester, _key('a_hearts'));
        expect(rig.provider.stakeOn(aHearts), 110);
        await _rightClick(tester, _key('a_hearts'));
        expect(rig.provider.stakeOn(aHearts), 10);
        expect(rig.provider.balance, 2990);
        expect(rig.provider.activeChip, Lucky16Chip.hundred);
        await _rightClick(tester, _key('a_hearts'));
        expect(rig.provider.stakeOn(aHearts), 0);

        // Suit bar twice + DOUBLE -> [20, 20] on each of 4 Hearts cards -> one right-click removes 20 each.
        await _leftTap(tester, _key('chip-10'));
        await _leftTap(tester, _key('suit-hearts'));
        await _leftTap(tester, _key('suit-hearts'));
        await _leftTap(tester, _key('button-doubleBet'));
        for (final c in Lucky16Card.ofSuit(Lucky16Suit.hearts)) {
          expect(rig.provider.stakeOn(c), 40);
        }
        await _rightClick(tester, _key('suit-hearts'));
        for (final c in Lucky16Card.ofSuit(Lucky16Suit.hearts)) {
          expect(rig.provider.stakeOn(c), 20);
        }
        await _rightClick(tester, _key('suit-hearts'));
        expect(rig.provider.isBoardEmpty, isTrue);

        // Rank A selector -> 4 Aces placed -> right-click removes from all 4 Aces.
        await _leftTap(tester, _key('rank-A'));
        expect(rig.provider.total, 40);
        await _rightClick(tester, _key('rank-A'));
        expect(rig.provider.isBoardEmpty, isTrue);
        expect(rig.provider.balance, 3000);
        expect(rig.provider.activeChip, Lucky16Chip.ten);

        await closeLucky16(tester, rig);
      });
    }

    _testWithPlatform('Lucky 16 locks right-click at 05s and swaps Info dialog text to RIGHT-CLICK on Windows',
        (tester, _) async {
      // Windows Info dialog + lock behavior.
      _usePlatform(TargetPlatform.windows);
      final winRig = l16_rig.BetRig(tester, startInto: 75);
      await openLucky16(tester, winRig, _kDesktop1920, desktopPlatform: true);
      await _leftTap(tester, _key('chip-10'));
      await _leftTap(tester, _key('a_hearts'));
      await _leftTap(tester, _key('top-info'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.descendant(of: _key('info-dialog'), matching: find.text('RIGHT-CLICK')), findsOneWidget);
      expect(find.descendant(of: _key('info-dialog'), matching: find.text('REMOVE')), findsNothing);
      await _leftTap(tester, _key('info-close'));
      await tester.pump(const Duration(milliseconds: 400));

      await winRig.world.runUntil(98.5);
      await tester.pump();
      expect(winRig.provider.isLocked, isTrue);
      await _rightClick(tester, _key('a_hearts'));
      expect(winRig.provider.stakeOn(const Lucky16Card(Lucky16Rank.ace, Lucky16Suit.hearts)), 10);
      await closeLucky16(tester, winRig);

      // Android Info dialog still says REMOVE.
      _usePlatform(TargetPlatform.android);
      final androidRig = l16_rig.BetRig(tester, startInto: 40);
      await openLucky16(tester, androidRig, _kTablet1024, desktopPlatform: false);
      await _leftTap(tester, _key('top-info'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.descendant(of: _key('info-dialog'), matching: find.text('REMOVE')), findsOneWidget);
      expect(find.descendant(of: _key('info-dialog'), matching: find.text('RIGHT-CLICK')), findsNothing);
      await closeLucky16(tester, androidRig);
    });
  });
}
