import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../reel_counter/providers.dart';
import 'data/usage_repository.dart';
import 'data/usage_tracking_service.dart';
import 'domain/entities/daily_usage.dart';

final usageTrackingServiceProvider = Provider<UsageTrackingService>((ref) {
  return createUsageTrackingService();
});

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  return UsageRepository(
    client:      ref.watch(supabaseClientProvider),
    service:     ref.watch(usageTrackingServiceProvider),
    reelCounter: ref.watch(reelCounterServiceProvider),
  );
});

/// Re-runs whenever invalidated.  Pulls latest usage and pushes to Supabase.
final todayUsageProvider = FutureProvider<DailyUsage>((ref) async {
  final repo = ref.watch(usageRepositoryProvider);
  final svc  = ref.watch(usageTrackingServiceProvider);
  if (await svc.hasPermission()) {
    return repo.syncToday();
  }
  // No permission yet – serve last known row, or a zero-state.
  final row = await repo.getToday();
  return row ??
      DailyUsage(
        date: DateTime.now(),
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
});

final recentUsageProvider = FutureProvider<List<DailyUsage>>((ref) async {
  // Refresh today first so the latest point is included.
  await ref.watch(todayUsageProvider.future);
  return ref.watch(usageRepositoryProvider).getRecent(days: 7);
});

final usagePermissionProvider = FutureProvider<bool>((ref) {
  return ref.watch(usageTrackingServiceProvider).hasPermission();
});
