/// 연결할 수 있는 소셜 계정 종류.
enum SocialProvider { kakao, google }

/// 앱에서 쓰는 로그인 사용자 정보. Supabase 타입에 의존하지 않는다.
class AppUser {
  const AppUser({
    required this.id,
    required this.isAnonymous,
    this.linkedProviders = const {},
  });

  final String id;

  /// 소셜 계정을 연결하지 않은 익명 사용자인지.
  /// 익명 사용자는 앱을 지우면 같은 계정으로 돌아올 수 없다.
  final bool isAnonymous;

  final Set<SocialProvider> linkedProviders;

  bool isLinkedTo(SocialProvider provider) =>
      linkedProviders.contains(provider);
}
