import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';

import '../../../core/design/design.dart';
import '../../../core/map/map_tiles.dart';
import '../../../core/map/route_preview_map.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/metric_text.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../recording/presentation/start_recording.dart';
import '../../subscription/data/subscription_remote.dart';
import '../data/course_repository.dart';
import '../data/review_remote.dart';
import '../domain/competition.dart';
import '../domain/course.dart';
import '../domain/course_estimate.dart';
import 'competition_providers.dart';
import 'course_estimate_provider.dart';
import 'course_map.dart';
import 'course_reviews_section.dart';

/// 경쟁 화면에 항상 보여 주는 안전 문구 (기획서 4.7)
const safetyNotice = '무리한 속도 경쟁은 사고로 이어질 수 있어요. 내 속도로 안전하게 올라요.';

/// 기록 값을 표시용 글자로. 최다완등은 "6회", 최단시간은 "0:47:12"
String formatScore(RankingKind kind, int value) => switch (kind) {
  RankingKind.most => '$value회',
  RankingKind.fastest => formatClock(Duration(seconds: value)),
};

/// 코스 상세: 코스 정보, 이번 시즌 정복자, 랭킹(이번 시즌 / 명예의 전당)
class CourseDetailScreen extends ConsumerStatefulWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  RankingKind _kind = RankingKind.most;
  bool _allTime = false;
  bool _starting = false;

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await startRecording(context, ref);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesProvider).value ?? const <Course>[];
    final course = courses.where((c) => c.id == widget.courseId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(course?.mountainName ?? '코스')),
      body: course == null
          ? const Center(child: Text('코스를 찾지 못했어요', style: AppTypography.body))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
                AppSpacing.screenHorizontal,
                AppSpacing.xxl,
              ),
              children: [
                _CourseHeader(course: course),
                const SizedBox(height: AppSpacing.xxl),
                _CoursePathMap(course: course),
                const SizedBox(height: AppSpacing.xxl),
                _StatsCard(courseId: course.id),
                const SizedBox(height: AppSpacing.md),
                _PersonalEstimate(courseId: course.id),
                const SizedBox(height: AppSpacing.xxxl),
                _ConquerorSection(courseId: course.id),
                const SizedBox(height: AppSpacing.xxxl),
                const Text('랭킹', style: AppTypography.subtitle),
                const SizedBox(height: AppSpacing.md),
                SegmentedTabs<bool>(
                  options: {false: '이번 시즌', true: '명예의 전당'},
                  selected: _allTime,
                  onChanged: (v) => setState(() => _allTime = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedTabs<RankingKind>(
                  options: const {
                    RankingKind.most: '최다완등',
                    RankingKind.fastest: '최단시간',
                  },
                  selected: _kind,
                  onChanged: (v) => setState(() => _kind = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                _RankingList(
                  query: (courseId: course.id, kind: _kind, allTime: _allTime),
                ),
                const SizedBox(height: AppSpacing.sm),
                _RankingScopeNote(
                  query: (courseId: course.id, kind: _kind, allTime: _allTime),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const SafetyNoticeCard(),
                const SizedBox(height: AppSpacing.xxxl),
                CourseReviewsSection(courseId: course.id),
              ],
            ),
      bottomNavigationBar: course == null
          ? null
          : BottomActionBar(
              child: AppButton(
                label: '이 코스 기록 시작',
                onPressed: _starting ? null : _start,
              ),
            ),
    );
  }
}

class _CourseHeader extends StatelessWidget {
  const _CourseHeader({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final time = course.officialTimeMin;
    final difficulty = course.officialDifficulty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(course.fullName, style: AppTypography.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${course.startName} → ${course.endName}',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: MetricText(
                label: '거리',
                value: formatKm(course.distanceM),
                unit: 'km',
              ),
            ),
            Expanded(
              child: MetricText(
                label: '공식 오르막',
                value: time == null ? '-' : '$time',
                unit: '분',
              ),
            ),
            Expanded(
              child: MetricText(
                label: '난이도',
                value: difficulty == null || difficulty.isEmpty
                    ? '-'
                    : difficulty,
                unit: '',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 코스 전체 경로 (들머리 → 정상). 기기에 저장한 코스 선이라 인터넷이 없어도 보인다.
class _CoursePathMap extends StatelessWidget {
  const _CoursePathMap({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return RoutePreviewMap(
      points: [for (final p in course.path) toLatLng(p)],
      attribution: mapAttribution,
      // 정상 이름표(가로 약 160)가 지도 밖으로 잘리지 않게 좌우·위를 넓게 둔다.
      fitPadding: const EdgeInsets.fromLTRB(80, 56, 80, 32),
      markers: [
        Marker(
          point: toLatLng(course.start),
          width: 28,
          height: 28,
          child: const StartDot(selected: true),
        ),
        Marker(
          point: toLatLng(course.summit),
          width: 160,
          height: 48,
          alignment: Alignment.topCenter,
          child: SummitLabel(name: course.endName),
        ),
      ],
    );
  }
}

class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(courseStatsProvider(courseId));
    final progress = ref.watch(myBestProgressProvider(courseId)).value;
    // 완등은 없지만 중간까지 다녀온 기록이 있으면 함께 보여 준다.
    final progressLine = switch ((stats.value?.myCount, progress)) {
      (0, final p?) => '내 최고 진행률 ${(p * 100).round()}%',
      _ => null,
    };
    final List<String> lines = switch (stats) {
      AsyncData(:final value) when value.completionCount == 0 => [
        '아직 완주 기록이 없어요. 첫 완주에 도전해 보세요.',
        ?progressLine,
      ],
      AsyncData(:final value) => [
        '완주 기록 ${value.completionCount}회 · '
            '평균 ${formatHoursMinutes(value.averageAscent ?? Duration.zero)}',
        if (value.myCount > 0)
          '내 완주 ${value.myCount}회 · 최고 '
              '${formatClock(value.myBestAscent ?? Duration.zero)}',
        ?progressLine,
      ],
      AsyncError() => const ['인터넷에 연결되면 완주 기록을 볼 수 있어요'],
      _ => const [],
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: lines.isEmpty
          ? const SkeletonBox(width: 200, height: 20)
          : Column(
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

/// 구독자: 내 기록으로 계산한 예상 소요시간(오르는 시간, 휴식 포함)·맞춤 난이도·안전 안내.
/// 일반 사용자: 프리미엄 안내 한 줄.
class _PersonalEstimate extends ConsumerWidget {
  const _PersonalEstimate({required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isPremiumProvider)) {
      return Pressable(
        onPressed: () => context.push(AppRoutes.premium),
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: '내 맞춤 예상 시간과 난이도는 ',
                style: AppTypography.caption,
              ),
              TextSpan(
                text: '프리미엄에서 볼 수 있어요',
                style: AppTypography.caption.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      );
    }

    final estimate = ref.watch(courseEstimateProvider(courseId));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: switch (estimate) {
        AsyncData(value: null) => Text(
          '이 코스는 고도 정보가 없어 예상 시간을 계산할 수 없어요',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        AsyncData(value: final e?) => _EstimateBody(estimate: e),
        AsyncError() => Text(
          '예상 시간을 계산하지 못했어요',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        _ => const SkeletonBox(width: double.infinity, height: 96),
      },
    );
  }
}

class _EstimateBody extends StatelessWidget {
  const _EstimateBody({required this.estimate});

  final CourseEstimate estimate;

  static String _minutes(Duration d) => formatHoursMinutes(d);

  @override
  Widget build(BuildContext context) {
    final e = estimate;
    final secondary = AppTypography.body.copyWith(
      color: AppColors.textSecondary,
    );
    final compare = e.compareTo;
    final diff = compare == null ? null : e.total - compare.time;
    final mine = e.myRecords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '나에게 맞춘 예상',
          style: AppTypography.caption.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('약 ${_minutes(e.total)}', style: AppTypography.title),
        Text(
          '오르는 시간 · 걷는 시간 ${_minutes(e.walking)} + 휴식 ${_minutes(e.rest)}',
          style: secondary,
        ),
        if (e.difficulty case final d?) ...[
          const SizedBox(height: AppSpacing.md),
          Text(switch (d) {
            PersonalDifficulty.easier => '평소보다 쉬운 편이에요',
            PersonalDifficulty.usual => '평소 산행과 비슷한 정도예요',
            PersonalDifficulty.harder => '평소보다 힘든 편이에요',
          }, style: AppTypography.subtitle),
          Text(
            '평소 오르막 걷는 시간의 ${e.workloadRatio!.toStringAsFixed(1)}배',
            style: secondary,
          ),
        ],
        if (compare != null && diff != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            diff.inMinutes.abs() < 1
                ? '${compare.label}과 비슷하게 도착할 거예요'
                : '${compare.label}보다 ${diff.inMinutes.abs()}분 '
                      '${diff.isNegative ? '빨리' : '늦게'} 도착할 거예요',
            style: AppTypography.body,
          ),
        ],
        if (mine != null)
          Text(
            '내 기록 ${mine.count}번 · 평균 ${formatClock(mine.average)} · '
            '최고 ${formatClock(mine.best)}',
            style: AppTypography.body,
          ),
        for (final w in e.warnings) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상태 색은 아이콘과 함께 쓴다 (색만으로 구분하지 않기).
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(switch (w) {
                  SteepSections(:final count, :final lengthM) =>
                    '경사 30% 이상 급경사가 $count곳(약 ${lengthM.round()}m) 있어요.',
                  SteepDownhillHabit() =>
                    '급경사 내리막에서 빨라지는 편이에요. 같은 길로 내려올 때 특히 천천히 내려오세요.',
                  HarderThanUsual() => '평소보다 힘든 코스예요. 물과 간식을 넉넉히 챙기고 일찍 출발하세요.',
                }, style: AppTypography.body),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          e.personal
              ? '최근 산행 ${e.basedOnHikes}번 기준 · 경사 보정(Tobler)'
              : '산행 기록이 ${CourseEstimate.minHikes}번 쌓이면 나에게 맞춰 계산해요. '
                    '지금은 표준 등산객 기준이에요.',
          style: AppTypography.caption,
        ),
      ],
    );
  }
}

class _ConquerorSection extends ConsumerWidget {
  const _ConquerorSection({required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final season = ref.watch(currentSeasonProvider);
    final conquerors = ref.watch(conquerorsProvider).value ?? const [];
    Conqueror? of(RankingKind kind) => conquerors
        .where((c) => c.courseId == courseId && c.kind == kind)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${season.label} 정복자', style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _ConquerorCard(
                title: '최다완등',
                kind: RankingKind.most,
                conqueror: of(RankingKind.most),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _ConquerorCard(
                title: '최단시간',
                kind: RankingKind.fastest,
                conqueror: of(RankingKind.fastest),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConquerorCard extends StatelessWidget {
  const _ConquerorCard({
    required this.title,
    required this.kind,
    required this.conqueror,
  });

  final String title;
  final RankingKind kind;
  final Conqueror? conqueror;

  @override
  Widget build(BuildContext context) {
    final c = conqueror;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.md),
          if (c == null)
            Text(
              '아직 없어요\n첫 정복자가 되어 보세요',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            UserAvatar(nickname: c.nickname, imageUrl: c.avatarUrl, size: 44),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${c.nickname}#${c.nicknameTag}',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            Text(formatScore(kind, c.value), style: AppTypography.subtitle),
          ],
        ],
      ),
    );
  }
}

class _RankingList extends ConsumerWidget {
  const _RankingList({required this.query});

  final RankingQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = ref.watch(courseRankingProvider(query));
    return switch (ranking) {
      AsyncData(:final value) when value.entries.isEmpty => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Text(
          query.allTime ? '아직 이 코스를 완주한 사람이 없어요' : '이번 시즌 첫 정복자가 되어 보세요',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
      AsyncData(:final value) => Column(
        children: [
          for (final (i, entry) in value.entries.indexed) ...[
            // 상위 10명 밖의 "내 순위"는 한 칸 띄워서 보여 준다.
            if (i > 0 &&
                entry.rank > value.entries[i - 1].rank + 1 &&
                entry.isMe)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text('···', style: AppTypography.caption),
              ),
            RankingRow(entry: entry, kind: query.kind),
          ],
        ],
      ),
      AsyncError() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '인터넷에 연결되면 랭킹을 볼 수 있어요',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Pressable(
            onPressed: () => ref.invalidate(courseRankingProvider(query)),
            child: Text(
              '다시 시도',
              style: AppTypography.body.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
      _ => Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            const SkeletonBox(width: double.infinity, height: 48),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    };
  }
}

class RankingRow extends StatelessWidget {
  const RankingRow({super.key, required this.entry, required this.kind});

  final RankingEntry entry;
  final RankingKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        // 내 순위는 배경색으로 구분한다.
        color: entry.isMe ? AppColors.backgroundGrouped : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.xxxl,
            child: Text(
              '${entry.rank}',
              style: AppTypography.subtitle.copyWith(
                color: entry.rank <= 3
                    ? AppColors.primary
                    : AppColors.textTertiary,
              ),
            ),
          ),
          UserAvatar(nickname: entry.nickname, imageUrl: entry.avatarUrl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              entry.isMe ? '${entry.displayName} (나)' : entry.displayName,
              style: AppTypography.body.copyWith(
                fontWeight: entry.isMe ? FontWeight.w600 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            formatScore(kind, entry.value),
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class SafetyNoticeCard extends StatelessWidget {
  const SafetyNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrouped,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              safetyNotice,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 코스 상세에는 누구나 상위 10명 + 내 순위만 보여 준다. (리뷰까지 금방 내려갈 수 있게)
/// 구독자는 "전체 순위 보기"로 별도 화면에서 나눠 받아 본다.
/// (실제로 몇 줄을 받는지는 서버 DB 함수가 구독 여부로 정한다)
class _RankingScopeNote extends ConsumerWidget {
  const _RankingScopeNote({required this.query});

  final RankingQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isPremiumProvider)) {
      final total = ref.watch(courseRankingProvider(query)).value?.total;
      return AppButton(
        label: total == null ? '전체 순위 보기' : '전체 순위 보기 ($total명)',
        variant: AppButtonVariant.secondary,
        onPressed: () => context.push(
          AppRoutes.ranking(
            query.courseId,
            kind: query.kind,
            allTime: query.allTime,
          ),
        ),
      );
    }
    return Pressable(
      onPressed: () => context.push(AppRoutes.premium),
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text: '상위 10명과 내 순위까지 보여요 · ',
              style: AppTypography.caption,
            ),
            TextSpan(
              text: '전체 순위 보기',
              style: AppTypography.caption.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
