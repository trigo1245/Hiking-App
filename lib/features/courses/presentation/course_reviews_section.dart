import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/review_remote.dart';
import '../domain/review.dart';
import 'competition_providers.dart';

/// 코스 상세의 리뷰: 항목별 평균, 리뷰 쓰기, 리뷰 목록
class CourseReviewsSection extends ConsumerWidget {
  const CourseReviewsSection({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(reviewSummaryProvider(courseId));
    final reviews = ref.watch(courseReviewsProvider(courseId));
    // 이 코스를 완주했으면 리뷰를 쓸 수 있다. (서버도 다시 검사한다)
    final canWrite =
        (ref.watch(courseStatsProvider(courseId)).value?.myCount ?? 0) > 0;
    final mine = reviews.value?.where((r) => r.isMine).firstOrNull;

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
        if (canWrite)
          AppButton(
            label: mine == null ? '리뷰 쓰기' : '내 리뷰 고치기',
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(AppRoutes.writeReview(courseId)),
          )
        else
          Text('이 코스를 완주하면 리뷰를 쓸 수 있어요', style: AppTypography.caption),
        const SizedBox(height: AppSpacing.lg),
        for (final review in reviews.value ?? const <CourseReview>[])
          _ReviewTile(review: review),
      ],
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

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final CourseReview review;

  @override
  Widget build(BuildContext context) {
    final date = review.updatedAt.toLocal();
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
                child: Text(
                  review.isMine
                      ? '${review.displayName} (나)'
                      : review.displayName,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${date.month}월 ${date.day}일', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            [
              for (final a in ReviewAspect.values)
                '${a.label} ${review.scores[a]}',
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

/// 리뷰 쓰기·고치기 화면
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

  Future<void> _save() async {
    if (_busy || _scores.length < ReviewAspect.values.length) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(reviewRemoteProvider)
          .saveMyReview(widget.courseId, Map.of(_scores), _comment.text.trim());
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
    ref.invalidate(courseReviewsProvider(widget.courseId));
    ref.invalidate(reviewSummaryProvider(widget.courseId));
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref
        .watch(courseReviewsProvider(widget.courseId))
        .value
        ?.where((r) => r.isMine)
        .firstOrNull;
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
            _ScoreRow(
              aspect: aspect,
              value: _scores[aspect],
              onChanged: (v) => setState(() => _scores[aspect] = v),
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
          label: _scores.length < ReviewAspect.values.length
              ? '네 항목을 모두 골라 주세요'
              : '저장하기',
          onPressed: _busy || _scores.length < ReviewAspect.values.length
              ? null
              : _save,
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
