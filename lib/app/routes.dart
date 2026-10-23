import '../features/courses/domain/competition.dart';
import '../features/recording/data/location_service.dart';

/// 화면 경로 이름. 문자열을 여기저기 직접 쓰지 않도록 모아 둔다.
abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const activities = '/activities';
  static const myInfo = '/me';

  /// 기록 중 화면 (하단 탭 없이 전체 화면)
  static const recording = '/record';
  static String recordingDone(String activityId) => '/record-done/$activityId';

  /// 코스 상세 (하단 탭 위에 쌓아서 뒤로 가기로 지도에 돌아온다)
  static String course(String courseId) => '/course/$courseId';
  static String writeReview(String courseId) => '/course/$courseId/review';

  /// 코스 전체 순위 (프리미엄). 상세에서 고른 랭킹 종류·기간으로 연다.
  static String ranking(
    String courseId, {
    required RankingKind kind,
    required bool allTime,
  }) => '/course/$courseId/ranking?kind=${kind.name}&alltime=$allTime';

  /// 코스 리뷰 전체
  static String reviews(String courseId) => '/course/$courseId/reviews';

  /// 기록 상세 (기록 탭에서 카드를 누르면 열린다)
  static String activity(String activityId) => '/activity/$activityId';

  /// 프리미엄 구독
  static const premium = '/premium';
  static String locationPermission(LocationAccess access) =>
      '/location-permission/${access.name}';
}
