import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed accessor for environment variables loaded from `.env`.
class Env {
  Env._();

  static Future<void> load() => dotenv.load(fileName: '.env');

  static String get supabaseUrl       => _required('SUPABASE_URL');
  static String get supabaseAnonKey   => _required('SUPABASE_ANON_KEY');

  static String get googleWebClientId => dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID') ?? '';
  static String get googleIosClientId => dotenv.maybeGet('GOOGLE_IOS_CLIENT_ID') ?? '';

  static String get postHogApiKey     => dotenv.maybeGet('POSTHOG_API_KEY') ?? '';
  static String get postHogHost       => dotenv.maybeGet('POSTHOG_HOST') ?? 'https://us.i.posthog.com';

  /// Base URL used to build shareable referral/invite links, e.g.
  /// `https://scrolliq.app` → `https://scrolliq.app/invite?ref=ABCD1234`.
  ///
  /// Trailing slashes are stripped so callers can safely append `/invite...`
  /// without producing a malformed URL with a double slash.
  static String get referralBaseUrl {
    final raw = dotenv.maybeGet('REFERRAL_BASE_URL') ?? 'https://scrolliq.app';
    return raw.replaceFirst(RegExp(r'/+$'), '');
  }

  static String _required(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError('Missing required env var: $key');
    }
    return value;
  }
}
