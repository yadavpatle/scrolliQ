import 'package:equatable/equatable.dart';

/// Per-app usage in minutes for a given day.
class AppUsage extends Equatable {
  const AppUsage({
    required this.packageName,
    required this.appName,
    required this.minutes,
  });

  final String packageName;
  final String appName;
  final int    minutes;

  @override
  List<Object?> get props => [packageName, appName, minutes];
}

/// Aggregated daily usage breakdown.
class DailyUsage extends Equatable {
  const DailyUsage({
    required this.date,
    required this.totalMinutes,
    required this.instagramMinutes,
    required this.youtubeMinutes,
    required this.tiktokMinutes,
    required this.facebookMinutes,
    required this.snapchatMinutes,
    required this.twitterMinutes,
    required this.lateNightMinutes,
    required this.brainScore,
    this.reelsEstimated  = 0,
    this.shortsEstimated = 0,
    this.instagramReels    = 0,
    this.youtubeShorts     = 0,
    this.tiktokReels       = 0,
    this.snapchatSpotlight = 0,
    this.facebookReels     = 0,
  });

  final DateTime date;
  final int totalMinutes;
  final int instagramMinutes;
  final int youtubeMinutes;
  final int tiktokMinutes;
  final int facebookMinutes;
  final int snapchatMinutes;
  final int twitterMinutes;
  final int lateNightMinutes;
  final int brainScore;

  // Heuristic estimates (Phase 0, derived from minutes-on-app).
  final int reelsEstimated;
  final int shortsEstimated;

  // Accurate counts from the AccessibilityService (Phase A).
  final int instagramReels;
  final int youtubeShorts;
  final int tiktokReels;
  final int snapchatSpotlight;
  final int facebookReels;

  int get socialMinutes =>
      instagramMinutes + youtubeMinutes + tiktokMinutes +
      facebookMinutes + snapchatMinutes + twitterMinutes;

  /// Sum of accurate per-platform reel counts. Mirrors the generated
  /// `total_reels` column in Postgres.
  int get totalReels =>
      instagramReels + youtubeShorts + tiktokReels +
      snapchatSpotlight + facebookReels;

  DailyUsage copyWith({
    DateTime? date,
    int? totalMinutes,
    int? instagramMinutes,
    int? youtubeMinutes,
    int? tiktokMinutes,
    int? facebookMinutes,
    int? snapchatMinutes,
    int? twitterMinutes,
    int? lateNightMinutes,
    int? brainScore,
    int? reelsEstimated,
    int? shortsEstimated,
    int? instagramReels,
    int? youtubeShorts,
    int? tiktokReels,
    int? snapchatSpotlight,
    int? facebookReels,
  }) =>
      DailyUsage(
        date:              date ?? this.date,
        totalMinutes:      totalMinutes ?? this.totalMinutes,
        instagramMinutes:  instagramMinutes ?? this.instagramMinutes,
        youtubeMinutes:    youtubeMinutes ?? this.youtubeMinutes,
        tiktokMinutes:     tiktokMinutes ?? this.tiktokMinutes,
        facebookMinutes:   facebookMinutes ?? this.facebookMinutes,
        snapchatMinutes:   snapchatMinutes ?? this.snapchatMinutes,
        twitterMinutes:    twitterMinutes ?? this.twitterMinutes,
        lateNightMinutes:  lateNightMinutes ?? this.lateNightMinutes,
        brainScore:        brainScore ?? this.brainScore,
        reelsEstimated:    reelsEstimated ?? this.reelsEstimated,
        shortsEstimated:   shortsEstimated ?? this.shortsEstimated,
        instagramReels:    instagramReels ?? this.instagramReels,
        youtubeShorts:     youtubeShorts ?? this.youtubeShorts,
        tiktokReels:       tiktokReels ?? this.tiktokReels,
        snapchatSpotlight: snapchatSpotlight ?? this.snapchatSpotlight,
        facebookReels:     facebookReels ?? this.facebookReels,
      );

  factory DailyUsage.fromMap(Map<String, dynamic> m) => DailyUsage(
        date: DateTime.parse(m['date'].toString()),
        totalMinutes:      (m['total_screen_time']  as num?)?.toInt() ?? 0,
        instagramMinutes:  (m['instagram_time']     as num?)?.toInt() ?? 0,
        youtubeMinutes:    (m['youtube_time']       as num?)?.toInt() ?? 0,
        tiktokMinutes:     (m['tiktok_time']        as num?)?.toInt() ?? 0,
        facebookMinutes:   (m['facebook_time']      as num?)?.toInt() ?? 0,
        snapchatMinutes:   (m['snapchat_time']      as num?)?.toInt() ?? 0,
        twitterMinutes:    (m['twitter_time']       as num?)?.toInt() ?? 0,
        lateNightMinutes:  (m['late_night_minutes'] as num?)?.toInt() ?? 0,
        brainScore:        (m['brain_score']        as num?)?.toInt() ?? 100,
        reelsEstimated:    (m['reels_estimated']    as num?)?.toInt() ?? 0,
        shortsEstimated:   (m['shorts_estimated']   as num?)?.toInt() ?? 0,
        instagramReels:    (m['instagram_reels']    as num?)?.toInt() ?? 0,
        youtubeShorts:     (m['youtube_shorts']     as num?)?.toInt() ?? 0,
        tiktokReels:       (m['tiktok_reels']       as num?)?.toInt() ?? 0,
        snapchatSpotlight: (m['snapchat_spotlight'] as num?)?.toInt() ?? 0,
        facebookReels:     (m['facebook_reels']     as num?)?.toInt() ?? 0,
      );

  /// Note: `total_reels` is a Postgres GENERATED column — never include it
  /// in the upsert payload or the server rejects the row.
  Map<String, dynamic> toRow(String userId) => {
        'user_id': userId,
        'date': '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'total_screen_time':  totalMinutes,
        'instagram_time':     instagramMinutes,
        'youtube_time':       youtubeMinutes,
        'tiktok_time':        tiktokMinutes,
        'facebook_time':      facebookMinutes,
        'snapchat_time':      snapchatMinutes,
        'twitter_time':       twitterMinutes,
        'reels_estimated':    reelsEstimated,
        'shorts_estimated':   shortsEstimated,
        'instagram_reels':    instagramReels,
        'youtube_shorts':     youtubeShorts,
        'tiktok_reels':       tiktokReels,
        'snapchat_spotlight': snapchatSpotlight,
        'facebook_reels':     facebookReels,
        'late_night_minutes': lateNightMinutes,
        'brain_score':        brainScore,
      };

  @override
  List<Object?> get props => [
        date, totalMinutes, instagramMinutes, youtubeMinutes,
        tiktokMinutes, facebookMinutes, snapchatMinutes, twitterMinutes,
        lateNightMinutes, brainScore, reelsEstimated, shortsEstimated,
        instagramReels, youtubeShorts, tiktokReels,
        snapchatSpotlight, facebookReels,
      ];
}
