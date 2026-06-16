import 'package:flutter_test/flutter_test.dart';
import 'package:scrolliq/features/dashboard/domain/brain_score_calculator.dart';
import 'package:scrolliq/features/usage_tracking/domain/entities/daily_usage.dart';

DailyUsage _u({
  int total = 0,
  int instagram = 0,
  int youtube = 0,
  int tiktok = 0,
  int facebook = 0,
  int snapchat = 0,
  int twitter = 0,
  int lateNight = 0,
  int instagramReels = 0,
  int youtubeShorts = 0,
  int tiktokReels = 0,
  int snapchatSpotlight = 0,
  int facebookReels = 0,
}) =>
    DailyUsage(
      date: DateTime(2024, 1, 1),
      totalMinutes: total,
      instagramMinutes: instagram,
      youtubeMinutes: youtube,
      tiktokMinutes: tiktok,
      facebookMinutes: facebook,
      snapchatMinutes: snapchat,
      twitterMinutes: twitter,
      lateNightMinutes: lateNight,
      brainScore: 0,
      instagramReels: instagramReels,
      youtubeShorts: youtubeShorts,
      tiktokReels: tiktokReels,
      snapchatSpotlight: snapchatSpotlight,
      facebookReels: facebookReels,
    );

void main() {
  const calc = BrainScoreCalculator();

  test('returns 100 when no usage', () {
    expect(calc.calculate(_u()), 100);
  });

  test('returns 100 when usage is below thresholds', () {
    expect(calc.calculate(_u(total: 90, instagram: 30)), 100);
  });

  test('penalizes screen time above 2h', () {
    // 3h total → 1h over → -8 points
    final score = calc.calculate(_u(total: 180));
    expect(score, 92);
  });

  test('penalizes social media above 1h', () {
    // 90m social → 30m over → -6 points
    final score = calc.calculate(_u(total: 90, instagram: 90));
    expect(score, 94);
  });

  test('penalizes late-night usage', () {
    // 60m late night → -15
    expect(calc.calculate(_u(lateNight: 60)), 85);
  });

  test('clamps to 0 when penalties exceed 100', () {
    final score = calc.calculate(_u(
      total: 720,        // 12h
      instagram: 360,    // 6h social
      lateNight: 240,    // 4h late
    ));
    expect(score, 0);
  });

  test('categorizes scores correctly', () {
    expect(BrainScoreCalculator.categorize(95), BrainCategory.focusMaster);
    expect(BrainScoreCalculator.categorize(75), BrainCategory.healthy);
    expect(BrainScoreCalculator.categorize(55), BrainCategory.distracted);
    expect(BrainScoreCalculator.categorize(35), BrainCategory.doomscroller);
    expect(BrainScoreCalculator.categorize(10), BrainCategory.brainMelt);
  });

  test('applyTo returns new DailyUsage with score populated', () {
    final scored = calc.applyTo(_u(total: 180));
    expect(scored.brainScore, 92);
    expect(scored.totalMinutes, 180);
  });

  // ---- Phase D: Reel-count penalty tests ----

  test('no penalty when reels <= threshold (30)', () {
    expect(calc.calculate(_u(instagramReels: 20, youtubeShorts: 10)), 100);
  });

  test('penalizes reels above threshold', () {
    // 60 total reels → 30 over → 3 * (30/10) = 9 points
    final score = calc.calculate(_u(instagramReels: 40, youtubeShorts: 20));
    expect(score, 91);
  });

  test('reel penalty stacks with other penalties', () {
    // 3h total → -8, 60 reels → -9
    final score = calc.calculate(_u(total: 180, instagramReels: 60));
    expect(score, 83);
  });

  test('combined with all penalties clamps to 0', () {
    final score = calc.calculate(_u(
      total: 720,
      instagram: 360,
      lateNight: 240,
      instagramReels: 500,
    ));
    expect(score, 0);
  });
}
