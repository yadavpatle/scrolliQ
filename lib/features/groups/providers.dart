import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import 'data/groups_repository.dart';
import 'domain/entities/group.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(ref.watch(supabaseClientProvider));
});

final myGroupsProvider = FutureProvider<List<Group>>((ref) {
  return ref.watch(groupsRepositoryProvider).myGroups();
});

final groupMembersProvider =
    FutureProvider.family<List<GroupMember>, String>((ref, groupId) {
  return ref.watch(groupsRepositoryProvider).groupMembers(groupId);
});

final pendingGroupInvitesProvider =
    FutureProvider<List<GroupInvite>>((ref) {
  return ref.watch(groupsRepositoryProvider).myPendingInvites();
});
