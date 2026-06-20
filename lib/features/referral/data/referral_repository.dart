import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/env/env.dart';
import '../domain/entities/referrer_preview.dart';

/// Supabase-backed referral data source.
///
/// Each user owns a unique `referral_code` (column on `public.users`, assigned
/// by the `handle_new_user` trigger). Sharing builds a URL containing that
/// code; redeeming calls the `redeem_referral` RPC which creates a pending
/// friend request from the referrer to the redeeming user.
class ReferralRepository {
  ReferralRepository(this._client);
  final SupabaseClient _client;

  static const String _refParam = 'ref';

  String get _me {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  // ---------------------------------------------------------------------------
  // Link building / parsing
  // ---------------------------------------------------------------------------

  /// Builds the shareable invite URL for a referral [code].
  static String buildLink(String code) =>
      '${Env.referralBaseUrl}/invite?$_refParam=$code';

  /// Extracts a referral code from an incoming deep-link [uri], regardless of
  /// scheme/host (custom scheme or https app link). Returns null when absent.
  static String? parseCode(Uri uri) {
    final code = uri.queryParameters[_refParam];
    if (code == null || code.trim().isEmpty) return null;
    return code.trim().toUpperCase();
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// The current user's referral code.
  Future<String> myReferralCode() async {
    final row = await _client
        .from('users')
        .select('referral_code')
        .eq('id', _me)
        .maybeSingle();
    final code = row?['referral_code'] as String?;
    if (code == null || code.isEmpty) {
      throw StateError('Referral code not assigned yet.');
    }
    return code;
  }

  /// The current user's full shareable invite link.
  Future<String> myReferralLink() async => buildLink(await myReferralCode());

  /// Looks up who owns [code] (for previewing an invite). Null if invalid.
  Future<ReferrerPreview?> lookupReferrer(String code) async {
    final rows = await _client.rpc(
      'get_referrer',
      params: {'code': code.trim()},
    );
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    return ReferrerPreview.fromMap(list.first);
  }

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  /// Redeems [code] for the current user, creating a pending friend request
  /// from the referrer. Idempotent and self-referral-safe (handled server-side).
  Future<void> redeem(String code) async {
    await _client.rpc('redeem_referral', params: {'code': code.trim()});
  }
}
