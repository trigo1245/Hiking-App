import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_setup.dart';
import '../domain/review.dart';

/// 리뷰를 서버와 주고받는 창구. 쓰기 자격(완등 또는 40% 이상)은 서버 함수가 검사한다.
abstract interface class ReviewRemote {
  /// [offset]번째부터 [limit]개, [sort] 순서로 받는다.
  Future<ReviewPage> fetchReviews(
    String courseId, {
    ReviewSort sort = ReviewSort.recent,
    int offset = 0,
    int limit = 30,
  });

  Future<ReviewSummary> fetchSummary(String courseId);

  /// 내가 쓴 리뷰 (없으면 null)
  Future<MyReview?> fetchMyReview(String courseId);

  /// 내가 이 코스를 가장 멀리 간 비율 (중도 하산 기록이 없으면 null)
  Future<double?> fetchMyBestProgress(String courseId);

  /// [scores]에 없는 항목(조망)은 비워서 보낸다.
  Future<void> saveMyReview(
    String courseId,
    Map<ReviewAspect, int> scores,
    String? comment,
  );
  Future<void> deleteMyReview(String courseId);
}

class SupabaseReviewRemote implements ReviewRemote {
  SupabaseReviewRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<ReviewPage> fetchReviews(
    String courseId, {
    ReviewSort sort = ReviewSort.recent,
    int offset = 0,
    int limit = 30,
  }) async {
    final rows = (await _client.rpc<List<dynamic>>(
      'get_course_reviews',
      params: {
        'p_course_id': courseId,
        'p_sort': sort.name,
        'p_offset': offset,
        'p_limit': limit,
      },
    )).cast<Map<String, dynamic>>();
    return ReviewPage(
      total: rows.isEmpty ? 0 : rows.first['total_count'] as int,
      reviews: [
        for (final r in rows)
          CourseReview(
            nickname: r['nickname'] as String,
            nicknameTag: r['nickname_tag'] as String,
            avatarUrl: r['avatar_url'] as String?,
            scores: _scores(r),
            comment: r['comment'] as String?,
            updatedAt: DateTime.parse(r['updated_at'] as String),
            isMine: r['is_mine'] as bool,
            completionCount: (r['completion_count'] as int?) ?? 0,
            bestProgress: (r['best_progress'] as num?)?.toDouble(),
          ),
      ],
    );
  }

  static Map<ReviewAspect, int> _scores(Map<String, dynamic> r) => {
    for (final a in ReviewAspect.values)
      if (r[a.name] case final int v) a: v,
  };

  @override
  Future<ReviewSummary> fetchSummary(String courseId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_review_summary',
      params: {'p_course_id': courseId},
    );
    final r = rows.cast<Map<String, dynamic>>().first;
    return ReviewSummary(
      count: r['review_count'] as int,
      averages: {
        for (final a in ReviewAspect.values)
          if (r['avg_${a.name}'] case final num v) a: v.toDouble(),
      },
    );
  }

  @override
  Future<MyReview?> fetchMyReview(String courseId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('course_reviews')
        .select('difficulty, risk, view, crowd, comment')
        .eq('course_id', courseId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return MyReview(scores: _scores(row), comment: row['comment'] as String?);
  }

  @override
  Future<double?> fetchMyBestProgress(String courseId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final rows = await _client
        .from('course_attempts')
        .select('progress')
        .eq('course_id', courseId)
        .eq('user_id', userId)
        .order('progress', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : (rows.first['progress'] as num).toDouble();
  }

  @override
  Future<void> saveMyReview(
    String courseId,
    Map<ReviewAspect, int> scores,
    String? comment,
  ) async {
    await _client.rpc<void>(
      'upsert_my_review',
      params: {
        'p_course_id': courseId,
        for (final a in ReviewAspect.values) 'p_${a.name}': scores[a],
        'p_comment': comment,
      },
    );
  }

  @override
  Future<void> deleteMyReview(String courseId) async {
    await _client.rpc<void>(
      'delete_my_review',
      params: {'p_course_id': courseId},
    );
  }
}

final reviewRemoteProvider = Provider<ReviewRemote>((ref) {
  return SupabaseReviewRemote(ref.watch(supabaseClientProvider));
});

/// 코스 상세에 보여 줄 최신 리뷰 3개와 전체 개수
final latestReviewsProvider = FutureProvider.autoDispose
    .family<ReviewPage, String>(
      (ref, courseId) =>
          ref.watch(reviewRemoteProvider).fetchReviews(courseId, limit: 3),
      retry: (_, _) => null,
    );

final reviewSummaryProvider = FutureProvider.autoDispose
    .family<ReviewSummary, String>(
      (ref, courseId) => ref.watch(reviewRemoteProvider).fetchSummary(courseId),
      retry: (_, _) => null,
    );

final myReviewProvider = FutureProvider.autoDispose.family<MyReview?, String>(
  (ref, courseId) => ref.watch(reviewRemoteProvider).fetchMyReview(courseId),
  retry: (_, _) => null,
);

/// 이 코스를 가장 멀리 간 비율. 서버에서 못 받으면 null (완등 여부로만 판단한다).
final myBestProgressProvider = FutureProvider.autoDispose
    .family<double?, String>((ref, courseId) async {
      try {
        return await ref
            .watch(reviewRemoteProvider)
            .fetchMyBestProgress(courseId);
      } catch (_) {
        return null;
      }
    });
