import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.url, this.name, this.radius = 20});
  final String? url;
  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceDark2,
        backgroundImage: CachedNetworkImageProvider(url!),
      );
    }
    final trimmed = (name ?? '').trim();
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((e) => e[0]).join().toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
