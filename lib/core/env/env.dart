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

  static String _required(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError('Missing required env var: $key');
    }
    return value;
  }
}
