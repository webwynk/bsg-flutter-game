// The words the Lucky 16 Card screen says when something goes wrong. Copied from
// lib/widgets/lucky_card/lucky_card_messages.dart (Lucky Card), with Lucky 16 Card's limit (10,000).
//
//   * [lucky16RefusalLine]: the short line for a refused tap, shown for 2 seconds in the
//     header (not enough coins, no chip in hand, nothing to take back). Anything else is
//     silent: a closed table already dims the controls.
//   * [lucky16LimitSnackBar]: a card already at its largest stake (10,000) is answered by a
//     snackbar at the bottom, as Triple Chance answers its PLAY LIMIT REACHED (the user's
//     decision of 2026-10-23), not by a header line.
//   * [lucky16ProblemDialog]: what Triple Chance's shared dialog says for each kind of
//     problem the provider reports, in Triple Chance's own words (the bet was rejected, the
//     round never resolved, the connection was lost, the account is blocked).
//   * [Lucky16Notice]: the one line shown in the header, with its timer.
//
// Plain functions, so every word and every number is tested against the game's rules.
//
// Belongs to Lucky 16 Card only.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/lucky16_board.dart';
import '../../models/lucky16_models.dart';
import '../../providers/lucky16_provider.dart';
import '../../theme/app_colors.dart';
import '../common/game_bottom_banner.dart';
import 'lucky16_panel.dart';

/// How long a refusal line stays.
const Duration kLucky16RefusalLineTime = Duration(seconds: 2);

/// How long the "balance not confirmed" line stays (Triple Chance's bar stays 6 seconds).
const Duration kLucky16BalanceLineTime = Duration(seconds: 6);

/// What the header says when a round's balance could not be confirmed.
const String kLucky16BalanceLine = 'BALANCE NOT CONFIRMED - IT WILL UPDATE NEXT ROUND';

/// True when the tap was refused because a card is already at its largest stake (and not
/// because the coins ran out, which is the more useful thing to say): the screen answers with
/// [lucky16LimitSnackBar], not with a header line.
bool lucky16RefusalIsLimit(Set<Lucky16BoardIssue> issues) =>
    issues.contains(Lucky16BoardIssue.cardAtMaximum) && !issues.contains(Lucky16BoardIssue.notEnoughCoins);

/// How long the limit snackbar stays (Triple Chance's own is 3 seconds).
const Duration kLucky16LimitSnackBarTime = Duration(seconds: 3);

/// The snackbar for a card at its largest stake: a full-width bar at the bottom in Triple
/// Chance's own look (deep red to black, gold line on top, a warning icon, gold words and the
/// maximum in white), reading CARD PLAY LIMIT REACHED and "Max 10,000 / card".
/// Drawn by the shared bottom banner: edge to edge and sized for the device (Hasan, 2026-10-25).
SnackBar lucky16LimitSnackBar() => gameBottomBanner(
      key: const ValueKey('limit-snackbar'),
      icon: Icons.warning_amber_rounded,
      text: 'CARD PLAY LIMIT REACHED',
      detail: 'Max ${lucky16Grouped(kLucky16MaxStake)} / card',
      iconColor: AppColors.goldBright,
      textColor: AppColors.goldBright,
      gradient: const [AppColors.deepRed, AppColors.bgBase],
      edge: AppColors.goldPrimary,
      glow: AppColors.casinoRed.withValues(alpha: 0.4),
      duration: kLucky16LimitSnackBarTime,
    );

/// The line for a refused tap, or null when nothing should be said. When several reasons
/// came together the most useful one wins. (A card at its largest stake has no line: see
/// [lucky16RefusalIsLimit].)
String? lucky16RefusalLine(Set<Lucky16BoardIssue> issues) {
  if (issues.contains(Lucky16BoardIssue.notEnoughCoins)) return 'NOT ENOUGH COINS';
  if (issues.contains(Lucky16BoardIssue.noChipSelected)) return 'PICK A CHIP FIRST';
  if (issues.contains(Lucky16BoardIssue.nothingToRemove)) return 'NOTHING TO TAKE BACK';
  return null;
}

/// What Triple Chance's shared dialog shows for one problem.
@immutable
class Lucky16ProblemDialog {
  const Lucky16ProblemDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.endsSession,
    this.autoDismiss,
  });

  final IconData icon;
  final String title;
  final String message;

  /// True for a lost connection or a blocked account: the dialog cannot be skipped, and
  /// pressing OK logs the player out.
  final bool endsSession;

  /// How long before a dialog that may be skipped closes by itself.
  final Duration? autoDismiss;
}

const Duration _kAutoDismiss = Duration(seconds: 5);

/// The dialog for a problem the provider reported. Triple Chance's words, kind by kind.
Lucky16ProblemDialog lucky16ProblemDialog(Lucky16Problem problem) {
  switch (problem.kind) {
    case Lucky16ProblemKind.roundUnresolved:
      return const Lucky16ProblemDialog(
        icon: Icons.sync_problem_rounded,
        title: 'SERVER ERROR',
        message:
            'This round is taking longer than expected to resolve. Your balance will update automatically once it\'s ready.',
        endsSession: false,
        autoDismiss: _kAutoDismiss,
      );
    case Lucky16ProblemKind.connectionProblem:
      return problem.reason == Lucky16Error.accountBlocked ? lucky16BlockedDialog : lucky16ConnectionLostDialog;
    case Lucky16ProblemKind.betRejected:
      final (title, message) = switch (problem.reason) {
        Lucky16Error.insufficientCoins => (
            'INSUFFICIENT COINS',
            'You did not have enough coins for this bet when the round closed. Your coins have been returned.',
          ),
        Lucky16Error.roundClosed => (
            'ROUND CLOSED',
            'Betting for that round closed before your bet arrived. Your coins have been returned — please try the next round.',
          ),
        Lucky16Error.notAPlayer => (
            'ACCOUNT NOT ELIGIBLE',
            'This account cannot place bets. Please contact your agent or support.',
          ),
        Lucky16Error.unknown => (
            'BET NOT PLACED',
            'Something went wrong on our end and your bet could not be placed. Your coins have been returned — please try the next round.',
          ),
        _ => (
            'BET NOT PLACED',
            'Your bet could not be sent to the server. Your coins have been returned — please try the next round.',
          ),
      };
      return Lucky16ProblemDialog(
        icon: Icons.report_gmailerrorred_rounded,
        title: title,
        message: message,
        endsSession: false,
        autoDismiss: _kAutoDismiss,
      );
  }
}

/// The connection could not be kept: the player will be logged out.
const Lucky16ProblemDialog lucky16ConnectionLostDialog = Lucky16ProblemDialog(
  icon: Icons.wifi_off_rounded,
  title: 'CONNECTION LOST',
  message:
      'Could not stay connected to the server. For your safety you will be logged out — please sign back in once reconnected.',
  endsSession: true,
);

/// The account has been blocked: the player will be logged out.
const Lucky16ProblemDialog lucky16BlockedDialog = Lucky16ProblemDialog(
  icon: Icons.error_outline_rounded,
  title: 'ACCOUNT BLOCKED',
  message: 'Your account has been blocked. Please contact your agent. You will be logged out.',
  endsSession: true,
);

/// The dialog for a lost connection found by the round sync, from the reason it gives.
Lucky16ProblemDialog lucky16DialogForConnection(Lucky16Error reason) =>
    reason == Lucky16Error.accountBlocked ? lucky16BlockedDialog : lucky16ConnectionLostDialog;

/// The one line the header shows in place of the round's status words, for a short time.
class Lucky16Notice extends ChangeNotifier {
  String? _text;
  bool _important = false;
  Timer? _timer;

  /// The line, or null when there is none.
  String? get text => _text;

  /// An important line (a warning about the balance) may be shown even while betting is
  /// closed; an ordinary refusal line only while it is open.
  bool get important => _important;

  /// Shows [text] for [duration]; a new line replaces the old one and restarts the time.
  void show(String text, {Duration duration = kLucky16RefusalLineTime, bool important = false}) {
    _timer?.cancel();
    _text = text;
    _important = important;
    _timer = Timer(duration, clear);
    notifyListeners();
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    if (_text == null) return;
    _text = null;
    _important = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
