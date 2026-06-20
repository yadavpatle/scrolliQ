import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/challenge.dart';

class ChallengesRepository {
  ChallengesRepository(this._client);
  final SupabaseClient _client;

  String? get _me => _client.auth.currentUser?.id;

  Future<List<Challenge>> listAll() async {
    final rows = await _client
        .from('challenges')
        .select()
        .order('is_default', ascending: false)
        .order('created_at', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Challenge.fromMap)
        .toList();
  }

  Future<List<ChallengeProgress>> myProgress() async {
    final me = _me;
    if (me == null) return const [];
    final rows = await _client
        .from('challenge_participants')
        .select()
        .eq('user_id', me);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ChallengeProgress.fromMap)
        .toList();
  }

  Future<ChallengeProgress?> progressFor(String challengeId) async {
    final me = _me;
    if (me == null) return null;
    final row = await _client
        .from('challenge_participants')
        .select()
        .eq('user_id', me)
        .eq('challenge_id', challengeId)
        .maybeSingle();
    return row == null ? null : ChallengeProgress.fromMap(row);
  }

  Future<void> join(String challengeId) async {
    final me = _me;
    if (me == null) throw StateError('Not signed in');
    await _client.from('challenge_participants').upsert(
      {
        'challenge_id': challengeId,
        'user_id': me,
      },
      onConflict: 'challenge_id,user_id',
    );
  }

  Future<void> leave(String challengeId) async {
    final me = _me;
    if (me == null) return;
    await _client
        .from('challenge_participants')
        .delete()
        .eq('user_id', me)
        .eq('challenge_id', challengeId);
  }

  /// Recomputes daysCompleted/score using the user's recent daily_usage rows.
  /// Counts a day as "completed" if brain_score >= challenge.min_score and
  /// the row's date >= started_at::date.
  Future<ChallengeProgress?> recompute({
    required Challenge challenge,
  }) async {
    final me = _me;
    if (me == null) return null;
    final progress = await progressFor(challenge.id);
    if (progress == null) return null;

    final start = progress.startedAt.toUtc();
    final endLimit = start.add(Duration(days: challenge.durationDays));
    final fromStr = '${start.year.toString().padLeft(4, '0')}-'
        '${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
    // Exclusive upper bound: the window covers exactly [start, endLimit).
    final toStr = '${endLimit.year.toString().padLeft(4, '0')}-'
        '${endLimit.month.toString().padLeft(2, '0')}-'
        '${endLimit.day.toString().padLeft(2, '0')}';

    final rows = await _client
        .from('daily_usage')
        .select('date,brain_score')
        .eq('user_id', me)
        .gte('date', fromStr)
        .lt('date', toStr)
        .order('date');

    int days = 0;
    int totalScore = 0;
    for (final r in rows as List) {
      final score = (r['brain_score'] as num?)?.toInt() ?? 0;
      totalScore += score;
      if (score >= challenge.minScore) days += 1;
    }
    days = days.clamp(0, challenge.durationDays);

    final completed = days >= challenge.durationDays;
    await _client.from('challenge_participants').update({
      'days_completed': days,
      'score': totalScore,
      if (completed) 'completed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', progress.id);

    // Optional safety: stop counting after duration window passes.
    if (DateTime.now().toUtc().isAfter(endLimit) && !completed) {
      // Window expired without success – leave row but completed_at stays null.
    }

    return progressFor(challenge.id);
  }
}
