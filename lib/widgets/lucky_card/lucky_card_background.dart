// The in-game background of the Lucky Card screen (App Step 9, spec §17AI): the supplied red
// theatre stage, filling the whole screen behind the canvas, notch areas included.
//
//   * `BoxFit.cover`, so a screen of any shape is filled; the picture is 1003 x 564 (1.78 : 1),
//     so a wide or a tall screen crops a little of its edges, which are curtains.
//   * Decoded no wider than the screen needs, and never enlarged (the picture is smaller than
//     a big tablet's screen until the 2400 x 1350 re-export of spec §17B arrives).
//   * It is only a picture: it takes no taps and says nothing to a screen reader.
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

import 'lucky_card_art.dart';
import 'lucky_card_layout.dart';

class LuckyCardBackground extends StatelessWidget {
  const LuckyCardBackground({super.key, required this.art});

  final LuckyCardArt art;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return IgnorePointer(
      child: Image(
        image: art.image(LuckyCardArtKey.background, cacheWidth: LuckyCardLayout.cacheWidth(size.width, dpr)),
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
Future<void> precacheLuckyCardBackground(BuildContext context, LuckyCardArt art) {
  final size = MediaQuery.sizeOf(context);
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return precacheImage(
    art.image(LuckyCardArtKey.background, cacheWidth: LuckyCardLayout.cacheWidth(size.width, dpr)),
    context,
  );
}
