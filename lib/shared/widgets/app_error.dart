import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import 'mascot.dart';

class AppError extends StatelessWidget {
  const AppError({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  /// Convenience constructor that converts any thrown object into a
  /// user-friendly string automatically.
  AppError.friendly(
    Object error, {
    super.key,
    this.onRetry,
    this.icon = Icons.error_outline,
  })  : message = friendlyMessage(error);

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  /// Translates raw exceptions into short, human-readable messages.
  static String friendlyMessage(Object error) {
    // Network-level failures (no internet, DNS, timeout).
    if (error is SocketException) {
      return 'No internet connection. Pull down to refresh.';
    }
    if (error is AuthRetryableFetchException) {
      return 'No internet connection. Pull down to refresh.';
    }
    // The string check catches wrapped ClientException / SocketException
    // messages that aren't typed directly.
    final str = error.toString();
    if (str.contains('SocketException') ||
        str.contains('Failed host lookup') ||
        str.contains('ClientException') ||
        str.contains('Connection refused') ||
        str.contains('Connection timed out') ||
        str.contains('Network is unreachable')) {
      return 'No internet connection. Pull down to refresh.';
    }
    // Auth failures from Supabase SDK.
    if (error is AuthException) {
      return 'Session expired. Please sign in again.';
    }
    // App-specific Failure subtypes already have clean messages.
    if (error is Failure) {
      return error.message;
    }
    return 'Something went wrong. Pull down to refresh.';
  }

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

