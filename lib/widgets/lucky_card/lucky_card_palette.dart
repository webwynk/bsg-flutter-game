// The colours of the Lucky Card reference design, in one place.
//
// Every value here was read out of the supplied design files
// (reference-design/royal-cards-standalone/, the phone layout) rather than matched by eye, so
// the screen follows the design by measurement. Names say what a colour is FOR, not what it
// looks like, so a later change of shade does not leave a lying name behind.
//
// This file is additive: the older palette in lucky_card_panel.dart still colours the parts of
// the screen that have not been rebuilt yet. The two live side by side until the board and the
// side panel are rebuilt too.
//
// Belongs to Lucky Card only.

import 'package:flutter/widgets.dart';

/// The screen behind everything: a dark red room, brightest up and to the left.
/// (`radial-gradient(ellipse at 35% 25%, #5a0f18, #2a070c 55%, #160407)`.)
const List<Color> kDesignBackdrop = [Color(0xFF5A0F18), Color(0xFF2A070C), Color(0xFF160407)];
const Alignment kDesignBackdropCenter = Alignment(-0.3, -0.5);

/// The header bar: a gold rim around a deep red bar, lit from above.
const Color kDesignBarRim = Color(0xFFF2C14E);
const List<Color> kDesignBarFill = [Color(0xFFA3192A), Color(0xFF6E0B17), Color(0xFF4D0710)];

/// The hard shadow under the bar, which gives it its thickness.
const Color kDesignBarUnder = Color(0xFF2A0408);

/// The pale gold the design's own round buttons were rimmed in. The header no longer draws
/// this (the user asked it removed, 2026-10-23: a ring on every small button crowded a narrow
/// phone, and the bar's own rim already frames the row). Kept as a measured value from the
/// design, not drawn by anything currently.
const Color kDesignButtonRim = Color(0xFFFFE08A);

/// The four round buttons: the light, the middle and the dark of each ball, then the
/// hard shadow under it.
const List<Color> kDesignExitFill = [Color(0xFFFF6A5C), Color(0xFFD81F2E), Color(0xFF8C0A16)];
const Color kDesignExitUnder = Color(0xFF5A0610);

const List<Color> kDesignHistoryFill = [Color(0xFFFFC27A), Color(0xFFF5781F), Color(0xFFA84A05)];
const Color kDesignHistoryUnder = Color(0xFF6A2E02);

const List<Color> kDesignSoundFill = [Color(0xFF6FA8FF), Color(0xFF2A63E0), Color(0xFF133A9C)];
const Color kDesignSoundUnder = Color(0xFF0B2466);

const List<Color> kDesignRulesFill = [Color(0xFF6BE08A), Color(0xFF1FA34A), Color(0xFF0D6A2C)];
const Color kDesignRulesUnder = Color(0xFF08471D);

/// The sunken pill the balance sits in (the BSG coin is a picture), and the balance figure.
const List<Color> kDesignBalanceWell = [Color(0xFF24030A), Color(0xFF3D0610)];
const Color kDesignBalanceText = Color(0xFFFFE58A);

/// The countdown: a gold ring that empties as the round runs, around a purple disc.
const Color kDesignRing = Color(0xFFFFD34D);
const Color kDesignRingSpent = Color(0x59000000);
const List<Color> kDesignCountdownDisc = [Color(0xFF5B2AA8), Color(0xFF2E0F63)];
const Color kDesignCountdownText = Color(0xFFFFFFFF);
const Color kDesignCountdownShadow = Color(0xFF12052B);

/// The line of words in the middle of the header.
const Color kDesignStatusText = Color(0xFFFFFFFF);
const Color kDesignStatusShadow = Color(0xFF2A0408);

/// What that line turns once betting has closed ("NO MORE PLAY").
/// (The design draws no such state; this is its own brightest red, so the words still read
/// against the deep red bar.)
const Color kDesignAlertText = Color(0xFFFF6A5C);

/// What that line turns for a refusal or a balance notice ("NOT ENOUGH COINS" and the like).
/// Kept distinct from [kDesignAlertText] (amber, not red) so a refusal still reads as its own
/// kind of message, the same distinction the old strip under the board drew.
const Color kDesignNoticeText = Color(0xFFFFA500);

/// The light along the top edge of a raised piece, and the shade along its bottom.
const Color kDesignGlossTop = Color(0x73FFFFFF);
const Color kDesignGlossTopSoft = Color(0x47FFFFFF);
const Color kDesignGlossBottom = Color(0x40000000);

/// The soft shadow the whole bar casts on the room behind it.
const Color kDesignDropShadow = Color(0x73000000);

/// The gradient of a round button, lit from up and to the left, as the design draws it
/// (`radial-gradient(circle at 35% 30%, …)`).
RadialGradient designBallGradient(List<Color> fill) => RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 0.85,
      colors: fill,
      stops: const [0.0, 0.45, 1.0],
    );

// ── The bet panel (right side) ──────────────────────────────────────────

/// The purple panel the right-hand rows sit on: its gradient, its gold rim (the bar's gold) and
/// the hard shadow under it.
const List<Color> kDesignPanelFill = [Color(0xFF3B1466), Color(0xFF24093F)];
const Color kDesignPanelUnder = Color(0xFF12041F);

/// TOTAL BET (blue) and WIN (green): the face, the label, the hard shadow under the cell and under
/// its figure.
const List<Color> kDesignTotalBetFill = [Color(0xFF4F8DFF), Color(0xFF2459E0), Color(0xFF1A44B8)];
const Color kDesignTotalBetLabel = Color(0xFFDBE8FF);
const Color kDesignTotalBetUnder = Color(0xFF0E2A78);

const List<Color> kDesignWinFill = [Color(0xFF4FDC7A), Color(0xFF1FA34A), Color(0xFF158A3C)];
const Color kDesignWinLabel = Color(0xFFDDFFE7);
const Color kDesignWinUnder = Color(0xFF0A5424);

/// The sunken box holding the results, then its cards. The newest round is a white card (the face,
/// the hard shadow under it, the rank letter, a bonus in amber, "N" for none in a muted purple); the
/// nine before it are dark purple cards with a thin light edge and light writing. (The design draws
/// no bonus; the amber and the muted purple are this app's own, chosen to read on each card.)
const List<Color> kDesignResultsFill = [Color(0xFF1A0630), Color(0xFF2A0D4A)];

const List<Color> kDesignTileFill = [Color(0xFFFFFFFF), Color(0xFFFFFFFF)];
const Color kDesignTileUnder = Color(0xFF7A5AA8);
const Color kDesignTileLetter = Color(0xFF24093F);
const Color kDesignTileBonus = Color(0xFFB45F00);
const Color kDesignTileNoBonus = Color(0xFF8A7AA8);

const List<Color> kDesignOldTileFill = [Color(0xFF4D2784), Color(0xFF391664)];
const Color kDesignOldTileEdge = Color(0x40FFFFFF);
const Color kDesignOldTileUnder = Color(0xFF12041F);
const Color kDesignOldTileLetter = Color(0xFFFFFFFF);
const Color kDesignOldTileBonus = Color(0xFFFFD34D);
const Color kDesignOldTileNoBonus = Color(0xFFB9A3E0);

// ── The action buttons (bottom of bet panel) ────────────────────────────

/// The three action buttons (DOUBLE, CLEAR, REMOVE) plus REBET from the reference design.
///
/// DOUBLE: lime to gold to orange gradient with a pale yellow rim, hard orange-brown shadow under,
/// and a warm orange glow.
const List<Color> kDesignDoubleFill = [Color(0xFFB6FF3B), Color(0xFFFFD31A), Color(0xFFFF8A00)];
const List<double> kDesignDoubleStops = [0.0, 0.40, 1.0];
const Color kDesignDoubleBorder = Color(0xFFFFF3A8);
const Color kDesignDoubleUnder = Color(0xFF9A4A00);
const Color kDesignDoubleGlow = Color(0x80FFAA00);
const Color kDesignDoubleTextShadow = Color(0xFF9A4A00);

/// CLEAR: pink to magenta to violet gradient with a light pink rim, deep violet-magenta shadow under,
/// and a pink glow.
const List<Color> kDesignClearFill = [Color(0xFFFF5FD2), Color(0xFFFF2E7E), Color(0xFFB62BFF)];
const List<double> kDesignClearStops = [0.0, 0.45, 1.0];
const Color kDesignClearBorder = Color(0xFFFFC4F0);
const Color kDesignClearUnder = Color(0xFF6E0F7A);
const Color kDesignClearGlow = Color(0x73FF2EA0);
const Color kDesignClearTextShadow = Color(0xFF7A0A52);

/// REMOVE: cyan to blue to indigo gradient with a light cyan rim, navy shadow under,
/// and a cyan glow.
const List<Color> kDesignRemoveFill = [Color(0xFF3EE8FF), Color(0xFF1AA3FF), Color(0xFF4B4DFF)];
const List<double> kDesignRemoveStops = [0.0, 0.45, 1.0];
const Color kDesignRemoveBorder = Color(0xFFB8F4FF);
const Color kDesignRemoveUnder = Color(0xFF1F2A8F);
const Color kDesignRemoveGlow = Color(0x731EA0FF);
const Color kDesignRemoveTextShadow = Color(0xFF1A2A9C);

/// REBET: lavender to violet to deep purple gradient with a soft lavender rim, deep purple shadow under.
const List<Color> kDesignRebetFill = [Color(0xFFC79BFF), Color(0xFF7A35E0), Color(0xFF45168F)];
const List<double> kDesignRebetStops = [0.0, 0.45, 1.0];
const Color kDesignRebetBorder = Color(0xFFE2C8FF);
const Color kDesignRebetUnder = Color(0xFF3A0060);
const Color kDesignRebetGlow = Color(0x737A35E0);
const Color kDesignRebetTextShadow = Color(0xFF3A0060);

/// The button gloss gradient (top half highlight as drawn in the design).
const List<Color> kDesignButtonGloss = [
  Color(0x61FFFFFF),
  Color(0x1FFFFFFF),
  Color(0x00FFFFFF),
  Color(0x00FFFFFF),
];
const List<double> kDesignButtonGlossStops = [0.0, 0.46, 0.47, 1.0];

// ── The chips (in bet panel) ──────────────────────────────────────────

/// The dark purple inner ring separating the chip from the gold selection ring.
const Color kDesignChipInnerRing = Color(0xFF24093F);

/// The bright gold selection ring and its outer atmospheric glow.
const Color kDesignChipGoldRing = Color(0xFFFFD34D);
const Color kDesignChipGoldGlow = Color(0x73FFD34D);

/// The hard drop-shadow under the chip.
const Color kDesignChipUnder = Color(0x80000000);


