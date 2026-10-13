/// 로그인 방법. 카카오 계정과 구글 계정은 각각 별개의 사용자다.
enum SocialProvider { kakao, google }

/// 앱에서 쓰는 로그인 사용자 정보. Supabase 타입에 의존하지 않는다.
class AppUser {
  const AppUser({required this.id, required this.provider});

  final String id;

  /// 어떤 계정으로 로그인했는지. 알 수 없으면 null.
  final SocialProvider? provider;
}
