import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/courses/data/course_remote.dart';
import 'package:hiking_app/features/courses/data/course_repository.dart';

import '../../../helpers/pump_app.dart';
import '../fake_course_remote.dart';

void main() {
  test('서버 course_catalog 한 행을 코스로 바꾼다 (경로는 GeoJSON)', () {
    final course = courseFromCatalogRow({
      'id': '6f1c…',
      'slug': 'seunghaksan-donga',
      'name': '동아대 코스',
      'start_name': '동아대학교 승학캠퍼스',
      'end_name': '승학산 정상',
      'distance_m': 1040,
      'official_time_min': 18,
      'official_difficulty': '하',
      'mountain_name': '승학산',
      'summit_lat': 35.11683,
      'summit_lon': 128.97982,
      'path': {
        'type': 'LineString',
        'coordinates': [
          [128.9704, 35.11916],
          [128.97989, 35.11677],
        ],
      },
    });
    expect(course.fullName, '승학산 동아대 코스');
    expect(course.distanceM, 1040.0);
    expect(course.path, hasLength(2));
    // GeoJSON은 [경도, 위도] 순서다.
    expect(course.start.lat, 35.11916);
    expect(course.start.lon, 128.9704);
  });

  test('data/trails/courses의 실제 코스 파일도 읽을 수 있다', () {
    final feature = jsonDecode(
      File('data/trails/courses/geumjeongsan-beomeosa.geojson')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final p = feature['properties'] as Map<String, dynamic>;
    final course = courseFromCatalogRow({
      'id': 'x',
      'name': p['course_name'],
      'start_name': p['start_name'],
      'end_name': p['end_name'],
      'distance_m': p['distance_m'],
      'official_time_min': p['official_time_min'],
      'official_difficulty': p['official_difficulty'],
      'mountain_name': p['mountain_name'],
      'summit_lat': 35.28015,
      'summit_lon': 129.05062,
      'path': feature['geometry'],
    });
    expect(course.path.length, greaterThan(100));
    // 마지막 점(정상)이 고당봉 근처다.
    expect(course.path.last.lat, closeTo(35.28015, 0.001));
  });

  test('받은 코스를 기기에 저장하고, 서버 연결이 안 되면 저장본을 그대로 둔다', () async {
    final db = testDatabase();
    final remote = FakeCourseRemote([
      testCourse(id: 'a', mountainName: '승학산'),
      testCourse(id: 'b', mountainName: '금정산'),
    ]);
    final repo = CourseRepository(db, remote);

    expect(await repo.sync(), isTrue);
    var saved = await repo.watchAll().first;
    expect(saved.map((c) => c.mountainName), ['금정산', '승학산']);
    expect(saved.first.path, hasLength(3));

    remote.failWith = const SocketException('offline');
    expect(await repo.sync(), isFalse);
    saved = await repo.watchAll().first;
    expect(saved, hasLength(2));
  });

  test('서버에서 코스가 빠지면 기기에서도 빠진다', () async {
    final db = testDatabase();
    final remote = FakeCourseRemote([testCourse(id: 'a'), testCourse(id: 'b')]);
    final repo = CourseRepository(db, remote);
    await repo.sync();

    remote.courses = [testCourse(id: 'b')];
    await repo.sync();

    expect((await repo.watchAll().first).map((c) => c.id), ['b']);
  });
}
