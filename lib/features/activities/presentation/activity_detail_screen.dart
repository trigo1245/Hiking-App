import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/map/route_preview_map.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/metric_text.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../subscription/data/subscription_remote.dart';
import '../../subscription/domain/subscription.dart';
import '../data/gpx_sharer.dart';
import '../../courses/domain/course.dart';
import '../../courses/presentation/competition_providers.dart';
import '../domain/activity_analysis.dart';
import '../domain/activity_deletion.dart';
import '../domain/activity_summary.dart';
import '../domain/gpx_writer.dart';
import 'activities_providers.dart';
import 'activity_detail_providers.dart';
import 'delete_activity_sheet.dart';
import 'elevation_chart.dart';

/// 기록 상세: 지도 위 내 경로, 수치 전체, 완주한 코스, GPX 내보내기, 다시 올리기.
/// 프리미엄이면 상세 분석(고도 그래프, 구간별 페이스, km별 기록, 전반·후반, 같은 코스 비교)을 더 보여 준다.
class ActivityDetailScreen extends ConsumerWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  Future<void> _shareGpx(WidgetRef ref, ActivityDetail detail) async {
    final date = detail.summary.startedAt;
    final name =
        'hike_${date.year}${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}.gpx';
    await ref
        .read(gpxSharerProvider)
        .share(
          fileName: name,
          gpx: buildGpx(title: detail.summary.title, points: detail.points),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(activityDetailProvider(activityId));
    final premium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.summary.title ?? '기록')),
      body: switch (detail) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              formatDateTime(value.summary.startedAt),
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _TrackMap(detail: value),
            const SizedBox(height: AppSpacing.xxl),
            _Metrics(summary: value.summary),
            const SizedBox(height: AppSpacing.xxxl),
            _Completions(detail: value),
            const SizedBox(height: AppSpacing.xxxl),
            if (premium)
              _PremiumAnalysis(detail: value)
            else
              const _PremiumTeaser(),
            const SizedBox(height: AppSpacing.xxxl),
            _UploadRow(summary: value.summary),
            const SizedBox(height: AppSpacing.xl),
            _DeleteRow(detail: value),
          ],
        ),
        AsyncError() => const Center(
          child: Text('기록을 불러오지 못했어요', style: AppTypography.body),
        ),
        _ => const Padding(
          padding: EdgeInsets.all(AppSpacing.screenHorizontal),
          child: SkeletonBox(width: double.infinity, height: 220),
        ),
      },
      bottomNavigationBar: detail.value == null
          ? null
          : BottomActionBar(
              child: AppButton(
                label: 'GPX 내보내기',
                onPressed: () => _shareGpx(ref, detail.value!),
              ),
            ),
    );
  }
}

/// 지도 위 내 경로 (기기에 저장한 실제 GPS 점). 출발점은 채운 점, 도착점은 빈 점.
class _TrackMap extends StatelessWidget {
  const _TrackMap({required this.detail});

  final ActivityDetail detail;

  @override
  Widget build(BuildContext context) {
    final points = [
      for (final p in detail.points) LatLng(p.latitude, p.longitude),
    ];
    if (points.length < 2) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.backgroundGrouped,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: const Text('경로가 없는 기록이에요', style: AppTypography.caption),
      );
    }
    return RoutePreviewMap(
      points: points,
      markers: [
        Marker(
          point: points.first,
          width: 16,
          height: 16,
          child: const _Dot(filled: true),
        ),
        Marker(
          point: points.last,
          width: 16,
          height: 16,
          child: const _Dot(filled: false),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: filled ? AppColors.primary : AppColors.background,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 3),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.summary});

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final movingH = summary.moving.inSeconds / 3600;
    final speed = movingH == 0 ? 0.0 : summary.distanceM / 1000 / movingH;
    Widget cell(String label, String value, String unit) => Expanded(
      child: MetricText(label: label, value: value, unit: unit),
    );
    return Column(
      children: [
        Row(
          children: [
            cell('거리', formatKm(summary.distanceM), 'km'),
            cell('오른 높이', formatMeters(summary.elevationGainM), 'm'),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            cell('전체 시간', formatClock(summary.elapsed), ''),
            cell('움직인 시간', formatClock(summary.moving), ''),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            cell('최고 고도', formatMeters(summary.maxAltitudeM), 'm'),
            cell('평균 속도', speed.toStringAsFixed(1), 'km/h'),
          ],
        ),
      ],
    );
  }
}

class _Completions extends StatelessWidget {
  const _Completions({required this.detail});

  final ActivityDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('다녀온 코스', style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.md),
        if (detail.summary.isFlagged)
          Text(
            '이동 속도가 비정상적으로 빠른 구간이 있어 완주로 인정하지 않았어요.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          )
        else if (detail.completions.isEmpty && detail.attempts.isEmpty)
          Text(
            '등록된 코스와 일치하지 않아 개인 기록으로만 저장됐어요.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          )
        else ...[
          for (final (course, progress) in detail.attempts)
            _AttemptCard(course: course, progress: progress.progress),
          for (final (course, result) in detail.completions)
            Pressable(
              onPressed: () => context.push(AppRoutes.course(course.id)),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGrouped,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.fullName, style: AppTypography.body),
                          Text(
                            '등정 ${formatClock(result.ascent)}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// 정상까지 가지 않은 코스: 몇 %까지 갔는지 막대로 보여 준다.
class _AttemptCard extends StatelessWidget {
  const _AttemptCard({required this.course, required this.progress});

  final Course course;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    return Pressable(
      onPressed: () => context.push(AppRoutes.course(course.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.backgroundGrouped,
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(course.fullName, style: AppTypography.body),
                ),
                Text(
                  '$percent%까지',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  Container(
                    height: AppSpacing.sm,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                    ),
                  ),
                  Container(
                    width: c.maxWidth * progress,
                    height: AppSpacing.sm,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '정상 전에 돌아섰어요. 무리하지 않은 것도 좋은 판단이에요.',
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// 일반 사용자에게 보이는 프리미엄 안내
class _PremiumTeaser extends StatelessWidget {
  const _PremiumTeaser();

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
          const Text('더 자세한 분석이 궁금하다면', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.sm),
          for (final (title, _) in premiumBenefits.skip(1).take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '· $title',
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

/// 프리미엄 상세 분석 (기획서 6.4)
class _PremiumAnalysis extends ConsumerWidget {
  const _PremiumAnalysis({required this.detail});

  final ActivityDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(activityAnalysisProvider(detail.summary.id));
    final a = analysis.value;
    if (a == null) {
      return const SkeletonBox(width: double.infinity, height: 200);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('상세 분석', style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.lg),
        const Text('시간에 따른 고도', style: AppTypography.caption),
        const SizedBox(height: AppSpacing.xs),
        ElevationChart(
          samples: a.elevationProfile,
          total: a.totalDuration,
          rests: a.rests,
          dangers: a.dangers,
        ),
        if (a.rests.isNotEmpty || a.dangers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            [
              if (a.rests.isNotEmpty)
                '휴식 ${a.rests.length}번 · 총 ${formatHoursMinutes(a.restDuration)}',
              if (a.dangers.isNotEmpty) '경사 30% 이상 위험 구간 ${a.dangers.length}곳',
            ].join('\n'),
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        const Text('경사 보정 페이스', style: AppTypography.caption),
        const SizedBox(height: AppSpacing.xs),
        if (a.gradeAdjustedPace case final pace?) ...[
          Text('평지 환산 ${formatPace(pace)} /km', style: AppTypography.subtitle),
          Text(
            '표준 등산객(Tobler 공식)의 ${((a.efficiency ?? 0) * 100).round()}% 속도로 걸었어요',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Row(
          children: [
            for (final (kind, label) in const [
              (GradeKind.uphill, '오르막'),
              (GradeKind.flat, '평지'),
              (GradeKind.downhill, '내리막'),
            ])
              Expanded(
                child: _GradeTile(label: label, summary: a.grade(kind)),
              ),
          ],
        ),
        if (a.fatigue case final f?) ...[
          const SizedBox(height: AppSpacing.xxl),
          const Text('전반·후반 오르막 속도', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '전반 ${f.firstHalfClimbRate.round()} m/h → '
            '후반 ${f.secondHalfClimbRate.round()} m/h',
            style: AppTypography.subtitle,
          ),
          Text(
            f.ratio >= 0.9
                ? '끝까지 페이스를 잘 유지했어요'
                : '후반에 오르막 속도가 ${((1 - f.ratio) * 100).round()}% 느려졌어요',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (a.splits.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          const Text('km별 기록', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.sm),
          _Splits(splits: a.splits),
        ],
        for (final (course, _) in detail.completions) ...[
          const SizedBox(height: AppSpacing.xxl),
          _CourseHistory(
            courseId: course.id,
            title: course.fullName,
            currentId: detail.summary.id,
          ),
        ],
      ],
    );
  }
}

class _GradeTile extends StatelessWidget {
  const _GradeTile({required this.label, required this.summary});

  final String label;
  final GradeSummary summary;

  /// 오르막·평지·내리막의 경사 보정 페이스(평지 환산)와 실제 속도
  @override
  Widget build(BuildContext context) {
    final pace = summary.gradeAdjustedPace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: pace == null ? '-' : formatPace(pace),
                style: AppTypography.subtitle,
              ),
              TextSpan(text: ' /km', style: AppTypography.caption),
            ],
          ),
        ),
        Text(
          // 좁은 칸에서 단위만 줄바꿈되지 않게 두 줄로 나눈다.
          '실제 ${summary.speedKmh.toStringAsFixed(1)} km/h\n'
          '${formatKm(summary.distanceM)} km',
          style: AppTypography.caption,
        ),
      ],
    );
  }
}

/// km별 기록: 걸린 시간을 한 가지 색 막대로 비교한다.
class _Splits extends StatelessWidget {
  const _Splits({required this.splits});

  final List<KmSplit> splits;

  @override
  Widget build(BuildContext context) {
    final longest = splits
        .map((s) => s.duration.inSeconds)
        .reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final s in splits)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text('${s.km} km', style: AppTypography.caption),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: c.maxWidth * s.duration.inSeconds / longest,
                        height: AppSpacing.sm,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppSpacing.xs),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    '${formatClock(s.duration)} · ↑${s.gainM.round()} m',
                    textAlign: TextAlign.right,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 같은 코스를 완주한 내 기록 회차별 비교
class _CourseHistory extends ConsumerWidget {
  const _CourseHistory({
    required this.courseId,
    required this.title,
    required this.currentId,
  });

  final String courseId;
  final String title;
  final String currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attempts = ref.watch(myCourseAttemptsProvider(courseId)).value;
    if (attempts == null) return const SizedBox.shrink();
    final best = attempts.isEmpty
        ? null
        : attempts.reduce((a, b) => a.ascent <= b.ascent ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title 내 기록', style: AppTypography.caption),
        const SizedBox(height: AppSpacing.sm),
        for (final (i, at) in attempts.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text('${i + 1}회', style: AppTypography.caption),
                ),
                Expanded(
                  child: Text(
                    '${at.date.month}월 ${at.date.day}일'
                    '${at.activityId == currentId ? ' (이번 기록)' : ''}',
                    style: AppTypography.body,
                  ),
                ),
                Text(
                  formatClock(at.ascent),
                  style: AppTypography.body.copyWith(
                    fontWeight: at == best ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (at == best)
                  Text(
                    '  최고',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _UploadRow extends ConsumerWidget {
  const _UploadRow({required this.summary});

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = switch (summary.uploadStatus) {
      UploadStatus.done => '서버에 올라가 있어요',
      UploadStatus.pending => '인터넷에 연결되면 올릴게요',
      UploadStatus.failed => '업로드에 실패했어요',
    };
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Pressable(
          onPressed: () async {
            final ok = await ref
                .read(uploadActionsProvider)
                .upload(summary.id, force: true);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(ok ? '다시 올렸어요' : '올리지 못했어요. 인터넷 연결을 확인해 주세요'),
                ),
              );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              '다시 올리기',
              style: AppTypography.body.copyWith(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// 잘못 기록된 산행을 지운다. 주의사항을 확인하고 한 번 더 눌러야 지워진다.
/// 서버에서 먼저 지우고, 성공해야 이 기기에서도 지운다. (인터넷이 없으면 지우지 않는다)
class _DeleteRow extends ConsumerStatefulWidget {
  const _DeleteRow({required this.detail});

  final ActivityDetail detail;

  @override
  ConsumerState<_DeleteRow> createState() => _DeleteRowState();
}

class _DeleteRowState extends ConsumerState<_DeleteRow> {
  bool _busy = false;

  Future<void> _delete() async {
    final detail = widget.detail;
    final confirmed = await showDeleteActivitySheet(
      context,
      title: detail.summary.title,
      notices: deletionNotices(
        summary: detail.summary,
        completedCourses: [for (final (c, _) in detail.completions) c.fullName],
        attemptedCourses: [
          for (final (c, p) in detail.attempts) (c.fullName, p.progress),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final id = detail.summary.id;
    final actions = ref.read(uploadActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    setState(() => _busy = true);
    try {
      await actions.deleteFromServer(id);
    } catch (e) {
      debugPrint('[delete] $e');
      if (mounted) setState(() => _busy = false);
      say('지우지 못했어요. 인터넷에 연결된 뒤 다시 시도해 주세요');
      return;
    }
    // 완주 기록이 지워졌으니 지도의 정복자를 다시 받는다.
    ref.invalidate(conquerorsProvider);
    if (mounted) context.pop();
    await actions.deleteFromDevice(id);
    say('기록을 지웠어요');
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Pressable(
        onPressed: _busy ? null : _delete,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(
            _busy ? '지우는 중…' : '이 기록 지우기',
            style: AppTypography.body.copyWith(color: AppColors.danger),
          ),
        ),
      ),
    );
  }
}
