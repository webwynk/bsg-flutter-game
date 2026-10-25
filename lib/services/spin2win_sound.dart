// Every sound of the Spin2Win screen, and its own mute (screens Phase 6), built the way Lucky
// Card's is (lucky_card_sound.dart):
//
//   * [Spin2WinSoundOutput] lists the sounds the screen asks for. The real one,
//     [AppSpin2WinSoundOutput], calls Triple Chance's `SoundService` PUBLIC methods exactly as
//     they are (call only, nothing in it changed) and so plays the app's own files in
//     `assets/sounds/`. The wheel's spin is the one exception: Hasan's own 3.9 s file in
//     `assets/spin2win/sounds/`, played on Spin2Win's own player as Lucky Card plays its wheel.
//     A test hands in a fake that writes down what was asked.
//   * [Spin2WinSound] is the gate every sound passes through. Spin2Win's SOUND button closes it:
//     nothing is played and whatever is playing is stopped. The choice belongs to Spin2Win alone
//     (Hasan's rule, 2026-10-24: each game has its own mute), so muting here leaves Triple Chance
//     and Lucky Card as they were, and theirs leaves this one. It is remembered until the app
//     closes (the app has no storage package), as Lucky Card's is.
//   * Opening and leaving the game set and clear `SoundService`'s in-game flag (needed for its
//     "no more bets" voice) and stop every sound on the way out, even if muted.
//
// Haptics are not sounds: the SOUND button does not touch them.
//
// Belongs to Spin2Win only.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'sound_service.dart';

/// The wheel's own spin sound: Hasan's file (3.9 s, ends just before the 4 s spin does), packed
/// with Spin2Win's assets (`assets/spin2win/sounds/`, added to `pubspec.yaml` with his
/// permission). The path is relative to `assets/`, as `AssetSource` wants it.
const String kSpin2WinWheelSpinSound = 'spin2win/sounds/spin2win-wheel-spin.mp3';

/// The sounds the Spin2Win screen can ask for.
abstract class Spin2WinSoundOutput {
  void buttonClick();
  void chipClick();
  void numberSelect();
  void noMoreBets();
  void spinStart();
  void spinStop();
  void ding();
  void coin();
  void win();
  void notification();
  void setInGame(bool inGame);
  void stopAll();
}

/// Triple Chance's sound service, called as it is.
class AppSpin2WinSoundOutput implements Spin2WinSoundOutput {
  const AppSpin2WinSoundOutput();

  @override
  void buttonClick() => SoundService().playButtonClick();

  @override
  void chipClick() => SoundService().playChipClick();

  @override
  void numberSelect() => SoundService().playNumberSelect();

  @override
  void noMoreBets() => SoundService().playNoBets();

  /// Spin2Win's own player: the wheel's sound is not one of Triple Chance's files, so it does
  /// not go through `SoundService` (which plays only `assets/sounds/`). Created on first use;
  /// it shares the app-wide audio setup `SoundService` makes (mix with other sounds).
  static AudioPlayer? _spinPlayer;

  @override
  void spinStart() {
    _playSpin();
  }

  /// The file ends on its own just before the wheel stops; stopping covers a spin cut short.
  @override
  void spinStop() {
    _stopSpin();
  }

  static Future<void> _playSpin() async {
    try {
      final player = _spinPlayer ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource(kSpin2WinWheelSpinSound));
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
  void ding() => SoundService().playRimSelect();

  @override
  void coin() => SoundService().playCoin();

  @override
  void win() => SoundService().playWin();

  @override
  void notification() => SoundService().playNotification();

  @override
  void setInGame(bool inGame) => SoundService().setInGameScreen(inGame);

  @override
  void stopAll() {
    SoundService().stopAll();
    _stopSpin();
  }
}

/// The gate: plays a sound unless Spin2Win is muted.
class Spin2WinSound {
  Spin2WinSound([Spin2WinSoundOutput? output]) : _output = output ?? const AppSpin2WinSoundOutput();

  final Spin2WinSoundOutput _output;

  /// Spin2Win's own mute, remembered until the app closes.
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
  void noMoreBets() => _gate(_output.noMoreBets);
  void spinStart() => _gate(_output.spinStart);
  void spinStop() => _gate(_output.spinStop);
  void ding() => _gate(_output.ding);
  void coin() => _gate(_output.coin);
  void win() => _gate(_output.win);
  void notification() => _gate(_output.notification);

  /// The game screen opens: the in-game flag is set (Triple Chance's voice needs it).
  void enterGame() => _output.setInGame(true);

  /// The game screen closes (or stops itself): the flag is cleared and every sound stops, muted
  /// or not.
  void leaveGame() {
    _output.setInGame(false);
    _output.stopAll();
  }
}
