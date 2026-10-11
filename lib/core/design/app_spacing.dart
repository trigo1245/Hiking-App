/// 간격 토큰 (4의 배수).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// 화면 좌우 여백
  static const double screenHorizontal = 20;
}

/// 모서리 둥글기 토큰.
abstract final class AppRadius {
  static const double card = 20;
  static const double button = 16;
  static const double input = 12;
}

/// 크기 관련 토큰.
abstract final class AppSizes {
  /// 하단 고정 버튼 높이
  static const double bottomButtonHeight = 56;

  /// 눌림 효과 배율
  static const double pressedScale = 0.97;
}
