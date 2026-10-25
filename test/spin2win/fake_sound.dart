// Sounds for the screen tests: writes down what the screen asked for instead of playing it.

import 'package:best_smart_game/services/spin2win_sound.dart';

class FakeSoundOutput implements Spin2WinSoundOutput {
  final List<String> played = [];
  final List<bool> inGame = [];
  int stops = 0;

  @override
  void buttonClick() => played.add('button');
  @override
  void chipClick() => played.add('chip');
  @override
  void numberSelect() => played.add('number');
  @override
  void noMoreBets() => played.add('noMoreBets');
  @override
  void spinStart() => played.add('spinStart');
  @override
  void spinStop() => played.add('spinStop');
  @override
  void ding() => played.add('ding');
  @override
  void coin() => played.add('coin');
  @override
  void win() => played.add('win');
  @override
  void notification() => played.add('notification');
  @override
  void setInGame(bool value) => inGame.add(value);
  @override
  void stopAll() => stops++;
}
