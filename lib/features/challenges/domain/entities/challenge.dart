import 'package:equatable/equatable.dart';

class Challenge extends Equatable {
  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.durationDays,
    required this.minScore,
    required this.isDefault,
  });

  final String id;
  final String title;
  final String description;
  final int    durationDays;
  final int    minScore;
  final bool   isDefault;

  factory Challenge.fromMap(Map<String, dynamic> m) => Challenge(
        id: m['id'].toString(),
        title: m['title'].toString(),
        description: m['description'].toString(),
        durationDays: (m['duration_days'] as num).toInt(),
        minScore:     (m['min_score']     as num?)?.toInt() ?? 75,
        isDefault:    (m['is_default']    as bool?) ?? false,
      );

  @override
  List<Object?> get props => [id, title, description, durationDays, minScore, isDefault];
}

class ChallengeProgress extends Equatable {
  const ChallengeProgress({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.score,
    required this.daysCompleted,
    required this.startedAt,
    this.completedAt,
  });

  final String id;
  final String challengeId;
  final String userId;
  final int    score;
  final int    daysCompleted;
  final DateTime startedAt;
  final DateTime? completedAt;

  factory ChallengeProgress.fromMap(Map<String, dynamic> m) => ChallengeProgress(
        id: m['id'].toString(),
        challengeId: m['challenge_id'].toString(),
        userId: m['user_id'].toString(),
        score: (m['score'] as num?)?.toInt() ?? 0,
        daysCompleted: (m['days_completed'] as num?)?.toInt() ?? 0,
        startedAt: DateTime.parse(m['started_at'].toString()),
        completedAt: m['completed_at'] == null
            ? null
            : DateTime.tryParse(m['completed_at'].toString()),
      );

  @override
  List<Object?> get props =>
      [id, challengeId, userId, score, daysCompleted, startedAt, completedAt];
}
