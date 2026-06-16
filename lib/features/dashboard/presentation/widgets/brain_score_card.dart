import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/stat_pill.dart';
import '../../../usage_tracking/domain/entities/daily_usage.dart';
import '../../domain/brain_score_calculator.dart';

/// Hero card showing the current Brain Score.
///
/// Layout:
///   - Eyebrow + category pill (top)
///   - Big monospaced number with /100 suffix on the left
///   - Custom radial gauge on the right
class BrainScoreCard extends StatelessWidget {
  const BrainScoreCard({super.key, required this.usage});
  final DailyUsage usage;

  @override
  Widget build(BuildContext context) {
    final cat = BrainScoreCalculator.categorize(usage.brainScore);
    final accent = _colorForCategory(cat);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      radius: AppTheme.radiusXl,
      shadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.18),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('BRAIN SCORE', style: AppText.eyebrow()),
              ),
              const SizedBox(width: 8),
              StatPill(
                label: cat.label,
                color: accent,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FittedBox keeps the giant 72pt score readable for 1–2
                    // digit values but scales down gracefully when it's 100,
                    // preventing a horizontal overflow next to the gauge.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${usage.brainScore}',
                            style: AppText.statHero(color: accent),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 14, left: 4),
                            child: Text(
                              '/100',
                              style: AppText.mono(
                                size: 16,
                                color: AppColors.textSecondaryDark,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitleForCategory(cat),
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                height: 110,
                child: _ScoreGauge(
                  value: usage.brainScore / 100,
                  color: accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorForCategory(BrainCategory c) => switch (c) {
        BrainCategory.focusMaster  => AppColors.scoreFocusMaster,
        BrainCategory.healthy      => AppColors.scoreHealthy,
        BrainCategory.distracted   => AppColors.scoreDistracted,
        BrainCategory.doomscroller => AppColors.scoreDoomscroller,
        BrainCategory.brainMelt    => AppColors.scoreBrainMelt,
      };

  String _subtitleForCategory(BrainCategory c) => switch (c) {
        BrainCategory.focusMaster  => 'Sharp and intentional. Keep flowing.',
        BrainCategory.healthy      => 'Solid focus. A little drift is fine.',
        BrainCategory.distracted   => 'Pulled in too many directions.',
        BrainCategory.doomscroller => 'The algorithm is winning today.',
        BrainCategory.brainMelt    => 'Hit pause. Reset before bed.',
      };
}

/// Radial gauge: 270° arc with track + animated value stroke.
class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.value, required this.color});

  /// Score value 0..1.
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => CustomPaint(
        painter: _GaugePainter(value: v, color: color),
        child: Center(
          child: Icon(Icons.bolt_rounded, color: color, size: 28),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    // 270° arc starting at 135° (lower-left) going clockwise to 405° (lower-right).
    const startAngle = math.pi * 0.75; // 135°
    const sweepAngle = math.pi * 1.5;  // 270°

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.surfaceDark3;

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          color.withValues(alpha: 0.6),
          color,
        ],
        transform: const GradientRotation(startAngle - math.pi / 2),
      ).createShader(rect);

    canvas.drawArc(rect, startAngle, sweepAngle, false, track);
    canvas.drawArc(rect, startAngle, sweepAngle * value, false, progress);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.color != color;
}
