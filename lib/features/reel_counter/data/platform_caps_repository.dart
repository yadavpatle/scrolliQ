import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/reel_count.dart';

/// User-configurable per-platform daily reel limit.
class PlatformCap extends Equatable {
  const PlatformCap({required this.platform, required this.limit, this.enabled = true});
  final ReelPlatform platform;

  /// Max reels allowed per day on this platform. 0 = unlimited.
  final int limit;

  /// Whether the cap is active.
  final bool enabled;

  PlatformCap copyWith({int? limit, bool? enabled}) => PlatformCap(
        platform: platform,
        limit: limit ?? this.limit,
        enabled: enabled ?? this.enabled,
      );

  @override
  List<Object?> get props => [platform, limit, enabled];
}

/// Persists per-platform caps in SharedPreferences.
class PlatformCapsRepository {
  static const _prefix = 'reel_cap_';

  Future<List<PlatformCap>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return ReelPlatform.values.map((p) {
      final limit = prefs.getInt('$_prefix${p.name}_limit') ?? _defaultLimit(p);
      final enabled = prefs.getBool('$_prefix${p.name}_enabled') ?? true;
      return PlatformCap(platform: p, limit: limit, enabled: enabled);
    }).toList();
  }

  Future<void> save(PlatformCap cap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix${cap.platform.name}_limit', cap.limit);
    await prefs.setBool('$_prefix${cap.platform.name}_enabled', cap.enabled);
  }

  /// Check if any cap is exceeded for given snapshot.
  Future<List<ReelPlatform>> checkExceeded(ReelCountSnapshot snap) async {
    final caps = await loadAll();
    final byPlatform = snap.byPlatform;
    final exceeded = <ReelPlatform>[];
    for (final cap in caps) {
      if (!cap.enabled || cap.limit <= 0) continue;
      final count = byPlatform[cap.platform] ?? 0;
      if (count >= cap.limit) exceeded.add(cap.platform);
    }
    return exceeded;
  }

  static int _defaultLimit(ReelPlatform p) => switch (p) {
        ReelPlatform.instagram => 50,
        ReelPlatform.youtubeShorts => 50,
        ReelPlatform.tiktok => 50,
        ReelPlatform.snapchatSpotlight => 30,
        ReelPlatform.facebookReels => 30,
      };
}
