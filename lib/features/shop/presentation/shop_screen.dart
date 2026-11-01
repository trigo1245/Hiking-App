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

/// 쇼핑 탭: 맨 위 광고 칸(최대 2개, 번갈아) + 상품 카드 2열.
/// 왼쪽 위 ☰로 카테고리를 고르면 그 분류 상품만 보인다. 오른쪽 위에서 주문 내역으로 간다.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  /// null이면 전체
  ProductCategory? _category;

  Future<void> _pickCategory(List<Product> products) async {
    final picked = await showModalBottomSheet<_CategoryChoice>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (context) =>
          _CategorySheet(products: products, selected: _category),
    );
    if (picked == null || picked.category == _category) return;
    setState(() => _category = picked.category);
    // 카테고리를 바꾸면 광고 칸도 다음 차례로 바꾼다.
    ref.read(adRotationProvider.notifier).next();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final rotation = ref.watch(adRotationProvider);
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.screenHorizontal - AppSpacing.md,
          ),
          child: IconButton(
            tooltip: '카테고리',
            onPressed: products.hasValue
                ? () => _pickCategory(products.value!)
                : null,
            icon: const Icon(Icons.menu_rounded),
          ),
        ),
        title: Text(_category?.label ?? '쇼핑'),
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
          onRefresh: () async {
            ref.read(adRotationProvider.notifier).next();
            ref.invalidate(productsProvider);
          },
          child: _ProductList(
            layout: ShopLayout.of(
              value,
              category: _category,
              rotation: rotation,
            ),
            grouped: _category == null,
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

/// 광고 칸 + 일반 목록. [grouped]면(전체 보기) 분류 제목을 붙인다.
class _ProductList extends StatelessWidget {
  const _ProductList({required this.layout, required this.grouped});

  final ShopLayout layout;
  final bool grouped;

  static Widget _title(String text) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenHorizontal,
      AppSpacing.lg,
      AppSpacing.screenHorizontal,
      AppSpacing.md,
    ),
    sliver: SliverToBoxAdapter(
      child: Text(text, style: AppTypography.subtitle),
    ),
  );

  static Widget _grid(List<Product> products, {bool ads = false}) =>
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
            for (final p in products)
              _ProductCard(product: p, showAdBadge: ads),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (layout.ads.isNotEmpty) ...[
          const SliverPadding(padding: EdgeInsets.only(top: AppSpacing.sm)),
          _grid(layout.ads, ads: true),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.lg,
                AppSpacing.screenHorizontal,
                0,
              ),
              child: Divider(height: 1, color: AppColors.divider),
            ),
          ),
        ],
        ..._itemSlivers(),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
      ],
    );
  }

  /// 광고 칸 아래 일반 목록. 전체 보기는 분류 제목으로 묶고, 카테고리 보기는 한 덩어리.
  List<Widget> _itemSlivers() {
    final items = layout.items;
    if (items.isEmpty && layout.ads.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('이 카테고리에는 아직 상품이 없어요')),
        ),
      ];
    }
    if (!grouped) {
      return [
        const SliverPadding(padding: EdgeInsets.only(top: AppSpacing.lg)),
        _grid(items),
      ];
    }
    return [
      for (final category in ProductCategory.values)
        if (items.any((p) => p.category == category)) ...[
          _title(category.label),
          _grid([
            for (final p in items)
              if (p.category == category) p,
          ]),
        ],
    ];
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, this.showAdBadge = false});

  final Product product;

  /// 맨 위 광고 칸에 있을 때만 "광고"를 표시한다 (칸에 들지 못한 광고 상품은 일반 상품처럼).
  final bool showAdBadge;

  @override
  Widget build(BuildContext context) => Pressable(
    onPressed: () => context.push(AppRoutes.product(product.id)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ProductArt(
              category: product.category,
              art: product.art,
              size: null,
              radius: AppRadius.card,
            ),
            if (showAdBadge)
              const Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: AdBadge(),
              ),
          ],
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

/// 카테고리 시트에서 고른 값 (전체는 category가 null)
class _CategoryChoice {
  const _CategoryChoice(this.category);

  final ProductCategory? category;
}

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.products, required this.selected});

  final List<Product> products;
  final ProductCategory? selected;

  @override
  Widget build(BuildContext context) {
    Widget row(ProductCategory? c) {
      final count = c == null
          ? products.length
          : products.where((p) => p.category == c).length;
      final isSelected = c == selected;
      return ListTile(
        leading: Icon(
          c == null ? Icons.apps_rounded : ProductArt.iconOf(c),
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        title: Text(
          c?.label ?? '전체',
          style: AppTypography.body.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.check_rounded, color: AppColors.primary),
            ],
          ],
        ),
        onTap: () => Navigator.of(context).pop(_CategoryChoice(c)),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
            ),
            child: Text('카테고리', style: AppTypography.subtitle),
          ),
          row(null),
          for (final c in ProductCategory.values) row(c),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
