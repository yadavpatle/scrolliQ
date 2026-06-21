import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../referral/providers.dart';
import '../../providers.dart';
import 'challenge_friends_screen.dart';

/// Post-login "first impression" screen that asks the freshly authenticated
/// user to invite a friend.
///
/// Lives outside [OnboardingScreen] so it can run *after* the user is signed
/// in — that way [ReferralService.shareInvite] generates a real
/// `https://.../invite?ref=<CODE>` URL using the new account's
/// `referral_code`, rather than a generic homepage link.
///
/// Both "Challenge" and "Skip" mark the screen as shown, so it never appears
/// twice. The router's redirect (gated on
/// [PostLoginInviteController.shown]) takes the user to `/home` afterwards.
class PostLoginInviteScreen extends ConsumerStatefulWidget {
  const PostLoginInviteScreen({super.key});

  @override
  ConsumerState<PostLoginInviteScreen> createState() =>
      _PostLoginInviteScreenState();
}

class _PostLoginInviteScreenState
    extends ConsumerState<PostLoginInviteScreen> {
  bool _busy = false;

  Future<void> _markShownAndExit() async {
    if (_busy) return;
    _busy = true;
    // Triggers a router refresh which redirects to `/home`.
    await ref.read(postLoginInviteControllerProvider).markShown();
  }

  Future<void> _onChallenge() async {
    // Open the share sheet *before* marking shown so a share failure doesn't
    // permanently dismiss the screen — but advance regardless to avoid a
    // dead-end if the system share dialog is unavailable.
    await ref.read(referralServiceProvider).shareInvite();
    if (!mounted) return;
    await _markShownAndExit();
  }

  Future<void> _onSkip() async {
    await _markShownAndExit();
  }

  @override
  Widget build(BuildContext context) {
    return ChallengeFriendsScreen(
      onChallenge: _onChallenge,
      onSkip: _onSkip,
    );
  }
}
