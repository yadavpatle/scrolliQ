import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/challenges/presentation/screens/challenges_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/friends/presentation/screens/friends_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/permissions_screen.dart';
import '../../features/onboarding/presentation/screens/post_login_invite_screen.dart';
import '../../features/onboarding/providers.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/referral/providers.dart';
import '../../shared/widgets/main_shell.dart';

/// Notifies GoRouter on Supabase auth state changes.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthRefreshNotifier();
  // Read (not watch) — the controller itself is a Listenable and is wired
  // into `refreshListenable` below, so the router rebuilds its redirect when
  // the welcome-invite flag flips without re-creating the GoRouter instance.
  final inviteCtrl = ref.read(postLoginInviteControllerProvider);
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([authNotifier, inviteCtrl]),
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final loggedIn = session != null;
      final loc = state.matchedLocation;

      final isAuthRoute = loc == '/login' ||
          loc == '/signup' ||
          loc == '/forgot-password';
      final isSplash = loc == '/splash';
      final isOnboarding = loc == '/onboarding';
      final isWelcomeInvite = loc == '/welcome-invite';

      // Splash and onboarding manage their own navigation.
      if (isSplash || isOnboarding) return null;

      // 1. Unauthenticated users belong on auth routes.
      if (!loggedIn) {
        return isAuthRoute ? null : '/login';
      }

      // 2. Authenticated. If the post-login invite hasn't been shown yet, gate
      //    every other route behind it (except splash/onboarding handled above).
      //    `loaded` guards against flashing the screen before prefs hydrate.
      final needsInvite = inviteCtrl.loaded && !inviteCtrl.shown;
      if (needsInvite) {
        return isWelcomeInvite ? null : '/welcome-invite';
      }

      // 3. Authenticated and invite already handled — no auth/invite routes.
      if (isAuthRoute || isWelcomeInvite) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login',  builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/welcome-invite',
        builder: (_, __) => const PostLoginInviteScreen(),
      ),
      GoRoute(
        path: '/permissions',
        builder: (_, __) => const PermissionsScreen(),
      ),

      // Referral landing route. The OS / browser launches the app on
      // `https://<base>/invite?ref=CODE` (HTTPS App Link or web build), which
      // Flutter forwards as the initial GoRouter location. We hand the URI to
      // ReferralService (so the code gets persisted + redeemed once authed)
      // then bounce to login/home — the top-level redirect handles the rest
      // (auth gate, welcome-invite gate, etc.).
      GoRoute(
        path: '/invite',
        redirect: (context, state) {
          // Fire-and-forget: storing the pending code is async but redirect is
          // synchronous. The auth state-change listener inside ReferralService
          // will redeem the code once the user signs in, so racing the
          // navigation here is fine.
          unawaited(ref.read(referralServiceProvider).handleUri(state.uri));
          final loggedIn =
              Supabase.instance.client.auth.currentSession != null;
          return loggedIn ? '/home' : '/login';
        },
      ),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home',        builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
          GoRoute(path: '/challenges',  builder: (_, __) => const ChallengesScreen()),
          GoRoute(path: '/profile',     builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/friends',     builder: (_, __) => const FriendsScreen()),
        ],
      ),
    ],
  );
});
