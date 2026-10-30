// The colours of the Lucky 16 Card screen, in one place.
//
// Copied from lib/widgets/lucky_card/lucky_card_palette.dart (Lucky Card), colour for colour:
// the approved Lucky 16 phone mockup (reference-design/lucky16/lucky16-phone.html) uses Lucky
// Card's own look for everything but the board. Lucky Card's values were read out of its design
// files (reference-design/royal-cards-standalone/) by measurement. Names say what a colour is FOR,
// not what it looks like; only the prefix changed (kDesign... is kLucky16... here).
//
// The dark gold-edged panel of the dialogs has its own colours in lucky16_panel.dart.
//
// Belongs to Lucky 16 Card only.

import 'package:flutter/widgets.dart';

/// The header bar: a gold rim around a deep red bar, lit from above.
const Color kLucky16BarRim = Color(0xFFF2C14E);
const List<Color> kLucky16BarFill = [Color(0xFFA3192A), Color(0xFF6E0B17), Color(0xFF4D0710)];

/// The hard shadow under the bar, which gives it its thickness.
const Color kLucky16BarUnder = Color(0xFF2A0408);

/// The four round buttons: the light, the middle and the dark of each ball, then the
/// hard shadow under it.
const List<Color> kLucky16ExitFill = [Color(0xFFFF6A5C), Color(0xFFD81F2E), Color(0xFF8C0A16)];
const Color kLucky16ExitUnder = Color(0xFF5A0610);

const List<Color> kLucky16HistoryFill = [Color(0xFFFFC27A), Color(0xFFF5781F), Color(0xFFA84A05)];
const Color kLucky16HistoryUnder = Color(0xFF6A2E02);

const List<Color> kLucky16SoundFill = [Color(0xFF6FA8FF), Color(0xFF2A63E0), Color(0xFF133A9C)];
const Color kLucky16SoundUnder = Color(0xFF0B2466);

const List<Color> kLucky16RulesFill = [Color(0xFF6BE08A), Color(0xFF1FA34A), Color(0xFF0D6A2C)];
const Color kLucky16RulesUnder = Color(0xFF08471D);

/// The sunken pill the balance sits in (the BSG coin is a picture), and the balance figure.
const List<Color> kLucky16BalanceWell = [Color(0xFF24030A), Color(0xFF3D0610)];
const Color kLucky16BalanceText = Color(0xFFFFE58A);

/// The countdown: the number on a purple disc.
const List<Color> kLucky16CountdownDisc = [Color(0xFF5B2AA8), Color(0xFF2E0F63)];
const Color kLucky16CountdownText = Color(0xFFFFFFFF);
const Color kLucky16CountdownShadow = Color(0xFF12052B);

/// The line of words in the middle of the header.
const Color kLucky16StatusText = Color(0xFFFFFFFF);
const Color kLucky16StatusShadow = Color(0xFF2A0408);

/// What that line turns once betting has closed ("NO MORE PLAY").
/// (The design draws no such state; this is its own brightest red, so the words still read
/// against the deep red bar.)
const Color kLucky16AlertText = Color(0xFFFF6A5C);

/// What that line turns for a refusal or a balance notice ("NOT ENOUGH COINS" and the like).
/// Kept distinct from [kLucky16AlertText] (amber, not red) so a refusal still reads as its own
/// kind of message, the same distinction the old strip under the board drew.
const Color kLucky16NoticeText = Color(0xFFFFA500);

/// The light along the top edge of a raised piece, and the shade along its bottom.
const Color kLucky16GlossTopSoft = Color(0x47FFFFFF);

/// The soft shadow the whole bar casts on the room behind it.
const Color kLucky16DropShadow = Color(0x73000000);

/// The gradient of a round button, lit from up and to the left, as the design draws it
/// (`radial-gradient(circle at 35% 30%, …)`).
RadialGradient lucky16BallGradient(List<Color> fill) => RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 0.85,
      colors: fill,
      stops: const [0.0, 0.45, 1.0],
    );

// ── The bet panel (right side) ──────────────────────────────────────────

/// The purple panel the right-hand rows sit on: its gradient, its gold rim (the bar's gold) and
/// the hard shadow under it.
const List<Color> kLucky16PanelFill = [Color(0xFF3B1466), Color(0xFF24093F)];
const Color kLucky16PanelUnder = Color(0xFF12041F);

/// PLAY (blue) and WIN (green): the face, the label, the hard shadow under the cell and under
/// its figure.
const List<Color> kLucky16TotalBetFill = [Color(0xFF4F8DFF), Color(0xFF2459E0), Color(0xFF1A44B8)];
const Color kLucky16TotalBetLabel = Color(0xFFDBE8FF);
const Color kLucky16TotalBetUnder = Color(0xFF0E2A78);

const List<Color> kLucky16WinFill = [Color(0xFF4FDC7A), Color(0xFF1FA34A), Color(0xFF158A3C)];
const Color kLucky16WinLabel = Color(0xFFDDFFE7);
const Color kLucky16WinUnder = Color(0xFF0A5424);

/// The sunken box holding the results, then its history cards (spec §17BO).
const List<Color> kLucky16ResultsFill = [Color(0xFF1A0630), Color(0xFF2A0D4A)];

/// The history cards. The frames are the user's two pictures (cream for the older rounds, dark
/// green for the newest). On the cream card the rank letter is red for hearts and diamonds and
/// black for spades and clubs; on the green card it is white with a thin dark outline and the suit
/// picture sits on a small cream patch, so every suit stays readable (the user's decision of
/// 2026-10-24).
const Color kLucky16HistoryRed = Color(0xFFD4141C);
const Color kLucky16HistoryBlack = Color(0xFF1D1A17);
const Color kLucky16HistoryLatestLetter = Color(0xFFFFFFFF);
const Color kLucky16HistoryLatestOutline = Color(0xFF063D1B);
const Color kLucky16HistoryPatch = Color(0xFFF6EEDC);

/// The red bubble with the round's bonus ("N", "2X" to "10X"): a red gradient, a gold ring, white writing.
const List<Color> kLucky16HistoryBubbleFill = [Color(0xFFFF5A52), Color(0xFFC4161C)];
const Color kLucky16HistoryBubbleRing = Color(0xFFFFD34D);
const Color kLucky16HistoryBubbleText = Color(0xFFFFFFFF);

// ── The action buttons (bottom of bet panel) ────────────────────────────

/// The three action buttons (DOUBLE, CLEAR, REMOVE) plus REBET from the reference design.
///
/// DOUBLE: lime to gold to orange gradient with a pale yellow rim, hard orange-brown shadow under,
/// and a warm orange glow.
const List<Color> kLucky16DoubleFill = [Color(0xFFB6FF3B), Color(0xFFFFD31A), Color(0xFFFF8A00)];
const List<double> kLucky16DoubleStops = [0.0, 0.40, 1.0];
const Color kLucky16DoubleBorder = Color(0xFFFFF3A8);
const Color kLucky16DoubleUnder = Color(0xFF9A4A00);
const Color kLucky16DoubleGlow = Color(0x80FFAA00);
const Color kLucky16DoubleTextShadow = Color(0xFF9A4A00);

/// CLEAR: pink to magenta to violet gradient with a light pink rim, deep violet-magenta shadow under,
/// and a pink glow.
const List<Color> kLucky16ClearFill = [Color(0xFFFF5FD2), Color(0xFFFF2E7E), Color(0xFFB62BFF)];
const List<double> kLucky16ClearStops = [0.0, 0.45, 1.0];
const Color kLucky16ClearBorder = Color(0xFFFFC4F0);
const Color kLucky16ClearUnder = Color(0xFF6E0F7A);
const Color kLucky16ClearGlow = Color(0x73FF2EA0);
const Color kLucky16ClearTextShadow = Color(0xFF7A0A52);

/// REMOVE: cyan to blue to indigo gradient with a light cyan rim, navy shadow under,
/// and a cyan glow.
const List<Color> kLucky16RemoveFill = [Color(0xFF3EE8FF), Color(0xFF1AA3FF), Color(0xFF4B4DFF)];
const List<double> kLucky16RemoveStops = [0.0, 0.45, 1.0];
const Color kLucky16RemoveBorder = Color(0xFFB8F4FF);
const Color kLucky16RemoveUnder = Color(0xFF1F2A8F);
const Color kLucky16RemoveGlow = Color(0x731EA0FF);
const Color kLucky16RemoveTextShadow = Color(0xFF1A2A9C);

/// REBET: lavender to violet to deep purple gradient with a soft lavender rim, deep purple shadow under.
const List<Color> kLucky16RebetFill = [Color(0xFFC79BFF), Color(0xFF7A35E0), Color(0xFF45168F)];
const List<double> kLucky16RebetStops = [0.0, 0.45, 1.0];
const Color kLucky16RebetBorder = Color(0xFFE2C8FF);
const Color kLucky16RebetUnder = Color(0xFF3A0060);
const Color kLucky16RebetGlow = Color(0x737A35E0);
const Color kLucky16RebetTextShadow = Color(0xFF3A0060);

/// The button gloss gradient (top half highlight as drawn in the design).
const List<Color> kLucky16ButtonGloss = [
  Color(0x61FFFFFF),
  Color(0x1FFFFFFF),
  Color(0x00FFFFFF),
  Color(0x00FFFFFF),
];
const List<double> kLucky16ButtonGlossStops = [0.0, 0.46, 0.47, 1.0];

// ── The chips (in bet panel) ──────────────────────────────────────────

/// The dark purple inner ring separating the chip from the gold selection ring.
const Color kLucky16ChipInnerRing = Color(0xFF24093F);

/// The bright gold selection ring and its outer atmospheric glow.
const Color kLucky16ChipGoldRing = Color(0xFFFFD34D);
const Color kLucky16ChipGoldGlow = Color(0x73FFD34D);

/// The hard drop-shadow under the chip.
const Color kLucky16ChipUnder = Color(0x80000000);
