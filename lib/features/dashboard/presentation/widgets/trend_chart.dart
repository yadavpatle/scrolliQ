import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../usage_tracking/domain/entities/daily_usage.dart';

class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.history});
  final List<DailyUsage> history;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].brainScore.toDouble()));
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: SizedBox(
        height: 200,
        child: history.isEmpty
            ? const Center(
                child: Text('No data yet',
                    style: TextStyle(color: AppColors.textSecondaryDark)),
              )
            : LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.borderDark,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 25,
                        getTitlesWidget: (value, _) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: AppColors.textTertiaryDark,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i < 0 || i >= history.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat.E()
                                  .format(history[i].date)
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.textTertiaryDark,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.4,
                      barWidth: 3,
                      gradient: const LinearGradient(
                        colors: [AppColors.scoreHealthy, AppColors.primary],
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, ___) =>
                            FlDotCirclePainter(
                          radius: 3.5,
                          color: AppColors.primary,
                          strokeColor: AppColors.bgDark,
                          strokeWidth: 2,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.22),
                            AppColors.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
