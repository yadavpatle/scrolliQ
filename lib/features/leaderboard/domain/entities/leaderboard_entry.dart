import 'package:equatable/equatable.dart';

class LeaderboardEntry extends Equatable {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.brainScore,
    this.avatarUrl,
    this.totalScreenTime = 0,
  });

  final int rank;
  final String userId;
  final String name;
  final int brainScore;
  final String? avatarUrl;
  final int totalScreenTime;

  factory LeaderboardEntry.fromMap(Map<String, dynamic> m) => LeaderboardEntry(
        rank: (m['rank'] as num).toInt(),
        userId: m['user_id'].toString(),
        name: (m['name'] as String?) ?? 'Anonymous',
        avatarUrl: m['avatar_url'] as String?,
        brainScore: (m['brain_score'] as num?)?.toInt() ?? 100,
        totalScreenTime: (m['total_screen_time'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props =>
      [rank, userId, name, brainScore, avatarUrl, totalScreenTime];
}
