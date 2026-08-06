import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/auth_provider.dart';
import '../services/sound_service.dart';
import '../services/round_sync_service.dart';
import '../theme/app_colors.dart';
import '../widgets/wheel/wheel_widget.dart';
import '../widgets/panels/left_tab_strip.dart';
import '../widgets/controls/right_panel.dart';
import '../widgets/overlays/result_overlay.dart';
import '../models/play_limits_config.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _allowPop = false;
  late GameProvider _gameProvider;

  @override
  void initState() {
    super.initState();
    SoundService().setInGameScreen(true);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameProvider = context.read<GameProvider>();
      final auth = context.read<AuthProvider>();
      auth.suspendHeartbeatPolling();
      auth.setUncommittedBetGetter(() => _gameProvider.uncommittedStake);
      _gameProvider.setAutoSpinCallback(_handleSpin);
      // Attach RoundSyncService — syncs timer to server and listens for results
      RoundSyncService().attach(_gameProvider, auth);
    });
  }


  Future<void> _handleSpin() async {
    final game = context.read<GameProvider>();
    final auth = context.read<AuthProvider>();

    if (game.isSpinning) return;

    game.closeDrawer();

    // CRITICAL FIX: Freeze the heartbeat timer as the ABSOLUTE FIRST operation.
    // This closes the race window where markBetsSubmitted() sets uncommittedStake=0
    // BEFORE submitBets() has sent the deduction to the DB. Without this lock,
    // the 15s heartbeat can fire during that 100-500ms gap, read the stale pre-bet
    // balance (42) from the DB, and set auth.balance = 42 - 0 = 42 (wrong).
    // That corrupts balanceAtSpinStart in onGlobalResult → win math is off by the stake.
    auth.holdHeartbeatBalance();

    game.markBetsSubmitted();

    final sync = RoundSyncService();

    // 1. Submit bets to server if player placed any
    if (!game.board.isEmpty) {
      final singleBets = Map<String, int>.from(game.board.single);
      final doubleBets = Map<String, int>.from(game.board.double_);
      final tripleBets = Map<String, int>.from(game.board.triple);
      final totalStake = game.totalBet;

      final success = await sync.submitBets(
        singleBets: singleBets,
        doubleBets: doubleBets,
        tripleBets: tripleBets,
        totalStake: totalStake,
        token:      auth.token,
        auth:       auth,
      );

      if (!success) {
        auth.releaseHeartbeatBalance();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bet submission failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // 2. FETCH RESULT EXACTLY ONCE! (For both bettors and spectators)
    await sync.fetchAndDeliverResult(game, auth);
  }


  @override
  void dispose() {
    SoundService().setInGameScreen(false);
    SoundService().stopAll();
    RoundSyncService().detach();
    try {
      final auth = context.read<AuthProvider>();
      auth.setUncommittedBetGetter(null);
      auth.resumeHeartbeatPolling();
    } catch (_) {}
    _gameProvider.abortSpin();
    _gameProvider.stopCountdown();
    _gameProvider.setAutoSpinCallback(null);
    _gameProvider.clearRebetSnapshot();
    _gameProvider.clearSpinHistory();
    super.dispose();
  }


  Future<bool?> _showExitConfirmation(BuildContext context) {
    bool isClosed = false;
    SoundService().playNotification();
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'ExitConfirmation',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        Future.delayed(const Duration(seconds: 5), () {
          if (ctx.mounted && !isClosed && Navigator.of(ctx).canPop()) {
            isClosed = true;
            Navigator.of(ctx).pop(false);
          }
        });

        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF220500), Color(0xFF0C0200)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.goldPrimary.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldPrimary.withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                    const BoxShadow(
                      color: Colors.black87,
                      blurRadius: 25,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Warning icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3E0800),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.goldBright,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Title
                      const Text(
                        'EXIT GAME',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: AppColors.goldBright,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Message
                      const Text(
                        'Do you want to exit?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Actions (YES / NO buttons side-by-side)
                      Row(
                        children: [
                          // NO button (Stay) - Green 3D Button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (!isClosed) {
                                  isClosed = true;
                                  Navigator.of(ctx).pop(false);
                                }
                              },
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF55FF55), Color(0xFF00AA00), Color(0xFF005500)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF99FF99), width: 1.2),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'NO',
                                    style: TextStyle(
                                      fontFamily: 'DMSans',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // YES button (Exit) - Red 3D Button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (!isClosed) {
                                  isClosed = true;
                                  Navigator.of(ctx).pop(true);
                                }
                              },
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF5555), Color(0xFFCC0000), Color(0xFF660000)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFFAAAA), width: 1.2),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'YES',
                                    style: TextStyle(
                                      fontFamily: 'DMSans',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }

  void _showInsufficientCoinsDialog(BuildContext context) {
    bool isClosed = false;
    SoundService().playNotification();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'InsufficientCoins',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        Future.delayed(const Duration(seconds: 5), () {
          if (ctx.mounted && !isClosed && Navigator.of(ctx).canPop()) {
            isClosed = true;
            Navigator.of(ctx).pop();
          }
        });

        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF220500), Color(0xFF0C0200)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.goldPrimary.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldPrimary.withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                    const BoxShadow(
                      color: Colors.black87,
                      blurRadius: 25,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glowing Warning Icon
                      Image.asset(
                        'assets/images/bsg_coin.webp',
                        width: 64,
                        height: 64,
                      ),
                      const SizedBox(height: 14),

                      // Title (DMSans)
                      const Text(
                        'INSUFFICIENT COINS',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Color(0xFFFFD54F), // Gold yellow
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      // Subtitle
                      const Text(
                        'You do not have enough coins to place this bet. Please top up your balance or choose a lower chip amount.',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // OK Button (not full width, premium green gradient)
                      GestureDetector(
                        onTap: () {
                          if (!isClosed) {
                            isClosed = true;
                            SoundService().playButtonClick();
                            Navigator.of(ctx).pop();
                          }
                        },
                        child: Container(
                          height: 38,
                          width: 140, // Reduced width (not full width)
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF55FF55), Color(0xFF00AA00), Color(0xFF005500)], // Green 3D gradient
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF99FF99), width: 1.2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'OK',
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.white, // White text color
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = Provider.of<GameProvider>(context);
    if (game.error == 'INSUFFICIENT_COINS') {
      game.clearError();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInsufficientCoinsDialog(context);
      });
    }

    if (game.lastRejection.reason == BetRejectReason.cellMaxExceeded) {
      final boardName = game.lastRejection.board?.name.replaceAll('_', '').toUpperCase() ?? '';
      final cap = game.lastRejection.cap;
      game.clearRejection();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.fixed,
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            content: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.deepRed, AppColors.bgBase],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                border: const Border(
                  top: BorderSide(color: AppColors.goldPrimary, width: 2.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.casinoRed.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.goldBright, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$boardName PLAY LIMIT REACHED',
                      style: const TextStyle(
                        color: AppColors.goldBright,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Text(
                    'Max $cap / number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      });
    }

    // Bug #7 fix: show a non-blocking warning if balance sync failed after spin.
    if (game.balanceSyncFailed) {
      game.clearBalanceSyncFailed();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.fixed,
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            content: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A3000), Color(0xFF1A1000)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                border: const Border(
                  top: BorderSide(color: Color(0xFFFFA500), width: 2.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.sync_problem_rounded, color: Color(0xFFFFA500), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Balance sync failed — your balance will update on the next round.',
                      style: TextStyle(
                        color: Color(0xFFFFA500),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      });
    }

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final exit = await _showExitConfirmation(context);
        if (exit == true && context.mounted) {
          setState(() => _allowPop = true);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          // Tap outside drawer to close it
          onTap: () {
            final game = context.read<GameProvider>();
            if (game.isDrawerOpen) game.closeDrawer();
          },
          behavior: HitTestBehavior.translucent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background ──────────────────────────────────────────
              Image.asset('assets/images/bg_lobby.webp', fit: BoxFit.cover),
  
              // ── Dark gradient overlay (top + bottom) ────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x66000000), Colors.transparent, Color(0x66000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
  
              // ── Main game layout ────────────────────────────────────
              Stack(
                fit: StackFit.expand,
                children: [
                  // Center — wheel (stationary, filling space between tabs and right panel, drawn UNDER panels)
                  Positioned(
                    left: 158.0, // Fixed width of the closed tabs
                    top: 0,
                    bottom: 0,
                    right: MediaQuery.of(context).size.width * 0.28,
                    child: Consumer<GameProvider>(
                      builder: (context, game, child) {
                        return ClipRect(
                          child: GestureDetector(
                            onTap: () {
                              if (game.isDrawerOpen) game.closeDrawer();
                            },
                            child: const WheelWidget(),
                          ),
                        );
                      },
                    ),
                  ),

                  // Left accordion panel (expands ON TOP of the wheel)
                  const Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: LeftAccordionPanel(),
                  ),

                  // Right control panel (Fixed 28% width)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: MediaQuery.of(context).size.width * 0.28,
                    child: RightControlPanel(onSpin: _handleSpin),
                  ),
                ],
              ),
  
              // ── Result overlay ───────────────────────────────────────
              Consumer<GameProvider>(
                builder: (_, game, __) =>
                  (game.lastResult != null && game.lastResult!.won)
                    ? const ResultOverlay()
                    : const SizedBox.shrink(),
              ),

              // ── No Connection overlay ────────────────────────────────
              ListenableBuilder(
                listenable: RoundSyncService(),
                builder: (context, _) {
                  final sync = RoundSyncService();
                  if (sync.isConnected || sync.isConnecting && sync.connectionError == null) {
                    return const SizedBox.shrink();
                  }
                  // Show banner only when truly disconnected
                  if (sync.connectionError != 'NO_CONNECTION') {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _NoConnectionBanner(
                      onRetry: () {
                        final game = context.read<GameProvider>();
                        final auth = context.read<AuthProvider>();
                        sync.retry(game, auth);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner shown at the top of the game screen when internet is lost.
class _NoConnectionBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _NoConnectionBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xCC3A0000), Color(0xCC1A0000)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: const Border(
              bottom: BorderSide(color: AppColors.goldPrimary, width: 1.5),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: AppColors.goldBright, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'NO INTERNET CONNECTION — Game paused',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFF8B6914)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'RETRY',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: Color(0xFF350000),
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
