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
  static String locationPermission(LocationAccess access) =>
      '/location-permission/${access.name}';
}
