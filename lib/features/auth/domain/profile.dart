/// Supabase `profiles` 테이블의 한 행 (내 프로필).
class Profile {
  const Profile({
    required this.id,
    required this.nickname,
    this.nicknameTag,
    this.avatarUrl,
    this.hasCustomAvatar = false,
    this.bio,
    this.region,
  });

  final String id;
  final String nickname;

  /// 같은 닉네임을 구분하는 4자리 숫자 (예: 0421)
  final String? nicknameTag;

  /// 프로필 사진 주소 (카카오·구글 사진 또는 직접 올린 사진)
  final String? avatarUrl;

  /// 직접 올린 사진이면 true (카카오·구글 사진으로 되돌릴 수 있다)
  final bool hasCustomAvatar;

  /// 소개 (300자 이내, 공개)
  final String? bio;

  /// 주 활동 지역 (직접 입력, 공개). 예: 부산 금정구
  final String? region;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    nickname: json['nickname'] as String,
    nicknameTag: json['nickname_tag'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    hasCustomAvatar: json['custom_avatar_path'] != null,
    bio: json['bio'] as String?,
    region: json['region'] as String?,
  );
}

/// 다른 사용자도 볼 수 있는 프로필 (랭킹·리뷰에서 눌렀을 때). 개인정보는 없다.
class PublicProfile {
  const PublicProfile({
    required this.nickname,
    required this.nicknameTag,
    this.avatarUrl,
    this.bio,
    this.region,
    this.isMe = false,
  });

  final String nickname;
  final String nicknameTag;
  final String? avatarUrl;
  final String? bio;
  final String? region;
  final bool isMe;
}
