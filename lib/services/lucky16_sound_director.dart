// Turns two changes of the Lucky 16 Card provider into sounds. Copied from
// lib/services/lucky_card_sound_director.dart (Lucky Card); only the names changed:
//
//   * betting closes (the lock, with the countdown at the lock mark): the "no more bets"
//     voice, as Triple Chance plays it;
//   * the suit rim lands and the card is revealed: the second ding (the first, for the rank
//     rim, comes from the wheel at 3 s).
//
// Both are an EDGE, a change from false to true seen after the director started, so a screen
// that opens while betting is already closed, or after the card was shown, stays silent:
// nothing is replayed for a late joiner. The lock that comes from a result sequence (not the
// countdown) is not announced. Start it after the provider has attached.
//
// Everything passes the mute gate ([Lucky16Sound]).
//
// Belongs to Lucky 16 Card only.

import '../providers/lucky16_provider.dart';
import 'lucky16_round_clock.dart';
import 'lucky16_sound.dart';

class Lucky16SoundDirector {
  Lucky16SoundDirector({required Lucky16Provider provider, required Lucky16Sound sound})
      : _provider = provider,
        _sound = sound,
        _wasLocked = provider.isLocked,
        _wasRevealed = provider.cardRevealed {
    provider.addListener(_onChange);
  }

  final Lucky16Provider _provider;
  final Lucky16Sound _sound;
  bool _wasLocked;
  bool _wasRevealed;

  void _onChange() {
    final locked = _provider.isLocked;
    if (locked && !_wasLocked && _provider.countdown <= kLucky16LockCountdown && !_provider.isSequenceRunning) {
      _sound.noMoreBets();
    }
    _wasLocked = locked;

    final revealed = _provider.cardRevealed;
    if (revealed && !_wasRevealed) _sound.ding();
    _wasRevealed = revealed;
  }

  void dispose() => _provider.removeListener(_onChange);
}
