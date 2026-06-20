import 'package:flutter/material.dart';

import '../../../shared/widgets/mascot.dart';

/// One story slide in the onboarding flow.
class OnboardingSlide {
  const OnboardingSlide({
    required this.headline,
    this.subtitle,
    this.reelCount,
    this.reelCountColor,
    this.emoji,
    this.mascotMood,
    this.chips,
    this.benefits,
  });

  final String headline;
  final String? subtitle;

  /// If non-null, displays an orange/red pill showing "X reels".
  final int? reelCount;
  final Color? reelCountColor;

  /// Large emoji codepoint string shown as the hero illustration.
  final String? emoji;

  /// If set, the mascot is shown as the hero illustration with this emotion
  /// (takes precedence over [emoji]).
  final MascotMood? mascotMood;

  /// Goal chips (slide 7).
  final List<GoalChip>? chips;

  /// Benefit list (slide 9).
  final List<Benefit>? benefits;
}

class GoalChip {
  const GoalChip(this.emoji, this.label);
  final String emoji;
  final String label;
}

class Benefit {
  const Benefit(this.emoji, this.label);
  final String emoji;
  final String label;
}

/// Permission item shown on the permissions screen.
class PermissionItem {
  const PermissionItem({
    required this.title,
    required this.subtitle,
    required this.key,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final PermissionKey key;
  final IconData icon;
}

enum PermissionKey { accessibility, overlay, battery, usageStats }
