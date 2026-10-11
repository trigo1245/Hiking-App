import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// 글자 스타일 토큰. 폰트는 Pretendard.
abstract final class AppTypography {
  static const fontFamily = 'Pretendard';

  /// 대형 수치 (기록 화면의 시간·거리)
  static const display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  /// 제목
  static const title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  /// 소제목
  static const subtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  /// 본문
  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// 보조 설명
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
    height: 1.4,
  );

  /// 하단 고정 버튼 글자
  static const button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.onPrimary,
    height: 1.2,
  );
}
