import 'package:flutter/material.dart';

import '../design/design.dart';

/// 아직 내용이 없는 화면에 쓰는 안내 문구.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
