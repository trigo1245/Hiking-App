import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/activities/domain/activity_analysis.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';

/// 합성 기록의 한 구간: [steps]번 걷는다. 한 걸음에 [seconds]초, 고도 [rise]m, 북쪽으로 [meters]m.
/// [meters]가 0이면 제자리에 머문다(휴식). [segment]가 바뀌면 일시정지 후 다시 시작한 것.
typedef Leg = ({
  int steps,
  int seconds,
  double rise,
  double meters,
  int segment,
});

Leg leg(
  int steps,
  int seconds,
  double rise, {
  double meters = 10,
  int segment = 0,
}) => (
  steps: steps,
  seconds: seconds,
  rise: rise,
  meters: meters,
  segment: segment,
);

List<TrackPoint> hike(List<Leg> legs) {
  final out = <TrackPoint>[];
  var t = DateTime.utc(2026, 10, 20, 0);
  var lat = 35.0;
  var alt = 100.0;
  TrackPoint point(int segment) => TrackPoint(
    segment: segment,
    latitude: lat,
    longitude: 129.0,
    altitude: alt,
    accuracy: 5,
    recordedAt: t,
  );
  out.add(point(0));
  for (final l in legs) {
    for (var i = 0; i < l.steps; i++) {
      lat += l.meters / 111195;
      alt += l.rise;
      t = t.add(Duration(seconds: l.seconds));
      out.add(point(l.segment));
    }
  }
  return out;
}

void main() {
  // 평지 1km(10초/10m) → 오르막 1km +150m(15초/10m) → 내리막 1km -150m(8초/10m)
  final track = hike([leg(100, 10, 0), leg(100, 15, 1.5), leg(100, 8, -1.5)]);
  final analysis = ActivityAnalyzer.analyze(track);

  group('Tobler 등산 함수', () {
    test('약간 내리막(-5%)에서 가장 빠른 6km/h, 평지는 약 5.04km/h', () {
      expect(toblerSpeedKmh(-0.05), closeTo(6, 1e-9));
      expect(toblerFlatKmh, closeTo(5.036, 0.001));
    });

    test('오르막이든 내리막이든 가파를수록 느려진다', () {
      expect(toblerSpeedKmh(0.15), lessThan(toblerFlatKmh));
      expect(toblerSpeedKmh(0.3), lessThan(toblerSpeedKmh(0.15)));
      expect(toblerSpeedKmh(-0.3), lessThan(toblerSpeedKmh(-0.1)));
    });
  });

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

  test('구간별 실제 평균 속도', () {
    expect(analysis.grade(GradeKind.flat).speedKmh, closeTo(3.6, 0.2));
    expect(analysis.grade(GradeKind.uphill).speedKmh, closeTo(2.4, 0.2));
    expect(analysis.grade(GradeKind.downhill).speedKmh, closeTo(4.5, 0.3));
  });

  group('경사 보정 페이스 (GAP)', () {
    test('평지는 실제 페이스와 같다 (3.6km/h → 1km에 약 16분 40초)', () {
      final pace = analysis.grade(GradeKind.flat).gradeAdjustedPace!;
      expect(pace.inSeconds, closeTo(1000, 30));
    });

    test('오르막은 경사만큼 보정해 평지 환산 페이스가 실제보다 빠르다', () {
      final up = analysis.grade(GradeKind.uphill);
      // 15% 오르막 표준 속도 = 6·e^(-3.5·0.2) ≈ 2.98km/h, 내 속도 2.4km/h → 표준의 약 81%
      expect(up.efficiency, closeTo(2.4 / toblerSpeedKmh(0.15), 0.05));
      final actualPace = 3600 / up.speedKmh;
      expect(up.gradeAdjustedPace!.inSeconds, lessThan(actualPace));
    });

    test('같은 속도 비율이면 오르막·평지 효율이 같게 나온다', () {
      // 평지를 표준의 80%로, 15% 오르막도 표준의 80%로 걷는다.
      int secondsFor(double kmh) => (10 / (kmh * 0.8) * 3.6).round();
      final even = ActivityAnalyzer.analyze(
        hike([
          leg(100, secondsFor(toblerFlatKmh), 0),
          leg(100, secondsFor(toblerSpeedKmh(0.15)), 1.5),
        ]),
      );
      expect(even.grade(GradeKind.flat).efficiency, closeTo(0.8, 0.06));
      expect(even.grade(GradeKind.uphill).efficiency, closeTo(0.8, 0.06));
    });
  });

  group('휴식 구간', () {
    final withRest = ActivityAnalyzer.analyze(
      hike([
        leg(50, 10, 0),
        leg(5, 60, 0, meters: 0), // 5분 제자리
        leg(50, 10, 0),
      ]),
    );

    test('15m 안에 2분 이상 머물면 휴식으로 본다', () {
      expect(withRest.rests, hasLength(1));
      // 앞뒤 한 걸음(10m, 10초)은 반경 15m 안이라 휴식에 포함될 수 있다.
      expect(withRest.rests.single.length.inSeconds, closeTo(300, 20));
      expect(withRest.rests.single.start.inSeconds, closeTo(500, 10));
    });

    test('휴식 시간은 페이스 계산에서 뺀다', () {
      expect(withRest.grade(GradeKind.flat).speedKmh, closeTo(3.6, 0.2));
    });

    test('2분보다 짧게 멈추면 휴식이 아니다', () {
      final short = ActivityAnalyzer.analyze(
        hike([leg(50, 10, 0), leg(1, 90, 0, meters: 0), leg(50, 10, 0)]),
      );
      expect(short.rests, isEmpty);
    });

    test('일시정지한 시간도 휴식으로 본다', () {
      final paused = ActivityAnalyzer.analyze(
        hike([leg(50, 10, 0), leg(50, 10, 0, segment: 1)]),
      );
      expect(paused.rests, hasLength(1));
    });

    test('천천히 걸어도 계속 움직이면 휴식이 아니다', () {
      expect(analysis.rests, isEmpty);
    });
  });

  group('위험 구간', () {
    // 평지 → 경사 40% 오르막 200m → 평지 → 경사 40% 내리막 200m → 평지
    final steep = ActivityAnalyzer.analyze(
      hike([
        leg(30, 10, 0),
        leg(20, 20, 4),
        leg(30, 10, 0),
        leg(20, 12, -4),
        leg(30, 10, 0),
      ]),
    );

    test('경사 30% 이상인 곳을 오르막·내리막 모두 위험 구간으로 본다', () {
      expect(steep.dangers, hasLength(2));
      // 첫 위험 구간은 오르막(300초 뒤 시작) 근처
      expect(steep.dangers.first.start.inSeconds, closeTo(300, 60));
    });

    test('급경사 내리막만 따로 모은다', () {
      expect(steep.dangerDownhill, isNotNull);
      expect(steep.dangerDownhill!.distanceM, greaterThan(100));
    });

    test('완만한 길만 걸으면 위험 구간이 없다', () {
      expect(analysis.dangers, isEmpty);
      expect(analysis.dangerDownhill, isNull);
    });
  });

  test('1km마다 걸린 시간과 오른 높이', () {
    expect(analysis.splits.map((s) => s.km), [1, 2, 3]);
    expect(analysis.splits[0].duration.inSeconds, closeTo(1000, 20));
    expect(analysis.splits[1].duration.inSeconds, closeTo(1500, 30));
    expect(analysis.splits[1].gainM, closeTo(150, 5));
    expect(analysis.splits[2].gainM, closeTo(0, 2));
  });

  test('고도 그래프는 가로축이 시간이고, 최대 120개 점으로 솎는다', () {
    final profile = analysis.elevationProfile;
    expect(profile.length, ActivityAnalyzer.maxProfilePoints);
    expect(profile.first.elapsed, Duration.zero);
    expect(profile.first.altitudeM, closeTo(100, 1));
    expect(profile.last.elapsed, analysis.totalDuration);
    // 1000 + 1500 + 800초
    expect(analysis.totalDuration, const Duration(seconds: 3300));
  });

  test('후반 오르막이 느려지면 피로도 비율이 1보다 작다', () {
    // 오르막만 두 번: 앞은 빠르게(10초), 뒤는 느리게(20초) 같은 높이를 오른다.
    final tired = ActivityAnalyzer.analyze(
      hike([leg(100, 10, 1.0), leg(100, 20, 1.0)]),
    );
    expect(tired.fatigue, isNotNull);
    expect(tired.fatigue!.ratio, lessThan(0.8));
  });

  test('오르막이 없으면 피로도를 계산하지 않는다', () {
    final flatOnly = ActivityAnalyzer.analyze(hike([leg(200, 10, 0)]));
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
    expect(result.dangers, isEmpty);
    expect(
      result.elevationProfile
          .map((s) => s.altitudeM)
          .reduce((a, b) => a > b ? a : b),
      lessThan(300),
    );
  });

  test('점이 없으면 빈 분석을 돌려준다', () {
    final empty = ActivityAnalyzer.analyze(const []);
    expect(empty.elevationProfile, isEmpty);
    expect(empty.efficiency, isNull);
  });
}
