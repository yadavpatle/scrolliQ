import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Premium card used across the app.
///
/// Defaults to a hairline-bordered surface card. Pass [gradient] for a
/// "hero" treatment, or [outlined: false] / [filled: ...] for variants.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gradient,
    this.color,
    this.borderColor,
    this.radius = AppTheme.radiusLg,
    this.onTap,
    this.outlined = true,
    this.shadow,
  });

  /// Card child.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Optional gradient. When non-null, [color] is ignored and the gradient
  /// is rendered with no border (for hero cards).
  final Gradient? gradient;

  /// Override the default surface color.
  final Color? color;

  /// Override the default hairline border color.
  final Color? borderColor;

  /// Corner radius — defaults to [AppTheme.radiusLg].
  final double radius;

  /// Tap handler — when non-null, an InkWell is layered on top.
  final VoidCallback? onTap;

  /// Whether to draw the hairline border (ignored when [gradient] is non-null).
  final bool outlined;

  /// Optional drop shadow.
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final hasGradient = gradient != null;

    final decoration = BoxDecoration(
      color: hasGradient ? null : (color ?? AppColors.surfaceDark),
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: !hasGradient && outlined
          ? Border.all(color: borderColor ?? AppColors.borderDark)
          : null,
      boxShadow: shadow,
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: AppColors.primary.withValues(alpha: 0.06),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: content,
        ),
      ),
    );
  }
}

/// Wraps a child with a 1-px gradient stroke. Useful for "premium" CTAs and
/// hero stats (e.g. the brain-score gauge container).
class GradientBorder extends StatelessWidget {
  const GradientBorder({
    super.key,
    required this.child,
    this.gradient = AppColors.cardBorderGradient,
    this.radius = AppTheme.radiusXl,
    this.strokeWidth = 1,
    this.color = AppColors.surfaceDark,
  });

  final Widget child;
  final Gradient gradient;
  final double radius;
  final double strokeWidth;

  /// Inner background color (the "fill" inside the gradient stroke).
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: EdgeInsets.all(strokeWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                BorderRadius.circular((radius - strokeWidth).clamp(0, radius)),
          ),
          child: child,
        ),
      ),
    );
  }
}
