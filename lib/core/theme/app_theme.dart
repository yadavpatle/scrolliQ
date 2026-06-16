import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Material 3 light & dark themes for ScrollIQ.
///
/// Typography is intentionally mixed:
///   - Space Grotesk → display / headline / title (geometric, distinctive)
///   - Inter        → body / label  (highly readable)
///   - JetBrains Mono → numerical stats (use [AppText.mono] / [AppText.statNumber])
///
/// Component theming follows a tight radius scale (28 / 20 / 16 / 12) and
/// hairline borders rather than heavy elevation.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Radius scale — used across the app
  // ---------------------------------------------------------------------------

  static const double radiusXl = 28;
  static const double radiusLg = 20;
  static const double radiusMd = 16;
  static const double radiusSm = 12;
  static const double radiusXs = 8;

  // ---------------------------------------------------------------------------
  // Dark theme
  // ---------------------------------------------------------------------------

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onPrimary,
      tertiary: AppColors.accent,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimaryDark,
      error: AppColors.danger,
    );

    final textTheme = _buildTextTheme(
      bodyColor: AppColors.textPrimaryDark,
      mutedColor: AppColors.textSecondaryDark,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bgDark,
      canvasColor: AppColors.bgDark,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.textPrimaryDark, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.bgDark,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryDark,
          backgroundColor: AppColors.surfaceDark,
          side: const BorderSide(color: AppColors.borderDark),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(
          color: AppColors.textSecondaryDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.inter(
          color: AppColors.textTertiaryDark,
          fontSize: 14,
        ),
        prefixIconColor: AppColors.textSecondaryDark,
        suffixIconColor: AppColors.textSecondaryDark,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.textPrimaryDark,
        unselectedLabelColor: AppColors.textSecondaryDark,
        indicatorColor: AppColors.primary,
        labelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceDark2,
        labelStyle: GoogleFonts.inter(
          color: AppColors.textPrimaryDark,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: AppColors.borderDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      dividerColor: AppColors.borderDark,
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDark2,
        contentTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: AppColors.borderDark),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(color: AppColors.borderDark),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondaryDark,
        textColor: AppColors.textPrimaryDark,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimaryDark,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          color: AppColors.textSecondaryDark,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.onPrimary;
          return AppColors.textSecondaryDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.surfaceDark3;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Light theme (placeholder; app runs dark)
  // ---------------------------------------------------------------------------

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      error: AppColors.danger,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bgLight,
      textTheme: _buildTextTheme(
        bodyColor: AppColors.textPrimaryLight,
        mutedColor: AppColors.textSecondaryLight,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static TextTheme _buildTextTheme({
    required Color bodyColor,
    required Color mutedColor,
  }) {
    TextStyle d(double size, FontWeight w, {double letter = -0.5, double height = 1.1}) =>
        GoogleFonts.spaceGrotesk(
          fontSize: size,
          fontWeight: w,
          letterSpacing: letter,
          height: height,
          color: bodyColor,
        );

    TextStyle b(double size, FontWeight w, {double letter = 0.0, double height = 1.4}) =>
        GoogleFonts.inter(
          fontSize: size,
          fontWeight: w,
          letterSpacing: letter,
          height: height,
          color: bodyColor,
        );

    return TextTheme(
      displayLarge:  d(48, FontWeight.w800),
      displayMedium: d(40, FontWeight.w800),
      displaySmall:  d(32, FontWeight.w700),
      headlineLarge: d(28, FontWeight.w700, letter: -0.4),
      headlineMedium: d(24, FontWeight.w700, letter: -0.3),
      headlineSmall: d(20, FontWeight.w700, letter: -0.2),
      titleLarge:    d(18, FontWeight.w700, letter: -0.1, height: 1.2),
      titleMedium:   d(16, FontWeight.w600, letter: 0.0, height: 1.3),
      titleSmall:    d(14, FontWeight.w600, letter: 0.0, height: 1.3),
      bodyLarge:     b(15, FontWeight.w500),
      bodyMedium:    b(14, FontWeight.w500),
      bodySmall:     b(13, FontWeight.w400).copyWith(color: mutedColor),
      labelLarge:    b(14, FontWeight.w600, letter: 0.1, height: 1.2),
      labelMedium:   b(12, FontWeight.w600, letter: 0.2, height: 1.2),
      labelSmall:    b(11, FontWeight.w600, letter: 0.4, height: 1.2),
    );
  }
}

/// Reusable text styles that don't fit cleanly into [TextTheme]
/// (numeric stats, monospaced metrics, eyebrow labels).
class AppText {
  AppText._();

  /// Massive monospaced numeric — used in the brain-score hero.
  static TextStyle statHero({Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: 72,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: -2,
        color: color ?? AppColors.textPrimaryDark,
      );

  /// Medium monospaced numeric — used inside cards.
  static TextStyle statLarge({Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: -1,
        color: color ?? AppColors.textPrimaryDark,
      );

  /// Small monospaced numeric — for inline metrics.
  static TextStyle statSmall({Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.0,
        letterSpacing: -0.5,
        color: color ?? AppColors.textPrimaryDark,
      );

  /// Small monospaced text for inline numbers / IDs.
  static TextStyle mono({double size = 13, Color? color, FontWeight? weight}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w500,
        color: color ?? AppColors.textPrimaryDark,
      );

  /// Eyebrow label — uppercase, tracked, small.
  static TextStyle eyebrow({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: color ?? AppColors.textSecondaryDark,
      );
}
