import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../domain/entities/group.dart';
import '../../providers.dart';
import '../widgets/join_group_sheet.dart';
import 'create_group_sheet.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(myGroupsProvider);
    final invites = ref.watch(pendingGroupInvitesProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceDark2,
      onRefresh: () async {
        ref.invalidate(myGroupsProvider);
        ref.invalidate(pendingGroupInvitesProvider);
        await ref.read(myGroupsProvider.future);
      },
      child: groups.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            AppShimmer(height: 120),
            SizedBox(height: 12),
            AppShimmer(height: 120),
          ],
        ),
        error: (e, _) => AppError.friendly(e, onRetry: () {
          ref.invalidate(myGroupsProvider);
        }),
        data: (groupList) {
          if (groupList.isEmpty &&
              (invites.valueOrNull ?? <GroupInvite>[]).isEmpty) {
            return _EmptyState(ref: ref);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Pending invites
              ...invites.maybeWhen(
                data: (list) => list.isEmpty
                    ? <Widget>[]
                    : [
                        _PendingInvitesBanner(invites: list),
                        const SizedBox(height: 16),
                      ],
                orElse: () => <Widget>[],
              ),

              // Action buttons row
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Create Group',
                      icon: Icons.add_rounded,
                      onPressed: () => _showCreateSheet(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Join by Code',
                      icon: Icons.qr_code_rounded,
                      onPressed: () => _showJoinSheet(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Group cards
              for (int i = 0; i < groupList.length; i++) ...[
                _GroupCard(group: groupList[i]),
                if (i < groupList.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const CreateGroupSheet(),
    );
  }

  void _showJoinSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const JoinGroupSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Group Card
// ---------------------------------------------------------------------------

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});
  final Group group;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/groups/${group.id}'),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          // Emoji avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            alignment: Alignment.center,
            child: Text(
              group.avatarEmoji,
              style: const TextStyle(fontSize: 26),
            ),
          ),
          const SizedBox(width: 14),
          // Group info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.group_outlined,
                        size: 14, color: AppColors.textSecondaryDark),
                    const SizedBox(width: 4),
                    Text(
                      '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiaryDark),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pending Invites Banner
// ---------------------------------------------------------------------------

class _PendingInvitesBanner extends ConsumerWidget {
  const _PendingInvitesBanner({required this.invites});
  final List<GroupInvite> invites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PENDING INVITES',
          style: AppText.eyebrow(color: AppColors.accent),
        ),
        const SizedBox(height: 8),
        for (final invite in invites) ...[
          AppCard(
            padding: const EdgeInsets.all(14),
            borderColor: AppColors.accent.withValues(alpha: 0.3),
            color: AppColors.accent.withValues(alpha: 0.06),
            child: Row(
              children: [
                Text(
                  invite.groupEmoji ?? '🔥',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.groupName ?? 'Group',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Invited by ${invite.inviterName ?? 'someone'}',
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle, color: AppColors.success),
                  onPressed: () async {
                    await ref
                        .read(groupsRepositoryProvider)
                        .respondInvite(invite.id, accept: true);
                    ref.invalidate(pendingGroupInvitesProvider);
                    ref.invalidate(myGroupsProvider);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: AppColors.danger),
                  onPressed: () async {
                    await ref
                        .read(groupsRepositoryProvider)
                        .respondInvite(invite.id, accept: false);
                    ref.invalidate(pendingGroupInvitesProvider);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty State
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.groups_rounded,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'No groups yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Create a group to compete with friends on Brain Scores '
          'and track your collective scroll habits.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Create your first group',
          icon: Icons.add_rounded,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.surfaceDark2,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => const CreateGroupSheet(),
            );
          },
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: 'Join with invite code',
          icon: Icons.qr_code_rounded,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.surfaceDark2,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => const JoinGroupSheet(),
            );
          },
        ),
      ],
    );
  }
}
