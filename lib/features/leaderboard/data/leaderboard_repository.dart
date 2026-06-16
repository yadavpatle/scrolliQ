import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/leaderboard_entry.dart';

class LeaderboardRepository {
  LeaderboardRepository(this._client);
  final SupabaseClient _client;

  Future<List<LeaderboardEntry>> fetchToday({int limit = 100}) async {
    final rows = await _client
        .from('leaderboard_today')
        .select()
        .order('brain_score', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromMap)
        .toList();
  }

  Future<List<LeaderboardEntry>> fetchTopPreview({int limit = 5}) =>
      fetchToday(limit: limit);
}
