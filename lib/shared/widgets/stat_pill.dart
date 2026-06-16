import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Compact rounded pill — used for status tags, category badges, friend
/// counts, leaderboard rank chips, etc.
///
/// The pill auto-themes its background to a soft tint of [color] when
/// [filled] is false (default) and uses a solid fill when true.
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.primary,
    this.filled = false,
    this.dense = false,
    this.textColor,
  });

  final String label;
  final IconData? icon;
  final Color color;

  /// When true the pill is filled with [color]; otherwise it gets a soft
  /// translucent tint background and uses [color] for foreground.
  final bool filled;

  /// Smaller padding / font when true.
  final bool dense;

  /// Override the foreground color (rarely needed).
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final fg = textColor ??
        (filled
            ? (color.computeLuminance() > 0.6
                ? AppColors.onPrimary
                : Colors.white)
            : color);
    final bg =
        filled ? color : color.withValues(alpha: 0.14);

    final hPad = dense ? 8.0 : 10.0;
    final vPad = dense ? 4.0 : 6.0;
    final fontSize = dense ? 11.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: fg, size: dense ? 12 : 13),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
