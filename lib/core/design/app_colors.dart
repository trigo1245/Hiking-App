import 'package:flutter/painting.dart';

/// 색상 토큰. 위젯에서는 색 값을 직접 쓰지 않고 항상 이 토큰을 사용한다.
abstract final class AppColors {
  /// 브랜드 색 확정 시 이 값만 교체한다.
  static const primary = Color(0xFF3182F6);

  static const background = Color(0xFFFFFFFF);

  /// 카드 뒤 배경
  static const backgroundGrouped = Color(0xFFF2F4F6);

  static const textPrimary = Color(0xFF191F28);
  static const textSecondary = Color(0xFF4E5968);
  static const textTertiary = Color(0xFF8B95A1);

  static const divider = Color(0xFFE5E8EB);
  static const danger = Color(0xFFF04452);
  static const success = Color(0xFF03B26C);

  /// primary 위에 올라가는 글자색
  static const onPrimary = Color(0xFFFFFFFF);
}
