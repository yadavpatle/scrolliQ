import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client singleton (after `Supabase.initialize`).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// PostHog analytics – thin wrapper.
final analyticsProvider = Provider<Analytics>((ref) => Analytics());

class Analytics {
  final Posthog _ph = Posthog();

  Future<void> capture(String event, {Map<String, Object>? props}) async {
    try {
      await _ph.capture(eventName: event, properties: props);
    } catch (_) {/* analytics is best-effort */}
  }

  Future<void> identify(String userId, {Map<String, Object>? props}) async {
    try {
      await _ph.identify(userId: userId, userProperties: props);
    } catch (_) {/* ignore */}
  }

  Future<void> reset() async {
    try { await _ph.reset(); } catch (_) {/* ignore */}
  }
}
