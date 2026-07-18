import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../friends/providers.dart';
import '../../providers.dart';

/// Bottom sheet for inviting existing friends to a group.
class InviteFriendsSheet extends ConsumerStatefulWidget {
  const InviteFriendsSheet({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<InviteFriendsSheet> createState() =>
      _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends ConsumerState<InviteFriendsSheet> {
  final _sent = <String>{};

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsListProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Invite Friends',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select friends to invite to this group.',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: friends.when(
                  loading: () => ListView.separated(
                    controller: scrollController,
                    itemCount: 5,
                    itemBuilder: (_, __) => const AppShimmer(height: 60),
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                  ),
                  error: (e, _) => const Center(
                    child: Text(
                      'Could not load friends.',
                      style: TextStyle(color: AppColors.textSecondaryDark),
                    ),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No friends yet. Add friends first from the '
                            'Friends tab, then invite them to your group.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final f = list[i];
                        final otherId = f.otherId(
                          Supabase.instance.client.auth
                                  .currentUser?.id ??
                              '',
                        );
                        final alreadySent = _sent.contains(otherId);

                        return AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                url: f.otherAvatarUrl,
                                name: f.otherName,
                                radius: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.otherName ?? 'Unknown',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    if (f.otherEmail != null)
                                      Text(
                                        f.otherEmail!,
                                        style: const TextStyle(
                                          color:
                                              AppColors.textSecondaryDark,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (alreadySent)
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Text(
                                    'Sent ✓',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              else
                                FilledButton.tonal(
                                  onPressed: () =>
                                      _invite(otherId),
                                  child: const Text('Invite'),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _invite(String inviteeId) async {
    try {
      await ref
          .read(groupsRepositoryProvider)
          .sendInvite(widget.groupId, inviteeId);
      setState(() => _sent.add(inviteeId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }
}
