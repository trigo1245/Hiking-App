import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/activities/domain/activity_analysis.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';

/// 북쪽으로 10m씩 걷는 합성 기록을 만든다.
/// 각 구간: (걸음 수, 걸음당 초, 걸음당 고도 변화)
List<TrackPoint> hike(List<(int, int, double)> legs) {
  final out = <TrackPoint>[];
  var t = DateTime.utc(2026, 10, 20, 0);
  var lat = 35.0;
  var alt = 100.0;
  out.add(
    TrackPoint(
      segment: 0,
      latitude: lat,
      longitude: 129.0,
      altitude: alt,
      accuracy: 5,
      recordedAt: t,
    ),
  );
  for (final (steps, seconds, rise) in legs) {
    for (var i = 0; i < steps; i++) {
      lat += 10 / 111195; // 약 10m
      alt += rise;
      t = t.add(Duration(seconds: seconds));
      out.add(
        TrackPoint(
          segment: 0,
          latitude: lat,
          longitude: 129.0,
          altitude: alt,
          accuracy: 5,
          recordedAt: t,
        ),
      );
    }
  }
  return out;
}

void main() {
  // 평지 1km(10초/10m) → 오르막 1km +150m(15초/10m) → 내리막 1km -150m(8초/10m)
  final track = hike([(100, 10, 0), (100, 15, 1.5), (100, 8, -1.5)]);
  final analysis = ActivityAnalyzer.analyze(track);

  test('오르막·평지·내리막을 경사 5% 기준으로 나눈다', () {
    final up = analysis.grade(GradeKind.uphill);
    final flat = analysis.grade(GradeKind.flat);
    final down = analysis.grade(GradeKind.downhill);

    expect(up.distanceM, closeTo(1000, 60));
    expect(flat.distanceM, closeTo(1000, 60));
    expect(down.distanceM, closeTo(1000, 60));
    expect(up.verticalM, closeTo(150, 10));
    expect(down.verticalM, closeTo(150, 10));
  });

  test('구간별 평균 속도', () {
    expect(analysis.grade(GradeKind.flat).speedKmh, closeTo(3.6, 0.2));
    expect(analysis.grade(GradeKind.uphill).speedKmh, closeTo(2.4, 0.2));
    expect(analysis.grade(GradeKind.downhill).speedKmh, closeTo(4.5, 0.3));
  });

  test('1km마다 걸린 시간과 오른 높이', () {
    expect(analysis.splits.map((s) => s.km), [1, 2, 3]);
    expect(analysis.splits[0].duration.inSeconds, closeTo(1000, 20));
    expect(analysis.splits[1].duration.inSeconds, closeTo(1500, 30));
    expect(analysis.splits[1].gainM, closeTo(150, 5));
    expect(analysis.splits[2].gainM, closeTo(0, 2));
  });

  test('고도 그래프는 최대 120개 점으로 솎는다', () {
    expect(analysis.elevationProfile.length, ActivityAnalyzer.maxProfilePoints);
    expect(analysis.elevationProfile.first.altitudeM, 100);
    expect(analysis.elevationProfile.first.distanceM, 0);
    expect(analysis.elevationProfile.last.distanceM, closeTo(3000, 60));
  });

  test('후반 오르막이 느려지면 피로도 비율이 1보다 작다', () {
    // 오르막만 두 번: 앞은 빠르게(10초), 뒤는 느리게(20초) 같은 높이를 오른다.
    final tired = ActivityAnalyzer.analyze(
      hike([(100, 10, 1.0), (100, 20, 1.0)]),
    );
    expect(tired.fatigue, isNotNull);
    expect(tired.fatigue!.ratio, lessThan(0.8));
  });

  test('오르막이 없으면 피로도를 계산하지 않는다', () {
    final flatOnly = ActivityAnalyzer.analyze(hike([(200, 10, 0)]));
    expect(flatOnly.fatigue, isNull);
  });

  test('정확도가 나쁜 점은 분석에서 뺀다', () {
    final noisy = [
      ...track.take(50),
      TrackPoint(
        segment: 0,
        latitude: 36.0, // 100km 떨어진 튀는 점
        longitude: 129.0,
        altitude: 900,
        accuracy: 200,
        recordedAt: track[50].recordedAt,
      ),
      ...track.skip(50),
    ];
    final result = ActivityAnalyzer.analyze(noisy);
    expect(result.elevationProfile.last.distanceM, closeTo(3000, 60));
  });
}
