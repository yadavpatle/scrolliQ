import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import 'data/profile_repository.dart';
import 'domain/entities/user_stats.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final myStatsProvider = FutureProvider<UserStats?>((ref) {
  return ref.watch(profileRepositoryProvider).myStats();
});
