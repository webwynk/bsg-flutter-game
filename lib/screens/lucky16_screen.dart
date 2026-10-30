// The Lucky 16 Card game screen -- phone phases 1 to 7: the frame, the header, the betting board, the
// bet panel, the wheel with the reveal card, the win effects, the popups, the sounds and the messages.
//
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const Lucky16Screen()));
//
// Built from lib/screens/lucky_card_screen.dart (Lucky Card) one phase at a time. What it does now,
// and nothing more:
//   * builds the game's own objects (the API service, the round sync, the provider) over the shared
//     AuthProvider's balance, through [AuthLucky16Wallet] (nothing is registered in main.dart);
//   * forces landscape, preloads the board's, the panel's and the reveal's pictures and the background
//     behind a short loading screen, then starts the provider, so the header's balance and countdown
//     are live;
//   * lays out the canvas (lib/widgets/lucky16/lucky16_layout.dart: the phone, tablet or desktop arrangement) with the
//     background over the whole screen, the header at the top, the betting board (the four suit bars
//     over the 16 cards, and the four rank selectors) and the bet panel (PLAY / WIN, the twelve latest
//     results, the five chips, DOUBLE or REBET, CLEAR and REMOVE), all linked to the provider;
//   * at the lock (countdown 5) swaps the board's place for the wheel and the reveal card beside it
//     ([Lucky16RegionSwap]): the wheel spins to the server's card and bonus with Lucky Card's timing,
//     the card shuffles and settles on the winner (and lights up gold), and the board comes back when
//     the next round opens;
//   * on a winning round shows the coins bursting from the wheel and the win popup with the server's
//     payout, exactly when the provider says (Lucky Card's timing), over everything;
//   * asks "EXIT GAME / Do you want to exit?" for the EXIT button and the back gesture, as Lucky Card
//     does; leaving gives back any chips that were never sent (the provider's own `leave`);
//   * opens the Info popup from the INFO button and the History popup from the HISTORY button: every
//     round the player bet on since logging in, read from the database each time it opens, from the
//     login time the shared AuthProvider keeps (`sessionStartAt`, read only).
//
//   * plays every sound Lucky Card's screen plays, through Lucky 16 Card's own mute (the SOUND ball);
//   * says what went wrong, as Lucky Card's screen does: a refused tap gets a line in the header, a card
//     at 10,000 the limit banner, too few coins the shared dialog, and a problem the provider reports
//     (a rejected bet, a round that never resolved, a lost connection, a blocked account) the shared
//     dialog in Lucky Card's words. A lost connection or a blocked account logs the player out.
//
//   * handles the app going to the background, as Lucky Card's screen does. `main.dart` logs the player
//     out after 20 seconds away and settles only Triple Chance's bet, so this screen settles its own: on
//     every return it sends a bet whose cutoff passed while the app was away, and on a return after 20
//     seconds or more it stops itself, leaving nothing running behind the shared "you were away" popup.
//     `main.dart` is not touched.
//
// The screen is not reachable from the lobby yet (that, and listing the pictures in
// pubspec.yaml, is its own approved step).
//
// Belongs to Lucky 16 Card only.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/lucky16_board.dart';
import '../models/lucky16_models.dart';
import '../providers/auth_provider.dart';
import '../providers/lucky16_history_provider.dart';
import '../providers/lucky16_provider.dart';
import '../services/lucky16_api_service.dart';
import '../services/lucky16_auth_wallet.dart';
import '../services/lucky16_round_sync.dart';
import '../services/lucky16_sound.dart';
import '../services/lucky16_sound_director.dart';
import '../utils/app_exit.dart';
import '../widgets/dialogs/action_dialog.dart';
import '../widgets/lucky16/lucky16_art.dart';
import '../widgets/lucky16/lucky16_background.dart';
import '../widgets/lucky16/lucky16_board_binding.dart';
import '../widgets/lucky16/lucky16_board_view.dart';
import '../widgets/lucky16/lucky16_canvas.dart';
import '../widgets/lucky16/lucky16_desktop_pieces.dart';
import '../widgets/lucky16/lucky16_exit_dialog.dart';
import '../widgets/lucky16/lucky16_history_dialog.dart';
import '../widgets/lucky16/lucky16_info_dialog.dart';
import '../widgets/lucky16/lucky16_layout.dart';
import '../widgets/lucky16/lucky16_messages.dart';
import '../widgets/lucky16/lucky16_readouts_binding.dart';
import '../widgets/lucky16/lucky16_region_swap.dart';
import '../widgets/lucky16/lucky16_reveal_binding.dart';
import '../widgets/lucky16/lucky16_wheel_binding.dart';
import '../widgets/lucky16/lucky16_controls_binding.dart';
import '../widgets/lucky16/lucky16_top_bar_binding.dart';

/// What the screen is built on. The real app lets the screen make its own; a test hands in a
/// provider on a simulated server and the pictures read from disk.
class Lucky16ScreenSetup {
  const Lucky16ScreenSetup({
    required this.provider,
    this.art = const AssetLucky16Art(),
    this.ownsProvider = false,
    this.setOrientation = true,
    this.history,
    this.ownsHistory = false,
    this.sessionStart,
    this.auth,
    this.sound,
    this.endSession,
    this.desktopPlatform,
  });

  final Lucky16Provider provider;
  final Lucky16Art art;

  /// The player's history. When null the screen makes its own (over the real database read) and
  /// disposes it; a test hands in one over a scripted read.
  final Lucky16HistoryProvider? history;

  /// True when the screen must dispose a [history] it was given. A history the screen made itself is
  /// always disposed with it.
  final bool ownsHistory;

  /// Where "since logging in" starts, when a test wants to say it directly. By default it is the shared
  /// AuthProvider's `sessionStartAt`, read when HISTORY is tapped.
  final DateTime? Function()? sessionStart;

  /// The shared AuthProvider. The real app leaves this null and the screen takes it from the widget
  /// tree; a test hands in a stand-in or none.
  final AuthProvider? auth;

  /// The sound gate; the real app lets the screen make one over the shared sounds.
  final Lucky16Sound? sound;

  /// Whether a screen of at least 1280 x 720 gets the desktop arrangement. The real app's default setup
  /// passes true, so the choice is by screen size alone. Null (a test that leaves it unset) means false.
  final bool? desktopPlatform;

  /// What OK does on "connection lost" after the unsent chips are given back. The real app logs out
  /// and closes, as Lucky Card and Triple Chance do; a test hands in its own.
  final Future<void> Function()? endSession;

  /// True when the screen made the provider and must dispose it.
  final bool ownsProvider;

  /// Whether to force landscape (the real app does).
  final bool setOrientation;
}

class Lucky16Screen extends StatefulWidget {
  const Lucky16Screen({super.key, this.setup});

  final Lucky16ScreenSetup? setup;

  /// Away this long or longer, `main.dart` logs the player out.
  static const Duration awayThreshold = Duration(seconds: 20);

  @override
  State<Lucky16Screen> createState() => _Lucky16ScreenState();
}

class _Lucky16ScreenState extends State<Lucky16Screen> with WidgetsBindingObserver {
  late final Lucky16Provider _provider;
  late final Lucky16Art _art;
  late final bool _ownsProvider;
  late final bool _desktopPlatform;
  late final Lucky16HistoryProvider _history;
  late final bool _ownsHistory;
  late final DateTime? Function() _sessionStart;
  AuthProvider? _auth;
  late final Lucky16Sound _sound;
  Lucky16SoundDirector? _director;
  late final Future<void> Function()? _endSession;
  final Lucky16Notice _notice = Lucky16Notice();
  bool _connectionDialogShowing = false;
  bool _wasBalanceFailed = false;
  bool _ready = false;

  /// True once the player has answered YES, so the page may really close.
  bool _allowPop = false;

  /// True while the exit question is up, so a second tap or back gesture does not stack another.
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
    _desktopPlatform = setup.desktopPlatform ?? false;
    _history = setup.history ?? Lucky16HistoryProvider();
    _ownsHistory = setup.history == null || setup.ownsHistory;
    _auth = setup.auth;
    if (widget.setup == null) _auth = context.read<AuthProvider>();
    // Read when HISTORY is tapped, not now: with no login (a test) the list is empty.
    _sessionStart = setup.sessionStart ?? () => _auth?.sessionStartAt;
    _sound = setup.sound ?? Lucky16Sound();
    _endSession = setup.endSession;
    _provider.onProblem = _onProblem;
    _sound.enterGame();
    if (setup.setOrientation) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  /// The real app's objects: Lucky 16 Card's own API service and round sync, over the shared
  /// AuthProvider's balance (read and updated only through its public methods).
  static Lucky16ScreenSetup _defaultSetup(BuildContext context) {
    final api = Lucky16ApiService();
    final provider = Lucky16Provider(
      api: api,
      wallet: AuthLucky16Wallet(context.read<AuthProvider>()),
      sync: Lucky16RoundSync(api: api),
    );
    return Lucky16ScreenSetup(provider: provider, ownsProvider: true, desktopPlatform: true);
  }

  /// Preloads the background, then starts the game.
  Future<void> _open() async {
    if (!mounted) return;
    final layout = Lucky16Layout.of(MediaQuery.sizeOf(context), desktopPlatform: _desktopPlatform);
    try {
      await Future.wait([
        precacheLucky16Board(context, layout, _art),
        precacheLucky16SideColumn(context, layout, _art),
        precacheLucky16Reveal(context, layout, _art),
        precacheLucky16Background(context, _art),
      ]);
    } catch (e) {
      // A picture that cannot be preloaded is simply loaded when it is first drawn.
      debugPrint('Lucky16Screen: preloading failed: $e');
    }
    if (!mounted) return;
    // Before the attach, so a connection that is already down is noticed.
    _provider.sync.addListener(_onSync);
    await _provider.attach();
    if (!mounted) return;
    _wasBalanceFailed = _provider.balanceSyncFailed;
    _provider.addListener(_onProviderChanged);
    // After the attach, so a screen opened while betting is closed or after a result has been shown
    // starts silent: only changes seen from now on make a sound.
    _director = Lucky16SoundDirector(provider: _provider, sound: _sound);
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

  /// The app went to the background or came back. Copied from Lucky Card's screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _awayTimer?.cancel();
        _awayTimer = Timer(Lucky16Screen.awayThreshold, () => _awayPastThreshold = true);
      case AppLifecycleState.resumed:
        _awayTimer?.cancel();
        _awayTimer = null;
        if (!_ready || _stopped) return;
        // The timer may have been frozen straight through the lock mark: send the bet now.
        _provider.catchUpMissedSubmissionIfNeeded();
        if (_awayPastThreshold) {
          _awayPastThreshold = false;
          // main.dart is about to log the player out. Stop everything here; a bet that was sent is
          // left to settle, chips that were not are given back.
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

  /// The SOUND ball: mutes or unmutes Lucky 16 Card's own sounds (haptics are not affected).
  void _toggleSound() {
    _sound.toggle();
    setState(() {});
  }

  // ── What goes wrong (Lucky Card's rules) ─────────────────────────────────

  /// A refused tap: too few coins pops up the shared dialog; a card at its largest stake gets the limit
  /// banner at the bottom; anything else a short line in the header, or nothing.
  void _refusal(Set<Lucky16BoardIssue> issues) {
    if (issues.contains(Lucky16BoardIssue.notEnoughCoins)) {
      showInsufficientCoinsDialog(context);
    }
    if (lucky16RefusalIsLimit(issues)) {
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..clearSnackBars()
        ..showSnackBar(lucky16LimitSnackBar());
      return;
    }
    final line = lucky16RefusalLine(issues);
    if (line != null) _notice.show(line);
  }

  /// A problem the provider reports: a bet that was rejected, a round that never resolved, or a
  /// connection that could not be kept.
  void _onProblem(Lucky16Problem problem) {
    if (!mounted || _stopped) return;
    if (problem.reason == Lucky16Error.insufficientCoins) {
      showInsufficientCoinsDialog(context);
      return;
    }
    final dialog = lucky16ProblemDialog(problem);
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

  /// The round sync lost the connection (three failed polls in a row). A connection that comes back
  /// does not take the dialog away, and a second outage does not stack a second one: OK is the only way
  /// out of it and OK ends the session, so one dialog per visit is all there is.
  void _onSync() {
    final sync = _provider.sync;
    final reason = sync.connectionError;
    if (sync.isConnected || reason == null) return;
    if (!mounted || _stopped) return;
    _showSessionEnding(lucky16DialogForConnection(reason));
  }

  /// The dialog that cannot be skipped: OK gives back the chips that were never sent, logs the player
  /// out and closes the app, as Lucky Card does. Shown once per outage, and not at all while the
  /// away-too-long flow of main.dart is already closing the app.
  void _showSessionEnding(Lucky16ProblemDialog dialog) {
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
      _notice.show(kLucky16BalanceLine, duration: kLucky16BalanceLineTime, important: true);
    }
    _wasBalanceFailed = failed;
  }

  /// The light click of the card taps and buttons.
  void _lightClick() => HapticFeedback.selectionClick();

  /// The EXIT button and the back gesture: asks first, and leaves only on YES.
  Future<void> _requestExit() async {
    if (_asking) return;
    _asking = true;
    final leave = await Lucky16ExitDialog.show(context, onOpen: _sound.notification);
    _asking = false;
    if (leave == true && mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  /// The INFO button.
  void _showInfo() => Lucky16InfoDialog.show(
        context,
        provider: _provider,
        art: _art,
        onOpen: _sound.notification,
        onTab: (_) => _sound.buttonClick(),
      );

  /// The HISTORY button: the popup reads the database itself and closes by itself when betting closes.
  void _showHistory() => Lucky16HistoryDialog.show(
        context,
        provider: _provider,
        history: _history,
        since: _sessionStart(),
        art: _art,
        onOpen: _sound.notification,
        onRow: _sound.notification,
      );

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
    // The phone's own insets (a notch, a cut-out, the system bars), read here above the SafeArea
    // that is about to consume them, so the header's paint can reach under them.
    final insets = MediaQuery.paddingOf(context);
    final canvas = SafeArea(
      left: false,
      right: false,
      child: Lucky16BoardBinding(
        provider: _provider,
        art: _art,
        onRefused: (target, issues) => _refusal(issues),
        onTapped: (target, result) {
          // When the tap changed the board: a single card makes the number-select sound, a bar the chip
          // click; both with the light haptic, as Lucky Card.
          if (result.changedAnything) {
            if (target is Lucky16CardTarget) {
              _sound.numberSelect();
            } else {
              _sound.chipClick();
            }
            _lightClick();
          }
        },
        builder: (context, zones) => Lucky16Canvas(
          layoutOf: (screen) => Lucky16Layout.of(screen, desktopPlatform: _desktopPlatform),
          // The background is the screen's own, behind the safe area (below).
          background: const SizedBox.shrink(),
          topBar: (context, layout) => Lucky16TopBarBinding(
            provider: _provider,
            layout: layout,
            art: _art,
            bleed: EdgeInsets.only(top: insets.top),
            soundOn: !_sound.muted,
            onExit: _requestExit,
            onToggleSound: _toggleSound,
            onInfo: _showInfo,
            onHistory: _showHistory,
            // The header carries the round's status and, for a moment, a refused tap's warning.
            notice: _notice,
          ),
          // Phase 2: the betting board -- the four suit bars over the 16 cards, and the four rank
          // selectors -- while betting is open. Phase 4: once it closes (countdown 5) the board's place
          // holds the wheel and, beside it, the reveal card, until the next round opens.
          // On the desktop the board and the selectors stay where they are (dimmed by their own lock).
          grid: (context, layout) => layout.isDesktop
              ? zones.grid(context, layout)
              : Lucky16RegionSwap(
                  provider: _provider,
                  betting: (context) => zones.grid(context, layout),
                  reveal: (context) => Lucky16WheelBinding(
                    provider: _provider,
                    layout: layout,
                    // The first ding, for the rank rim, and the wheel's own sound from the start of the spin
                    // (the second ding, for the suit rim, comes from the sound director).
                    onSpinStart: _sound.wheelSpin,
                    onRankLanded: _sound.ding,
                  ),
                ),
          rankColumn: (context, layout) => layout.isDesktop
              ? zones.rankColumn(context, layout)
              : Lucky16RegionSwap(
                  provider: _provider,
                  betting: (context) => zones.rankColumn(context, layout),
                  reveal: (context) => Lucky16RevealColumn(provider: _provider, layout: layout, art: _art),
                ),
          // Phase 3: the bet panel -- PLAY / WIN, the twelve latest results, the five chips and
          // DOUBLE (or REBET), CLEAR and REMOVE.
          side: (context, layout) => layout.isDesktop
              ? Lucky16DesktopSide(
                  provider: _provider,
                  layout: layout,
                  art: _art,
                  onSpinStart: _sound.wheelSpin,
                  onRankLanded: _sound.ding,
                )
              : Lucky16SideColumn(
                  provider: _provider,
                  layout: layout,
                  art: _art,
                  onChipSelected: (_) => _sound.buttonClick(),
                  onButtonRefused: (control, issues) => _refusal(issues),
                  onButtonPressed: (_) {
                    _sound.buttonClick();
                    _lightClick();
                  },
                ),
          // The desktop's results row and its bar of chips and buttons.
          resultsBar: (context, layout) => Lucky16ResultsBarBinding(provider: _provider, layout: layout, art: _art),
          actionBar: (context, layout) => Lucky16ActionBar(
            provider: _provider,
            layout: layout,
            art: _art,
            onChipSelected: (_) => _sound.buttonClick(),
            onButtonRefused: (control, issues) => _refusal(issues),
            onButtonPressed: (_) {
              _sound.buttonClick();
              _lightClick();
            },
          ),
          // A tablet's chips are in a bar under the board; a phone has no such zone.
          chipBar: (context, layout) => Lucky16ChipBar(
            provider: _provider,
            layout: layout,
            art: _art,
            onChipSelected: (_) => _sound.buttonClick(),
          ),
          // Phase 5: the coins and the win popup over everything, for a winning round.
          overlay: (context, layout) => Lucky16RevealOverlay(
            provider: _provider,
            layout: layout,
            art: _art,
            onCoinsStart: _sound.coin,
            onPopupOpen: _sound.win,
          ),
        ),
      ),
    );
    final game = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: Lucky16Background(art: _art)),
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
