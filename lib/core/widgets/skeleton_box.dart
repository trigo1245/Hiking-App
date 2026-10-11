import 'package:flutter/material.dart';

import '../design/design.dart';

/// 로딩 중 자리를 잡아 두는 회색 상자. 스피너 대신 쓴다.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
    );
  }
}
