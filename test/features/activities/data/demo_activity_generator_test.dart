import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/activities/data/demo_activity_generator.dart';
import 'package:hiking_app/features/courses/domain/course.dart';
import 'package:hiking_app/features/courses/domain/course_matching.dart';
import 'package:hiking_app/features/recording/data/recording_repository.dart';

import '../../../helpers/course_walk.dart';
import '../../../helpers/pump_app.dart';

Course named(String id, String mountain, String name) {
  final c = loadCourse(id);
  return Course(
    id: id,
    mountainName: mountain,
    name: name,
    startName: '',
    endName: '',
    distanceM: 0,
    path: c.path,
    summit: c.summit,
  );
}

void main() {
  test('시연용 기록 3개는 실제 코스 완주로 판정되고, 속도 이상 표시가 없다', () async {
    final db = testDatabase();
    final recording = RecordingRepository(db);
    final courses = [
      named('geumjeongsan-beomeosa', '금정산', '범어사 코스'),
      named('seunghaksan-donga', '승학산', '동아대 코스'),
    ];

    final ids = await DemoActivityGenerator(recording).createDemoHikes(
      courses: courses,
      userId: 'u1',
      now: DateTime(2026, 10, 20, 12),
    );
    expect(ids, hasLength(3));

    final matched = <String>[];
    for (final id in ids) {
      final summary = await recording.loadSummary(id);
      expect(summary.isFlagged, isFalse, reason: summary.title);
      expect(summary.elevationGainM, greaterThan(100));
      final results = CourseMatcher.matchAll(
        courses,
        await recording.loadPoints(id),
      );
      matched.addAll(results.map((r) => r.courseId));
    }
    expect(matched, [
      'geumjeongsan-beomeosa',
      'seunghaksan-donga',
      'geumjeongsan-beomeosa',
    ]);
  });
}
