import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import 'data/challenges_repository.dart';
import 'domain/entities/challenge.dart';

final challengesRepositoryProvider = Provider<ChallengesRepository>((ref) {
  return ChallengesRepository(ref.watch(supabaseClientProvider));
});

final challengesProvider = FutureProvider<List<Challenge>>((ref) {
  return ref.watch(challengesRepositoryProvider).listAll();
});

final myChallengeProgressProvider =
    FutureProvider<List<ChallengeProgress>>((ref) {
  return ref.watch(challengesRepositoryProvider).myProgress();
});
