enum AuthFailureType {
  /// 사용자가 로그인 창을 닫음. 안내 문구 없이 조용히 넘어간다.
  cancelled,

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
