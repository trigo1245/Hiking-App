import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_setup.dart';
import '../domain/review.dart';

/// 리뷰를 서버와 주고받는 창구. 쓰기 권한(완주 여부)은 서버 함수가 검사한다.
abstract interface class ReviewRemote {
  Future<List<CourseReview>> fetchReviews(String courseId);
  Future<ReviewSummary> fetchSummary(String courseId);
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
  Future<List<CourseReview>> fetchReviews(String courseId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_course_reviews',
      params: {'p_course_id': courseId},
    );
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        CourseReview(
          nickname: r['nickname'] as String,
          nicknameTag: r['nickname_tag'] as String,
          avatarUrl: r['avatar_url'] as String?,
          scores: {for (final a in ReviewAspect.values) a: r[a.name] as int},
          comment: r['comment'] as String?,
          updatedAt: DateTime.parse(r['updated_at'] as String),
          isMine: r['is_mine'] as bool,
        ),
    ];
  }

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

final courseReviewsProvider = FutureProvider.autoDispose
    .family<List<CourseReview>, String>(
      (ref, courseId) => ref.watch(reviewRemoteProvider).fetchReviews(courseId),
      retry: (_, _) => null,
    );

final reviewSummaryProvider = FutureProvider.autoDispose
    .family<ReviewSummary, String>(
      (ref, courseId) => ref.watch(reviewRemoteProvider).fetchSummary(courseId),
      retry: (_, _) => null,
    );
