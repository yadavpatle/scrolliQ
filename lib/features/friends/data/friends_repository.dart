import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/friendship.dart';

class FriendsRepository {
  FriendsRepository(this._client);
  final SupabaseClient _client;

  String get _me {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  Future<List<UserSearchResult>> searchUsers(String query) async {
    if (query.trim().length < 2) return const [];
    final rows = await _client.rpc('search_users', params: {'q': query.trim()});
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(UserSearchResult.fromMap)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Friend list / requests
  // ---------------------------------------------------------------------------

  Future<List<Friendship>> _fetch(String filter) async {
    final me = _me;
    final rows = await _client
        .from('friends')
        .select('''
          id, sender_id, receiver_id, status, created_at,
          sender:users!friends_sender_id_fkey(id,name,email,avatar_url),
          receiver:users!friends_receiver_id_fkey(id,name,email,avatar_url)
        ''')
        .or(filter)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((m) => Friendship.fromMap(m, me: me))
        .toList();
  }

  /// Accepted friends.
  Future<List<Friendship>> friends() async {
    final me = _me;
    final all = await _fetch('sender_id.eq.$me,receiver_id.eq.$me');
    return all.where((f) => f.status == FriendStatus.accepted).toList();
  }

  /// Pending requests received.
  Future<List<Friendship>> incomingRequests() async {
    final me = _me;
    final all = await _fetch('receiver_id.eq.$me');
    return all.where((f) => f.status == FriendStatus.pending).toList();
  }

  /// Pending requests sent.
  Future<List<Friendship>> outgoingRequests() async {
    final me = _me;
    final all = await _fetch('sender_id.eq.$me');
    return all.where((f) => f.status == FriendStatus.pending).toList();
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<void> sendRequest(String receiverId) async {
    final me = _me;
    if (receiverId == me) {
      throw ArgumentError("Can't friend yourself.");
    }
    await _client.from('friends').upsert(
      {
        'sender_id': me,
        'receiver_id': receiverId,
        'status': 'pending',
      },
      onConflict: 'sender_id,receiver_id',
    );
  }

  Future<void> respond(String friendshipId, {required bool accept}) async {
    await _client.from('friends').update({
      'status': accept ? 'accepted' : 'declined',
    }).eq('id', friendshipId);
  }

  Future<void> remove(String friendshipId) async {
    await _client.from('friends').delete().eq('id', friendshipId);
  }
}
