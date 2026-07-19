import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/env/env.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/app_user.dart';

/// Repository for authentication & profile lookup.
class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;
  Session? get currentSession => _client.auth.currentSession;
  User? get currentAuthUser => _client.auth.currentUser;

  // ---------------------------------------------------------------------------
  // Email auth
  // ---------------------------------------------------------------------------

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      );
      final user = res.user;
      if (user == null) {
        throw const AuthFailure('Sign-up failed. Please try again.');
      }
      // Trigger creates the row, but make sure it exists.
      await _ensureProfileRow(id: user.id, email: email.trim(), name: name.trim());
      return AppUser(id: user.id, email: email.trim(), name: name.trim());
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = res.user;
      if (user == null) {
        throw const AuthFailure('Login failed. Please try again.');
      }
      return await fetchProfile(user.id);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In  (uses ID-token flow → Supabase signInWithIdToken)
  // ---------------------------------------------------------------------------

  Future<AppUser> signInWithGoogle() async {
    try {
      final google = GoogleSignIn(
        clientId: Env.googleIosClientId.isEmpty ? null : Env.googleIosClientId,
        serverClientId:
            Env.googleWebClientId.isEmpty ? null : Env.googleWebClientId,
      );
      final account = await google.signIn();
      if (account == null) {
        throw const AuthFailure('Sign-in cancelled.');
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      if (idToken == null) {
        throw const AuthFailure('Could not obtain Google ID token.');
      }
      final res = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      final user = res.user;
      if (user == null) {
        throw const AuthFailure('Google sign-in failed.');
      }
      await _ensureProfileRow(
        id: user.id,
        email: user.email ?? account.email,
        name: account.displayName ?? user.email ?? '',
        avatarUrl: account.photoUrl,
      );
      return await fetchProfile(user.id);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } on PlatformException catch (e) {
      throw AuthFailure(_mapGoogleSignInError(e));
    }
  }

  /// Maps native Google Sign-In [PlatformException]s to user-facing messages.
  ///
  /// The Android `GoogleSignIn` plugin surfaces failures as a
  /// `PlatformException(sign_in_failed, <statusCode>: ...)`. The most common in
  /// production is status code 10 (`DEVELOPER_ERROR`), which means the app's
  /// package name + signing SHA-1 has no matching Android OAuth client in the
  /// Google Cloud project (e.g. the Play App Signing certificate was never
  /// registered), or the configured server/web client ID is wrong.
  String _mapGoogleSignInError(PlatformException e) {
    final detail = (e.message ?? '').toLowerCase();
    final code = e.code;

    if (code == GoogleSignIn.kSignInFailedError) {
      // Status code is embedded in the message, e.g. "o2.d: 10: ".
      if (detail.contains('10:') || detail.contains('developer_error')) {
        return 'Google sign-in isn\'t configured for this build. '
            'Please try email sign-in, or update the app to the latest version.';
      }
      if (detail.contains('12501') || detail.contains('canceled')) {
        return 'Sign-in cancelled.';
      }
      if (detail.contains('7:') || detail.contains('network')) {
        return 'Network error during Google sign-in. Check your connection and try again.';
      }
      return 'Google sign-in failed. Please try again or use email sign-in.';
    }
    if (code == GoogleSignIn.kNetworkError) {
      return 'Network error during Google sign-in. Check your connection and try again.';
    }
    if (code == GoogleSignIn.kSignInCanceledError) {
      return 'Sign-in cancelled.';
    }
    return 'Google sign-in failed. Please try again or use email sign-in.';
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  // ---------------------------------------------------------------------------
  // Profile helpers
  // ---------------------------------------------------------------------------

  Future<AppUser> fetchProfile(String userId) async {
    final row = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) {
      // Race-condition fallback: build minimal profile from auth user.
      final u = _client.auth.currentUser;
      return AppUser(
        id: userId,
        email: u?.email ?? '',
        name: (u?.userMetadata?['name'] as String?) ?? '',
      );
    }
    return AppUser.fromMap(row);
  }

  Future<void> _ensureProfileRow({
    required String id,
    required String email,
    required String name,
    String? avatarUrl,
  }) async {
    await _client.from('users').upsert({
      'id': id,
      'email': email,
      'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
  }

  Future<void> updateFcmToken(String token) async {
    final id = currentAuthUser?.id;
    if (id == null) return;
    await _client.from('users').update({'fcm_token': token}).eq('id', id);
  }
}
