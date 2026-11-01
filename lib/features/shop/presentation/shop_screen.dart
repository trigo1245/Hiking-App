import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../data/shop_remote.dart';
import '../domain/shop.dart';
import 'shop_widgets.dart';

/// 쇼핑 탭: 분류별 상품 카드 2열. 오른쪽 위에서 주문 내역으로 간다.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('쇼핑'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: AppSpacing.screenHorizontal - AppSpacing.md,
            ),
            child: IconButton(
              tooltip: '주문 내역',
              onPressed: () => context.push(AppRoutes.orders),
              icon: const Icon(Icons.receipt_long_outlined),
            ),
          ),
        ],
      ),
      body: switch (products) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(productsProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              for (final category in ProductCategory.values)
                if (value.any((p) => p.category == category)) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.lg,
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        category.label,
                        style: AppTypography.subtitle,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    sliver: SliverGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.lg,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.66,
                      children: [
                        for (final p in value.where(
                          (p) => p.category == category,
                        ))
                          _ProductCard(product: p),
                      ],
                    ),
                  ),
                ],
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxxl),
              ),
            ],
          ),
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
          child: SkeletonBox(width: double.infinity, height: 240),
        ),
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) => Pressable(
    onPressed: () => context.push(AppRoutes.product(product.id)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductArt(
          category: product.category,
          art: product.art,
          size: null,
          radius: AppRadius.card,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body,
        ),
        const SizedBox(height: 2),
        Text(
          formatPrice(product.price),
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        RatingSummary(product: product),
      ],
    ),
  );
}
