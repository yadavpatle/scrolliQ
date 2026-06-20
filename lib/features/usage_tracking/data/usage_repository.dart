import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dashboard/domain/brain_score_calculator.dart';
import '../../reel_counter/data/reel_counter_service.dart';
import '../../reel_counter/domain/entities/reel_count.dart';
import '../domain/entities/daily_usage.dart';
import 'usage_tracking_service.dart';

/// Coordinates UsageStats reads, ReelCounter snapshots, score computation,
/// and Supabase sync.
class UsageRepository {
  UsageRepository({
    required this.client,
    required this.service,
    required this.reelCounter,
    BrainScoreCalculator? calculator,
  }) : calculator = calculator ?? const BrainScoreCalculator();

  final SupabaseClient        client;
  final UsageTrackingService  service;
  final ReelCounterService    reelCounter;
  final BrainScoreCalculator  calculator;

  /// Pulls today's usage + reel counts from device, computes score, upserts.
  Future<DailyUsage> syncToday() async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Cannot sync usage when signed out.');
    }

    final raw = await service.getAggregatedUsage();
    final reels = await _safeReelSnapshot();
    final merged = _mergeReels(raw, reels);
    final scored = calculator.applyTo(merged);

    await client.from('daily_usage').upsert(
      scored.toRow(user.id),
      onConflict: 'user_id,date',
    );
    return scored;
  }

  /// Reads ReelCounter snapshot, swallowing any platform errors so a missing
  /// AccessibilityService never blocks the usage sync.
  Future<ReelCountSnapshot?> _safeReelSnapshot() async {
    try {
      return await reelCounter.getSnapshot();
    } catch (_) {
      return null;
    }
  }

  DailyUsage _mergeReels(DailyUsage usage, ReelCountSnapshot? snap) {
    if (snap == null || snap.total == 0) return usage;
    final byPlatform = snap.byPlatform;
    // Only the supported platforms are populated. TikTok/Snapchat columns
    // stay at their existing values (0) until support is re-enabled.
    return usage.copyWith(
      instagramReels: byPlatform[ReelPlatform.instagram] ?? 0,
      youtubeShorts:  byPlatform[ReelPlatform.youtubeShorts] ?? 0,
      facebookReels:  byPlatform[ReelPlatform.facebookReels] ?? 0,
    );
  }

  /// Fetches the user's recent (most-recent first) daily rows.
  Future<List<DailyUsage>> getRecent({int days = 7}) async {
    final user = client.auth.currentUser;
    if (user == null) return const [];

    final from = DateTime.now().subtract(Duration(days: days - 1));
    final fromStr = '${from.year.toString().padLeft(4, '0')}-'
        '${from.month.toString().padLeft(2, '0')}-'
        '${from.day.toString().padLeft(2, '0')}';

    final rows = await client
        .from('daily_usage')
        .select()
        .eq('user_id', user.id)
        .gte('date', fromStr)
        .order('date', ascending: true);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(DailyUsage.fromMap)
        .toList();
  }

  /// Fetches today's row from Supabase (without forcing a re-sync).
  Future<DailyUsage?> getToday() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final now = DateTime.now();
    final todayStr = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final row = await client
        .from('daily_usage')
        .select()
        .eq('user_id', user.id)
        .eq('date', todayStr)
        .maybeSingle();
    if (row == null) return null;
    return DailyUsage.fromMap(row);
  }
}
