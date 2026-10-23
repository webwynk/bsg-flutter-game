// What the table is doing, in words:
//
//   * betting is open:                 "PLACE YOUR CHIPS"
//   * betting closed, 5 to 1 s left:   "NO MORE PLAY", flashing
//   * the wheel, the card and the win: "NO MORE PLAY", steady (a small deliberate
//     difference from Triple Chance, which goes back to "Place your chips" while
//     the wheel turns, spec §17W)
//
// These words used to have a strip of their own under the board. The reference design has
// no such strip: the header shows them, and a refused tap borrows the same spot for a
// moment (see `luckyCardHeaderStatus` in lucky_card_readouts_binding.dart and
// `LuckyCardStatusLine` in lucky_card_top_bar.dart, which still flashes the last five
// seconds and still stops flashing when the phone's "reduce motion" setting is on).
// What is left here is the mode itself and its words, which the header reads.
//
// Belongs to Lucky Card only.

enum LuckyCardStatusMode {
  /// Betting is open.
  placeChips,

  /// Betting has just closed: the last seconds, flashing.
  noMoreFlashing,

  /// Betting is closed and the round is being drawn, spun and shown.
  noMoreSteady,
}

/// The words of each mode.
String luckyCardStatusText(LuckyCardStatusMode mode) =>
    mode == LuckyCardStatusMode.placeChips ? 'PLACE YOUR CHIPS' : 'NO MORE PLAY';
