import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../reel_counter/providers.dart';
import '../../../referral/providers.dart';
import 'challenge_friends_screen.dart';
import 'demo_screen.dart';
import 'permissions_screen.dart';
import 'story_slides_screen.dart';

/// Orchestrates the 4-phase onboarding:
///   Story (9 slides) → Permissions → Challenge Friends → Open YouTube demo
///
/// Uses a simple int stepper rather than nested routes because the flow is
/// linear and animations should be cross-fade, not slide.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0; // 0=story, 1=perms, 2=challenge, 3=demo

  void _advance() {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  /// Opens the share sheet with an invite link, then advances regardless of
  /// whether the user actually shared (so the flow never gets stuck).
  Future<void> _shareAndAdvance() async {
    await ref.read(referralServiceProvider).shareInvite();
    if (!mounted) return;
    _advance();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefOnboardingDone, true);

    // Start overlay bubble automatically if permission was granted.
    final overlay = ref.read(overlayControllerProvider.notifier);
    await overlay.refresh();
    final state = ref.read(overlayControllerProvider);
    if (state.canDraw) await overlay.start();

    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (_step) {
        0 => StorySlides(key: const ValueKey(0), onComplete: _advance),
        1 => PermissionsScreen(key: const ValueKey(1), onComplete: _advance),
        2 => ChallengeFriendsScreen(
            key: const ValueKey(2),
            onChallenge: _shareAndAdvance,
            onSkip: _advance,
          ),
        _ => DemoScreen(key: const ValueKey(3), onComplete: _finish),
      },
    );
  }
}
