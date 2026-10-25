// Turns the Spin2Win round into sounds (screens Phase 6), with Triple Chance's own files and
// moments:
//
//   * betting closes at the lock mark (05): the "no more bets" voice;
//   * the wheel starts (00): the spin sound;
//   * the wheel stops and the number shows: the spin sound fades out and the ding plays;
//   * the coins burst (a win of 900 or more, the same rule as the coins themselves): the coin
//     sound, as Triple Chance plays it for its own 900+ coin fountain;
//   * the win popup opens: the win sound.
//
// Every one is an EDGE, a change seen after the director started, so a screen that opens in the
// middle of a round stays silent until something new happens: nothing is replayed for a late
// joiner. A lock that comes from a result sequence, not the countdown, is not announced.
// Everything passes Spin2Win's mute gate ([Spin2WinSound]). Start it after the provider has
// attached.
//
// Belongs to Spin2Win only.

import '../providers/spin2win_provider.dart';
import '../widgets/spin2win/spin2win_coin_burst.dart';
import 'spin2win_round_clock.dart';
import 'spin2win_sound.dart';

class Spin2WinSoundDirector {
  Spin2WinSoundDirector({required Spin2WinProvider provider, required Spin2WinSound sound})
      : _provider = provider,
        _sound = sound,
        _wasLocked = provider.isLocked,
        _wasSpinning = provider.stage == Spin2WinStage.spinning,
        _wasRevealed = provider.numberRevealed,
        _wasCoins = provider.showCoinFx,
        _wasPopup = provider.popup != null {
    provider.addListener(_onChange);
  }

  final Spin2WinProvider _provider;
  final Spin2WinSound _sound;
  bool _wasLocked;
  bool _wasSpinning;
  bool _wasRevealed;
  bool _wasCoins;
  bool _wasPopup;

  void _onChange() {
    final p = _provider;

    final locked = p.isLocked;
    if (locked && !_wasLocked && p.countdown <= kSpin2WinLockCountdown && p.stage == Spin2WinStage.none) {
      _sound.noMoreBets();
    }
    _wasLocked = locked;

    final spinning = p.stage == Spin2WinStage.spinning;
    if (spinning && !_wasSpinning) _sound.spinStart();
    _wasSpinning = spinning;

    final revealed = p.numberRevealed;
    if (revealed && !_wasRevealed) {
      _sound.spinStop();
      _sound.ding();
    }
    _wasRevealed = revealed;

    final coins = p.showCoinFx;
    if (coins && !_wasCoins && spin2WinShowsCoinBurst(p.lastOutcome?.payout ?? 0)) _sound.coin();
    _wasCoins = coins;

    final popup = p.popup != null;
    if (popup && !_wasPopup) _sound.win();
    _wasPopup = popup;
  }

  void dispose() => _provider.removeListener(_onChange);
}
