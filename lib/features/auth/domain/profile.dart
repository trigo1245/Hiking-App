/// Supabase `profiles` 테이블의 한 행.
class Profile {
  const Profile({required this.id, required this.nickname});

  final String id;
  final String nickname;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      Profile(id: json['id'] as String, nickname: json['nickname'] as String);
}
