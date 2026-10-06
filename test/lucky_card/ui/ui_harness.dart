// Shared by the Lucky Card layout tests: the device matrix of spec §12.2, a way
// to show a widget at one of those sizes, and the pictures read from disk.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:best_smart_game/widgets/lucky_card/lucky_card_art.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// One device of the matrix.
class Device {
  const Device(this.name, this.width, this.height);

  final String name;
  final double width;
  final double height;

  Size get size => Size(width, height);
  double get ratio => width / height;

  @override
  String toString() => '$name ${width.toInt()}x${height.toInt()}';
}

/// The device matrix of spec §12.2 (landscape, logical dp). The two shapes at each
/// end are the hardest.
const List<Device> kDeviceMatrix = [
  Device('small phone', 640, 360),
  Device('phone', 720, 360),
  Device('phone with notch', 844, 390),
  Device('large phone', 915, 412),
  Device('tall phone', 960, 412),
  Device('small tablet', 1024, 768),
  Device('tablet', 1280, 800),
  Device('large tablet', 1366, 1024),
];

/// Shows [child] filling a screen of [size] dp, at [devicePixelRatio], with the
/// system font scale at [textScale].
Future<void> pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget child, {
  double devicePixelRatio = 1,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * devicePixelRatio;
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  // Whatever the test left running (a wheel mid-spin, say) is taken off the screen
  // when the test ends, pass or fail. Left running, it can keep a FAILED test's
  // process from ever finishing, so the failure is never reported.
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(
    MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(body: child)),
  );
  await tester.pump();
}

/// The same pictures as [AssetLuckyCardArt], read from disk, for tests.
class FileLuckyCardArt extends LuckyCardArt {
  const FileLuckyCardArt();

  @override
  ImageProvider image(LuckyCardArtKey key, {required int cacheWidth}) =>
      ResizeImage(FileImage(File(key.assetPath)), width: cacheWidth);
}

/// Loads the app's real number font, so text in a test has real widths and, in a
/// screenshot, real letters (without it a test draws every glyph as a square).
Future<void> loadLuckyCardFonts() async {
  final oswald = FontLoader('Oswald')..addFont(rootBundle.load('assets/fonts/Oswald-Medium.ttf'));
  final dmSans = FontLoader('DMSans')..addFont(rootBundle.load('assets/fonts/DMSans-Medium.ttf'));
  await oswald.load();
  await dmSans.load();
}

/// Loads the Material icon font from the Flutter SDK, so an icon in a screenshot is
/// drawn as itself (without it a test draws every icon as a square). The path comes
/// from FLUTTER_ROOT, which `flutter test` sets.
Future<void> loadLuckyCardIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final file = File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (!file.existsSync()) return;
  final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

/// Loads the BOLD weight of the two fonts, which is what the wheel paints with.
/// (Use instead of [loadLuckyCardFonts] in a test file that draws the wheel.)
Future<void> loadLuckyCardWheelFonts() async {
  final oswald = FontLoader('Oswald')..addFont(rootBundle.load('assets/fonts/Oswald-Bold.ttf'));
  final dmSans = FontLoader('DMSans')..addFont(rootBundle.load('assets/fonts/DMSans-Bold.ttf'));
  await oswald.load();
  await dmSans.load();
}

/// The pictures decoded once, up front, and handed out instantly. A screenshot
/// test needs this: reading and decoding a file does not finish inside a widget
/// test's frame clock, so a picture asked for during the test would be blank.
class PreloadedLuckyCardArt extends LuckyCardArt {
  PreloadedLuckyCardArt._(this._images);

  final Map<LuckyCardArtKey, ui.Image> _images;

  /// Decodes every picture. Call it inside [WidgetTester.runAsync].
  static Future<PreloadedLuckyCardArt> load() async {
    final images = <LuckyCardArtKey, ui.Image>{};
    for (final key in LuckyCardArtKey.all) {
      final codec = await ui.instantiateImageCodec(await File(key.assetPath).readAsBytes());
      images[key] = (await codec.getNextFrame()).image;
    }
    return PreloadedLuckyCardArt._(images);
  }

  @override
  ImageProvider image(LuckyCardArtKey key, {required int cacheWidth}) => _InstantImage(_images[key]!);
}

class _InstantImage extends ImageProvider<_InstantImage> {
  const _InstantImage(this.image);

  final ui.Image image;

  @override
  Future<_InstantImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_InstantImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: image)));

  @override
  bool operator ==(Object other) => other is _InstantImage && identical(other.image, image);

  @override
  int get hashCode => identityHashCode(image);
}
