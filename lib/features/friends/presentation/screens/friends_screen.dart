import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../referral/providers.dart';
import '../../domain/entities/friendship.dart';
import '../../providers.dart';
import '../widgets/invite_code_card.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(referralServiceProvider).shareInvite(),
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Invite'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Friends'),
              Tab(text: 'Requests'),
              Tab(text: 'Find'),
            ],
            indicatorColor: AppColors.primary,
          ),
        ),
        body: const TabBarView(
          children: [
            _FriendsTab(),
            _RequestsTab(),
            _SearchTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(friendsListProvider);
    return list.when(
      loading: () => _shimmerList(),
      error:   (e, _) => AppError(message: e.toString()),
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(friendsListProvider),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 32),
                const Icon(
                  Icons.group_add_outlined,
                  size: 56,
                  color: AppColors.textSecondaryDark,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No friends yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Invite friends to compare Brain Scores and challenge '
                  'each other to scroll less.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondaryDark),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(referralServiceProvider).shareInvite(),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Invite a friend'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(friendsListProvider),
          color: AppColors.primary,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _FriendTile(
              friendship: items[i],
              trailing: IconButton(
                icon: const Icon(Icons.person_remove_outlined,
                    color: AppColors.danger),
                onPressed: () async {
                  await ref
                      .read(friendsRepositoryProvider)
                      .remove(items[i].id);
                  ref.invalidate(friendsListProvider);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingRequestsProvider);
    final outgoing = ref.watch(outgoingRequestsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(incomingRequestsProvider);
        ref.invalidate(outgoingRequestsProvider);
      },
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Incoming',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          incoming.when(
            loading: () => const AppShimmer(height: 80),
            error:   (e, _) => AppError(message: e.toString()),
            data: (items) => items.isEmpty
                ? const _Empty(message: 'No pending requests.')
                : Column(
                    children: items
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _FriendTile(
                                friendship: f,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check_circle,
                                          color: AppColors.success),
                                      onPressed: () async {
                                        await ref
                                            .read(friendsRepositoryProvider)
                                            .respond(f.id, accept: true);
                                        ref.invalidate(incomingRequestsProvider);
                                        ref.invalidate(friendsListProvider);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.cancel,
                                          color: AppColors.danger),
                                      onPressed: () async {
                                        await ref
                                            .read(friendsRepositoryProvider)
                                            .respond(f.id, accept: false);
                                        ref.invalidate(incomingRequestsProvider);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 24),
          const Text('Sent',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          outgoing.when(
            loading: () => const AppShimmer(height: 80),
            error:   (e, _) => AppError(message: e.toString()),
            data: (items) => items.isEmpty
                ? const _Empty(message: 'No outgoing requests.')
                : Column(
                    children: items
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _FriendTile(
                                friendship: f,
                                trailing: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    'Pending',
                                    style: TextStyle(
                                      color: AppColors.textSecondaryDark,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();
  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(userSearchProvider(_query));
    return CustomScrollView(
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: InviteCodeCard(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (_query.trim().length < 2)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _Empty(message: 'Type at least 2 characters to search.'),
          )
        else
          ...results.when(
            loading: () => [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: 6,
                  itemBuilder: (_, __) => const AppShimmer(height: 64),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                ),
              ),
            ],
            error: (e, _) => [
              SliverToBoxAdapter(child: AppError(message: e.toString())),
            ],
            data: (items) {
              if (items.isEmpty) {
                return [
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Empty(message: 'No users found.'),
                  ),
                ];
              }
              return [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final u = items[i];
                      return AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            UserAvatar(url: u.avatarUrl, name: u.name, radius: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  Text(u.email,
                                      style: const TextStyle(
                                        color: AppColors.textSecondaryDark,
                                        fontSize: 12,
                                      )),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(friendsRepositoryProvider)
                                      .sendRequest(u.id);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Friend request sent.')),
                                  );
                                  ref.invalidate(outgoingRequestsProvider);
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              },
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ];
            },
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friendship, this.trailing});
  final Friendship friendship;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          UserAvatar(
            url: friendship.otherAvatarUrl,
            name: friendship.otherName,
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friendship.otherName ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (friendship.otherEmail != null)
                  Text(
                    friendship.otherEmail!,
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondaryDark),
        ),
      ),
    );
  }
}

Widget _shimmerList() => ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => const AppShimmer(height: 64),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
    );
