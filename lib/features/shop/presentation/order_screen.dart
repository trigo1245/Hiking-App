import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../auth/data/profile_remote.dart';
import '../../auth/domain/profile_rules.dart';
import '../data/shop_remote.dart';
import '../domain/shop.dart';
import 'shop_widgets.dart';

/// 주문서로 넘기는 값: 고른 상품과 옵션
class OrderDraft {
  const OrderDraft({required this.product, this.option});

  final Product product;
  final String? option;
}

/// 주문서: 상품·옵션·수량, 배송지(개인정보), 결제 수단(시연용), 최종 금액 → "N원 결제하기"
class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key, required this.draft});

  final OrderDraft draft;

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  int _quantity = 1;
  bool _busy = false;

  Product get _product => widget.draft.product;
  int get _total => _product.price * _quantity;

  Future<void> _pay() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(shopRemoteProvider)
          .placeOrder(
            _product.id,
            option: widget.draft.option,
            quantity: _quantity,
          );
      ref.invalidate(myOrdersProvider);
      if (!mounted) return;
      // 주문서는 닫고 완료 화면을 띄운다 (뒤로 가면 상품 상세).
      context.pushReplacement(
        AppRoutes.orderDone,
        extra: OrderDone(productName: _product.name, total: _total),
      );
    } catch (e) {
      debugPrint('[shop] $e');
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(errorMessage(e, failed: '결제하지 못했어요'))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(myPrivateInfoProvider);
    final option = widget.draft.option;
    return Scaffold(
      appBar: AppBar(title: const Text('주문서')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.lg,
        ),
        children: [
          const Text('주문 상품', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              ProductArt(category: _product.category, art: _product.art),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_product.name, style: AppTypography.body),
                    if (option != null)
                      Text(
                        '${_product.optionName} $option',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    Text(
                      formatPrice(_product.price),
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Expanded(child: Text('수량', style: AppTypography.body)),
              _QuantityStepper(
                value: _quantity,
                onChanged: _busy ? null : (v) => setState(() => _quantity = v),
              ),
            ],
          ),
          const _Divider(),
          Row(
            children: [
              const Expanded(child: Text('배송지', style: AppTypography.subtitle)),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await context.push<bool>(AppRoutes.privateInfo);
                        ref.invalidate(myPrivateInfoProvider);
                      },
                child: const Text('바꾸기'),
              ),
            ],
          ),
          switch (info) {
            AsyncValue(:final value?) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${value.name ?? ''} · ${formatPhone(value.phone ?? '')}',
                  style: AppTypography.body,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (value.postcode != null) '(${value.postcode})',
                    value.address ?? '',
                    value.addressDetail ?? '',
                  ].where((s) => s.isNotEmpty).join(' '),
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            AsyncValue(:final error?) => Text(
              errorMessage(error, failed: '배송지를 불러오지 못했어요'),
              style: AppTypography.body.copyWith(color: AppColors.danger),
            ),
            _ => const SkeletonBox(width: double.infinity, height: 44),
          },
          const _Divider(),
          const Text('결제 수단', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.backgroundGrouped,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Row(
              children: [
                const Icon(Icons.credit_card_rounded, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '시연용 결제 (실제로 결제되지 않아요)',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _Divider(),
          _PriceRow(label: '상품 금액', value: formatPrice(_total)),
          const _PriceRow(label: '배송비', value: '무료'),
          const SizedBox(height: AppSpacing.sm),
          _PriceRow(
            label: '최종 결제 금액',
            value: formatPrice(_total),
            strong: true,
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: _busy ? '결제하는 중…' : '${formatPrice(_total)} 결제하기',
          onPressed: _busy || !info.hasValue ? null : _pay,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Divider(height: 1, color: AppColors.divider),
  );
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? AppTypography.subtitle
        : AppTypography.body.copyWith(color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: strong ? style.copyWith(color: AppColors.primary) : style,
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String label, int? next) => Pressable(
      onPressed: next == null || onChanged == null
          ? null
          : () => onChanged!(next),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.backgroundGrouped,
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        child: Icon(
          icon,
          size: 20,
          semanticLabel: label,
          color: next == null ? AppColors.textTertiary : AppColors.textPrimary,
        ),
      ),
    );
    return Row(
      children: [
        button(Icons.remove_rounded, '수량 줄이기', value > 1 ? value - 1 : null),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppTypography.subtitle,
          ),
        ),
        button(
          Icons.add_rounded,
          '수량 늘리기',
          value < maxOrderQuantity ? value + 1 : null,
        ),
      ],
    );
  }
}

/// 주문 완료 화면으로 넘기는 값
class OrderDone {
  const OrderDone({required this.productName, required this.total});

  final String productName;
  final int total;
}

/// 주문 완료: 시연용 결제 안내, 주문 내역 / 쇼핑 계속하기
class OrderDoneScreen extends StatelessWidget {
  const OrderDoneScreen({super.key, required this.done});

  final OrderDone done;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 72,
              color: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('주문했어요', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${done.productName} · ${formatPrice(done.total)}',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '시연용 결제라 실제로 결제되지 않았어요.\n'
              '2분쯤 지나면 배송 완료로 바뀌고, 그때 리뷰를 쓸 수 있어요.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: '주문 내역 보기',
              onPressed: () => context.pushReplacement(AppRoutes.orders),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: '쇼핑 계속하기',
              variant: AppButtonVariant.secondary,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}
