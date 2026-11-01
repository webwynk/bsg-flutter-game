import 'package:best_smart_game/utils/round_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each game writes its own round id', () {
    expect(GameRound.tripleChance.id(17413022), 'TC-17413022');
    expect(GameRound.luckyCard.id(17413022), 'LC-17413022');
    expect(GameRound.spin2win.id(17935360), 'SW-17935360');
    expect(GameRound.lucky16.id(17413022), 'LS-17413022');
  });
}
