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
import '../../features/profile/presentation/screens/profile_screen.dart';
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
  final notifier = _AuthRefreshNotifier();
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final loggedIn = session != null;
      final loc = state.matchedLocation;

      final isAuthRoute = loc == '/login' ||
          loc == '/signup' ||
          loc == '/forgot-password';
      final isSplash     = loc == '/splash';
      final isOnboarding = loc == '/onboarding';

      // Splash and onboarding manage their own navigation.
      if (isSplash || isOnboarding) return null;

      if (!loggedIn && !isAuthRoute) return '/login';
      if (loggedIn && isAuthRoute)   return '/home';
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
