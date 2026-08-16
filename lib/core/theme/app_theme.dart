import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Classic YouTube-Inspired Theme for Video Origin Analyzer
class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: AppColors.youtubeRed,
      colorScheme: const ColorScheme.light(
        primary: AppColors.youtubeRed,
        secondary: AppColors.youtubeBlack,
        surface: AppColors.lightSurface,
        error: AppColors.strengthContradictory,
        onSurface: AppColors.textDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      textTheme: GoogleFonts.robotoTextTheme(baseTextTheme).copyWith(
        displayLarge: GoogleFonts.roboto(
            fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark),
        headlineMedium: GoogleFonts.roboto(
            fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
        titleMedium: GoogleFonts.roboto(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
        bodyMedium: GoogleFonts.roboto(
            fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.textDark),
        bodySmall: GoogleFonts.roboto(fontSize: 12, color: AppColors.textMuted),
        labelSmall: GoogleFonts.jetBrainsMono(
            fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.youtubeRed),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.youtubeRed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // YouTube Pill Button
          textStyle: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textDark,
          side: const BorderSide(color: AppColors.lightBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.youtubeRed, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F0F0F), // YouTube Dark Mode background
      primaryColor: AppColors.youtubeRed,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.youtubeRed,
        secondary: Colors.white,
        surface: Color(0xFF212121),
        error: AppColors.strengthContradictory,
        onSurface: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF212121),
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF212121),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF383838), width: 1),
        ),
      ),
      textTheme: GoogleFonts.robotoTextTheme(baseTextTheme).copyWith(
        displayLarge: GoogleFonts.roboto(
            fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
        headlineMedium: GoogleFonts.roboto(
            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        titleMedium: GoogleFonts.roboto(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        bodyMedium: GoogleFonts.roboto(
            fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white70),
        bodySmall: GoogleFonts.roboto(fontSize: 12, color: Colors.white54),
        labelSmall: GoogleFonts.jetBrainsMono(
            fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.youtubeRed),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.youtubeRed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF383838)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF383838),
        thickness: 1,
      ),
    );
  }
}
