import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import 'data/referral_repository.dart';
import 'referral_service.dart';

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  return ReferralRepository(ref.watch(supabaseClientProvider));
});

/// Long-lived service that captures invite links and redeems them after auth.
/// Call `init()` once at app start (see `main.dart`).
final referralServiceProvider = Provider<ReferralService>((ref) {
  final service = ReferralService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// The current user's shareable invite link.
final myReferralLinkProvider = FutureProvider<String>((ref) {
  return ref.watch(referralRepositoryProvider).myReferralLink();
});
