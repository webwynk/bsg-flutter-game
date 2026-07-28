import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color bgBase       = Color(0xFF060000);
  static const Color bgSurface    = Color(0xFF120000);
  static const Color bgPanel      = Color(0xFF1E0400);
  static const Color bgPanelLight = Color(0xFF2A0800);

  // Gold system
  static const Color goldBright   = Color(0xFFFFD700);
  static const Color goldPrimary  = Color(0xFFD4AF37);
  static const Color goldDark     = Color(0xFF8B6914);
  static const Color goldDarkest  = Color(0xFF5a3f00);
  static const Color goldGlow     = Color(0xFFF5A623);

  static const Color casinoRed    = Color(0xFFC41E3A);
  static const Color casinoGreen  = Color(0xFF176930);
  static const Color blackRim     = Color(0xFF1E0400);
  static const Color deepRed      = Color(0xFF8B0000);
  static const Color darkRed      = Color(0xFF1a0000);

  // Wheel ring colors
  static const Color redRing1     = Color(0xFF6B0000);
  static const Color redRing2     = Color(0xFFAA2020);
  static const Color greenRing1   = Color(0xFF0A3D1F);
  static const Color greenRing2   = Color(0xFF176930);
  static const Color blackRing1   = Color(0xFF0d0d0d);
  static const Color blackRing2   = Color(0xFF2a2a2a);

  // Cell colors
  static const Color cellGreenTop  = Color(0xFF3D9A3D);
  static const Color cellGreenBot  = Color(0xFF1A6A1A);
  static const Color cellGreenBorder = Color(0xFF145A14);
  static const Color cellPinkTop   = Color(0xFFD06070);
  static const Color cellPinkBot   = Color(0xFFA02030);
  static const Color cellPinkBorder = Color(0xFF801520);
  static const Color cellSelTop    = Color(0xFF9A7000);
  static const Color cellSelBot    = Color(0xFF6A4500);

  // UI
  static const Color textGoldLight = Color(0xFFF5E6C4);
  static const Color historyStart  = Color(0xFF1A0500);
  static const Color historyEnd    = Color(0xFF000000);
  static const Color tabDarkRed    = Color(0xFF2a1000);
  static const Color tabDarkerRed  = Color(0xFF1a0000);
  static const Color blueLens     = Color(0xFF1a3f99);
  static const Color blueLensDark = Color(0xFF060f3a);
  static const Color textCream    = Color(0xFFF0E8D0);
  static const Color textMuted    = Color(0xFF666666);
  static const Color textGold     = Color(0xFFFFD700);
  static const Color successGreen = Color(0xFF27AE60);
  static const Color dangerRed    = Color(0xFFE74C3C);
  static const Color pureWhite    = Color(0xFFFFFFFF);

  // Gradients
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFE066), Color(0xFFFFD700), Color(0xFFD4AF37), Color(0xFF8B6914)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient goldGradientV = LinearGradient(
    colors: [Color(0xFFFFE066), Color(0xFFFFD700), Color(0xFFD4AF37), Color(0xFF8B6914)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient redGradient = LinearGradient(
    colors: [Color(0xFFC41E3A), Color(0xFF8B0000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF1E0400), Color(0xFF060000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardBgGradient = LinearGradient(
    colors: [Color(0xFF2A0800), Color(0xFF100000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient rightPanelGradient = LinearGradient(
    colors: [Color(0xFF150500), Color(0xFF060000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient topBarGradient = LinearGradient(
    colors: [Color(0xFF990000), Color(0xFF4A0000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
