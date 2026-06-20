/// Lightweight view of the user who owns a referral code.
///
/// Returned by the `get_referrer` RPC so an invite can be previewed before the
/// invited user has authenticated.
class ReferrerPreview {
  const ReferrerPreview({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String? avatarUrl;

  factory ReferrerPreview.fromMap(Map<String, dynamic> map) {
    return ReferrerPreview(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}
