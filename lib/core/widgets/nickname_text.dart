import 'package:flutter/material.dart';

import '../design/design.dart';

/// 닉네임#태그. 태그는 닉네임보다 연하게 보여 준다. 예: 등산왕#0421
/// [suffix]는 태그 뒤에 닉네임과 같은 색으로 붙인다. 예: " (나)"
class NicknameText extends StatelessWidget {
  const NicknameText({
    super.key,
    required this.nickname,
    required this.tag,
    this.style,
    this.suffix,
  });

  final String nickname;
  final String? tag;
  final TextStyle? style;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final base = style ?? AppTypography.body;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: nickname),
          if (tag != null && tag!.isNotEmpty)
            TextSpan(
              text: '#$tag',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w400,
              ),
            ),
          if (suffix != null) TextSpan(text: suffix),
        ],
      ),
      style: base,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
