// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Palette
  static const background = Color(0xFF0F0F12);
  static const surface = Color(0xFF1A1A1E);
  static const accent = Color(0xFFFF6B35);
  static const accentLight = Color(0xFFFF946D);
  static const secondary = Color(0xFFF7931E);
  
  // Neutral Palette
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFA1A1A1);
  static const textTertiary = Color(0xFF6E6E6E);
  
  // Glass Palette
  static const glassBg = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x33FFFFFF);
  static const orangeGlass = Color(0x26FF6B35);
  
  // Gradients
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, secondary],
  );
  
  static const glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
  );
}

class AppStyles {
  static TextStyle get h1 => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get h2 => GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get h3 => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );

  static TextStyle get buttonText => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.5,
  );
}

class AppDecorations {
  static BoxDecoration get neoGlass => BoxDecoration(
    borderRadius: BorderRadius.circular(24),
    gradient: AppColors.glassGradient,
    border: Border.all(color: AppColors.glassBorder, width: 1.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );

  static BoxDecoration get primaryButton => BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: AppColors.primaryGradient,
    boxShadow: [
      BoxShadow(
        color: AppColors.accent.withOpacity(0.3),
        blurRadius: 15,
        offset: const Offset(0, 8),
      ),
    ],
  );
}