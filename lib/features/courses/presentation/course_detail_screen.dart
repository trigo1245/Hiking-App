import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/metric_text.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../recording/presentation/start_recording.dart';
import '../data/course_repository.dart';
import '../domain/competition.dart';
import '../domain/course.dart';
import 'competition_providers.dart';

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
                _StatsCard(courseId: course.id),
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
                const SizedBox(height: AppSpacing.xxl),
                const _SafetyNotice(),
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

class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(courseStatsProvider(courseId));
    final List<String> lines = switch (stats) {
      AsyncData(:final value) when value.completionCount == 0 => const [
        '아직 완주 기록이 없어요. 첫 완주에 도전해 보세요.',
      ],
      AsyncData(:final value) => [
        '완주 기록 ${value.completionCount}회 · '
            '평균 ${formatHoursMinutes(value.averageAscent ?? Duration.zero)}',
        if (value.myCount > 0)
          '내 완주 ${value.myCount}회 · 최고 '
              '${formatClock(value.myBestAscent ?? Duration.zero)}',
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
      AsyncData(:final value) when value.isEmpty => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Text(
          query.allTime ? '아직 이 코스를 완주한 사람이 없어요' : '이번 시즌 첫 정복자가 되어 보세요',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
      AsyncData(:final value) => Column(
        children: [
          for (final (i, entry) in value.indexed) ...[
            // 상위 10명 밖의 "내 순위"는 한 칸 띄워서 보여 준다.
            if (i > 0 && entry.rank > value[i - 1].rank + 1 && entry.isMe)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text('···', style: AppTypography.caption),
              ),
            _RankingRow(entry: entry, kind: query.kind),
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

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.entry, required this.kind});

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

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

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
