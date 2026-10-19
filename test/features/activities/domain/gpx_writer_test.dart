import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/activities/domain/gpx_writer.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';
import 'package:hiking_app/features/recording/domain/track_stats.dart';

import '../../../helpers/gpx.dart';

void main() {
  TrackPoint point(int segment, int second, {double? altitude = 100}) =>
      TrackPoint(
        segment: segment,
        latitude: 37.46 + second * 0.00001,
        longitude: 126.95,
        altitude: altitude,
        accuracy: 4.5,
        recordedAt: DateTime.utc(2026, 10, 13, 0, 0, second),
      );

  test('일시정지로 나뉜 구간마다 trkseg를 따로 만든다', () {
    final gpx = buildGpx(
      title: '관악산',
      points: [point(0, 0), point(0, 10), point(1, 20)],
    );
    expect('<trkseg>'.allMatches(gpx), hasLength(2));
    expect('<trkpt '.allMatches(gpx), hasLength(3));
  });

  test('시간은 UTC, 정확도는 extensions에 넣는다', () {
    final gpx = buildGpx(title: 't', points: [point(0, 5)]);
    expect(gpx, contains('<time>2026-10-13T00:00:05.000Z</time>'));
    expect(gpx, contains('<hk:accuracy>4.5</hk:accuracy>'));
  });

  test('고도를 모르는 점은 ele를 생략한다', () {
    final gpx = buildGpx(title: 't', points: [point(0, 0, altitude: null)]);
    expect(gpx, isNot(contains('<ele>')));
  });

  test('제목의 특수문자를 XML에 맞게 바꾼다', () {
    final gpx = buildGpx(title: '북한산 <백운대> & "인수봉"', points: const []);
    expect(gpx, contains('<name>북한산 &lt;백운대&gt; &amp; &quot;인수봉&quot;</name>'));
  });

  test('만든 GPX를 다시 읽으면 같은 경로와 수치가 나온다', () {
    final original = readGpx('test_data/synthetic_climb.gpx');
    final gpx = buildGpx(
      title: 'synthetic',
      points: [for (final s in original) TrackPoint.fromSample(s, segment: 0)],
    );
    final file = File('${Directory.systemTemp.path}/roundtrip_test.gpx')
      ..writeAsStringSync(gpx);
    addTearDown(file.deleteSync);

    final stats =
        (TrackStatsCalculator()..addAll(
              readGpx(file.path)
                  .map((s) => TrackPoint.fromSample(s, segment: 0)),
            ))
            .stats;
    expect(stats.pointCount, 51);
    expect(stats.distanceM, closeTo(556, 1));
    expect(stats.elevationGainM, 100);
  });
}
