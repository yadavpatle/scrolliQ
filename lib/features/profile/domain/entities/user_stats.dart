import 'package:equatable/equatable.dart';

class UserStats extends Equatable {
  const UserStats({
    required this.userId,
    required this.name,
    required this.currentScore,
    required this.weeklyAvgScore,
    required this.focusDays,
    this.avatarUrl,
  });

  final String  userId;
  final String  name;
  final int     currentScore;
  final int     weeklyAvgScore;
  final int     focusDays;
  final String? avatarUrl;

  factory UserStats.fromMap(Map<String, dynamic> m) => UserStats(
        userId: m['user_id'].toString(),
        name: (m['name'] as String?) ?? '',
        avatarUrl: m['avatar_url'] as String?,
        currentScore:    (m['current_score']     as num?)?.toInt() ?? 100,
        weeklyAvgScore:  (m['weekly_avg_score']  as num?)?.toInt() ?? 100,
        focusDays:       (m['focus_days']        as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props =>
      [userId, name, avatarUrl, currentScore, weeklyAvgScore, focusDays];
}
