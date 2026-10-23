import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/review_remote.dart';
import '../domain/review.dart';
import 'competition_providers.dart';

/// 이 코스에서 내 리뷰 쓰기 자격 (완등 횟수는 서버 통계, 진행률은 서버 진행률 기록)
final reviewAccessProvider = Provider.autoDispose.family<ReviewAccess?, String>(
  (ref, courseId) {
    final stats = ref.watch(courseStatsProvider(courseId));
    final progress = ref.watch(myBestProgressProvider(courseId));
    if (!stats.hasValue || !progress.hasValue) return null;
    return ReviewAccess.of(
      completions: stats.value!.myCount,
      bestProgress: progress.value,
    );
  },
);

/// 코스 상세의 리뷰: 항목별 평균, 리뷰 쓰기, 최신 리뷰 3개, 전체 보기
class CourseReviewsSection extends ConsumerWidget {
  const CourseReviewsSection({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(reviewSummaryProvider(courseId));
    final latest = ref.watch(latestReviewsProvider(courseId));
    final access = ref.watch(reviewAccessProvider(courseId));
    final mine = ref.watch(myReviewProvider(courseId)).value;
    final total = latest.value?.total ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('리뷰', style: AppTypography.subtitle)),
            if (summary.value case ReviewSummary(:final count) when count > 0)
              Text('$count개', style: AppTypography.caption),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        switch (summary) {
          AsyncData(:final value) when value.count > 0 => _Averages(
            summary: value,
          ),
          AsyncData() => Text(
            '아직 리뷰가 없어요',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          AsyncError() => Text(
            '인터넷에 연결되면 리뷰를 볼 수 있어요',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          _ => const SkeletonBox(width: double.infinity, height: 96),
        },
        const SizedBox(height: AppSpacing.lg),
        switch (access) {
          ReviewAccess.completed || ReviewAccess.partial => AppButton(
            label: mine == null ? '리뷰 쓰기' : '내 리뷰 고치기',
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(AppRoutes.writeReview(courseId)),
          ),
          ReviewAccess.none => Text(
            '이 코스를 ${(reviewMinProgress * 100).round()}% 이상 다녀오면 리뷰를 쓸 수 있어요',
            style: AppTypography.caption,
          ),
          null => const SizedBox.shrink(),
        },
        const SizedBox(height: AppSpacing.lg),
        for (final review in latest.value?.reviews ?? const <CourseReview>[])
          ReviewTile(review: review),
        if (total > (latest.value?.reviews.length ?? 0))
          AppButton(
            label: '리뷰 전체 보기 ($total개)',
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(AppRoutes.reviews(courseId)),
          ),
      ],
    );
  }
}

/// 리뷰를 30개씩 나눠 받는다. 정렬이 바뀌면 처음부터 다시 받는다.
class ReviewPager extends ChangeNotifier {
  ReviewPager(this._remote, this.courseId);

  static const pageSize = 30;

  final ReviewRemote _remote;
  final String courseId;

  ReviewSort sort = ReviewSort.recent;
  final reviews = <CourseReview>[];
  int? total;
  bool loading = false;
  Object? error;
  int _generation = 0;

  bool get hasMore => total == null || reviews.length < total!;

  Future<void> reset({ReviewSort? sort}) {
    this.sort = sort ?? this.sort;
    _generation++;
    reviews.clear();
    total = null;
    error = null;
    loading = false;
    notifyListeners();
    return loadMore();
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    final generation = _generation;
    loading = true;
    notifyListeners();
    try {
      final page = await _remote.fetchReviews(
        courseId,
        sort: sort,
        offset: reviews.length,
        limit: pageSize,
      );
      if (generation != _generation) return;
      reviews.addAll(page.reviews);
      total = page.total;
    } catch (e) {
      if (generation != _generation) return;
      error = e;
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }
}

/// 코스 리뷰 전체: 정렬(최신순 / 완등 많은 순), 스크롤하면 30개씩 더 받는다.
class AllReviewsScreen extends ConsumerStatefulWidget {
  const AllReviewsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends ConsumerState<AllReviewsScreen> {
  late final ReviewPager _pager = ReviewPager(
    ref.read(reviewRemoteProvider),
    widget.courseId,
  );
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _pager.addListener(_onChanged);
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _pager.loadMore();
    });
    _pager.reset();
  }

  @override
  void dispose() {
    _pager
      ..removeListener(_onChanged)
      ..dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = _pager;
    return Scaffold(
      appBar: AppBar(title: Text(p.total == null ? '리뷰' : '리뷰 ${p.total}개')),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
        ),
        children: [
          SegmentedTabs<ReviewSort>(
            options: {for (final s in ReviewSort.values) s: s.label},
            selected: p.sort,
            onChanged: (s) => p.reset(sort: s),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final review in p.reviews) ReviewTile(review: review),
          if (p.loading)
            for (var i = 0; i < 3; i++) ...[
              const SkeletonBox(width: double.infinity, height: 96),
              const SizedBox(height: AppSpacing.sm),
            ]
          else if (p.error != null)
            Pressable(
              onPressed: () {
                p.error = null;
                p.loadMore();
              },
              child: Text(
                '인터넷에 연결되면 리뷰를 볼 수 있어요 · 다시 시도',
                style: AppTypography.body.copyWith(color: AppColors.primary),
              ),
            )
          else if (p.reviews.isEmpty)
            Text(
              '아직 리뷰가 없어요',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// 항목별 평균: 한 가지 색의 얇은 막대 + 숫자
class _Averages extends StatelessWidget {
  const _Averages({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final aspect in ReviewAspect.values)
          if (summary.averages[aspect] case final avg?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 76,
                    child: Text(aspect.label, style: AppTypography.caption),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => Stack(
                        children: [
                          Container(
                            height: AppSpacing.sm,
                            decoration: BoxDecoration(
                              color: AppColors.backgroundGrouped,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.xs,
                              ),
                            ),
                          ),
                          Container(
                            width: c.maxWidth * avg / 5,
                            height: AppSpacing.sm,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.xs,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: Text(
                      '${avg.toStringAsFixed(1)} · ${_meaning(aspect, avg)}',
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

  /// 평균이 어느 쪽에 가까운지 짧은 말로
  static String _meaning(ReviewAspect aspect, double avg) {
    if (avg < 2.5) return aspect.lowLabel;
    if (avg > 3.5) return aspect.highLabel;
    return '보통';
  }
}

/// 리뷰 한 개. 작성자가 이 코스를 완등한 횟수(없으면 가장 멀리 간 비율)를 함께 보여 준다.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});

  final CourseReview review;

  @override
  Widget build(BuildContext context) {
    final date = review.updatedAt.toLocal();
    final badge = review.completionCount > 0
        ? '완등 ${review.completionCount}회'
        : switch (review.bestProgress) {
            final p? => '${(p * 100).round()}%까지 다녀옴',
            null => null,
          };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: review.isMine
            ? AppColors.backgroundGrouped
            : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: review.isMine ? null : Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                nickname: review.nickname,
                imageUrl: review.avatarUrl,
                size: 32,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.isMine
                          ? '${review.displayName} (나)'
                          : review.displayName,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (badge != null)
                      Text(
                        badge,
                        style: AppTypography.caption.copyWith(
                          color: review.completionCount > 0
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              Text('${date.month}월 ${date.day}일', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            [
              for (final a in ReviewAspect.values)
                if (review.scores[a] case final score?) '${a.label} $score',
            ].join('  ·  '),
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (review.comment case final comment? when comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(comment, style: AppTypography.body),
          ],
        ],
      ),
    );
  }
}

/// 리뷰 쓰기·고치기 화면. 완등하지 않았으면 조망은 매기지 않는다.
class WriteReviewScreen extends ConsumerStatefulWidget {
  const WriteReviewScreen({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  final _scores = <ReviewAspect, int>{};
  final _comment = TextEditingController();
  bool _loadedMine = false;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  List<ReviewAspect> get _aspects =>
      (ref.read(reviewAccessProvider(widget.courseId)) ??
              ReviewAccess.completed)
          .aspects;

  bool get _complete => _aspects.every(_scores.containsKey);

  Future<void> _save() async {
    if (_busy || !_complete) return;
    setState(() => _busy = true);
    try {
      await ref.read(reviewRemoteProvider).saveMyReview(widget.courseId, {
        for (final a in _aspects) a: _scores[a]!,
      }, _comment.text.trim());
      _refresh();
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('[review] $e');
      _snack('저장하지 못했어요. 인터넷 연결을 확인해 주세요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await ref.read(reviewRemoteProvider).deleteMyReview(widget.courseId);
      _refresh();
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('[review] $e');
      _snack('지우지 못했어요. 인터넷 연결을 확인해 주세요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() {
    ref.invalidate(latestReviewsProvider(widget.courseId));
    ref.invalidate(reviewSummaryProvider(widget.courseId));
    ref.invalidate(myReviewProvider(widget.courseId));
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myReviewProvider(widget.courseId)).value;
    final access =
        ref.watch(reviewAccessProvider(widget.courseId)) ??
        ReviewAccess.completed;
    // 이미 쓴 리뷰가 있으면 처음 한 번 채워 둔다.
    if (mine != null && !_loadedMine) {
      _loadedMine = true;
      _scores.addAll(mine.scores);
      _comment.text = mine.comment ?? '';
    }

    return Scaffold(
      appBar: AppBar(title: Text(mine == null ? '리뷰 쓰기' : '내 리뷰 고치기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
        ),
        children: [
          for (final aspect in ReviewAspect.values) ...[
            Text(aspect.label, style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.sm),
            if (access.aspects.contains(aspect))
              _ScoreRow(
                aspect: aspect,
                value: _scores[aspect],
                onChanged: (v) => setState(() => _scores[aspect] = v),
              )
            else
              Text(
                '${aspect.label}은 정상까지 다녀온 분만 평가해요',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
          ],
          const Text('한 줄 후기 (선택)', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _comment,
            maxLength: reviewCommentMaxLength,
            maxLines: 3,
            style: AppTypography.body,
            decoration: const InputDecoration(
              hintText: '다른 등산객에게 도움이 될 이야기를 남겨 주세요',
            ),
          ),
          if (mine != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Pressable(
              onPressed: _busy ? null : _delete,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  '내 리뷰 지우기',
                  style: AppTypography.body.copyWith(color: AppColors.danger),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: _complete ? '저장하기' : '모든 항목을 골라 주세요',
          onPressed: _busy || !_complete ? null : _save,
        ),
      ),
    );
  }
}

/// 1~5점 고르기. 양 끝에 무슨 뜻인지 적어 둔다.
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.aspect,
    required this.value,
    required this.onChanged,
  });

  final ReviewAspect aspect;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var score = 1; score <= 5; score++) ...[
              if (score > 1) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Pressable(
                  onPressed: () => onChanged(score),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == score
                          ? AppColors.primary
                          : AppColors.backgroundGrouped,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                    child: Text(
                      '$score',
                      semanticsLabel: '${aspect.label} $score점',
                      style: AppTypography.subtitle.copyWith(
                        color: value == score
                            ? AppColors.onPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(aspect.lowLabel, style: AppTypography.caption),
            Text(aspect.highLabel, style: AppTypography.caption),
          ],
        ),
      ],
    );
  }
}
