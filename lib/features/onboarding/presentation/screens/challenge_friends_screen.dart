import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/mascot.dart';

/// "Challenge Friends" promo shown after permissions.
/// [onChallenge] — user taps "Challenge Your Friend" → deeplink / share.
/// [onSkip] — user taps "I'll Do It Later" → advance to demo.
class ChallengeFriendsScreen extends StatelessWidget {
  const ChallengeFriendsScreen({
    super.key,
    required this.onChallenge,
    required this.onSkip,
  });

  final VoidCallback onChallenge;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Text(
                'Flex your scroll count',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'CHALLENGE\nFRIENDS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 40),
              // VS illustration
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Avatar(
                      label: 'YOU',
                      count: 36,
                      color: AppColors.success,
                      mood: MascotMood.ecstatic),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('⚡', style: TextStyle(fontSize: 36)),
                  ),
                  _Avatar(
                      label: 'FRIEND',
                      count: 93,
                      color: AppColors.danger,
                      mood: MascotMood.melting),
                ],
              ),
              const Spacer(flex: 3),
              // CTA
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onChallenge,
                  icon: const Icon(Icons.sports_mma_rounded, size: 20),
                  label: const Text('Challenge Your Friend'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onSkip,
                child: const Text(
                  "I'll Do It Later",
                  style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 15),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.label,
    required this.count,
    required this.color,
    required this.mood,
  });
  final String label;
  final int count;
  final Color color;
  final MascotMood mood;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: AppColors.surfaceDark2,
          child: Mascot(mood: mood, size: 60),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
