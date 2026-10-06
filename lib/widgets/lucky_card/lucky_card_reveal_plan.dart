// What the big card of the reveal shows while the wheel spins: which of the 12
// faces, in which order, and when each flip happens.
//
// The user's decision of 2026-10-06 (§17U): one big card flips through the faces
// at random, slowing down, and stops on the winner. The plan is pure arithmetic,
// so it is tested without a screen.
//
//   * The ORDER of the faces comes from the round number, so every phone shows the
//     same faces in the same order (as the wheel's segments are the same on every
//     phone, §17S).
//   * 11 changes, the first at the start of the spin and the others slowing down:
//     the change times follow (k / 10)^1.5 of `span`, so the gaps between changes
//     grow every time, from about 0.15 s to about 0.67 s.
//   * Every face shown is different, and the LAST face shown before the wheel lands
//     is never the winner. The winner appears only when the provider reveals it
//     (the card "settles", with its own flip), so this column can never show the
//     winner before the hub does.
//
// Belongs to Lucky Card only.

import 'dart:math' as math;

import '../../models/lucky_card_models.dart';

/// One flip: the card turns over to [face], starting at [at] and taking [flip].
class LuckyCardRevealStep {
  const LuckyCardRevealStep(this.at, this.flip, this.face);

  final Duration at;
  final Duration flip;
  final LuckyCard face;
}

class LuckyCardRevealPlan {
  const LuckyCardRevealPlan._(this.steps, this.winner, this.span);

  /// The flips in order. The first turns the card over from its back.
  final List<LuckyCardRevealStep> steps;

  /// The card the column settles on when the provider reveals it.
  final LuckyCard winner;

  /// When the last random flip starts, at the latest.
  final Duration span;

  /// How long the plan runs: the last flip has finished by then.
  Duration get total => steps.last.at + steps.last.flip;
}

/// Where the card is at one moment: turning from [from] to [to], [progress] of the
/// way (0 shows [from] face-on, 1 shows [to] face-on). A null face is the card's
/// back.
class LuckyCardRevealFrame {
  const LuckyCardRevealFrame(this.from, this.to, this.progress);

  final LuckyCard? from;
  final LuckyCard? to;
  final double progress;

  /// The face to draw: the old one in the first half of a flip, the new one in the
  /// second.
  LuckyCard? get visible => progress < 0.5 ? from : to;
}

const int _kChanges = 11;
const Duration _kLastGap = Duration(milliseconds: 700);

/// Builds the plan for a round. [span] is when the last random flip starts.
LuckyCardRevealPlan luckyCardRevealPlan({
  required LuckyCard winner,
  required int roundNumber,
  Duration span = const Duration(milliseconds: 4600),
}) {
  // The 12 faces in an order fixed by the round number.
  final faces = List<LuckyCard>.of(LuckyCard.all);
  var state = (roundNumber & 0xFFFFFFFF) ^ 0x9E3779B9;
  for (var i = faces.length - 1; i > 0; i--) {
    state = (state * 1664525 + 1013904223) & 0xFFFFFFFF;
    final j = (state >> 8) % (i + 1);
    final tmp = faces[i];
    faces[i] = faces[j];
    faces[j] = tmp;
  }
  // The faces shown: the first 11, with the winner never the last of them.
  final shown = faces.take(_kChanges).toList();
  if (shown.last == winner) {
    shown[_kChanges - 1] = faces[_kChanges];
  }

  final times = [
    for (var k = 0; k < _kChanges; k++)
      Duration(microseconds: (span.inMicroseconds * math.pow(k / (_kChanges - 1), 1.5)).round()),
  ];
  final steps = <LuckyCardRevealStep>[];
  for (var k = 0; k < _kChanges; k++) {
    final gap = k + 1 < _kChanges ? times[k + 1] - times[k] : _kLastGap;
    final flip = Duration(
      microseconds: (gap.inMicroseconds * 0.7).round().clamp(80000, 280000),
    );
    steps.add(LuckyCardRevealStep(times[k], flip, shown[k]));
  }
  return LuckyCardRevealPlan._(steps, winner, span);
}

/// Where the card is [elapsed] after the spin began.
LuckyCardRevealFrame luckyCardRevealFrameAt(LuckyCardRevealPlan plan, Duration elapsed) {
  var k = -1;
  for (var i = 0; i < plan.steps.length; i++) {
    if (plan.steps[i].at <= elapsed) k = i;
  }
  if (k < 0) return const LuckyCardRevealFrame(null, null, 1);
  final step = plan.steps[k];
  final progress = ((elapsed - step.at).inMicroseconds / step.flip.inMicroseconds).clamp(0.0, 1.0);
  return LuckyCardRevealFrame(k == 0 ? null : plan.steps[k - 1].face, step.face, progress);
}
