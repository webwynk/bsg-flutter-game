// Popups for the screen tests: writes down what the screen asked for instead of calling Triple
// Chance's shared popups (which need the app's pictures and sounds).

import 'package:best_smart_game/widgets/spin2win/spin2win_messages.dart';
import 'package:flutter/widgets.dart';

class FakeAlerts extends Spin2WinAlerts {
  FakeAlerts();

  int insufficient = 0;
  final List<Spin2WinProblemDialog> problems = [];
  final List<VoidCallback?> sessionEnds = [];

  @override
  void insufficientCoins(BuildContext context) => insufficient++;

  @override
  void problem(BuildContext context, Spin2WinProblemDialog dialog, {VoidCallback? onSessionEnd}) {
    problems.add(dialog);
    sessionEnds.add(onSessionEnd);
  }
}
