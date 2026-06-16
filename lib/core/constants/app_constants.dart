/// App-wide constants, copy strings, and tracked package names.
class AppConstants {
  AppConstants._();

  static const String appName = 'ScrollIQ';
  static const String tagline = 'Reclaim your attention.';

  // Tracked Android package names (extendable).
  static const Map<String, String> trackedApps = {
    'com.instagram.android': 'Instagram',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.ss.android.ugc.trill': 'TikTok',
    'com.google.android.youtube': 'YouTube',
    'com.facebook.katana': 'Facebook',
    'com.twitter.android': 'X',
    'com.snapchat.android': 'Snapchat',
  };

  // Default penalty thresholds (minutes / hours).
  static const int screenTimeThresholdMinutes = 120;   // 2h
  static const int socialMediaThresholdMinutes = 60;   // 1h
  static const int lateNightStartHour = 0;             // 00:00
  static const int lateNightEndHour = 5;               // 05:00

  // Onboarding storage keys.
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefUsagePermissionAsked = 'usage_permission_asked';
}
