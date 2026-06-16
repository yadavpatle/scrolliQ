import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Section title used between content blocks on the dashboard / profile.
///
/// Layout: small uppercase eyebrow on top, then the section title, with an
/// optional trailing tap target ("See all", "Manage", etc.).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
    this.onTrailingTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
  });

  final String title;
  final String? eyebrow;

  /// Trailing action label. If provided, it becomes a tappable text button
  /// styled in the primary accent.
  final String? trailing;
  final VoidCallback? onTrailingTap;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: AppText.eyebrow(),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trailing!,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
