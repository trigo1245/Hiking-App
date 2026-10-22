import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/features/activities/domain/gpx_reader.dart';
import 'package:hiking_app/features/activities/domain/gpx_writer.dart';
import 'package:hiking_app/features/recording/domain/track_point.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 13, 0, 5);

  TrackPoint point(int i, {int segment = 0, double? altitude}) => TrackPoint(
    segment: segment,
    latitude: 35.1 + i * 0.0001,
    longitude: 129.0 - i * 0.0001,
    altitude: altitude,
    accuracy: 4.5 + i,
    recordedAt: t0.add(Duration(seconds: i * 3)),
  );

  test('GPX로 쓴 점을 그대로 다시 읽는다 (위치·고도·시각·정확도)', () {
    final points = [for (var i = 0; i < 5; i++) point(i, altitude: 100.0 + i)];
    final read = parseGpx(buildGpx(title: '금정산 <고당봉>', points: points));

    expect(read, hasLength(5));
    for (var i = 0; i < 5; i++) {
      expect(read[i].latitude, points[i].latitude);
      expect(read[i].longitude, points[i].longitude);
      expect(read[i].altitude, points[i].altitude);
      expect(read[i].accuracy, points[i].accuracy);
      expect(read[i].recordedAt, points[i].recordedAt);
      expect(read[i].segment, 0);
    }
  });

  test('일시정지로 나뉜 구간을 구간 번호로 되살린다', () {
    final points = [
      point(0),
      point(1),
      point(2, segment: 3), // 기기에서는 3번 구간이어도
      point(3, segment: 3),
    ];
    final read = parseGpx(buildGpx(title: 't', points: points));
    // 순서대로 0, 1로 다시 매긴다 (구간이 나뉘었다는 사실만 중요하다).
    expect(read.map((p) => p.segment), [0, 0, 1, 1]);
  });

  test('고도가 없는 점은 고도 없이, 정확도가 없으면 기본값으로 읽는다', () {
    const gpx = '''
<gpx><trk><trkseg>
  <trkpt lat="35.1" lon="129.0"><time>2026-10-13T00:05:00.000Z</time></trkpt>
</trkseg></trk></gpx>''';
    final read = parseGpx(gpx);
    expect(read.single.altitude, isNull);
    expect(read.single.accuracy, 10);
  });

  test('빈 GPX는 빈 목록', () {
    expect(parseGpx(buildGpx(title: 't', points: const [])), isEmpty);
  });
}
