import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';
import 'data/repositories/auth_repository.dart';
import 'domain/entities/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Streams Supabase AuthState changes.
final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Resolves the current `AppUser` (or null when signed out).
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  // Recompute whenever auth state changes.
  ref.watch(authStateStreamProvider);
  final repo = ref.watch(authRepositoryProvider);
  final session = repo.currentSession;
  if (session == null) return null;
  return repo.fetchProfile(session.user.id);
});

/// Controller for auth UI screens.
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._repo, this._ref) : super(const AsyncData(null));

  final AuthRepository _repo;
  final Ref _ref;

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.signUpWithEmail(email: email, password: password, name: name);
      _ref.read(analyticsProvider).capture('sign_up', props: {'method': 'email'});
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.signInWithEmail(email: email, password: password);
      _ref.read(analyticsProvider).capture('sign_in', props: {'method': 'email'});
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      await _repo.signInWithGoogle();
      _ref.read(analyticsProvider).capture('sign_in', props: {'method': 'google'});
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    try {
      await _repo.sendPasswordResetEmail(email);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _repo.signOut();
      _ref.read(analyticsProvider).reset();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider), ref);
});
