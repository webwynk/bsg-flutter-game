// A whole Lucky 16 Card screen's worth of objects for the provider tests: a fake
// world (one clock), the simulated server, a fake wallet, the round sync and the
// provider, wired together. Shared by the bet tests and the result tests.
//
// Copied from test/lucky_card/provider_rig.dart; the names changed and the
// stake is now 10 on each of 16 cards (160).

import 'package:best_smart_game/models/lucky16_board.dart';
import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/providers/lucky16_provider.dart';
import 'package:best_smart_game/services/lucky16_round_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_wallet.dart';
import 'sim_server.dart';

const int cycle = 17390003; // winner = card 3 (A clubs, 17390003 % 16), bonus 4X in the simulated server

/// Runs to [position] and tells the provider the wheel has landed. Returns W.
Future<double> landWheelAt(BetRig rig, double position) async {
  await rig.world.runUntil(position);
  final w = rig.world.cyclePosition;
  rig.provider.wheelLanded();
  await rig.world.run(const Duration(milliseconds: 50));
  return w;
}

/// Where a moment fell in its round, in seconds.
double positionOf(DateTime t) => (t.millisecondsSinceEpoch / 1000 + 0.5) % 103;

class BetRig {
  BetRig(
    WidgetTester tester, {
    double startInto = 40,
    int startBalance = 1000,
    Duration latency = const Duration(milliseconds: 100),
    Duration tickInterval = const Duration(seconds: 1),
  })  : world = SimWorld(tester, cycleNumber: cycle, startInto: startInto) {
    server = SimulatedLucky16Server(now: () => world.serverNow, latency: latency)
      ..serverBalance = startBalance;
    wallet = FakeWallet(startBalance);
    sync = Lucky16RoundSync(api: server, now: () => world.deviceNow, tickInterval: tickInterval);
    provider = Lucky16Provider(
      api: server,
      wallet: wallet,
      sync: sync,
      now: () => world.deviceNow,
    );
    provider.onProblem = problems.add;
  }

  final SimWorld world;
  late final SimulatedLucky16Server server;
  late final FakeWallet wallet;
  late final Lucky16RoundSync sync;
  late final Lucky16Provider provider;
  final List<Lucky16Problem> problems = [];

  Future<void> open() async {
    final attached = provider.attach();
    await world.run(const Duration(seconds: 1));
    await attached;
  }

  /// 10 on each of the 16 cards: a stake of 160.
  void betTenOnEveryCard() {
    provider.selectChip(Lucky16Chip.ten);
    for (final card in Lucky16Card.all) {
      provider.tapCard(card);
    }
  }

  /// Runs on across the next cycle boundary, then to [position] seconds into
  /// that next cycle (the server's cycle position wraps at 103, so a position
  /// past 103 can never be waited for directly).
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
