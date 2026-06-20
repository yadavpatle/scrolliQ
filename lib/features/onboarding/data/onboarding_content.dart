import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mascot.dart';
import '../domain/onboarding_data.dart';

/// The 9 story slides shown before permissions.
const kStorySlides = <OnboardingSlide>[
  // 1. Hook
  OnboardingSlide(
    headline: 'See your reels count',
    subtitle: 'Instagram • YouTube • Facebook',
    mascotMood: MascotMood.happy,
  ),
  // 2. Fresh start
  OnboardingSlide(
    headline: 'Your brain starts\nfresh every day',
    reelCount: 0,
    reelCountColor: AppColors.accent,
    mascotMood: MascotMood.ecstatic,
  ),
  // 3. Scrolling begins
  OnboardingSlide(
    headline: 'Then you start\nscrolling.',
    reelCount: 21,
    reelCountColor: AppColors.accent,
    mascotMood: MascotMood.neutral,
  ),
  // 4. Drain
  OnboardingSlide(
    headline: 'Every reel drains\nyour brain more.',
    reelCount: 100,
    reelCountColor: AppColors.secondary,
    mascotMood: MascotMood.sad,
  ),
  // 5. Focus drops (red zone)
  OnboardingSlide(
    headline: 'Your ability to\nfocus drops.',
    reelCount: 500,
    reelCountColor: AppColors.danger,
    mascotMood: MascotMood.melting,
  ),
  // 6. What matters
  OnboardingSlide(
    headline: 'Even on things that\nmatter to you.',
    chips: [
      GoalChip('💪', 'Focus on study'),
      GoalChip('👨‍👩‍👧', 'Family time'),
      GoalChip('🚶', 'Walks'),
      GoalChip('✌️', 'Clear mind'),
      GoalChip('😴', 'Better sleep'),
    ],
  ),
  // 7. Empowerment
  OnboardingSlide(
    headline: 'You decide when\nto stop.\nNot the algorithm.',
    mascotMood: MascotMood.ecstatic,
  ),
  // 8. Privacy
  OnboardingSlide(
    headline: 'We only count reels.\n\nYour personal data stays\non your phone.',
    emoji: '🔒',
  ),
  // 9. Promise
  OnboardingSlide(
    headline: "Within a week,\nyou'll scroll less.",
    subtitle: 'And your mind will feel clearer.',
    mascotMood: MascotMood.celebrating,
    benefits: [
      Benefit('😴', 'Sleep calmly'),
      Benefit('📖', 'Focus better'),
      Benefit('🧘', 'Improved mental health'),
    ],
  ),
];

/// Permissions we request after the story.
const kPermissions = <PermissionItem>[
  PermissionItem(
    title: 'Accessibility',
    subtitle: 'To count reels',
    key: PermissionKey.accessibility,
    icon: Icons.accessibility_new_rounded,
  ),
  PermissionItem(
    title: 'Display over other apps',
    subtitle: 'To show reels count',
    key: PermissionKey.overlay,
    icon: Icons.layers_rounded,
  ),
  PermissionItem(
    title: 'Battery (unrestricted)',
    subtitle: 'To keep counting in background',
    key: PermissionKey.battery,
    icon: Icons.battery_saver_rounded,
  ),
  PermissionItem(
    title: 'Usage stats',
    subtitle: 'To track screen time',
    key: PermissionKey.usageStats,
    icon: Icons.query_stats_rounded,
  ),
];
