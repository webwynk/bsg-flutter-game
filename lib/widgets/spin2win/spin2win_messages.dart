// What the Spin2Win screen says when something goes wrong, in Triple Chance's own words and looks
// (Hasan, 2026-10-24: "error popups, min/max banner: all exactly like Triple Chance"), the way
// Lucky Card does it:
//
//   * [spin2WinProblemDialog]: the words of Triple Chance's shared popup for each problem the
//     provider reports (a bet that was rejected, a round that never resolved, a lost connection,
//     a blocked account). The popup itself is Triple Chance's own `showActionDialog`, called, not
//     changed ([Spin2WinSharedAlerts]).
//   * Not enough coins for a chip, DOUBLE or REBET: Triple Chance's own INSUFFICIENT COINS popup
//     (`showInsufficientCoinsDialog`, called, not changed).
//   * A number already at 10,000: Triple Chance's PLAY LIMIT REACHED bar at the bottom for
//     3 seconds, reading "Max 10,000 / number" ([spin2WinLimitSnackBar]). The minimum needs no
//     message: the smallest chip is the minimum, so a number can never hold less.
//   * A round whose balance could not be confirmed: Triple Chance's orange bar for 6 seconds
//     ([spin2WinBalanceSnackBar]).
//
// Plain functions, so every word is tested.
//
// Belongs to Spin2Win only.

import 'package:flutter/material.dart';

import '../../models/spin2win_board.dart';
import '../../models/spin2win_models.dart';
import '../../providers/spin2win_provider.dart';
import '../../theme/app_colors.dart';
import '../common/game_bottom_banner.dart';
import '../dialogs/action_dialog.dart';
import 'spin2win_palette.dart';

/// What Triple Chance's shared popup shows for one problem.
@immutable
class Spin2WinProblemDialog {
  const Spin2WinProblemDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.endsSession,
    this.autoDismiss,
  });

  final IconData icon;
  final String title;
  final String message;

  /// True for a lost connection or a blocked account: the popup cannot be skipped, and OK logs
  /// the player out and closes the app, as in Triple Chance.
  final bool endsSession;

  /// How long before a popup that may be skipped closes by itself.
  final Duration? autoDismiss;
}

const Duration _kAutoDismiss = Duration(seconds: 5);

/// The connection could not be kept: the player will be logged out.
const Spin2WinProblemDialog kSpin2WinConnectionLostDialog = Spin2WinProblemDialog(
  icon: Icons.wifi_off_rounded,
  title: 'CONNECTION LOST',
  message:
      'Could not stay connected to the server. For your safety you will be logged out — please sign back in once reconnected.',
  endsSession: true,
);

/// The account has been blocked: the player will be logged out.
const Spin2WinProblemDialog kSpin2WinBlockedDialog = Spin2WinProblemDialog(
  icon: Icons.error_outline_rounded,
  title: 'ACCOUNT BLOCKED',
  message: 'Your account has been blocked. Please contact your agent. You will be logged out.',
  endsSession: true,
);

/// The round never resolved (not the player's connection).
const Spin2WinProblemDialog kSpin2WinServerErrorDialog = Spin2WinProblemDialog(
  icon: Icons.sync_problem_rounded,
  title: 'SERVER ERROR',
  message:
      'This round is taking longer than expected to resolve. Your balance will update automatically once it\'s ready.',
  endsSession: false,
  autoDismiss: _kAutoDismiss,
);

/// The popup for a lost connection found by the round sync, from the reason it gives.
Spin2WinProblemDialog spin2WinDialogForConnection(Spin2WinError? reason) =>
    reason == Spin2WinError.accountBlocked ? kSpin2WinBlockedDialog : kSpin2WinConnectionLostDialog;

/// The popup for a problem the provider reported, in Triple Chance's words. (Not enough coins is
/// answered with Triple Chance's own INSUFFICIENT COINS popup instead: see [Spin2WinAlerts].)
Spin2WinProblemDialog spin2WinProblemDialog(Spin2WinProblem problem) {
  switch (problem.kind) {
    case Spin2WinProblemKind.roundUnresolved:
      return kSpin2WinServerErrorDialog;
    case Spin2WinProblemKind.connectionProblem:
      return spin2WinDialogForConnection(problem.reason);
    case Spin2WinProblemKind.betRejected:
      final (title, message) = switch (problem.reason) {
        Spin2WinError.insufficientCoins => (
            'INSUFFICIENT COINS',
            'You did not have enough coins for this bet when the round closed. Your coins have been returned.',
          ),
        Spin2WinError.roundClosed => (
            'ROUND CLOSED',
            'Betting for that round closed before your bet arrived. Your coins have been returned — please try the next round.',
          ),
        Spin2WinError.notAPlayer => (
            'ACCOUNT NOT ELIGIBLE',
            'This account cannot place bets. Please contact your agent or support.',
          ),
        Spin2WinError.unknown => (
            'BET NOT PLACED',
            'Something went wrong on our end and your bet could not be placed. Your coins have been returned — please try the next round.',
          ),
        // BELOW_MIN and EXCEEDS_MAX fall here, as in Triple Chance: the board already stops a
        // chip from going past either limit.
        _ => (
            'BET NOT PLACED',
            'Your bet could not be sent to the server. Your coins have been returned — please try the next round.',
          ),
      };
      return Spin2WinProblemDialog(
        icon: Icons.report_gmailerrorred_rounded,
        title: title,
        message: message,
        endsSession: false,
        autoDismiss: _kAutoDismiss,
      );
  }
}

/// True when a refused tap gets the PLAY LIMIT REACHED bar: a number was at its maximum and the
/// coins did not run out (that is the more useful thing to say, with its own popup).
bool spin2WinRefusalIsLimit(Set<Spin2WinBoardIssue> issues) =>
    issues.contains(Spin2WinBoardIssue.numberAtMaximum) && !issues.contains(Spin2WinBoardIssue.notEnoughCoins);

/// How long the limit bar stays (Triple Chance's is 3 seconds).
const Duration kSpin2WinLimitSnackBarTime = Duration(seconds: 3);

/// How long the balance bar stays (Triple Chance's is 6 seconds).
const Duration kSpin2WinBalanceSnackBarTime = Duration(seconds: 6);

const String kSpin2WinLimitTitle = 'PLAY LIMIT REACHED';
final String kSpin2WinLimitDetail = 'Max ${spin2WinAmountText(kSpin2WinMaxStake)} / number';
const String kSpin2WinBalanceLine = 'Balance sync failed — your balance will update on the next round.';

/// Triple Chance's PLAY LIMIT REACHED bar, drawn by the shared bottom banner (edge to edge, sized
/// for the device): deep red to black with a gold line on top, a warning icon, gold words and the
/// maximum in white.
SnackBar spin2WinLimitSnackBar() => gameBottomBanner(
      key: const ValueKey('spin2win-limit-bar'),
      icon: Icons.warning_amber_rounded,
      text: kSpin2WinLimitTitle,
      detail: kSpin2WinLimitDetail,
      iconColor: AppColors.goldBright,
      textColor: AppColors.goldBright,
      gradient: const [AppColors.deepRed, AppColors.bgBase],
      edge: AppColors.goldPrimary,
      glow: AppColors.casinoRed.withValues(alpha: 0.4),
      duration: kSpin2WinLimitSnackBarTime,
    );

/// Triple Chance's orange "balance sync failed" bar, drawn by the shared bottom banner.
SnackBar spin2WinBalanceSnackBar() => gameBottomBanner(
      key: const ValueKey('spin2win-balance-bar'),
      icon: Icons.sync_problem_rounded,
      text: kSpin2WinBalanceLine,
      iconColor: const Color(0xFFFFA500),
      textColor: const Color(0xFFFFA500),
      gradient: const [Color(0xFF4A3000), Color(0xFF1A1000)],
      edge: const Color(0xFFFFA500),
      glow: Colors.orange.withValues(alpha: 0.3),
      textWeight: FontWeight.w700,
      letterSpacing: 0.4,
      duration: kSpin2WinBalanceSnackBarTime,
    );

/// How the screen puts a popup up. The real one calls Triple Chance's shared popups; a test hands
/// in one that only writes down what was asked.
abstract class Spin2WinAlerts {
  const Spin2WinAlerts();

  /// Triple Chance's INSUFFICIENT COINS popup.
  void insufficientCoins(BuildContext context);

  /// Triple Chance's popup with [dialog]'s words. [onSessionEnd] is called when OK is pressed on
  /// a popup that ends the session.
  void problem(BuildContext context, Spin2WinProblemDialog dialog, {VoidCallback? onSessionEnd});
}

/// The real popups: Triple Chance's own, called exactly as Lucky Card calls them.
class Spin2WinSharedAlerts extends Spin2WinAlerts {
  const Spin2WinSharedAlerts();

  @override
  void insufficientCoins(BuildContext context) => showInsufficientCoinsDialog(context);

  @override
  void problem(BuildContext context, Spin2WinProblemDialog dialog, {VoidCallback? onSessionEnd}) {
    showActionDialog(
      context,
      icon: dialog.icon,
      title: dialog.title,
      message: dialog.message,
      barrierDismissible: !dialog.endsSession,
      autoDismissAfter: dialog.endsSession ? null : dialog.autoDismiss,
      onPressed: dialog.endsSession ? onSessionEnd : null,
    );
  }
}
