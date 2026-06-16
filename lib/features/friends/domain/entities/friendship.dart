import 'package:equatable/equatable.dart';

enum FriendStatus { pending, accepted, declined, blocked }

FriendStatus _parseStatus(String s) => switch (s) {
      'pending'  => FriendStatus.pending,
      'accepted' => FriendStatus.accepted,
      'declined' => FriendStatus.declined,
      'blocked'  => FriendStatus.blocked,
      _          => FriendStatus.pending,
    };

class Friendship extends Equatable {
  const Friendship({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.otherName,
    this.otherAvatarUrl,
    this.otherEmail,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final FriendStatus status;
  final DateTime createdAt;

  // Joined user info
  final String? otherName;
  final String? otherAvatarUrl;
  final String? otherEmail;

  String otherId(String me) => senderId == me ? receiverId : senderId;
  bool isIncoming(String me) => receiverId == me;

  factory Friendship.fromMap(Map<String, dynamic> m, {String? me}) {
    final senderId = m['sender_id'].toString();
    final receiverId = m['receiver_id'].toString();
    final senderUser = m['sender'] as Map<String, dynamic>?;
    final receiverUser = m['receiver'] as Map<String, dynamic>?;

    Map<String, dynamic>? other;
    if (me != null) {
      other = senderId == me ? receiverUser : senderUser;
    }

    return Friendship(
      id: m['id'].toString(),
      senderId: senderId,
      receiverId: receiverId,
      status: _parseStatus(m['status'].toString()),
      createdAt: DateTime.parse(m['created_at'].toString()),
      otherName:      other?['name']       as String?,
      otherAvatarUrl: other?['avatar_url'] as String?,
      otherEmail:     other?['email']      as String?,
    );
  }

  @override
  List<Object?> get props => [id, senderId, receiverId, status, createdAt];
}

class UserSearchResult extends Equatable {
  const UserSearchResult({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  factory UserSearchResult.fromMap(Map<String, dynamic> m) => UserSearchResult(
        id: m['id'].toString(),
        name: (m['name'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        avatarUrl: m['avatar_url'] as String?,
      );

  @override
  List<Object?> get props => [id, name, email, avatarUrl];
}
