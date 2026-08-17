import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_contract.dart';
import '../services/sound_service.dart';
import '../services/round_sync_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_exit.dart';
import '../widgets/dialogs/action_dialog.dart';
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
  // F-7: nullable, not late. This is assigned in a post-frame callback, so
  // popping the screen before the first frame completed made dispose() throw
  // LateInitializationError and crash the app.
  GameProvider? _gameProvider;
  // Issue #10 fix: cached the same way as _gameProvider, for the same reason
  // -- context.read<AuthProvider>() inside dispose() (see below) is wrapped
  // in a try/catch specifically because it can fail there, which was
  // silently skipping the mid-round-exit refund this field exists to fix.
  AuthProvider? _authProvider;
  // Tracks which BetError reason the connection-lost dialog was last shown
  // for, so it's shown once per distinct disconnection rather than once per
  // rebuild (RoundSyncService can notify repeatedly while still down).
  bool _connectionDialogShowing = false;

  @override
  void initState() {
    super.initState();
    SoundService().setInGameScreen(true);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final game = context.read<GameProvider>();
      _gameProvider = game;
      final auth = context.read<AuthProvider>();
      _authProvider = auth;
      // M-5: the heartbeat timer itself is no longer suspended here (that used
      // to use a lock that could leak and freeze the balance forever).
      // Ordering is handled by ledger_version instead; the getter below stays
      // because chips on the board are deducted locally and have no
      // counterpart in the database until betting closes.
      auth.setUncommittedStakeGetter(() => _gameProvider?.uncommittedStake ?? 0);
      // Issue #48 amendment: the heartbeat still runs every 15s (including its
      // blocked-account check, never skipped), but won't *apply* a balance it
      // fetches while a spin is actively revealing -- stateless read each
      // tick, not a lock, so a skipped tick just tries again next time.
      auth.setIsSpinningGetter(() => _gameProvider?.isSpinning ?? false);
      game.setAutoSpinCallback(_handleSpin, noBetsCallback: _handleEarlyBetSubmission);
      // Attach RoundSyncService — syncs timer to server and listens for results
      RoundSyncService().attach(game, auth);
    });
  }

  Future<void> _handleEarlyBetSubmission() async {
    final game = context.read<GameProvider>();
    final auth = context.read<AuthProvider>();

    if (game.isSpinning || game.board.isEmpty) return;

    game.closeDrawer();
    game.markBetsSubmitted();

    final sync = RoundSyncService();

    final minViolation = game.validateMinimums();
    if (minViolation != null) {
      game.refundRejectedBets(auth);
      if (mounted) _showBetRejectedDialog(context, 'BELOW_MIN');
      return;
    }

    final singleBets = Map<String, int>.from(game.board.single);
    final doubleBets = Map<String, int>.from(game.board.double_);
    final tripleBets = Map<String, int>.from(game.board.triple);

    final accepted = await sync.submitBets(
      singleBets: singleBets,
      doubleBets: doubleBets,
      tripleBets: tripleBets,
      auth:       auth,
      game:       game,
    );

    if (!accepted) {
      // Refund unconditionally here, same as always -- if this turns out to
      // be a connectivity failure and routes to the severe dialog below, its
      // own OK-button abortSpin() will find the board already empty and
      // simply no-op the refund it would otherwise attempt (it only refunds
      // when !submittedBets, which markBetsSubmitted() already set true
      // before this call ran, so it can't be relied on alone here).
      game.refundRejectedBets(auth);
      if (mounted) {
        final reason = sync.lastSubmitError;
        // Issue #57: accountBlocked must route here too -- it's a real
        // account-status fact, not a connectivity problem, and this is the
        // dialog that already renders it correctly (see
        // _showConnectionLostDialog's own accountBlocked case below).
        // Falling through to _showBetRejectedDialog's generic fallback
        // showed "Bet Not Placed" instead of telling the player why.
        if (reason == BetError.offline ||
            reason == BetError.unauthenticated ||
            reason == BetError.accountBlocked) {
          _showConnectionLostDialogGuarded(context, reason!);
        } else {
          _showBetRejectedDialog(context, reason);
        }
      }
    }
  }

  Future<void> _handleSpin() async {
    final game = context.read<GameProvider>();
    final auth = context.read<AuthProvider>();

    if (game.isSpinning) return;

    game.closeDrawer();

    final sync = RoundSyncService();

    // 1. Submit bets to server if player placed any that haven't been submitted yet
    if (!game.board.isEmpty && game.betStatus != BetSubmissionStatus.submitted) {
      game.markBetsSubmitted();

      final minViolation = game.validateMinimums();
      if (minViolation != null) {
        game.refundRejectedBets(auth);
        if (mounted) _showBetRejectedDialog(context, 'BELOW_MIN');
        // Still fetches the round's result for the wheel animation (this
        // player is now a spectator for this round) -- but deliberately
        // doesn't react to a false return with a second dialog on top of
        // the BELOW_MIN one just shown above; nothing was staked here to
        // refund a second time.
        await sync.fetchAndDeliverResult(game, auth);
        return;
      }

      final singleBets = Map<String, int>.from(game.board.single);
      final doubleBets = Map<String, int>.from(game.board.double_);
      final tripleBets = Map<String, int>.from(game.board.triple);

      final accepted = await sync.submitBets(
        singleBets: singleBets,
        doubleBets: doubleBets,
        tripleBets: tripleBets,
        auth:       auth,
        game:       game,
      );

      if (!accepted) {
        // See _handleEarlyBetSubmission for why refund is unconditional here.
        game.refundRejectedBets(auth);
        if (mounted) {
          final reason = sync.lastSubmitError;
          // Issue #57: same fix as _handleEarlyBetSubmission -- see its
          // comment for why accountBlocked must route here too.
          if (reason == BetError.offline ||
              reason == BetError.unauthenticated ||
              reason == BetError.accountBlocked) {
            _showConnectionLostDialogGuarded(context, reason!);
          } else {
            _showBetRejectedDialog(context, reason);
          }
        }
      }
    }

    // 2. FETCH RESULT EXACTLY ONCE! (For both bettors and spectators)
    final delivered = await sync.fetchAndDeliverResult(game, auth);
    // Issue #14: the round genuinely never resolved server-side within the
    // retry budget. Deliberately does NOT call refundRejectedBets here --
    // that only changes the on-screen number, not the server's real
    // balance, and place_bet already deducted the stake for real the moment
    // this bet was accepted. Claiming a refund that hasn't actually happened
    // would be reversed a few seconds later by the next honest balance
    // sync, with no explanation. Just tell the player the truth instead:
    // the round is unresolved, their real balance will catch up
    // automatically via the normal sync path once it's ready.
    if (!delivered && mounted) {
      _showServerErrorDialog(context);
    }
  }


  @override
  void dispose() {
    SoundService().setInGameScreen(false);
    SoundService().stopAll();
    RoundSyncService().detach();
    // Issue #10 fix: use the cached reference (set in initState's post-frame
    // callback, same pattern as _gameProvider below) instead of
    // context.read<AuthProvider>() here -- that call was wrapped in a
    // try/catch specifically because it can fail at this exact point in the
    // widget lifecycle, which was silently skipping the refund below.
    final auth = _authProvider;
    if (auth != null) {
      auth.setUncommittedStakeGetter(null);
      auth.setIsSpinningGetter(null);
    }
    final game = _gameProvider;
    if (game != null) {
      game.abortSpin(auth);
      game.stopCountdown();
      game.setAutoSpinCallback(null);
      game.clearRebetSnapshot();
    }
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

  /// M-3 FIX: explains why a bet the player already "paid" for was not accepted.
  /// [reason] is a sentinel from RoundApiService._mapSubmitError.
  /// BELOW_MIN and EXCEEDS_MAX deliberately have no case here anymore --
  /// both fall to the generic fallback below. Every direct chip-placement
  /// path (confirmed: all 4 of them) already hard-blocks a chip before it
  /// can go under the board minimum or over its maximum, and the in-game
  /// "PLAY LIMIT REACHED" snackbar already covers the max side live as it
  /// happens. The one remaining gap -- REBET restoring a stale snapshot
  /// against limits that changed since the previous round -- was confirmed
  /// and explicitly accepted: coins are still correctly refunded either way,
  /// only the specific wording differs. Issue #46 later disabled the REBET
  /// button itself when unaffordable, which narrows but doesn't fully close
  /// this specific gap.
  ///
  /// OFFLINE and UNAUTHENTICATED deliberately have no case here either --
  /// both are now intercepted at the call site (see
  /// `_handleEarlyBetSubmission`/`_handleSpin`) after all retries are
  /// exhausted, and routed to the merged, severe `_showConnectionLostDialog`
  /// instead: those two reasons mean a real connectivity/session problem,
  /// which deserves the "you'll be logged out" treatment, not this dialog's
  /// "stay in the game" one.
  void _showBetRejectedDialog(BuildContext context, String? reason) {
    final (title, message) = switch (reason) {
      'INSUFFICIENT_COINS' => (
        'INSUFFICIENT COINS',
        'You did not have enough coins for this bet when the round closed. Your coins have been returned.'
      ),
      'ROUND_CLOSED' => (
        'ROUND CLOSED',
        'Betting for that round closed before your bet arrived. Your coins have been returned — please try the next round.'
      ),
      // Issue #23: NOT_A_PLAYER means the server rejected this bet before
      // touching the balance at all (place_bet's role check runs before any
      // apply_coin_movement call -- verified directly against the live SQL),
      // so there is nothing to "return" here, unlike the other cases above.
      // A genuine account/permissions problem, not a transient one -- worth
      // telling the player to contact support rather than "try next round".
      'NOT_A_PLAYER' => (
        'ACCOUNT NOT ELIGIBLE',
        'This account cannot place bets. Please contact your agent or support.'
      ),
      // Issue #23: the honest catch-all for a genuinely unrecognized server
      // error, after retries already failed -- kept deliberately separate
      // from the default message below so a future bespoke case can be added
      // here without disturbing UNKNOWN's own wording.
      'UNKNOWN' => (
        'BET NOT PLACED',
        'Something went wrong on our end and your bet could not be placed. Your coins have been returned — please try the next round.'
      ),
      _ => (
        'BET NOT PLACED',
        'Your bet could not be sent to the server. Your coins have been returned — please try the next round.'
      ),
    };

    showActionDialog(
      context,
      icon: Icons.report_gmailerrorred_rounded,
      title: title,
      message: message,
      barrierDismissible: true,
      autoDismissAfter: const Duration(seconds: 5),
    );
  }

  /// Issue #14: shown when a round genuinely fails to resolve server-side
  /// (the draw itself never completed, not a connectivity/session problem --
  /// those still go to the severe _showConnectionLostDialog). One honest,
  /// reusable message for "the server had a problem, not you, not your
  /// wifi" -- rather than a bespoke message per failure mode. Same
  /// stay-in-the-game treatment as _showBetRejectedDialog: this doesn't end
  /// the session, the player just continues to the next round.
  ///
  /// Deliberately does NOT claim coins were refunded: place_bet deducts the
  /// stake from the server-side balance the moment a bet is accepted, well
  /// before the round is ever drawn. If this round never resolved, that
  /// deduction is still real and hasn't been reversed by anything -- saying
  /// otherwise here would be an outright false statement that the very next
  /// heartbeat/round-poll balance sync would silently contradict a few
  /// seconds later. The truthful state is "unresolved, will update once
  /// it's ready" -- the server's own authoritative balance is always what
  /// actually displays, via the normal sync path, whatever that turns out
  /// to be.
  void _showServerErrorDialog(BuildContext context) {
    showActionDialog(
      context,
      icon: Icons.sync_problem_rounded,
      title: 'SERVER ERROR',
      message: 'This round is taking longer than expected to resolve. Your balance will update automatically once it\'s ready.',
      barrierDismissible: true,
      autoDismissAfter: const Duration(seconds: 5),
    );
  }

  /// Shared entry point for [_showConnectionLostDialog], reused by both the
  /// background poll (via the ListenableBuilder below) and a failed bet
  /// submission (see `_handleEarlyBetSubmission`/`_handleSpin`) -- the two
  /// can plausibly fire around the same moment during a real outage (the
  /// background poll keeps failing every 2s while a submission is retrying),
  /// so both routes go through this one guard rather than each tracking
  /// "showing" independently, which would let them stack a duplicate dialog.
  void _showConnectionLostDialogGuarded(BuildContext context, String reason) {
    if (_connectionDialogShowing) return;
    _connectionDialogShowing = true;
    _showConnectionLostDialog(context, reason);
  }

  /// Shown whenever RoundSyncService can't reach the server for any reason.
  /// Replaces the old top-of-screen banner. Every connectivity/server reason
  /// (offline, session expired, unrecognized server error) now shares one
  /// merged message -- the player doesn't need to diagnose *why*, only that
  /// they'll be logged out for their safety and can sign back in. The one
  /// deliberate exception is accountBlocked: that's a real account-status
  /// fact ("your agent blocked you"), not a connectivity problem, so folding
  /// it into the generic message would mislead the player into thinking
  /// it's a network issue rather than something to contact their agent
  /// about -- same reasoning as why ROUND_CLOSED stays out of the merged
  /// Bet Rejected message. Every reason still ends the same way -- a full,
  /// clean logout. Not dismissible by tapping outside, by the system back
  /// button/gesture (see the PopScope in showActionDialog), or by an
  /// auto-timeout -- this needs a conscious tap on OK.
  void _showConnectionLostDialog(BuildContext context, String reason) {
    final (icon, title, message) = switch (reason) {
      BetError.accountBlocked => (
        Icons.error_outline_rounded,
        'ACCOUNT BLOCKED',
        'Your account has been blocked. Please contact your agent. You will be logged out.'
      ),
      _ => (
        Icons.wifi_off_rounded,
        'CONNECTION LOST',
        'Could not stay connected to the server. For your safety you will be logged out — please sign back in once reconnected.'
      ),
    };

    showActionDialog(
      context,
      icon: icon,
      title: title,
      message: message,
      barrierDismissible: false,
      onPressed: () async {
        // Order matters: refund/clear the board FIRST, while auth still has
        // a real, non-null user -- logging out first would silently defeat
        // any refund, since AuthProvider.updateBalance() no-ops once the
        // user is null. Handles all three of the user's described cases at
        // once: unsubmitted bet -> refunded and cleared; already-submitted
        // bet -> left alone to settle normally, board still cleared; no bet
        // at all -> nothing to do, straight through to logout.
        final game = context.read<GameProvider>();
        final auth = context.read<AuthProvider>();
        game.abortSpin(auth);
        // Awaited so the session is genuinely torn down (local storage
        // cleared, server notified) before the app closes -- closing first
        // would risk killing the process mid-cleanup.
        await auth.logout();
        closeApp();
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

              // ── No Connection / Session dialog ───────────────────────
              // Replaces the old thin top banner (which offered "RETRY" for
              // a dropped connection, only forcing logout for session/
              // account issues). Every disconnection reason except a genuine
              // account block now shows the same one merged "CONNECTION
              // LOST" popup and always ends in a full, clean logout -- no
              // ambiguous "maybe still connected" state to leave a
              // real-money session sitting in.
              ListenableBuilder(
                listenable: RoundSyncService(),
                builder: (context, _) {
                  final sync = RoundSyncService();
                  final reason = sync.connectionError;
                  if (sync.isConnected || reason == null) {
                    _connectionDialogShowing = false;
                    return const SizedBox.shrink();
                  }
                  // Show at most once per outage, regardless of how many
                  // times the reason changes while still disconnected (e.g.
                  // offline -> unauthenticated) or how many times
                  // RoundSyncService notifies (each failed poll) -- a
                  // reason-keyed guard would let those cases stack a second
                  // dialog on top of the first. Also skip entirely if the
                  // away-too-long flow is already closing the app -- showing
                  // a second, redundant popup right as the app is on its way
                  // out would be pointless and confusing.
                  if (!isClosingApp.value) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _showConnectionLostDialogGuarded(context, reason);
                    });
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

