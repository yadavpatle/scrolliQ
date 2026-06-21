import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// Tracks whether the post-login "Challenge Friends" welcome screen has been
/// shown on this device.
///
/// Exposed as a [ChangeNotifier] so the GoRouter can use it directly as a
/// `refreshListenable` to re-evaluate its redirect when the flag flips.
///
/// State machine:
///   * Not loaded yet → [shown] reports `true` (the safer default — we don't
///     want to flash the welcome screen for users who already saw it before
///     prefs finish loading). Callers that need to gate redirect logic on
///     "definitely not shown" should also check [loaded].
///   * Loaded, false → user should see `/welcome-invite` after auth.
///   * Loaded, true  → skip straight to `/home`.
class PostLoginInviteController extends ChangeNotifier {
  PostLoginInviteController() {
    _load();
  }

  bool _shown = true;
  bool _loaded = false;

  /// Whether the welcome-invite has already been shown (or, before prefs
  /// finish loading, the conservative default of `true`).
  bool get shown => _shown;

  /// Whether [shown] reflects the persisted value yet.
  bool get loaded => _loaded;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    // Migration: users who completed onboarding before this screen existed
    // shouldn't be shown an unexpected post-login prompt. Mark them as already
    // having seen it so they go straight to `/home`.
    final onboardingDone =
        prefs.getBool(AppConstants.prefOnboardingDone) ?? false;
    final hasInviteFlag =
        prefs.containsKey(AppConstants.prefPostLoginInviteShown);
    if (onboardingDone && !hasInviteFlag) {
      await prefs.setBool(AppConstants.prefPostLoginInviteShown, true);
    }

    _shown = prefs.getBool(AppConstants.prefPostLoginInviteShown) ?? false;
    _loaded = true;
    notifyListeners();
  }

  /// Persist that the welcome-invite has been shown and notify listeners so
  /// the router redirects out of `/welcome-invite`.
  Future<void> markShown() async {
    if (_shown && _loaded) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefPostLoginInviteShown, true);
    _shown = true;
    _loaded = true;
    notifyListeners();
  }
}

/// Long-lived controller for the post-login welcome-invite gate. Read by the
/// router (for redirect decisions) and the welcome-invite screen (to mark it
/// as shown on exit).
final postLoginInviteControllerProvider =
    Provider<PostLoginInviteController>((ref) {
  final ctrl = PostLoginInviteController();
  ref.onDispose(ctrl.dispose);
  return ctrl;
});
