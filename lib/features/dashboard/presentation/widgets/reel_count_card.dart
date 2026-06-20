import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/stat_pill.dart';
import '../../../reel_counter/domain/entities/reel_count.dart';
import '../../../reel_counter/providers.dart';

/// Shows today's reel count live + per-platform breakdown + overlay toggle.
class ReelCountCard extends ConsumerWidget {
  const ReelCountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(reelCountStreamProvider);
    final accessOn = ref.watch(reelCounterAccessibilityEnabledProvider);
    final overlayState = ref.watch(overlayControllerProvider);

    // Guarantee the card is always visible so users have a single place to see
    // whether reel counting is working. Falls back to ReelCountSnapshot.empty
    // while loading/erroring so the UI never collapses.
    final snap = stream.maybeWhen(
      data: (s) => s,
      orElse: () => ReelCountSnapshot.empty,
    );
    final accessibilityEnabled = accessOn.valueOrNull ?? false;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REELS TODAY',
                      style: AppText.eyebrow(color: AppColors.secondary),
                    ),
                    const SizedBox(height: 6),
                    // FittedBox so very high reel counts don't overflow into
                    // the overlay toggle on the right.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${snap.total}',
                            style: AppText.statLarge(),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4, left: 6),
                            child: Text(
                              'consumed',
                              style: TextStyle(
                                color: AppColors.textSecondaryDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    overlayState.running ? 'OVERLAY ON' : 'OVERLAY OFF',
                    style: AppText.eyebrow(
                      color: overlayState.running
                          ? AppColors.primary
                          : AppColors.textTertiaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Switch.adaptive(
                    value: overlayState.running,
                    activeTrackColor: AppColors.primary,
                    onChanged: (_) => ref
                        .read(overlayControllerProvider.notifier)
                        .toggle(),
                  ),
                ],
              ),
            ],
          ),
          if (snap.total > 0) ...[
            const SizedBox(height: 14),
            _PlatformRow(snap: snap),
          ] else if (!accessibilityEnabled) ...[
            const SizedBox(height: 12),
            const Text(
              'Enable Accessibility above to start counting.',
              style: TextStyle(
                color: AppColors.textTertiaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              'No reels yet today. Open Instagram, YouTube Shorts, or Facebook Reels to start.',
              style: TextStyle(
                color: AppColors.textTertiaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlatformRow extends StatelessWidget {
  const _PlatformRow({required this.snap});
  final ReelCountSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final entries = snap.byPlatform.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((e) {
        return StatPill(
          label: '${_icon(e.key)}  ${e.value}',
          color: AppColors.textPrimaryDark,
          dense: true,
        );
      }).toList(),
    );
  }

  String _icon(ReelPlatform p) => switch (p) {
        ReelPlatform.instagram => '📷',
        ReelPlatform.youtubeShorts => '▶️',
        ReelPlatform.facebookReels => '📘',
      };
}
