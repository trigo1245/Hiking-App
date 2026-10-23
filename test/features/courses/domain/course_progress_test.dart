import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/core/utils/geo.dart';
import 'package:hiking_app/features/courses/domain/course.dart';
import 'package:hiking_app/features/courses/domain/course_matching.dart';

import '../../../helpers/course_walk.dart';

/// 코스 길이의 [fraction]까지만 잘라낸 경로
List<GeoPoint> prefix(List<GeoPoint> path, double fraction) {
  var total = 0.0;
  for (var i = 1; i < path.length; i++) {
    total += haversineMeters(
      path[i - 1].lat,
      path[i - 1].lon,
      path[i].lat,
      path[i].lon,
    );
  }
  final out = [path.first];
  var acc = 0.0;
  for (var i = 1; i < path.length; i++) {
    acc += haversineMeters(
      path[i - 1].lat,
      path[i - 1].lon,
      path[i].lat,
      path[i].lon,
    );
    if (acc > total * fraction) break;
    out.add(path[i]);
  }
  return out;
}

void main() {
  final course = loadCourse('geumjeongsan-beomeosa');

  test('코스 60%까지 갔다가 같은 길로 돌아오면 진행률 약 60%', () {
    final up = prefix(course.path, 0.6);
    final track = walk([...up, ...up.reversed.skip(1)]);

    expect(CourseMatcher.match(course, track), isNull);
    final p = CourseMatcher.progress(course, track)!;
    expect(p.progress, closeTo(0.6, 0.05));
    expect(p.startedAt, walkStart);
  });

  test('완주한 코스는 진행률 목록에 넣지 않는다 (완주 기록으로 따로 남는다)', () {
    final track = walk(course.path);
    expect(CourseMatcher.match(course, track), isNotNull);
    expect(CourseMatcher.progressAll([course], track), isEmpty);
  });

  test('들머리를 지나지 않았으면 진행률이 없다', () {
    // 코스 중간부터 걷기 시작
    final middle = course.path.sublist(course.path.length ~/ 2);
    expect(CourseMatcher.progress(course, walk(middle)), isNull);
  });

  test('10% 미만은 그 코스에 간 것으로 보지 않는다', () {
    final track = walk(prefix(course.path, 0.05));
    expect(CourseMatcher.progressAll([course], track), isEmpty);
  });

  test('들머리에서 다른 길로 빠지면 따라간 데까지만 센다', () {
    // 30%까지 코스를 따르다가 동쪽으로 500m 벗어난다.
    final up = prefix(course.path, 0.3);
    final last = up.last;
    final detour = [
      for (var k = 1; k <= 50; k++)
        GeoPoint(last.lat, last.lon + k * 10 / 91000),
    ];
    final p = CourseMatcher.progress(course, walk([...up, ...detour]))!;
    expect(p.progress, closeTo(0.3, 0.05));
  });

  test('진행률 목록은 코스마다 하나씩', () {
    final other = Course(
      id: 'far',
      mountainName: '',
      name: '',
      startName: '',
      endName: '',
      distanceM: 0,
      path: const [GeoPoint(35.0, 128.9), GeoPoint(35.01, 128.9)],
      summit: const GeoPoint(35.01, 128.9),
    );
    final up = prefix(course.path, 0.5);
    final list = CourseMatcher.progressAll([course, other], walk(up));
    expect(list.map((p) => p.courseId), [course.id]);
  });
}
