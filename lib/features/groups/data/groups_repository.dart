import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/group.dart';

class GroupsRepository {
  GroupsRepository(this._client);
  final SupabaseClient _client;

  String? get _me => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Groups CRUD
  // ---------------------------------------------------------------------------

  /// Fetch all groups the current user belongs to, including member count.
  Future<List<Group>> myGroups() async {
    final me = _me;
    if (me == null) return const [];

    try {
      // Step 1: Get group IDs the user belongs to.
      final memberRows = await _client
          .from('group_members')
          .select('group_id')
          .eq('user_id', me);

      final groupIds = (memberRows as List)
          .cast<Map<String, dynamic>>()
          .map((r) => r['group_id'].toString())
          .toList();

      if (groupIds.isEmpty) return const [];

      // Step 2: Fetch those groups.
      final groupRows = await _client
          .from('groups')
          .select()
          .inFilter('id', groupIds);

      final groups = <Group>[];
      for (final g in (groupRows as List).cast<Map<String, dynamic>>()) {
        // Step 3: Count members per group.
        final countResult = await _client
            .from('group_members')
            .select()
            .eq('group_id', g['id'])
            .count(CountOption.exact);

        groups.add(Group.fromMap({
          ...g,
          'member_count': countResult.count,
        }));
      }
      return groups;
    } catch (e, st) {
      debugPrint('GroupsRepository.myGroups error: $e\n$st');
      rethrow;
    }
  }

  /// Create a new group. The current user becomes the owner.
  ///
  /// Uses the `create_group` RPC (security definer) so the group row and the
  /// owner `group_members` row are inserted atomically. This also avoids a
  /// PostgREST edge case where the `.from('groups').insert(...)` path can be
  /// rejected by the "Groups: insert self" RLS policy even when
  /// `auth.uid() = created_by`.
  Future<Group> createGroup({
    required String name,
    String description = '',
    String avatarEmoji = '🔥',
  }) async {
    final me = _me;
    if (me == null) throw StateError('Not signed in');

    final result = await _client.rpc('create_group', params: {
      'p_name': name,
      'p_description': description,
      'p_avatar_emoji': avatarEmoji,
    });

    if (result == null) {
      throw StateError('create_group returned null');
    }

    final row = Map<String, dynamic>.from(result as Map);
    return Group.fromMap({...row, 'member_count': 1});
  }

  /// Update group details (owner only).
  Future<void> updateGroup(
    String groupId, {
    String? name,
    String? description,
    String? avatarEmoji,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (avatarEmoji != null) updates['avatar_emoji'] = avatarEmoji;
    if (updates.isEmpty) return;

    await _client.from('groups').update(updates).eq('id', groupId);
  }

  /// Delete a group (owner only — cascades to members + invites).
  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
  }

  // ---------------------------------------------------------------------------
  // Members
  // ---------------------------------------------------------------------------

  /// Fetch members of a group with today's brain score from the leaderboard
  /// view (ranked by brain_score DESC).
  Future<List<GroupMember>> groupMembers(String groupId) async {
    final rows = await _client
        .from('group_leaderboard')
        .select()
        .eq('group_id', groupId)
        .order('rank');

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((m) => GroupMember(
              id: '${m['group_id']}_${m['user_id']}',
              groupId: m['group_id'].toString(),
              userId: m['user_id'].toString(),
              role: _parseRole(m['role'].toString()),
              joinedAt: DateTime.now(), // View doesn't expose joined_at
              userName: m['user_name'] as String?,
              userAvatarUrl: m['user_avatar_url'] as String?,
              todayBrainScore: (m['brain_score'] as num?)?.toInt() ?? 0,
              todayReels: (m['total_reels'] as num?)?.toInt() ?? 0,
              rank: (m['rank'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  /// Join a group using an invite code.
  Future<String> joinByCode(String code) async {
    final result = await _client.rpc(
      'join_group_by_code',
      params: {'code': code.trim()},
    );
    return result.toString();
  }

  /// Leave a group (removes own membership).
  Future<void> leaveGroup(String groupId) async {
    final me = _me;
    if (me == null) return;
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', me);
  }

  /// Remove a member from a group (owner/admin).
  Future<void> removeMember(String groupId, String userId) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  // ---------------------------------------------------------------------------
  // In-app invites
  // ---------------------------------------------------------------------------

  /// Send an in-app group invite to a friend.
  Future<void> sendInvite(String groupId, String inviteeId) async {
    final me = _me;
    if (me == null) throw StateError('Not signed in');
    await _client.from('group_invites').upsert(
      {
        'group_id': groupId,
        'inviter_id': me,
        'invitee_id': inviteeId,
        'status': 'pending',
      },
      onConflict: 'group_id,invitee_id',
    );
  }

  /// Respond to an invite. If accepted, also joins the group as a member.
  Future<void> respondInvite(String inviteId, {required bool accept}) async {
    final me = _me;
    if (me == null) return;

    if (accept) {
      // Fetch the invite to get group_id.
      final invite = await _client
          .from('group_invites')
          .select('group_id')
          .eq('id', inviteId)
          .single();

      // Update invite status.
      await _client.from('group_invites').update({
        'status': 'accepted',
      }).eq('id', inviteId);

      // Add as member (ignore if already exists).
      await _client.from('group_members').upsert(
        {
          'group_id': invite['group_id'],
          'user_id': me,
          'role': 'member',
        },
        onConflict: 'group_id,user_id',
      );
    } else {
      await _client.from('group_invites').update({
        'status': 'declined',
      }).eq('id', inviteId);
    }
  }

  /// Fetch pending group invites for the current user.
  Future<List<GroupInvite>> myPendingInvites() async {
    final me = _me;
    if (me == null) return const [];

    try {
      final rows = await _client
          .from('group_invites')
          .select()
          .eq('invitee_id', me)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final invites = <GroupInvite>[];
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        // Enrich with group name / emoji.
        String? groupName;
        String? groupEmoji;
        String? inviterName;
        try {
          final g = await _client
              .from('groups')
              .select('name, avatar_emoji')
              .eq('id', row['group_id'])
              .maybeSingle();
          groupName = g?['name'] as String?;
          groupEmoji = g?['avatar_emoji'] as String?;
        } catch (_) {}

        try {
          final u = await _client
              .from('users')
              .select('name')
              .eq('id', row['inviter_id'])
              .maybeSingle();
          inviterName = u?['name'] as String?;
        } catch (_) {}

        invites.add(GroupInvite.fromMap({
          ...row,
          'group': {'name': groupName, 'avatar_emoji': groupEmoji},
          'inviter': {'name': inviterName},
        }));
      }
      return invites;
    } catch (e, st) {
      debugPrint('GroupsRepository.myPendingInvites error: $e\n$st');
      rethrow;
    }
  }
}

GroupRole _parseRole(String s) => switch (s) {
      'owner' => GroupRole.owner,
      'admin' => GroupRole.admin,
      'member' => GroupRole.member,
      _ => GroupRole.member,
    };
