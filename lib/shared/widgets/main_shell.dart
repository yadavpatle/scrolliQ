import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Bottom-nav shell that hosts dashboard, leaderboard, challenges, profile.
///
/// Uses a floating, blurred pill at the bottom rather than the default
/// Material 3 NavigationBar — gives the app a distinctive premium feel.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  static const _tabs = <_Tab>[
    _Tab('/home',        Icons.home_rounded,        'Home'),
    _Tab('/leaderboard', Icons.bar_chart_rounded,   'Ranks'),
    _Tab('/challenges',  Icons.flag_rounded,        'Goals'),
    _Tab('/profile',     Icons.person_rounded,      'You'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    // /friends is a shell route that's reached via push from /profile —
    // keep Profile highlighted while the user is browsing friends.
    if (loc.startsWith('/friends')) {
      final profileIdx = _tabs.indexWhere((t) => t.path == '/profile');
      if (profileIdx >= 0) return profileIdx;
    }
    final i = _tabs.indexWhere((t) => loc.startsWith(t.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark2.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: AppColors.borderDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: _NavButton(
                          tab: _tabs[i],
                          selected: i == idx,
                          onTap: () => context.go(_tabs[i].path),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm + 12),
            border: selected
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
                : null,
          ),
          // FittedBox guarantees the icon+label combo never overflows the
          // narrow per-tab slot on small phones (≤ 380dp). When there's
          // plenty of room it renders at full size.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  tab.icon,
                  size: 20,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondaryDark,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            tab.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.path, this.icon, this.label);
  final String path;
  final IconData icon;
  final String label;
}
