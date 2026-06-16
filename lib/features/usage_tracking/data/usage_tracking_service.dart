import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/entities/daily_usage.dart';

/// Platform-agnostic abstraction.  iOS implementation can be added later
/// (Apple's Screen Time API requires extensions; this stub keeps the API stable).
abstract class UsageTrackingService {
  /// Whether the platform supports tracking and the user has granted access.
  Future<bool> hasPermission();

  /// Open the relevant settings UI to grant access.
  Future<void> requestPermission();

  /// Returns per-app usage for `day` (defaults to today).
  Future<List<AppUsage>> getDailyUsage({DateTime? day});

  /// Convenience wrapper that returns aggregated daily usage with brain score.
  Future<DailyUsage> getAggregatedUsage({DateTime? day});
}

/// Stub used on platforms without a native implementation (iOS, web, desktop).
class NoopUsageTrackingService implements UsageTrackingService {
  @override
  Future<List<AppUsage>> getDailyUsage({DateTime? day}) async => const [];

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<DailyUsage> getAggregatedUsage({DateTime? day}) async {
    final d = day ?? DateTime.now();
    return DailyUsage(
      date: DateTime(d.year, d.month, d.day),
      totalMinutes: 0,
      instagramMinutes: 0,
      youtubeMinutes: 0,
      tiktokMinutes: 0,
      facebookMinutes: 0,
      snapchatMinutes: 0,
      twitterMinutes: 0,
      lateNightMinutes: 0,
      brainScore: 100,
    );
  }
}

/// Android implementation backed by `UsageStatsManager` via MethodChannel.
class AndroidUsageTrackingService implements UsageTrackingService {
  static const _channel = MethodChannel('com.scrolliq/usage_stats');

  @override
  Future<bool> hasPermission() async {
    final ok = await _channel.invokeMethod<bool>('hasPermission');
    return ok ?? false;
  }

  @override
  Future<void> requestPermission() async {
    await _channel.invokeMethod<void>('requestPermission');
  }

  @override
  Future<List<AppUsage>> getDailyUsage({DateTime? day}) async {
    final d = day ?? DateTime.now();
    final start = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    final end   = DateTime(d.year, d.month, d.day, 23, 59, 59).millisecondsSinceEpoch;

    final raw = await _channel.invokeMethod<List<dynamic>>('queryUsage', {
      'start': start,
      'end':   end,
    });
    if (raw == null) return const [];
    return raw
        .cast<Map<dynamic, dynamic>>()
        .map((m) => AppUsage(
              packageName: m['packageName'] as String,
              appName: (m['appName'] as String?) ??
                  AppConstants.trackedApps[m['packageName']] ??
                  m['packageName'] as String,
              minutes: ((m['totalTimeMs'] as num?) ?? 0).toInt() ~/ 60000,
            ))
        .where((u) => u.minutes > 0)
        .toList();
  }

  @override
  Future<DailyUsage> getAggregatedUsage({DateTime? day}) async {
    final d = day ?? DateTime.now();
    final usages = await getDailyUsage(day: d);

    int instagram = 0, youtube = 0, tiktok = 0;
    int facebook = 0, snapchat = 0, twitter = 0;
    int total = 0;

    for (final u in usages) {
      total += u.minutes;
      switch (u.packageName) {
        case 'com.instagram.android':                instagram += u.minutes; break;
        case 'com.google.android.youtube':           youtube   += u.minutes; break;
        case 'com.zhiliaoapp.musically':
        case 'com.ss.android.ugc.trill':             tiktok    += u.minutes; break;
        case 'com.facebook.katana':                  facebook  += u.minutes; break;
        case 'com.snapchat.android':                 snapchat  += u.minutes; break;
        case 'com.twitter.android':                  twitter   += u.minutes; break;
      }
    }

    // Late-night minutes need fine-grained event data; for MVP we approximate
    // with hour-by-hour buckets queried from native side.
    int lateNight = 0;
    try {
      final start = DateTime(d.year, d.month, d.day, AppConstants.lateNightStartHour);
      final end   = DateTime(d.year, d.month, d.day, AppConstants.lateNightEndHour);
      final raw = await _channel.invokeMethod<int>('queryRangeMinutes', {
        'start': start.millisecondsSinceEpoch,
        'end':   end.millisecondsSinceEpoch,
      });
      lateNight = raw ?? 0;
    } catch (_) {/* ignore */ }

    return DailyUsage(
      date: DateTime(d.year, d.month, d.day),
      totalMinutes: total,
      instagramMinutes: instagram,
      youtubeMinutes: youtube,
      tiktokMinutes: tiktok,
      facebookMinutes: facebook,
      snapchatMinutes: snapchat,
      twitterMinutes: twitter,
      lateNightMinutes: lateNight,
      // Rough heuristics — real reel/short detection requires accessibility
      // service; MVP estimates ~70% of in-app time on short-video platforms.
      reelsEstimated:  (instagram * 0.7).round(),
      shortsEstimated: (youtube   * 0.4).round() + (tiktok * 0.9).round(),
      brainScore: 100, // computed downstream by BrainScoreCalculator
    );
  }
}

/// Factory that returns the right implementation per platform.
UsageTrackingService createUsageTrackingService() {
  if (Platform.isAndroid) return AndroidUsageTrackingService();
  return NoopUsageTrackingService();
}
