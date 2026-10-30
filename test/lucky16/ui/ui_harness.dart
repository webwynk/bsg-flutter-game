// Shared by the Lucky 16 Card screen tests: the phone sizes, a way to show a widget at one of those
// sizes, the pictures read from disk, and the real fonts.
//
// Copied from test/lucky_card/ui/ui_harness.dart (Lucky Card); the names changed, and the fonts are
// the weights the header actually paints with (Oswald Bold, DM Sans ExtraBold), so a screenshot
// shows the real letters.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:best_smart_game/services/sound_service.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_art.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// One device size.
class Device {
  const Device(this.name, this.width, this.height);

  final String name;
  final double width;
  final double height;

  Size get size => Size(width, height);

  @override
  String toString() => '$name ${width.toInt()}x${height.toInt()}';
}

/// The phones the layout is checked at (landscape, logical dp): Lucky Card's phone matrix plus the
/// three sizes of the approved mockup's screenshots (800x360, 844x390, 915x412) and the widest phone.
const List<Device> kPhoneMatrix = [
  Device('small phone', 640, 360),
  Device('phone', 720, 360),
  Device('mockup small', 800, 360),
  Device('phone with notch', 844, 390),
  Device('large phone', 915, 412),
  Device('tall phone', 960, 412),
  Device('widest phone', 932, 430),
];

/// The three sizes of the approved mockup's screenshots, used for the golden pictures.
const List<Device> kGoldenPhones = [
  Device('mockup small', 800, 360),
  Device('phone with notch', 844, 390),
  Device('large phone', 915, 412),
];

/// Shows [child] filling a screen of [size] dp, at [devicePixelRatio], with the system font scale at
/// [textScale].
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
  // Whatever the test left running is taken off the screen when the test ends, pass or fail.
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(body: child)));
  await tester.pump();
}

/// The same pictures as [AssetLucky16Art], read from disk, for tests (the Lucky 16 pictures are not
/// listed in pubspec.yaml yet).
class FileLucky16Art extends Lucky16Art {
  const FileLucky16Art();

  @override
  ImageProvider image(Lucky16ArtKey key, {required int cacheWidth}) =>
      ResizeImage(FileImage(File(key.assetPath)), width: cacheWidth);
}

/// Loads the fonts the header paints with, so text in a test has real widths and, in a screenshot,
/// real letters (without them a test draws every glyph as a square).
Future<void> loadLucky16Fonts() async {
  final oswald = FontLoader('Oswald')..addFont(rootBundle.load('assets/fonts/Oswald-Bold.ttf'));
  final dmSans = FontLoader('DMSans')..addFont(rootBundle.load('assets/fonts/DMSans-ExtraBold.ttf'));
  await oswald.load();
  await dmSans.load();
}

/// Loads the Material icon font from the Flutter SDK, so an icon in a screenshot is drawn as itself.
Future<void> loadLucky16Icons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final file = File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (!file.existsSync()) return;
  final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

/// The pictures decoded once, up front, and handed out instantly. A screenshot test needs this:
/// decoding a file does not finish inside a widget test's frame clock.
class PreloadedLucky16Art extends Lucky16Art {
  PreloadedLucky16Art._(this._images);

  final Map<Lucky16ArtKey, ui.Image> _images;

  /// Decodes every picture. Call it inside [WidgetTester.runAsync].
  static Future<PreloadedLucky16Art> load() async {
    final images = <Lucky16ArtKey, ui.Image>{};
    for (final key in Lucky16ArtKey.all) {
      final codec = await ui.instantiateImageCodec(await File(key.assetPath).readAsBytes());
      images[key] = (await codec.getNextFrame()).image;
    }
    return PreloadedLucky16Art._(images);
  }

  @override
  ImageProvider image(Lucky16ArtKey key, {required int cacheWidth}) => _InstantImage(_images[key]!);
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

/// The shared SoundService makes its audio players on first use, which fails in a test (there is no
/// audio plugin) with an error that arrives at an unpredictable moment. The shared coins dialog plays a
/// sound, so a test file that shows it calls this once, in setUpAll: the first use happens here, quietly.
Future<void> warmUpSharedSounds() async {
  final saved = FlutterError.onError;
  FlutterError.onError = (_) {};
  await runZonedGuarded(() async {
    SoundService().playNotification();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }, (_, __) {});
  FlutterError.onError = saved;
}
