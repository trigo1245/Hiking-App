import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../data/subscription_remote.dart';
import '../domain/subscription.dart';

/// 프리미엄 구독 화면. 결제는 시연용이라 실제로 돈이 나가지 않는다.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _busy = false;

  Future<void> _run({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function(SubscriptionRemote) action,
    required String done,
  }) async {
    if (_busy) return;
    final ok = await showConfirmSheet(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: '닫기',
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(subscriptionRemoteProvider));
      ref.invalidate(mySubscriptionProvider);
      if (mounted) _snack(done);
    } catch (e) {
      debugPrint('[premium] $e');
      if (mounted) _snack('처리하지 못했어요. 인터넷 연결을 확인해 주세요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(mySubscriptionProvider);
    final active = subscription.value?.isActive ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('프리미엄')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            active ? '프리미엄을 이용하고 있어요' : '내 산행을 더 깊이 알아보세요',
            style: AppTypography.title,
          ),
          const SizedBox(height: AppSpacing.xs),
          switch (subscription) {
            AsyncData(:final value) when value != null && value.isActive =>
              Text(
                '${_date(value.expiresAt)}까지 이용할 수 있어요',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            AsyncLoading() => const SkeletonBox(width: 160, height: 20),
            AsyncError() => Text(
              '구독 상태를 불러오지 못했어요',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            _ => Text(
              premiumPriceLabel,
              style: AppTypography.subtitle.copyWith(color: AppColors.primary),
            ),
          },
          const SizedBox(height: AppSpacing.xxl),
          for (final (title, description) in premiumBenefits)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(description, style: AppTypography.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.backgroundGrouped,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Text(
              '시연용 결제예요. 실제로 결제되지 않고, 해지하면 남은 기간과 상관없이 바로 끝나요.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: active
            ? AppButton(
                label: '구독 해지',
                variant: AppButtonVariant.secondary,
                onPressed: _busy
                    ? null
                    : () => _run(
                        title: '프리미엄을 해지할까요?',
                        message: '해지하면 바로 일반 사용자로 바뀌어요.',
                        confirmLabel: '해지하기',
                        action: (r) => r.cancel(),
                        done: '프리미엄을 해지했어요',
                      ),
              )
            : AppButton(
                label: '$premiumPriceLabel 구독하기',
                onPressed: _busy || subscription.isLoading
                    ? null
                    : () => _run(
                        title: '프리미엄을 구독할까요?',
                        message: '$premiumPriceLabel · 시연용 결제라 실제로 돈이 나가지 않아요.',
                        confirmLabel: '결제하기',
                        action: (r) => r.startDemo(),
                        done: '프리미엄을 시작했어요',
                      ),
              ),
      ),
    );
  }

  static String _date(DateTime t) {
    final local = t.toLocal();
    return '${local.year}년 ${local.month}월 ${local.day}일';
  }
}
