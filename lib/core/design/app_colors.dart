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

  /// 업적 배지 단계 색 (3단계 동·은·금, 2단계 동·금, 1단계 금)
  static const badgeBronze = Color(0xFFC9895A);
  static const badgeSilver = Color(0xFFA3AEBA);
  static const badgeGold = Color(0xFFF0B429);

  /// 시즌 정복 배지: 백금 바탕에 무지갯빛(프리즘) 그라데이션을 얹는다.
  static const badgePlatinum = Color(0xFFE3E8EE);
  static const badgePrism = [
    Color(0xFFFFBFDD),
    Color(0xFFBCD4FF),
    Color(0xFFB8EED5),
    Color(0xFFFFE89E),
    Color(0xFFD6C2FF),
    Color(0xFFFFBFDD),
  ];

  /// 아직 얻지 못한 배지
  static const badgeLocked = Color(0xFFD1D6DB);

  /// 카카오 로그인 버튼 (카카오 로그인 디자인 가이드 지정 색)
  static const kakaoContainer = Color(0xFFFEE500);
  static const kakaoLabel = Color(0xD9000000);
}
