// The Lucky Card game screen (App Step 8a, spec §17AC): everything built in Steps 1 to 7,
// put together and linked to the shared wallet.
//
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const LuckyCardScreen()));
//
// What it does, and nothing more:
//   * builds the game's own objects (the API service, the round sync, the provider) over
//     the shared AuthProvider's balance, through [AuthLuckyCardWallet], and the player's
//     history provider (nothing of it is registered in main.dart);
//   * forces landscape, preloads the pictures behind a short loading screen, then starts the
//     provider;
//   * lays out the top bar, the board (or, once betting closes, the wheel), the rank
//     selectors (or the card column) and the side column on the canvas (the round's status
//     words and warnings are in the header),
//     with the coins and the win popup over everything. On a desktop screen (spec §17BP: Windows,
//     macOS, Linux or a browser, and at least 1280 x 720 dp) the wheel is instead always on
//     screen in a column at the left, the board and rank selectors only dim while betting is
//     closed, and the results and the chips-and-buttons have a row and a bar of their own;
//   * asks "EXIT GAME / Do you want to exit?" for the EXIT button and the back gesture, as
//     Triple Chance does; chips that were never sent are given back when the screen closes;
//   * opens the Info dialog from the INFO button, and the History dialog from the HISTORY
//     button: it lists every round the player bet on since logging in. It is read from the
//     database each time the dialog opens, from the login time the shared AuthProvider keeps
//     (`sessionStartAt`, read only), so leaving with EXIT and coming back keeps the list and
//     logging out and in starts an empty one;
//   * handles the app going to the background. `main.dart` logs the player out after 20
//     seconds away and settles only Triple Chance's bet, so this screen settles its own: on
//     every return it sends a bet whose cutoff passed while the app was away, and on a
//     return after 20 seconds or more it stops itself, leaving nothing running behind the
//     shared "you were away" popup. `main.dart` is not touched.
//
// Not here yet: the sounds and the mute (8b: the SOUND button only changes its look), the
// messages for refusals and problems (8c).
//
// Belongs to Lucky Card only.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../models/lucky_card_board.dart';
import '../models/lucky_card_models.dart';
import '../providers/lucky_card_history_provider.dart';
import '../providers/lucky_card_provider.dart';
import '../services/lucky_card_api_service.dart';
import '../services/lucky_card_auth_wallet.dart';
import '../services/lucky_card_round_sync.dart';
import '../services/lucky_card_sound.dart';
import '../services/lucky_card_sound_director.dart';
import '../utils/app_exit.dart';
import '../widgets/dialogs/action_dialog.dart';
import '../widgets/lucky_card/lucky_card_art.dart';
import '../widgets/lucky_card/lucky_card_background.dart';
import '../widgets/lucky_card/lucky_card_board_binding.dart';
import '../widgets/lucky_card/lucky_card_board_view.dart';
import '../widgets/lucky_card/lucky_card_canvas.dart';
import '../widgets/lucky_card/lucky_card_controls_binding.dart';
import '../widgets/lucky_card/lucky_card_desktop_pieces.dart';
import '../widgets/lucky_card/lucky_card_exit_dialog.dart';
import '../widgets/lucky_card/lucky_card_history_dialog.dart';
import '../widgets/lucky_card/lucky_card_info_dialog.dart';
import '../widgets/lucky_card/lucky_card_layout.dart';
import '../widgets/lucky_card/lucky_card_messages.dart';
import '../widgets/lucky_card/lucky_card_readouts_binding.dart';
import '../widgets/lucky_card/lucky_card_region_swap.dart';
import '../widgets/lucky_card/lucky_card_reveal_binding.dart';
import '../widgets/lucky_card/lucky_card_wheel_binding.dart';

/// What the screen is built on. The real app lets the screen make its own; a test hands in
/// a provider on a simulated server and the pictures read from disk.
class LuckyCardScreenSetup {
  const LuckyCardScreenSetup({
    required this.provider,
    this.art = const AssetLuckyCardArt(),
    this.ownsProvider = false,
    this.setOrientation = true,
    this.sound,
    this.endSession,
    this.history,
    this.ownsHistory = false,
    this.sessionStart,
    this.auth,
    this.desktopPlatform,
  });

  final LuckyCardProvider provider;
  final LuckyCardArt art;

  /// Whether a screen of at least 1280 x 720 gets the desktop arrangement (spec §17BP: the wheel
  /// always on screen at the left, the board dimmed while betting is closed, the results row and the
  /// chips-and-buttons bar). The real app's default setup ([_defaultSetup]) passes true, so the choice
  /// is by screen size alone, like Triple Chance, on every platform (including an Android emulator on
  /// a desktop). Null (only a test that leaves it unset) means false: the phone and tablet
  /// arrangements however big the screen is.
  final bool? desktopPlatform;

  /// The player's history. When null the screen makes its own (over the real database read)
  /// and disposes it; a test hands in one over a scripted read.
  final LuckyCardHistoryProvider? history;

  /// True when the screen must dispose a [history] it was given. A history the screen made
  /// itself is always disposed with it.
  final bool ownsHistory;

  /// Where "since logging in" starts, when a test wants to say it directly. By default it is
  /// the shared AuthProvider's `sessionStartAt`, read when HISTORY is tapped.
  final DateTime? Function()? sessionStart;

  /// The shared AuthProvider. The real app leaves this null and the screen takes it from the
  /// widget tree; a test hands in a stand-in (the real one cannot be built without Supabase), to
  /// prove the screen reads `sessionStartAt` from it.
  final AuthProvider? auth;

  /// The sound gate; the real app lets the screen make one over Triple Chance's sounds.
  final LuckyCardSound? sound;

  /// What OK does on "connection lost" after the unsent chips are given back. The real app
  /// logs out and closes (Triple Chance's way); a test hands in its own.
  final Future<void> Function()? endSession;

  /// True when the screen made the provider and must dispose it.
  final bool ownsProvider;

  /// Whether to force landscape (the real app does).
  final bool setOrientation;
}

class LuckyCardScreen extends StatefulWidget {
  const LuckyCardScreen({super.key, this.setup});

  final LuckyCardScreenSetup? setup;

  /// Away this long or longer, `main.dart` logs the player out (spec §17AC).
  static const Duration awayThreshold = Duration(seconds: 20);

  @override
  State<LuckyCardScreen> createState() => _LuckyCardScreenState();
}

class _LuckyCardScreenState extends State<LuckyCardScreen> with WidgetsBindingObserver {
  late final LuckyCardProvider _provider;
  late final LuckyCardArt _art;
  late final bool _ownsProvider;
  late final LuckyCardHistoryProvider _history;
  late final bool _ownsHistory;
  late final DateTime? Function() _sessionStart;
  late final LuckyCardSound _sound;
  LuckyCardSoundDirector? _director;
  late final Future<void> Function()? _endSession;
  late final bool _desktopPlatform;
  AuthProvider? _auth;
  final LuckyCardNotice _notice = LuckyCardNotice();
  bool _connectionDialogShowing = false;
  bool _wasBalanceFailed = false;

  bool _ready = false;
  bool _allowPop = false;
  bool _asking = false;

  Timer? _awayTimer;
  bool _awayPastThreshold = false;

  /// True once the screen has stopped itself after a long absence.
  bool _stopped = false;

  @override
  void initState() {
    super.initState();
    final setup = widget.setup ?? _defaultSetup(context);
    _provider = setup.provider;
    _art = setup.art;
    _ownsProvider = setup.ownsProvider;
    _history = setup.history ?? LuckyCardHistoryProvider();
    _ownsHistory = setup.history == null || setup.ownsHistory;
    _sound = setup.sound ?? LuckyCardSound();
    _endSession = setup.endSession;
    _desktopPlatform = setup.desktopPlatform ?? false;
    _auth = setup.auth;
    if (widget.setup == null) _auth = context.read<AuthProvider>();
    // Read when HISTORY is tapped, not now: with no login (a test) the list is empty.
    _sessionStart = setup.sessionStart ?? () => _auth?.sessionStartAt;
    _provider.onProblem = _onProblem;
    _sound.enterGame();
    if (setup.setOrientation) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  static LuckyCardScreenSetup _defaultSetup(BuildContext context) {
    final api = LuckyCardApiService();
    final sync = LuckyCardRoundSync(api: api);
    final provider = LuckyCardProvider(
      api: api,
      wallet: AuthLuckyCardWallet(context.read<AuthProvider>()),
      sync: sync,
    );
    // The real app chooses the desktop arrangement by screen size alone (>= 1280 x 720 dp), exactly
    // like Triple Chance's `isDesktopScreen`, so an emulator such as BlueStacks on a desktop (which
    // reports Android as its platform) gets the desktop arrangement too.
    return LuckyCardScreenSetup(provider: provider, ownsProvider: true, desktopPlatform: true);
  }

  /// Preloads the pictures, then starts the game.
  Future<void> _open() async {
    if (!mounted) return;
    final layout = LuckyCardLayout.of(MediaQuery.sizeOf(context), desktopPlatform: _desktopPlatform);
    try {
      await Future.wait([
        precacheLuckyCardBoard(context, layout, _art),
        precacheLuckyCardReveal(context, layout, _art),
        precacheLuckyCardSideColumn(context, layout, _art),
        precacheLuckyCardBackground(context, _art),
      ]);
    } catch (e) {
      // A picture that cannot be preloaded is simply loaded when it is first drawn.
      debugPrint('LuckyCardScreen: preloading failed: $e');
    }
    if (!mounted) return;
    // Before the attach, so a connection that is already down is noticed.
    _provider.sync.addListener(_onSync);
    await _provider.attach();
    if (!mounted) return;
    _wasBalanceFailed = _provider.balanceSyncFailed;
    _provider.addListener(_onProviderChanged);
    // After the attach, so a screen opened while betting is closed or after a result has
    // been shown starts silent: only changes seen from now on make a sound.
    _director = LuckyCardSoundDirector(provider: _provider, sound: _sound);
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _awayTimer?.cancel();
    _director?.dispose();
    _provider.sync.removeListener(_onSync);
    _provider.removeListener(_onProviderChanged);
    _provider.onProblem = null;
    _notice.dispose();
    _sound.leaveGame();
    _provider.leave();
    if (_ownsProvider) _provider.dispose();
    if (_ownsHistory) _history.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _awayTimer?.cancel();
        _awayTimer = Timer(LuckyCardScreen.awayThreshold, () => _awayPastThreshold = true);
      case AppLifecycleState.resumed:
        _awayTimer?.cancel();
        _awayTimer = null;
        if (!_ready || _stopped) return;
        // The timer may have been frozen straight through the lock mark: send the bet now.
        _provider.catchUpMissedSubmissionIfNeeded();
        if (_awayPastThreshold) {
          _awayPastThreshold = false;
          // main.dart is about to log the player out. Stop everything here; a bet that
          // was sent is left to settle, chips that were not are given back.
          _sound.stopAll();
          _notice.clear();
          _provider.leave();
          setState(() => _stopped = true);
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _requestExit() async {
    if (_asking) return;
    _asking = true;
    final leave = await LuckyCardExitDialog.show(context, onOpen: _sound.notification);
    _asking = false;
    if (leave == true && mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  void _showInfo() => LuckyCardInfoDialog.show(
        context,
        provider: _provider,
        onOpen: _sound.notification,
        onTab: (_) => _sound.buttonClick(),
      );

  /// The HISTORY button: opens the list of this login's rounds with the notification sound, as
  /// Triple Chance's history does; tapping a line makes the same sound as its detail popup does there.
  /// The dialog reads the database itself and closes by itself when betting closes.
  void _showHistory() => LuckyCardHistoryDialog.show(
        context,
        provider: _provider,
        history: _history,
        since: _sessionStart(),
        onOpen: _sound.notification,
        onRow: _sound.notification,
      );

  /// The SOUND button: mutes or unmutes Lucky Card's own sounds (haptics are not affected).
  void _toggleSound() {
    _sound.toggle();
    setState(() {});
  }

  // ── What goes wrong (App Step 8c, spec §17AG) ───────────────────────────

  /// A refused tap: a card at its largest stake gets Triple Chance's kind of snackbar at the bottom
  /// (the user's decision of 2026-10-23); insufficient coins pops up the modal dialog; anything else a short line in the header, or nothing.
  void _refusal(Set<LuckyCardBoardIssue> issues) {
    if (issues.contains(LuckyCardBoardIssue.notEnoughCoins)) {
      showInsufficientCoinsDialog(context);
    }
    if (luckyCardRefusalIsLimit(issues)) {
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..clearSnackBars()
        ..showSnackBar(luckyCardLimitSnackBar());
      return;
    }
    final line = luckyCardRefusalLine(issues);
    if (line != null) _notice.show(line);
  }

  /// A problem the provider reports: a bet that was rejected, a round that never resolved,
  /// or a connection that could not be kept.
  void _onProblem(LuckyCardProblem problem) {
    if (!mounted || _stopped) return;
    if (problem.reason == LuckyCardError.insufficientCoins) {
      showInsufficientCoinsDialog(context);
      return;
    }
    final dialog = luckyCardProblemDialog(problem);
    if (dialog.endsSession) {
      _showSessionEnding(dialog);
    } else {
      showActionDialog(
        context,
        icon: dialog.icon,
        title: dialog.title,
        message: dialog.message,
        barrierDismissible: true,
        autoDismissAfter: dialog.autoDismiss,
      );
    }
  }

  /// The round sync lost the connection (three failed polls in a row). A connection that comes
  /// back does not take the dialog away, and a second outage does not stack a second one: OK is
  /// the only way out of it and OK ends the session, so one dialog per visit is all there is.
  void _onSync() {
    final sync = _provider.sync;
    final reason = sync.connectionError;
    if (sync.isConnected || reason == null) return;
    if (!mounted || _stopped) return;
    _showSessionEnding(luckyCardDialogForConnection(reason));
  }

  /// The dialog that cannot be skipped: OK gives back the chips that were never sent, logs the
  /// player out and closes the app, as Triple Chance does. Shown once per outage, and not at
  /// all while the away-too-long flow of main.dart is already closing the app.
  void _showSessionEnding(LuckyCardProblemDialog dialog) {
    if (_connectionDialogShowing || isClosingApp.value) return;
    _connectionDialogShowing = true;
    showActionDialog(
      context,
      icon: dialog.icon,
      title: dialog.title,
      message: dialog.message,
      barrierDismissible: false,
      onPressed: () async {
        _provider.leave();
        await _finishSession();
      },
    );
  }

  Future<void> _finishSession() async {
    final custom = _endSession;
    if (custom != null) {
      await custom();
      return;
    }
    await _auth?.logout();
    closeApp();
  }

  /// A round whose balance could not be confirmed: a warning line, for a while.
  void _onProviderChanged() {
    final failed = _provider.balanceSyncFailed;
    if (failed && !_wasBalanceFailed) {
      _notice.show(kLuckyCardBalanceLine, duration: kLuckyCardBalanceLineTime, important: true);
    }
    _wasBalanceFailed = failed;
  }

  /// The light click of Triple Chance's card taps and buttons.
  void _lightClick() => HapticFeedback.selectionClick();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF060000),
        body: _ready ? _game(context) : const _Loading(),
      ),
    );
  }

  Widget _game(BuildContext context) {
    final provider = _provider;
    final art = _art;
    // The phone's own insets (a notch, a cut-out, the system bars), read here above the SafeArea
    // that is about to consume them.
    final insets = MediaQuery.paddingOf(context);
    final canvas = SafeArea(
      left: false,
      right: false,
      child: LuckyCardBoardBinding(
        provider: provider,
        art: art,
        onRefused: (target, issues) => _refusal(issues),
        onTapped: (target, result) {
          // When the tap changed the board: a single card makes Triple Chance's number-select
          // sound (as a number of its grid does), a bar makes the chip click; both with the
          // light haptic of Triple Chance.
          if (result.changedAnything) {
            if (target is LuckyCardCardTarget) {
              _sound.numberSelect();
            } else {
              _sound.chipClick();
            }
            _lightClick();
          }
        },
        builder: (context, zones) => LuckyCardCanvas(
          layoutOf: (screen) => LuckyCardLayout.of(screen, desktopPlatform: _desktopPlatform),
          // The background is the screen's own, behind the safe area (below).
          background: const SizedBox.shrink(),
          topBar: (context, layout) => LuckyCardTopBarBinding(
            provider: provider,
            layout: layout,
            art: art,
            // The canvas is edge-to-edge horizontally; bleed upward under any status bar/notch.
            bleed: EdgeInsets.only(top: insets.top),
            soundOn: !_sound.muted,
            onExit: _requestExit,
            onToggleSound: _toggleSound,
            onInfo: _showInfo,
            onHistory: _showHistory,
            // The reference design has no strip under the board: the header carries the
            // round's status and, for a moment, a refused tap's warning.
            notice: _notice,
          ),
          // Desktop (spec §17BP): the board and the rank selectors stay where they are while betting is
          // closed (dimmed and locked by their own lock) and the wheel lives in the side column, so
          // nothing is swapped and no card flips over the rank column.
          grid: (context, layout) => layout.isDesktop
              ? zones.grid(context, layout)
              : LuckyCardRegionSwap(
                  provider: provider,
                  betting: (context) => zones.grid(context, layout),
                  reveal: (context) => LuckyCardWheelBinding(
                    provider: provider,
                    layout: layout,
                    // The first ding, for the rank rim, and the owner's own wheel sound from the start of
                    // the spin (the second ding, for the suit rim, comes from the sound director).
                    onSpinStart: _sound.wheelSpin,
                    onRankLanded: _sound.ding,
                  ),
                ),
          rankColumn: (context, layout) => layout.isDesktop
              ? zones.rankColumn(context, layout)
              : LuckyCardRegionSwap(
                  provider: provider,
                  betting: (context) => zones.rankColumn(context, layout),
                  // The card flip has no sound (owner's decision 2026-10-07): the wheel's own sound and
                  // the two dings are what is heard.
                  reveal: (context) => LuckyCardRevealColumn(provider: provider, layout: layout, art: art),
                ),
          side: (context, layout) => layout.isDesktop
              ? LuckyCardDesktopSide(
                  provider: provider,
                  layout: layout,
                  art: art,
                  onSpinStart: _sound.wheelSpin,
                  onRankLanded: _sound.ding,
                )
              : LuckyCardSideColumn(
                  provider: provider,
                  layout: layout,
                  art: art,
                  onChipSelected: (_) => _sound.buttonClick(),
                  onButtonRefused: (control, issues) => _refusal(issues),
                  onButtonPressed: (_) {
                    _sound.buttonClick();
                    _lightClick();
                  },
                ),
          // The desktop's results row and its bar of chips and buttons (not built on a phone or a tablet).
          resultsBar: (context, layout) => LuckyCardResultsBarBinding(provider: provider, layout: layout, art: art),
          actionBar: (context, layout) => LuckyCardActionBar(
            provider: provider,
            layout: layout,
            art: art,
            onChipSelected: (_) => _sound.buttonClick(),
            onButtonRefused: (control, issues) => _refusal(issues),
            onButtonPressed: (_) {
              _sound.buttonClick();
              _lightClick();
            },
          ),
          // A tablet's chips are in a bar under the board (spec §17BN); a phone has no such zone.
          chipBar: (context, layout) => LuckyCardChipBar(
            provider: provider,
            layout: layout,
            art: art,
            onChipSelected: (_) => _sound.buttonClick(),
          ),
          overlay: (context, layout) => LuckyCardRevealOverlay(
          provider: provider,
          layout: layout,
          art: art,
          onCoinsStart: _sound.coin,
          onPopupOpen: _sound.win,
        ),
        ),
      ),
    );
    // The supplied stage fills the whole screen, notch areas included; the game sits inside the safe area.
    final game = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: LuckyCardBackground(art: art)),
        canvas,
      ],
    );
    // After a long absence the screen has stopped itself: nothing on it can be used.
    return _stopped ? IgnorePointer(child: Opacity(opacity: 0.4, child: game)) : game;
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFD4AF37)),
        ),
      );
}
