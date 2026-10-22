import 'package:hiking_app/features/courses/data/course_remote.dart';
import 'package:hiking_app/features/courses/domain/course.dart';

/// 서버 대신 정해 둔 코스를 돌려주는 가짜. [failWith]를 정하면 그 오류를 던진다.
class FakeCourseRemote implements CourseRemote {
  FakeCourseRemote([this.courses = const []]);

  List<Course> courses;
  Object? failWith;

  /// 코스 전체를 내려받은 횟수
  int fetchCalls = 0;

  /// 버전만 물어본 횟수
  int versionCalls = 0;

  @override
  Future<List<Course>> fetchCourses() async {
    fetchCalls++;
    if (failWith case final error?) throw error;
    return courses;
  }

  @override
  Future<CatalogVersion> fetchVersion() async {
    versionCalls++;
    if (failWith case final error?) throw error;
    final times = [for (final c in courses) ?c.updatedAt];
    return CatalogVersion(
      count: courses.length,
      latestUpdate: times.isEmpty
          ? null
          : times.reduce((a, b) => a.isAfter(b) ? a : b),
    );
  }
}

/// 테스트용 코스: 승학산 정상까지 남서→북동으로 가는 짧은 코스
Course testCourse({
  String id = 'c1',
  String mountainName = '승학산',
  String name = '동아대 코스',
  DateTime? updatedAt,
  List<double>? elevations,
}) => Course(
  id: id,
  mountainName: mountainName,
  name: name,
  startName: '동아대학교 승학캠퍼스',
  endName: '$mountainName 정상',
  distanceM: 1040,
  officialTimeMin: 18,
  officialDifficulty: '하',
  path: const [
    GeoPoint(35.11916, 128.97040),
    GeoPoint(35.11800, 128.97500),
    GeoPoint(35.11677, 128.97989),
  ],
  summit: const GeoPoint(35.11683, 128.97982),
  updatedAt: updatedAt ?? DateTime.utc(2026, 10, 20, 9),
  // 경로 점 3개마다의 고도 (주면 맞춤 예상 시간을 계산할 수 있다)
  elevations: elevations,
);
