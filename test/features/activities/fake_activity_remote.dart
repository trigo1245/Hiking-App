import 'package:hiking_app/features/activities/data/activity_remote.dart';
import 'package:hiking_app/features/courses/domain/course_matching.dart';

/// 서버 대신 올라온 내용을 기억하는 가짜. [failWith]를 정하면 그 오류를 던진다.
class FakeActivityRemote implements ActivityRemote {
  final gpxFiles = <String, String>{};
  final rows = <String, Map<String, Object?>>{};

  /// 기록 ID → 보낸 완주 결과
  final completions = <String, List<CourseCompletion>>{};
  Object? failWith;
  int uploadCalls = 0;

  @override
  Future<void> uploadGpx({required String path, required String gpx}) async {
    uploadCalls++;
    if (failWith case final error?) throw error;
    gpxFiles[path] = gpx;
  }

  @override
  Future<void> upsertActivity(Map<String, Object?> row) async {
    if (failWith case final error?) throw error;
    rows[row['id']! as String] = row;
  }

  @override
  Future<void> recordCompletions(
    String activityId,
    List<CourseCompletion> completions,
  ) async {
    if (failWith case final error?) throw error;
    this.completions[activityId] = completions;
  }

  /// 받기에 실패할 GPX 경로 (일부만 실패하는 경우 확인용)
  final brokenGpx = <String>{};

  @override
  Future<List<Map<String, dynamic>>> fetchMyActivities() async {
    if (failWith case final error?) throw error;
    return [for (final r in rows.values) Map<String, dynamic>.from(r)];
  }

  @override
  Future<String> downloadGpx(String path) async {
    if (failWith case final error?) throw error;
    if (brokenGpx.contains(path)) throw Exception('download failed');
    return gpxFiles[path]!;
  }
}
