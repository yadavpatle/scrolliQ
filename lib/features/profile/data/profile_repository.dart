import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/user_stats.dart';

class ProfileRepository {
  ProfileRepository(this._client);
  final SupabaseClient _client;

  Future<UserStats?> myStats() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return null;
    final row = await _client
        .from('user_stats')
        .select()
        .eq('user_id', id)
        .maybeSingle();
    if (row == null) return null;
    return UserStats.fromMap(row);
  }

  Future<void> updateName(String name) async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return;
    await _client.from('users').update({'name': name.trim()}).eq('id', id);
  }
}
