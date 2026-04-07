import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Colors ────────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Brand — forest green family
  static const forest = Color(0xFF1B4332);
  static const green = Color(0xFF2D6A4F);
  static const sage = Color(0xFF52B788);
  static const mint = Color(0xFF95D5B2);

  // Accent
  static const tera = Color(0xFFC75B39);
  static const gold = Color(0xFFE8A020);

  // Surfaces — light
  static const cream = Color(0xFFFAF3E0);
  static const sand = Color(0xFFE8D5A3);
  static const white = Color(0xFFFFFFFF);

  // Surfaces — dark
  static const earth = Color(0xFF2C1A0E);
  static const charcoal = Color(0xFF1C1C1C);
  static const darkSurface = Color(0xFF2A2A2A);

  // Payment brands
  static const mpesaGreen = Color(0xFF00A550);
  static const airtelRed = Color(0xFFE40520);

  // Semantic
  static const success = Color(0xFF52B788);
  static const error = Color(0xFFE53935);
  static const warning = Color(0xFFE8A020);
  static const info = Color(0xFF1565C0);
}

// ── Spacing ───────────────────────────────────────────────────────────────────

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 14,
  );
}

// ── Radius ────────────────────────────────────────────────────────────────────

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static BorderRadius smAll = BorderRadius.circular(sm);
  static BorderRadius mdAll = BorderRadius.circular(md);
  static BorderRadius lgAll = BorderRadius.circular(lg);
  static BorderRadius xlAll = BorderRadius.circular(xl);
  static BorderRadius pillAll = BorderRadius.circular(pill);
}

// ── Text Styles ───────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  // Display
  static TextStyle display1 = GoogleFonts.sora(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
  );

  // Headings
  static TextStyle h1 = GoogleFonts.sora(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
  static TextStyle h2 = GoogleFonts.sora(
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );
  static TextStyle h3 = GoogleFonts.sora(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  static TextStyle h4 = GoogleFonts.sora(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  // Body
  static TextStyle bodyLarge = GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );
  static TextStyle bodyMedium = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static TextStyle bodySmall = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // Special
  static TextStyle button = GoogleFonts.sora(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
  static TextStyle amount = GoogleFonts.sora(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );
  static TextStyle amountSmall = GoogleFonts.sora(
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );
  static TextStyle label = GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
  );
  static TextStyle tab = GoogleFonts.sora(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
  static TextStyle caption = GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
}

// ── Theme ─────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.forest,
        primary: AppColors.forest,
        onPrimary: AppColors.cream,
        secondary: AppColors.sage,
        onSecondary: AppColors.white,
        tertiary: AppColors.tera,
        surface: AppColors.cream,
        onSurface: AppColors.charcoal,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.cream,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppTextStyles.h3.copyWith(color: AppColors.cream),
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),

      // Text
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display1,
        headlineLarge: AppTextStyles.h1,
        headlineMedium: AppTextStyles.h2,
        headlineSmall: AppTextStyles.h3,
        titleLarge: AppTextStyles.h4,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.button,
        labelSmall: AppTextStyles.label,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: AppColors.cream,
          elevation: 0,
          shape: StadiumBorder(),
          textStyle: AppTextStyles.button,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(double.infinity, 52),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forest,
          side: const BorderSide(color: AppColors.forest, width: 1.5),
          shape: StadiumBorder(),
          textStyle: AppTextStyles.button,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(double.infinity, 52),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.forest,
          textStyle: AppTextStyles.button,
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.sand),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.sand),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: Colors.grey.shade400,
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.green),
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error),
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: AppColors.sand.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.zero,
      ),

      // Bottom Nav
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.mint.withValues(alpha: 0.3),
        labelTextStyle: WidgetStateProperty.all(AppTextStyles.tab),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.forest);
          }
          return IconThemeData(color: Colors.grey.shade400);
        }),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.sand.withValues(alpha: 0.3),
        selectedColor: AppColors.forest,
        labelStyle: AppTextStyles.bodySmall,
        shape: StadiumBorder(),
        side: BorderSide.none,
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.forest,
        linearTrackColor: AppColors.sand,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.sand,
        thickness: 1,
        space: 0,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.forest,
        brightness: Brightness.dark,
        primary: AppColors.sage,
        onPrimary: AppColors.earth,
        secondary: AppColors.mint,
        onSecondary: AppColors.earth,
        tertiary: AppColors.gold,
        surface: AppColors.darkSurface,
        onSurface: AppColors.cream,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.charcoal,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.earth,
        foregroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppTextStyles.h3.copyWith(color: AppColors.cream),
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),

      textTheme: TextTheme(
        displayLarge: AppTextStyles.display1.copyWith(color: AppColors.cream),
        headlineLarge: AppTextStyles.h1.copyWith(color: AppColors.cream),
        headlineMedium: AppTextStyles.h2.copyWith(color: AppColors.cream),
        headlineSmall: AppTextStyles.h3.copyWith(color: AppColors.cream),
        titleLarge: AppTextStyles.h4.copyWith(color: AppColors.cream),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: AppColors.sand),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: AppColors.sand),
        bodySmall: AppTextStyles.bodySmall.copyWith(
          color: AppColors.sand.withValues(alpha: 0.7),
        ),
        labelLarge: AppTextStyles.button.copyWith(color: AppColors.cream),
        labelSmall: AppTextStyles.label.copyWith(color: AppColors.mint),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sage,
          foregroundColor: AppColors.earth,
          elevation: 0,
          shape: StadiumBorder(),
          textStyle: AppTextStyles.button,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(double.infinity, 52),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.sage,
          side: const BorderSide(color: AppColors.sage, width: 1.5),
          shape: StadiumBorder(),
          textStyle: AppTextStyles.button,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(double.infinity, 52),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.sand.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.sand.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.sage, width: 1.5),
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: Colors.grey.shade600,
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.mint),
      ),

      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: AppColors.sand.withValues(alpha: 0.1)),
        ),
        margin: EdgeInsets.zero,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.earth,
        indicatorColor: AppColors.sage.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.all(
          AppTextStyles.tab.copyWith(color: AppColors.cream),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.sage);
          }
          return const IconThemeData(color: Colors.grey);
        }),
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.sand.withValues(alpha: 0.1),
        thickness: 1,
        space: 0,
      ),
    );
  }
}
