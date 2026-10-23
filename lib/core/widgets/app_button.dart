import 'package:flutter/material.dart';

import '../design/design.dart';
import 'pressable.dart';

enum AppButtonVariant {
  /// 화면의 핵심 행동
  primary,

  /// 카카오 로그인
  kakao,

  /// 보조 행동 (회색 배경)
  secondary,

  /// 되돌릴 수 없는 행동 (삭제 등)
  danger,
}

/// 꽉 찬 너비, 높이 56의 기본 버튼.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
  });

  final String label;

  /// null이면 비활성화된다.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (variant) {
      AppButtonVariant.primary => (AppColors.primary, AppColors.onPrimary),
      AppButtonVariant.kakao => (
        AppColors.kakaoContainer,
        AppColors.kakaoLabel,
      ),
      AppButtonVariant.secondary => (
        AppColors.backgroundGrouped,
        AppColors.textPrimary,
      ),
      AppButtonVariant.danger => (AppColors.danger, AppColors.onPrimary),
    };

    return Pressable(
      onPressed: onPressed,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.4 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: AppSizes.bottomButtonHeight,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Text(
            label,
            style: AppTypography.button.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}
