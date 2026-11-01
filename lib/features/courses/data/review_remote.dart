import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/photos/photo_item.dart';
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

  /// 리뷰와 사진을 함께 지운다.
  Future<void> deleteMyReview(String courseId);

  /// 내 리뷰에 사진을 붙인다. 리뷰를 먼저 저장해야 한다. (리뷰 하나에 3장까지, 서버가 검사)
  Future<void> addReviewPhoto(String courseId, Uint8List jpeg);

  Future<void> deleteReviewPhoto(PhotoItem photo);
}

/// 리뷰 사진을 담는 공개 버킷. 경로: {user_id}/{course_id}/{사진 id}.jpg
const reviewPhotoBucket = 'review-photos';

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
            photoUrls: [
              for (final p in (r['photo_paths'] as List?) ?? const [])
                _photoUrl(p as String),
            ],
          ),
      ],
    );
  }

  String _photoUrl(String path) =>
      _client.storage.from(reviewPhotoBucket).getPublicUrl(path);

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
    final photos = await _client
        .from('review_photos')
        .select('id, path')
        .eq('course_id', courseId)
        .eq('user_id', userId)
        .order('created_at');
    return MyReview(
      scores: _scores(row),
      comment: row['comment'] as String?,
      photos: [
        for (final p in photos)
          PhotoItem(
            id: p['id'] as String,
            path: p['path'] as String,
            url: _photoUrl(p['path'] as String),
          ),
      ],
    );
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
    final userId = _client.auth.currentUser?.id;
    // 사진 행은 리뷰와 함께 지워지므로(cascade) 파일 경로를 먼저 받아 둔다.
    final photos = userId == null
        ? const <Map<String, dynamic>>[]
        : await _client
              .from('review_photos')
              .select('path')
              .eq('course_id', courseId)
              .eq('user_id', userId);
    await _client.rpc<void>(
      'delete_my_review',
      params: {'p_course_id': courseId},
    );
    if (photos.isEmpty) return;
    try {
      await _client.storage.from(reviewPhotoBucket).remove([
        for (final p in photos) p['path'] as String,
      ]);
    } catch (e) {
      debugPrint('[photo] 리뷰 사진 파일을 지우지 못했어요: $e');
    }
  }

  @override
  Future<void> addReviewPhoto(String courseId, Uint8List jpeg) async {
    final userId = _client.auth.currentUser!.id;
    final id = const Uuid().v4();
    final path = '$userId/$courseId/$id.jpg';
    await _client.storage
        .from(reviewPhotoBucket)
        .uploadBinary(
          path,
          jpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    try {
      await _client.from('review_photos').insert({
        'id': id,
        'course_id': courseId,
        'user_id': userId,
        'path': path,
      });
    } catch (_) {
      await _client.storage.from(reviewPhotoBucket).remove([path]);
      rethrow;
    }
  }

  @override
  Future<void> deleteReviewPhoto(PhotoItem photo) async {
    await _client.from('review_photos').delete().eq('id', photo.id);
    try {
      await _client.storage.from(reviewPhotoBucket).remove([photo.path]);
    } catch (e) {
      debugPrint('[photo] 파일을 지우지 못했어요: $e');
    }
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
