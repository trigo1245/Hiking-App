import 'package:hiking_app/features/activities/data/gpx_sharer.dart';
import 'package:hiking_app/features/courses/data/review_remote.dart';
import 'package:hiking_app/features/courses/domain/review.dart';
import 'package:hiking_app/features/subscription/data/subscription_remote.dart';
import 'package:hiking_app/features/subscription/domain/subscription.dart';

/// 서버 대신 리뷰를 기억하는 가짜
class FakeReviewRemote implements ReviewRemote {
  final reviews = <CourseReview>[];
  final saved = <(String, Map<ReviewAspect, int>, String?)>[];
  int deletes = 0;

  @override
  Future<List<CourseReview>> fetchReviews(String courseId) async =>
      List.of(reviews);

  @override
  Future<ReviewSummary> fetchSummary(String courseId) async {
    if (reviews.isEmpty) return const ReviewSummary(count: 0);
    return ReviewSummary(
      count: reviews.length,
      averages: {
        for (final a in ReviewAspect.values)
          a:
              reviews.map((r) => r.scores[a]!).reduce((x, y) => x + y) /
              reviews.length,
      },
    );
  }

  @override
  Future<void> saveMyReview(
    String courseId,
    Map<ReviewAspect, int> scores,
    String? comment,
  ) async {
    saved.add((courseId, scores, comment));
    reviews
      ..removeWhere((r) => r.isMine)
      ..insert(
        0,
        CourseReview(
          nickname: '김세민',
          nicknameTag: '0369',
          scores: scores,
          comment: comment,
          updatedAt: DateTime(2026, 10, 20),
          isMine: true,
        ),
      );
  }

  @override
  Future<void> deleteMyReview(String courseId) async {
    deletes++;
    reviews.removeWhere((r) => r.isMine);
  }
}

/// 서버 대신 구독 상태를 기억하는 가짜
class FakeSubscriptionRemote implements SubscriptionRemote {
  FakeSubscriptionRemote({bool active = false}) {
    if (active) _start();
  }

  Subscription? current;
  int starts = 0;
  int cancels = 0;

  void _start() => current = Subscription(
    startedAt: DateTime(2026, 10, 20),
    expiresAt: DateTime(2026, 11, 20),
    isActive: true,
  );

  @override
  Future<Subscription?> fetchMine() async => current;

  @override
  Future<void> startDemo() async {
    starts++;
    _start();
  }

  @override
  Future<void> cancel() async {
    cancels++;
    current = Subscription(
      startedAt: current!.startedAt,
      expiresAt: DateTime(2026, 10, 20),
      isActive: false,
    );
  }
}

/// 공유 창 대신 내보낸 파일을 기억하는 가짜
class FakeGpxSharer implements GpxSharer {
  final shared = <(String, String)>[];

  @override
  Future<void> share({required String fileName, required String gpx}) async =>
      shared.add((fileName, gpx));
}

CourseReview review(
  String name,
  int score, {
  String? comment,
  bool isMine = false,
}) => CourseReview(
  nickname: name,
  nicknameTag: '0001',
  scores: {for (final a in ReviewAspect.values) a: score},
  comment: comment,
  updatedAt: DateTime(2026, 10, 1),
  isMine: isMine,
);
