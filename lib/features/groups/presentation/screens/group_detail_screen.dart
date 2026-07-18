import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/stat_pill.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/group.dart';
import '../../providers.dart';
import '../widgets/invite_friends_sheet.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupMembersProvider(groupId));
    final groups = ref.watch(myGroupsProvider);
    final me = Supabase.instance.client.auth.currentUser?.id;

    // Find this group from the cached groups list.
    final group = groups.valueOrNull
        ?.where((g) => g.id == groupId)
        .firstOrNull;

    final isOwner = group?.createdBy == me;

    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? 'Group'),
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) => _handleMenuAction(context, ref, v, group),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit Group')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Group',
                      style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceDark2,
        onRefresh: () async {
          ref.invalidate(groupMembersProvider(groupId));
          ref.invalidate(myGroupsProvider);
          await ref.read(groupMembersProvider(groupId).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            // Header card
            if (group != null) _HeaderCard(group: group),
            const SizedBox(height: 24),

            // Leaderboard section
            const SectionHeader(
              eyebrow: 'Competition',
              title: "Today's Standings",
            ),
            const SizedBox(height: 12),
            members.when(
              loading: () => Column(
                children: List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: AppShimmer(height: 72),
                  ),
                ),
              ),
              error: (e, _) => AppError.friendly(e, onRetry: () {
                ref.invalidate(groupMembersProvider(groupId));
              }),
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No usage data yet today.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondaryDark),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < list.length; i++) ...[
                      _MemberRankCard(
                        member: list[i],
                        isMe: list[i].userId == me,
                      ),
                      if (i < list.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Invite & leave actions
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showInviteSheet(context),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Invite Friends'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle:
                          const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (!isOwner) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () =>
                        _confirmLeave(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(
                          color: AppColors.danger.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                    ),
                    child: const Text('Leave'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => InviteFriendsSheet(groupId: groupId),
    );
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text('You can rejoin later using the invite code.'),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Leave',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(groupsRepositoryProvider).leaveGroup(groupId);
    ref.invalidate(myGroupsProvider);
    if (context.mounted) context.pop();
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    Group? group,
  ) {
    switch (action) {
      case 'delete':
        _confirmDelete(context, ref);
        break;
      case 'edit':
        // TODO: Implement edit group sheet
        break;
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group?'),
        content: const Text(
            'This will remove the group and all members. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(groupsRepositoryProvider).deleteGroup(groupId);
    ref.invalidate(myGroupsProvider);
    if (context.mounted) context.pop();
  }
}

// ---------------------------------------------------------------------------
// Header Card — emoji, name, invite code
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.group});
  final Group group;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: const LinearGradient(
        colors: [Color(0xFF1E2330), Color(0xFF15171D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          // Emoji + name
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            alignment: Alignment.center,
            child: Text(group.avatarEmoji,
                style: const TextStyle(fontSize: 34)),
          ),
          const SizedBox(height: 12),
          Text(
            group.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          if (group.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              group.description,
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 6),
          StatPill(
            label:
                '${group.memberCount} / ${group.maxMembers} members',
            icon: Icons.group_outlined,
            color: AppColors.primary,
            dense: true,
          ),
          const SizedBox(height: 16),

          // Invite code row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                  color: AppColors.borderDark.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.key_rounded,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  group.inviteCode,
                  style: AppText.mono(
                    size: 18,
                    color: AppColors.accent,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                _CopyButton(code: group.inviteCode),
                const SizedBox(width: 6),
                _ShareButton(code: group.inviteCode, name: group.name),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite code copied!')),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.code, required this.name});
  final String code;
  final String name;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        SharePlus.instance.share(
          ShareParams(
            text:
              'Join my ScrollIQ group "$name"! Use invite code: $code',
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.ios_share_rounded,
            size: 16, color: AppColors.primary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Member Rank Card
// ---------------------------------------------------------------------------

class _MemberRankCard extends StatelessWidget {
  const _MemberRankCard({required this.member, required this.isMe});
  final GroupMember member;
  final bool isMe;

  String get _rankEmoji => switch (member.rank) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => '#${member.rank}',
      };

  Color get _scoreColor {
    final s = member.todayBrainScore;
    if (s >= 90) return AppColors.scoreFocusMaster;
    if (s >= 70) return AppColors.scoreHealthy;
    if (s >= 50) return AppColors.scoreDistracted;
    if (s >= 30) return AppColors.scoreDoomscroller;
    return AppColors.scoreBrainMelt;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: isMe
          ? AppColors.primary.withValues(alpha: 0.4)
          : null,
      color: isMe ? AppColors.primary.withValues(alpha: 0.06) : null,
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 36,
            child: member.rank <= 3
                ? Text(_rankEmoji,
                    style: const TextStyle(fontSize: 22),
                    textAlign: TextAlign.center)
                : Text(
                    _rankEmoji,
                    style: AppText.mono(
                      size: 14,
                      color: AppColors.textSecondaryDark,
                      weight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 10),
          // Avatar
          UserAvatar(
            url: member.userAvatarUrl,
            name: member.userName,
            radius: 20,
          ),
          const SizedBox(width: 12),
          // Name + role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.userName ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isMe
                            ? AppColors.primary
                            : AppColors.textPrimaryDark,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      const StatPill(
                        label: 'You',
                        color: AppColors.primary,
                        filled: true,
                        dense: true,
                      ),
                    ],
                  ],
                ),
                if (member.role != GroupRole.member)
                  Text(
                    member.role.name,
                    style: const TextStyle(
                      color: AppColors.textTertiaryDark,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          // Score + reels
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${member.todayBrainScore}',
                style: AppText.statSmall(color: _scoreColor),
              ),
              Text(
                '${member.todayReels} reels',
                style: const TextStyle(
                  color: AppColors.textTertiaryDark,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
