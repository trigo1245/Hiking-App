import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../clubs/presentation/club_format.dart';
import '../../subscription/data/subscription_remote.dart';
import '../data/mileage_remote.dart';
import '../domain/mileage.dart';

/// 마일리지 (내 정보에서 진입): 잔액, 프리미엄 교환권, 적립 방법, 적립·사용 내역
class MileageScreen extends ConsumerStatefulWidget {
  const MileageScreen({super.key});

  @override
  ConsumerState<MileageScreen> createState() => _MileageScreenState();
}

class _MileageScreenState extends ConsumerState<MileageScreen> {
  bool _busy = false;

  void _refresh() => ref
    ..invalidate(mileageSummaryProvider)
    ..invalidate(mileageHistoryProvider);

  Future<void> _redeem(MileageReward reward, MileageSummary summary) async {
    if (_busy) return;
    final ok = await showConfirmSheet(
      context,
      title: '${reward.label}으로 바꿀까요?',
      message:
          '${formatMileage(reward.cost)} 마일리지를 쓰고 프리미엄을 ${reward.days}일 받아요. '
          '구독 중이면 끝나는 날이 ${reward.days}일 늘어나요. '
          '바꾼 마일리지는 되돌릴 수 없어요.',
      confirmLabel: '교환하기',
      cancelLabel: '취소',
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final expires = await ref.read(mileageRemoteProvider).redeem(reward);
      _refresh();
      ref.invalidate(mySubscriptionProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '프리미엄을 ${expires.month}월 ${expires.day}일까지 이용할 수 있어요',
            ),
          ),
        );
    } catch (e) {
      debugPrint('[mileage] $e');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(errorMessage(e, failed: '교환하지 못했어요'))),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(mileageSummaryProvider);
    final history = ref.watch(mileageHistoryProvider);
    final value = summary.value;
    return Scaffold(
      appBar: AppBar(title: const Text('마일리지')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.lg,
          ),
          children: [
            switch (summary) {
              AsyncValue(:final value?) => _Balance(summary: value),
              AsyncValue(:final error?) => TextButton(
                onPressed: _refresh,
                child: Text(
                  '${errorMessage(error, failed: '마일리지를 불러오지 못했어요')}\n눌러서 다시 시도',
                  textAlign: TextAlign.center,
                ),
              ),
              _ => const SkeletonBox(width: double.infinity, height: 96),
            },
            const SizedBox(height: AppSpacing.xxl),
            const Text('프리미엄 교환권', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '마일리지는 프리미엄 교환권으로만 바꿀 수 있어요',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final reward in MileageReward.values)
              _RewardCard(
                reward: reward,
                balance: value?.balance,
                onRedeem: _busy || value == null
                    ? null
                    : () => _redeem(reward, value),
              ),
            const SizedBox(height: AppSpacing.xxl),
            _Rules(premium: value?.premium ?? false),
            const SizedBox(height: AppSpacing.xxl),
            const Text('적립·사용 내역', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.sm),
            ...switch (history) {
              AsyncValue(:final value?) when value.isEmpty => [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    '아직 내역이 없어요. 산행을 기록하면 마일리지가 쌓여요',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
              AsyncValue(:final value?) => [
                for (final e in value) _EntryRow(entry: e),
              ],
              AsyncValue(:final error?) => [
                Text(errorMessage(error, failed: '내역을 불러오지 못했어요')),
              ],
              _ => [const SkeletonBox(width: double.infinity, height: 120)],
            },
          ],
        ),
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.summary});

  final MileageSummary summary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      color: AppColors.backgroundGrouped,
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '내 마일리지',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: formatMileage(summary.balance),
                style: AppTypography.display,
              ),
              TextSpan(
                text: ' 마일리지',
                style: AppTypography.body.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '오늘 ${formatMileage(summary.earnedToday)} / ${formatMileage(summary.dailyCap)} 적립'
          '${summary.premium ? ' · 프리미엄 1.5배 적립 중' : ''}',
          style: AppTypography.caption.copyWith(
            color: summary.premium ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
      ],
    ),
  );
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.balance,
    required this.onRedeem,
  });

  final MileageReward reward;
  final int? balance;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    final short = balance == null ? null : reward.cost - balance!;
    final enough = short != null && short <= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.label,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  enough || short == null
                      ? '${formatMileage(reward.cost)} 마일리지'
                      : '${formatMileage(reward.cost)} 마일리지 · ${formatMileage(short)} 더 모으면 돼요',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Pressable(
            onPressed: enough ? onRedeem : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: enough && onRedeem != null
                    ? AppColors.primary
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Text(
                '교환하기',
                style: AppTypography.caption.copyWith(
                  color: enough && onRedeem != null
                      ? AppColors.onPrimary
                      : AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules({required this.premium});

  final bool premium;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('적립 방법', style: AppTypography.subtitle),
      const SizedBox(height: AppSpacing.xs),
      Text(
        premium
            ? '프리미엄이라 1.5배로 받아요 · 하루 최대 ${formatMileage((mileageDailyCap * mileagePremiumRate).round())}'
            : '프리미엄은 1.5배로 받아요 · 하루 최대 ${formatMileage(mileageDailyCap)}',
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final rule in MileageRule.all)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rule.title, style: AppTypography.body),
                    Text(
                      rule.note,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '+${rule.amountFor(premium: premium)}',
                style: AppTypography.body.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        '같은 일로는 처음 1번만 받아요. 기록·리뷰를 지웠다 다시 써도 다시 받지 않고, 받은 마일리지는 그대로 남아요. '
        '속도 이상 기록은 적립되지 않아요.',
        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
      ),
    ],
  );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final MileageEntry entry;

  @override
  Widget build(BuildContext context) {
    final plus = entry.amount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body,
                ),
                Text(
                  formatShortDate(entry.createdAt),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${plus ? '+' : ''}${formatMileage(entry.amount)}',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: plus ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
