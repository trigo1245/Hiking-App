import 'package:flutter/material.dart';

import '../design/design.dart';
import 'pressable.dart';

/// 두세 개 중 하나를 고르는 탭. 예: 이번 시즌 | 명예의 전당
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// 값 → 표시 이름
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          for (final MapEntry(key: value, value: label) in options.entries)
            Expanded(
              child: Pressable(
                onPressed: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == selected
                        ? AppColors.background
                        : AppColors.backgroundGrouped,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Text(
                    label,
                    style: AppTypography.body.copyWith(
                      fontWeight: value == selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: value == selected
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
