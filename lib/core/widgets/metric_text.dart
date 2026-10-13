import 'package:flutter/material.dart';

import '../design/design.dart';

/// "거리 / 3.42 km"처럼 이름, 숫자, 단위를 보여 준다. 숫자는 크고 굵게, 단위는 작고 연하게.
class MetricText extends StatelessWidget {
  const MetricText({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.valueStyle = AppTypography.title,
  });

  final String label;
  final String value;
  final String unit;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.xs),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: value, style: valueStyle),
              TextSpan(
                text: ' $unit',
                style: AppTypography.body.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
