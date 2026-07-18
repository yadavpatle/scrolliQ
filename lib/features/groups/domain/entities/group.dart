import 'package:equatable/equatable.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum GroupRole { owner, admin, member }

GroupRole _parseRole(String s) => switch (s) {
      'owner' => GroupRole.owner,
      'admin' => GroupRole.admin,
      'member' => GroupRole.member,
      _ => GroupRole.member,
    };

enum GroupInviteStatus { pending, accepted, declined }

GroupInviteStatus _parseInviteStatus(String s) => switch (s) {
      'pending' => GroupInviteStatus.pending,
      'accepted' => GroupInviteStatus.accepted,
      'declined' => GroupInviteStatus.declined,
      _ => GroupInviteStatus.pending,
    };

// ---------------------------------------------------------------------------
// Group
// ---------------------------------------------------------------------------

class Group extends Equatable {
  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.avatarEmoji,
    required this.createdBy,
    required this.inviteCode,
    required this.maxMembers,
    required this.memberCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String avatarEmoji;
  final String createdBy;
  final String inviteCode;
  final int maxMembers;
  final int memberCount;
  final DateTime createdAt;

  factory Group.fromMap(Map<String, dynamic> m) => Group(
        id: m['id'].toString(),
        name: (m['name'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        avatarEmoji: (m['avatar_emoji'] as String?) ?? '🔥',
        createdBy: m['created_by'].toString(),
        inviteCode: (m['invite_code'] as String?) ?? '',
        maxMembers: (m['max_members'] as num?)?.toInt() ?? 20,
        memberCount: (m['member_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(m['created_at'].toString()),
      );

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        avatarEmoji,
        createdBy,
        inviteCode,
        maxMembers,
        memberCount,
        createdAt,
      ];
}

// ---------------------------------------------------------------------------
// GroupMember
// ---------------------------------------------------------------------------

class GroupMember extends Equatable {
  const GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.userName,
    this.userAvatarUrl,
    this.todayBrainScore = 0,
    this.todayReels = 0,
    this.rank = 0,
  });

  final String id;
  final String groupId;
  final String userId;
  final GroupRole role;
  final DateTime joinedAt;
  final String? userName;
  final String? userAvatarUrl;
  final int todayBrainScore;
  final int todayReels;
  final int rank;

  factory GroupMember.fromMap(Map<String, dynamic> m) => GroupMember(
        id: m['id'].toString(),
        groupId: m['group_id'].toString(),
        userId: m['user_id'].toString(),
        role: _parseRole(m['role'].toString()),
        joinedAt: DateTime.parse(m['joined_at'].toString()),
        userName: m['user_name'] as String?,
        userAvatarUrl: m['user_avatar_url'] as String?,
        todayBrainScore: (m['brain_score'] as num?)?.toInt() ?? 0,
        todayReels: (m['total_reels'] as num?)?.toInt() ?? 0,
        rank: (m['rank'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [
        id,
        groupId,
        userId,
        role,
        joinedAt,
        userName,
        userAvatarUrl,
        todayBrainScore,
        todayReels,
        rank,
      ];
}

// ---------------------------------------------------------------------------
// GroupInvite
// ---------------------------------------------------------------------------

class GroupInvite extends Equatable {
  const GroupInvite({
    required this.id,
    required this.groupId,
    required this.inviterId,
    required this.inviteeId,
    required this.status,
    required this.createdAt,
    this.groupName,
    this.groupEmoji,
    this.inviterName,
  });

  final String id;
  final String groupId;
  final String inviterId;
  final String inviteeId;
  final GroupInviteStatus status;
  final DateTime createdAt;
  final String? groupName;
  final String? groupEmoji;
  final String? inviterName;

  factory GroupInvite.fromMap(Map<String, dynamic> m) {
    final group = m['group'] as Map<String, dynamic>?;
    final inviter = m['inviter'] as Map<String, dynamic>?;

    return GroupInvite(
      id: m['id'].toString(),
      groupId: m['group_id'].toString(),
      inviterId: m['inviter_id'].toString(),
      inviteeId: m['invitee_id'].toString(),
      status: _parseInviteStatus(m['status'].toString()),
      createdAt: DateTime.parse(m['created_at'].toString()),
      groupName: group?['name'] as String?,
      groupEmoji: group?['avatar_emoji'] as String?,
      inviterName: inviter?['name'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        groupId,
        inviterId,
        inviteeId,
        status,
        createdAt,
      ];
}
