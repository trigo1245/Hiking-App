import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/photos/photo_widgets.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/nickname_text.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/domain/profile_rules.dart';
import '../../auth/presentation/private_info_screen.dart';
import '../../auth/presentation/public_profile_sheet.dart';
import '../../clubs/presentation/club_format.dart';
import '../data/shop_remote.dart';
import '../domain/shop.dart';
import 'order_screen.dart';
import 'shop_widgets.dart';

/// 상품 상세: 그림·이름·가격·별점·설명, 옵션 고르기, 리뷰(최신순 / 별점 높은 순), 하단 "구매하기".
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  String? _option;
  ProductReviewSort _sort = ProductReviewSort.recent;

  Future<void> _buy(Product product) async {
    if (product.hasOptions && _option == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${withObjectParticle(product.optionName ?? '옵션')} 골라 주세요',
            ),
          ),
        );
      return;
    }
    // 배송에 필요한 개인정보가 없으면 여기서 받고 이어서 주문서로 간다.
    final ok = await requirePrivateInfo(
      context,
      fields: {PrivateField.name, PrivateField.phone, PrivateField.address},
      purpose: '상품 배송',
    );
    if (!ok || !mounted) return;
    await context.push(
      AppRoutes.orderNew,
      extra: OrderDraft(product: product, option: _option),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productProvider(widget.productId));
    final value = product.value;
    return Scaffold(
      appBar: AppBar(),
      body: switch (product) {
        AsyncValue(:final value?) => _body(value),
        AsyncValue(hasValue: true) => const Center(
          child: Text('판매하지 않는 상품이에요'),
        ),
        AsyncValue(:final error?) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(productsProvider),
            child: Text(
              '${errorMessage(error, failed: '상품을 불러오지 못했어요')}\n눌러서 다시 시도',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const Padding(
          padding: EdgeInsets.all(AppSpacing.screenHorizontal),
          child: SkeletonBox(width: double.infinity, height: 320),
        ),
      },
      bottomNavigationBar: value == null
          ? null
          : BottomActionBar(
              child: AppButton(
                label: '${formatPrice(value.price)} 구매하기',
                onPressed: () => _buy(value),
              ),
            ),
    );
  }

  Widget _body(Product p) {
    return RefreshIndicator(
      onRefresh: () async => ref
        ..invalidate(productsProvider)
        ..invalidate(productReviewsProvider)
        ..invalidate(myProductReviewProvider(p.id)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        children: [
          ProductArt(
            category: p.category,
            art: p.art,
            size: null,
            radius: AppRadius.card,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            p.category.label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(p.name, style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatPrice(p.price),
            style: AppTypography.title.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              RatingSummary(product: p),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '무료배송',
                style: AppTypography.caption.copyWith(color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            p.description,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          if (p.hasOptions) ...[
            const SizedBox(height: AppSpacing.xxl),
            Text(p.optionName ?? '옵션', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final o in p.options)
                  _OptionChip(
                    label: o,
                    selected: _option == o,
                    onPressed: () => setState(() => _option = o),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xxxl),
          _Reviews(
            product: p,
            sort: _sort,
            onSort: (s) => setState(() => _sort = s),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    onPressed: onPressed,
    child: Container(
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(
          color: selected ? AppColors.onPrimary : AppColors.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}

/// 리뷰: 정렬, 내 리뷰 쓰기·고치기(배송 완료된 주문이 있을 때), 목록(30개)
class _Reviews extends ConsumerWidget {
  const _Reviews({
    required this.product,
    required this.sort,
    required this.onSort,
  });

  final Product product;
  final ProductReviewSort sort;
  final ValueChanged<ProductReviewSort> onSort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(productReviewsProvider((product.id, sort)));
    final mine = ref.watch(myProductReviewProvider(product.id)).value;
    final total = reviews.value?.total ?? product.reviewCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('리뷰 $total', style: AppTypography.subtitle)),
            if (mine?.canReview ?? false)
              TextButton(
                onPressed: () {
                  ref.invalidate(myProductReviewProvider(product.id));
                  context.push(AppRoutes.productReview(product.id));
                },
                child: Text(mine!.exists ? '내 리뷰 고치기' : '리뷰 쓰기'),
              ),
          ],
        ),
        Text(
          '구매하고 배송을 받은 분만 리뷰를 쓸 수 있어요',
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.md),
        SegmentedTabs<ProductReviewSort>(
          options: {for (final s in ProductReviewSort.values) s: s.label},
          selected: sort,
          onChanged: onSort,
        ),
        const SizedBox(height: AppSpacing.md),
        ...switch (reviews) {
          AsyncValue(:final value?) when value.reviews.isEmpty => [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                '아직 리뷰가 없어요',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
          AsyncValue(:final value?) => [
            for (final r in value.reviews) ProductReviewTile(review: r),
            if (value.total > value.reviews.length)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  '최근 ${value.reviews.length}개만 보여 드려요',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
          ],
          AsyncValue(:final error?) => [
            TextButton(
              onPressed: () => ref.invalidate(productReviewsProvider),
              child: Text(errorMessage(error, failed: '리뷰를 불러오지 못했어요')),
            ),
          ],
          _ => [const SkeletonBox(width: double.infinity, height: 120)],
        },
      ],
    );
  }
}

class ProductReviewTile extends StatelessWidget {
  const ProductReviewTile({super.key, required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    final images = [for (final u in review.photoUrls) NetworkImage(u)];
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            onPressed: () => showPublicProfile(
              context,
              nickname: review.nickname,
              tag: review.nicknameTag,
              avatarUrl: review.avatarUrl,
            ),
            child: Row(
              children: [
                UserAvatar(
                  nickname: review.nickname,
                  imageUrl: review.avatarUrl,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: NicknameText(
                    nickname: review.nickname,
                    tag: review.nicknameTag,
                    suffix: review.isMine ? ' (나)' : null,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  formatShortDate(review.createdAt),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              StarRating(rating: review.rating.toDouble()),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '구매 확인',
                style: AppTypography.caption.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          if (review.comment case final c? when c.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(c, style: AppTypography.body),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            PhotoStrip(
              size: 72,
              images: images,
              onTap: (i) =>
                  openPhotoViewer(context, images: images, initial: i),
            ),
          ],
        ],
      ),
    );
  }
}
