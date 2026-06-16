import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../reel_counter/domain/entities/reel_count.dart';
import '../../../reel_counter/providers.dart';

/// Predicts next week's reels using linear regression on the last 7 days.
class ForecastCard extends ConsumerWidget {
  const ForecastCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(reelCountHistoryProvider(7));
    return history.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (days) {
        if (days.length < 3) return const SizedBox.shrink();
        final forecast = _forecast(days);
        final thisWeek = days.fold<int>(0, (sum, d) => sum + d.total);
        final improving = forecast < thisWeek;
        final accent = improving ? AppColors.primary : AppColors.secondary;

        return AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      improving
                          ? Icons.trending_down_rounded
                          : Icons.trending_up_rounded,
                      color: accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'NEXT 7 DAYS · FORECAST',
                    style: AppText.eyebrow(color: AppColors.textSecondaryDark),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '~$forecast',
                    style: AppText.statLarge(color: accent),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6, left: 8),
                    child: Text(
                      'reels',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                improving
                    ? 'Trending down — keep it up.'
                    : 'Try setting a daily cap to break the trend.',
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _forecast(List<ReelCountDay> days) {
    final n = days.length;
    final ys = days.map((d) => d.total.toDouble()).toList();
    final xMean = (n - 1) / 2.0;
    final yMean = ys.reduce((a, b) => a + b) / n;

    double num = 0, den = 0;
    for (int i = 0; i < n; i++) {
      final dx = i - xMean;
      num += dx * (ys[i] - yMean);
      den += dx * dx;
    }
    final b = den == 0 ? 0.0 : num / den;
    final a = yMean - b * xMean;

    double sum = 0;
    for (int i = n; i < n + 7; i++) {
      final predicted = (a + b * i).clamp(0.0, 999.0);
      sum += predicted;
    }
    return sum.round();
  }
}
