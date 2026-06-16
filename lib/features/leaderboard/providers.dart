import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import 'data/leaderboard_repository.dart';
import 'domain/entities/leaderboard_entry.dart';

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepository(ref.watch(supabaseClientProvider));
});

final leaderboardProvider =
    FutureProvider<List<LeaderboardEntry>>((ref) async {
  return ref.watch(leaderboardRepositoryProvider).fetchToday();
});

final leaderboardPreviewProvider =
    FutureProvider<List<LeaderboardEntry>>((ref) async {
  return ref.watch(leaderboardRepositoryProvider).fetchTopPreview(limit: 5);
});
