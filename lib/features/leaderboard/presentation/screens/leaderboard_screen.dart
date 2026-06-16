import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/stat_pill.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/providers.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(leaderboardProvider);
    final me      = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceDark2,
          onRefresh: () async {
            ref.invalidate(leaderboardProvider);
            await ref.read(leaderboardProvider.future);
          },
          child: entries.when(
            loading: () => ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
              itemCount: 8,
              itemBuilder: (_, __) => const AppShimmer(height: 64),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
            ),
            error: (e, _) => AppError(message: e.toString()),
            data: (list) {
              if (list.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
                  children: const [
                    SectionHeader(
                      eyebrow: 'Today',
                      title: 'Leaderboard',
                    ),
                    SizedBox(height: 24),
                    _Empty(),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                itemCount: list.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: SectionHeader(
                        eyebrow: 'Today',
                        title: 'Leaderboard',
                      ),
                    );
                  }
                  final e = list[i - 1];
                  final isMe = me?.id == e.userId;
                  return _LeaderboardRow(entry: e, highlight: isMe);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Center(
        child: Text(
          'No data yet — be the first to log usage today.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, this.highlight = false});
  final LeaderboardEntry entry;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final medalColor = switch (entry.rank) {
      1 => AppColors.accent,
      2 => const Color(0xFFC9CCD2),
      3 => const Color(0xFFE08A4A),
      _ => null,
    };

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor:
          highlight ? AppColors.primary.withValues(alpha: 0.5) : null,
      color: highlight
          ? AppColors.primary.withValues(alpha: 0.08)
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: medalColor != null
                ? Icon(Icons.emoji_events_rounded, color: medalColor, size: 22)
                : Text(
                    '#${entry.rank}',
                    style: AppText.mono(
                      size: 13,
                      color: AppColors.textTertiaryDark,
                      weight: FontWeight.w700,
                    ),
                  ),
          ),
          UserAvatar(url: entry.avatarUrl, name: entry.name, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name + (highlight ? ' · you' : ''),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: highlight
                        ? AppColors.primary
                        : AppColors.textPrimaryDark,
                  ),
                ),
                if (entry.totalScreenTime > 0)
                  Text(
                    Formatters.minutes(entry.totalScreenTime),
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          StatPill(
            label: '${entry.brainScore}',
            color: AppColors.primary,
            filled: highlight,
          ),
        ],
      ),
    );
  }
}
