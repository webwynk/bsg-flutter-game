import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle gameTitle({double size = 22, Color? color}) => TextStyle(
    fontFamily: 'DMSans',
    fontWeight: FontWeight.w700,
    fontSize: size,
    color: color ?? AppColors.goldBright,
    shadows: const [
      Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(2, 2)),
      Shadow(color: Color(0x44FFD700), blurRadius: 16),
    ],
  );

  static TextStyle number({double size = 18, Color? color}) => TextStyle(
    fontFamily: 'Oswald',
    fontWeight: FontWeight.w700,
    fontSize: size,
    color: color ?? AppColors.textCream,
  );

  static TextStyle numberMedium({double size = 16, Color? color}) => TextStyle(
    fontFamily: 'Oswald',
    fontWeight: FontWeight.w600,
    fontSize: size,
    color: color ?? AppColors.textCream,
  );

  static TextStyle countdown({double size = 38, Color? color}) => TextStyle(
    fontFamily: 'Oswald',
    fontWeight: FontWeight.w700,
    fontSize: size,
    color: color ?? AppColors.goldBright,
    shadows: [
      Shadow(color: (color ?? AppColors.goldBright).withValues(alpha: 0.5), blurRadius: 12),
    ],
  );

  static TextStyle label({double size = 11, Color? color}) => TextStyle(
    fontFamily: 'DMSans',
    fontWeight: FontWeight.w600,
    fontSize: size,
    letterSpacing: 1.5,
    color: color ?? AppColors.textMuted,
  );

  static TextStyle labelLight({double size = 10, Color? color}) => TextStyle(
    fontFamily: 'DMSans',
    fontWeight: FontWeight.w400,
    fontSize: size,
    letterSpacing: 1.0,
    color: color ?? AppColors.textMuted,
  );

  static TextStyle button({double size = 13, Color? color}) => TextStyle(
    fontFamily: 'DMSans',
    fontWeight: FontWeight.w700,
    fontSize: size,
    letterSpacing: 2.0,
    color: color ?? AppColors.bgBase,
  );

  static TextStyle balance({double size = 22}) => TextStyle(
    fontFamily: 'Oswald',
    fontWeight: FontWeight.w700,
    fontSize: size,
    color: AppColors.goldBright,
    shadows: const [
      Shadow(color: Color(0x668B6914), blurRadius: 6),
    ],
  );

  static TextStyle sectionHeader({double size = 13, Color? color}) => TextStyle(
    fontFamily: 'DMSans',
    fontWeight: FontWeight.w700,
    fontSize: size,
    letterSpacing: 3.0,
    color: color ?? AppColors.goldPrimary,
  );
}
