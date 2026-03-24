import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static final forest = Color(0xFF1B4332);
  static const green = Color(0xFF2D6A4F);
  static const sage = Color(0xFF52B788);
  static const mint = Color(0xFF95D5B2);
  static const tera = Color(0xFFC75B39);
  static const gold = Color(0xFFE8A020);
  static const cream = Color(0xFFFAF3E0);
  static const sand = Color(0xFFE8D5A3);
  static const earth = Color(0xFF2C1A0E);
  static const charcoal = Color(0xFF1C1C1C);
}

class AppTheme {
  ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      primary: AppColors.forest,
      secondary: AppColors.sage,
      tertiary: AppColors.tera,
      surface: AppColors.cream,
      error: AppColors.earth,
    ),
    scaffoldBackgroundColor: AppColors.cream,
    textTheme: GoogleFonts.soraTextTheme().copyWith(
      bodyLarge: GoogleFonts.dmSans(fontSize: 16),
      bodyMedium: GoogleFonts.dmSans(fontSize: 14),
      bodySmall: GoogleFonts.dmSans(fontSize: 12),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.forest,
      foregroundColor: AppColors.cream,
      elevation: 0,
      titleTextStyle: GoogleFonts.sora(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.cream,
        letterSpacing: 0.04,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.cream,
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.sora(fontWeight: FontWeight.w600, fontSize: 14),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.sand),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.forest, width: 1.5),
      ),
      hintStyle: GoogleFonts.dmSans(color: Colors.grey.shade400),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.sand.withOpacity(0.5)),
      ),
    ),
  );

  ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      brightness: Brightness.dark,
      primary: AppColors.sage,
      secondary: AppColors.mint,
      surface: AppColors.earth,
      background: AppColors.earth,
    ),
    scaffoldBackgroundColor: AppColors.earth,
  );
}
