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
  bool isMuted = false;
  bool _isInGameScreen = false;
  int _fadeSessionId = 0; // tracking ID to cancel previous fade loops

  void setInGameScreen(bool inGame) {
    _isInGameScreen = inGame;
    if (!inGame) {
      _voicePlayer.stop();
    }
  }

  Future<void> _play(String fileName) async {
    if (isMuted) return;
    try {
      await _player.stop();
      await _player.setVolume(1.0); // Reset volume to max
      await _player.play(AssetSource('sounds/$fileName'));
    } catch (_) {
      // Sound files may not exist yet — silently ignore
    }
  }

  Future<void> _playSfx(String fileName) async {
    if (isMuted) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sounds/$fileName'));
    } catch (_) {
      // Sound files may not exist yet — silently ignore
    }
  }

  Future<void> _playVoice(String fileName) async {
    if (isMuted) return;
    try {
      await _voicePlayer.stop();
      await _voicePlayer.play(AssetSource('sounds/$fileName'));
    } catch (_) {
      // Sound files may not exist yet — silently ignore
    }
  }

  Future<void> playSpinStart() async {
    _fadeSessionId++; // Cancel any active fade loop
    await _play('spin_start.mp3');
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
  Future<void> playLose()         async => _play('lose.mp3');
  Future<void> playChipClick()    async => _playSfx('button_click.mp3');
  Future<void> playButtonClick()  async => _playSfx('button_click.mp3');
  Future<void> playNumberSelect() async => _playSfx('number-select.mp3');
  Future<void> playRimSelect()    async => _playSfx('ding.mp3');
  Future<void> playNoBets() async {
    if (!_isInGameScreen) return;
    await _playVoice('no_bets.mp3');
  }
  Future<void> playNotification() async => _playSfx('notification-sound-effect.mp3');

  void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) {
      _player.stop();
      _sfxPlayer.stop();
      _voicePlayer.stop();
    }
  }

  void mute() {
    isMuted = true;
    _player.stop();
    _sfxPlayer.stop();
    _voicePlayer.stop();
  }

  void unmute() => isMuted = false;

  /// Stops all playing sounds immediately (e.g. when user exits game mid-spin).
  void stopAll() {
    _player.stop();
    _sfxPlayer.stop();
    _voicePlayer.stop();
  }

  void dispose() {
    _player.dispose();
    _sfxPlayer.dispose();
    _voicePlayer.dispose();
  }
}
