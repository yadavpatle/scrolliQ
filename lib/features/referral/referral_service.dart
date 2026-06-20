import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/di/providers.dart';
import '../../core/env/env.dart';
import '../friends/providers.dart';
import 'data/referral_repository.dart';

/// Orchestrates the referral lifecycle:
///   • capture incoming invite deep links (cold start + while running)
///   • stash the code until the user is authenticated
///   • redeem it (create a friend request) once signed in
///   • share the current user's invite link via the system share sheet
class ReferralService {
  ReferralService(this._ref);
  final Ref _ref;

  static const String _prefPendingCode = 'pending_referral_code';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  StreamSubscription<AuthState>? _authSub;
  bool _started = false;

  ReferralRepository get _repo =>
      ReferralRepository(_ref.read(supabaseClientProvider));
  SupabaseClient get _client => _ref.read(supabaseClientProvider);

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Wires up deep-link and auth listeners. Safe to call once at app start.
  Future<void> init() async {
    if (_started) return;
    _started = true;

    // 1. Cold-start link (app launched by tapping an invite).
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handleUri(initial);
    } catch (e) {
      debugPrint('Referral: initial link failed: $e');
    }

    // 2. Links received while the app is already running.
    _linkSub = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object e) => debugPrint('Referral: link stream error: $e'),
    );

    // 3. Redeem any pending code as soon as the user is authenticated.
    _authSub = _client.auth.onAuthStateChange.listen((state) {
      if (_client.auth.currentSession != null) {
        unawaited(_redeemPending());
      }
    });

    // 4. Already signed in at launch with a pending code? Redeem now.
    if (_client.auth.currentSession != null) {
      unawaited(_redeemPending());
    }
  }

  void dispose() {
    _linkSub?.cancel();
    _authSub?.cancel();
  }

  // ---------------------------------------------------------------------------
  // Sharing
  // ---------------------------------------------------------------------------

  /// Opens the system share sheet with the current user's invite link.
  /// Falls back to a generic app link when the user isn't signed in yet
  /// (e.g. during onboarding, before a referral code has been assigned).
  /// Returns false if the share sheet could not be opened.
  Future<bool> shareInvite() async {
    String link;
    try {
      link = await _repo.myReferralLink();
    } catch (_) {
      // Not signed in / no code yet — share the plain app link.
      link = Env.referralBaseUrl;
    }
    try {
      await Share.share(
        "I'm using ScrollIQ to turn my screen-time into a Brain Score 🧠 "
        "Join me and let's see who scrolls less:\n$link",
        subject: 'Join me on ScrollIQ',
      );
      _ref.read(analyticsProvider).capture('referral_shared');
      return true;
    } catch (e) {
      debugPrint('Referral: share failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _handleUri(Uri uri) async {
    final code = ReferralRepository.parseCode(uri);
    if (code == null) return;
    await _storePending(code);
    // If the user is already signed in, redeem immediately.
    if (_client.auth.currentSession != null) {
      await _redeemPending();
    }
  }

  Future<void> _storePending(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPendingCode, code);
  }

  Future<void> _redeemPending() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefPendingCode);
    if (code == null || code.isEmpty) return;

    try {
      await _repo.redeem(code);
      await prefs.remove(_prefPendingCode);
      _ref.read(analyticsProvider).capture('referral_redeemed');
      // Refresh friend request lists so the new pending request shows up.
      _ref.invalidate(incomingRequestsProvider);
      _ref.invalidate(friendsListProvider);
    } catch (e) {
      // Keep the code stored so a transient failure can retry next launch.
      debugPrint('Referral: redeem failed: $e');
    }
  }
}
