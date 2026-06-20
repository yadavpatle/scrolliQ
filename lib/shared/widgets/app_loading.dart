import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_colors.dart';
import 'mascot.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Mascot(mood: MascotMood.thinking, size: 96),
          const SizedBox(height: 8),
          Text(
            message ?? 'Thinking…',
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class AppShimmer extends StatelessWidget {
  const AppShimmer({super.key, this.height = 80});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceDark2,
      highlightColor: AppColors.surfaceDark,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceDark2,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
