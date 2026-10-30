// Proves what pubspec.yaml bundles for Lucky 16 Card (phone phase 8): every picture the screen can ask
// for, the lobby poster and the wheel's sound are in the asset bundle `flutter test` makes from the
// pubspec, so a picture that is not listed there cannot be loaded here either. Copied from
// test/lucky_card/lucky_card_bundle_test.dart (Lucky Card).

import 'package:best_smart_game/services/lucky16_sound.dart' show kLucky16WheelSpinSound;
import 'package:best_smart_game/widgets/lucky16/lucky16_art.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every picture of the Lucky 16 Card screen is in the asset bundle', () async {
    final missing = <String>[];
    for (final key in Lucky16ArtKey.all) {
      try {
        final data = await rootBundle.load(key.assetPath);
        if (data.lengthInBytes < 1000) missing.add('${key.assetPath} is empty');
      } catch (e) {
        missing.add('${key.assetPath}: $e');
      }
    }
    expect(missing, isEmpty, reason: 'not bundled: $missing');
  });

  test('so is the lobby poster', () async {
    final data = await rootBundle.load(Lucky16ArtKey.gameCard.assetPath);
    expect(data.lengthInBytes, greaterThan(10000));
  });

  test('the wheel\'s sound is in the asset bundle, at the path the sound service plays', () async {
    // AssetSource paths are relative to assets/; the bundle's own are not.
    final data = await rootBundle.load('assets/$kLucky16WheelSpinSound');
    expect(data.lengthInBytes, greaterThan(1000));
  });
}
