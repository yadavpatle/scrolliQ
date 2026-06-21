import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/providers.dart';
import '../../../usage_tracking/providers.dart';
import '../../providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user  = ref.watch(currentUserProvider);
    final stats = ref.watch(myStatsProvider);
    final perm  = ref.watch(usagePermissionProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceDark2,
          onRefresh: () async {
            ref.invalidate(myStatsProvider);
            ref.invalidate(currentUserProvider);
            ref.invalidate(usagePermissionProvider);
            await ref.read(myStatsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              const SectionHeader(eyebrow: 'Account', title: 'Profile'),
              const SizedBox(height: 16),
              user.when(
                loading: () => const AppShimmer(height: 120),
                error: (e, _) => AppError(message: e.toString()),
                data: (u) {
                  if (u == null) return const SizedBox.shrink();
                  return AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.brandGradient,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceDark,
                              shape: BoxShape.circle,
                            ),
                            child: UserAvatar(
                              url: u.avatarUrl,
                              name: u.name,
                              radius: 30,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.name.isEmpty ? 'ScrollIQ user' : u.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                u.email,
                                style: const TextStyle(
                                  color: AppColors.textSecondaryDark,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              const SectionHeader(eyebrow: 'Snapshot', title: 'Your stats'),
              const SizedBox(height: 12),
              stats.when(
                loading: () => const AppShimmer(height: 130),
                error:   (e, _) => AppError(message: e.toString()),
                data: (s) {
                  if (s == null) return const SizedBox.shrink();
                  return Row(
                    children: [
                      Expanded(child: _StatCard(
                        label: 'Today',
                        value: '${s.currentScore}',
                        color: AppColors.primary,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(
                        label: '7-day avg',
                        value: '${s.weeklyAvgScore}',
                        color: AppColors.scoreHealthy,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(
                        label: 'Focus days',
                        value: '${s.focusDays}',
                        color: AppColors.accent,
                      )),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              const SectionHeader(eyebrow: 'Manage', title: 'Settings'),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.people_outline_rounded,
                      label: 'Friends',
                      onTap: () => context.push('/friends'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _MenuTile(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notifications',
                      trailing: const Text('Enabled',
                          style: TextStyle(color: AppColors.textSecondaryDark)),
                      onTap: () {},
                    ),
                    perm.maybeWhen(
                      data: (granted) => Column(
                        children: [
                          const Divider(height: 1, indent: 56),
                          _MenuTile(
                            icon: Icons.shield_outlined,
                            label: 'Permissions',
                            trailing: Text(
                              granted ? 'Granted' : 'Review',
                              style: TextStyle(
                                color: granted
                                    ? AppColors.success
                                    : AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () async {
                              await context.push('/permissions');
                              ref.invalidate(usagePermissionProvider);
                            },
                          ),
                        ],
                      ),
                      orElse: () => Column(
                        children: [
                          const Divider(height: 1, indent: 56),
                          _MenuTile(
                            icon: Icons.shield_outlined,
                            label: 'Permissions',
                            onTap: () async {
                              await context.push('/permissions');
                              ref.invalidate(usagePermissionProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: AppText.statSmall(color: AppColors.textPrimaryDark)
                .copyWith(fontSize: 22),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String   label;
  final Widget?  trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      title: Text(label),
      trailing: trailing ??
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiaryDark),
      onTap: onTap,
    );
  }
}
