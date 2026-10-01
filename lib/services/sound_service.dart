import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal() {
    AudioPlayer.global.setAudioContext(AudioContextConfig(
      respectSilence: false,
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build());
  }

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();
  bool _isInGameScreen = false;
  int _fadeSessionId = 0; // tracking ID to cancel previous fade loops

  void setInGameScreen(bool inGame) {
    _isInGameScreen = inGame;
    if (!inGame) {
      _voicePlayer.stop();
    }
  }

  Future<void> _play(String fileName) async {
    // Issue #114: any new sound on this channel cancels a running spin-stop
    // fade. playSpinStop()'s loop acts on the CHANNEL, not on a particular
    // sound -- it lowers `_player`'s volume and finally stop()s it without
    // knowing what is playing -- so a sound started mid-fade would be faded to
    // silence and killed. This used to depend on each caller remembering to
    // bump the id itself (playSpinStart and playCoin did; playWin only escaped
    // because it happens to fire long after the fade ends). Doing it here, in
    // the one place every `_player` sound goes through, makes it automatic.
    _fadeSessionId++;
    try {
      await _player.stop();
      await _player.setVolume(1.0); // Reset volume to max
      await _player.play(AssetSource('sounds/$fileName'));
    } catch (_) {
      // Sound files may not exist yet — silently ignore
    }
  }

  Future<void> _playSfx(String fileName) async {
    try {
      await _sfxPlayer.stop();
      // Issue #115: same defensive reset _play() does for `_player`. Nothing
      // lowers this channel's volume today, so it is a no-op in practice --
      // but if anyone ever adds a fade, mute or ducking effect here, every
      // later click/ding/select would otherwise play at the left-over volume,
      // silently and permanently. Costs one extra platform call per sound on
      // a frequently-used path (every chip tap); not measured, so it is on
      // the manual test checklist.
      await _sfxPlayer.setVolume(1.0);
      await _sfxPlayer.play(AssetSource('sounds/$fileName'));
    } catch (_) {
      // Sound files may not exist yet — silently ignore
    }
  }

  Future<void> _playVoice(String fileName) async {
    try {
      await _voicePlayer.stop();
      await _voicePlayer.play(AssetSource('sounds/$fileName'));
    } catch (_) {
      // Sound files may not exist yet — silently ignore
    }
  }

  Future<void> playSpinStart() async {
    await _play('spin_start.mp3'); // _play() also cancels any active fade loop
  }

  Future<void> playSpinStop() async {
    final int myId = ++_fadeSessionId;
    try {
      final double startVol = 1.0;
      final int steps = 10;
      final int stepTime = 50; // 500ms total fade duration
      for (int i = steps; i >= 0; i--) {
        if (_fadeSessionId != myId) return; // Abort if a new spin started
        final double vol = (i / steps) * startVol;
        await _player.setVolume(vol);
        await Future.delayed(Duration(milliseconds: stepTime));
      }
      if (_fadeSessionId == myId) {
        await _player.stop();
        await _player.setVolume(1.0); // Restore volume for next play
      }
    } catch (_) {
      try {
        await _player.stop();
      } catch (_) {}
    }
  }
  Future<void> playWin()          async => _play('win.mp3');

  /// Big-win coin fountain sound (Issue #106). Plays at wheel-stop + 0.300s
  /// for wins of 900+ coins.
  ///
  /// Deliberately on `_player`, not `_sfxPlayer`, for two reasons:
  ///  * `playWin()` at wheel-stop + 1.800s uses the same player, so its own
  ///    `stop()` cuts this file at exactly the 1.5s mark the animation ends
  ///    on — coin.mp3 is 1.536s, so the 36ms tail is trimmed for free and can
  ///    never overlap the win sound.
  ///  * `_sfxPlayer` is still playing the 1.704s rim `ding.mp3` started at
  ///    wheel-stop; using it here would cut that off after only 0.3s.
  ///
  /// This sound starts inside `playSpinStop()`'s ~550ms fade window on
  /// `_player` (wheel-stop to ~+0.55s). That fade lowers and then stops
  /// whatever is on the channel without knowing what it is, so it must be
  /// cancelled or it would silence this sound a fraction of a second after it
  /// starts. Since Issue #114 `_play()` cancels it for every sound, so no
  /// separate step is needed here.
  Future<void> playCoin() async {
    await _play('coin.mp3');
  }
  Future<void> playChipClick()    async => _playSfx('button_click.mp3');
  Future<void> playButtonClick()  async => _playSfx('button_click.mp3');
  Future<void> playNumberSelect() async => _playSfx('number-select.mp3');
  Future<void> playRimSelect()    async => _playSfx('ding.mp3');
  Future<void> playNoBets() async {
    if (!_isInGameScreen) return;
    await _playVoice('no_bets.mp3');
  }
  Future<void> playNotification() async => _playSfx('notification-sound-effect.mp3');

  /// Stops all playing sounds immediately (e.g. when user exits game mid-spin).
  void stopAll() {
    _player.stop();
    _sfxPlayer.stop();
    _voicePlayer.stop();
  }

}
