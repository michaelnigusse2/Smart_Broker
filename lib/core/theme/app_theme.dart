import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF4F46E5); // Indigo 600
  static const primaryLight = Color(0xFF818CF8); // Indigo 400
  static const primaryDark = Color(0xFF3730A3); // Indigo 800

  static const background = Color(0xFFFAFAFA); // Ultra light gray background
  static const surface = Color(0xFFFFFFFF); // Pure white
  static const surfaceElevated = Color(0xFFF4F4F5); // Slightly darker surface for tonal separation
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF10B981); // Emerald 500

  static const textPrimary = Color(0xFF111111); // Deep gray/almost black
  static const textSecondary = Color(0xFF666666); // Muted gray
  static const textTertiary = Color(0xFFA1A1AA); // Very light gray

  static const divider = Color(0xFFEAEAEA); // Subtle border/divider
  static const border = Color(0xFFE4E4E7);
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double pill = 999.0;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get button => BorderRadius.circular(md);
  static BorderRadius get input => BorderRadius.circular(md);
  static BorderRadius get chip => BorderRadius.circular(sm);
}

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(color: AppColors.textPrimary, letterSpacing: -0.5),
        displayMedium: baseTextTheme.displayMedium?.copyWith(color: AppColors.textPrimary, letterSpacing: -0.5),
        displaySmall: baseTextTheme.displaySmall?.copyWith(color: AppColors.textPrimary),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleLarge: baseTextTheme.titleLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleMedium: baseTextTheme.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleSmall: baseTextTheme.titleSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: AppColors.textPrimary, height: 1.5),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: AppColors.textPrimary, height: 1.5),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        labelLarge: baseTextTheme.labelLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        labelMedium: baseTextTheme.labelMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        labelSmall: baseTextTheme.labelSmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary, // Stark minimalist approach
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.textTertiary),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        space: 1,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceElevated,
        labelStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.chip,
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: false,
        showSelectedLabels: true,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}
