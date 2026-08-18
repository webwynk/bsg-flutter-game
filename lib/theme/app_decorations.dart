import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppDecorations {
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

  // Result overlay card
  static BoxDecoration resultCard = BoxDecoration(
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.goldPrimary, width: 2.5),
    boxShadow: const [
      BoxShadow(color: Color(0x66D4AF37), blurRadius: 40, spreadRadius: 0),
    ],
  );
}
