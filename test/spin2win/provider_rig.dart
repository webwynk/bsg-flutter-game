// A whole Spin2Win screen's worth of objects for the provider tests: a fake
// world (one clock), the simulated server, a fake wallet, the round sync and the
// provider, wired together. Shared by the bet tests and the result tests.

import 'package:best_smart_game/models/spin2win_board.dart';
import 'package:best_smart_game/models/spin2win_models.dart';
import 'package:best_smart_game/providers/spin2win_provider.dart';
import 'package:best_smart_game/services/spin2win_round_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_wallet.dart';
import 'sim_server.dart';

const int cycle = 17390007; // winner = number 7, bonus 4X in the simulated server

/// Runs to [position] and tells the provider the wheel has landed. Returns W.
Future<double> landWheelAt(BetRig rig, double position) async {
  await rig.world.runUntil(position);
  final w = rig.world.cyclePosition;
  rig.provider.wheelLanded();
  await rig.world.run(const Duration(milliseconds: 50));
  return w;
}

/// Where a moment fell in its round, in seconds.
double positionOf(DateTime t) => (t.millisecondsSinceEpoch / 1000 + 0.5) % 100;

class BetRig {
  BetRig(
    WidgetTester tester, {
    double startInto = 40,
    int startBalance = 1000,
    Duration latency = const Duration(milliseconds: 100),
    Duration tickInterval = const Duration(seconds: 1),
  })  : world = SimWorld(tester, cycleNumber: cycle, startInto: startInto) {
    server = SimulatedSpin2WinServer(now: () => world.serverNow, latency: latency)
      ..serverBalance = startBalance;
    wallet = FakeWallet(startBalance);
    sync = Spin2WinRoundSync(api: server, now: () => world.deviceNow, tickInterval: tickInterval);
    provider = Spin2WinProvider(
      api: server,
      wallet: wallet,
      sync: sync,
      now: () => world.deviceNow,
    );
    provider.onProblem = problems.add;
  }

  final SimWorld world;
  late final SimulatedSpin2WinServer server;
  late final FakeWallet wallet;
  late final Spin2WinRoundSync sync;
  late final Spin2WinProvider provider;
  final List<Spin2WinProblem> problems = [];

  Future<void> open() async {
    final attached = provider.attach();
    await world.run(const Duration(seconds: 1));
    await attached;
  }

  /// 10 on each of the ten numbers: a stake of 100.
  void betTenOnEveryNumber() {
    provider.selectChip(Spin2WinChip.ten);
    for (final number in kSpin2WinNumbers) {
      provider.tapNumber(number);
    }
  }

  /// Runs on across the next cycle boundary, then to [position] seconds into
  /// that next cycle (the server's cycle position wraps at 100, so a position
  /// past 100 can never be waited for directly).
  Future<void> runIntoNextCycle(double position) async {
    var guard = 0;
    while (world.cyclePosition >= 10 && ++guard < 100000) {
      await world.tester.pump(const Duration(milliseconds: 100));
    }
    await world.runUntil(position);
  }

  Future<void> finish() async {
    provider.dispose();
    await world.run(const Duration(seconds: 12));
  }
}
