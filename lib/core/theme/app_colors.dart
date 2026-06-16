import 'package:flutter/material.dart';

/// Brand palette for ScrollIQ.
///
/// Identity: warm-ink surfaces with an electric lime/chartreuse signature
/// accent. Coral and amber play supporting roles. Designed to feel like a
/// top-tier productivity app (Linear / Things 3 / Opal) rather than a stock
/// Material-3 template.
///
/// All legacy token names are preserved so existing call sites keep working.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Brand accents
  // ---------------------------------------------------------------------------

  /// Signature electric lime. High-contrast on the deep ink background;
  /// pair with [onPrimary] for foreground text on primary fills.
  static const Color primary = Color(0xFFC5F75A);

  /// Slightly muted lime used for hover / pressed states and subtle fills.
  static const Color primarySoft = Color(0xFF7FA738);

  /// Foreground colour used on top of [primary] (warm near-black).
  static const Color onPrimary = Color(0xFF0A0B0E);

  /// Warm coral — used for secondary highlights and friendly emphasis.
  static const Color secondary = Color(0xFFFF7A59);

  /// Honey amber — used for streaks / awards / playful accents.
  static const Color accent = Color(0xFFFFC857);

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger  = Color(0xFFF87171);
  static const Color info    = Color(0xFF60A5FA);

  // ---------------------------------------------------------------------------
  // Dark surfaces (default theme)
  // ---------------------------------------------------------------------------

  /// Top-most app background. A warm ink — not the typical cool blue-violet.
  static const Color bgDark = Color(0xFF0B0C10);

  /// Default card surface.
  static const Color surfaceDark = Color(0xFF15171D);

  /// Slightly raised surface (modals, input fields, secondary cards).
  static const Color surfaceDark2 = Color(0xFF1B1E25);

  /// Highest elevation (floating nav, popovers).
  static const Color surfaceDark3 = Color(0xFF22262F);

  /// Hairline border / divider used across cards.
  static const Color borderDark = Color(0xFF262A33);

  /// Stronger border for focus / selected states.
  static const Color borderDarkStrong = Color(0xFF3A3F4B);

  // ---------------------------------------------------------------------------
  // Light surfaces (kept for completeness — app currently runs in dark mode)
  // ---------------------------------------------------------------------------

  static const Color bgLight       = Color(0xFFF6F5F0);
  static const Color surfaceLight  = Color(0xFFFFFFFF);
  static const Color surfaceLight2 = Color(0xFFEFEDE6);
  static const Color borderLight   = Color(0xFFE2DFD5);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  /// Warm cream rather than pure white — feels less "AI default".
  static const Color textPrimaryDark   = Color(0xFFF2EFE6);
  static const Color textSecondaryDark = Color(0xFF9AA0AC);
  static const Color textTertiaryDark  = Color(0xFF60656F);

  static const Color textPrimaryLight   = Color(0xFF15171D);
  static const Color textSecondaryLight = Color(0xFF6B6E78);

  // ---------------------------------------------------------------------------
  // Brain score category colours (used by the score gauge / badge)
  // ---------------------------------------------------------------------------

  static const Color scoreFocusMaster  = Color(0xFFC5F75A); // primary lime
  static const Color scoreHealthy      = Color(0xFF7DE0BD); // mint
  static const Color scoreDistracted   = Color(0xFFFFC857); // amber
  static const Color scoreDoomscroller = Color(0xFFFF8A4C); // orange
  static const Color scoreBrainMelt    = Color(0xFFF87171); // danger

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------

  /// Signature lime gradient used on the splash logo and the brain-score gauge.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFC5F75A), Color(0xFF7DE0BD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warm gradient used for "competitive / streak" cards.
  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFFC857), Color(0xFFFF7A59)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle border gradient for premium cards.
  static const LinearGradient cardBorderGradient = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x0AFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
