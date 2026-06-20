import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'mascot.dart';

class AppError extends StatelessWidget {
  const AppError({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(mood: MascotMood.dead, size: 88),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 14,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
