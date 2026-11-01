import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../clubs/presentation/club_format.dart';
import '../data/shop_remote.dart';
import '../domain/shop.dart';
import 'shop_widgets.dart';

/// 주문 내역 (내 정보·쇼핑 탭에서 진입). 배송 완료된 상품은 여기서 리뷰를 쓴다.
/// 시연용 배송 상태는 시간이 지나면 바뀌므로, 화면이 열려 있는 동안 15초마다 다시 받는다.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  /// 배송 상태가 바뀌면 리뷰 자격도 바뀌므로 함께 다시 받는다.
  /// (상품 상세가 아래에 열려 있으면 예전 리뷰 자격을 들고 있다)
  void _refresh() => ref
    ..invalidate(myOrdersProvider)
    ..invalidate(myProductReviewProvider);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(myOrdersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('주문 내역')),
      body: switch (orders) {
        AsyncValue(:final value?) when value.isEmpty => const EmptyView(
          message: '아직 주문한 상품이 없어요.\n쇼핑 탭에서 등산 장비를 둘러보세요',
        ),
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [for (final o in value) _OrderCard(order: o)],
          ),
        ),
        AsyncValue(:final error?) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(myOrdersProvider),
            child: Text(
              '${errorMessage(error, failed: '주문 내역을 불러오지 못했어요')}\n눌러서 다시 시도',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const Padding(
          padding: EdgeInsets.all(AppSpacing.screenHorizontal),
          child: SkeletonBox(width: double.infinity, height: 160),
        ),
      },
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final ShopOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delivered = order.status == OrderStatus.delivered;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${formatShortDate(order.createdAt)} 주문',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const Spacer(),
              Text(
                order.status.label,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: delivered ? AppColors.success : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Pressable(
            onPressed: () => context.push(AppRoutes.product(order.productId)),
            child: Row(
              children: [
                ProductArt(category: order.category, art: order.art, size: 56),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.productName, style: AppTypography.body),
                      Text(
                        order.summary,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        formatPrice(order.totalPrice),
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (delivered)
            OutlinedButton(
              onPressed: () async {
                ref.invalidate(myProductReviewProvider(order.productId));
                await context.push(AppRoutes.productReview(order.productId));
                ref.invalidate(myOrdersProvider);
              },
              child: Text(order.hasReview ? '내 리뷰 고치기' : '리뷰 쓰기'),
            )
          else
            Text(
              order.status == OrderStatus.paid
                  ? '곧 배송을 시작해요. 배송이 끝나면 리뷰를 쓸 수 있어요'
                  : '배송 중이에요. 배송이 끝나면 리뷰를 쓸 수 있어요',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
