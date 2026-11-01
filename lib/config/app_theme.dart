import 'package:flutter/material.dart';

class AppTheme {
  // Couleurs officielles CSP Les Rois du Sahel
  static const Color primaryPurple = Color(0xFF3B0764); // Violet impérial profond
  static const Color primaryPurpleLight = Color(0xFF581C87);
  static const Color primaryPurpleCard = Color(0xFF4C1D95);
  static const Color accentGold = Color(0xFFF59E0B);    // Or / Ambre officiel
  static const Color accentGoldLight = Color(0xFFFBBF24);
  static const Color accentGoldDark = Color(0xFFD97706);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color cardBg = Colors.white;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        primary: primaryPurple,
        secondary: accentGold,
        surface: surfaceLight,
      ),
      scaffoldBackgroundColor: surfaceLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: accentGold,
        foregroundColor: primaryPurple,
        elevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: primaryPurple,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(
          color: primaryPurple,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 14),
        prefixIconColor: primaryPurple,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
    );
  }
}

