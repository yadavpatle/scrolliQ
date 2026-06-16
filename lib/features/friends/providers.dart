import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import 'data/friends_repository.dart';
import 'domain/entities/friendship.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(ref.watch(supabaseClientProvider));
});

final friendsListProvider = FutureProvider<List<Friendship>>((ref) {
  return ref.watch(friendsRepositoryProvider).friends();
});

final incomingRequestsProvider = FutureProvider<List<Friendship>>((ref) {
  return ref.watch(friendsRepositoryProvider).incomingRequests();
});

final outgoingRequestsProvider = FutureProvider<List<Friendship>>((ref) {
  return ref.watch(friendsRepositoryProvider).outgoingRequests();
});

/// Search users by name/email; query is the parameter.
final userSearchProvider =
    FutureProvider.family<List<UserSearchResult>, String>((ref, query) {
  return ref.watch(friendsRepositoryProvider).searchUsers(query);
});
