import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppDecorations {
  // Gold-bordered dark panel
  static BoxDecoration goldBorderPanel({double radius = 12, double borderWidth = 1.5}) =>
    BoxDecoration(
      gradient: AppColors.darkBgGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.goldPrimary, width: borderWidth),
      boxShadow: const [
        BoxShadow(color: Color(0x33D4AF37), blurRadius: 20, spreadRadius: 0),
        BoxShadow(color: Colors.black87, blurRadius: 30, offset: Offset(0, 8)),
      ],
    );

  // Login card
  static BoxDecoration loginCard = BoxDecoration(
    gradient: AppColors.cardBgGradient,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: AppColors.goldPrimary, width: 2.5),
    boxShadow: const [
      BoxShadow(color: Color(0x55D4AF37), blurRadius: 40, spreadRadius: 0),
      BoxShadow(color: Colors.black87, blurRadius: 60, offset: Offset(0, 20)),
    ],
  );

  // Text field
  static InputDecoration textField({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontFamily: 'DMSans',
      fontSize: 14,
      color: Color(0xFF666666),
    ),
    prefixIcon: Icon(prefixIcon, color: AppColors.goldPrimary, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFF1a0800),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF4a1500)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF4a1500)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.goldPrimary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  // Gold shimmer SPIN/LOGIN button
  static BoxDecoration goldButton({double radius = 10}) => BoxDecoration(
    gradient: AppColors.goldGradient,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const [
      BoxShadow(color: Color(0x55FFD700), blurRadius: 18, spreadRadius: 0),
      BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
    ],
  );

  // Action button (INFO, DOUBLE, CLEAR, REMOVE)
  static BoxDecoration actionButton(List<Color> colors) => BoxDecoration(
    gradient: LinearGradient(
      colors: colors,
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColors.goldPrimary, width: 1.5),
    boxShadow: const [
      BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2)),
      BoxShadow(color: Color(0x33FFD700), blurRadius: 4, spreadRadius: 1),
    ],
  );

  // Right control panel
  static BoxDecoration rightPanel = BoxDecoration(
    gradient: AppColors.rightPanelGradient,
    border: const Border(
      left: BorderSide(color: AppColors.goldPrimary, width: 1.5),
    ),
  );

  // Left tab strip
  static BoxDecoration leftTabStrip = const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF1a0000), Color(0xFF0a0000)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    border: Border(
      right: BorderSide(color: Color(0xFF3a0800), width: 1.0),
    ),
  );

  // Active tab in left strip
  static BoxDecoration activeTab = BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF4a1800), Color(0xFF2d0a00)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    border: Border.all(color: AppColors.goldPrimary, width: 0),
  );

  // Drawer panel (metallic bronze/gold gradient)
  static BoxDecoration drawerPanel = BoxDecoration(
    gradient: const LinearGradient(
      colors: [
        Color(0xFFDCA857), // Light gold-bronze
        Color(0xFFB57E3B), // Medium bronze
        Color(0xFF6B4515), // Deep dark bronze/brown
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    border: const Border(
      right: BorderSide(color: AppColors.goldPrimary, width: 2.5),
      top: BorderSide(color: AppColors.goldPrimary, width: 1.5),
      bottom: BorderSide(color: AppColors.goldPrimary, width: 1.5),
    ),
    boxShadow: const [
      BoxShadow(
        color: Colors.black87,
        blurRadius: 40,
        spreadRadius: 10,
        offset: Offset(20, 0),
      ),
    ],
  );

  // Grid gold frame
  static BoxDecoration gridFrame = BoxDecoration(
    border: Border.all(color: AppColors.goldPrimary, width: 2.0),
    borderRadius: BorderRadius.circular(6),
    boxShadow: const [
      BoxShadow(color: Color(0x33D4AF37), blurRadius: 8),
      BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
    ],
  );

  // Game lobby card
  static BoxDecoration lobbyCard = BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.goldPrimary, width: 2.5),
    boxShadow: const [
      BoxShadow(color: Color(0x44D4AF37), blurRadius: 12),
      BoxShadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 4)),
    ],
  );

  // Result overlay card
  static BoxDecoration resultCard = BoxDecoration(
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.goldPrimary, width: 2.5),
    boxShadow: const [
      BoxShadow(color: Color(0x66D4AF37), blurRadius: 40, spreadRadius: 0),
    ],
  );

  // Balance box in top bar
  static BoxDecoration balanceBox = BoxDecoration(
    color: const Color(0xFF220000),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColors.goldPrimary, width: 1.0),
  );
}
