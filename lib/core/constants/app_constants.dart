/// App-wide constants, copy strings, and tracked package names.
class AppConstants {
  AppConstants._();

  static const String appName = 'ScrollIQ';
  static const String tagline = 'Reclaim your attention.';

  // Tracked Android package names (extendable).
  // Currently limited to Instagram, YouTube and Facebook. TikTok / Snapchat /
  // X are paused for now and can be re-added here when support returns.
  static const Map<String, String> trackedApps = {
    'com.instagram.android': 'Instagram',
    'com.google.android.youtube': 'YouTube',
    'com.facebook.katana': 'Facebook',
    'com.facebook.lite': 'Facebook',
  };

  // Default penalty thresholds (minutes / hours).
  static const int screenTimeThresholdMinutes = 120;   // 2h
  static const int socialMediaThresholdMinutes = 60;   // 1h
  static const int lateNightStartHour = 0;             // 00:00
  static const int lateNightEndHour = 5;               // 05:00

  // Onboarding storage keys.
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefUsagePermissionAsked = 'usage_permission_asked';

  /// Whether the floating HUD bubble should run. Defaults to ON — the overlay
  /// auto-starts whenever the "display over other apps" permission is granted.
  /// Set to false only when the user explicitly turns the HUD off.
  static const String prefHudEnabled = 'hud_enabled';
}
