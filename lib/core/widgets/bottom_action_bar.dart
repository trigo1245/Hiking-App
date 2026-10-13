import 'package:flutter/material.dart';

import '../design/design.dart';

/// 화면 하단에 고정되는 버튼 영역. (좌우 여백 20)
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
        ),
        child: child,
      ),
    );
  }
}
