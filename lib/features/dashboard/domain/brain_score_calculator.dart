import '../../../core/constants/app_constants.dart';
import '../../usage_tracking/domain/entities/daily_usage.dart';

/// Categorisation buckets shown on the dashboard.
enum BrainCategory {
  focusMaster, // 90-100
  healthy,     // 70-89
  distracted,  // 50-69
  doomscroller,// 30-49
  brainMelt,   // 0-29
}

extension BrainCategoryX on BrainCategory {
  String get label => switch (this) {
        BrainCategory.focusMaster  => 'Focus Master',
        BrainCategory.healthy      => 'Healthy Focus',
        BrainCategory.distracted   => 'Distracted',
        BrainCategory.doomscroller => 'Doomscroller',
        BrainCategory.brainMelt    => 'Brain Melt',
      };
}

/// Pure, side-effect-free score calculator. Easy to unit-test.
///
/// Penalty axes (4):
///   1. Total screen time above [screenTimeThreshold]
///   2. Social-media time above [socialMediaThreshold]
///   3. Late-night usage
///   4. Reel/shorts count above [reelCountThreshold]   ← Phase D addition
class BrainScoreCalculator {
  const BrainScoreCalculator({
    this.screenTimeThreshold     = AppConstants.screenTimeThresholdMinutes,
    this.socialMediaThreshold    = AppConstants.socialMediaThresholdMinutes,
    this.screenTimePenaltyPerHour = 8,
    this.socialPenaltyPerHour     = 12,
    this.lateNightPenaltyPerHour  = 15,
    this.reelCountThreshold       = 30,
    this.reelPenaltyPer10         = 3,
  });

  final int screenTimeThreshold;
  final int socialMediaThreshold;
  final int screenTimePenaltyPerHour;
  final int socialPenaltyPerHour;
  final int lateNightPenaltyPerHour;

  /// No penalty for ≤ this many reels/day.
  final int reelCountThreshold;

  /// Points deducted per 10 reels above threshold.
  final int reelPenaltyPer10;

  int calculate(DailyUsage u) {
    int score = 100;

    // 1. Screen-time penalty.
    if (u.totalMinutes > screenTimeThreshold) {
      final overHours = (u.totalMinutes - screenTimeThreshold) / 60.0;
      score -= (overHours * screenTimePenaltyPerHour).round();
    }

    // 2. Social-media penalty.
    if (u.socialMinutes > socialMediaThreshold) {
      final overHours = (u.socialMinutes - socialMediaThreshold) / 60.0;
      score -= (overHours * socialPenaltyPerHour).round();
    }

    // 3. Late-night usage penalty.
    if (u.lateNightMinutes > 0) {
      final lateHours = u.lateNightMinutes / 60.0;
      score -= (lateHours * lateNightPenaltyPerHour).round();
    }

    // 4. Reel-count penalty (Phase D).
    final reels = u.totalReels;
    if (reels > reelCountThreshold) {
      final over = reels - reelCountThreshold;
      score -= ((over / 10.0) * reelPenaltyPer10).round();
    }

    return score.clamp(0, 100);
  }

  /// Returns a new `DailyUsage` with `brainScore` populated.
  DailyUsage applyTo(DailyUsage u) {
    return u.copyWith(brainScore: calculate(u));
  }

  static BrainCategory categorize(int score) {
    if (score >= 90) return BrainCategory.focusMaster;
    if (score >= 70) return BrainCategory.healthy;
    if (score >= 50) return BrainCategory.distracted;
    if (score >= 30) return BrainCategory.doomscroller;
    return BrainCategory.brainMelt;
  }
}
