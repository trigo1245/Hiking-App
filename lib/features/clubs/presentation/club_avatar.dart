import 'package:flutter/material.dart';

import '../../../core/design/design.dart';

/// 동호회 대표 사진. 사진이 없거나 불러오지 못하면 이름 첫 글자를 둥근 네모에 보여 준다.
/// (사람 프로필은 동그라미, 동호회는 둥근 네모로 구분한다)
class ClubAvatar extends StatelessWidget {
  const ClubAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 48,
    this.borderColor,
  });

  final String name;
  final String? photoUrl;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final initial = Center(
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: AppTypography.body.copyWith(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
    final url = photoUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
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
