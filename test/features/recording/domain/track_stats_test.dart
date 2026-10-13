import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';
import 'package:hiking_app/features/recording/domain/track_stats.dart';

import '../../../helpers/gpx.dart';

final _t0 = DateTime.utc(2026, 10, 13, 9);

/// 북쪽으로 [step]번째 점. 위도 0.0001도 ≈ 11.1m
TrackPoint _point(
  int step, {
  int seconds = 10,
  double? altitude,
  double accuracy = 5,
  int segment = 0,
  double latStep = 0.0001,
  int? atSecond,
}) => TrackPoint(
  segment: segment,
  latitude: 37.46 + step * latStep,
  longitude: 126.95,
  altitude: altitude,
  accuracy: accuracy,
  recordedAt: _t0.add(Duration(seconds: atSecond ?? step * seconds)),
);

TrackStats _calc(Iterable<TrackPoint> points) =>
    (TrackStatsCalculator()..addAll(points)).stats;

void main() {
  group('test_data/synthetic_climb.gpx', () {
    final stats = _calc(
      readGpx('test_data/synthetic_climb.gpx')
          .map((s) => TrackPoint.fromSample(s, segment: 0)),
    );

    test('거리: 50걸음 × 약 11.12m', () {
      expect(stats.distanceM, closeTo(556, 1));
    });

    test('상승고도: 100m → 200m', () {
      expect(stats.elevationGainM, 100);
      expect(stats.maxAltitudeM, 200);
    });

    test('이동 시간: 계속 움직였으므로 500초 전체', () {
      expect(stats.moving, const Duration(seconds: 500));
    });

    test('정상 속도(약 4km/h)라 표시되지 않는다', () {
      expect(stats.isFlagged, isFalse);
      expect(stats.pointCount, 51);
    });
  });

  group('정확도 필터', () {
    test('정확도 30m보다 나쁜 점은 계산에서 빼지만 개수에는 포함한다', () {
      final stats = _calc([
        _point(0),
        _point(50, accuracy: 80, atSecond: 10), // 튀는 점 (약 555m 떨어짐)
        _point(1, atSecond: 20),
      ]);
      expect(stats.distanceM, closeTo(11.1, 0.1));
      expect(stats.pointCount, 3);
      expect(stats.isFlagged, isFalse);
    });

    test('정확도 정확히 30m는 사용한다', () {
      final stats = _calc([_point(0), _point(1, accuracy: 30)]);
      expect(stats.distanceM, closeTo(11.1, 0.1));
    });
  });

  group('누적 상승고도 (3m 임계값)', () {
    List<TrackPoint> withAltitudes(List<double> altitudes) => [
      for (var i = 0; i < altitudes.length; i++)
        _point(i, altitude: altitudes[i]),
    ];

    test('2m 이내로 흔들리는 고도는 더하지 않는다', () {
      final stats = _calc(withAltitudes([100, 102, 100, 101.5, 99, 101]));
      expect(stats.elevationGainM, 0);
    });

    test('3m 이상 오르면 더한다', () {
      final stats = _calc(withAltitudes([100, 103, 106, 110]));
      expect(stats.elevationGainM, 10);
    });

    test('내려갔다 다시 오르면 다시 오른 만큼만 더한다', () {
      final stats = _calc(withAltitudes([100, 110, 95, 105]));
      expect(stats.elevationGainM, 20); // 100→110, 95→105
      expect(stats.maxAltitudeM, 110);
    });

    test('고도를 모르는 점은 건너뛴다', () {
      final stats = _calc([
        _point(0, altitude: 100),
        _point(1),
        _point(2, altitude: 105),
      ]);
      expect(stats.elevationGainM, 5);
    });
  });

  group('이동 시간', () {
    test('같은 자리에 오래 있던 구간은 빠진다', () {
      final stats = _calc([
        _point(0, atSecond: 0),
        _point(1, atSecond: 10), // 이동
        _point(1, atSecond: 310), // 5분 동안 제자리
        _point(2, atSecond: 320), // 이동
      ]);
      expect(stats.moving, const Duration(seconds: 20));
    });

    test('일시정지로 구간이 바뀌면 그 사이 거리와 시간은 더하지 않는다', () {
      final stats = _calc([
        _point(0, atSecond: 0),
        _point(1, atSecond: 10),
        _point(30, atSecond: 1000, segment: 1), // 일시정지 중 이동한 거리
        _point(31, atSecond: 1010, segment: 1),
      ]);
      expect(stats.distanceM, closeTo(22.2, 0.2));
      expect(stats.moving, const Duration(seconds: 20));
    });
  });

  group('속도 이상 표시 (시속 15km 초과)', () {
    test('시속 15km를 넘는 구간이 있으면 표시한다', () {
      // 10초에 약 55.6m = 시속 약 20km
      final stats = _calc([_point(0), _point(5, atSecond: 10)]);
      expect(stats.isFlagged, isTrue);
    });

    test('시속 15km 이하면 표시하지 않는다', () {
      // 10초에 약 33.4m = 시속 약 12km
      final stats = _calc([_point(0), _point(3, atSecond: 10)]);
      expect(stats.isFlagged, isFalse);
    });
  });
}
