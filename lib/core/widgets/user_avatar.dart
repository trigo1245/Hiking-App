import 'package:flutter/material.dart';

import '../design/design.dart';

/// 카카오·구글 프로필 사진. 사진이 없거나 인터넷이 없으면 닉네임 첫 글자를 보여 준다.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.nickname,
    this.imageUrl,
    this.size = 40,
    this.borderColor,
  });

  final String nickname;
  final String? imageUrl;
  final double size;

  /// 지도 위에서처럼 테두리가 필요할 때
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final initial = Center(
      child: Text(
        nickname.isEmpty ? '?' : nickname.characters.first,
        style: AppTypography.body.copyWith(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
    final url = imageUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        shape: BoxShape.circle,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? initial
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initial,
            ),
    );
  }
}
