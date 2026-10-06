// Every sound of the Lucky Card screen, and the mute (App Step 8b, spec §17AC, §17AE).
//
//   * [LuckyCardSoundOutput] lists the few sounds the screen asks for. The real one,
//     [AppSoundOutput], calls Triple Chance's `SoundService` PUBLIC methods exactly as they
//     are (shared-object permission: call only); a test hands in a fake that writes down
//     what was asked.
//   * [LuckyCardSound] is the gate every sound passes through. The SOUND button closes it:
//     nothing is played, whatever is playing is stopped, and the choice is remembered until
//     the app closes (a static value; `pubspec.yaml` has no storage package). `SoundService`
//     itself has no mute switch, so this one covers Lucky Card's own sounds only.
//   * Opening and leaving the game set and clear `SoundService`'s in-game flag (the same
//     public call Triple Chance's screen makes, needed for its "no more bets" voice) and stop
//     every sound on the way out, even if muted.
//
// Haptics are not sounds: the SOUND button does not touch them (spec §17AE).
//
// Belongs to Lucky Card only.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'sound_service.dart';

/// The wheel's own spin sound: the owner's file, packed with Lucky Card's assets
/// (`assets/lucky_card/sounds/`, added to `pubspec.yaml` with the owner's permission).
/// The path is relative to `assets/`, as `AssetSource` wants it.
const String kLuckyCardWheelSpinSound = 'lucky_card/sounds/lucky-card-wheel-spin-sound.mp3';

/// The sounds the Lucky Card screen can ask for.
abstract class LuckyCardSoundOutput {
  void buttonClick();
  void chipClick();
  void numberSelect();
  void ding();
  void wheelSpin();
  void notification();
  void win();
  void coin();
  void noMoreBets();
  void setInGame(bool inGame);
  void stopAll();
}

/// Triple Chance's sound service, called as it is.
class AppSoundOutput implements LuckyCardSoundOutput {
  const AppSoundOutput();

  @override
  void buttonClick() => SoundService().playButtonClick();

  @override
  void chipClick() => SoundService().playChipClick();

  @override
  void numberSelect() => SoundService().playNumberSelect();

  @override
  void ding() => SoundService().playRimSelect();

  /// Lucky Card's own player: the wheel's sound is not one of Triple Chance's files, so it does
  /// not go through `SoundService` (which plays only `assets/sounds/`). Created on first use;
  /// it shares the app-wide audio setup `SoundService` makes (mix with other sounds).
  static AudioPlayer? _spinPlayer;

  @override
  void wheelSpin() {
    _playSpin();
  }

  static Future<void> _playSpin() async {
    try {
      final player = _spinPlayer ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource(kLuckyCardWheelSpinSound));
    } catch (_) {
      // A sound that cannot play must never break the game.
    }
  }

  static Future<void> _stopSpin() async {
    try {
      await _spinPlayer?.stop();
    } catch (_) {}
  }

  @override
  void notification() => SoundService().playNotification();

  @override
  void win() => SoundService().playWin();

  @override
  void coin() => SoundService().playCoin();

  @override
  void noMoreBets() => SoundService().playNoBets();

  @override
  void setInGame(bool inGame) => SoundService().setInGameScreen(inGame);

  @override
  void stopAll() {
    SoundService().stopAll();
    _stopSpin();
  }
}

/// The gate: plays a sound unless it is muted.
class LuckyCardSound {
  LuckyCardSound([LuckyCardSoundOutput? output]) : _output = output ?? const AppSoundOutput();

  final LuckyCardSoundOutput _output;

  /// Remembered until the app closes, and shared by every screen of the run.
  static final ValueNotifier<bool> _muted = ValueNotifier<bool>(false);

  /// Puts the sound back on. For tests only: a real run keeps the player's choice.
  @visibleForTesting
  static void resetMute() => _muted.value = false;

  bool get muted => _muted.value;

  /// Flips the SOUND button. Muting stops whatever is playing.
  void toggle() {
    _muted.value = !_muted.value;
    if (_muted.value) _output.stopAll();
  }

  void _gate(void Function() play) {
    if (!_muted.value) play();
  }

  void buttonClick() => _gate(_output.buttonClick);
  void chipClick() => _gate(_output.chipClick);
  void numberSelect() => _gate(_output.numberSelect);
  void ding() => _gate(_output.ding);
  void wheelSpin() => _gate(_output.wheelSpin);
  void notification() => _gate(_output.notification);
  void win() => _gate(_output.win);
  void coin() => _gate(_output.coin);
  void noMoreBets() => _gate(_output.noMoreBets);

  /// The game screen opens: the in-game flag is set (Triple Chance's voice needs it).
  void enterGame() => _output.setInGame(true);

  /// The game screen closes (or stops itself): the flag is cleared and every sound stops,
  /// muted or not.
  void leaveGame() {
    _output.setInGame(false);
    _output.stopAll();
  }

  /// Stops everything now (a long absence).
  void stopAll() => _output.stopAll();
}
