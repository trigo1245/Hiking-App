import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/activities/domain/hike_check.dart';
import 'package:hiking_app/features/courses/domain/course.dart';

import '../../../helpers/course_walk.dart';

void main() {
  final beomeosa = loadCourse('geumjeongsan-beomeosa');
  final start = beomeosa.path.first;

  test('코스를 따라 걸으면 오른 높이와 상관없이 산행이다', () {
    final track = walk(beomeosa.path.take(20).toList());
    expect(
      HikeCheck.isHike(
        distanceM: 800,
        elevationGainM: 0,
        track: track,
        courses: [beomeosa],
      ),
      isTrue,
    );
  });

  test('코스 선 200m 안을 지나기만 해도 산행으로 본다 (들머리 근처 다른 길)', () {
    // 들머리에서 동쪽으로 약 150m 떨어진 곳을 남북으로 걷는다.
    final track = walk([
      GeoPoint(start.lat - 0.002, start.lon + 0.0016),
      GeoPoint(start.lat + 0.002, start.lon + 0.0016),
    ]);
    expect(HikeCheck.passesNearCourse(track, [beomeosa]), isTrue);
  });

  test('코스에서 먼 평지 산책은 산행이 아니다', () {
    // 부산 시내 (범어사 코스에서 수 km 떨어진 곳)
    final track = walk([
      const GeoPoint(35.1580, 129.0590),
      const GeoPoint(35.1620, 129.0640),
    ]);
    expect(
      HikeCheck.isHike(
        distanceM: 700,
        elevationGainM: 12,
        track: track,
        courses: [beomeosa],
      ),
      isFalse,
    );
  });

  test('등록되지 않은 산도 가파르게 100m 넘게 오르면 산행이다', () {
    expect(
      HikeCheck.climbsEnough(distanceM: 2000, elevationGainM: 180),
      isTrue,
    );
    // 10km를 걸으며 조금씩 오른 100m (1km당 10m)는 언덕 많은 동네 산책으로 본다.
    expect(
      HikeCheck.climbsEnough(distanceM: 10000, elevationGainM: 100),
      isFalse,
    );
    expect(HikeCheck.climbsEnough(distanceM: 500, elevationGainM: 60), isFalse);
  });
}
