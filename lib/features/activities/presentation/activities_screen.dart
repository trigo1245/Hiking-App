import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/metric_text.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../domain/activity_summary.dart';
import 'activities_providers.dart';

/// 기록 탭: 이번 달 요약과 날짜 역순 기록 카드, 업로드 상태.
class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(myActivitiesProvider);
    final now = ref.read(clockProvider)();

    return Scaffold(
      appBar: AppBar(title: const Text('기록')),
      body: switch (activities) {
        AsyncData(:final value) when value.isEmpty => const _EmptyState(),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.xxl,
          ),
          children: [
            _MonthSummaryView(summary: MonthSummary.of(value, now)),
            const SizedBox(height: AppSpacing.xxl),
            for (final activity in value) ...[
              _ActivityCard(activity: activity),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
        _ => const _LoadingSkeleton(),
      },
    );
  }
}

class _MonthSummaryView extends StatelessWidget {
  const _MonthSummaryView({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('이번 달', style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: MetricText(
                label: '횟수',
                value: '${summary.count}',
                unit: '번',
              ),
            ),
            Expanded(
              child: MetricText(
                label: '거리',
                value: formatKm(summary.distanceM),
                unit: 'km',
              ),
            ),
            Expanded(
              child: MetricText(
                label: '시간',
                value: formatHoursMinutes(summary.elapsed),
                unit: '',
                valueStyle: AppTypography.subtitle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard({required this.activity});

  final ActivitySummary activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 카드를 누르면 기록 상세가 열린다.
    return Pressable(
      onPressed: () => context.push(AppRoutes.activity(activity.id)),
      child: _card(ref),
    );
  }

  Widget _card(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  activity.title,
                  style: AppTypography.subtitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _UploadBadge(status: activity.uploadStatus),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatDateTime(activity.startedAt),
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${formatKm(activity.distanceM)} km  ·  '
            '${formatClock(activity.elapsed)}  ·  '
            '오른 높이 ${formatMeters(activity.elevationGainM)} m',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          if (activity.uploadStatus == UploadStatus.failed) ...[
            const SizedBox(height: AppSpacing.md),
            Pressable(
              onPressed: () =>
                  ref.read(uploadActionsProvider).upload(activity.id),
              child: Text(
                '업로드에 실패했어요. 다시 시도할까요?',
                style: AppTypography.body.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadBadge extends StatelessWidget {
  const _UploadBadge({required this.status});

  final UploadStatus status;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (status) {
      UploadStatus.pending => ('업로드 대기', AppColors.textTertiary),
      UploadStatus.done => ('업로드 완료', AppColors.success),
      UploadStatus.failed => ('업로드 실패', AppColors.danger),
    };
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('아직 등산 기록이 없어요', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '홈에서 "등산 기록 시작"을 눌러 첫 기록을 남겨 보세요',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      children: const [
        SkeletonBox(width: 120, height: 24),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(width: double.infinity, height: 56),
        SizedBox(height: AppSpacing.xxl),
        SkeletonBox(width: double.infinity, height: 120),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(width: double.infinity, height: 120),
      ],
    );
  }
}
