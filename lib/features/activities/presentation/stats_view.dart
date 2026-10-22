import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/metric_text.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../courses/data/course_repository.dart';
import '../../courses/domain/course.dart';
import '../../subscription/data/subscription_remote.dart';
import '../domain/activity_summary.dart';
import '../domain/hiking_stats.dart';
import 'stats_charts.dart';
import 'stats_providers.dart';

/// 기록 탭의 "통계": 지금까지의 산행을 종합한다. 구독자는 종합 분석을 더 본다.
class StatsView extends ConsumerStatefulWidget {
  const StatsView({super.key, required this.activities});

  final List<ActivitySummary> activities;

  @override
  ConsumerState<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends ConsumerState<StatsView> {
  StatsPeriod _period = StatsPeriod.season;

  @override
  Widget build(BuildContext context) {
    final now = ref.read(clockProvider)();
    final completions = ref.watch(myCompletionsProvider);
    final stats = HikingStats.of(
      activities: widget.activities,
      completions: completions.value,
      period: _period,
      now: now,
    );
    final premium = ref.watch(isPremiumProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        AppSpacing.xxl,
      ),
      children: [
        SegmentedTabs<StatsPeriod>(
          options: const {
            StatsPeriod.season: '이번 시즌',
            StatsPeriod.year: '올해',
            StatsPeriod.all: '전체',
          },
          selected: _period,
          onChanged: (p) => setState(() => _period = p),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: MetricText(
                label: '등산',
                value: '${stats.hikeCount}',
                unit: '번',
              ),
            ),
            Expanded(
              child: MetricText(
                label: '완등',
                value: switch (completions) {
                  AsyncData() => '${stats.completionCount ?? '-'}',
                  _ => '-',
                },
                unit: '번',
              ),
            ),
          ],
        ),
        if (completions.hasValue && completions.value == null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '완등 횟수는 인터넷에 연결되면 볼 수 있어요',
              style: AppTypography.caption,
            ),
          ),
        const SizedBox(height: AppSpacing.xxxl),
        _Section(
          title: '등반 주기',
          child: _Rhythm(stats: stats),
        ),
        _Section(
          title: '누적',
          child: _Totals(stats: stats),
        ),
        _Section(
          title: '월별 등산 횟수',
          child: MonthlyBarChart(months: stats.monthly),
        ),
        _Section(
          title: '자주 간 코스',
          child: _CourseList(
            records: stats.topCourses,
            loading: completions.isLoading,
            offline: completions.hasValue && completions.value == null,
          ),
        ),
        if (premium)
          _PremiumStatsSection(period: _period)
        else
          const _PremiumStatsTeaser(),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// 회색 카드 안의 문장 여러 줄
class _Lines extends StatelessWidget {
  const _Lines(this.lines);

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(line, style: AppTypography.body),
            ),
        ],
      ),
    );
  }
}

class _Rhythm extends StatelessWidget {
  const _Rhythm({required this.stats});

  final HikingStats stats;

  @override
  Widget build(BuildContext context) {
    final interval = stats.averageIntervalDays;
    final since = stats.daysSinceLast;
    return _Lines([
      if (interval == null)
        '산행이 2번 이상 쌓이면 주기를 알려 드려요'
      else
        '평균 ${interval < 1 ? '하루에 한 번 이상' : '${interval.round()}일마다'} 등산해요',
      if (since != null) since == 0 ? '오늘 등산했어요' : '마지막 산행 후 $since일 지났어요',
      if (stats.weekStreak > 0) '${stats.weekStreak}주 연속 등산 중이에요',
    ]);
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.stats});

  final HikingStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: MetricText(
                label: '거리',
                value: formatKm(stats.distanceM),
                unit: 'km',
                valueStyle: AppTypography.subtitle,
              ),
            ),
            Expanded(
              child: MetricText(
                label: '오른 높이',
                value: formatMeters(stats.elevationGainM),
                unit: 'm',
                valueStyle: AppTypography.subtitle,
              ),
            ),
            Expanded(
              child: MetricText(
                label: '시간',
                value: formatHoursMinutes(stats.elapsed),
                unit: '',
                valueStyle: AppTypography.subtitle,
              ),
            ),
          ],
        ),
        if (stats.elevationGainM > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            '에베레스트(8,849m) 높이의 '
            '${stats.everestRatio.toStringAsFixed(stats.everestRatio < 1 ? 2 : 1)}배를 올랐어요',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// 코스 이름과 완주 횟수·최고 기록
class _CourseList extends ConsumerWidget {
  const _CourseList({
    required this.records,
    required this.loading,
    required this.offline,
  });

  final List<CourseRecord> records;
  final bool loading;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading) return const SkeletonBox(width: double.infinity, height: 56);
    if (offline) return const _Lines(['인터넷에 연결되면 볼 수 있어요']);
    if (records.isEmpty) return const _Lines(['아직 완주한 코스가 없어요']);
    final courses = ref.watch(coursesProvider).value ?? const <Course>[];
    String name(String id) =>
        courses.where((c) => c.id == id).firstOrNull?.fullName ?? '삭제된 코스';
    return Column(
      children: [
        for (final r in records)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name(r.courseId),
                    style: AppTypography.body,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${r.count}번 · 최고 ${formatClock(r.best)}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _percent(double v) => '${(v * 100).round()}%';

/// 구독자 종합 분석 (기획서 6.4 "성장 추적" 등)
class _PremiumStatsSection extends ConsumerWidget {
  const _PremiumStatsSection({required this.period});

  final StatsPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyses = ref.watch(myAnalysesProvider);
    final completions = ref.watch(myCompletionsProvider);
    final hikes = analyses.value;
    if (hikes == null) {
      return const SkeletonBox(width: double.infinity, height: 200);
    }
    final p = PremiumStats.of(
      hikes: hikes,
      completions: completions.value,
      period: period,
      now: ref.read(clockProvider)(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '프리미엄 종합 분석',
          style: AppTypography.caption.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Section(
          title: '체력 추이',
          child: p.efficiencyTrend.length < 2
              ? const _Lines(['산행이 2번 이상 쌓이면 추이를 보여 드려요'])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '경사를 보정한 속도를 표준 등산객(Tobler 공식)과 비교했어요',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TrendLineChart(
                      points: p.efficiencyTrend,
                      reference: 1,
                      referenceLabel: '표준',
                      format: (v) => '표준의 ${_percent(v)}',
                    ),
                  ],
                ),
        ),
        _Section(
          title: '피로도 추이',
          child: p.fatigueTrend.length < 2
              ? const _Lines(['오르막이 있는 산행이 2번 이상 쌓이면 보여 드려요'])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '후반 오르막 속도를 전반과 비교했어요. 높을수록 끝까지 힘이 남아 있었어요',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TrendLineChart(
                      points: p.fatigueTrend,
                      reference: 1,
                      referenceLabel: '전반과 같음',
                      format: (v) => '후반 ${_percent(v)}',
                    ),
                  ],
                ),
        ),
        _Section(
          title: '오르막형? 내리막형?',
          child: _Lines(switch (p.climbStyle) {
            null => ['오르막과 내리막 기록이 쌓이면 알려 드려요'],
            final style => [
              switch (style) {
                ClimbStyle.uphill => '오르막에 강한 오르막형이에요',
                ClimbStyle.downhill => '내리막에 강한 내리막형이에요',
                ClimbStyle.balanced => '오르막과 내리막이 고른 균형형이에요',
              },
              '오르막 표준의 ${_percent(p.uphillEfficiency!)} · '
                  '내리막 표준의 ${_percent(p.downhillEfficiency!)}',
            ],
          }),
        ),
        _Section(
          title: '휴식 패턴',
          child: _Lines([
            if (p.walkMinutesPerRest case final m?)
              '평균 ${m.round()}분 걷고 한 번 쉬어요'
            else
              '아직 쉬어 간 기록이 없어요',
            if (p.restRatio case final r?) '전체 시간의 ${_percent(r)}가 휴식이에요',
          ]),
        ),
        _Section(
          title: '급경사 내리막 습관',
          child: _SteepHabit(ratio: p.steepDownhillRatio),
        ),
        _Section(
          title: '코스별 내 최고 기록',
          child: _CourseList(
            records: p.courseBests,
            loading: completions.isLoading,
            offline: completions.hasValue && completions.value == null,
          ),
        ),
      ],
    );
  }
}

class _SteepHabit extends StatelessWidget {
  const _SteepHabit({required this.ratio});

  final double? ratio;

  @override
  Widget build(BuildContext context) {
    final r = ratio;
    if (r == null) return const _Lines(['급경사 내리막을 지난 기록이 아직 없어요']);
    final warn = r > PremiumStats.steepDownhillWarn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태 색은 아이콘과 함께 쓴다 (색만으로 구분하지 않기).
          Icon(
            warn ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            color: warn ? AppColors.danger : AppColors.success,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              warn
                  ? '급경사 내리막에서 평소 내리막보다 ${((r - 1) * 100).round()}% 빨라지는 편이에요. '
                        '미끄러지지 않게 천천히 내려오세요.'
                  : '급경사 내리막에서 속도를 잘 조절하고 있어요.',
              style: AppTypography.body,
            ),
          ),
        ],
      ),
    );
  }
}

/// 일반 사용자에게 보이는 종합 분석 안내
class _PremiumStatsTeaser extends StatelessWidget {
  const _PremiumStatsTeaser();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('내 산행을 종합해서 분석해 보세요', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.sm),
          for (final line in const [
            '체력 추이와 피로도 추이',
            '오르막형·내리막형',
            '휴식 패턴과 급경사 내리막 습관',
            '코스별 내 최고 기록',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '· $line',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: '프리미엄 알아보기',
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(AppRoutes.premium),
          ),
        ],
      ),
    );
  }
}
