enum AuthFailureType {
  /// 사용자가 로그인 창을 닫음. 안내 문구 없이 조용히 넘어간다.
  cancelled,

  /// 연결하려는 소셜 계정이 이미 다른 사용자에 연결돼 있음.
  /// (예: 앱을 다시 설치한 뒤 익명으로 시작하고, 예전 카카오 계정을 연결하려는 경우)
  identityAlreadyExists,

  /// Supabase·Google·Kakao 콘솔 설정이 빠졌거나 틀림.
  notConfigured,

  network,
  unknown,
}

/// 로그인 과정에서 생긴 오류. repository가 외부 라이브러리 오류를 이 타입으로 바꿔 던진다.
class AuthFailure implements Exception {
  const AuthFailure(this.type, [this.detail]);

  final AuthFailureType type;

  /// 개발자 확인용 원본 메시지. 화면에 그대로 보여 주지 않는다.
  final String? detail;

  @override
  String toString() => 'AuthFailure($type, $detail)';
}
