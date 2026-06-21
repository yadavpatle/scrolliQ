import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../reel_counter/providers.dart';
import '../../../usage_tracking/providers.dart';
import '../../data/onboarding_content.dart';
import '../../domain/onboarding_data.dart';

/// Shows 4 permissions, each with "Allow" button or checkmark.
/// Bottom CTA "Why should I give this permission?" expandable.
///
/// Two modes:
///   * **Onboarding mode** — pass [onComplete]; screen renders without an
///     AppBar and shows a bottom "Continue" button that fires the callback.
///     Onboarding requires this step, so it always provides a non-null
///     callback here.
///   * **Standalone / settings mode** — leave [onComplete] null; screen
///     renders with an AppBar (back arrow) so it can be pushed from the
///     Profile screen any time the user wants to review or change permissions.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key, this.onComplete});

  /// If null, the screen renders in standalone mode (AppBar + no Continue CTA).
  final VoidCallback? onComplete;

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with WidgetsBindingObserver {
  final _granted = <PermissionKey, bool>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAll();
  }

  Future<void> _refreshAll() async {
    final svc = ref.read(reelCounterServiceProvider);
    final usageSvc = ref.read(usageTrackingServiceProvider);
    final results = await Future.wait([
      svc.isAccessibilityEnabled(),
      svc.canDrawOverlays(),
      svc.isBatteryOptimizationIgnored(),
      usageSvc.hasPermission(),
    ]);
    if (!mounted) return;
    setState(() {
      _granted[PermissionKey.accessibility] = results[0];
      _granted[PermissionKey.overlay] = results[1];
      _granted[PermissionKey.battery] = results[2];
      _granted[PermissionKey.usageStats] = results[3];
    });
  }

  Future<void> _request(PermissionKey key) async {
    final svc = ref.read(reelCounterServiceProvider);
    final usageSvc = ref.read(usageTrackingServiceProvider);
    switch (key) {
      case PermissionKey.accessibility:
        await svc.openAccessibilitySettings();
      case PermissionKey.overlay:
        await svc.openOverlaySettings();
      case PermissionKey.battery:
        await svc.openBatterySettings();
      case PermissionKey.usageStats:
        await usageSvc.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final standalone = widget.onComplete == null;
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: standalone
          ? AppBar(
              backgroundColor: AppColors.bgDark,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'Permissions',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: SafeArea(
        top: !standalone,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: standalone ? 8 : 32),
              if (standalone) ...[
                const Text(
                  'Manage app permissions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Toggle these any time. ScrollIQ needs them to count reels and track screen time.',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ] else
                const Text(
                  'Enable permissions to\nstart counting reels',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              const SizedBox(height: 32),
              ...kPermissions.map((p) => _PermRow(
                    item: p,
                    granted: _granted[p.key] ?? false,
                    onAllow: () => _request(p.key),
                  )),
              const Spacer(),
              _WhyBanner(),
              const SizedBox(height: 16),
              if (!standalone)
                PrimaryButton(
                  label: 'Continue',
                  onPressed: widget.onComplete!,
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow({required this.item, required this.granted, required this.onAllow});
  final PermissionItem item;
  final bool granted;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(item.subtitle,
                    style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13)),
              ],
            ),
          ),
          if (granted)
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark2,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: AppColors.success, size: 20),
            )
          else
            TextButton(
              onPressed: onAllow,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Allow', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

class _WhyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified, color: AppColors.primary, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Why should I give this permission?',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textSecondaryDark, size: 20),
        ],
      ),
    );
  }
}
