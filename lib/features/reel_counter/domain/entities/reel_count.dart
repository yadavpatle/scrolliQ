import 'package:equatable/equatable.dart';

/// Snapshot of today's reel counts emitted by the native AccessibilityService.
class ReelCountSnapshot extends Equatable {
  const ReelCountSnapshot({
    required this.date,
    required this.total,
    required this.perApp,
    required this.timestamp,
  });

  /// `yyyy-MM-dd` in the device's local timezone.
  final String date;

  /// Sum of [perApp] values; cached on the native side.
  final int total;

  /// Reel count per package, e.g. `{"com.instagram.android": 12, ...}`.
  final Map<String, int> perApp;

  /// Wall-clock millis-since-epoch when the snapshot was generated.
  final DateTime timestamp;

  /// Friendly per-platform aggregation. Combines TikTok variants and FB +
  /// FB Lite into a single bucket so the dashboard does not have to.
  Map<ReelPlatform, int> get byPlatform {
    final int instagram = perApp['com.instagram.android'] ?? 0;
    final int youtube = perApp['com.google.android.youtube'] ?? 0;
    final int tiktok = (perApp['com.zhiliaoapp.musically'] ?? 0) +
        (perApp['com.ss.android.ugc.trill'] ?? 0);
    final int snapchat = perApp['com.snapchat.android'] ?? 0;
    final int facebook =
        (perApp['com.facebook.katana'] ?? 0) + (perApp['com.facebook.lite'] ?? 0);
    return {
      ReelPlatform.instagram: instagram,
      ReelPlatform.youtubeShorts: youtube,
      ReelPlatform.tiktok: tiktok,
      ReelPlatform.snapchatSpotlight: snapchat,
      ReelPlatform.facebookReels: facebook,
    };
  }

  factory ReelCountSnapshot.fromMap(Map<dynamic, dynamic> raw) {
    final perApp = <String, int>{};
    final p = raw['perApp'];
    if (p is Map) {
      p.forEach((k, v) {
        perApp[k.toString()] = (v as num).toInt();
      });
    }
    return ReelCountSnapshot(
      date: raw['date']?.toString() ?? '',
      total: (raw['total'] as num?)?.toInt() ?? 0,
      perApp: perApp,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (raw['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Zero-state value for first launch. Not a const because [DateTime] is
  /// not const-constructible.
  static final ReelCountSnapshot empty = ReelCountSnapshot(
    date: '',
    total: 0,
    perApp: const <String, int>{},
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  );

  @override
  List<Object?> get props => [date, total, perApp, timestamp];
}

/// Single day of history returned from `getHistory`.
class ReelCountDay extends Equatable {
  const ReelCountDay({
    required this.date,
    required this.total,
    required this.perApp,
  });

  final String date;
  final int total;
  final Map<String, int> perApp;

  factory ReelCountDay.fromMap(Map<dynamic, dynamic> raw) {
    final perApp = <String, int>{};
    final p = raw['perApp'];
    if (p is Map) {
      p.forEach((k, v) {
        perApp[k.toString()] = (v as num).toInt();
      });
    }
    return ReelCountDay(
      date: raw['date']?.toString() ?? '',
      total: (raw['total'] as num?)?.toInt() ?? 0,
      perApp: perApp,
    );
  }

  @override
  List<Object?> get props => [date, total, perApp];
}

/// Friendly identifier for the apps we track. Maps to one or more package
/// names on the native side.
enum ReelPlatform {
  instagram,
  youtubeShorts,
  tiktok,
  snapchatSpotlight,
  facebookReels,
}

extension ReelPlatformX on ReelPlatform {
  String get label => switch (this) {
        ReelPlatform.instagram => 'Instagram Reels',
        ReelPlatform.youtubeShorts => 'YouTube Shorts',
        ReelPlatform.tiktok => 'TikTok',
        ReelPlatform.snapchatSpotlight => 'Snap Spotlight',
        ReelPlatform.facebookReels => 'Facebook Reels',
      };
}
