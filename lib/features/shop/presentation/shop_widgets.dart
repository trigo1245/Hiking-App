import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/pressable.dart';
import '../domain/shop.dart';

/// 상품 그림: 상품 사진 대신 분류 아이콘을 넣은 색 카드 (나중에 이미지로 바꿀 수 있다)
class ProductArt extends StatelessWidget {
  const ProductArt({
    super.key,
    required this.category,
    required this.art,
    this.size = 64,
    this.radius = AppRadius.input,
  });

  final ProductCategory category;
  final int art;

  /// 정사각형 한 변. null이면 부모 너비를 채운다(정사각형).
  final double? size;
  final double radius;

  static IconData iconOf(ProductCategory c) => switch (c) {
    ProductCategory.shoes => Icons.hiking_rounded,
    ProductCategory.backpack => Icons.backpack_outlined,
    ProductCategory.poles => Icons.straighten_rounded,
    ProductCategory.clothing => Icons.checkroom_rounded,
    ProductCategory.safety => Icons.flashlight_on_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final i = art % AppColors.productArtBackgrounds.length;
    final box = LayoutBuilder(
      builder: (context, constraints) {
        final side = size ?? constraints.maxWidth;
        return Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: AppColors.productArtBackgrounds[i],
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Icon(
            iconOf(category),
            size: side * 0.42,
            color: AppColors.productArtForegrounds[i],
          ),
        );
      },
    );
    return size == null ? AspectRatio(aspectRatio: 1, child: box) : box;
  }
}

/// 별점 (읽기 전용). 반 개는 그리지 않고 반올림한다.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          Icons.star_rounded,
          size: size,
          color: i <= rating.round() ? AppColors.star : AppColors.divider,
        ),
    ],
  );
}

/// 별점 고르기 (리뷰 쓰기)
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 1; i <= 5; i++)
        Pressable(
          onPressed: () => onChanged(i),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Icon(
              Icons.star_rounded,
              size: 44,
              semanticLabel: '별 $i개',
              color: i <= (value ?? 0) ? AppColors.star : AppColors.divider,
            ),
          ),
        ),
    ],
  );
}

/// "★ 4.5 (12)" 또는 "아직 리뷰가 없어요"
class RatingSummary extends StatelessWidget {
  const RatingSummary({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final avg = product.ratingAvg;
    if (avg == null) {
      return Text(
        '아직 리뷰가 없어요',
        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 16, color: AppColors.star),
        const SizedBox(width: 2),
        Text(
          '${avg.toStringAsFixed(1)} (${product.reviewCount})',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
