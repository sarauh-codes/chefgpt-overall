// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0A0A0A);
  static const cardBg = Color(0xFF140A00);
  static const orangePrimary = Color(0xFFFF6B35);
  static const orangeSecondary = Color(0xFFF7931E);
  static const goldText = Color(0xFFFFD27F);
}

class AppStyles {
  static const titleStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: -0.5,
  );

  static const subtitleStyle = TextStyle(
    fontSize: 13,
    color: Colors.white54,
    fontWeight: FontWeight.w300,
  );

  static const buttonTextStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: Colors.white,
  );

  static const inputTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
  );
}

class AppDecorations {
  static BoxDecoration get glassCard => BoxDecoration(
    borderRadius: BorderRadius.circular(32),
    color: AppColors.cardBg.withOpacity(0.55),
    border: Border.all(
      color: AppColors.orangePrimary.withOpacity(0.2),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.6),
        blurRadius: 80,
      ),
    ],
  );

  static BoxDecoration get gradientButton => BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    gradient: const LinearGradient(
      colors: [AppColors.orangePrimary, AppColors.orangeSecondary],
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.orangePrimary.withOpacity(0.45),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
  );
}