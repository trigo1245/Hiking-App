import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/courses/domain/course_matching.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';

import '../../../helpers/course_walk.dart';

void main() {
  final beomeosa = loadCourse('geumjeongsan-beomeosa');
  final sanseong = loadCourse('geumjeongsan-sanseong');

  test('코스를 따라 오르면 완주이고, 등정 시간은 들머리→정상 시간이다', () {
    final track = walk(beomeosa.path);
    final result = CourseMatcher.match(beomeosa, track);

    expect(result, isNotNull);
    expect(result!.overlapRatio, greaterThan(0.95));
    // 2.8km를 10초에 10m씩 걸으면 약 47분. 들머리 100m 원을 벗어날 때부터
    // 정상 50m 원에 들어올 때까지 재므로 약 2.5분 짧은 44분 안팎이다.
    expect(result.ascent.inMinutes, closeTo(44, 2));
  });

  test('주차장에서 기다렸다 출발해도 마지막으로 들머리를 지난 시각부터 잰다', () {
    final waiting = [
      for (var k = 0; k < 30; k++)
        TrackPoint(
          segment: 0,
          latitude: beomeosa.start.lat,
          longitude: beomeosa.start.lon,
          accuracy: 5,
          recordedAt: walkStart.add(Duration(seconds: k * 10)),
        ),
    ];
    final climb = walk(
      beomeosa.path,
      from: walkStart.add(const Duration(minutes: 30)),
    );
    final result = CourseMatcher.match(beomeosa, [...waiting, ...climb])!;

    expect(result.ascent.inMinutes, closeTo(44, 2));
  });

  test('들머리에서 멀리 떨어져 시작하면 완주가 아니다', () {
    // 코스 앞 30%를 건너뛰고 중간부터 걷는다.
    final track = walk(beomeosa.path.sublist(beomeosa.path.length * 3 ~/ 10));
    expect(CourseMatcher.match(beomeosa, track), isNull);
  });

  test('정상 직전에서 돌아서면 완주가 아니다', () {
    final track = walk(beomeosa.path.sublist(0, beomeosa.path.length - 15));
    expect(CourseMatcher.match(beomeosa, track), isNull);
  });

  test('중간에 코스에서 크게 벗어나면(겹침 80% 미만) 완주가 아니다', () {
    final n = beomeosa.path.length;
    final detour = [
      for (var k = 0; k < n; k++)
        // 코스 가운데 40%를 북쪽으로 120m 벗어나 걷는다.
        k > n * 0.3 && k < n * 0.7
            ? shiftNorth(beomeosa.path[k], 120)
            : beomeosa.path[k],
    ];
    expect(CourseMatcher.match(beomeosa, walk(detour)), isNull);
  });

  test('내려오기만 한 기록은 완주가 아니다', () {
    final down = walk(beomeosa.path.reversed.toList());
    expect(CourseMatcher.match(beomeosa, down), isNull);
  });

  test('범어사로 올라 산성마을로 내려오면 범어사 코스만 완주다', () {
    final up = walk(beomeosa.path);
    final down = walk(
      sanseong.path.reversed.toList(),
      from: up.last.recordedAt.add(const Duration(minutes: 10)),
    );
    final results = CourseMatcher.matchAll(
      [beomeosa, sanseong],
      [...up, ...down],
    );

    expect(results.map((r) => r.courseId), ['geumjeongsan-beomeosa']);
  });

  test('정확도가 나쁜 점만으로는 정상 도착을 인정하지 않는다', () {
    final track = walk(beomeosa.path);
    // 정상 근처 점들의 정확도가 나쁘다.
    final degraded = [
      for (final (i, p) in track.indexed)
        i > track.length - 10
            ? TrackPoint(
                segment: p.segment,
                latitude: p.latitude,
                longitude: p.longitude,
                accuracy: 80,
                recordedAt: p.recordedAt,
              )
            : p,
    ];
    expect(CourseMatcher.match(beomeosa, degraded), isNull);
  });

  test('겹침 비율: 같은 선은 1, 멀리 떨어진 선은 0', () {
    final far = [for (final p in beomeosa.path) shiftNorth(p, 500)];
    expect(CourseMatcher.overlapRatio(beomeosa.path, beomeosa.path), 1);
    expect(CourseMatcher.overlapRatio(beomeosa.path, far), 0);
  });
}
