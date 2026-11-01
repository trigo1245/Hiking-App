/// Supabase `profiles` 테이블의 한 행.
class Profile {
  const Profile({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.hasCustomAvatar = false,
  });

  final String id;
  final String nickname;

  /// 프로필 사진 주소 (카카오·구글 사진 또는 직접 올린 사진)
  final String? avatarUrl;

  /// 직접 올린 사진이면 true (카카오·구글 사진으로 되돌릴 수 있다)
  final bool hasCustomAvatar;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    nickname: json['nickname'] as String,
    avatarUrl: json['avatar_url'] as String?,
    hasCustomAvatar: json['custom_avatar_path'] != null,
  );
}
