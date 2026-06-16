import 'package:equatable/equatable.dart';

/// Domain entity representing the authenticated user profile.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final DateTime? createdAt;

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    DateTime? createdAt,
  }) =>
      AppUser(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt ?? this.createdAt,
      );

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as String,
        email: map['email'] as String? ?? '',
        name: map['name'] as String? ?? '',
        avatarUrl: map['avatar_url'] as String?,
        createdAt: map['created_at'] == null
            ? null
            : DateTime.tryParse(map['created_at'].toString()),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'name': name,
        'avatar_url': avatarUrl,
      };

  @override
  List<Object?> get props => [id, email, name, avatarUrl, createdAt];
}
