import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/mascot.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/stat_pill.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/providers.dart';
import '../../../leaderboard/providers.dart';
import '../../../reel_counter/providers.dart';
import '../../../usage_tracking/providers.dart';
import '../widgets/brain_score_card.dart';
import '../widgets/forecast_card.dart';
import '../widgets/reel_count_card.dart';
import '../widgets/trend_chart.dart';
import '../widgets/usage_breakdown.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Instantiate the overlay controller on first load so the HUD auto-starts
    // (default-on) when overlay permission is already granted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(overlayControllerProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user returns to ScrollIQ from another app (e.g. after scrolling
    // YouTube Shorts), the cached FutureProviders are stale. Invalidate so the
    // dashboard refreshes brain score, reel history, leaderboard, and re-checks
    // permissions. The reelCountStreamProvider is a live stream, no refresh
    // needed.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(todayUsageProvider);
      ref.invalidate(recentUsageProvider);
      ref.invalidate(leaderboardPreviewProvider);
      ref.invalidate(usagePermissionProvider);
      ref.invalidate(reelCounterAccessibilityEnabledProvider);
      ref.invalidate(reelCountHistoryProvider(7));
      ref.read(overlayControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(currentUserProvider);
    final usage     = ref.watch(todayUsageProvider);
    final history   = ref.watch(recentUsageProvider);
    final preview   = ref.watch(leaderboardPreviewProvider);
    final hasPerm   = ref.watch(usagePermissionProvider);
    final accessOn  = ref.watch(reelCounterAccessibilityEnabledProvider);

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceDark2,
        onRefresh: () async {
          ref.invalidate(todayUsageProvider);
          ref.invalidate(recentUsageProvider);
          ref.invalidate(leaderboardPreviewProvider);
          ref.invalidate(usagePermissionProvider);
          ref.invalidate(reelCounterAccessibilityEnabledProvider);
          ref.invalidate(reelCountHistoryProvider(7));
          await ref.read(todayUsageProvider.future);
        },
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              _Greeting(user: user.valueOrNull),
              const SizedBox(height: 22),
              // Usage-stats permission banner
              hasPerm.maybeWhen(
                data: (granted) => granted
                    ? const SizedBox.shrink()
                    : const _PermissionBanner(),
                orElse: () => const SizedBox.shrink(),
              ),
              if (!(hasPerm.valueOrNull ?? false)) const SizedBox(height: 12),
              // Accessibility-service permission banner (required for reel counts)
              accessOn.maybeWhen(
                data: (enabled) => enabled
                    ? const SizedBox.shrink()
                    : const _AccessibilityBanner(),
                orElse: () => const SizedBox.shrink(),
              ),
              if (!(accessOn.valueOrNull ?? false)) const SizedBox(height: 16),
              usage.when(
                loading:  () => const AppShimmer(height: 220),
                error:    (e, _) => AppError(message: e.toString()),
                data:     (u) => BrainScoreCard(usage: u),
              ),
              const SizedBox(height: 16),
              const ReelCountCard(),
              const SizedBox(height: 22),
              const SectionHeader(
                eyebrow: 'Today',
                title: 'Where it goes',
              ),
              const SizedBox(height: 12),
              usage.when(
                loading:  () => const AppShimmer(height: 200),
                error:    (e, _) => const SizedBox.shrink(),
                data:     (u) => UsageBreakdown(usage: u),
              ),
              const SizedBox(height: 22),
              const SectionHeader(
                eyebrow: 'Last 7 days',
                title: 'Brain Score trend',
              ),
              const SizedBox(height: 12),
              history.when(
                loading:  () => const AppShimmer(height: 220),
                error:    (e, _) => const SizedBox.shrink(),
                data:     (h) => TrendChart(history: h),
              ),
              const SizedBox(height: 16),
              const ForecastCard(),
              const SizedBox(height: 22),
              SectionHeader(
                eyebrow: 'Live',
                title: "Today's leaderboard",
                trailing: 'See all',
                onTrailingTap: () => context.go('/leaderboard'),
              ),
              const SizedBox(height: 12),
              preview.when(
                loading: () => const AppShimmer(height: 180),
                error:   (e, _) => AppError(message: e.toString()),
                data:    (entries) => _PreviewList(entries: entries),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final name = user == null ? 'there' : Formatters.firstName(user.name);
    final dateLabel = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel.toUpperCase(),
                style: AppText.eyebrow(color: AppColors.textTertiaryDark),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimaryDark,
                  ),
                  children: [
                    TextSpan(text: '${Formatters.greeting()},\n'),
                    TextSpan(
                      text: '$name.',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderDark),
          ),
          child: UserAvatar(
            url: user?.avatarUrl,
            name: user?.name,
            radius: 22,
          ),
        ),
      ],
    );
  }
}

class _PermissionBanner extends ConsumerWidget {
  const _PermissionBanner();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.warning.withValues(alpha: 0.3),
      color: AppColors.warning.withValues(alpha: 0.06),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Grant Usage Access to start tracking your screen time.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () async {
              await ref.read(usageTrackingServiceProvider).requestPermission();
              ref.invalidate(usagePermissionProvider);
              ref.invalidate(todayUsageProvider);
            },
            child: const Text('Grant'),
          ),
        ],
      ),
    );
  }
}

/// Banner shown when the AccessibilityService isn't enabled. Without it
/// ScrollIQ cannot count reels/shorts at all.
class _AccessibilityBanner extends ConsumerWidget {
  const _AccessibilityBanner();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.danger.withValues(alpha: 0.35),
      color: AppColors.danger.withValues(alpha: 0.06),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.accessibility_new_rounded,
                color: AppColors.danger, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Enable Accessibility for ScrollIQ to count reels & shorts.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () async {
              await ref
                  .read(reelCounterServiceProvider)
                  .openAccessibilitySettings();
              // Defer invalidation until the user comes back; the lifecycle
              // observer in DashboardScreen handles it.
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}

class _PreviewList extends StatelessWidget {
  const _PreviewList({required this.entries});
  final List entries;
  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const AppCard(
        padding: EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            Mascot(mood: MascotMood.sleepy, size: 84),
            SizedBox(height: 12),
            Text(
              'No leaderboard data yet today.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
            SizedBox(height: 4),
            Text(
              'Be the first to set a Brain Score.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textTertiaryDark,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#${entries[i].rank}',
                      style: AppText.mono(
                        size: 13,
                        color: AppColors.textTertiaryDark,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  UserAvatar(
                      url: entries[i].avatarUrl,
                      name: entries[i].name,
                      radius: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entries[i].name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  StatPill(
                    label: '${entries[i].brainScore}',
                    color: AppColors.primary,
                    dense: true,
                  ),
                ],
              ),
            ),
            if (i < entries.length - 1)
              const Divider(height: 1, indent: 14, endIndent: 14),
          ],
        ],
      ),
    );
  }
}
