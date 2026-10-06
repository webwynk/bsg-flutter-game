// The words the Lucky Card screen says when something goes wrong (App Step 8c, spec §17AG).
//
//   * [luckyCardRefusalLine]: the short line for a refused tap, shown for 2 seconds in the
//     status strip (not enough coins, a card at its limit, no chip in hand, nothing to take
//     back). Anything else is silent: a closed table already dims the controls.
//   * [luckyCardProblemDialog]: what Triple Chance's shared dialog says for each kind of
//     problem the provider reports, in Triple Chance's own words (the bet was rejected, the
//     round never resolved, the connection was lost, the account is blocked).
//   * [LuckyCardNotice]: the one line shown in the status strip, with its timer.
//
// Plain functions, so every word and every number is tested against the game's rules.
//
// Belongs to Lucky Card only.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/lucky_card_board.dart';
import '../../models/lucky_card_models.dart';
import '../../providers/lucky_card_provider.dart';
import 'lucky_card_panel.dart';

/// How long a refusal line stays.
const Duration kLuckyCardRefusalLineTime = Duration(seconds: 2);

/// How long the "balance not confirmed" line stays (Triple Chance's bar stays 6 seconds).
const Duration kLuckyCardBalanceLineTime = Duration(seconds: 6);

/// What the status strip says when a round's balance could not be confirmed.
const String kLuckyCardBalanceLine = 'BALANCE NOT CONFIRMED - IT WILL UPDATE NEXT ROUND';

/// The line for a refused tap, or null when nothing should be said. When several reasons
/// came together the most useful one wins.
String? luckyCardRefusalLine(Set<LuckyCardBoardIssue> issues) {
  if (issues.contains(LuckyCardBoardIssue.notEnoughCoins)) return 'NOT ENOUGH COINS';
  if (issues.contains(LuckyCardBoardIssue.cardAtMaximum)) return 'CARD AT ${luckyCardGrouped(kLuckyCardMaxStake)} LIMIT';
  if (issues.contains(LuckyCardBoardIssue.noChipSelected)) return 'PICK A CHIP FIRST';
  if (issues.contains(LuckyCardBoardIssue.nothingToRemove)) return 'NOTHING TO TAKE BACK';
  return null;
}

/// What Triple Chance's shared dialog shows for one problem.
@immutable
class LuckyCardProblemDialog {
  const LuckyCardProblemDialog({
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
LuckyCardProblemDialog luckyCardProblemDialog(LuckyCardProblem problem) {
  switch (problem.kind) {
    case LuckyCardProblemKind.roundUnresolved:
      return const LuckyCardProblemDialog(
        icon: Icons.sync_problem_rounded,
        title: 'SERVER ERROR',
        message: 'This round is taking longer than expected to resolve. Your balance will update automatically once it\'s ready.',
        endsSession: false,
        autoDismiss: _kAutoDismiss,
      );
    case LuckyCardProblemKind.connectionProblem:
      return problem.reason == LuckyCardError.accountBlocked ? luckyCardBlockedDialog : luckyCardConnectionLostDialog;
    case LuckyCardProblemKind.betRejected:
      final (title, message) = switch (problem.reason) {
        LuckyCardError.insufficientCoins => (
            'INSUFFICIENT COINS',
            'You did not have enough coins for this bet when the round closed. Your coins have been returned.',
          ),
        LuckyCardError.roundClosed => (
            'ROUND CLOSED',
            'Betting for that round closed before your bet arrived. Your coins have been returned — please try the next round.',
          ),
        LuckyCardError.notAPlayer => (
            'ACCOUNT NOT ELIGIBLE',
            'This account cannot place bets. Please contact your agent or support.',
          ),
        LuckyCardError.unknown => (
            'BET NOT PLACED',
            'Something went wrong on our end and your bet could not be placed. Your coins have been returned — please try the next round.',
          ),
        _ => (
            'BET NOT PLACED',
            'Your bet could not be sent to the server. Your coins have been returned — please try the next round.',
          ),
      };
      return LuckyCardProblemDialog(
        icon: Icons.report_gmailerrorred_rounded,
        title: title,
        message: message,
        endsSession: false,
        autoDismiss: _kAutoDismiss,
      );
  }
}

/// The connection could not be kept: the player will be logged out.
const LuckyCardProblemDialog luckyCardConnectionLostDialog = LuckyCardProblemDialog(
  icon: Icons.wifi_off_rounded,
  title: 'CONNECTION LOST',
  message: 'Could not stay connected to the server. For your safety you will be logged out — please sign back in once reconnected.',
  endsSession: true,
);

/// The account has been blocked: the player will be logged out.
const LuckyCardProblemDialog luckyCardBlockedDialog = LuckyCardProblemDialog(
  icon: Icons.error_outline_rounded,
  title: 'ACCOUNT BLOCKED',
  message: 'Your account has been blocked. Please contact your agent. You will be logged out.',
  endsSession: true,
);

/// The dialog for a lost connection found by the round sync, from the reason it gives.
LuckyCardProblemDialog luckyCardDialogForConnection(LuckyCardError reason) =>
    reason == LuckyCardError.accountBlocked ? luckyCardBlockedDialog : luckyCardConnectionLostDialog;

/// The one line the status strip shows in place of its words, for a short time.
class LuckyCardNotice extends ChangeNotifier {
  String? _text;
  bool _important = false;
  Timer? _timer;

  /// The line, or null when there is none.
  String? get text => _text;

  /// An important line (a warning about the balance) may be shown even while betting is
  /// closed; an ordinary refusal line only while it is open.
  bool get important => _important;

  /// Shows [text] for [duration]; a new line replaces the old one and restarts the time.
  void show(String text, {Duration duration = kLuckyCardRefusalLineTime, bool important = false}) {
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
