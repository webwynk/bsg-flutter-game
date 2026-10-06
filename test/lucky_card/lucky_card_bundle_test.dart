// Proves what pubspec.yaml bundles (App Step 9, spec §17AI): every picture the Lucky Card screen can
// ask for is in the app's own asset bundle, so a real build can show it. Flutter's test bundle is
// made from the pubspec, so a picture that is not listed there cannot be loaded here either.

import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every picture of the Lucky Card screen is in the asset bundle', () async {
    final missing = <String>[];
    for (final key in LuckyCardArtKey.all) {
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
    final data = await rootBundle.load('assets/lucky_card/images/lucky-card-game-card.webp');
    expect(data.lengthInBytes, greaterThan(100000));
  });

  test('the fonts the screen uses are declared', () async {
    for (final f in ['assets/fonts/Oswald-Medium.ttf', 'assets/fonts/Oswald-Bold.ttf', 'assets/fonts/DMSans-Medium.ttf', 'assets/fonts/DMSans-Bold.ttf']) {
      expect((await rootBundle.load(f)).lengthInBytes, greaterThan(1000), reason: f);
    }
  });

  test('the whole Lucky Card picture folder is bundled: 12 cards, 4 bars, 4 symbols, 3 selectors, the 500 chip, the stage and the poster', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final own = manifest.listAssets().where((a) => a.startsWith('assets/lucky_card/images/')).toList();
    expect(own.length, 26, reason: own.toString());
    for (final key in LuckyCardArtKey.all.where((k) => k.assetPath.startsWith('assets/lucky_card/'))) {
      expect(own, contains(key.assetPath));
    }
  });
}
