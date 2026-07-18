import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../domain/entities/challenge.dart';
import '../../providers.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../../groups/presentation/screens/groups_list_screen.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Goals'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Challenges'),
              Tab(text: 'Friends'),
              Tab(text: 'Groups'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondaryDark,
          ),
        ),
        body: const TabBarView(
          children: [
            _ChallengesTab(),
            FriendsContent(),
            GroupsListScreen(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Challenges Tab — extracted from the original ChallengesScreen
// ---------------------------------------------------------------------------

class _ChallengesTab extends ConsumerWidget {
  const _ChallengesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(challengesProvider);
    final progress = ref.watch(myChallengeProgressProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(challengesProvider);
        ref.invalidate(myChallengeProgressProvider);
        await ref.read(challengesProvider.future);
      },
      child: challenges.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            AppShimmer(height: 200),
            SizedBox(height: 12),
            AppShimmer(height: 120),
          ],
        ),
        error: (e, _) => AppError.friendly(e, onRetry: () {
          ref.invalidate(challengesProvider);
        }),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No challenges yet.',
                  style: TextStyle(color: AppColors.textSecondaryDark)),
            );
          }
          final progressMap = {
            for (final p in progress.valueOrNull ?? <ChallengeProgress>[])
              p.challengeId: p,
          };
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final c = list[i];
              return _ChallengeCard(
                challenge: c,
                progress: progressMap[c.id],
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Challenge Card — preserved from the original
// ---------------------------------------------------------------------------

class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard({required this.challenge, this.progress});
  final Challenge challenge;
  final ChallengeProgress? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joined = progress != null;
    final pct = joined
        ? (progress!.daysCompleted / challenge.durationDays).clamp(0.0, 1.0)
        : 0.0;
    final completed = progress?.completedAt != null;

    return AppCard(
      padding: const EdgeInsets.all(20),
      gradient: challenge.isDefault
          ? const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: challenge.isDefault ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  completed ? Icons.emoji_events : Icons.flag_circle,
                  color: challenge.isDefault ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: challenge.isDefault
                            ? Colors.white
                            : AppColors.textPrimaryDark,
                      ),
                    ),
                    Text(
                      '${challenge.durationDays} days · score ≥ ${challenge.minScore}',
                      style: TextStyle(
                        fontSize: 12,
                        color: challenge.isDefault
                            ? Colors.white70
                            : AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            challenge.description,
            style: TextStyle(
              color: challenge.isDefault ? Colors.white : AppColors.textSecondaryDark,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (joined) ...[
            Row(
              children: [
                Text(
                  '${progress!.daysCompleted}/${challenge.durationDays} days',
                  style: TextStyle(
                    color: challenge.isDefault ? Colors.white : AppColors.textPrimaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (completed)
                  const Text('Completed 🎉',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ))
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  challenge.isDefault ? Colors.white : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Refresh progress',
                    icon: Icons.refresh,
                    onPressed: () async {
                      await ref
                          .read(challengesRepositoryProvider)
                          .recompute(challenge: challenge);
                      ref.invalidate(myChallengeProgressProvider);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.exit_to_app, color: AppColors.danger),
                  onPressed: () async {
                    await ref
                        .read(challengesRepositoryProvider)
                        .leave(challenge.id);
                    ref.invalidate(myChallengeProgressProvider);
                  },
                ),
              ],
            ),
          ] else
            PrimaryButton(
              label: 'Join challenge',
              onPressed: () async {
                await ref
                    .read(challengesRepositoryProvider)
                    .join(challenge.id);
                ref.invalidate(myChallengeProgressProvider);
              },
            ),
        ],
      ),
    );
  }
}
