import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../usage_tracking/domain/entities/daily_usage.dart';

/// Grid of small cards showing per-app screen time.
class UsageBreakdown extends StatelessWidget {
  const UsageBreakdown({super.key, required this.usage});
  final DailyUsage usage;

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item('Total',     usage.totalMinutes,     Icons.smartphone_rounded, AppColors.primary),
      _Item('Instagram', usage.instagramMinutes, Icons.camera_alt_rounded, const Color(0xFFFF4D8B)),
      _Item('YouTube',   usage.youtubeMinutes,   Icons.play_arrow_rounded, const Color(0xFFFF5252)),
      _Item('TikTok',    usage.tiktokMinutes,    Icons.music_note_rounded, const Color(0xFF7DE0BD)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      physics: const NeverScrollableScrollPhysics(),
      children: items
          .map((i) => AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: i.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(i.icon, color: i.color, size: 18),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.label.toUpperCase(),
                          style: AppText.eyebrow(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.minutes(i.minutes),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.textPrimaryDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _Item {
  const _Item(this.label, this.minutes, this.icon, this.color);
  final String   label;
  final int      minutes;
  final IconData icon;
  final Color    color;
}
