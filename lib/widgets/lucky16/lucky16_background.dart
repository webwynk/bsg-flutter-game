// The in-game background of the Lucky 16 Card screen: Lucky Card's red theatre stage (read in place,
// never copied), filling the whole screen behind the canvas, notch areas included.
//
// Copied from lib/widgets/lucky_card/lucky_card_background.dart (Lucky Card); only the names changed.
//   * `BoxFit.cover`, so a screen of any shape is filled (the picture's edges are curtains).
//   * Decoded no wider than the screen needs.
//   * It is only a picture: it takes no taps and says nothing to a screen reader.
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

import 'lucky16_art.dart';
import 'lucky16_layout.dart';

class Lucky16Background extends StatelessWidget {
  const Lucky16Background({super.key, required this.art});

  final Lucky16Art art;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return IgnorePointer(
      child: Image(
        image: art.image(Lucky16ArtKey.background, cacheWidth: Lucky16Layout.cacheWidth(size.width, dpr)),
        width: size.width,
        height: size.height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Loads the background into the image cache, so it does not pop in when the screen opens.
Future<void> precacheLucky16Background(BuildContext context, Lucky16Art art) {
  final size = MediaQuery.sizeOf(context);
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return precacheImage(
    art.image(Lucky16ArtKey.background, cacheWidth: Lucky16Layout.cacheWidth(size.width, dpr)),
    context,
  );
}
