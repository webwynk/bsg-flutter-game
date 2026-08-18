import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle number({double size = 18, Color? color}) => TextStyle(
    fontFamily: 'Oswald',
    fontWeight: FontWeight.w700,
    fontSize: size,
    color: color ?? AppColors.textCream,
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

  static TextStyle sectionHeader({double size = 13, Color? color}) => TextStyle(
    fontFamily: 'DMSans',
    fontWeight: FontWeight.w700,
    fontSize: size,
    letterSpacing: 3.0,
    color: color ?? AppColors.goldPrimary,
  );
}
