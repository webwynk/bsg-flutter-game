// The Spin2Win game screen.
//
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const Spin2WinScreen()));
//
// What it does so far (screens Phases 2 to 5, 2026-10-25):
//   * builds the game's own objects (the API service, the round sync, the provider) over the
//     shared AuthProvider's balance, through [AuthSpin2WinWallet] (nothing is registered in
//     main.dart), forces landscape, and starts the provider;
//   * draws the phone screen ([Spin2WinFrameBinding]) with the betting panel working: cards,
//     chips, ODD / EVEN, DOUBLE / REBET, REMOVE, CLEAR, the countdown, the balance, PLAY and the
//     history strip; the board locks at 05 and the bet is sent then, by the provider;
//   * handles the app going to the background as Lucky Card does: on every return it sends a bet
//     whose cutoff passed while the app was away, and on a return after 20 seconds or more
//     (main.dart is then logging the player out) it stops itself. `main.dart` is not touched;
//   * gives back the chips that were never sent when the screen closes (the provider's leave);
//   * asks "EXIT GAME / Do you want to exit?" for the EXIT button and the back gesture, as Triple
//     Chance does (Phase 5);
//   * opens MY RECORDS from the trophy while betting is open: the rounds played since login, read
//     from the database each time (from the login time the shared AuthProvider keeps,
//     `sessionStartAt`, read only), and the Payout tab (Phase 5);
//   * answers what goes wrong as Triple Chance does (spin2win_messages.dart): its INSUFFICIENT
//     COINS popup, its PLAY LIMIT REACHED bar, its popups for a rejected bet or a round that never
//     resolved, its orange balance bar, and for a lost connection or a blocked account its popup
//     that logs the player out and closes the app (Phase 5).
//
//   * plays Triple Chance's own sounds at Triple Chance's moments, through Spin2Win's own mute
//     (the SOUND button), with the light haptic on every tap that does something (Phase 6;
//     spin2win_sound.dart, spin2win_sound_director.dart).
//
// Not here yet: tablet and desktop (Phase 7), the lobby tile (Phase 8).
//
// Belongs to Spin2Win only.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/spin2win_board.dart';
import '../models/spin2win_models.dart';
import '../providers/auth_provider.dart';
import '../providers/spin2win_history_provider.dart';
import '../providers/spin2win_provider.dart';
import '../services/spin2win_api_service.dart';
import '../services/spin2win_auth_wallet.dart';
import '../services/spin2win_round_sync.dart';
import '../services/spin2win_sound.dart';
import '../services/spin2win_sound_director.dart';
import '../utils/app_exit.dart';
import '../widgets/spin2win/spin2win_bet_panel.dart';
import '../widgets/spin2win/spin2win_exit_dialog.dart';
import '../widgets/spin2win/spin2win_frame.dart';
import '../widgets/spin2win/spin2win_frame_binding.dart';
import '../widgets/spin2win/spin2win_messages.dart';
import '../widgets/spin2win/spin2win_records_dialog.dart';

/// What the screen is built on. The real app lets the screen make its own; a test hands in a
/// provider on a simulated server and chip pictures read from memory.
class Spin2WinScreenSetup {
  const Spin2WinScreenSetup({
    required this.provider,
    this.ownsProvider = false,
    this.setOrientation = true,
    this.chipImage = spin2WinAssetChipImage,
    this.precacheChips = true,
    this.history,
    this.sessionStart,
    this.alerts = const Spin2WinSharedAlerts(),
    this.endSession,
    this.sound,
    this.onRefused,
    this.onProblem,
  });

  final Spin2WinProvider provider;

  /// True when the screen made the provider and must dispose it.
  final bool ownsProvider;

  /// Whether to force landscape (the real app does).
  final bool setOrientation;

  final ImageProvider Function(Spin2WinChip chip) chipImage;

  /// Whether to load the chip pictures before the game starts (a test on a fake clock, where a
  /// picture never finishes loading, passes false).
  final bool precacheChips;

  /// The player's history for MY RECORDS; null makes one over the real database.
  final Spin2WinHistoryProvider? history;

  /// The start of this login; null reads it from the shared AuthProvider.
  final DateTime? Function()? sessionStart;

  /// How popups are put up (Triple Chance's own by default).
  final Spin2WinAlerts alerts;

  /// What OK does on a popup that ends the session; null logs out and closes the app, as Triple
  /// Chance does.
  final Future<void> Function()? endSession;

  /// The sounds (Triple Chance's own through Spin2Win's mute); null makes the real one.
  final Spin2WinSound? sound;

  /// Also told about a tap the board could not fully do (after the message is shown).
  final void Function(Set<Spin2WinBoardIssue> issues)? onRefused;

  /// Also told about a problem the provider reports (after the popup is shown).
  final void Function(Spin2WinProblem problem)? onProblem;
}

class Spin2WinScreen extends StatefulWidget {
  const Spin2WinScreen({super.key, this.setup});

  final Spin2WinScreenSetup? setup;

  /// Away this long or longer, `main.dart` logs the player out.
  static const Duration awayThreshold = Duration(seconds: 20);

  @override
  State<Spin2WinScreen> createState() => _Spin2WinScreenState();
}

class _Spin2WinScreenState extends State<Spin2WinScreen> with WidgetsBindingObserver {
  late final Spin2WinScreenSetup _setup;
  Spin2WinProvider get _provider => _setup.provider;
  late final Spin2WinHistoryProvider _history = _setup.history ?? Spin2WinHistoryProvider();
  late final Spin2WinSound _sound = _setup.sound ?? Spin2WinSound();
  Spin2WinSoundDirector? _director;

  bool _ready = false;

  Timer? _awayTimer;
  bool _awayPastThreshold = false;

  /// True once the screen has stopped itself after a long absence.
  bool _stopped = false;

  /// True once YES was answered, so the screen may close.
  bool _allowPop = false;
  bool _askingExit = false;

  /// One session-ending popup per visit (OK is the only way out of it, and OK ends the session).
  bool _sessionPopupShown = false;
  bool _wasBalanceFailed = false;

  @override
  void initState() {
    super.initState();
    _setup = widget.setup ?? _defaultSetup(context);
    _provider.onProblem = _onProblem;
    _provider.addListener(_onProviderChanged);
    _provider.sync.addListener(_onSync);
    if (_setup.setOrientation) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  static Spin2WinScreenSetup _defaultSetup(BuildContext context) {
    final api = Spin2WinApiService();
    final provider = Spin2WinProvider(
      api: api,
      wallet: AuthSpin2WinWallet(context.read<AuthProvider>()),
      sync: Spin2WinRoundSync(api: api),
    );
    return Spin2WinScreenSetup(provider: provider, ownsProvider: true);
  }

  /// Preloads the chip pictures, then starts the game.
  Future<void> _open() async {
    if (!mounted) return;
    if (_setup.precacheChips) await _precacheChips();
    if (!mounted) return;
    await _provider.attach();
    if (!mounted) return;
    _sound.enterGame();
    _director = Spin2WinSoundDirector(provider: _provider, sound: _sound);
    setState(() => _ready = true);
  }

  Future<void> _precacheChips() async {
    try {
      await Future.wait([
        for (final chip in Spin2WinChip.values) precacheImage(_setup.chipImage(chip), context),
      ]);
    } catch (e) {
      // A picture that cannot be preloaded is simply loaded when it is first drawn.
      debugPrint('Spin2WinScreen: preloading failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _awayTimer?.cancel();
    _provider.removeListener(_onProviderChanged);
    _provider.sync.removeListener(_onSync);
    _provider.onProblem = null;
    _director?.dispose();
    _sound.leaveGame();
    if (_setup.history == null) _history.dispose();
    _provider.leave();
    if (_setup.ownsProvider) _provider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _awayTimer?.cancel();
        _awayTimer = Timer(Spin2WinScreen.awayThreshold, () => _awayPastThreshold = true);
      case AppLifecycleState.resumed:
        _awayTimer?.cancel();
        _awayTimer = null;
        if (!_ready || _stopped) return;
        // The timer may have been frozen straight through the lock mark: send the bet now.
        _provider.catchUpMissedSubmissionIfNeeded();
        if (_awayPastThreshold) {
          _awayPastThreshold = false;
          // main.dart is about to log the player out. Stop everything here; a bet that was sent
          // is left to settle, chips that were not are given back.
          _provider.leave();
          _director?.dispose();
          _director = null;
          _sound.leaveGame();
          setState(() => _stopped = true);
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  // ── What goes wrong (Phase 5, Triple Chance's words and looks) ───────────

  /// A problem the provider reports: a rejected bet, a round that never resolved, or a lost
  /// connection.
  void _onProblem(Spin2WinProblem problem) {
    if (!mounted || _stopped) return;
    if (problem.reason == Spin2WinError.insufficientCoins) {
      _setup.alerts.insufficientCoins(context);
    } else {
      final dialog = spin2WinProblemDialog(problem);
      if (dialog.endsSession) {
        _showSessionEnding(dialog);
      } else {
        _setup.alerts.problem(context, dialog);
      }
    }
    _setup.onProblem?.call(problem);
  }

  /// The round sync lost the connection (three failed polls in a row).
  void _onSync() {
    final sync = _provider.sync;
    if (sync.isConnected || sync.connectionError == null) return;
    if (!mounted || _stopped || !_ready) return;
    _showSessionEnding(spin2WinDialogForConnection(sync.connectionError));
  }

  /// The popup that cannot be skipped: OK gives back the chips that were never sent, logs the
  /// player out and closes the app, as Triple Chance does. Not shown while main.dart's
  /// away-too-long flow is already closing the app.
  void _showSessionEnding(Spin2WinProblemDialog dialog) {
    if (_sessionPopupShown || isClosingApp.value) return;
    _sessionPopupShown = true;
    _setup.alerts.problem(context, dialog, onSessionEnd: () async {
      _provider.leave();
      final custom = _setup.endSession;
      if (custom != null) {
        await custom();
        return;
      }
      await context.read<AuthProvider>().logout();
      closeApp();
    });
  }

  /// A round whose balance could not be confirmed: Triple Chance's orange bar.
  void _onProviderChanged() {
    final failed = _provider.balanceSyncFailed;
    if (failed && !_wasBalanceFailed && mounted && !_stopped) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(spin2WinBalanceSnackBar());
    }
    _wasBalanceFailed = failed;
  }

  /// A tap the board could not fully do: not enough coins gets the INSUFFICIENT COINS popup, a
  /// number at 10,000 the PLAY LIMIT REACHED bar; anything else is silent (the buttons are dimmed
  /// when they cannot work), as in Triple Chance.
  void _onRefused(Set<Spin2WinBoardIssue> issues) {
    if (issues.contains(Spin2WinBoardIssue.notEnoughCoins)) {
      _setup.alerts.insufficientCoins(context);
    } else if (spin2WinRefusalIsLimit(issues)) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(spin2WinLimitSnackBar());
    }
    _setup.onRefused?.call(issues);
  }

  // ── Sounds (Phase 6) ──────────────────────────────────────────────────────

  /// A tap that did something: Triple Chance's sound for it and its light haptic.
  void _onTapped(Spin2WinTapKind kind) {
    switch (kind) {
      case Spin2WinTapKind.number:
        _sound.numberSelect();
      case Spin2WinTapKind.chip:
        _sound.chipClick();
      case Spin2WinTapKind.button:
        _sound.buttonClick();
    }
    HapticFeedback.selectionClick();
  }

  /// The SOUND button: Spin2Win's own mute (haptics are not affected).
  void _toggleSound() {
    _sound.toggle();
    _sound.buttonClick();
    setState(() {});
  }

  // ── EXIT and MY RECORDS ───────────────────────────────────────────────────

  /// EXIT and the back gesture: asks first; YES leaves (the chips never sent are given back by
  /// dispose, through the provider's leave).
  Future<void> _requestExit() async {
    if (_askingExit) return;
    _askingExit = true;
    _sound.notification();
    final leave = await Spin2WinExitDialog.show(context);
    _askingExit = false;
    if (leave != true || !mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  DateTime? _sessionStart() {
    final custom = _setup.sessionStart;
    if (custom != null) return custom();
    return context.read<AuthProvider>().sessionStartAt;
  }

  /// The trophy: MY RECORDS, only while betting is open (it closes by itself when betting closes).
  void _showRecords() {
    if (_provider.isLocked) return;
    _sound.notification();
    Spin2WinRecordsDialog.show(
      context,
      provider: _provider,
      history: _history,
      since: _sessionStart(),
      chipImage: _setup.chipImage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07132E),
        body: Spin2WinViewport(
          child: _ready
              ? Spin2WinFrameBinding(
                  provider: _provider,
                  muted: _sound.muted,
                  chipImage: _setup.chipImage,
                  onExit: _requestExit,
                  onRecords: _showRecords,
                  onSound: _toggleSound,
                  onRefused: _onRefused,
                  onTapped: _onTapped,
                )
              : const Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFFFD45A)),
                  ),
                ),
        ),
      ),
    );
  }
}
